import importlib.util
import unittest
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("release_audit", ROOT / "scripts/audit_skill_release.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ReleaseAuditTests(unittest.TestCase):
    def test_local_only_benchmark_evidence_is_not_scanned_as_public(self):
        self.assertFalse(any(path.startswith("biofigure/benchmark/evidence/") for path in module.machine_specific_references()))

    def test_release_contract(self):
        result = module.audit()
        self.assertEqual(result["status"], "PASS", result["errors"])
        self.assertEqual(result['check_scope'], 'public-package-portability-and-gallery')
        self.assertLessEqual(result["hot_load"]["total_zh_chars"], 8000)
        self.assertTrue(all(x["zh_chars"] <= 1200 for x in result["hot_load"]["files"]))
        catalog = json.loads((ROOT.parent/'docs/gallery/catalog.json').read_text())
        self.assertEqual(set(result['selected_public_gallery_pngs']), {x['image'] for x in catalog['figures']})
        # OncoPrint may remain explicitly blocked until its fresh native geometry
        # and output review pass; the other twelve public cases must stay runnable.
        manifest = json.loads((ROOT/'public-cases.json').read_text())
        statuses = {case['id']: case['status'] for case in manifest['cases']}
        self.assertEqual(len(statuses), 15)
        for case_id in ('dpm-bubbles', 'dpm-network'):
            self.assertEqual(statuses[case_id], 'reference-only')
        self.assertIn(statuses['oncoprint'], ('runnable', 'blocked'))
        self.assertTrue(all(status == 'runnable' for case_id, status in statuses.items()
                            if case_id not in ('dpm-bubbles', 'dpm-network', 'oncoprint')))
        expected = {'runnable': 12 + (statuses['oncoprint'] == 'runnable'), 'reference-only': 2}
        if statuses['oncoprint'] == 'blocked':
            expected['blocked'] = 1
        self.assertEqual(result['public_cases']['case_counts'], expected)
        self.assertEqual(result['learning_catalog']['indexed_records'], 454)
        self.assertFalse(result['scientific_or_visual_pass_inferred'])


if __name__ == "__main__":
    unittest.main()
