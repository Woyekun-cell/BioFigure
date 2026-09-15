import hashlib
import json
import struct
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


class SciDrawBatch2ReviewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.methods = json.loads((ROOT / "atlas/scidraw-batch2-methods.json").read_text())["cases"]
        cls.evidence = json.loads((ROOT / "atlas/scidraw-batch2-review-evidence.json").read_text())["cases"]

    def test_twenty_cases_are_source_compared(self):
        self.assertEqual(len(self.methods), 20)
        self.assertEqual({x["id"] for x in self.methods}, {x["case_id"] for x in self.evidence})
        for case in self.methods:
            expected = "source-compared-png" if case["review_status"] == "pass" else "source-compared-needs-revision"
            self.assertEqual(case["runtime_status"], expected)
            self.assertEqual(len(case["validated_pngs"]), 1)

    def test_artifact_hashes_and_dimensions(self):
        for case in self.evidence:
            artifact = case["implementation"]
            path = REPO / artifact["artifact"]
            self.assertTrue(path.is_file(), path)
            payload = path.read_bytes()
            self.assertEqual(hashlib.sha256(payload).hexdigest(), artifact["artifact_sha256"])
            self.assertEqual(payload[:8], b"\x89PNG\r\n\x1a\n")
            self.assertEqual(list(struct.unpack(">II", payload[16:24])), artifact["artifact_pixels"])
            self.assertIn(case["review_status"], {"pass", "needs-revision"})
            strict = case["strict_fidelity"]
            self.assertEqual(set(strict), {"family", "panel_topology", "required_structures", "typography", "annotation", "information_density"})
            if case["review_status"] == "pass":
                self.assertTrue(all(value == "pass" for value in strict.values()))

    def test_source_binding_is_auditable(self):
        for case in self.evidence:
            source = case["source"]
            self.assertRegex(source["url"], r"^https://mp\.weixin\.qq\.com/s/")
            self.assertGreater(source["code_files"], 0)
            for key in ("code_sha256", "image_sha256"):
                self.assertRegex(source[key], r"^[0-9a-f]{64}$")
            self.assertRegex(case["comparison_sha256"], r"^[0-9a-f]{64}$")

    def test_public_bundle_contains_only_independent_material(self):
        assets = list((REPO / "docs/assets/scidraw-gallery-batch2").glob("*.png"))
        self.assertEqual(len(assets), 20)
        example = ROOT / "examples/scidraw-gallery"
        forbidden = [
            path for path in example.rglob("*")
            if path.suffix.lower() in {".html", ".htm", ".jpg", ".jpeg", ".webp"}
        ]
        self.assertFalse(forbidden)
        self.assertTrue((example / "scripts/generate_batch20.R").is_file())

    def test_graph_nodes_match_batch2_evidence(self):
        graph = json.loads((ROOT / "atlas/unified-capability-graph.json").read_text())
        by_id = {node["id"]: node for node in graph["nodes"]}
        for case in self.methods:
            node = by_id[case["graph_node_id"]]
            self.assertEqual(node["visual_status"], case["runtime_status"])
            self.assertEqual(node["review_status"], case["review_status"])
            self.assertEqual(node["high_fidelity_eligible"], case["review_status"] == "pass")


if __name__ == "__main__":
    unittest.main()
