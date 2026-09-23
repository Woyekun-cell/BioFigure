import importlib.util
import unittest
from pathlib import Path
import yaml
root=Path(__file__).resolve().parents[1]
s=importlib.util.spec_from_file_location('spec',root/'scripts/validate_design_spec.py')
m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
schema=yaml.safe_load((root/'schemas/figure-design-spec.schema.yaml').read_text())
class DesignTests(unittest.TestCase):
 def reference_analysis(self):
  return {
   'figure_family':'multi-track circular heatmap',
   'semantic_purpose':'compare aligned measurements and set membership by feature',
   'panels':[{'id':'main','role':'primary evidence','position':'full canvas'}],
   'elements':[
    {'id':'heatmap','role':'primary matrix','geometry':'concentric tiles','position':'outer tracks','data_mapping':'feature by assay value','required':True},
    {'id':'upset','role':'set intersections','geometry':'bar and dot matrix','position':'center','data_mapping':'feature membership','required':True},
   ],
   'relationships':[{'from':'heatmap','to':'upset','type':'shares-order','shared_key':'feature_id'}],
   'spatial_topology':{'coordinate_system':'polar','reading_order':['outer tracks','center'],'alignment_keys':['feature_id'],'layer_order':['heatmap','upset']},
   'required_structures':['segmented multi-track matrix','central set summary'],
   'forbidden_substitutions':['single polar tile ring without sector or set structure'],
  }
 def test_unseen_reference_rejected(self):
  errors=m.validate({'design_target':{'reference':'user attachment','reference_opened':False}},schema)
  self.assertTrue(any('reference_opened' in e for e in errors))
 def test_text_without_allowlist_rejected(self):
  errors=m.validate({'text_contract':{'allow_headings':False,'allowed_text':[]}},schema)
  self.assertTrue(any('allowed_text' in e for e in errors))
 def test_concrete_target_and_text_contract_accepted(self):
  target={'reference':'user attachment','reference_opened':True}
  for key in ['hierarchy','geometry','palette','typography','marks','annotation']:
   target[key]={'observation':'Observed reference feature','implementation':'Task-specific rendering decision','difference_reason':'Adapted to current data'}
  errors=m.validate({'design_target':target,'text_contract':{'allowed_text':['Dose (mg)'],'allow_headings':False}},schema)
  self.assertFalse(any('design_target.' in e or 'text_contract.' in e for e in errors))
 def test_reference_analysis_is_mandatory_before_rendering(self):
  errors=m.validate({},schema)
  self.assertIn('reference_analysis must be a mapping completed before rendering',errors)
 def test_reference_analysis_requires_elements_positions_and_relationships(self):
  analysis=self.reference_analysis()
  del analysis['elements'][0]['position']
  analysis['relationships'][0]['to']='invented-layer'
  errors=m.validate({'reference_analysis':analysis},schema)
  self.assertTrue(any('elements[0].position' in e for e in errors))
  self.assertTrue(any('references unknown element: invented-layer' in e for e in errors))
 def test_reference_analysis_contract_accepts_complete_decomposition(self):
  errors=m.validate({'reference_analysis':self.reference_analysis()},schema)
  self.assertFalse(any(error.startswith('reference_analysis') or error.startswith('duplicate reference_analysis') for error in errors))
if __name__=='__main__':unittest.main()
