import importlib.util
import tempfile
import unittest
from pathlib import Path
from argparse import Namespace
import yaml
from PIL import Image, ImageDraw
s=importlib.util.spec_from_file_location('critics',Path(__file__).resolve().parents[1]/'scripts/run_critics.py')
m=importlib.util.module_from_spec(s); s.loader.exec_module(m)
class CriticsTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.art=Path(self.tmp.name)/'figure.png'
        im=Image.new('RGB',(300,300),'white'); ImageDraw.Draw(im).rectangle((30,30,70,270),fill='navy'); im.save(self.art)
        self.ev={'artifact':str(self.art),'artifact_sha256':m.sha256(self.art),'artifact_opened':True,'inspected_at':'2026-09-08','inspector':'test-fixture-only',
         'viewer_record':{'method':'direct-open','opened_artifact_sha256':m.sha256(self.art)},
         'visual_evidence':{k:{'observation':k+' fixture observations for protocol validation only, not evidence of an actual human review.'} for k in ['hierarchy','whitespace','legend','title_discipline']},
         'detected':{k:False for k in ['clipping','overlap','missing_glyph','legend_overlap','non_white_background','font_fallback','unrequested_text']},'issues':[],
         'critic_reviews':{'scientific':{'status':'PASS','evidence':'Synthetic protocol fixture only; no scientific claim is evaluated.'}}}
    def run_case(self):
        p=Path(self.tmp.name)/'evidence.yaml'; p.write_text(yaml.safe_dump(self.ev))
        return m.run(Namespace(artifact=str(self.art),pattern='MAT-EXPR-001',mode='standard',inspection_evidence=str(p),design_spec=None,domain=[]))
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
