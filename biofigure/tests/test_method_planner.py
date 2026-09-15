import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load():
    path = ROOT / "scripts/plan_figure_method.py"
    spec = importlib.util.spec_from_file_location("planner", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class MethodPlannerTests(unittest.TestCase):
    def test_ternary_contract_prefers_verified_ggtern(self):
        plan = load().compile_plan("三元图 ggtern 分组组成")
        self.assertEqual(plan["subtype"], "ternary")
        self.assertFalse(plan["selected_case"]["high_fidelity_eligible"])
        self.assertIn("ggtern", plan["package_contract"]["candidates"])
        self.assertIn("composition_closure_check", plan["layer_contract"])

    def test_swimmer_contract_keeps_timeline_and_annotations(self):
        plan = load().compile_plan("临床泳道图")
        self.assertEqual(plan["subtype"], "swimmer")
        self.assertIn("swimplot", plan["package_contract"]["candidates"])
        self.assertIn("aligned_clinical_tracks", plan["layer_contract"])

    def test_short_ambiguous_request_does_not_pick_arbitrary_case(self):
        for query in ('画个图','基因组分布图'):
            plan=load().compile_plan(query)
            self.assertIsNone(plan['selected_case'])
            self.assertFalse(plan['ready_to_render'])

    def test_named_chart_still_requires_actual_data_validation(self):
        plan=load().compile_plan('森林图')
        self.assertFalse(plan['ready_to_render'])
        self.assertTrue(plan['missing'])

    def test_all_contracts_are_actionable(self):
        module = load()
        doc = module.yaml.safe_load((ROOT / "atlas/family-execution-contracts.yaml").read_text())
        self.assertEqual(len(doc["families"]), 15)
        self.assertGreaterEqual(len(doc["subtypes"]), 8)
        for contract in [*doc["families"].values(), *doc["subtypes"].values()]:
            self.assertTrue(contract["preferred_packages"])
            self.assertTrue(contract["mandatory_layers"])
            self.assertTrue(contract["failure_conditions"])


if __name__ == "__main__":
    unittest.main()
