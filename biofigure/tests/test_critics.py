import importlib.util
import tempfile
import unittest
import copy
import sys
import json
from pathlib import Path
from argparse import Namespace
import yaml
from PIL import Image, ImageDraw
s=importlib.util.spec_from_file_location('critics',Path(__file__).resolve().parents[1]/'scripts/run_critics.py')
m=importlib.util.module_from_spec(s); s.loader.exec_module(m)
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
class CriticsTests(unittest.TestCase):
    def test_same_artifact_with_new_render_receipt_requires_fresh_inspection(self):
        receipt = Path(str(self.art) + '.render.json')
        document = {'inspection_binding_policy': 'render-receipt-sha256-v1',
                    'artifact': {'sha256': m.sha256(self.art)},
                    'authorization_consumption': {'authorization_id': 'a' * 64}}
        receipt.write_text(json.dumps(document))
        self.ev['render_receipt_sha256'] = m.sha256(receipt)
        current = self.run_case()
        self.assertEqual(current['status'], 'PASS', current)
        self.assertTrue(current['inspection']['current_render_inspection_verified'])
        document['authorization_consumption']['authorization_id'] = 'b' * 64
        receipt.write_text(json.dumps(document))
        stale = self.run_case()
        self.assertEqual(stale['status'], 'FAIL', stale)
        self.assertFalse(stale['inspection']['current_render_inspection_verified'])
        self.assertTrue(any(row['issue'] == 'inspection_render_binding_invalid' for row in stale['hard_failures']))
        self.ev['render_receipt_sha256'] = m.sha256(receipt)
        self.assertEqual(self.run_case()['status'], 'PASS')

    def test_legacy_inspection_does_not_claim_current_render_verification(self):
        result = self.run_case()
        self.assertEqual(result['status'], 'PASS', result)
        self.assertFalse(result['inspection']['current_render_inspection_verified'])

    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.art=Path(self.tmp.name)/'figure.png'
        im=Image.new('RGB',(300,300),'white'); ImageDraw.Draw(im).rectangle((30,30,70,270),fill='navy'); im.save(self.art)
        self.ev={'artifact':str(self.art),'artifact_sha256':m.sha256(self.art),'artifact_opened':True,'inspected_at':'2026-09-08','inspector':'test-fixture-only',
         'viewer_record':{'method':'direct-open','opened_artifact_sha256':m.sha256(self.art)},
         'visual_evidence':{k:{'observation':k+' fixture observations for protocol validation only, not evidence of an actual human review.'} for k in ['hierarchy','whitespace','legend','title_discipline']},
         'detected':{k:False for k in ['clipping','overlap','missing_glyph','legend_overlap','non_white_background','font_fallback','unrequested_text','small_text','text_position','label_overlap','panel_misalignment','footer_text']},'issues':[],
         'rendered_text':[],
         'critic_reviews':{'scientific':{'status':'PASS','evidence':'Synthetic protocol fixture only; no scientific claim is evaluated.'}}}
    def run_case(self, pattern='DIST-BOX-001', design_spec=None):
        p=Path(self.tmp.name)/'evidence.yaml'; p.write_text(yaml.safe_dump(self.ev))
        return m.run(Namespace(artifact=str(self.art),pattern=pattern,mode='standard',inspection_evidence=str(p),design_spec=design_spec,domain=[]))

    def learned_spec(self):
        from retrieve_learned_methods import retrieve
        entry = retrieve('', case_id='SCICASE-007')['results'][0]
        asset = 'benchmark/library/scidraw/sources/06_half_violin_box_points_source.jpg'
        return {'selected_pattern': 'LEARNED-SCICASE-007', 'reference_evidence': {
            'selected_method_case_id': 'SCICASE-007', 'learned_source_reference': {
                'method_id': 'SCICASE-007', 'source_record_sha256': entry['source_sha256'],
                'read_hashes': entry['current_read_hashes'], 'opened_source_asset': {
                    'path': asset, 'sha256': entry['current_read_hashes'][asset], 'original_size_viewed': True}}}}

    def test_current_bound_learned_pattern_is_accepted(self):
        spec = Path(self.tmp.name)/'spec.yaml'; spec.write_text(yaml.safe_dump(self.learned_spec()))
        result = self.run_case('LEARNED-SCICASE-007', str(spec))
        self.assertEqual(result['status'], 'PASS', result)

    def test_stale_learned_binding_and_unviewed_source_are_rejected(self):
        for key in ('hash', 'view'):
            doc = copy.deepcopy(self.learned_spec())
            binding = doc['reference_evidence']['learned_source_reference']
            if key == 'hash':
                binding['source_record_sha256'] = '0'*64
            else:
                binding['opened_source_asset']['original_size_viewed'] = False
            spec = Path(self.tmp.name)/'spec.yaml'; spec.write_text(yaml.safe_dump(doc))
            result = self.run_case('LEARNED-SCICASE-007', str(spec))
            self.assertEqual(result['status'], 'FAIL')

    def test_learned_prefix_without_valid_binding_is_not_a_whitelist(self):
        result = self.run_case('LEARNED-SCICASE-007')
        self.assertEqual(result['status'], 'FAIL')
    def test_coloured_data_not_grey_background(self):
        im=Image.open(self.art); ImageDraw.Draw(im).rectangle((30,30,270,270),fill='navy'); im.save(self.art)
        self.ev['artifact_sha256']=m.sha256(self.art)
        self.ev['viewer_record']['opened_artifact_sha256']=m.sha256(self.art)
        self.assertEqual(self.run_case()['status'],'PASS')
    def test_fallback_blocks_pass(self):
        self.ev['detected']['font_fallback']=True
        self.assertNotEqual(self.run_case()['status'],'PASS')
    def test_unrequested_text_blocks_pass(self):
        self.ev['detected']['unrequested_text']=True
        self.assertNotEqual(self.run_case()['status'],'PASS')
    def test_footer_observation_and_screenshot_text_block_pass(self):
        self.ev['detected']['footer_text']=True
        self.assertNotEqual(self.run_case()['status'],'PASS')
        self.ev['detected']['footer_text']=False
        self.ev['rendered_text']=['n = 8 fish per group; infection day 12']
        self.assertNotEqual(self.run_case()['status'],'PASS')
    def test_heatmap_visual_pass_requires_actual_cell_geometry_observation(self):
        spec=Path(self.tmp.name)/'heatmap.yaml'
        doc={'selected_pattern':'MAT-EXPR-001','heatmap_cell_contract':{
            'policy_id':'heatmap-cells-v1','shape':'square','rows':8,'columns':4,
            'measurement_basis':'final_body_viewports_mm','max_relative_error':.01}}
        spec.write_text(yaml.safe_dump(doc))
        result=self.run_case(pattern='MAT-EXPR-001',design_spec=str(spec))
        self.assertNotEqual(result['status'],'PASS')
        self.assertTrue(any(row['issue']=='heatmap_cell_observation_missing' for row in result['hard_failures']))
        self.ev['heatmap_cells']=[{'panel_id':'expr-1-1','rows':8,'columns':4,
            'body_width_mm':20,'body_height_mm':40,'cell_width_mm':5,'cell_height_mm':5,
            'measurement_method':'final_body_viewports_mm'}]
        self.ev['visual_evidence']['cell_geometry']={
            'status':'PASS','observation':'All displayed cells inspected at final output size; each body cell is 5 by 5 mm, excluding the legend and annotation strip.'}
        self.assertEqual(self.run_case(pattern='MAT-EXPR-001',design_spec=str(spec))['status'],'PASS')
        self.ev['heatmap_cells'][0]['body_height_mm']=32
        self.assertNotEqual(self.run_case(pattern='MAT-EXPR-001',design_spec=str(spec))['status'],'PASS')
    def test_reported_actual_ai_note_blocks_false_clean_inspection(self):
        self.ev['rendered_text']=['Dose (mg)', 'AI insight: publication-ready plot']
        result=self.run_case()
        self.assertEqual(result['status'],'FAIL')
        self.assertTrue(any(row['issue']=='prohibited_figure_text' for row in result['hard_failures']))
    def test_scientific_actual_text_and_external_audit_notes_remain_valid(self):
        self.ev['rendered_text']=['AI accuracy', 'AI_001', 'n = 6', 'P = 0.01', 'Scale bar: 50 μm']
        self.ev['audit_note']='Generated by ChatGPT; CP2 PASS. Kept outside the figure.'
        self.assertEqual(self.run_case()['status'],'PASS')
    def test_critic_rejects_self_approved_ai_note_in_design(self):
        spec=Path(self.tmp.name)/'spec.yaml'
        spec.write_text(yaml.safe_dump({'selected_pattern':'MAT-EXPR-001',
            'text_contract':{'allowed_text':['AI note: for illustration only'], 'allow_headings':True}}))
        result=self.run_case(design_spec=str(spec))
        self.assertEqual(result['status'],'FAIL')
        self.assertTrue(any(row['issue']=='prohibited_figure_text' for row in result['hard_failures']))
    def test_malformed_actual_text_cannot_receive_pass(self):
        self.ev['rendered_text']='Dose (mg)'
        self.assertEqual(self.run_case()['status'],'FAIL')
    def test_small_or_mispositioned_text_blocks_pass(self):
        for defect in ('small_text','text_position','label_overlap','panel_misalignment'):
            with self.subTest(defect=defect):
                self.ev['detected'][defect]=True
                self.assertNotEqual(self.run_case()['status'],'PASS')
                self.ev['detected'][defect]=False
    def test_missing_scientific_review(self):
        self.ev.pop('critic_reviews')
        result=self.run_case()
        self.assertNotEqual(result['status'],'PASS')
        self.assertEqual(result['scores']['scientific']['result'],'NOT_ASSESSED')
    def test_malformed_evidence_does_not_crash(self):
        self.ev=[]
        self.assertEqual(self.run_case()['status'],'FAIL')
    def test_reported_scientific_failure(self):
        self.ev['critic_reviews']['scientific']['status']='FAIL'
        self.assertNotEqual(self.run_case()['status'],'PASS')
if __name__=='__main__': unittest.main()
