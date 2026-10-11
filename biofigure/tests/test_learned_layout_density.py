import json,sys,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from validate_learned_reuse import validate_layout_density,validate_typography
from benchmark_core import digest

class LearnedLayoutDensityTests(unittest.TestCase):
 def test_empty_or_unbound_layout_is_not_visual_density_evidence(self):
  self.assertTrue(validate_layout_density({}, {}, {}, ROOT))
 def test_source_observation_and_actual_renderer_metrics_are_both_required(self):
  with tempfile.TemporaryDirectory() as temp:
   root=Path(temp);path=root/'geometry.json';path.write_text(json.dumps({'row_pitch_mm':3.2}))
   metric={'path':'geometry.json','sha256':digest(path)}
   contract={'reference':{'sha256':'a'*64},'source_density_contract':{'source_reference_sha256':'a'*64,'source_observations':{k:'Observed source layout' for k in ('outer_margins','row_or_cell_spacing','panel_gaps','legend_packing','intentional_whitespace')}}}
   receipt={'artifacts':[metric]};review={'layout_density_metrics':metric,'dimensions':{'information_density':{'source_layout_compared':True}}}
   self.assertEqual(validate_layout_density(contract,receipt,review,root),[])
   review['dimensions']['information_density']['source_layout_compared']=False
   self.assertTrue(validate_layout_density(contract,receipt,review,root))
   review['dimensions']['information_density']['source_layout_compared']=True
   path.write_text('{}')
   self.assertTrue(validate_layout_density(contract,receipt,review,root))
 def test_font_preset_alone_cannot_claim_readable_actual_output(self):
  self.assertTrue(validate_typography({}, {}, {}, ROOT))
 def test_font_adjustment_requires_actual_roles_pdf_sizes_and_observation(self):
  with tempfile.TemporaryDirectory() as temp:
   root=Path(temp);roles={'axis_text':7,'axis_title':8}
   preset=ROOT/'references/layout.md';layout=root/'geometry.json';pdf=root/'pdf-qa.json'
   layout.write_text(json.dumps({'font_sizes_pt':roles}));pdf.write_text(json.dumps({'pdf_sha256':'p','effective_point_sizes':[7,8]}))
   lr={'path':layout.name,'sha256':digest(layout)};pr={'path':pdf.name,'sha256':digest(pdf)}
   contract={'typography_contract':{'size_roles_pt':roles,'selection_basis':'Actual source and first output observed','preset_reference':{'path':'references/layout.md','sha256':digest(preset)}}}
   receipt={'artifacts':[lr,pr,{'path':'plot.pdf','sha256':'p'}]};review={'layout_density_metrics':lr,'pdf_font_metrics':pr,'dimensions':{'typography':{'final_size_readability_reviewed':True,'source_text_proportion_compared':True}}}
   self.assertEqual(validate_typography(contract,receipt,review,root),[])
   pdf.write_text(json.dumps({'pdf_sha256':'p','effective_point_sizes':[5,8]}));pr['sha256']=digest(pdf)
   self.assertTrue(validate_typography(contract,receipt,review,root))

if __name__=='__main__':unittest.main()
