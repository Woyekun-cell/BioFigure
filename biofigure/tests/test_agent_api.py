import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from agent_api import ApiAgent, _NoRedirect, _Tools, SandboxUnavailable

ASK = {"type": "object", "properties": {"answer": {"type": "string"}, "actions": {"type": "array"}},
       "required": ["answer", "actions"], "additionalProperties": False}
RENDER = {"type": "object", "properties": {field: {"type": "string"} for field in ("status", "message", "png", "pdf", "script", "checks")},
          "required": ["status", "message", "png", "pdf", "script", "checks"], "additionalProperties": False}
ANSWER = {"answer": "Compare only the selected measurements.", "actions": []}


def response(protocol, text=None, tool=None):
    text = json.dumps(ANSWER if text is None else text)
    if protocol == "openai":
        message = {"role": "assistant", "content": text}
        if tool:
            message = {"role": "assistant", "content": None, "tool_calls": [
                {"id": "call-id", "type": "function", "function": {"name": tool[0], "arguments": json.dumps(tool[1])}}]}
        return {"choices": [{"message": message}]}
    if protocol == "anthropic":
        content = [{"type": "text", "text": text}]
        if tool:
            content = [{"type": "tool_use", "id": "call-id", "name": tool[0], "input": tool[1]}]
        return {"content": content}
    parts = [{"text": text}]
    if tool:
        parts = [{"functionCall": {"id": "native-id", "name": tool[0], "args": tool[1]}, "thoughtSignature": "keep-this"}]
    return {"candidates": [{"content": {"role": "model", "parts": parts}}]}


class ApiAgentTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)
        self.cwd = self.folder / "job"
        self.cwd.mkdir()
        self.image = self.cwd / "current.png"
        Image.new("RGB", (32, 32), "blue").save(self.image)
        self.source = self.folder / "source.csv"
        self.source.write_text("id,value\na,1\n")
        self.key = 'FAKE-KEY-"quoted\\value'

    def agent(self, protocol="openai", key=None):
        return ApiAgent(protocol, "https://api.example.test/" + ("v1beta" if protocol == "gemini" else "v1"), self.key if key is None else key, "custom-model")

    def test_all_three_protocols_use_native_request_shapes_and_parse_answers(self):
        for protocol in ("openai", "anthropic", "gemini"):
            agent = self.agent(protocol)
            with patch.object(agent, "_post", return_value=response(protocol)) as post:
                self.assertEqual(agent.run("Question", ASK, self.cwd, images=[self.image]), ANSWER)
            body = post.call_args.args[0]
            if protocol == "gemini":
                self.assertIn("inlineData", body["contents"][0]["parts"][1])
                self.assertNotIn("generationConfig", body)
            else:
                self.assertEqual(body["model"], "custom-model")
                image = body["messages"][0]["content"][1]
                self.assertEqual(image["type"], "image_url" if protocol == "openai" else "image")
            serialized = json.dumps(body)
            self.assertNotIn(self.key, serialized)

    def test_function_tools_and_current_image_pixels_are_returned_for_each_protocol(self):
        for protocol in ("openai", "anthropic", "gemini"):
            agent = self.agent(protocol)
            replies = [response(protocol, tool=("view_image", {"path": str(self.image)})), response(protocol)]
            with patch.object(agent, "_post", side_effect=replies) as post:
                self.assertEqual(agent.run("Review generated image", ASK, self.cwd), ANSWER)
            body = post.call_args.args[0]
            messages = body["contents"] if protocol == "gemini" else body["messages"]
            last = messages[-1]
            if protocol == "gemini":
                self.assertIn("inlineData", last["parts"][1])
                model = messages[-3]
                self.assertEqual(model["parts"][0]["thoughtSignature"], "keep-this")
                self.assertEqual(messages[-2]["parts"][0]["functionResponse"]["id"], "native-id")
            else:
                self.assertEqual(last["content"][1]["type"], "image_url" if protocol == "openai" else "image")
                self.assertEqual(messages[-2]["role"], "tool" if protocol == "openai" else "user")
            self.assertNotIn("_view_image", json.dumps(messages))

    def test_scoped_tools_reject_unrelated_files_credentials_and_readonly_writes(self):
        tools = _Tools(self.cwd, [], [self.source], "ask")
        self.assertEqual(tools.call("read_file", {"path": str(self.source)}, 5)["content"], self.source.read_text())
        outside = self.folder / "unselected.csv"
        outside.write_text("unselected")
        for path in (outside, Path.home() / ".ssh/id_rsa"):
            with self.assertRaises(ValueError):
                tools.call("read_file", {"path": str(path)}, 5)
            with self.assertRaises(ValueError):
                tools.call("view_image", {"path": str(path)}, 5)
        for name, arguments in (("write_file", {"path": "bad.R", "content": "x"}), ("run_command", {"argv": ["true"]})):
            with self.assertRaises(ValueError):
                tools.call(name, arguments, 5)

    def test_render_writes_only_inside_job_and_rejects_symlink_escape(self):
        tools = _Tools(self.cwd, [], [self.source], "render")
        result = tools.call("write_file", {"path": "render.R", "content": "plot(1)"}, 5)
        self.assertEqual(result["written"], "render.R")
        (self.cwd / "linked").symlink_to(self.folder, target_is_directory=True)
        for path in (str(self.source), "../outside.R", "linked/escape.R"):
            with self.assertRaises(ValueError):
                tools.call("write_file", {"path": path, "content": "bad"}, 5)
        self.assertEqual(self.source.read_text(), "id,value\na,1\n")

    def test_missing_os_sandbox_returns_needs_input_before_any_api_charge(self):
        agent = self.agent()
        with patch("agent_api.shutil.which", return_value=None), patch.object(agent, "_post") as post:
            result = agent.run("Render", RENDER, self.cwd, mode="render")
        self.assertEqual(result["status"], "needs_input")
        post.assert_not_called()

    def test_completed_render_requires_executed_command_and_current_visual_review(self):
        final = {"status": "completed", "message": "Done", "png": "current.png", "pdf": "figure.pdf", "script": "draw.R", "checks": "checks.json"}
        (self.cwd / "checks.json").write_text('{"passed":true}')
        (self.cwd / "draw.R").write_text('plot(1:3)')
        agent = self.agent()
        with patch("agent_api._Tools.probe"), patch.object(agent, "_post", return_value=response("openai", text=final)):
            self.assertEqual(agent.run("Render", RENDER, self.cwd, mode="render")["status"], "needs_input")
        replies = [response("openai", tool=("run_command", {"argv": ["Rscript", "draw.R"]})),
                   response("openai", tool=("view_image", {"path": "current.png"})), response("openai", text=final)]
        with patch("agent_api._Tools.probe"), patch("agent_api._Tools.command", return_value=subprocess.CompletedProcess([],0,"ok","")), patch.object(agent, "_post", side_effect=replies):
            self.assertEqual(agent.run("Render", RENDER, self.cwd, mode="render")["status"], "completed")

    def test_redirects_and_http_failures_do_not_forward_or_disclose_credentials(self):
        agent = self.agent()
        self.assertIsNone(_NoRedirect().redirect_request(None,None,302,"",{},"https://untrusted.example"))
        for code in (302, 401, 500):
            error = HTTPError(agent._url(), code, "contains " + self.key, {}, io.BytesIO(self.key.encode()))
            with patch.object(agent._opener, "open", side_effect=error) as request:
                with self.assertRaisesRegex(RuntimeError, f"HTTP {code}") as caught:
                    agent._post({}, 5)
                self.assertNotIn(self.key, str(caught.exception))
                self.assertEqual(request.call_count, 1)

    def test_keys_are_only_http_headers_and_never_logged(self):
        for protocol in ("openai", "anthropic", "gemini"):
            agent = self.agent(protocol)
            reply = io.BytesIO(json.dumps(response(protocol)).encode())
            with patch.object(agent._opener, "open", return_value=reply) as opened:
                agent._post({"model": "custom"}, 5)
            request = opened.call_args.args[0]
            self.assertNotIn(self.key, request.full_url)
            self.assertNotIn(self.key.encode(), request.data)
            expected = {"openai": "Authorization", "anthropic": "X-api-key", "gemini": "X-goog-api-key"}[protocol]
            self.assertEqual(request.get_header(expected), ("Bearer " if protocol == "openai" else "") + self.key)
            self.assertEqual(list(self.cwd.glob('*.log')), [])

    def test_key_redaction_preserves_schema_keys_and_escaped_values(self):
        for key in (self.key, "a"):
            agent = self.agent(key=key)
            result = {"answer": "Provider echoed " + key, "actions": []}
            with patch.object(agent, "_post", return_value=response("openai", text=result)):
                answer = agent.run("Question", ASK, self.cwd)
            self.assertEqual(set(answer), {"answer", "actions"})
            if len(key) >= 8:
                self.assertNotIn(key, answer["answer"])
            else:
                self.assertEqual(answer, result)

    def test_model_cannot_write_an_echoed_provider_key_into_source(self):
        agent = self.agent()
        replies = [response("openai", tool=("write_file", {"path": "leak.R", "content": "key='" + self.key + "'"})), response("openai")]
        with patch("agent_api._Tools.probe"), patch.object(agent, "_post", side_effect=replies):
            agent.run("Render", ASK, self.cwd, mode="render")
        self.assertFalse((self.cwd / "leak.R").exists())

    def test_base_urls_keep_custom_prefixes_and_never_embed_key(self):
        examples = [
            ("openai", "https://host.test", "https://host.test/v1/chat/completions"),
            ("openai", "https://host.test/custom/v1", "https://host.test/custom/v1/chat/completions"),
            ("anthropic", "https://host.test/v1/messages", "https://host.test/v1/messages"),
            ("gemini", "https://host.test/v1beta", "https://host.test/v1beta/models/model:generateContent"),
        ]
        for protocol, base, expected in examples:
            self.assertEqual(ApiAgent(protocol,base,"key","model")._url(),expected)
        for base in ("https://user:password@host.test/v1", "https://host.test/v1?key=secret", "http://remote.test/v1"):
            with self.assertRaises(ValueError):
                ApiAgent("openai",base,"key","model")
        self.assertEqual(ApiAgent("openai","http://127.0.0.1:9000/v1","","local-model")._url(),"http://127.0.0.1:9000/v1/chat/completions")

    def test_child_environment_does_not_inherit_api_keys_or_provider_logins(self):
        tools = _Tools(self.cwd, [], [], "render")
        with patch.dict(os.environ, {"OPENAI_API_KEY":self.key,"ANTHROPIC_API_KEY":self.key,"GEMINI_API_KEY":self.key,"CUSTOM_SECRET":self.key}):
            environment=tools._environment()
        self.assertNotIn(self.key, environment.values())
        self.assertEqual(environment["HOME"],str(self.cwd.resolve()))
        self.assertNotIn("OPENAI_API_KEY",environment)


if __name__ == "__main__":
    unittest.main()
