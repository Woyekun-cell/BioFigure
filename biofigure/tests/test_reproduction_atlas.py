import importlib.util, json, tempfile, unittest
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('builder',ROOT/'scripts/build_reproduction_atlas.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)

class ReproductionAtlasTests(unittest.TestCase):
 def test_code_analysis_contains_features_not_source(self):
  result=m.analyze_code_texts([('plot.R','library(ggplot2)\nggplot(d)+geom_point(color="#336699")')])
  self.assertIn('ggplot2',result['packages']);self.assertIn('geom_point',result['primitives'])
  self.assertIn('layered-grammar',result['coding_techniques'])
  self.assertIn('explicit-palette',result['coding_techniques'])
  self.assertNotIn('source_code',result);self.assertNotIn('ggplot(d)',json.dumps(result))
 def test_visual_card_has_roles_claims_and_hash(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'x.png';Image.new('RGB',(80,120),'white').save(p)
   card=m.visual_profile(p,'Nature原图 复现图 适合展示趋势')
   self.assertEqual(len(card['sha256']),64);self.assertTrue(card['palette_roles'])
   self.assertIn('trend-display',card['source_claim_tags'])
 def test_title_taxonomy(self):
  self.assertIn('matrix',m.chart_tags('带注释的热图'))
  self.assertIn('time-to-event',m.chart_tags('生存曲线'))
 def test_all_available_cases_have_package_first_methods(self):
  doc=json.loads((ROOT/'atlas/reproduction-methods.json').read_text())
  self.assertEqual(doc['coverage']['available_cases'],79)
  self.assertEqual(doc['coverage']['missing_issues'],[30])
  self.assertTrue(doc['policy']['specialized_package_first'])
  self.assertTrue(all('core_packages' in x and 'key_functions' in x for x in doc['cases']))
 def test_high_fidelity_status_requires_review_field(self):
  doc=json.loads((ROOT/'atlas/reproduction-methods.json').read_text())
  eligible=[x for x in doc['cases'] if x.get('runtime_status')=='source-compared-png' and x.get('review_status')=='pass']
  self.assertTrue(eligible)
  self.assertTrue(all(x.get('validated_pngs') for x in eligible))

if __name__=='__main__':unittest.main()
