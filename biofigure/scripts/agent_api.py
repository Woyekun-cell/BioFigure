"""Native API agent transports with scoped, local scientific-figure tools."""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlsplit, urlunsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

from agent_host import _json, _validate

SKILL = Path(__file__).resolve().parents[1]
PROTOCOLS = ("openai", "anthropic", "gemini")
MAX_READ = 256_000
MAX_HTTP = 16_000_000
# Protocol references, checked 2026-11-28.
# https://developers.openai.com/api/reference/resources/chat
# https://platform.claude.com/docs/en/api/messages
# https://ai.google.dev/api/generate-content


class SandboxUnavailable(RuntimeError):
    pass


class _NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def _sensitive(path):
    blocked = {".ssh", ".aws", ".codex", ".claude", ".gemini", ".config", ".kube", ".git",
               ".gnupg", ".netrc", ".npmrc", ".pypirc", "credentials", "auth.json", "keychains"}
    return any(part.lower() in blocked or part.lower().startswith(".env") or
               part.lower().endswith("-host.json") for part in path.parts)


def _json_file(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False), encoding="utf-8")


def _image_data(path):
    content = path.read_bytes()
    if len(content) > 5_000_000:
        raise ValueError("Use figure previews smaller than 5 MB")
    if content.startswith(b"\x89PNG\r\n\x1a\n"):
        mime = "image/png"
    elif content.startswith(b"\xff\xd8"):
        mime = "image/jpeg"
    elif content[:4] == b"RIFF" and content[8:12] == b"WEBP":
        mime = "image/webp"
    else:
        raise ValueError("Attach PNG, JPEG or WebP figure previews")
    from PIL import Image
    try:
        with Image.open(path) as image:
            image.verify()
    except (OSError, SyntaxError, Image.DecompressionBombError) as error:
        raise ValueError("The figure is not a valid image") from error
    return mime, base64.b64encode(content).decode("ascii")



