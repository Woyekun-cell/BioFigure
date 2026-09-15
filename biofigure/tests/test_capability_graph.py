import importlib.util
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load():
    path = ROOT / "scripts/retrieve_capabilities.py"
    spec = importlib.util.spec_from_file_location("capability_retriever", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class CapabilityGraphTests(unittest.TestCase):
    def test_graph_counts_and_status_boundary(self):
        graph = json.loads((ROOT / "atlas/unified-capability-graph.json").read_text())
        reproduction = json.loads((ROOT / "atlas/reproduction-methods.json").read_text())["cases"]
        scidraw = json.loads((ROOT / "atlas/scidraw-source-compared-methods.json").read_text())["cases"]
        scidraw_batch2 = json.loads((ROOT / "atlas/scidraw-batch2-methods.json").read_text())["cases"]
        expected = sum(
            case.get("runtime_status") == "source-compared-png" and case.get("review_status") == "pass"
            for case in reproduction + scidraw + scidraw_batch2
        )
        self.assertEqual(graph["summary"]["case_count"], 231)
        self.assertEqual(graph["summary"]["source_compared_pass"], expected)
        self.assertIn("only review_status=pass", graph["summary"]["status_boundary"])

    def test_retrieval_never_promotes_incomplete_case(self):
        out = load().retrieve("三元 ggtern", 20)
        self.assertTrue(out["results"])
        for item in out["results"]:
            if item["high_fidelity_eligible"]:
                self.assertEqual(item["visual_status"], "source-compared-png")
                self.assertEqual(item["review_status"], "pass")

    def test_each_topjournal_node_matches_atlas_evidence(self):
        graph = json.loads((ROOT / "atlas/unified-capability-graph.json").read_text())
        methods = json.loads((ROOT / "atlas/reproduction-methods.json").read_text())["cases"]
        by_issue = {item["issue"]: item for item in methods}
        checked = 0
        for node in graph["nodes"]:
            match = re.fullmatch(r"topfigure-(\d+)-[0-9a-f]+", node.get("id", ""))
            if not match:
                continue
            method = by_issue[int(match.group(1))]
            eligible = method.get("runtime_status") == "source-compared-png" and method.get("review_status") == "pass"
            self.assertEqual(node.get("visual_status"), method.get("runtime_status", "not-run"))
            self.assertEqual(node.get("review_status"), method.get("review_status", "missing"))
            self.assertEqual(bool(node.get("high_fidelity_eligible")), eligible)
            checked += 1
        self.assertEqual(checked, len(methods))


if __name__ == "__main__":
    unittest.main()
