import hashlib
import json
import re
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


class SciDrawReviewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.methods = json.loads((ROOT / "atlas/scidraw-source-compared-methods.json").read_text())
        cls.evidence = json.loads((ROOT / "atlas/scidraw-review-evidence.json").read_text())

    def test_case_sets_and_review_status(self):
        self.assertEqual(
            {case["id"] for case in self.methods["cases"]},
            {case["case_id"] for case in self.evidence["cases"]},
        )
        self.assertEqual(len(self.methods["cases"]), 8)
        for case in self.methods["cases"]:
            expected = "source-compared-png" if case["review_status"] == "pass" else "source-compared-needs-revision"
            self.assertEqual(case["runtime_status"], expected)

    def test_artifacts_and_hashes(self):
        for case in self.evidence["cases"]:
            artifact = case["implementation"]
            path = REPO / artifact["artifact_path"]
            self.assertTrue(path.is_file(), path)
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), artifact["artifact_sha256"])
            header = path.read_bytes()[:24]
            self.assertEqual(list(struct.unpack(">II", header[16:24])), artifact["artifact_pixels"])
            self.assertIn(case["review_status"], {"pass", "needs-revision"})
            for key in ("image_sha256", "html_sha256", "code_blocks_sha256"):
                self.assertRegex(case["source"][key], r"^[0-9a-f]{64}$")

    def test_public_gallery_excludes_source_material(self):
        pngs = list((REPO / "docs/assets/scidraw-gallery").glob("*.png"))
        self.assertEqual(len(pngs), 8)
        public_example = ROOT / "examples/scidraw-gallery"
        forbidden = [p for p in public_example.rglob("*") if p.suffix.lower() in {".html", ".htm"}]
        self.assertFalse(forbidden)
        self.assertIn("不包含公众号原始图片", (public_example / "README.md").read_text())

    def test_source_identifiers_are_auditable(self):
        for case in self.evidence["cases"]:
            self.assertRegex(case["source"]["url"], r"^https://mp\.weixin\.qq\.com/s/")
            self.assertGreater(case["source"]["code_blocks"], 0)


if __name__ == "__main__":
    unittest.main()
