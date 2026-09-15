import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIMS = {"family", "panel_topology", "required_structures", "typography", "annotation", "information_density"}


class ReferenceFidelityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.requirements = json.loads((ROOT / "atlas/reference-fidelity-requirements.json").read_text())["cases"]
        cls.evidence = {}
        for name in ("scidraw-review-evidence.json", "scidraw-batch2-review-evidence.json"):
            for case in json.loads((ROOT / "atlas" / name).read_text())["cases"]:
                cls.evidence[case["case_id"]] = case

    def test_strict_pass_requires_every_dimension(self):
        self.assertEqual(len(self.requirements), 28)
        for req in self.requirements:
            fidelity = self.evidence[req["case_id"]]["strict_fidelity"]
            self.assertEqual(set(fidelity), DIMS)
            if req["strict_review_status"] == "pass":
                self.assertTrue(all(value == "pass" for value in fidelity.values()))
            else:
                self.assertTrue(req["mismatch_reasons"])
                self.assertIn("fail", fidelity.values())

    def test_known_structural_divergences_are_blocked(self):
        by_id = {x["case_id"]: x for x in self.requirements}
        for case_id in ("SCIDRAW-TERNARY-001", "SCIDRAW-CHORD-TRACK-001", "SCIDRAW-LINKET-NET-001"):
            self.assertEqual(by_id[case_id]["strict_review_status"], "needs-revision")


if __name__ == "__main__":
    unittest.main()
