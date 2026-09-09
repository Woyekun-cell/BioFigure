import importlib.util
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
if __name__=='__main__':unittest.main()
