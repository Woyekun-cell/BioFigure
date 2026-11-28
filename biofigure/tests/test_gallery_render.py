import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch
import uuid

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from gallery_render import RenderJobs, codex_environment


class RenderJobTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)
        executable = patch("agent_host.shutil.which",side_effect=lambda name:"/mock/bin/"+Path(name).name)
        executable.start()
        self.addCleanup(executable.stop)
        self.site = self.folder / "site"
        (self.site / "assets").mkdir(parents=True)
        (self.site / "resources").mkdir()
        Image.new("RGB", (32, 32), "white").save(self.site / "assets/original.png")
        self.data = self.site / "resources/input.csv"
        self.data.write_text("id,value\na,1\nb,2\n")
        (self.site / "resources/draw.R").write_text("x <- read.csv('input.csv')\n")
        self.rows = {"figure": {"id": "figure", "chart": {"en": "Heatmap", "zh": "热图"},
                                "image": "assets/original.png", "thumbnail": "assets/original.png",
                                "resources": {"code": [{"name": "draw.R", "url": "resources/draw.R"}],
                                              "data": [{"name": "input.csv", "url": "resources/input.csv"}]}}}
        self.jobs = RenderJobs(self.site, self.folder / "outputs", "codex", "test-model")
        self.body = {"ids": ["figure"], "instruction": "Make the cells blue"}

    def wait(self, ident):
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            state = self.jobs.get(ident)
            if state["status"] != "running":
                return state
            time.sleep(0.01)
        self.fail("Worker did not finish")

    def render(self, command, **kwargs):
        folder = Path(command[command.index("-C") + 1])
        output = Path(command[command.index("--output-last-message") + 1])
        Image.new("RGB", (32, 32), "blue").save(folder / "figure.png")
        (folder / "figure.pdf").write_bytes(b"%PDF-1.4\n%%EOF\n")
        (folder / "draw.R").write_text("plot(1:2, col='blue')\n")
        (folder / "checks.json").write_text(json.dumps({
            "passed": True, "input_hashes": {"input.csv": hashlib.sha256(self.data.read_bytes()).hexdigest()}}))
        output.write_text(json.dumps({"status": "completed", "message": "Changed the cell color",
                                      "png": "figure.png", "pdf": "figure.pdf", "script": "draw.R", "checks": "checks.json"}))
        self.assertEqual(command[command.index("--sandbox") + 1], "workspace-write")
        self.assertIn("Never invent", kwargs["input"])
        self.assertNotIn("_", kwargs["env"])
        return subprocess.CompletedProcess(command, 0, "", "")

    def start_with(self, render=None):
        with patch("gallery_render.subprocess.run", side_effect=render or self.render):
            return self.wait(self.jobs.start(self.body, self.rows)["id"])

    def test_codex_environment_filters_non_unicode_shell_values(self):
        values = {"_": "shell command", "BIOFIGURE_TEST_VALID": "中文/path",
                  "BIOFIGURE_TEST_BAD_VALUE": "broken\udcff", "BIOFIGURE_TEST_BAD_KEY\udcfe": "value"}
        with patch.dict(os.environ, values, clear=False):
            environment = codex_environment()
        self.assertNotIn("_", environment)
        self.assertEqual(environment["BIOFIGURE_TEST_VALID"], "中文/path")
        self.assertNotIn("BIOFIGURE_TEST_BAD_VALUE", environment)
        self.assertNotIn("BIOFIGURE_TEST_BAD_KEY\udcfe", environment)
        for key, value in environment.items():
            key.encode("utf-8")
            value.encode("utf-8")

    def test_completed_artifacts_are_downloadable_and_survive_restart(self):
        state = self.start_with()
        self.assertEqual(state["status"], "completed", state)
        self.assertEqual(state["review_status"], "awaiting-review")
        self.assertEqual(len(state["files"]), 4)
        self.assertNotIn(str(self.folder), json.dumps(state))
        for artifact in state["files"]:
            self.assertTrue(self.jobs.file(state["id"], artifact["name"]).is_file())
        restarted = RenderJobs(self.site, self.jobs.root, "codex", "test-model")
        self.assertEqual(restarted.get(state["id"]), state)
        with self.assertRaises(ValueError):
            restarted.file(state["id"], "context.json")
        with self.assertRaises(ValueError):
            restarted.file(state["id"], "../../input.csv")

    def test_generated_helper_scripts_are_downloadable_with_the_renderer(self):
        def render_with_helper(command, **kwargs):
            result = self.render(command, **kwargs)
            folder = Path(command[command.index("-C") + 1])
            (folder / "helpers").mkdir()
            (folder / "helpers/palette.R").write_text("palette <- c('blue')\n")
            return result
        state = self.start_with(render_with_helper)
        self.assertEqual(state["status"], "completed", state)
        scripts = [item for item in state["files"] if item["kind"] == "script"]
        self.assertEqual({item["name"] for item in scripts}, {"draw.R", "helpers/palette.R"})
        self.assertEqual(self.jobs.file(state["id"], "helpers/palette.R").read_text(), "palette <- c('blue')\n")
        self.assertEqual(len(state["files"]), 5)

    def test_supplementary_source_symlinks_are_rejected(self):
        def render_with_symlink(command, **kwargs):
            result = self.render(command, **kwargs)
            folder = Path(command[command.index("-C") + 1])
            (folder / "borrowed.R").symlink_to(self.site / "resources/draw.R")
            return result
        state = self.start_with(render_with_symlink)
        self.assertEqual(state["status"], "failed", state)
        self.assertEqual(state["files"], [])

    def test_reject_foreign_ids_and_ambiguous_multi_selection(self):
        with self.assertRaises(ValueError):
            self.jobs.start({**self.body, "ids": ["foreign"]}, self.rows)
        rows = {**self.rows, "second": self.rows["figure"]}
        with self.assertRaisesRegex(ValueError, "which selected figure"):
            self.jobs.start({**self.body, "ids": ["figure", "second"]}, rows)
        with self.assertRaisesRegex(ValueError, "drawing script"):
            rows["figure"] = {**rows["figure"], "resources": {"code": [], "data": []}}
            self.jobs.start(self.body, rows)

    def test_reject_path_escape_and_symlink_artifacts(self):
        for attack in ("../outside.png", "linked.png"):
            def escaped(command, **kwargs):
                result = self.render(command, **kwargs)
                folder = Path(command[command.index("-C") + 1])
                response = folder / "response.json"
                data = json.loads(response.read_text())
                data["png"] = attack
                response.write_text(json.dumps(data))
                (folder / "linked.png").symlink_to(folder / "figure.png")
                return result
            state = self.start_with(escaped)
            self.assertEqual(state["status"], "failed", state)
            self.assertEqual(state["files"], [])

    def test_reject_invalid_or_unchanged_images_and_failed_checks(self):
        for fault in ("png", "unchanged", "checks", "input_hash", "duplicate"):
            def faulty(command, **kwargs):
                result = self.render(command, **kwargs)
                folder = Path(command[command.index("-C") + 1])
                if fault == "png":
                    (folder / "figure.png").write_bytes(b"not an image")
                if fault == "unchanged":
                    (folder / "figure.png").write_bytes((self.site / "assets/original.png").read_bytes())
                if fault == "checks":
                    (folder / "checks.json").write_text('{"passed":false}')
                if fault == "input_hash":
                    (folder / "checks.json").write_text('{"passed":true,"input_hashes":{"input.csv":"bad"}}')
                if fault == "duplicate":
                    response = json.loads((folder / "response.json").read_text())
                    response["checks"] = response["script"]
                    (folder / "response.json").write_text(json.dumps(response))
                return result
            state = self.start_with(faulty)
            self.assertEqual(state["status"], "failed", state)

    def test_worker_error_and_timeout_are_persisted_and_retryable(self):
        for failure in (subprocess.TimeoutExpired("codex", 600), RuntimeError("worker failed")):
            state = self.start_with(lambda *_args, **_kwargs: (_ for _ in ()).throw(failure))
            self.assertEqual(state["status"], "failed")
            self.assertFalse(self.jobs.lock.locked())
        self.assertEqual(self.start_with()["status"], "completed")

    def test_terminal_state_is_published_together_with_worker_release(self):
        import gallery_render
        save = gallery_render._write
        def slow_save(path, state):
            save(path, state)
            if path.name == "job.json" and state["status"] != "running":
                time.sleep(0.03)
        with patch("gallery_render._write", side_effect=slow_save):
            state = self.start_with()
            self.assertEqual(state["status"], "completed")
            self.assertFalse(self.jobs.lock.locked())
            self.assertIsNone(self.jobs.active)

    def test_failed_resource_paths_are_not_exposed_in_job_responses(self):
        error = RuntimeError("Cannot open /Users/test/project/private data.csv")
        state = self.start_with(lambda *_args, **_kwargs: (_ for _ in ()).throw(error))
        self.assertEqual(state["status"], "failed")
        self.assertNotIn("/Users/", state["message"])

    def test_one_render_runs_at_a_time(self):
        waiting, release = threading.Event(), threading.Event()
        def hold(command, **kwargs):
            waiting.set()
            self.assertTrue(release.wait(2))
            return self.render(command, **kwargs)
        with patch("gallery_render.subprocess.run", side_effect=hold):
            state = self.jobs.start(self.body, self.rows)
            self.assertTrue(waiting.wait(2))
            with self.assertRaisesRegex(RuntimeError, "being rendered"):
                self.jobs.start(self.body, self.rows)
            release.set()
            self.assertEqual(self.wait(state["id"])["status"], "completed")

    def test_continue_from_completed_revision_and_reject_unchanged_previous(self):
        prior = self.start_with()
        self.body["previous_job"] = prior["id"]
        continued = self.start_with()
        self.assertEqual(continued["status"], "failed", continued)
        self.assertIn("without any visible change", continued["message"])
        self.body["previous_job"] = str(uuid.uuid4())
        with self.assertRaises(ValueError):
            self.jobs.start(self.body, self.rows)

    def test_continuation_rejects_changed_original_inputs_and_scripts(self):
        prior = self.start_with()
        self.body["previous_job"] = prior["id"]
        for source in (self.data, self.site / "resources/draw.R"):
            original = source.read_bytes()
            source.write_bytes(original + b"changed source\n")
            try:
                with self.assertRaisesRegex(ValueError, "Start a new drawing task"):
                    self.jobs.start(self.body, self.rows)
                self.assertFalse(self.jobs.lock.locked())
            finally:
                source.write_bytes(original)

    def test_continuation_locks_reference_inputs_as_well_as_primary_inputs(self):
        reference = self.site / "resources/reference.csv"
        reference.write_text("id,value\na,5\n")
        self.rows["reference"] = {
            **self.rows["figure"],
            "resources": {"code": [], "data": [{"name": "reference.csv", "url": "resources/reference.csv"}]},
        }
        self.body.update(ids=["figure", "reference"], target_id="figure")
        prior = self.start_with()
        self.body["previous_job"] = prior["id"]
        reference.write_text("id,value\na,500\n")
        with self.assertRaisesRegex(ValueError, "Start a new drawing task"):
            self.jobs.start(self.body, self.rows)

    def test_download_and_continuation_verify_persisted_artifact_hashes(self):
        prior = self.start_with()
        for artifact in prior["files"]:
            path = self.jobs.file(prior["id"], artifact["name"])
            self.assertEqual(artifact["sha256"], hashlib.sha256(path.read_bytes()).hexdigest())
        renderer = self.jobs.root / prior["id"] / "draw.R"
        renderer.write_text("plot(999)\n")
        with self.assertRaisesRegex(ValueError, "changed after verification"):
            self.jobs.file(prior["id"], "draw.R")
        self.body["previous_job"] = prior["id"]
        with self.assertRaisesRegex(ValueError, "changed after verification"):
            self.jobs.start(self.body, self.rows)

    def test_source_scripts_cannot_change_during_rendering(self):
        def render_changed_source(command, **kwargs):
            result = self.render(command, **kwargs)
            (self.site / "resources/draw.R").write_text("plot(999)\n")
            return result
        state = self.start_with(render_changed_source)
        self.assertEqual(state["status"], "failed", state)
        self.assertIn("source changed during rendering", state["message"])

    def test_legacy_artifacts_remain_accessible_without_invented_hashes(self):
        prior = self.start_with()
        for artifact in prior["files"]:
            del artifact["sha256"]
        state_path = self.jobs.root / prior["id"] / "job.json"
        state_path.write_text(json.dumps(prior))
        self.assertTrue(self.jobs.file(prior["id"], "draw.R").is_file())
        self.assertTrue(all("sha256" not in item for item in self.jobs.get(prior["id"])["files"]))

    def test_abandoned_job_is_explicitly_failed_after_restart(self):
        ident = str(uuid.uuid4())
        folder = self.jobs.root / ident
        folder.mkdir(parents=True)
        (folder / "job.json").write_text(json.dumps({"id": ident, "status": "running", "files": []}))
        self.assertEqual(self.jobs.get(ident)["status"], "failed")
        self.assertEqual(json.loads((folder / "job.json").read_text())["status"], "failed")

    def test_missing_inputs_and_external_sources_are_not_silently_substituted(self):
        self.rows["figure"]["resources"]["data"][0]["url"] = "https://example.com/private.csv"
        with self.assertRaisesRegex(ValueError, "plotting data"):
            self.jobs.start(self.body, self.rows)
        self.rows["figure"]["resources"]["data"][0]["url"] = "resources/missing.csv"
        with self.assertRaisesRegex(ValueError, "missing local resource"):
            self.jobs.start(self.body, self.rows)


if __name__ == "__main__":
    unittest.main()
