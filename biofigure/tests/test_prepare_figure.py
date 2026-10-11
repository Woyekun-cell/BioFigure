import importlib.util
import json
import sys
import subprocess
import tempfile
import unittest
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
spec = importlib.util.spec_from_file_location('prepare_figure', ROOT / 'scripts/prepare_figure.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
checkpoint_spec = importlib.util.spec_from_file_location('prepare_checkpoint_validator', ROOT / 'scripts/validate_checkpoints.py')
checkpoint_module = importlib.util.module_from_spec(checkpoint_spec)
checkpoint_spec.loader.exec_module(checkpoint_module)


class PrepareFigureTests(unittest.TestCase):
    def setUp(self):
        self.request = {
            'primary_domain': 'genome-sequence-variation',
            'primary_role': 'comparison',
            'backend': 'R',
            'deliverable': 'paper-composite',
            'figure_task': 'genome chromosome distribution of gene variants',
            'data_shape': 'chromosome, genomic position, variant count',
            'figure_family': 'genome distribution',
        }

    def test_preparation_searches_benchmark_and_reference_corpora_before_code(self):
        result = module.prepare(self.request)
        self.assertEqual(result['status'], 'PREFLIGHT_COMPLETE')
        self.assertIn('reproduction', result['retrievals'])
        self.assertIn('scidraw', result['retrievals'])
        self.assertIn('capability_benchmark', result['retrievals'])
        self.assertIn('top_journal', result['retrievals'])
        self.assertEqual(result['code_gate'], 'BLOCKED_UNTIL_REFERENCE_ANALYSIS_AND_CP2')
        self.assertEqual(result['pre_code_gate']['status'], 'BLOCKED_UNTIL_REFERENCE_ANALYSIS_AND_CP2')
        self.assertTrue(result['preparation_id'])
        self.assertEqual(result['missing_material'], [])
        self.assertIn('references/visual-design-synthesis.md', result['source_hashes'])
        self.assertIn('atlas/unified-capability-graph.json', result['source_hashes'])

    def test_missing_figure_task_blocks_instead_of_guessing(self):
        request = dict(self.request)
        request.pop('figure_task')
        with self.assertRaisesRegex(ValueError, 'figure_task'):
            module.prepare(request)

    def test_ambiguous_task_does_not_authorize_rendering(self):
        request = dict(self.request, figure_task='make a nice figure xyz qqq', figure_family='', data_shape='')
        result = module.prepare(request)
        self.assertNotEqual(result['code_gate'], 'READY')
        self.assertNotEqual(result['method_plan']['planning_status'], 'METHOD_CANDIDATE')

    def test_same_request_produces_same_reference_and_method_contract(self):
        first = module.prepare(self.request)
        second = module.prepare(self.request)
        self.assertEqual(first['planning_id'], second['planning_id'])
        self.assertNotEqual(first['preparation_id'], second['preparation_id'])
        self.assertEqual(first['selected_reference_candidates'], second['selected_reference_candidates'])
        self.assertEqual(first['method_plan']['package_contract'], second['method_plan']['package_contract'])

    def test_real_receipt_binds_task_domain_backend_and_selected_method(self):
        receipt = module.prepare(self.request)
        spec = {'figure_task': self.request['figure_task'],
                'biology_contract': {'primary_domain': self.request['primary_domain']},
                'role_contract': {'primary_role': self.request['primary_role']},
                'backend_lock': {'backend': self.request['backend']},
                'reference_analysis': {'figure_family': 'genome'},
                'deliverable_contract': {'target': 'paper-composite', 'required_formats': ['pdf', 'svg', 'png']},
                'output_size': {'formats': ['pdf', 'svg', 'png']},
                'reference_evidence': {
                    'preparation_id': receipt['preparation_id'],
                    'preparation_request': receipt['request'],
                    'selected_method_case_id': receipt['selected_reference_candidates']['planner_selected']}}
        with tempfile.TemporaryDirectory(prefix='biofigure-receipt-binding-') as tmp:
            spec['reference_evidence']['learned_method_reuse'] = {'adopted': [], 'rejected': [
                {'method_id': x['method_id'], 'reason': 'unit test isolates receipt binding; candidate drawing is outside fixture scope'}
                for x in receipt['learned_methods']['results']]}
            path = Path(tmp) / 'preparation.json'
            path.write_text(json.dumps(receipt), encoding='utf-8')
            self.assertEqual(checkpoint_module.validate_preparation_receipt(str(path), spec), [])

    def test_cp2_binds_complete_normalized_request_not_only_task_and_backend(self):
        receipt = module.prepare(self.request)
        spec = {'figure_task': self.request['figure_task'],
                'biology_contract': {'primary_domain': self.request['primary_domain']},
                'role_contract': {'primary_role': self.request['primary_role']},
                'backend_lock': {'backend': self.request['backend']},
                'reference_analysis': {'figure_family': 'genome'},
                'deliverable_contract': {'target': 'paper-composite', 'required_formats': ['pdf', 'svg', 'png']},
                'output_size': {'formats': ['pdf', 'svg', 'png']},
                'reference_evidence': {'preparation_id': receipt['preparation_id'],
                    'preparation_request': receipt['request'],
                    'selected_method_case_id': receipt['selected_reference_candidates']['planner_selected']}}
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'receipt.json'
            altered = dict(receipt)
            altered['request'] = dict(receipt['request'], data_shape='changed units and replicate semantics')
            altered.pop('preparation_id')
            altered['preparation_id'] = __import__('hashlib').sha256(
                json.dumps(altered, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
            path.write_text(json.dumps(altered, ensure_ascii=False))
            errors = checkpoint_module.validate_preparation_receipt(str(path), spec)
        self.assertTrue(any('complete CP2 request binding' in error for error in errors))

    def test_cli_returns_success_for_completed_preflight(self):
        with tempfile.TemporaryDirectory(prefix='biofigure-preflight-test-') as tmp:
            request_path = Path(tmp) / 'request.yaml'
            receipt_path = Path(tmp) / 'preparation.json'
            request_path.write_text(yaml.safe_dump(self.request, allow_unicode=True), encoding='utf-8')
            result = subprocess.run([sys.executable, str(ROOT/'scripts/prepare_figure.py'),
                                     str(request_path), '--output', str(receipt_path)],
                                    capture_output=True, text=True, cwd=tmp)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(json.loads(receipt_path.read_text())['status'], 'PREFLIGHT_COMPLETE')

    def test_cli_failure_writes_complete_receipt_and_nonzero_status(self):
        with tempfile.TemporaryDirectory(prefix='biofigure-preflight-failure-') as tmp:
            request_path = Path(tmp) / 'request.yaml'
            receipt_path = Path(tmp) / 'preparation.json'
            request_path.write_text('figure_task: [malformed schema]\n')
            result = subprocess.run([sys.executable, str(ROOT/'scripts/prepare_figure.py'),
                                     str(request_path), '--output', str(receipt_path)],
                                    capture_output=True, text=True, cwd=tmp)
            self.assertNotEqual(result.returncode, 0)
            receipt = json.loads(receipt_path.read_text())
            self.assertEqual(receipt['status'], 'INVALID_REQUEST')
            self.assertEqual(receipt['code_gate'], 'BLOCKED')
            self.assertTrue(receipt['preparation_id'])

    def test_cli_blocked_and_invalid_receipts_never_crash_while_printing_summary(self):
        cases = [
            ('missing-field', {'figure_task': 'plot'}, 'INVALID_REQUEST'),
            ('missing-tool', dict(self.request, required_tools=['missing-tool'], available_tools=[]), 'BLOCKED_CAPABILITY'),
            ('missing-permission', dict(self.request, required_permissions=['write-project'], available_permissions=[]), 'BLOCKED_CAPABILITY'),
        ]
        for name, request, expected_status in cases:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as tmp:
                request_path = Path(tmp) / 'request.yaml'
                receipt_path = Path(tmp) / 'receipt.json'
                request_path.write_text(yaml.safe_dump(request, allow_unicode=True), encoding='utf-8')
                result = subprocess.run([sys.executable, str(ROOT/'scripts/prepare_figure.py'),
                                         str(request_path), '--output', str(receipt_path)],
                                        capture_output=True, text=True, cwd=tmp)
                self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                self.assertNotIn('Traceback', result.stdout + result.stderr)
                printed = json.loads(result.stdout)
                receipt = json.loads(receipt_path.read_text(encoding='utf-8'))
                self.assertEqual(printed['status'], expected_status)
                self.assertEqual(receipt['status'], expected_status)
                self.assertTrue(receipt.get('preparation_id'))
                self.assertIn('code_gate', receipt)

    def test_cp2_rejects_deliverable_mismatch_even_when_request_is_copied(self):
        receipt = module.prepare(dict(self.request, deliverable='quick-png'))
        spec = {'figure_task': self.request['figure_task'],
                'biology_contract': {'primary_domain': self.request['primary_domain']},
                'role_contract': {'primary_role': self.request['primary_role']},
                'backend_lock': {'backend': self.request['backend']},
                'reference_analysis': {'figure_family': 'genome'},
                'deliverable_contract': {'target': 'editable-vector', 'required_formats': ['svg', 'pdf', 'png']},
                'output_size': {'formats': ['svg', 'pdf', 'png']},
                'reference_evidence': {'preparation_id': receipt['preparation_id'],
                    'preparation_request': receipt['request'],
                    'selected_method_case_id': receipt['selected_reference_candidates']['planner_selected']}}
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'receipt.json'
            path.write_text(json.dumps(receipt), encoding='utf-8')
            errors = checkpoint_module.validate_preparation_receipt(str(path), spec)
        self.assertTrue(any('deliverable' in error.lower() for error in errors))

    def test_every_route_loads_hard_gate_and_all_required_reference_sources(self):
        from route_figure import route
        result = route(self.request)
        self.assertIn('references/figure-execution-gates.md', result['modules'])
        self.assertIn('references/benchmark-protocol.md', result['modules'])
        self.assertEqual(set(result['reference_evidence_layers']), {'reproduction', 'top_journal', 'scidraw'})
        self.assertTrue(result['pre_code_gate']['mandatory'])

    def test_explicit_request_cannot_skip_a_required_corpus(self):
        from route_figure import route
        request = dict(self.request, reference_sources=['scidraw'])
        with self.assertRaisesRegex(ValueError, 'cannot be skipped'):
            route(request)

    def test_route_canonicalizes_optional_source_order_and_secondary_axes(self):
        from route_figure import route
        a = dict(self.request, secondary_domains=['single-cell-spatial', 'chromatin-epigenome'],
                 secondary_roles=['validation', 'discovery'],
                 reference_sources=['scidraw', 'top_journal', 'reproduction'])
        b = dict(self.request, secondary_domains=['chromatin-epigenome', 'single-cell-spatial'],
                 secondary_roles=['discovery', 'validation'],
                 reference_sources=['reproduction', 'scidraw', 'top_journal'])
        self.assertEqual(route(a), route(b))


if __name__ == '__main__':
    unittest.main()

class PrepareNormalizationTests(unittest.TestCase):
    def setUp(self):
        self.request = {
            'primary_domain': 'genome-sequence-variation',
            'primary_role': 'comparison', 'backend': 'R',
            'deliverable': 'paper-composite',
            'figure_task': 'genome chromosome distribution of gene variants',
            'data_shape': 'chromosome, genomic position, variant count',
            'figure_family': 'genome distribution',
        }

    def test_request_id_ignores_key_order_model_label_and_cwd(self):
        import os
        a = module.prepare(dict(self.request, model_label='model-a'))
        b = module.prepare(dict(reversed(list(self.request.items())), model_label='model-b'))
        old = os.getcwd()
        try:
            os.chdir('/tmp')
            c = module.prepare(dict(self.request, model_label='model-c'))
        finally:
            os.chdir(old)
        self.assertEqual(a['request_id'], b['request_id'])
        self.assertEqual(a['request_id'], c['request_id'])

    def test_missing_chart_family_returns_needs_spec_without_retrieval_guess(self):
        request = dict(self.request, figure_family='', data_shape='')
        result = module.prepare(request)
        self.assertEqual(result['status'], 'NEEDS_SPEC')
        self.assertEqual(result['selected_reference_candidates']['planner_selected'], None)

    def test_unspecified_chart_family_leaves_choice_to_scientific_analysis(self):
        request = dict(self.request)
        request.pop('figure_family')
        result = module.prepare(request)
        self.assertEqual(result['status'], 'READY_FOR_CHART_SELECTION')
        self.assertNotEqual(result['code_gate'], 'OPEN')
        self.assertIn('CP2', result['code_gate'])
        self.assertIn('propose a preferred chart and alternatives', result['required_next_steps'][0])

    def test_unavailable_tool_or_permission_blocks_bootstrap(self):
        tool = module.prepare(dict(self.request, required_tools=['plot-backend'], available_tools=[]))
        permission = module.prepare(dict(self.request, required_permissions=['write-project'], available_permissions=[]))
        self.assertEqual(tool['status'], 'BLOCKED_CAPABILITY')
        self.assertEqual(tool['missing_tools'], ['plot-backend'])
        self.assertEqual(permission['status'], 'BLOCKED_CAPABILITY')
        self.assertEqual(permission['missing_permissions'], ['write-project'])

    def test_invalid_schema_value_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'backend'):
            module.prepare(dict(self.request, backend='Both'))
