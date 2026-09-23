import importlib.util
import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


retrieval = load("awesome_retrieval", "scripts/retrieve_awesome_figures.py")
routing = load("awesome_routing", "scripts/route_figure.py")


class CandidateTests(unittest.TestCase):
    def test_catalog_never_claims_review_or_reproduction(self):
        catalog = json.loads((ROOT / "atlas/awesome-scientific-figure-candidates.json").read_text())
        self.assertEqual(len({e["candidate_family"] for e in catalog["candidates"]}), 3)
        self.assertEqual(len({e["id"] for e in catalog["candidates"]}), 3)
        for entry in catalog["candidates"]:
            self.assertFalse(entry["actual_figure_reviewed"])
            self.assertFalse(entry["original_article_checked"])
            self.assertEqual(entry["source_data_status"], "not-verified")
            self.assertEqual(entry["candidate_family_status"], "inferred-from-catalog")
            self.assertNotIn("validated_pngs", entry)
            self.assertNotIn("figure_asset_url", entry)

    def test_query_requires_domain_and_task_overlap(self):
        found = retrieval.retrieve("imaging-assay", "antibody comparison")
        self.assertEqual([e["id"] for e in found["candidate_references"]], ["ASF-JIN-2022-F2"])
        self.assertTrue(found["verified_reference_evidence_gap"])
        self.assertEqual(retrieval.retrieve("imaging-assay", "unrelated query")["candidate_references"], [])
        self.assertEqual(retrieval.retrieve("single-cell-spatial", "antibody comparison")["candidate_references"], [])
        with self.assertRaises(ValueError):
            retrieval.retrieve("imaging-assay", " ")

    def test_route_is_opt_in(self):
        request = {"primary_domain": "imaging-assay", "primary_role": "comparison", "backend": "R", "deliverable": "quick-png"}
        default = routing.route(request)
        self.assertNotIn("awesome_scientific_figure", default["reference_evidence_layers"])
        request["reference_sources"] = ["top_journal", "awesome_scientific_figure"]
        opted = routing.route(request)
        self.assertIn("references/awesome-scientific-figure-learning.md", opted["modules"])
        self.assertEqual(opted["reference_evidence_layers"]["awesome_scientific_figure"]["policy"], "optional_catalog_candidates_only_not_verified_evidence")


if __name__ == "__main__":
    unittest.main()
