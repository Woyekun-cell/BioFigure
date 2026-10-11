import importlib.util
import tempfile
import unittest
import copy
import sys
from pathlib import Path
from argparse import Namespace
import yaml
from PIL import Image, ImageDraw
s=importlib.util.spec_from_file_location('critics',Path(__file__).resolve().parents[1]/'scripts/run_critics.py')
m=importlib.util.module_from_spec(s); s.loader.exec_module(m)
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
class CriticsTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.art=Path(self.tmp.name)/'figure.png'
        im=Image.new('RGB',(300,300),'white'); ImageDraw.Draw(im).rectangle((30,30,70,270),fill='navy'); im.save(self.art)
        self.ev={'artifact':str(self.art),'artifact_sha256':m.sha256(self.art),'artifact_opened':True,'inspected_at':'2026-09-08','inspector':'test-fixture-only',
         'viewer_record':{'method':'direct-open','opened_artifact_sha256':m.sha256(self.art)},
         'visual_evidence':{k:{'observation':k+' fixture observations for protocol validation only, not evidence of an actual human review.'} for k in ['hierarchy','whitespace','legend','title_discipline']},
         'detected':{k:False for k in ['clipping','overlap','missing_glyph','legend_overlap','non_white_background','font_fallback','unrequested_text','small_text','text_position','label_overlap','panel_misalignment']},'issues':[],
         'critic_reviews':{'scientific':{'status':'PASS','evidence':'Synthetic protocol fixture only; no scientific claim is evaluated.'}}}
    def run_case(self, pattern='MAT-EXPR-001', design_spec=None):
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
