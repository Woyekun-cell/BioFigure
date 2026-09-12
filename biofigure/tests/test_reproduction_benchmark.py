import importlib.util,tempfile,unittest,yaml,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('bench',ROOT/'scripts/run_reproduction_benchmark.py');m=importlib.util.module_from_spec(spec);spec_STA=spec.loader.exec_module(m)
class BenchmarkTests(unittest.TestCase):
 def test_six_natural_language_tasks_hide_author_code(self):
  tasks=yaml.safe_load((ROOT/'benchmark/reproduction/tasks.yaml').read_text())['tasks']
  self.assertEqual(len(tasks),6)
  self.assertTrue(all(t['input_mode']=='natural-language-plus-data-contract' for t in tasks))
  self.assertTrue(all('source_code' not in json.dumps(t) for t in tasks))
 def test_missing_artifacts_fail(self):
  with tempfile.TemporaryDirectory() as d:
   result=m.audit_outputs(Path(d),['survival'])
   self.assertEqual(result['status'],'FAIL')
if __name__=='__main__':unittest.main()
