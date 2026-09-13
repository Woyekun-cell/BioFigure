import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("release_audit", ROOT / "scripts/audit_skill_release.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ReleaseAuditTests(unittest.TestCase):
    def test_release_contract(self):
        result = module.audit()
        self.assertEqual(result["status"], "PASS", result["errors"])
        self.assertLessEqual(result["hot_load"]["total_zh_chars"], 8000)
        self.assertTrue(all(x["zh_chars"] <= 1200 for x in result["hot_load"]["files"]))
        self.assertEqual(len(result["selected_public_gallery_pngs"]), 8)


if __name__ == "__main__":
    unittest.main()
