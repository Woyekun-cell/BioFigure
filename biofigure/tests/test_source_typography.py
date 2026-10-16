import copy
import hashlib
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from validate_design_spec import validate, load, SCHEMA


class SourceTypographyTests(unittest.TestCase):
    def setUp(self):
        path = 'benchmark/library/scidraw/sources/06_half_violin_box_points_source.jpg'
        asset = {'path': path, 'sha256': hashlib.sha256((ROOT / path).read_bytes()).hexdigest()}
        roles = {'axis_text': 6.5, 'axis_title': 8, 'legend_text': 7,
                 'strip_text': 9, 'annotation_text': 7, 'panel_label': 18}
        self.doc = {
            'selected_pattern': 'LEARNED-SCICASE-007',
            'font_contract': {
                'family': 'Arial', 'resolved_font_file': 'runtime_systemfonts_path',
                'fallback_policy': 'fail', 'warning_policy': 'fail',
                'all_layers_inherit_policy': 'fail_if_any_layer_unverified',
                'rendered_face_check': 'actual_pdf_role_sizes_and_final_image',
                'minimum_final_text_pt': 6.5, 'size_basis': 'final_output_size',
                'size_roles_pt': roles},
            'source_typography_contract': {
                'source_asset': copy.deepcopy(asset), 'maximum_role_ratio': 2.8,
                'reason': 'Retain the viewed source panel-letter hierarchy with small scientific annotations.',
                'role_basis': {key: 'Source semantic role at final output size' for key in roles},
                'final_pdf_role_sizes_required': True},
            'reference_evidence': {
                'selected_method_case_id': 'SCICASE-007',
                'preparation_request': {'operation': 'reproduce'},
                'learned_source_reference': {
                    'method_id': 'SCICASE-007', 'read_hashes': {path: asset['sha256']},
                    'opened_source_asset': dict(asset, original_size_viewed=True)}}}

    def typography_errors(self, doc):
        return [e for e in validate(doc, load(SCHEMA))
                if e.startswith(('font_contract', 'source_typography_contract'))]

    def test_bound_source_hierarchy_is_preserved(self):
        self.assertEqual(self.typography_errors(self.doc), [])

    def test_default_ratio_remains_without_contract(self):
        del self.doc['source_typography_contract']
        self.assertIn('font_contract size hierarchy exceeds allowed final-size ratio',
                      self.typography_errors(self.doc))

    def test_exception_cannot_exceed_declared_ratio(self):
        self.doc['source_typography_contract']['maximum_role_ratio'] = 2.5
        self.assertTrue(self.typography_errors(self.doc))

    def test_source_exception_does_not_relax_minimum_text(self):
        self.doc['font_contract']['size_roles_pt']['annotation_text'] = 4
        self.assertTrue(any('below minimum_final_text_pt' in e for e in self.typography_errors(self.doc)))

    def test_additional_roles_cannot_hide_oversized_text(self):
        self.doc['font_contract']['size_roles_pt']['isomer_label'] = 100
        self.doc['source_typography_contract']['role_basis']['isomer_label'] = 'Large isomer label'
        self.assertTrue(self.typography_errors(self.doc))

    def test_additional_source_role_requires_its_own_basis(self):
        self.doc['font_contract']['size_roles_pt']['isomer_label'] = 11
        self.assertTrue(self.typography_errors(self.doc))

    def test_invalid_source_contracts_are_rejected(self):
        for change in ('unviewed', 'stale', 'operation', 'role', 'reason', 'method',
                       'pdf_check', 'code_asset', 'outside', 'nan_ratio', 'huge_ratio'):
            with self.subTest(change=change):
                doc = copy.deepcopy(self.doc)
                contract = doc['source_typography_contract']
                binding = doc['reference_evidence']['learned_source_reference']
                if change == 'unviewed':
                    binding['opened_source_asset']['original_size_viewed'] = False
                elif change == 'stale':
                    contract['source_asset']['sha256'] = '0' * 64
                    binding['opened_source_asset']['sha256'] = '0' * 64
                    binding['read_hashes'][contract['source_asset']['path']] = '0' * 64
                elif change == 'operation':
                    doc['reference_evidence']['preparation_request']['operation'] = 'draw'
                elif change == 'role':
                    del contract['role_basis']['panel_label']
                elif change == 'reason':
                    contract['reason'] = ' '
                elif change == 'method':
                    binding['method_id'] = 'SCICASE-075'
                elif change == 'pdf_check':
                    contract['final_pdf_role_sizes_required'] = False
                elif change in ('code_asset', 'outside'):
                    contract['source_asset']['path'] = 'scripts/validate_design_spec.py' if change == 'code_asset' else '../source.png'
                elif change == 'nan_ratio':
                    contract['maximum_role_ratio'] = float('nan')
                elif change == 'huge_ratio':
                    contract['maximum_role_ratio'] = 100
                self.assertTrue(self.typography_errors(doc))


if __name__ == '__main__':
    unittest.main()
