import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('checkpoints', ROOT/'scripts/validate_checkpoints.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

class ReceiptTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.artifact = self.root/'figure.png'
        self.artifact.write_bytes(b'fixture: hash validation only, not visual evidence')
        self.script = self.root/'plot.R'
        self.script.write_text('render()')
        self.font = self.root/'Arial.ttf'
        self.font.write_bytes(b'fixture font')
        self.receipt = self.root/'receipt.json'
        def bound(p):
            return {'path':str(p), 'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
        self.data = {'schema_version':1, 'status':'PASS', 'backend':'R',
                     'artifact':bound(self.artifact), 'sources':[bound(self.script)],
                     'font':dict(bound(self.font), family='Arial'),
                     'checks':{k:True for k in ('font','text_allowlist','layout','target_size')},
                     'target_min_text_pt':7}
        self.receipt.write_text(json.dumps(self.data))
    def check(self):
        return m.validate_render_receipt(str(self.receipt), self.artifact)
    def test_valid_bound_receipt(self):
        self.assertEqual(self.check(), [])
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
    def test_other_artifact_rejected(self):
        other=self.root/'other.png'; other.write_bytes(b'other')
        self.assertTrue(m.validate_render_receipt(str(self.receipt),other))
    def test_missing_ggplot_helper(self):
        self.data['renderer']='ggplot2'
        self.receipt.write_text(json.dumps(self.data))
        self.assertTrue(self.check())
    def test_small_text_requires_basis(self):
        self.data['target_min_text_pt']=5.5
        self.receipt.write_text(json.dumps(self.data))
        self.assertTrue(self.check())
    def test_changed_spec(self):
        spec_path=self.root/'design.yaml'; spec_path.write_text('fixture: true')
        self.data['sources'].append({'path':str(spec_path),'sha256':m.digest(spec_path)})
        self.receipt.write_text(json.dumps(self.data))
        self.assertEqual(m.validate_render_receipt(str(self.receipt),self.artifact,spec_path),[])
        spec_path.write_text('changed: true')
        self.assertTrue(m.validate_render_receipt(str(self.receipt),self.artifact,spec_path))
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
        spec_path.write_text('biology_contract:\n  primary_domain: imaging-assay\n')
        self.data['sources'].append({'path':str(spec_path),'sha256':m.digest(spec_path)})
        self.receipt.write_text(json.dumps(self.data))
        retrieval=self.root/'retrieval.json'
        retrieval.write_text(json.dumps({'schema_version':1,'query':'fixture','corpus':{'path':str(m.REPRO_CORPUS.resolve()),'sha256':m.digest(m.REPRO_CORPUS)},
            'results':[{'case_id':f'x{i}'} for i in range(3)],'generation_contract':{'author_material_access':'forbidden','implementation':'new-script-from-user-data-and-derived-patterns'}}))
        entries[2]['evidence'].update(design_spec=str(spec_path),design_spec_validation='PASS',renderer_available=True,layout_slots_reserved=True,reproduction_retrieval_receipt=str(retrieval))
        entries[3]['evidence'].update(artifact=str(self.artifact),artifact_sha256=m.digest(self.artifact),
            render_receipt=str(self.receipt),artifact_opened=True,viewer_method='direct-open',target_size_checked=True,
            detected=dict.fromkeys(m.DETECTED_KEYS,False))
        entries[4]['evidence'].update(critic_status='PASS',qa_status='PASS',simulation_disclosed=True,
            deliverables=[{'path':str(self.artifact),'sha256':m.digest(self.artifact)}])
        return {'schema_version':1,'artifact_id':'fixture','mode':'standard','checkpoints':entries},definition
    def test_gate_invokes_full_critics_and_domain(self):
        ledger,definition=self.ledger()
        # Tests orchestration only; fixture is deliberately not a valid scientific Spec.
        with patch.object(m.subprocess,'run',return_value=SimpleNamespace(returncode=0,stdout='',stderr='')) as run:
            self.assertEqual(m.validate(ledger,definition),[])
        commands=[c.args[0] for c in run.call_args_list]
        self.assertIn('validate_design_spec.py',commands[0][1])
        self.assertIn('publication',commands[1]); self.assertIn('imaging-assay',commands[1])
    def test_self_reported_pass_cannot_override_failed_validator(self):
        ledger,definition=self.ledger()
        with patch.object(m.subprocess,'run',return_value=SimpleNamespace(returncode=1,stdout='REVISE',stderr='')):
            errors=m.validate(ledger,definition)
        self.assertTrue(any('CP2 actual' in e for e in errors))
        self.assertTrue(any('CP4 actual' in e for e in errors))

if __name__ == '__main__': unittest.main()
