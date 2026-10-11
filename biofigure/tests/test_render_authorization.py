import hashlib
import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
import sys
import yaml

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('authorize_render', ROOT / 'scripts/authorize_render.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
sys.path.insert(0, str(ROOT / 'scripts'))
prep_spec = importlib.util.spec_from_file_location('prepare_for_render_auth', ROOT / 'scripts/prepare_figure.py')
prep_module = importlib.util.module_from_spec(prep_spec)
prep_spec.loader.exec_module(prep_module)


class RenderAuthorizationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.receipt = self.root / 'receipt.json'
        self.design = self.root / 'design.yaml'
        self.source = self.root / 'plot.R'
        request = {'primary_domain': 'single-cell-spatial', 'primary_role': 'discovery',
                   'backend': 'R', 'deliverable': 'quick-png',
                   'figure_task': 'marker-expression-across-cell-types',
                   'data_shape': 'genes by cells with pct and average expression', 'figure_family': 'single-cell'}
        receipt = prep_module.prepare(request)
        self.receipt.write_text(json.dumps(receipt, ensure_ascii=False))
        design_doc = yaml.safe_load((ROOT / 'schemas/examples/marker-dotplot.yaml').read_text(encoding='utf-8'))
        style = self.root / 'project-style.yaml'
        style.write_bytes((ROOT / 'schemas/examples/project-style.yaml').read_bytes())
        design_doc['project_style_contract']['registry_path'] = 'project-style.yaml'
        design_doc['deliverable_contract'] = {'target': 'quick-png', 'required_formats': ['png']}
        design_doc['output_size']['formats'] = ['png']
        design_doc['reference_evidence']['preparation_id'] = receipt['preparation_id']
        design_doc['reference_evidence']['preparation_request'] = receipt['request']
        design_doc['reference_evidence']['selected_method_case_id'] = receipt['selected_reference_candidates']['planner_selected']
        design_doc['reference_evidence']['learned_method_reuse'] = {'adopted': [], 'rejected': [
            {'method_id': x['method_id'], 'reason': 'test isolates render authorization, not implementation of this source method'}
            for x in receipt['learned_methods']['results']]}
        design_doc['reference_analysis'] = {
            'figure_family': 'single-cell', 'semantic_purpose': 'display marker specificity',
            'panels': [{'id': 'main', 'role': 'primary evidence', 'position': 'full canvas'}],
            'elements': [{'id': 'bubbles', 'role': 'marker expression', 'geometry': 'points', 'position': 'matrix cells', 'data_mapping': 'gene by cell type', 'required': True},
                         {'id': 'labels', 'role': 'gene labels', 'geometry': 'text', 'position': 'left', 'data_mapping': 'gene labels', 'required': True}],
            'relationships': [{'from': 'bubbles', 'to': 'labels', 'type': 'aligns-with', 'shared_key': 'gene'}],
            'spatial_topology': {'coordinate_system': 'cartesian', 'reading_order': ['main'], 'alignment_keys': ['gene', 'cell_type'], 'layer_order': ['bubbles', 'labels']},
            'required_structures': ['gene by cell type matrix'], 'forbidden_substitutions': ['bar chart']}
        design_doc['design_target'] = {'reference': 'ATLAS-TJ-HCL-F2', 'reference_opened': True}
        for key in ('hierarchy', 'geometry', 'palette', 'typography', 'marks', 'annotation'):
            design_doc['design_target'][key] = {'observation': 'visible', 'implementation': 'task-specific', 'difference_reason': 'adapted'}
        design_doc['text_contract'] = {'allowed_text': ['Gene', 'Cell type'], 'allow_headings': False}
        self.design.write_text(yaml.safe_dump(design_doc, allow_unicode=True))
        self.source.write_text('plot(1)\n')
        self.auth = self.root / 'authorization.json'

    def tearDown(self):
        self.tmp.cleanup()

    def test_authorization_is_bound_to_spec_receipt_and_source_and_consumed_once(self):
        token = module.issue(self.receipt, self.design, [self.source], self.auth)
        self.assertTrue(module.consume(self.auth, self.design, [self.source]))
        with self.assertRaisesRegex(ValueError, 'already consumed'):
            module.consume(self.auth, self.design, [self.source])

    def test_deleting_marker_does_not_make_consumed_authorization_replayable(self):
        module.issue(self.receipt, self.design, [self.source], self.auth)
        module.consume(self.auth, self.design, [self.source])
        self.auth.with_suffix(self.auth.suffix + '.consumed').unlink()
        with self.assertRaisesRegex(ValueError, 'already consumed'):
            module.consume(self.auth, self.design, [self.source])

    def test_cp2_validates_spec_and_real_receipt_before_any_source_exists(self):
        result = subprocess.run(['python3', str(ROOT / 'scripts/validate_design_spec.py'),
                                 str(self.design), '--preparation-receipt', str(self.receipt)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('DESIGN_SPEC_VALIDATION_OK', result.stdout)

    def test_spec_receipt_or_source_tampering_invalidates_authorization(self):
        module.issue(self.receipt, self.design, [self.source], self.auth)
        self.source.write_text('plot(2)\n')
        with self.assertRaisesRegex(ValueError, 'changed'):
            module.consume(self.auth, self.design, [self.source])


if __name__ == '__main__':
    unittest.main()
