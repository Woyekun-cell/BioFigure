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
  self.assertEqual(payload['generation_contract']['author_material_access'],'forbidden')
  self.assertEqual(payload['generation_contract']['technique_transfer'],'abstract-patterns-only')
  self.assertNotIn('source_code',str(payload))
if __name__=='__main__':unittest.main()
