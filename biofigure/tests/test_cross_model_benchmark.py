import importlib.util
import json
import subprocess
import tempfile
import tempfile
import unittest
from types import SimpleNamespace
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('cross_model_benchmark', ROOT / 'scripts/run_cross_model_benchmark.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class CrossModelBenchmarkTests(unittest.TestCase):
    def _review_fixture(self, tmp, *, coord=None, png_hash='a'*64, inspection_override=None,
                        run_key=None, run_id='technical-run', input_sha256='d'*64, prefix='fixture'):
        dimensions = module.load_protocol()['review_dimensions']
        run_key = run_key or {'blind_id': 'blind-01', 'case_id': 'distribution-transfer', 'repeat': 1}
        reviews = []
        records = []
        for index in (1, 2):
            review = {'schema_version': 1, 'reviewer_id': f'reviewer-{index}', 'reviewer_type': 'human',
                      'judgment': 'PASS', 'artifact_sha256': png_hash, 'first_pass': True,
                      **run_key, 'run_id': run_id, 'input_sha256': input_sha256,
                      'scores': {d: 5 for d in dimensions}, 'scientific_hard_errors': [],
                      'missing_deliverables': [], 'defect_coordinates': [coord] if coord else []}
            path = Path(tmp) / f'{prefix}-review-{index}.json'
            path.write_text(json.dumps(review, allow_nan=True), encoding='utf-8')
            ref = {'path': str(path), 'sha256': module.sha(path)}
            reviews.append(ref)
            records.append({'review_file': ref, 'review': review})
        inspection = {'artifact_sha256': png_hash, 'first_render_sha256': 'b'*64,
                      'run_id': run_id, **run_key, 'input_sha256': input_sha256,
                      'artifact_path': '/tmp/final.png', 'first_render_path': '/tmp/first.png',
                      'target_size': {'width_mm': 90, 'height_mm': 70}, 'reviewer_type': 'human',
                      'reviewer_id': 'reviewer-1', 'judgment': 'PASS', 'defect_coordinates': [],
                      'viewer_method': 'direct-open', 'revision_count': 0, 'review_records': records,
                      'final_size_checks': {'target_size_opened': True, 'checks': {
                          key: {'status': 'PASS', 'evidence': f'{key} checked on final-size PNG', 'colored_data_marks': True}
                          for key in ('typography_size', 'typography_position', 'label_overlap',
                                      'legend_overlap', 'clipping', 'panel_alignment',
                                      'figure_text_proportion', 'semantic_color', 'footer_absent')}}}
        if inspection_override:
            inspection_override(inspection)
        return reviews, inspection

    def test_review_records_are_hashed_cp4_bound_and_metrics_are_derived(self):
        with tempfile.TemporaryDirectory() as tmp:
            reviews, inspection = self._review_fixture(tmp)
            errors, derived = module.validate_review_evidence(reviews, 'a'*64, inspection, Path(tmp),
                {'blind_id':'blind-01','case_id':'distribution-transfer','repeat':1}, 'technical-run', 'd'*64)
        self.assertEqual(errors, [])
        self.assertEqual(derived['scientific_hard_errors'], 0)
        self.assertTrue(derived['first_pass'])
        self.assertEqual(derived['hard_visual_defects'], 0)
        self.assertEqual(len(derived['score_rows']), 2)

    def test_review_evidence_rejects_missing_hash_nan_wrong_png_and_cp4_mismatch(self):
        bad_cases = ('missing', 'wrong_hash', 'nan_coordinate', 'wrong_png_hash', 'cp4_mismatch')
        for bad in bad_cases:
            with self.subTest(bad=bad), tempfile.TemporaryDirectory() as tmp:
                coord = {'issue': 'overlap', 'severity': 'hard', 'x': 0.4, 'y': 0.3, 'unit': 'normalized'}
                if bad == 'nan_coordinate': coord['x'] = float('nan')
                mutate = (lambda doc: doc['review_records'][0]['review'].__setitem__('judgment', 'FAIL')) if bad == 'cp4_mismatch' else None
                reviews, inspection = self._review_fixture(tmp, coord=coord if bad == 'nan_coordinate' else None,
                    png_hash='c'*64 if bad == 'wrong_png_hash' else 'a'*64, inspection_override=mutate)
                if bad == 'missing': reviews[0]['path'] = str(Path(tmp) / 'absent.json')
                if bad == 'wrong_hash': reviews[0]['sha256'] = '0'*64
                errors, _ = module.validate_review_evidence(reviews, 'a'*64, inspection, Path(tmp),
                    {'blind_id':'blind-01','case_id':'distribution-transfer','repeat':1}, 'technical-run', 'd'*64)
                self.assertTrue(errors, bad)

    def _full_review_matrix(self, tmp):
        protocol = module.load_protocol()
        protocol['execution_ready'] = True
        protocol['fixed_conditions'].update({'skill_commit': 'test-commit', 'prompt_sha256': 'a'*64,
            'package_lock_sha256': 'b'*64, 'toolset': ['R'], 'permission_profile': 'test-permissions', 'cpu_limit': 1})
        report = {'protocol_sha256': module.sha(module.PROTOCOL),
                  'thresholds_sha256': __import__('hashlib').sha256(
                      json.dumps(protocol['acceptance_thresholds'], sort_keys=True).encode()).hexdigest(),
                  'runs': []}
        for blind in protocol['model_blind_ids']:
            for case in protocol['cases']:
                for repeat in range(1, protocol['repeats_per_model_case'] + 1):
                    run_key = {'blind_id': blind, 'case_id': case['case_id'], 'repeat': repeat}
                    run_id = f"{blind}-{case['case_id']}-{repeat}"
                    artifact_hash = __import__('hashlib').sha256(run_id.encode()).hexdigest()
                    reviews, inspection = self._review_fixture(tmp, png_hash=artifact_hash, run_key=run_key,
                        run_id=run_id, input_sha256=case['input_sha256'], prefix=run_id)
                    inspection_path = Path(tmp) / f'{run_id}-inspection.json'
                    inspection_path.write_text(json.dumps(inspection), encoding='utf-8')
                    evidence = {role: {'path': str(Path(tmp)/f'{run_id}-{role}'),
                                      'sha256': __import__('hashlib').sha256(f'{run_id}-{role}'.encode()).hexdigest()}
                                for role in ('renderer_source','png','render_receipt','design_spec','preparation_receipt','checkpoint_ledger')}
                    evidence['png']['sha256'] = artifact_hash
                    evidence['inspection_evidence'] = {'path': str(inspection_path), 'sha256': module.sha(inspection_path)}
                    evidence['reviews'] = reviews
                    manifest_path = Path(tmp) / f'{run_id}-manifest.json'
                    manifest = {'schema_version':1, **run_key, 'run_key':run_key, 'run_id':run_id,
                                'input_sha256':case['input_sha256'], 'evidence':evidence}
                    manifest_path.write_text(json.dumps(manifest), encoding='utf-8')
                    evidence['run_manifest'] = {'path':str(manifest_path), 'sha256':module.sha(manifest_path)}
                    report['runs'].append({'blind_id': blind, 'case_id': case['case_id'], 'repeat': repeat,
                        'run_id': run_id,
                        'status': 'PASS', 'input_sha256': case['input_sha256'], 'canvas_mm': case['canvas_mm'],
                        'dpi': case['dpi'], 'seed': case['seed'], 'skill_commit': 'test-commit',
                        'prompt_sha256': 'a'*64, 'package_lock_sha256': 'b'*64, 'toolset': ['R'],
                        'permission_profile': 'test-permissions', 'reasoning_effort': 'matched',
                        'cpu_limit': 1, 'wall_time_limit_seconds': 1800,
                        'evidence': evidence,
                        'reviews': reviews.copy()})
        return report, protocol, Path(report['runs'][0]['evidence']['inspection_evidence']['path'])

    def test_full_matrix_aggregates_only_hashed_review_files_not_row_claims(self):
        with tempfile.TemporaryDirectory() as tmp:
            report, protocol, inspection_path = self._full_review_matrix(tmp)
            with patch.object(module, 'load_protocol', return_value=protocol), \
                 patch.object(module, 'validate_run_evidence', return_value=[]):
                errors = module.validate_report(report, Path(tmp))
            self.assertEqual(errors, [])
            self.assertEqual(report['computed_metrics']['scientific_hard_errors'], 0)
            self.assertEqual(report['computed_metrics']['first_pass_rate'], 1.0)
            self.assertEqual(report['computed_metrics']['hard_visual_defect_rate'], 0.0)
            for row in report['runs'][:3]:
                review_ref = row['reviews'][0]
                review_path = Path(review_ref['path'])
                review = json.loads(review_path.read_text(encoding='utf-8'))
                review['defect_coordinates'] = [{'issue':'overlap','severity':'hard','x':0.4,'y':0.3,'unit':'normalized'}]
                review_path.write_text(json.dumps(review), encoding='utf-8')
                review_ref['sha256'] = module.sha(review_path)
                inspection_path = Path(row['evidence']['inspection_evidence']['path'])
                inspection = json.loads(inspection_path.read_text(encoding='utf-8'))
                inspection['review_records'][0] = {'review_file': review_ref, 'review': review}
                inspection_path.write_text(json.dumps(inspection), encoding='utf-8')
                row['evidence']['inspection_evidence']['sha256'] = module.sha(inspection_path)
            report['runs'][0]['hard_visual_defects'] = 0
            with patch.object(module, 'load_protocol', return_value=protocol), \
                 patch.object(module, 'validate_run_evidence', return_value=[]):
                errors = module.validate_report(report, Path(tmp))
            self.assertTrue(any('row-level review aggregates are ignored' in error for error in errors))
            self.assertTrue(any('PASS judgment conflicts' in error for error in errors))
            self.assertNotIn('computed_metrics', report)

    def test_nonpass_matrix_and_reused_run_bundle_cannot_produce_metrics(self):
        with tempfile.TemporaryDirectory() as tmp:
            report, protocol, _ = self._full_review_matrix(tmp)
            for row in report['runs']:
                row['status'] = 'FAIL'
                row['failure_reason'] = 'deliberate negative fixture'
            with patch.object(module, 'load_protocol', return_value=protocol), \
                 patch.object(module, 'validate_run_evidence', return_value=[]):
                errors = module.validate_report(report, Path(tmp))
            self.assertTrue(any('non-PASS run rows' in error for error in errors))
            self.assertNotIn('computed_metrics', report)
        with tempfile.TemporaryDirectory() as tmp:
            report, protocol, _ = self._full_review_matrix(tmp)
            report['runs'][1]['evidence'] = report['runs'][0]['evidence']
            report['runs'][1]['reviews'] = report['runs'][0]['reviews']
            with patch.object(module, 'load_protocol', return_value=protocol), \
                 patch.object(module, 'validate_run_evidence', return_value=[]):
                errors = module.validate_report(report, Path(tmp))
            self.assertTrue(any('evidence path reused across run rows' in error for error in errors))

    def test_run_manifest_binds_report_run_key_session_and_all_evidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            report, _, _ = self._full_review_matrix(tmp)
            row = report['runs'][0]
            manifest_path = Path(row['evidence']['run_manifest']['path'])
            manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
            self.assertEqual(module.validate_run_manifest(row, row['evidence'], manifest, manifest_path, Path(tmp)), [])
            manifest['run_key']['repeat'] = 999
            errors = module.validate_run_manifest(row, row['evidence'], manifest, manifest_path, Path(tmp))
            self.assertTrue(any('run_key or run_id differs' in error for error in errors))

    def test_run_manifest_relative_to_report_directory_not_cwd(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            row_key = {'blind_id':'blind-01','case_id':'distribution-transfer','repeat':1}
            roles = ('renderer_source','png','render_receipt','design_spec','preparation_receipt',
                     'checkpoint_ledger','inspection_evidence')
            evidence = {}
            paths = {}
            for role in roles:
                extension = {'png':'.png','render_receipt':'.json','design_spec':'.yaml',
                             'preparation_receipt':'.json','checkpoint_ledger':'.yaml',
                             'inspection_evidence':'.json'}.get(role, '.R')
                path = root / f'{role}{extension}'
                path.write_text(role, encoding='utf-8')
                paths[role] = path
                evidence[role] = {'path':path.name, 'sha256':module.sha(path)}
            render_doc = {'sources':[{'path':str(paths['renderer_source'].resolve()),
                                      'sha256':module.sha(paths['renderer_source'])}]}
            paths['render_receipt'].write_text(json.dumps(render_doc), encoding='utf-8')
            evidence['render_receipt']['sha256'] = module.sha(paths['render_receipt'])
            paths['preparation_receipt'].write_text('{}', encoding='utf-8')
            evidence['preparation_receipt']['sha256'] = module.sha(paths['preparation_receipt'])
            ledger = {'checkpoints':[{'id':f'CP{i}','status':'PASS','evidence':{}} for i in range(5)]}
            ledger['checkpoints'][2]['evidence'].update(design_spec=str(paths['design_spec'].resolve()),
                preparation_receipt=str(paths['preparation_receipt'].resolve()))
            ledger['checkpoints'][3]['evidence'].update(render_receipt=str(paths['render_receipt'].resolve()),
                artifact=str(paths['png'].resolve()))
            ledger['checkpoints'][4]['evidence']['inspection_evidence']=str(paths['inspection_evidence'].resolve())
            paths['checkpoint_ledger'].write_text(json.dumps(ledger), encoding='utf-8')
            evidence['checkpoint_ledger']['sha256'] = module.sha(paths['checkpoint_ledger'])
            reviews = []
            evidence['reviews'] = reviews
            run_id, input_hash = 'run-rel-1', 'd'*64
            manifest_path = root / 'manifest.json'
            manifest = {'schema_version':1, **row_key, 'run_key':row_key, 'run_id':run_id,
                        'input_sha256':input_hash, 'evidence':evidence}
            manifest_path.write_text(json.dumps(manifest), encoding='utf-8')
            row = {**row_key, 'run_id':run_id, 'input_sha256':input_hash,
                   'reviews':[], 'evidence':{**{k:v for k,v in evidence.items() if k!='reviews'},
                               'run_manifest':{'path':'manifest.json','sha256':module.sha(manifest_path)}}}
            fake_checkpoint = SimpleNamespace(
                validate_preparation_receipt=lambda *a: [], validate_render_receipt=lambda *a: [],
                validate_inspection_evidence=lambda *a: [], validate=lambda *a: [],
                load=lambda *a: {}, DEFINITION=Path('unused'))
            with patch.object(module, '_load_checkpoint_validator', return_value=fake_checkpoint):
                errors = module.validate_run_evidence(row, root)
            self.assertEqual(errors, [])

    def test_duplicate_cp4_reviewer_identity_is_rejected_without_overwrite(self):
        with tempfile.TemporaryDirectory() as tmp:
            reviews, inspection = self._review_fixture(tmp)
            inspection['review_records'][1]['review']['reviewer_id'] = 'reviewer-1'
            errors, _ = module.validate_review_evidence(reviews, 'a'*64, inspection, Path(tmp),
                {'blind_id':'blind-01','case_id':'distribution-transfer','repeat':1}, 'technical-run', 'd'*64)
        self.assertTrue(any('reviewer_id values must be present and unique' in error for error in errors))

    def test_pass_judgment_and_first_pass_cannot_conflict_with_findings_or_revision(self):
        for finding in ('hard_defect', 'scientific_error', 'missing_output', 'revision'):
            with self.subTest(finding=finding), tempfile.TemporaryDirectory() as tmp:
                reviews, inspection = self._review_fixture(tmp)
                ref = reviews[0]
                path = Path(ref['path'])
                review = json.loads(path.read_text(encoding='utf-8'))
                if finding == 'hard_defect':
                    review['defect_coordinates'] = [{'issue':'overlap','severity':'hard','x':0.2,'y':0.7,'unit':'normalized'}]
                elif finding == 'scientific_error':
                    review['scientific_hard_errors'] = ['groups mislabeled']
                elif finding == 'missing_output':
                    review['missing_deliverables'] = ['editable vector']
                else:
                    inspection['revision_count'] = 1
                path.write_text(json.dumps(review), encoding='utf-8')
                ref['sha256'] = module.sha(path)
                inspection['review_records'][0] = {'review_file':ref,'review':review}
                errors, _ = module.validate_review_evidence(reviews, 'a'*64, inspection, Path(tmp),
                    {'blind_id':'blind-01','case_id':'distribution-transfer','repeat':1}, 'technical-run', 'd'*64)
                if finding == 'revision':
                    self.assertTrue(any('first_pass=true conflicts' in error for error in errors))
                else:
                    self.assertTrue(any('PASS judgment conflicts' in error for error in errors))

    def test_first_pass_boolean_revision_count_and_final_judgment_must_agree(self):
        scenarios = ((True, True, 'PASS', True), (False, 0, 'PASS', True), (False, 1, 'PASS', False),
                     (False, 0, 'REVISE', False), (False, 0, 'FAIL', False))
        for first_pass, revision_count, judgment, expect_error in scenarios:
            with self.subTest(first_pass=first_pass, revision_count=revision_count, judgment=judgment), tempfile.TemporaryDirectory() as tmp:
                reviews, inspection = self._review_fixture(tmp)
                inspection['revision_count'] = revision_count
                review_path = Path(reviews[0]['path'])
                review = json.loads(review_path.read_text(encoding='utf-8'))
                review['first_pass'] = first_pass
                review['judgment'] = judgment
                review_path.write_text(json.dumps(review), encoding='utf-8')
                reviews[0]['sha256'] = module.sha(review_path)
                inspection['review_records'][0] = {'review_file':reviews[0], 'review':review}
                if first_pass is False:
                    second_path = Path(reviews[1]['path'])
                    second_review = json.loads(second_path.read_text(encoding='utf-8'))
                    second_review['first_pass'] = False
                    second_review['judgment'] = judgment
                    second_path.write_text(json.dumps(second_review), encoding='utf-8')
                    reviews[1]['sha256'] = module.sha(second_path)
                    inspection['review_records'][1] = {'review_file':reviews[1], 'review':second_review}
                errors, _ = module.validate_review_evidence(reviews, 'a'*64, inspection, Path(tmp),
                    {'blind_id':'blind-01','case_id':'distribution-transfer','repeat':1}, 'technical-run', 'd'*64)
                self.assertEqual(bool(errors), expect_error)

    def test_full_matrix_review_evidence_failures_cannot_pass(self):
        for bad in ('missing', 'wrong_hash', 'nan_coordinate', 'inf_coordinate', 'bool_coordinate',
                    'out_of_range', 'wrong_unit', 'png_mismatch'):
            with self.subTest(bad=bad), tempfile.TemporaryDirectory() as tmp:
                report, protocol, inspection_path = self._full_review_matrix(tmp)
                ref = report['runs'][0]['reviews'][0]
                if bad == 'missing':
                    ref['path'] = str(Path(tmp) / 'removed-review.json')
                elif bad == 'wrong_hash':
                    ref['sha256'] = '0'*64
                else:
                    review_path = Path(ref['path'])
                    review = json.loads(review_path.read_text(encoding='utf-8'))
                    if bad in {'nan_coordinate', 'inf_coordinate', 'bool_coordinate', 'out_of_range', 'wrong_unit'}:
                        x, unit = {'nan_coordinate':(float('nan'),'normalized'),
                                   'inf_coordinate':(float('inf'),'normalized'),
                                   'bool_coordinate':(True,'normalized'),
                                   'out_of_range':(1.2,'normalized'),
                                   'wrong_unit':(0.4,'px')}[bad]
                        review['defect_coordinates'] = [{'issue':'overlap','severity':'hard','x':x,'y':0.4,'unit':unit}]
                    else:
                        review['artifact_sha256'] = 'c'*64
                    review_path.write_text(json.dumps(review, allow_nan=True), encoding='utf-8')
                    ref['sha256'] = module.sha(review_path)
                    inspection = json.loads(inspection_path.read_text(encoding='utf-8'))
                    inspection['review_records'][0] = {'review_file': ref, 'review': review}
                    inspection_path.write_text(json.dumps(inspection, allow_nan=True), encoding='utf-8')
                    for row in report['runs']:
                        row['evidence']['inspection_evidence']['sha256'] = module.sha(inspection_path)
                with patch.object(module, 'load_protocol', return_value=protocol), \
                     patch.object(module, 'validate_run_evidence', return_value=[]):
                    errors = module.validate_report(report, Path(tmp))
                self.assertTrue(errors, bad)

    def test_empty_or_unscored_report_is_incomplete_not_pass(self):
        errors = module.validate_report({'runs': []})
        self.assertTrue(any('review' in error.lower() or 'score' in error.lower() for error in errors))
        forged_pass = {'runs':[{'blind_id':'blind-01','case_id':'distribution-transfer',
                                'repeat':1,'status':'PASS'}]}
        errors = module.validate_report(forged_pass)
        self.assertTrue(any('INCOMPLETE' in error for error in errors))

    def test_claimed_receipt_consistency_without_hashed_artifacts_is_rejected(self):
        forged = {'runs': [{'blind_id':'blind-01','case_id':'distribution-transfer','repeat':1,
                            'status':'PASS','receipt_consistent':True}]}
        errors = module.validate_report(forged)
        self.assertTrue(any('self-reported receipt_consistent is ignored' in error for error in errors))
        self.assertTrue(any('actual artifact evidence map required' in error for error in errors))

    def test_run_evidence_requires_all_real_paths_and_matching_sha256(self):
        errors = module.validate_run_evidence({'receipt_consistent': True})
        roles = ('renderer_source', 'png', 'render_receipt', 'design_spec',
                 'preparation_receipt', 'checkpoint_ledger', 'inspection_evidence')
        for role in roles:
            self.assertTrue(any(role in error for error in errors), role)
        with tempfile.TemporaryDirectory() as tmp:
            file_path = Path(tmp) / 'plot.R'
            file_path.write_text('plot(1)')
            evidence = {role: {'path': str(file_path), 'sha256': '0'*64} for role in roles}
            errors = module.validate_run_evidence({'evidence': evidence})
        self.assertTrue(any('SHA-256 mismatch: renderer_source' in error for error in errors))

    def test_protocol_can_be_valid_while_execution_is_blocked_by_missing_sources(self):
        self.assertEqual(module.validate_protocol(), [])
        blockers = module.execution_blockers()
        self.assertTrue(any('authentic source figure and author code' in item for item in blockers))

    def test_cli_reports_protocol_valid_execution_blocked_and_empty_report_incomplete(self):
        protocol = subprocess.run(['python3', str(ROOT/'scripts/run_cross_model_benchmark.py'), '--validate-protocol'],
                                  capture_output=True, text=True)
        with tempfile.TemporaryDirectory() as tmp:
            report_path = Path(tmp) / 'empty-report.json'
            report_path.write_text(json.dumps({'runs': []}))
            report = subprocess.run(['python3', str(ROOT/'scripts/run_cross_model_benchmark.py'), '--validate-report', str(report_path)],
                                    capture_output=True, text=True)
        self.assertEqual(json.loads(protocol.stdout)['protocol_status'], 'PROTOCOL_VALID')
        self.assertEqual(json.loads(protocol.stdout)['execution_status'], 'EXECUTION_BLOCKED')
        self.assertEqual(json.loads(report.stdout)['status'], 'INCOMPLETE')
        self.assertEqual(report.returncode, 2)

    def test_transfer_and_source_exposed_cases_have_auditable_material_boundaries(self):
        protocol = module.load_protocol()
        for family in {'distribution', 'matrix', 'composition', 'topology'}:
            transfer = next(c for c in protocol['cases'] if c['family'] == family and c['exposure'] == 'transfer')
            exposed = next(c for c in protocol['cases'] if c['family'] == family and c['exposure'] == 'source-exposed')
            self.assertEqual(transfer['task'], exposed['task'])
            self.assertEqual(transfer['input_sha256'], exposed['input_sha256'])
            self.assertEqual((transfer['canvas_mm'], transfer['dpi'], transfer['seed']),
                             (exposed['canvas_mm'], exposed['dpi'], exposed['seed']))
            self.assertTrue(transfer.get('forbidden_materials'))
            self.assertTrue(exposed.get('permitted_materials'))
            self.assertNotEqual(transfer['available_materials'][0]['role'], exposed['available_materials'][0]['role'])

    def test_two_protocol_smoke_cases_run_deterministic_prepare_only(self):
        result = module.run_smoke_cases()
        self.assertEqual(len(result), 2)
        self.assertTrue(all(row['status'] == 'PREFLIGHT_COMPLETE' for row in result))
        self.assertTrue(all(row['request_id'] for row in result))

    def test_smoke_runner_does_not_accept_blocked_preflight(self):
        errors = module.smoke_preflight_errors([
            {'case_id': 'ok', 'status': 'PREFLIGHT_COMPLETE'},
            {'case_id': 'blocked', 'status': 'NEEDS_SPEC'},
        ])
        self.assertTrue(any('blocked' in error for error in errors))

    def test_rejects_label_leakage_unequal_inputs_missing_failures_and_threshold_drift(self):
        report = {'protocol_sha256': 'a' * 64, 'thresholds_sha256': 'b' * 64,
                  'runs': [{'blind_id': 'A', 'model_label': 'model-x', 'input_sha256': '1', 'toolset': ['R'],
                            'permission_profile': 'same', 'prompt_sha256': 'p', 'case_id': 'distribution-transfer',
                            'repeat': 1, 'status': 'PASS'},
                           {'blind_id': 'blind-02', 'input_sha256': 'different', 'toolset': ['Python'],
                            'permission_profile': 'same', 'prompt_sha256': 'p', 'case_id': 'distribution-transfer',
                            'repeat': 1, 'status': 'PASS'}]}
        errors = module.validate_report(report)
        for marker in ('model_label', 'failed or missing runs', 'unequal', 'threshold'):
            self.assertTrue(any(marker in item for item in errors), marker)


if __name__ == '__main__':
    unittest.main()
