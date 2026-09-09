import importlib.util
import unittest
from pathlib import Path
s=importlib.util.spec_from_file_location('retrieval',Path(__file__).resolve().parents[1]/'scripts/retrieve_scidraw.py')
m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class RetrievalTests(unittest.TestCase):
 def test_unknown_query_does_not_recommend_unrelated_cases(self):
  self.assertEqual(m.retrieve('no_matching_scientific_task_9471')['results'],[])
 def test_case_returns_actual_image_candidates_and_uncertainty(self):
  result=m.retrieve('气泡热图')['results'][0]
  self.assertIn('气泡',result['title'])
  self.assertTrue(result['requires_actual_image_review'])
  self.assertTrue(result['visual_candidates'])
  self.assertNotEqual(result['visual_match']['status'],'matched')
if __name__=='__main__':unittest.main()
