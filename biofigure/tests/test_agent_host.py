import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from agent_host import AgentHost, HOSTS, available_hosts

SCHEMA = {
    "type": "object", "properties": {
        "answer": {"type": "string"},
        "actions": {"type": "array", "items": {"type": "object", "properties": {
            "kind": {"type": "string", "enum": ["revision"]},
            "id": {"type": "string"}, "instruction": {"type": "string"}},
            "required": ["kind", "id", "instruction"], "additionalProperties": False}},
    }, "required": ["answer", "actions"], "additionalProperties": False,
}
ANSWER = {"answer": "Use the selected figure's original observations.", "actions": []}


class AgentHostTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)
        self.which = patch("agent_host.shutil.which", side_effect=lambda name: "/bin/" + Path(name).name)
        self.which.start()
        self.addCleanup(self.which.stop)

    def call(self, name, envelope=None, mode="ask", model=None, success=True):
        host = AgentHost(name, model=model)
        def run(command, **kwargs):
            self.command = command
            self.kwargs = kwargs
            if name == "codex" and success:
                Path(command[command.index("--output-last-message") + 1]).write_text(json.dumps(ANSWER))
            if name == "opencode":
                stdout = envelope or json.dumps({"type": "text", "part": {"type": "text", "text": json.dumps(ANSWER)}})
            else:
                stdout = json.dumps(envelope if envelope is not None else {"response": json.dumps(ANSWER)})
            return subprocess.CompletedProcess(command, 0 if success else 1, stdout, "" if success else "Sign in to continue")
        with patch("agent_host.subprocess.run", side_effect=run):
            return host.run("Preserve original data", SCHEMA, self.folder, mode=mode)

    def test_registry_detects_only_executables_without_login_or_desktop_launch(self):
        with patch("agent_host.shutil.which", side_effect=lambda cmd: "/bin/" + cmd if cmd in ("codex", "opencode") else None),patch("agent_host._workbuddy",return_value=None):
            hosts = available_hosts()
        self.assertEqual({item["id"] for item in hosts if item["installed"]}, {"codex", "opencode"})
        self.assertEqual(len(hosts), 5)
        self.assertEqual(HOSTS["codebuddy"]["command"], "codebuddy")
        with self.assertRaises(ValueError):
            AgentHost("workbuddy")

    def test_existing_workbuddy_bundle_runs_as_headless_node_without_installation(self):
        runtime,entry="/app/Electron","/app/app.asar/cli/bin/codebuddy"
        with patch("agent_host._workbuddy",return_value=(runtime,entry)),patch("agent_host.shutil.which",side_effect=lambda cmd:None if cmd=="codebuddy" else cmd):
            self.assertTrue(next(item for item in available_hosts() if item["id"]=="codebuddy")["installed"])
            for host in (AgentHost("codebuddy"),AgentHost("codebuddy",command=runtime)):
                def run(command,**kwargs):
                    self.assertEqual(command[:2],[runtime,entry])
                    self.assertEqual(kwargs["env"]["ELECTRON_RUN_AS_NODE"],"1")
                    self.assertEqual(kwargs["env"]["CODEBUDDY_FORCE_LITE_WB_BUNDLE"],"1")
                    return subprocess.CompletedProcess(command,0,json.dumps({"result":json.dumps(ANSWER)}),"")
                with patch("agent_host.subprocess.run",side_effect=run):
                    self.assertEqual(host.run("question",SCHEMA,self.folder),ANSWER)

    def test_codex_uses_native_defaults_and_explicit_sandbox(self):
        self.assertEqual(self.call("codex"), ANSWER)
        self.assertNotIn("--ignore-user-config", self.command)
        self.assertNotIn("-m", self.command)
        self.assertEqual(self.command[self.command.index("--sandbox") + 1], "read-only")
        self.assertNotIn("_", self.kwargs["env"])
        self.assertEqual(self.call("codex", mode="render", model="my-native-model"), ANSWER)
        self.assertEqual(self.command[self.command.index("--sandbox") + 1], "workspace-write")
        self.assertEqual(self.command[self.command.index("-m") + 1], "my-native-model")

    def test_claude_native_schema_and_output_envelopes(self):
        self.assertEqual(self.call("claude", {"structured_output": ANSWER}), ANSWER)
        self.assertIn("--json-schema", self.command)
        self.assertIn("--no-session-persistence", self.command)
        self.assertEqual(self.command[self.command.index("--tools") + 1], "Read,Glob,Grep")
        self.assertEqual(self.call("claude", {"result": "```json\n" + json.dumps(ANSWER) + "\n```"}, mode="render"), ANSWER)
        self.assertEqual(self.command[self.command.index("--permission-mode") + 1], "acceptEdits")
        self.assertIn("Bash", self.command[self.command.index("--allowedTools") + 1])
        self.assertFalse(any("dangerously" in arg for arg in self.command))

    def test_gemini_restricts_question_tools_and_parses_response(self):
        self.assertEqual(self.call("gemini", {"response": json.dumps(ANSWER), "stats": {}}), ANSWER)
        settings = json.loads((self.folder / ".gemini/settings.json").read_text())
        self.assertEqual(settings["tools"]["core"], ["read_file", "list_directory", "glob", "grep_search"])
        self.assertEqual(self.command[self.command.index("--approval-mode") + 1], "default")
        self.assertNotIn("--json-schema", self.command)
        self.assertIn("--allowed-mcp-server-names", self.command)
        self.assertEqual(self.call("gemini", mode="render"), ANSWER)
        self.assertEqual(self.command[self.command.index("--approval-mode") + 1], "auto_edit")
        with self.assertRaisesRegex(ValueError, "empty temporary"):
            self.call("gemini")

    def test_opencode_uses_final_text_and_ignores_tools_and_prior_messages(self):
        events = [
            {"type": "text", "part": {"messageID": "earlier", "type": "text", "text": "Planning notes"}},
            {"type": "tool_use", "part": {"text": json.dumps({"answer": "wrong", "actions": []})}},
            {"type": "reasoning", "part": {"text": "reasoning"}},
            {"type": "text", "part": {"messageID": "last", "id": "last-part", "type": "text", "text": "partial"}},
            {"type": "text", "part": {"messageID": "last", "id": "last-part", "type": "text", "text": json.dumps(ANSWER)}},
            {"type": "text", "part": {"synthetic": True, "text": "Continue?"}},
        ]
        self.assertEqual(self.call("opencode", "\n".join(map(json.dumps, events))), ANSWER)
        self.assertIn("--standalone", self.command)
        self.assertIn("--archived", self.command)
        self.assertNotIn("--auto", self.command)
        self.assertEqual(self.command[self.command.index("--agent") + 1], "plan")
        self.assertEqual(self.call("opencode", mode="render"), ANSWER)
        self.assertIn("--auto", self.command)
        self.assertEqual(self.command[self.command.index("--agent") + 1], "build")

    def test_codebuddy_uses_cli_json_and_preserves_model_default(self):
        self.assertEqual(self.call("codebuddy", {"result": json.dumps(ANSWER)}), ANSWER)
        self.assertEqual(self.command[0], "/bin/codebuddy")
        self.assertNotIn("--model", self.command)
        self.assertIn("--json-schema", self.command)
        self.assertNotIn("--dangerously-skip-permissions", self.command)
        self.assertEqual(self.call("codebuddy", mode="render", model="selected-model"), ANSWER)
        self.assertEqual(self.command[self.command.index("--model") + 1], "selected-model")

    def test_text_is_not_accepted_as_json_and_nested_schema_is_checked(self):
        for envelope in ({"response": "I changed it"}, {"response": '{"answer":1,"actions":[]}'},
                         {"response": '{"answer":"ok","actions":[{"kind":"unrecognized","id":"a","instruction":"x"}]}'},
                         {"response": '{"answer":"ok","actions":[],"extra":"false claim"}'}):
            with self.assertRaises((ValueError, json.JSONDecodeError)):
                self.call("codebuddy", envelope)

    def test_failure_and_auth_errors_are_reported_without_fallback(self):
        with self.assertRaisesRegex(RuntimeError, "Sign in"):
            self.call("codebuddy", success=False)
        with self.assertRaisesRegex(RuntimeError, "Authentication failed"):
            self.call("claude", {"is_error": True, "result": "Authentication failed"})
        with self.assertRaisesRegex(RuntimeError, "Quota exceeded"):
            self.call("opencode", json.dumps({"type": "error", "error": {"message": "Quota exceeded"}}))
        with patch("agent_host.shutil.which", return_value=None):
            with self.assertRaisesRegex(RuntimeError, "not installed"):
                AgentHost("claude").run("query", SCHEMA, self.folder)

    def test_images_are_native_attachments_or_explicit_readonly_paths(self):
        for name, flag in (("codex", "--image"), ("opencode", "--file"), ("claude", None)):
            host = AgentHost(name)
            def run(command, **kwargs):
                if flag:
                    self.assertEqual(command[command.index(flag) + 1], "/tmp/figure.png")
                else:
                    self.assertIn("/tmp/figure.png", kwargs["input"])
                    self.assertIn("--add-dir", command)
                    self.assertIn("mcp__*", command)
                if name == "codex":
                    Path(command[command.index("--output-last-message") + 1]).write_text(json.dumps(ANSWER))
                stdout = json.dumps({"response": json.dumps(ANSWER)})
                if name == "opencode":
                    stdout = json.dumps({"type": "text", "part": {"text": json.dumps(ANSWER)}})
                return subprocess.CompletedProcess(command, 0, stdout, "")
            with patch("agent_host.subprocess.run", side_effect=run):
                self.assertEqual(host.run("query", SCHEMA, self.folder, images=["/tmp/figure.png"]), ANSWER)

    def test_cli_directory_flags_accept_parents_of_scoped_source_files(self):
        source=self.folder/"source.csv"
        source.write_text("id,value\na,1\n")
        for name,flag in (("claude","--add-dir"),("codebuddy","--add-dir"),("gemini","--include-directories")):
            host=AgentHost(name)
            command=host._command(SCHEMA,self.folder,[],"ask",self.folder/"answer.json",[source])
            self.assertEqual(command[command.index(flag)+1],str(self.folder.resolve()))


if __name__ == "__main__":
    unittest.main()
