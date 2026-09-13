import importlib.util, unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('retriever',ROOT/'scripts/retrieve_reproduction.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class RetrievalTests(unittest.TestCase):
 def test_heatmap_query_prefers_matrix(self):
  cases=[{'case_id':'a','title':'热图','chart_tags':['matrix'],'advantage_tags':['dense-comparison'],'code_analysis':{'packages':['ComplexHeatmap'],'primitives':['Heatmap']}},
         {'case_id':'b','title':'生存曲线','chart_tags':['time-to-event'],'advantage_tags':[],'code_analysis':{'packages':['survival'],'primitives':[]}}]
  self.assertGreater(m.score_case(cases[0],'带注释热图 ComplexHeatmap'),m.score_case(cases[1],'带注释热图 ComplexHeatmap'))
 def test_result_forbids_source_copy(self):
  payload=m.rank_cases([{'case_id':'a','title':'热图','chart_tags':['matrix'],'advantage_tags':[],'code_analysis':{'packages':[],'primitives':[]}}],'热图',5)
  self.assertEqual(payload['generation_contract']['author_material_access'],'authorized-inspection-no-copy')
  self.assertEqual(payload['generation_contract']['technique_transfer'],'abstract-patterns-and-method-structure')
  self.assertNotIn('source_code',str(payload))
 def test_live_retrieval_returns_package_method(self):
  payload=m.retrieve('生存曲线')
  self.assertIn('package_method',payload['results'][0])
  self.assertIn('ggsurvfit',payload['results'][0]['package_method']['core_packages'])
 def test_validated_mode_never_returns_incomplete_precedent(self):
  payload=m.retrieve('热图 临床 环形 泳道',limit=20,require_validated=True)
  self.assertTrue(payload['results'])
  self.assertTrue(all(x['high_fidelity_eligible'] for x in payload['results']))
  self.assertTrue(all(x['package_method']['runtime_status']=='source-compared-png' for x in payload['results']))
  self.assertTrue(all(x['package_method']['review_status']=='pass' for x in payload['results']))
if __name__=='__main__':unittest.main()
