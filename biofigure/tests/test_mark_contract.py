import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('mark_design_validator', ROOT / 'scripts/validate_design_spec.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class MarkContractTests(unittest.TestCase):
    def test_archived_specs_keep_original_scope(self):
        self.assertEqual(module.validate_mark_style_contract({}), [])

    def test_explicit_roles_and_opacity(self):
        contract = {'policy_id': 'layer-role-opacity-v1', 'layers': [
            {'layer': 1, 'role': 'replicate-point', 'fill_alpha': .7, 'edge_alpha': 1},
            {'layer': 2, 'role': 'summary-line', 'alpha': 1}]}
        self.assertEqual(module.validate_mark_style_contract({'mark_style_contract': contract}), [])

    def test_bad_roles_duplicate_layers_and_invalid_opacity(self):
        for layers in ([{'layer': 1, 'role': 'foo'}],
                       [{'layer': True, 'role': 'dense-point'}],
                       [{'layer': 1, 'role': 'dense-point', 'alpha': 1.5}],
                       [{'layer': 1, 'role': 'dense-point', 'alpha': float('nan')}],
                       [{'layer': 1, 'role': 'dense-point', 'alpha': True}],
                       [{'layer': 1, 'role': 'dense-point'}, {'layer': 1, 'role': 'summary-line'}]):
            with self.subTest(layers=layers):
                self.assertTrue(module.validate_mark_style_contract({'mark_style_contract': {
                    'policy_id': 'layer-role-opacity-v1', 'layers': layers}}))

    def test_empty_or_wrong_policy_is_rejected(self):
        for value in (None, {}, {'policy_id': 'any', 'layers': []}):
            self.assertTrue(module.validate_mark_style_contract({'mark_style_contract': value}))

    def test_misspelled_style_fields_are_rejected(self):
        self.assertTrue(module.validate_mark_style_contract({'mark_style_contract': {
            'policy_id': 'layer-role-opacity-v1', 'layers': [
                {'layer': 1, 'role': 'replicate-point', 'fill_opacity': .2}]}}))


if __name__ == '__main__':
    unittest.main()
