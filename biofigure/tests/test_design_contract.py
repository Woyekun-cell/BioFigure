import importlib.util
import unittest
from pathlib import Path
import yaml
root=Path(__file__).resolve().parents[1]
s=importlib.util.spec_from_file_location('spec',root/'scripts/validate_design_spec.py')
m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
schema=yaml.safe_load((root/'schemas/figure-design-spec.schema.yaml').read_text())
class DesignTests(unittest.TestCase):
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
if __name__=='__main__':unittest.main()
