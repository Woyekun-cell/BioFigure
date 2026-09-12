import importlib.util
import json
import unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('builder',Path(__file__).resolve().parents[1]/'scripts/build_scidraw_atlas.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class CardTests(unittest.TestCase):
 def test_images_bind_to_own_card_not_previous_heading(self):
  page='<h2>Plots</h2><h3>Old heading</h3><div class="project-card"><div><img src="a.png"><br></div><h3>Radar</h3><a href="https://mp.weixin.qq.com/s/a">Code</a></div><div class="project-card"><img src="b.png"><h3>Tree</h3></div>'
  items=m.parse_inventory(page,'https://example.org/')
  self.assertEqual([(i['heading'],i['src']) for i in items],[('Radar','https://example.org/a.png'),('Tree','https://example.org/b.png')])
  self.assertEqual(items[0]['source_url'],'https://mp.weixin.qq.com/s/a')
  self.assertEqual(items[1]['source_url'],'')
 def test_source_compared_methods_lock_specialized_packages_and_alignment(self):
  root=Path(__file__).resolve().parents[1]
  doc=json.loads((root/'atlas/scidraw-source-compared-methods.json').read_text())
  by_id={x['id']:x for x in doc['cases']}
  self.assertIn('rms',by_id['SCIDRAW-RCS-001']['packages'])
  self.assertIn('do-not-substitute-geom-smooth',by_id['SCIDRAW-RCS-001']['guardrails'])
  self.assertIn('ggridges',by_id['SCIDRAW-RIDGE-BIPOLAR-001']['packages'])
  self.assertIn('category-factor-order',by_id['SCIDRAW-RIDGE-BIPOLAR-001']['shared_keys'])
  self.assertEqual(by_id['SCIDRAW-RCS-001']['runtime_status'],'source-compared-png')
  self.assertEqual(by_id['SCIDRAW-RIDGE-BIPOLAR-001']['runtime_status'],'source-compared-png')
  self.assertEqual(by_id['SCIDRAW-PCOA-MARGINAL-001']['runtime_status'],'source-compared-png-renderer-exception')
  entry=(root/'SKILL.md').read_text()
  self.assertIn('atlas/scidraw-source-compared-methods.json',entry)
  self.assertIn('命中`source-compared-png`案例时优先采用',entry)
if __name__=='__main__':unittest.main()
