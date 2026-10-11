import importlib.util
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
spec = importlib.util.spec_from_file_location("design_spec_validator", ROOT / "scripts/validate_design_spec.py")
design_validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(design_validator)


class PrimarySourceDesignReferenceTests(unittest.TestCase):
    def make_lock(self, root):
        files = []
        for role, name in (("figure_asset", "figure.png"), ("author_code", "author.R"), ("source_data", "source.xlsx")):
            path = root / name
            path.write_bytes(role.encode())
            files.append({"role": role, "path": name,
                          "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
        source = {"title": "Populus genome evolution", "doi": "10.1038/s41559-026-03069-3",
                  "url": "https://www.nature.com/articles/s41559-026-03069-3/figures/2",
                  "figure": "2", "panel": "b"}
        lock = {"schema_version": 1, "kind": "primary-source-lock", "query": "stacked composition",
                "project_root": str(root.resolve()), "primary_source": source, "source_files": files,
                "source_mapping": [{"panel": "2b", "author_code": "author_code", "source_data": "source_data"}],
                "inspection": {"original_figure_opened": True},
                "generation_contract": {"author_material_access": "authorized-inspection-no-copy",
                    "implementation": "new-script-from-user-data-and-derived-patterns", "blind_generation": False}}
        path = root / "source-lock.json"
        path.write_text(json.dumps(lock))
        return path, source

    def test_valid_primary_source_lock_allows_no_unrelated_atlas_ids(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path, source = self.make_lock(root)
            errors, has_lock = design_validator.validate_primary_source_reference(
                {"primary_source_lock": str(path), "primary_source": source}, root
            )
            self.assertEqual(errors, [])
            self.assertTrue(has_lock)

    def test_modified_source_reference_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path, source = self.make_lock(root)
            source["panel"] = "c"
            errors, has_lock = design_validator.validate_primary_source_reference(
                {"primary_source_lock": str(path), "primary_source": source}, root
            )
            self.assertFalse(has_lock)
            self.assertTrue(any("primary source metadata" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
