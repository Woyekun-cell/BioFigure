import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('footer_policy', ROOT/'scripts/figure_text_policy.py')
policy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(policy)


class FooterPolicyTests(unittest.TestCase):
    def test_screenshot_notes_are_not_canvas_labels(self):
        for label in (
            'n = 8 fish per group; infection day 12',
            'n = 8 fish per group',
            'n = 8; infection day 12',
            'FDR <= 0.05; VIP >= 1; FC >= 1.2 or <= 1/1.2',
            'FDR ≤ 0.05；VIP ≥ 1；FC ≥ 1.2',
            'VIP ≥ 1 and FC ≥ 1.2',
            '备注：每组8条鱼，感染后第12天',
            'Note: n = 8',
        ):
            with self.subTest(label=label):
                self.assertIsNotNone(policy.forbidden_figure_text_reason(label))

    def test_scientific_axes_legends_and_compact_statistics_survive(self):
        for label in ('-log10(FDR)','log2(F/NC)','FDR','VIP','Up','Down','Other',
                      'Liver','Muscle','n = 8','P = 0.01','q < 0.05','100 μm',
                      'Time after infection (days)','FDR < 0.05'):
            with self.subTest(label=label):
                self.assertIsNone(policy.forbidden_figure_text_reason(label))

    def test_heading_authorization_cannot_enable_footer(self):
        for contract in (
            {'allowed_text':['n = 8'], 'allow_headings':True,'allow_footer':True},
            {'allowed_text':['Liver'],'allow_headings':True,'caption':'n = 8'},
            {'allowed_text':['Liver'],'footer_policy':'allow'},
        ):
            self.assertTrue(policy.validate_footer_contract(contract))
        self.assertEqual(policy.validate_footer_contract({'allow_headings':True,'footer_policy':'outside-only'}),[])


if __name__=='__main__':
    unittest.main()
