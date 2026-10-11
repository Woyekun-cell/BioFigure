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
    def test_explicit_box_and_bar_with_primary_source_are_not_ambiguous(self):
        for query in ('bar plot of FOSCTTM by method with raw seed values',
                      'boxplot of Spearman coefficients by perturbation and method',
                      'boxplot of Spearman correlation by perturbation and method',
                      'bar plot of correlation coefficients by method',
                      'box plot of gene expression across groups'):
            plan = load().compile_plan(query, primary_source='https://www.nature.com/articles/s41587-022-01284-4/figures/2')
            self.assertEqual(plan['planning_status'], 'SOURCE_CANDIDATE')
            self.assertEqual(plan['families'][0], 'distribution')
            self.assertFalse(plan['ready_to_render'])

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

    def test_stacked_genomics_composition_keeps_requested_family_and_contract(self):
        query = (
            '100% stacked bar chart for Populus A/B chromatin compartments; '
            'ten species by four compartment-transition states and proportions'
        )
        plan = load().compile_plan(query)
        self.assertEqual(plan['planning_status'], 'METHOD_CANDIDATE')
        self.assertEqual(plan['families'][0], 'composition')
        self.assertNotIn('map', plan['families'])
        self.assertEqual(plan['subtype'], 'stacked-bar-composition')
        self.assertEqual(plan['data_contract'], ['group', 'category', 'value'])
        self.assertEqual(plan['package_contract']['candidates'][0], 'ggplot2')

    def test_authoritative_primary_source_preempts_unrelated_corpus_candidate(self):
        plan = load().compile_plan(
            '100% stacked bar chart for Populus A/B chromatin compartments',
            primary_source='https://www.nature.com/articles/s41559-026-03069-3/figures/2'
        )
        self.assertEqual(plan['planning_status'], 'SOURCE_CANDIDATE')
        self.assertEqual(plan['selected_case']['source'], 'primary-source')
        self.assertEqual(plan['selected_case']['reference'], 'https://www.nature.com/articles/s41559-026-03069-3/figures/2')
        self.assertFalse(plan['selected_case']['high_fidelity_eligible'])

    def test_closed_source_proportions_are_stacked_without_renormalizing(self):
        plan = load().compile_plan(
            '100% stacked bar chart using exact precomputed proportions from Supplementary Table 5'
        )
        self.assertIn('ggplot2::position_stack', plan['function_contract'])
        self.assertNotIn('ggplot2::position_fill', plan['function_contract'])
        self.assertEqual(plan['value_policy'], 'preserve-closed-proportions')
        self.assertIn('composition_closure_check', plan['layer_contract'])

    def test_umap_is_not_routed_to_geographic_map(self):
        plan = load().compile_plan('single-cell UMAP colored by chromatin class')
        self.assertIn('single-cell', plan['families'])
        self.assertNotIn('map', plan['families'])

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
