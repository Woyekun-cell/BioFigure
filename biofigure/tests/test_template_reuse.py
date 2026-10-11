import copy
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import prepare_figure
import yaml


class TemplateReuseTests(unittest.TestCase):
    def request(self, issue=97):
        return yaml.safe_load((ROOT / f'benchmark/library/topjournal/issue_{issue:03d}/data/metadata/request.yaml').read_text())

    def test_entry_returns_locked_template_in_fresh_context(self):
        result = prepare_figure.prepare(self.request())
        self.assertEqual(result['reusable_templates']['candidates'][0]['issue'], 97)
        self.assertIn('atlas/reusable-template-index.json', result['source_hashes'])

    def test_unrelated_task_does_not_inherit_tree_quality(self):
        result = prepare_figure.prepare(dict(self.request(), figure_task='chromosome gene density', figure_family='genome', primary_source=None, data_shape='position count'))
        self.assertEqual(result['reusable_templates']['candidates'], [])

    def test_exact_source_cannot_silently_skip_replay(self):
        from reuse_templates import validate_binding
        result = prepare_figure.prepare(self.request())
        self.assertTrue(validate_binding(result, {'reference_evidence': {}}))
        skipped = {'reference_evidence': {'template_reuse': {'decision': 'not_applicable', 'reason': 'new data', 'data_contract_difference': 'none'}}}
        self.assertTrue(validate_binding(result, skipped))

    def test_fixture_mode_cannot_authorize_changed_visual_spec(self):
        from reuse_templates import validate_binding
        result = prepare_figure.prepare(self.request(), fixture_replay_case_id='topfigure-097-19dfbfef')
        original = yaml.safe_load((ROOT / 'benchmark/library/topjournal/issue_097/data/metadata/design-spec.yaml').read_text())
        self.assertEqual(validate_binding(result, original), [])
        changed = copy.deepcopy(original)
        changed['output_size']['width_mm'] += 1
        self.assertTrue(validate_binding(result, changed))

    def test_generic_tree_does_not_select_specific_track_template(self):
        result = prepare_figure.prepare(dict(self.request(), primary_source=None, figure_task='phylogenetic tree', data_shape='Newick tips'))
        self.assertEqual(result['reusable_templates']['candidates'], [])

    def test_each_invocation_requires_its_own_replay(self):
        first = prepare_figure.prepare(self.request())
        second = prepare_figure.prepare(self.request())
        self.assertNotEqual(first['preparation_id'], second['preparation_id'])
        self.assertEqual(first['request_id'], second['request_id'])
        self.assertEqual(first['planning_id'], second['planning_id'])

    def test_cp2_does_not_accept_removed_reuse_contract(self):
        import tempfile
        import hashlib
        import validate_checkpoints
        receipt = prepare_figure.prepare(self.request())
        receipt.pop('reusable_templates')
        receipt.pop('preparation_id')
        receipt['preparation_id'] = hashlib.sha256(json.dumps(receipt, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'receipt.json'
            path.write_text(json.dumps(receipt))
            errors = validate_checkpoints.validate_preparation_receipt(str(path), {})
        self.assertTrue(any('reusable template contract missing' in e for e in errors))

    def test_declared_pass_without_render_evidence_is_rejected(self):
        import tempfile
        from reuse_templates import INDEX, sha, validate_report
        report = {'schema_version': 1, 'status': 'PASS', 'case_id': 'topfigure-097-19dfbfef',
                  'for_preparation_id': 'test', 'index_sha256': sha(INDEX),
                  'independent_R_processes': 2, 'png_pixel_identical': True, 'pdf_raster_identical': True,
                  'semantic_geometry_identical': False, 'environment_lock_checked': False,
                  'bound_files': [{'path': str(INDEX), 'sha256': sha(INDEX)}]}
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'fake.json';path.write_text(json.dumps(report))
            self.assertTrue(validate_report(path, report['case_id'], 'test'))


if __name__ == '__main__':
    unittest.main()