class _Tools:
    def __init__(self, cwd, images, read_dirs, mode):
        self.cwd = Path(cwd).resolve()
        self.mode = mode
        self.executed = False
        self.viewed = {}
        self.allowed = [Path(path).resolve() for path in (*images, *read_dirs)]
        self.allowed += [SKILL / "SKILL.md", *[SKILL / name for name in (
            "scripts", "references", "static", "patterns", "components", "palettes", "checkpoints", "critics")]]
        self.allowed = [path for path in self.allowed if path.exists() and not _sensitive(path)]
        self._sandbox = None

    def path(self, value, write=False):
        if not isinstance(value, str) or not value or "\x00" in value:
            raise ValueError("Supply a local file path")
        lexical = Path(value)
        if not lexical.is_absolute():
            lexical = self.cwd / lexical
        resolved = lexical.resolve()
        if _sensitive(lexical) or _sensitive(resolved):
            raise ValueError("Credential and unrelated configuration files are unavailable")
        # Refuse symlink-mediated writes even if the final destination is in cwd.
        if write:
            if self.mode != "render" or not resolved.is_relative_to(self.cwd):
                raise ValueError("Write only inside the current drawing task")
            if any(part.is_symlink() for part in (lexical, *lexical.parents) if part.is_relative_to(self.cwd)):
                raise ValueError("Do not write through symbolic links")
        elif not resolved.is_relative_to(self.cwd) and not any(
                resolved == root or (root.is_dir() and resolved.is_relative_to(root)) for root in self.allowed):
            raise ValueError("Read only the selected plotting materials")
        return resolved

    def declarations(self):
        tools = [
            {"name": "read_file", "description": "Read selected source text, using byte offset and limit for large files.",
             "parameters": {"type": "object", "properties": {"path": {"type": "string"},
                 "offset": {"type": "integer"}, "limit": {"type": "integer"}}, "required": ["path"]}},
            {"name": "list_files", "description": "List a selected source directory or the current drawing task.",
             "parameters": {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]}},
        ]
        tools.append({"name": "view_image", "description": "Attach an allowed current PNG/JPEG/WebP image for actual visual inspection.",
                      "parameters": {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]}})
        if self.mode == "render":
            tools += [
                {"name": "write_file", "description": "Write a new drawing script, configuration or artifact inside the task.",
                 "parameters": {"type": "object", "properties": {"path": {"type": "string"},
                     "content": {"type": "string"}}, "required": ["path", "content"]}},
                {"name": "run_command", "description": "Run a rendering/checking argv inside the task, offline and OS-sandboxed.",
                 "parameters": {"type": "object", "properties": {"argv": {"type": "array", "items": {"type": "string"}}},
                                "required": ["argv"]}},
            ]
        return tools

    def call(self, name, arguments, timeout):
        by_name = {tool["name"]: tool for tool in self.declarations()}
        if name not in by_name:
            raise ValueError("That tool is unavailable for this operation")
        _validate(arguments, by_name[name]["parameters"])
        if name == "read_file":
            path = self.path(arguments["path"])
            offset, limit = arguments.get("offset", 0), arguments.get("limit", MAX_READ)
            if not 0 <= offset or not 0 < limit <= MAX_READ:
                raise ValueError("Use a nonnegative offset and a read limit up to 256,000 bytes")
            with path.open("rb") as stream:
                stream.seek(offset)
                content = stream.read(limit + 1)
            return {"content": content[:limit].decode("utf-8", errors="replace"),
                    "truncated": len(content) > limit, "next_offset": offset + min(len(content), limit)}
        if name == "view_image":
            path = self.path(arguments["path"])
            _image_data(path)
            self.viewed[path] = hashlib.sha256(path.read_bytes()).hexdigest()
            return {"_view_image": str(path)}
        if name == "list_files":
            path = self.path(arguments["path"])
            if not path.is_dir():
                raise ValueError("Choose a selected directory")
            return {"files": [entry.name for entry in sorted(path.iterdir()) if not _sensitive(entry)][:500]}
        if name == "write_file":
            path = self.path(arguments["path"], write=True)
            content = arguments["content"]
            if len(content.encode("utf-8")) > 2_000_000:
                raise ValueError("Write source text in chunks smaller than 2 MB")
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")
            return {"written": path.relative_to(self.cwd).as_posix(), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        argv = arguments["argv"]
        if not argv or len(argv) > 100 or any(not arg or len(arg) > 10_000 or "\x00" in arg for arg in argv):
            raise ValueError("Supply a program and its argv arguments")
        result = self.command(argv, timeout)
        if result.returncode == 0:
            self.executed = True
        return {"returncode": result.returncode, "stdout": result.stdout[-MAX_READ:], "stderr": result.stderr[-MAX_READ:]}

    def _environment(self):
        temporary = self.cwd / ".tmp"
        temporary.mkdir(exist_ok=True)
        # Never pass the service's API keys, login tokens or arbitrary credentials.
        environment = {key: os.environ[key] for key in ("PATH", "LANG", "LC_ALL", "LC_CTYPE") if key in os.environ}
        environment.update(HOME=str(self.cwd), TMPDIR=str(temporary), R_USER=str(self.cwd),
                           R_PROFILE_USER="/dev/null", R_ENVIRON_USER="/dev/null",
                           PYTHONNOUSERSITE="1", PYTHONDONTWRITEBYTECODE="1")
        return environment

    def _sandbox_command(self, argv):
        runtime = [Path(path) for path in ("/System", "/usr/bin", "/usr/lib", "/usr/libexec", "/usr/share", "/bin", "/sbin",
                   "/opt/homebrew/bin", "/opt/homebrew/lib", "/opt/homebrew/Cellar", "/opt/homebrew/opt",
                   "/Library/Frameworks", "/Library/Fonts", "/Library/Developer/CommandLineTools", "/usr/local/bin", "/usr/local/lib", "/private/var/db/dyld", "/lib", "/lib64",
                   "/etc/fonts", "/etc/ld.so.cache", "/dev/null", "/dev/urandom", "/dev/random") if Path(path).exists()]
        if sys.platform == "darwin" and shutil.which("sandbox-exec"):
            def rule(path):
                return f'({"subpath" if path.is_dir() else "literal"} {json.dumps(str(path.resolve()), ensure_ascii=False)})'
            profile = "\n".join([
                "(version 1)", "(deny default)", "(allow process-exec process-fork)", "(allow sysctl-read)",
                '(allow mach-lookup (global-name "com.apple.system.notification_center") (global-name "com.apple.cfprefsd.agent") (global-name "com.apple.cfprefsd.daemon") (global-name "com.apple.system.logger"))',
                "(allow signal (target self))", "(allow file-read-metadata)", '(allow file-read* (literal "/"))',
                '(allow mach-lookup (global-name "com.apple.fonts") (global-name "com.apple.fonts.user"))',
                "(allow file-read* " + " ".join(rule(path) for path in (*runtime, self.cwd, *self.allowed)) + ")",
                "(allow file-write* " + rule(self.cwd) + ' (literal "/dev/null"))',
                '(deny file-read* (regex #"/\\\\.((ssh|aws|codex|claude|gemini|config|kube|git)(/|$)|env($|\\\\.))"))',
                '(deny file-read* (regex #"/(credentials|auth\\\\.json|[^/]*-host\\\\.json)$"))',
                "(deny network*)",
            ])
            path = self.cwd / ".api-sandbox.sb"
            path.write_text(profile, encoding="utf-8")
            return [shutil.which("sandbox-exec"), "-f", str(path), *argv]
        if sys.platform.startswith("linux") and shutil.which("bwrap"):
            command = [shutil.which("bwrap"), "--unshare-all", "--die-with-parent", "--new-session", "--proc", "/proc", "--dev", "/dev"]
            for path in dict.fromkeys((*runtime, *self.allowed)):
                command += ["--ro-bind", str(path), str(path)]
            command += ["--bind", str(self.cwd), str(self.cwd), "--chdir", str(self.cwd), "--", *argv]
            return command
        raise SandboxUnavailable("API drawing requires sandbox-exec on macOS or bubblewrap on Linux. Use an installed agent CLI for this drawing.")

    def command(self, argv, timeout):
        command = self._sandbox_command(argv)
        result = subprocess.run(command, cwd=self.cwd, env=self._environment(), text=True, capture_output=True,
                                timeout=max(1, min(timeout, 120)))
        if "sandbox_apply" in result.stderr or "Creating new namespace failed" in result.stderr:
            raise SandboxUnavailable("The operating system blocked the drawing sandbox. Choose a CLI host or enable a supported sandbox.")
        return result

    def probe(self):
        executable = shutil.which("true") or "/usr/bin/true"
        result = self.command([executable], 10)
        if result.returncode:
            raise SandboxUnavailable("The drawing sandbox could not start. Choose an installed CLI host.")


class ApiAgent:
    name = "api"
    label = "API"
    command = True

    def __init__(self, protocol, base_url, api_key, model):
        if protocol not in PROTOCOLS:
            raise ValueError("Choose OpenAI-compatible, Anthropic or Gemini API")
        if not isinstance(model, str) or not model.strip() or len(model) > 200:
            raise ValueError("Enter the API model name")
        parts = urlsplit(base_url.strip())
        if (parts.scheme not in ("https", "http") or not parts.hostname or parts.username or parts.password or
                parts.query or parts.fragment or (parts.scheme == "http" and parts.hostname not in ("localhost", "127.0.0.1", "::1"))):
            raise ValueError("Use an HTTPS API base URL, or HTTP for a local model")
        if not isinstance(api_key, str) or "\r" in api_key or "\n" in api_key:
            raise ValueError("Enter a valid API key")
        self.protocol, self.base_url, self.model = protocol, urlunsplit(parts).rstrip("/"), model.strip()
        self._key = api_key
        self._opener = build_opener(_NoRedirect())

    def _url(self):
        base = self.base_url
        if self.protocol == "openai":
            return base if base.endswith("/chat/completions") else base + ("/v1" if not urlsplit(base).path else "") + "/chat/completions"
        if self.protocol == "anthropic":
            return base if base.endswith("/messages") else base + ("/v1" if not urlsplit(base).path else "") + "/messages"
        if base.endswith(":generateContent"):
            return base
        version = "/v1beta" if not urlsplit(base).path else ""
        return base + version + "/models/" + quote(self.model.removeprefix("models/"), safe="-._") + ":generateContent"

    def _redact(self, text):
        # shortcut: short local-server placeholder keys are not secrets to scan
        # through ordinary words or source code; real provider keys are longer.
        return str(text).replace(self._key, "[redacted]") if len(self._key) >= 8 else str(text)

    def _contains_key(self, value):
        if len(self._key) < 8:
            return False
        if isinstance(value, str):
            return self._key in value
        if isinstance(value, dict):
            return any(self._contains_key(item) for item in value.values())
        if isinstance(value, list):
            return any(self._contains_key(item) for item in value)
        return False

    def _scrub(self, value):
        if isinstance(value, str):
            return self._redact(value)
        if isinstance(value, list):
            return [self._scrub(item) for item in value]
        if isinstance(value, dict):
            return {key: self._scrub(item) for key, item in value.items()}
        return value

    def _post(self, body, timeout):
        headers = {"Content-Type": "application/json"}
        if self.protocol == "anthropic":
            headers.update({"x-api-key": self._key, "anthropic-version": "2023-06-01"})
        elif self.protocol == "gemini":
            headers["x-goog-api-key"] = self._key
        elif self._key:
            headers["Authorization"] = "Bearer " + self._key
        request = Request(self._url(), data=json.dumps(body, ensure_ascii=False).encode("utf-8"), headers=headers, method="POST")
        try:
            with self._opener.open(request, timeout=max(1, min(timeout, 60))) as response:
                data = response.read(MAX_HTTP + 1)
            if len(data) > MAX_HTTP:
                raise RuntimeError("The API response exceeds the supported size")
            result = json.loads(data)
            if not isinstance(result, dict):
                raise ValueError("The API returned an invalid response")
            if result.get("error"):
                error = result["error"]
                raise RuntimeError(self._redact(error.get("message", "API request failed") if isinstance(error, dict) else error))
            return result
        except HTTPError as error:
            # Closing the body also prevents GC warnings from quoting a provider
            # reason that might contain credentials.
            status = error.code
            error.close()
            raise RuntimeError(f"API HTTP {status}. Check the endpoint, model, account and credentials.") from None
        except (URLError, TimeoutError, OSError):
            raise RuntimeError("Could not reach the configured API endpoint") from None
        except (UnicodeError, json.JSONDecodeError):
            raise RuntimeError("The API returned invalid JSON") from None

    def _initial(self, instructions, images):
        if self.protocol == "openai":
            content = [{"type": "text", "text": instructions}]
            for mime, data in images:
                content.append({"type": "image_url", "image_url": {"url": f"data:{mime};base64,{data}"}})
            return [{"role": "user", "content": content}]
        if self.protocol == "anthropic":
            content = [{"type": "text", "text": instructions}]
            content += [{"type": "image", "source": {"type": "base64", "media_type": mime, "data": data}} for mime, data in images]
            return [{"role": "user", "content": content}]
        parts = [{"text": instructions}] + [{"inlineData": {"mimeType": mime, "data": data}} for mime, data in images]
        return [{"role": "user", "parts": parts}]

    def _body(self, messages, tools):
        if self.protocol == "openai":
            return {"model": self.model, "messages": messages,
                    "tools": [{"type": "function", "function": tool} for tool in tools],
                    "response_format": {"type": "json_object"}}
        if self.protocol == "anthropic":
            return {"model": self.model, "max_tokens": 8192, "messages": messages,
                    "tools": [{"name": tool["name"], "description": tool["description"], "input_schema": tool["parameters"]} for tool in tools]}
        # Gemini 2.x cannot combine function tools with JSON MIME mode. The
        # schema in the prompt and local validation cover all supported models.
        return {"contents": messages, "tools": [{"functionDeclarations": tools}]}

    def _answer(self, response):
        if self.protocol == "openai":
            message = response["choices"][0]["message"]
            calls = [{"id": call["id"], "name": call["function"]["name"],
                      "arguments": _json(call["function"]["arguments"])} for call in message.get("tool_calls", [])]
            return message, calls, message.get("content") or ""
        if self.protocol == "anthropic":
            content = response["content"]
            calls = [{"id": part["id"], "name": part["name"], "arguments": part["input"]} for part in content if part.get("type") == "tool_use"]
            return {"role": "assistant", "content": content}, calls, "\n".join(part["text"] for part in content if part.get("type") == "text")
        content = response["candidates"][0]["content"]
        calls = [{"id": part["functionCall"].get("id"), "name": part["functionCall"]["name"], "arguments": part["functionCall"].get("args", {})}
                 for part in content["parts"] if "functionCall" in part]
        return content, calls, "\n".join(part["text"] for part in content["parts"] if "text" in part and not part.get("thought"))

    def _results(self, calls, results):
        if self.protocol == "openai":
            return [{"role": "tool", "tool_call_id": call["id"], "content": json.dumps(result, ensure_ascii=False)} for call, result in zip(calls, results)]
        if self.protocol == "anthropic":
            return [{"role": "user", "content": [{"type": "tool_result", "tool_use_id": call["id"], "content": json.dumps(result, ensure_ascii=False)}
                                                 for call, result in zip(calls, results)]}]
        return [{"role": "user", "parts": [{"functionResponse": {
            "name": call["name"], "response": result, **({"id": call["id"]} if call.get("id") else {})}}
            for call, result in zip(calls, results)]}]

    def _needs_input(self, message, schema):
        value = {"status": "needs_input", "message": message, "png": "", "pdf": "", "script": "", "checks": ""}
        _validate(value, schema)
        return value

    def run(self, prompt, schema, cwd, images=(), mode="ask", answer_path=None, timeout=600, read_dirs=()):
        if mode not in ("ask", "render"):
            raise ValueError("Unknown API agent operation")
        if len(images) > 12:
            raise ValueError("Attach at most twelve figure previews")
        tools = _Tools(cwd, images, read_dirs, mode)
        if mode == "render":
            try:
                tools.probe()
            except SandboxUnavailable as error:
                return self._needs_input(str(error), schema)
        attached = [_image_data(tools.path(str(path))) for path in images]
        instructions = prompt + "\nUse only these local tools. Preserve source files and data. Return final JSON matching:\n" + json.dumps(schema)
        messages = self._initial(instructions, attached)
        deadline = time.monotonic() + timeout
        for _ in range(32):
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("The API drawing request timed out")
            response = self._post(self._body(messages, tools.declarations()), remaining)
            try:
                message, calls, text = self._answer(response)
            except (KeyError, IndexError, TypeError):
                raise ValueError("The API response has no final answer or tool request") from None
            if not calls:
                result = _json(text)
                _validate(result, schema)
                if mode == "render" and result.get("status") == "completed":
                    output = tools.path(result["png"])
                    reviewed = tools.viewed.get(output)
                    if not tools.executed:
                        result = self._needs_input("The API did not execute a renderer. Retry with the source drawing script and inputs.", schema)
                    elif not reviewed or hashlib.sha256(output.read_bytes()).hexdigest() != reviewed:
                        result = self._needs_input("The API must inspect the current generated figure before returning it for review.", schema)
                if mode == "render" and result.get("status") == "completed" and len(self._key) >= 8:
                    sources = [path for path in tools.cwd.rglob("*") if path.is_file() and path.suffix.lower() in (".r", ".py")]
                    if result.get("checks"):
                        sources.append(tools.path(result["checks"]))
                    for source in sources:
                        if self._key.encode() in source.read_bytes():
                            raise ValueError("A generated source or checks file contains the configured API key")
                result = self._scrub(result)
                if answer_path:
                    destination = tools.path(str(answer_path), write=mode == "render")
                    if not destination.is_relative_to(tools.cwd):
                        raise ValueError("Keep the API answer in the current task")
                    _json_file(destination, result)
                return result
            messages.append(message)
            results = []
            current_images = []
            for call in calls:
                try:
                    # shortcut: short local-server placeholder keys are not
                    # scanned as file secrets, because common letters match code.
                    # A real provider key must be at least eight characters.
                    if self._contains_key(call["arguments"]):
                        raise ValueError("The API key cannot be written to files or command arguments")
                    result = tools.call(call["name"], call["arguments"], deadline - time.monotonic())
                    if "_view_image" in result:
                        current_images.append(_image_data(Path(result.pop("_view_image"))))
                        result = {"image_attached": True, "message": "Inspect the current image attached below."}
                    results.append(self._scrub(result))
                except SandboxUnavailable as error:
                    return self._needs_input(str(error), schema)
                except (ValueError, OSError, subprocess.TimeoutExpired) as error:
                    results.append({"error": self._redact(str(error))[:1000]})
            messages.extend(self._results(calls, results))
            if current_images:
                messages.extend(self._initial("Visually inspect these current figure pixels for labels, clipping, alignment and requested changes.", current_images))
        raise RuntimeError("The API reached the tool-step limit. Narrow the requested modification.")
