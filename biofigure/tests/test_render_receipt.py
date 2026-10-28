import hashlib
import importlib.util
import io
import json
from contextlib import redirect_stdout
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[1]
__import__('sys').path.insert(0, str(ROOT / 'scripts'))
spec = importlib.util.spec_from_file_location('checkpoints', ROOT/'scripts/validate_checkpoints.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

class ReceiptTests(unittest.TestCase):
    def test_cli_pending_ledger_returns_json_without_reading_inspection(self):
        definition = m.load(m.DEFINITION)
        entries = [{'id': gate['id'], 'status': 'STOP' if index == 0 else 'NOT_RUN',
                    'evidence': {}, 'failures': ['awaiting scientific intent'] if index == 0 else [],
                    'next_action': 'resolve earlier checkpoint'}
                   for index, gate in enumerate(definition['checkpoints'])]
        ledger = {'schema_version': 1, 'artifact_id': 'pending-fixture',
                  'mode': 'standard', 'checkpoints': entries}
        self.assertEqual(m.validate(ledger, definition), [])
        path = self.root / 'pending-ledger.json'
        path.write_text(json.dumps(ledger))
        result = subprocess.run([sys.executable, str(ROOT / 'scripts/validate_checkpoints.py'),
                                 str(path), '--json'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 1, result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload['status'], 'FAIL')
        self.assertTrue(any('release is blocked' in error for error in payload['errors']))
        self.assertFalse(payload['current_render_inspection_verified'])
        self.assertNotIn('Traceback', result.stderr)

    def test_final_inspection_reload_fails_closed_after_validation(self):
        original_validate = m.validate
        for change in ('missing-inspection', 'changed-receipt'):
            with self.subTest(change=change):
                ledger, _ = self.ledger()
                path = self.root / 'ledger.json'
                path.write_text(json.dumps(ledger))
                inspection = Path(ledger['checkpoints'][4]['evidence']['inspection_evidence'])
                def change_after_validation(document, definition):
                    errors = original_validate(document, definition)
                    self.assertEqual(errors, [])
                    if change == 'missing-inspection':
                        inspection.unlink()
                    else:
                        self.receipt.write_bytes(self.receipt.read_bytes() + b'\n')
                    return errors
                output = io.StringIO()
                with patch.object(m.subprocess, 'run', return_value=SimpleNamespace(returncode=0, stdout='', stderr='')), \
                     patch.object(m, 'validate', side_effect=change_after_validation), redirect_stdout(output):
                    status = m.main([str(path), '--json'])
                payload = json.loads(output.getvalue())
                self.assertEqual(status, 1, payload)
                self.assertEqual(payload['status'], 'FAIL')
                self.assertTrue(payload['errors'])
                self.assertFalse(payload['current_render_inspection_verified'])

    def test_current_cp3_cannot_omit_inspection_policy_to_use_legacy_scope(self):
        self.data.pop('inspection_binding_policy')
        self.receipt.write_text(json.dumps(self.data))
        self.assertTrue(any('inspection_binding_policy' in error for error in self.check()))

    def test_cp4_rejects_old_inspection_after_new_authorization_with_identical_artifact(self):
        ledger, definition = self.ledger()
        artifact_before = self.artifact.read_bytes()
        inspection_path = Path(ledger['checkpoints'][4]['evidence']['inspection_evidence'])
        inspection_before = inspection_path.read_bytes()
        with patch.object(m.subprocess, 'run', return_value=SimpleNamespace(returncode=0, stdout='', stderr='')):
            self.assertEqual(m.validate(ledger, definition), [])
            authorization = json.loads(self.authorization.read_text())
            authorization.pop('authorization_id')
            authorization.pop('consumed')
            authorization['issued_at'] = 'new authorized fixture render'
            new_id = hashlib.sha256(json.dumps(authorization, sort_keys=True).encode()).hexdigest()
            authorization.update(authorization_id=new_id, consumed=True)
            self.authorization.write_text(json.dumps(authorization))
            self.auth_marker.write_text(new_id + '\n')
            consumption = self.data['authorization_consumption']
            consumption['authorization_id'] = new_id
            for key, path in (('authorization_file', self.authorization), ('marker', self.auth_marker)):
                consumption[key] = {'path': str(path), 'sha256': m.digest(path)}
            self.receipt.write_text(json.dumps(self.data))
            errors = m.validate(ledger, definition)
            self.assertTrue(any('render_receipt_sha256' in error for error in errors), errors)
            self.assertEqual(inspection_path.read_bytes(), inspection_before)
            inspection = json.loads(inspection_path.read_text())
            inspection['render_receipt_sha256'] = m.digest(self.receipt)
            inspection_path.write_text(json.dumps(inspection))
            self.assertEqual(m.validate(ledger, definition), [])
        self.assertEqual(self.artifact.read_bytes(), artifact_before)

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.artifact = self.root/'figure.png'
        self.artifact.write_bytes(b'fixture: hash validation only, not visual evidence')
        self.script = self.root/'plot.R'
        self.script.write_text('render()')
        self.design = self.root/'design.yaml'
        self.design.write_text('figure_task: fixture\ntext_contract:\n  allowed_text: [Sample]\n  allow_headings: false\n')
        self.preparation = self.root/'preparation.json'
        self.preparation.write_text('{}')
        self.font = self.root/'Arial.ttf'
        self.font.write_bytes(b'fixture font')
        self.auth_marker = self.root/'authorization.json.consumed'
        self.auth_id = 'a' * 64
        self.auth_marker.write_text(self.auth_id + '\n')
        self.authorization = self.root/'authorization.json'
        def bound(path):
            return {'path':str(path.resolve()), 'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
        auth_body = {'schema_version':1,'status':'AUTHORIZED','single_use':True,
                     'bound':{'receipt':bound(self.preparation),'design_spec':bound(self.design),
                              'sources':[bound(self.script)]}}
        self.auth_id = hashlib.sha256(json.dumps(auth_body, sort_keys=True).encode()).hexdigest()
        auth_body['authorization_id'] = self.auth_id
        auth_body['consumed'] = True
        self.authorization.write_text(json.dumps(auth_body))
        self.auth_marker.write_text(self.auth_id + '\n')
        self.receipt = self.root/'receipt.json'
        def bound(p):
            return {'path':str(p), 'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
        self.data = {'schema_version':1, 'status':'PASS', 'backend':'R',
                     'inspection_binding_policy':'render-receipt-sha256-v1',
                     'artifact':bound(self.artifact), 'sources':[bound(self.script),bound(self.design)],
                     'font':dict(bound(self.font), family='Arial'),
                     'authorization_consumption':{'consumed':True,'authorization_id':self.auth_id,
                         'marker':bound(self.auth_marker),'authorization_file':bound(self.authorization),
                         'preparation_receipt':bound(self.preparation)},
                     'checks':{k:True for k in ('font','text_allowlist','layout','target_size','scientific_text_only','footer_free')},
                     'text_policy_id':'scientific-content-only-v1','footer_policy_id':'no-canvas-footer-v1','rendered_text':[],
                     'target_min_text_pt':7,
                     'target_size':{'width_mm':90,'height_mm':75,'size_class':'single-column',
                                    'size_basis':'final_physical_output'}}
        self.receipt.write_text(json.dumps(self.data))
    def _bind_authorization(self, preparation, design, renderer_sources=None):
        def bound(path):
            return {'path':str(path.resolve()), 'sha256':m.digest(path)}
        renderer_sources = [self.script] if renderer_sources is None else renderer_sources
        body={'schema_version':1,'status':'AUTHORIZED','single_use':True,
              'bound':{'receipt':bound(preparation),'design_spec':bound(design),
                       'sources':[bound(path) for path in renderer_sources]}}
        auth_id=hashlib.sha256(json.dumps(body,sort_keys=True).encode()).hexdigest()
        body['authorization_id']=auth_id
        body['consumed']=True
        self.authorization.write_text(json.dumps(body))
        self.auth_id=auth_id
        self.auth_marker.write_text(auth_id+'\n')
        self.data['sources']=[bound(path) for path in renderer_sources]+[bound(design)]
        self.data['authorization_consumption']={'consumed':True,'authorization_id':auth_id,
          'marker':bound(self.auth_marker),'authorization_file':bound(self.authorization),
          'preparation_receipt':bound(preparation)}
        self.receipt.write_text(json.dumps(self.data))
    def _text_receipt(self, labels=None, rendered=None, helper=None):
        labels = ['Sample', 'AI accuracy', 'AI_001', 'n = 6', '20 µm'] if labels is None else labels
        self.design.write_text(__import__('yaml').safe_dump({
            'figure_task':'fixture', 'text_contract':{'allowed_text':labels,'allow_headings':False}}))
        self.data['renderer']='ggplot2'
        self.data['text_policy_id']='scientific-content-only-v1'
        self.data['checks']['scientific_text_only']=True
        self.data['rendered_text']=labels if rendered is None else rendered
        helper = ROOT/'scripts/figure_style.R' if helper is None else helper
        self._bind_authorization(self.preparation, self.design, [self.script, helper])
    def check(self):
        return m.validate_render_receipt(str(self.receipt), self.artifact)
    def test_valid_bound_receipt(self):
        self.assertEqual(self.check(), [])
    def test_heatmap_cannot_pass_without_actual_physical_cell_measurement(self):
        self._text_receipt(labels=['Sample'])
        import yaml
        doc=yaml.safe_load(self.design.read_text())
        doc['reference_analysis']={'figure_family':'expression heatmap',
            'spatial_topology':{'coordinate_system':'cartesian'}}
        doc['heatmap_cell_contract']={'policy_id':'heatmap-cells-v1','shape':'square',
            'measurement_basis':'final_body_viewports_mm','max_relative_error':.01,'rows':8,'columns':4}
        self.design.write_text(yaml.safe_dump(doc))
        self.data['renderer']='native-grid'
        self._bind_authorization(self.preparation,self.design,[self.script,ROOT/'scripts/figure_style.R'])
        self.assertTrue(any('heatmap_cells' in e for e in self.check()))
        self.data['heatmap_cell_policy_id']='heatmap-cells-v1'
        self.data['checks']['cell_geometry']=True
        self.data['heatmap_cells']=[{'panel_id':'expr-1-1','rows':8,'columns':4,
            'body_width_mm':20,'body_height_mm':40,'cell_width_mm':5,'cell_height_mm':5,
            'measurement_method':'final_body_viewports_mm'}]
        self.receipt.write_text(json.dumps(self.data))
        self.assertEqual(self.check(),[])
        # A lying square result cannot hide the measured body geometry.
        self.data['heatmap_cells'][0]['body_height_mm']=32
        self.receipt.write_text(json.dumps(self.data))
        self.assertTrue(any('heatmap_cells' in e for e in self.check()))
    def test_native_backend_cannot_omit_actual_canvas_text(self):
        self._text_receipt(labels=['Sample'])
        self.data['renderer']='native-grid'
        self.data.pop('rendered_text')
        self.receipt.write_text(json.dumps(self.data))
        self.assertTrue(any('rendered_text must be an array' in error for error in self.check()))
    def test_screenshot_footer_is_rejected_even_when_allowlisted(self):
        self._text_receipt(labels=['Sample','n = 8 fish per group; infection day 12',
                                  'FDR <= 0.05; VIP >= 1; FC >= 1.2 or <= 1/1.2'])
        self.assertTrue(any('sample_design_footer' in error or 'filtering_criteria_footer' in error for error in self.check()))
    def test_every_renderer_requires_current_footer_policy_and_checked_result(self):
        for renderer in ('ggplot2', 'native-grid'):
            for defect in ('missing_policy', 'legacy_policy', 'missing_check', 'failed_check'):
                with self.subTest(renderer=renderer, defect=defect):
                    self._text_receipt(labels=['Sample'])
                    self.data['renderer']=renderer
                    if defect=='missing_policy':
                        self.data.pop('footer_policy_id')
                    elif defect=='legacy_policy':
                        self.data['footer_policy_id']='legacy-policy'
                    elif defect=='missing_check':
                        self.data['checks'].pop('footer_free')
                    else:
                        self.data['checks']['footer_free']=False
                    self.receipt.write_text(json.dumps(self.data))
                    self.assertTrue(any('no-canvas-footer' in error for error in self.check()))
    def test_python_render_receipt_cannot_pass_cp3_without_official_authorized_renderer(self):
        self.data['backend']='Python'
        self.receipt.write_text(json.dumps(self.data))
        self.assertTrue(any('Python CP3 PASS blocked' in error for error in self.check()))
    def test_missing_render_authorization_consumption_is_rejected(self):
        self.data.pop('authorization_consumption')
        self.receipt.write_text(json.dumps(self.data))
        self.assertTrue(any('authorization' in error for error in self.check()))
    def test_forged_authorization_id_or_marker_is_rejected(self):
        self.data['authorization_consumption']['authorization_id'] = 'b' * 64
        self.receipt.write_text(json.dumps(self.data))
        self.assertTrue(any('authorization' in error for error in self.check()))
        self.data['authorization_consumption']['authorization_id'] = self.auth_id
        self.auth_marker.write_text('b' * 64 + '\n')
        self.data['authorization_consumption']['marker'] = {'path':str(self.auth_marker), 'sha256':m.digest(self.auth_marker)}
        self.receipt.write_text(json.dumps(self.data))
        self.assertTrue(any('authorization' in error for error in self.check()))
    def test_deleted_consumption_marker_and_source_change_replay_are_rejected(self):
        self.auth_marker.unlink()
        self.assertTrue(any('authorization' in error for error in self.check()))
        self.auth_marker.write_text(self.auth_id + '\n')
        self.script.write_text('changed()')
        self.assertTrue(any('source' in error for error in self.check()))
    def test_authorization_file_hash_and_bound_inputs_are_verified(self):
        self.authorization.write_text('{"authorization_id":"forged"}')
        self.assertTrue(any('authorization' in error for error in self.check()))
    def test_preparation_receipt_tampering_invalidates_cp3_authorization(self):
        self.preparation.write_text('{"changed":true}')
        self.assertTrue(any('preparation receipt' in error for error in self.check()))
    def test_consumption_marker_must_be_the_authorizations_own_marker(self):
        other = self.root/'other.consumed'
        other.write_text(self.auth_id+'\n')
        self.data['authorization_consumption']['marker']={'path':str(other),'sha256':m.digest(other)}
        self.receipt.write_text(json.dumps(self.data))
        self.assertTrue(any('marker path' in error for error in self.check()))
    def test_repository_relative_static_receipt(self):
        receipt = ROOT.parent/'results/reproduction_benchmark/figures/survival.png.render.json'
        artifact = ROOT.parent/'results/reproduction_benchmark/figures/survival.png'
        design = ROOT.parent/'results/reproduction_benchmark/plot_data/survival-design.yaml'
        self.assertTrue(any('authorization' in error for error in m.validate_render_receipt(str(receipt), artifact, design)))
    def test_missing_receipt(self):
        self.receipt.unlink()
        self.assertTrue(self.check())
    def test_changed_script(self):
        self.script.write_text('changed()')
        self.assertTrue(self.check())
    def test_changed_image(self):
        self.artifact.write_bytes(b'changed')
        self.assertTrue(self.check())
    def test_sans_rejected(self):
        self.data['font']['family']='sans'
        self.receipt.write_text(json.dumps(self.data))
        self.assertTrue(self.check())
    def test_missing_check_rejected(self):
        del self.data['checks']['layout']
        self.receipt.write_text(json.dumps(self.data))
        self.assertTrue(self.check())
    def test_tiny_target_text_rejected(self):
        self.data['target_min_text_pt']=3.5
        self.receipt.write_text(json.dumps(self.data))
        self.assertTrue(self.check())
    def test_oversized_canvas_for_size_class_is_rejected(self):
        self.data['target_size']['width_mm']=183
        self.receipt.write_text(json.dumps(self.data))
        self.assertTrue(any('single-column width' in error for error in self.check()))
    def test_other_artifact_rejected(self):
        other=self.root/'other.png'; other.write_bytes(b'other')
        self.assertTrue(m.validate_render_receipt(str(self.receipt),other))
    def test_missing_ggplot_helper(self):
        self.data['renderer']='ggplot2'
        self.receipt.write_text(json.dumps(self.data))
        self.assertTrue(self.check())
    def test_ggplot_actual_scientific_text_is_bound_to_the_authorized_spec(self):
        self._text_receipt()
        self.assertEqual(self.check(), [])
        self.assertEqual(m.validate_render_receipt(str(self.receipt),self.artifact,self.design), [])
    def test_checks_true_and_a_self_approved_note_do_not_pass(self):
        self._text_receipt(labels=['Sample', 'AI-generated figure'])
        self.assertTrue(all(self.data['checks'].values()))
        errors=self.check()
        self.assertTrue(any('prohibited production/audit/disclaimer text' in error for error in errors))
    def test_missing_or_malformed_actual_text_cannot_pass_ggplot_cp3(self):
        self._text_receipt()
        for value in (None, 'Sample', ['Sample', 5], {'label':'Sample'}):
            with self.subTest(value=value):
                self.data['rendered_text']=value
                self.receipt.write_text(json.dumps(self.data))
                self.assertTrue(any('rendered_text must be an array' in error for error in self.check()))
        self.data.pop('rendered_text')
        self.receipt.write_text(json.dumps(self.data))
        self.assertTrue(any('rendered_text must be an array' in error for error in self.check()))
    def test_actual_visible_text_must_be_in_current_spec(self):
        self._text_receipt(labels=['Sample'],rendered=['Sample','n = 7'])
        self.assertTrue(any('unapproved labels' in error for error in self.check()))
    def test_empty_actual_text_array_is_valid_for_a_textless_object(self):
        self._text_receipt(rendered=[])
        self.assertEqual(self.check(), [])
    def test_ggplot_cp3_requires_current_policy_and_scientific_text_check(self):
        self._text_receipt()
        self.data['checks']['scientific_text_only']=False
        self.data['text_policy_id']='legacy-policy'
        self.receipt.write_text(json.dumps(self.data))
        errors=self.check()
        self.assertTrue(any('scientific_text_only' in error for error in errors))
        self.assertTrue(any('text_policy_id' in error for error in errors))
    def test_native_backend_requires_text_policy_without_requiring_ggplot_adapter(self):
        self._text_receipt(labels=['Sample', 'AI note: illustrative'])
        self.data['renderer']='native-grid'
        self.receipt.write_text(json.dumps(self.data))
        self.assertTrue(any('prohibited production/audit/disclaimer text' in error for error in self.check()))
        self._text_receipt(labels=['AI accuracy','AI_001'])
        self.data['renderer']='native-grid'
        self.data.pop('text_policy_id')
        self.data['checks'].pop('scientific_text_only')
        self.receipt.write_text(json.dumps(self.data))
        errors=self.check()
        self.assertTrue(any('text_policy_id' in error for error in errors))
        self.assertTrue(any('scientific_text_only' in error for error in errors))
    def test_legacy_or_modified_style_copy_cannot_claim_current_ggplot_cp3(self):
        helper=self.root/'figure_style.R'
        helper.write_text('legacy_unrestricted_export()')
        self._text_receipt(helper=helper)
        self.assertTrue(any('current canonical figure_style.R' in error for error in self.check()))
    def test_identical_style_copy_is_accepted(self):
        helper=self.root/'figure_style.R'
        helper.write_bytes((ROOT/'scripts/figure_style.R').read_bytes())
        self._text_receipt(helper=helper)
        self.assertEqual(self.check(), [])
    def test_small_text_requires_basis(self):
        self.data['target_min_text_pt']=5.5
        self.receipt.write_text(json.dumps(self.data))
        self.assertTrue(self.check())
    def test_changed_spec(self):
        self.assertEqual(m.validate_render_receipt(str(self.receipt),self.artifact,self.design),[])
        self.design.write_text('changed: true')
        self.assertTrue(m.validate_render_receipt(str(self.receipt),self.artifact,self.design))
    def test_reproduction_receipt_binds_current_corpus(self):
        corpus=self.root/'corpus.json';corpus.write_text('{"cases": []}')
        receipt=self.root/'retrieval.json'
        receipt.write_text(json.dumps({'schema_version':1,'query':'heatmap','corpus':{'path':str(corpus),'sha256':m.digest(corpus)},
            'results':[{'case_id':f'x{i}'} for i in range(3)],
            'generation_contract':{'author_material_access':'forbidden','implementation':'new-script-from-user-data-and-derived-patterns'}}))
        self.assertEqual(m.validate_reproduction_receipt(str(receipt),corpus),[])
        corpus.write_text('changed')
        self.assertTrue(m.validate_reproduction_receipt(str(receipt),corpus))
    def ledger(self):
        definition=m.load(m.DEFINITION)
        entries=[{'id':g['id'],'status':'PASS','evidence':dict.fromkeys(g['required_evidence'],'fixture'),
                  'failures':[],'next_action':'fixture only'} for g in definition['checkpoints']]
        entries[0]['evidence']['unresolved_critical_fields']=[]
        entries[1]['evidence']['sample_mapping_checked']=True
        spec_path=self.root/'design.yaml'
        spec_path.write_text('figure_task: fixture figure\nbiology_contract:\n  primary_domain: imaging-assay\nrole_contract:\n  primary_role: comparison\nbackend_lock:\n  backend: R\ndeliverable_contract:\n  target: quick-png\n  required_formats: [png]\noutput_size:\n  formats: [png]\nreference_evidence:\n  preparation_id: placeholder\n  preparation_request:\n    figure_task: fixture figure\n    figure_family: null\n    data_shape: fixture shape\n    primary_domain: imaging-assay\n    primary_role: comparison\n    backend: R\n    deliverable: quick-png\n  selected_method_case_id: fixture-case\n')
        self.data['sources'].append({'path':str(spec_path),'sha256':m.digest(spec_path)})
        self.receipt.write_text(json.dumps(self.data))
        retrieval=self.root/'retrieval.json'
        retrieval.write_text(json.dumps({'schema_version':1,'query':'fixture','corpus':{'path':str(m.REPRO_CORPUS.resolve()),'sha256':m.digest(m.REPRO_CORPUS)},
            'results':[{'case_id':f'x{i}'} for i in range(3)],'generation_contract':{'author_material_access':'forbidden','implementation':'new-script-from-user-data-and-derived-patterns'}}))
        bound_names=['SKILL.md','manifest.yaml','static/core/execution-contract.yaml','schemas/figure-request.schema.yaml','schemas/figure-design-spec.schema.yaml',
            'checkpoints/checkpoints.yaml','scripts/prepare_figure.py','scripts/route_figure.py',
            'scripts/plan_figure_method.py','scripts/retrieve_reproduction.py','scripts/retrieve_scidraw.py',
            'scripts/retrieve_capabilities.py','scripts/retrieve_references.py','scripts/benchmark_core.py',
            'scripts/validate_design_spec.py','scripts/validate_checkpoints.py','atlas/reproduction-derived-corpus.json',
            'atlas/reproduction-methods.json','atlas/scidraw-derived-corpus.json','atlas/scidraw-visual-grammar.yaml',
            'atlas/scidraw-source-compared-methods.json','atlas/scidraw-review-evidence.json',
            'atlas/scidraw-batch2-methods.json','atlas/scidraw-batch2-review-evidence.json',
            'atlas/scidraw-learning-ten-20260925.json','atlas/scidraw-learning-ten-20260925-02.json',
            'atlas/top-journal-corpus.yaml','atlas/unified-capability-graph.json',
            'atlas/family-execution-contracts.yaml','atlas/index.yaml','patterns/index.yaml','renderer-registry.yaml','benchmark/registry.json']
        preparation={'schema_version':1,'status':'PREFLIGHT_COMPLETE','code_gate':'BLOCKED_UNTIL_REFERENCE_ANALYSIS_AND_CP2',
            'request':{'figure_task':'fixture figure','figure_family':None,'data_shape':'fixture shape',
                'primary_domain':'imaging-assay','primary_role':'comparison','backend':'R','deliverable':'quick-png'},
            'route':{'modules':[],'reference_evidence_layers':{'reproduction':{},'top_journal':{},'scidraw':{}}},
            'selected_reference_candidates':{'planner_selected':'fixture-case'},
            'source_hashes':{name:m.digest(ROOT/name) for name in bound_names},'missing_material':[],
            'method_plan':{'selected_case':{'case_id':'fixture-case'}}}
        from reuse_templates import retrieve as retrieve_templates
        from retrieve_learned_methods import retrieve as retrieve_learning
        from prepare_figure import finalize_receipt
        new_material = ['atlas/reusable-template-index.json','scripts/reuse_templates.py','scripts/run_template_replay.py',
                        'references/stable-template-reuse.md','atlas/learned-method-index.json','scripts/retrieve_learned_methods.py',
                        'scripts/build_learned_method_index.py','references/all-learning-transfer.md',
                        'scripts/learning_materials.py','references/all-learning-audit-defects.md',
                        'atlas/learned-method-validations.json','scripts/validate_learned_reuse.py','atlas/source-syntax-audit.json']
        preparation['source_hashes'].update({name:m.digest(ROOT/name) for name in new_material})
        preparation['query']='fixture figure fixture shape'
        preparation['reusable_templates']=retrieve_templates(preparation['request'])
        preparation['learned_methods']=retrieve_learning(preparation['query'])
        preparation=finalize_receipt(preparation)
        spec_doc=m.load(spec_path)
        spec_doc['text_contract']={'allowed_text':['Sample'],'allow_headings':False,'footer_policy':'outside-only'}
        spec_doc['reference_evidence']['learned_method_reuse']={'adopted':[],'rejected':[
            {'method_id':x['method_id'],'reason':'orchestration fixture; no source adaptation rendered'}
            for x in preparation['learned_methods']['results']]}
        spec_path.write_text(__import__('yaml').safe_dump(spec_doc))
        spec_path.write_text(spec_path.read_text().replace('placeholder',preparation['preparation_id']))
        self.data['sources'][-1]={'path':str(spec_path),'sha256':m.digest(spec_path)}
        self.receipt.write_text(json.dumps(self.data))
        preparation_path=self.root/'preparation.json'; preparation_path.write_text(json.dumps(preparation,ensure_ascii=False))
        self._bind_authorization(preparation_path,spec_path)
        entries[2]['evidence'].update(design_spec=str(spec_path),design_spec_validation='PASS',renderer_available=True,layout_slots_reserved=True,reference_method_receipt=str(retrieval),preparation_receipt=str(preparation_path))
        entries[3]['evidence'].update(artifact=str(self.artifact),artifact_sha256=m.digest(self.artifact),
            render_receipt=str(self.receipt),artifact_opened=True,viewer_method='direct-open',target_size_checked=True,
            first_render={'path':str(self.artifact),'sha256':m.digest(self.artifact)},first_render_sha256=m.digest(self.artifact),
            target_size={'width_mm':90,'height_mm':75},detected=dict.fromkeys(m.DETECTED_KEYS,False))
        inspection=self.root/'inspection.yaml'
        inspection.write_text(json.dumps({'artifact_sha256':m.digest(self.artifact),
            'render_receipt_sha256':m.digest(self.receipt),
            'artifact_path':str(self.artifact.resolve()),'first_render_path':str(self.artifact.resolve()),
            'first_render_sha256':m.digest(self.artifact),'target_size':{'width_mm':90,'height_mm':75},
            'reviewer_type':'human','reviewer_id':'fixture-reviewer','judgment':'PASS',
            'defect_coordinates':[],'viewer_method':'direct-open','revision_count':0,
            'final_size_checks':{'target_size_opened':True,'checks':{
                key:{'status':'PASS','evidence':f'{key} checked on final-size PNG','colored_data_marks':True}
                for key in ('typography_size','typography_position','label_overlap',
                            'legend_overlap','clipping','panel_alignment',
                            'figure_text_proportion', 'semantic_color', 'footer_absent')}}}))
        entries[4]['evidence'].update(critic_status='PASS',qa_status='PASS',simulation_disclosed=True,
            reviewer_type='human',reviewer_id='fixture-reviewer',inspection_evidence=str(inspection),deliverables=[{'path':str(self.artifact),'sha256':m.digest(self.artifact)}])
        return {'schema_version':1,'artifact_id':'fixture','mode':'standard','checkpoints':entries},definition
    def test_gate_invokes_full_critics_and_domain(self):
        ledger,definition=self.ledger()
        # Tests orchestration only; fixture is deliberately not a valid scientific Spec.
        with patch.object(m.subprocess,'run',return_value=SimpleNamespace(returncode=0,stdout='',stderr='')) as run:
            self.assertEqual(m.validate(ledger,definition),[])
        commands=[c.args[0] for c in run.call_args_list]
        self.assertIn('validate_design_spec.py',commands[0][1])
        self.assertIn('publication',commands[1]); self.assertIn('imaging-assay',commands[1])
        self.assertIn('--render-receipt', commands[1])
    def test_preparation_receipt_tampering_is_rejected(self):
        ledger,definition=self.ledger()
        cp2=ledger['checkpoints'][2]['evidence']
        prep=Path(cp2['preparation_receipt'])
        payload=json.loads(prep.read_text())
        payload['request']['figure_task']='different figure'
        prep.write_text(json.dumps(payload))
        spec={'figure_task':'fixture figure','biology_contract':{'primary_domain':'imaging-assay'},
              'role_contract':{'primary_role':'comparison'},
              'backend_lock':{'backend':'R'},'reference_evidence':{'preparation_id':payload['preparation_id'],
                  'preparation_request':payload['request'],
                  'selected_method_case_id':'fixture-case'}}
        errors=m.validate_preparation_receipt(str(prep),spec)
        self.assertTrue(any('integrity hash invalid' in error for error in errors))
    def test_self_reported_pass_cannot_override_failed_validator(self):
        ledger,definition=self.ledger()
        with patch.object(m.subprocess,'run',return_value=SimpleNamespace(returncode=1,stdout='REVISE',stderr='')):
            errors=m.validate(ledger,definition)
        self.assertTrue(any('CP2 actual' in e for e in errors))
        self.assertTrue(any('CP4 actual' in e for e in errors))

if __name__ == '__main__': unittest.main()

class ReproductionAccessTests(unittest.TestCase):
    def test_one_reference_and_authorized_inspection(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d); corpus=root/'corpus.json'; corpus.write_text('{}')
            receipt=root/'receipt.json'
            value={'schema_version':1,'query':'forest', 'corpus':{'path':str(corpus),'sha256':m.digest(corpus)},'results':[{'case_id':'test'}], 'generation_contract':{'author_material_access':'authorized-inspection-no-copy','implementation':'new-script-from-user-data-and-derived-patterns'}}
            receipt.write_text(json.dumps(value))
            self.assertEqual(m.validate_reproduction_receipt(str(receipt),corpus),[])
            value['generation_contract']['blind_generation']=True
            receipt.write_text(json.dumps(value))
            self.assertTrue(m.validate_reproduction_receipt(str(receipt),corpus))
            value['generation_contract']['blind_generation']=False
            value['results']=[]
            receipt.write_text(json.dumps(value))
            self.assertTrue(m.validate_reproduction_receipt(str(receipt),corpus))

    def test_primary_source_lock_can_bind_new_author_figure_method(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            files=[]
            for role,name,content in [('figure_asset','reference.png',b'figure'),('author_code','Figure2b.R',b'ggplot code'),('source_data','source.xlsx',b'xlsx'),('analysis_input','plot.csv',b'csv')]:
                p=root/name; p.write_bytes(content)
                files.append({'role':role,'path':name,'sha256':m.digest(p)})
            receipt=root/'source-lock.json'
            value={'schema_version':1,'kind':'primary-source-lock','query':'100% stacked composition bar',
                'project_root':str(root.resolve()),
                'primary_source':{'title':'Populus genome evolution','doi':'10.1038/s41559-026-03069-3',
                    'url':'https://www.nature.com/articles/s41559-026-03069-3','figure':'2','panel':'b'},
                'source_files':files,
                'source_mapping':[{'panel':'2b','author_code':'author_code','source_data':'source_data','analysis_input':'analysis_input'}],
                'inspection':{'original_figure_opened':True},
                'generation_contract':{'author_material_access':'authorized-inspection-no-copy',
                    'implementation':'new-script-from-user-data-and-derived-patterns','blind_generation':False}}
            receipt.write_text(json.dumps(value))
            self.assertEqual(m.validate_reproduction_receipt(str(receipt),root=root),[])

    def test_primary_source_lock_rejects_modified_source_asset(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            records=[]
            for role,name in [('figure_asset','reference.png'),('author_code','Figure2b.R'),('source_data','source.xlsx')]:
                p=root/name; p.write_text(role)
                records.append({'role':role,'path':name,'sha256':m.digest(p)})
            receipt=root/'source-lock.json'
            receipt.write_text(json.dumps({'schema_version':1,'kind':'primary-source-lock','query':'figure',
                'project_root':str(root.resolve()),'primary_source':{'title':'Paper','doi':'10.1038/test','url':'https://example.org','figure':'2','panel':'b'},
                'source_files':records,'source_mapping':[{'panel':'2b','author_code':'author_code','source_data':'source_data'}],
                'inspection':{'original_figure_opened':True},'generation_contract':{'author_material_access':'authorized-inspection-no-copy',
                    'implementation':'new-script-from-user-data-and-derived-patterns','blind_generation':False}}))
            self.assertEqual(m.validate_reproduction_receipt(str(receipt),root=root),[])
            (root/'reference.png').write_text('changed')
            self.assertTrue(m.validate_reproduction_receipt(str(receipt),root=root))
