import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from PIL import Image

CLI = Path(__file__).resolve().parents[1] / "bin" / "biofigure"


class LocalCliTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.profile = self.root / "private" / "profile.sqlite"
        self.env = dict(os.environ, BIOFIGURE_PERSONAL_DB=str(self.profile))

    def call(self, *args, check=True):
        return subprocess.run([str(CLI), *args], cwd=self.root, env=self.env, text=True,
                              capture_output=True, check=check)

    def test_temporary_refs_and_reads_do_not_collect_or_create_a_profile(self):
        names = [f"图 {i}.png" for i in range(5)]
        for name in names:
            Image.new("RGB",(4,4)).save(self.root / name)
        self.assertEqual(json.loads(self.call("gallery", "list").stdout), [])
        brief = json.loads(self.call("gallery", "brief", "--family", "matrix", "留白", *names).stdout)
        self.assertEqual([Path(r["image"]).name for r in brief["selected"]], names)
        self.assertFalse(self.profile.exists())

    def test_save_star_select_and_error_status(self):
        Image.new("RGB",(4,4)).save(self.root / "example.png")
        key = self.call("gallery", "save", "example.png", "--family", "matrix").stdout.strip()
        self.call("gallery", "star", key, "--tag", "留白")
        selected = json.loads(self.call("gallery","brief","--family","matrix","用于新图",key).stdout)
        self.assertEqual(selected["selected"][0]["tags"], ["留白"])
        self.assertEqual(len(json.loads(self.call("gallery","list").stdout)), 1)
        self.assertNotEqual(self.call("bad-command",check=False).returncode, 0)
        self.assertNotEqual(self.call("gallery","get",check=False).returncode, 0)


if __name__ == "__main__":
    unittest.main()
