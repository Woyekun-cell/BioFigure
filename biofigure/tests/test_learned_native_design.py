import copy
import hashlib
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from retrieve_learned_methods import retrieve
from validate_design_spec import (validate_learned_source_reference,
    validate_source_panel_background, validate, load, SCHEMA)


class LearnedNativeDesignTests(unittest.TestCase):
    def setUp(self):
        self.entry = retrieve('', case_id='SCICASE-007')['results'][0]
        path = 'benchmark/library/scidraw/sources/06_half_violin_box_points_source.jpg'
        self.reference = {'selected_method_case_id': 'SCICASE-007',
            'learned_source_reference': {
                'method_id': 'SCICASE-007', 'source_record_sha256': self.entry['source_sha256'],
                'read_hashes': self.entry['current_read_hashes'],
                'opened_source_asset': {'path': path, 'sha256': self.entry['current_read_hashes'][path],
                                        'original_size_viewed': True}}}

    def test_bound_real_learned_source_can_supply_native_pattern(self):
        self.assertEqual(validate_learned_source_reference(self.reference, 'LEARNED-SCICASE-007'), ([], True))

    def test_other_method_cannot_borrow_a_source_binding(self):
        self.assertFalse(validate_learned_source_reference(self.reference, 'LEARNED-SCICASE-075')[1])

    def test_changed_material_or_unviewed_source_is_rejected(self):
        for mutate in ('hash', 'view'):
            reference = copy.deepcopy(self.reference)
            source = reference['learned_source_reference']
            if mutate == 'hash':
                source['read_hashes'][self.entry['source_record']] = '0' * 64
            else:
                source['opened_source_asset']['original_size_viewed'] = False
            self.assertFalse(validate_learned_source_reference(reference, 'LEARNED-SCICASE-007')[1])

    def test_source_asset_cannot_be_unrelated_or_a_code_file(self):
        reference = copy.deepcopy(self.reference)
        reference['learned_source_reference']['opened_source_asset']['path'] = self.entry['source_record']
        self.assertFalse(validate_learned_source_reference(reference, 'LEARNED-SCICASE-007')[1])

    def test_existing_patterns_do_not_gain_native_exception(self):
        self.assertEqual(validate_learned_source_reference({}, 'DIST-BOX-001'), ([], False))


class SourcePanelBackgroundTests(unittest.TestCase):
    def setUp(self):
        path = 'benchmark/library/scidraw/sources/ternary_03.png'
        sha256 = hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
        asset = {'path': path, 'sha256': sha256}
        self.doc = {
            'selected_pattern': 'LEARNED-SCICASE-071',
            'background_contract': {'canvas': '#FFFFFF', 'panel': '#EBEBEB', 'export': '#FFFFFF'},
            'source_panel_background_contract': {
                'color': '#EBEBEB', 'reason': 'Restore the source gray triangle and white fine grid.',
                'source_asset': copy.deepcopy(asset)},
            'reference_evidence': {'selected_method_case_id': 'SCICASE-071',
                'learned_source_reference': {'method_id': 'SCICASE-071',
                    'original_source_asset': dict(asset, original_size_viewed=True)}}}

    def test_current_viewed_original_accepts_source_gray(self):
        self.assertEqual(validate_source_panel_background(self.doc), [])
        errors = validate(self.doc, load(SCHEMA))
        self.assertFalse(any(e.startswith(('background_contract.panel', 'source_panel_background_contract')) for e in errors))

    def test_missing_contract_binding_or_reason_is_rejected(self):
        for missing in ('contract', 'original', 'source', 'reason'):
            with self.subTest(missing=missing):
                doc = copy.deepcopy(self.doc)
                if missing == 'contract':
                    del doc['source_panel_background_contract']
                elif missing == 'original':
                    del doc['reference_evidence']['learned_source_reference']['original_source_asset']
                elif missing == 'source':
                    del doc['source_panel_background_contract']['source_asset']
                else:
                    doc['source_panel_background_contract']['reason'] = '  '
                self.assertTrue(validate_source_panel_background(doc))

    def test_stale_hash_is_rejected_even_if_both_bindings_match(self):
        doc = copy.deepcopy(self.doc)
        doc['source_panel_background_contract']['source_asset']['sha256'] = '0' * 64
        doc['reference_evidence']['learned_source_reference']['original_source_asset']['sha256'] = '0' * 64
        self.assertIn('source_panel_background_contract.source_asset.sha256 differs from current source image', validate_source_panel_background(doc))

    def test_unrelated_asset_is_rejected_even_if_both_hashes_are_current(self):
        doc = copy.deepcopy(self.doc)
        path = 'benchmark/library/scidraw/evidence/comparison/02_ternary_cell_state.png'
        asset = {'path': path, 'sha256': hashlib.sha256((ROOT / path).read_bytes()).hexdigest()}
        doc['source_panel_background_contract']['source_asset'] = asset
        doc['reference_evidence']['learned_source_reference']['original_source_asset'] = dict(asset, original_size_viewed=True)
        self.assertTrue(validate_source_panel_background(doc))

    def test_different_asset_binding_or_unviewed_source_is_rejected(self):
        for mutate in ('hash', 'view', 'method'):
            with self.subTest(mutate=mutate):
                doc = copy.deepcopy(self.doc)
                binding = doc['reference_evidence']['learned_source_reference']
                if mutate == 'hash':
                    binding['original_source_asset']['sha256'] = '1' * 64
                elif mutate == 'view':
                    binding['original_source_asset']['original_size_viewed'] = False
                else:
                    binding['method_id'] = 'SCICASE-062'
                self.assertTrue(validate_source_panel_background(doc))

    def test_non_source_neutral_color_is_rejected(self):
        for color in ('#FF0000', '#EEEEEE', '#000000'):
            with self.subTest(color=color):
                doc = copy.deepcopy(self.doc)
                doc['background_contract']['panel'] = color
                doc['source_panel_background_contract']['color'] = color
                self.assertTrue(validate_source_panel_background(doc))

    def test_outside_or_missing_asset_is_rejected(self):
        for path in ('../00_全局控制台.md', 'benchmark/library/scidraw/sources/missing.png'):
            with self.subTest(path=path):
                doc = copy.deepcopy(self.doc)
                doc['source_panel_background_contract']['source_asset']['path'] = path
                self.assertTrue(validate_source_panel_background(doc))

    def test_canvas_and_export_are_still_white(self):
        for key in ('canvas', 'export'):
            with self.subTest(key=key):
                doc = copy.deepcopy(self.doc)
                doc['background_contract'][key] = '#EBEBEB'
                self.assertIn(f'background_contract.{key} must be #FFFFFF', validate(doc, load(SCHEMA)))

    def test_white_panel_still_requires_no_exception(self):
        self.assertEqual(validate_source_panel_background({'background_contract': {'panel': '#FFFFFF'}}), [])


if __name__ == '__main__':
    unittest.main()
