"""Use an installed agent CLI with its own authentication and provider settings."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

# Native command references, checked 2026-11-28.
# https://code.claude.com/docs/en/cli-reference
# https://geminicli.com/docs/cli/cli-reference/
# https://opencode.ai/docs/cli/ and installed OpenCode 2.4.2 `run --help`
# https://www.codebuddy.ai/docs/cli/cli-reference
HOSTS = {
    "codex": {"label": "Codex", "command": "codex"},
    "claude": {"label": "Claude Code", "command": "claude"},
    "gemini": {"label": "Gemini CLI", "command": "gemini"},
    "opencode": {"label": "OpenCode", "command": "opencode"},
    "codebuddy": {"label": "CodeBuddy / WorkBuddy CLI", "command": "codebuddy"},
}


def _workbuddy():
    app = Path("/Applications/WorkBuddy AI.app/Contents")
    runtime = app/"MacOS/Electron"
    unpacked = app/"Resources/app.asar.unpacked/cli"
    if runtime.is_file() and (unpacked/"bin/codebuddy").is_file() and (unpacked/"dist/codebuddy-lite-wb.mjs").is_file():
        return str(runtime),str(app/"Resources/app.asar/cli/bin/codebuddy")
    return None


def _installed(name):
    command = shutil.which(HOSTS[name]["command"])
    bundled = _workbuddy() if name == "codebuddy" and not command else None
    return command or (bundled[0] if bundled else None)


def available_hosts():
    return [{"id": name, "label": spec["label"], "installed": bool(_installed(name))}
            for name, spec in HOSTS.items()]


def codex_environment():
    # Rust env::vars() rejects surrogate-escaped shell variables.
    environment = {}
    for key, value in os.environ.items():
        if key == "_":
            continue
        try:
            key.encode("utf-8")
            value.encode("utf-8")
        except UnicodeEncodeError:
            continue
        environment[key] = value
    return environment


def _json(value):
    if isinstance(value, str):
        text = value.strip()
        fenced = re.fullmatch(r"```(?:json)?\s*\n(.*?)\n```", text, flags=re.DOTALL)
        return json.loads(fenced.group(1) if fenced else text)
    return value


def _validate(value, schema, field="$"):
    expected = schema.get("type")
    types = {"object": dict, "array": list, "string": str, "boolean": bool,
             "integer": int, "number": (int, float), "null": type(None)}
    if expected and (not isinstance(value, types[expected]) or
                     (expected in ("integer", "number") and isinstance(value, bool))):
        raise ValueError(f"Agent returned the wrong output type at {field}")
    if "enum" in schema and value not in schema["enum"]:
        raise ValueError(f"Agent returned an unsupported value at {field}")
    if isinstance(value, dict):
        properties = schema.get("properties", {})
        if any(key not in value for key in schema.get("required", [])):
            raise ValueError(f"Agent omitted required output fields at {field}")
        if schema.get("additionalProperties") is False and set(value) - properties.keys():
            raise ValueError(f"Agent returned unexpected output fields at {field}")
        for key, item in value.items():
            if key in properties:
                _validate(item, properties[key], f"{field}.{key}")
    if isinstance(value, list) and "items" in schema:
        for index, item in enumerate(value):
            _validate(item, schema["items"], f"{field}[{index}]")


def _error(value):
    if not isinstance(value, dict):
        return str(value)
    error = value.get("error") or value.get("errors") or value.get("result") or value.get("message")
    if isinstance(error, dict):
        return str(error.get("message") or error.get("type") or "Agent request failed")
    return str(error or "Agent request failed")


def _events(text):
    """Use only the final assistant text, excluding tools and internal reasoning."""
    parts = {}
    order = []
    for line in text.splitlines():
        if not line.strip():
            continue
        event = json.loads(line)
        if not isinstance(event, dict):
            raise ValueError("OpenCode returned an invalid event")
        if event.get("type") == "error":
            raise RuntimeError(_error(event))
        part = event.get("part", {})
        metadata = part.get("metadata") or {}
        if (event.get("type") != "text" or part.get("type", "text") != "text" or
                part.get("synthetic") or metadata.get("compaction_continue") or
                part.get("role") == "user" or part.get("summary") or
                part.get("agent") == "compaction"):
            continue
        message = part.get("messageID") or event.get("messageID") or str(len(order))
        if message not in parts:
            parts[message] = {}
            order.append(message)
        key = part.get("id") or str(len(parts[message]))
        parts[message][key] = part.get("text", "")
    if not order:
        raise ValueError("OpenCode did not return a final assistant answer")
    return _json("\n".join(parts[order[-1]].values()))


class AgentHost:
    def __init__(self, name, model=None, command=None):
        if name not in HOSTS:
            raise ValueError("Choose an installed agent CLI")
        if model is not None and (not isinstance(model, str) or len(model) > 200):
            raise ValueError("Invalid agent model")
        self.name = name
        self.label = HOSTS[name]["label"]
        self.model = model.strip() if model else None
        self.command = shutil.which(command) if command else _installed(name)
        bundled = _workbuddy() if name == "codebuddy" else None
        self._bundled_script = bundled[1] if bundled and self.command == bundled[0] else None

    def _command(self, schema, cwd, images, mode, answer, read_dirs):
        if not self.command:
            raise RuntimeError(f"{self.label} CLI is not installed or is not on PATH")
        if mode not in ("ask", "render"):
            raise ValueError("Unknown agent operation")
        roots = (Path(value).resolve() for value in read_dirs)
        directories = {str(path if path.is_dir() else path.parent) for path in roots}
        directories.update(str(Path(image).resolve().parent) for image in images)
        if self.name == "codex":
            schema_path = cwd / "response-schema.json"
            schema_path.write_text(json.dumps(schema), encoding="utf-8")
            command = [self.command, "-a", "never", "exec", "--sandbox",
                       "read-only" if mode == "ask" else "workspace-write", "--ephemeral",
                       "--skip-git-repo-check", "--color", "never", "-C", str(cwd),
                       "--output-schema", str(schema_path), "--output-last-message", str(answer)]
            if self.model:
                command.extend(["-m", self.model])
            for image in images:
                command.extend(["--image", str(image)])
            return command + ["-"]
        if self.name == "opencode":
            command = [self.command, "--standalone", "run", "--format", "json", "--archived",
                       "--agent", "plan" if mode == "ask" else "build"]
            if mode == "render":
                # OpenCode documents --auto as preserving explicit permission denies.
                command.append("--auto")
            if self.model:
                command.extend(["--model", self.model])
            for image in images:
                command.extend(["--file", str(image)])
            return command
        if self.name == "gemini":
            if mode == "ask":
                # Gemini's headless plan mode can exit into automatic execution.
                # Limit the temporary task to native read tools instead.
                settings = cwd / ".gemini/settings.json"
                if settings.exists():
                    raise ValueError("Use an empty temporary task directory for Gemini questions")
                settings.parent.mkdir(exist_ok=True)
                settings.write_text(json.dumps({"tools": {"core": ["read_file", "list_directory", "glob", "grep_search"]}}), encoding="utf-8")
            command = [self.command, "-p", "Follow the request on stdin.", "--output-format", "json",
                       "--approval-mode", "default" if mode == "ask" else "auto_edit"]
            if mode == "ask":
                command.extend(["--allowed-mcp-server-names", "__biofigure_readonly_no_servers__"])
                for directory in sorted(directories):
                    command.extend(["--include-directories", directory])
        else:
            command = [self.command, "-p", "--output-format", "json", "--permission-mode",
                       "plan" if mode == "ask" else "acceptEdits"]
            command.extend(["--json-schema", json.dumps(schema), "--tools",
                            "Read,Glob,Grep" if mode == "ask" else "Read,Glob,Grep,Edit,Write,Bash"])
            if self.name == "claude":
                command.append("--no-session-persistence")
            if mode == "ask":
                command.extend(["--disallowedTools", "mcp__*"])
                for directory in sorted(directories):
                    command.extend(["--add-dir", directory])
            if mode == "render":
                command.extend(["--allowedTools", "Read,Glob,Grep,Edit,Write,Bash"])
        if self.model:
            command.extend(["--model", self.model])
        if self._bundled_script:
            command.insert(1,self._bundled_script)
        return command

    def _response(self, result, answer):
        if self.name == "codex":
            if not answer.is_file():
                raise ValueError("Codex did not write its structured answer")
            return _json(answer.read_text(encoding="utf-8"))
        if self.name == "opencode":
            return _events(result.stdout)
        envelope = _json(result.stdout)
        if not isinstance(envelope, dict):
            raise ValueError(f"{self.label} returned an invalid JSON envelope")
        if envelope.get("is_error") or envelope.get("error"):
            raise RuntimeError(_error(envelope))
        for key in ("structured_output", "response", "result"):
            if key in envelope:
                return _json(envelope[key])
        raise ValueError(f"{self.label} did not return a final structured answer")

    def run(self, prompt, schema, cwd, images=(), mode="ask", answer_path=None, timeout=600, read_dirs=()):
        cwd = Path(cwd).resolve()
        answer = Path(answer_path).resolve() if answer_path else cwd / "response.json"
        if not answer.is_relative_to(cwd):
            raise ValueError("Keep the agent answer in its task output directory")
        command = self._command(schema, cwd, images, mode, answer, read_dirs)
        instructions = prompt + "\nReturn only a JSON object conforming to this schema:\n" + json.dumps(schema)
        if images and self.name not in ("codex", "opencode"):
            instructions += "\nUse your read-only image/file tool for these figure previews:\n" + "\n".join(map(str, images))
        environment = codex_environment()
        if self._bundled_script:
            environment.update(ELECTRON_RUN_AS_NODE="1",CODEBUDDY_FORCE_LITE_WB_BUNDLE="1",CODEBUDDY_DISABLE_COMPILE_CACHE="1")
        result = subprocess.run(command, cwd=cwd, text=True, input=instructions, capture_output=True,
                                timeout=timeout, env=environment)
        (cwd / ("codex.log" if self.name == "codex" else "host.log")).write_text(result.stderr, encoding="utf-8")
        if result.returncode:
            detail = re.sub(r"\x1b\[[0-9;]*m", "", result.stderr or result.stdout).strip()[-800:]
            raise RuntimeError(f"{self.label} exited with status {result.returncode}: {detail or 'No diagnostic was returned'}")
        value = self._response(result, answer)
        _validate(value, schema)
        answer.write_text(json.dumps(value, ensure_ascii=False), encoding="utf-8")
        return value
