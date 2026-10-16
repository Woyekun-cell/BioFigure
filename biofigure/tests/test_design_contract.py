import importlib.util
import hashlib
import tempfile
import unittest
from pathlib import Path
import yaml
root=Path(__file__).resolve().parents[1]
s=importlib.util.spec_from_file_location('spec',root/'scripts/validate_design_spec.py')
m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
schema=yaml.safe_load((root/'schemas/figure-design-spec.schema.yaml').read_text())
class DesignTests(unittest.TestCase):
 def test_rectangular_heatmap_requires_a_physical_square_cell_contract(self):
  doc={'reference_analysis':{'figure_family':'expression heatmap',
       'spatial_topology':{'coordinate_system':'cartesian'}}}
  self.assertTrue(any('heatmap_cell_contract' in e for e in m.validate(doc,schema)))
  doc['heatmap_cell_contract']={'policy_id':'heatmap-cells-v1','shape':'square',
    'measurement_basis':'final_body_viewports_mm','max_relative_error':.01,'rows':8,'columns':4}
  self.assertFalse(any('heatmap_cell_contract' in e for e in m.validate(doc,schema)))
  doc['heatmap_cell_contract']['max_relative_error']=.1
  self.assertTrue(any('heatmap_cell_contract' in e for e in m.validate(doc,schema)))
 def test_footer_contract_cannot_be_overridden_by_headings_or_allowlist(self):
  for contract in (
    {'allowed_text':['n = 8'],'allow_headings':True,'caption':'n = 8'},
    {'allowed_text':['Liver'],'allow_headings':True,'allow_footer':True},
    {'allowed_text':['n = 8 fish per group; infection day 12'],'allow_headings':True},
  ):
   with self.subTest(contract=contract):
    errors=m.validate({'text_contract':contract},schema)
    self.assertTrue(any('footer' in error for error in errors))
 def test_project_style_contract_matches_registry(self):
  registry={'schema_version':'1.0','project_id':'Project_021_顶刊配色审阅',
   'palette':{'palette_id':'tol-muted-9','semantic_colors':{'Group A':'#CC6677','Group B':'#332288'}},
   'typography':{'family':'Arial','size_roles_pt':{'axis_text':7,'axis_title':7,'legend_text':7,'strip_text':7,'annotation_text':6,'panel_label':8}},
   'size_system':{'allowed_classes':['double-column']}}
  with tempfile.TemporaryDirectory() as td:
   path=Path(td)/'project-style.yaml'; path.write_text(yaml.safe_dump(registry,allow_unicode=True),encoding='utf-8')
   sha=hashlib.sha256(path.read_bytes()).hexdigest()
   doc={'project_style_contract':{'registry_path':str(path),'registry_sha256':sha,
       'project_id':registry['project_id'],'palette_id':'tol-muted-9',
       'semantic_colors':registry['palette']['semantic_colors'],'reuse_policy':'exact_semantic_mapping',
       'exception_basis':''},
      'font_contract':{'family':'Arial','resolved_font_file':'runtime_systemfonts_path','fallback_policy':'verified_Arial_only','warning_policy':'fail','all_layers_inherit_policy':'fail_if_any_layer_unverified','rendered_face_check':'png_visual_plus_metadata','minimum_final_text_pt':5,'size_basis':'final_output_size','size_roles_pt':registry['typography']['size_roles_pt']},
      'output_size':{'width_mm':180,'height_mm':120,'formats':['png'],'size_class':'double-column','size_basis':'final_physical_output','size_rationale':{'panel_count':1,'density':'low','longest_label_chars':1,'recommended_class':'single-column','selection_reason':'project consistency audit','override_basis':'user requested overview'}}}
   errors=m.validate(doc,schema,spec_path=path.parent/'design-spec.yaml')
   self.assertFalse(any(e.startswith('project_style_contract') for e in errors))
   doc['project_style_contract']['palette_id']='wrong'
   errors=m.validate(doc,schema,spec_path=path.parent/'design-spec.yaml')
   self.assertIn('project_style_contract.palette_id differs from project style registry',errors)
 def test_project_style_contract_is_required(self):
  errors=m.validate({},schema)
  self.assertIn('missing required key: project_style_contract',errors)
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
 def test_production_notes_cannot_be_self_approved_as_figure_text(self):
  forbidden=['AI note: descriptive plot', 'AI insight', 'Generated by ChatGPT',
             'Generated figure', 'CP2 PASS', 'NOT_VERIFIED', 'For illustration only',
             'Descriptive only', 'AI备注：未作统计', '自动生成图', '仅作演示', '配对未核']
  for label in forbidden:
   for allow_headings in (False, True):
    with self.subTest(label=label, allow_headings=allow_headings):
     errors=m.validate({'text_contract':{'allow_headings':allow_headings,
                                        'allowed_text':['Dose (mg)',label]}},schema)
     self.assertTrue(any('production/audit/disclaimer text' in e for e in errors))
 def test_scientific_labels_and_ai_identifiers_remain_usable(self):
  labels=['AI prediction score', 'AI_NOTE_01', 'AI-generated risk score',
          'Dose (mg)', 'n = 30', 'P = 0.02', 'q < 0.05', 'r = 0.72',
          'R² = 0.51', 'ns', '50 μm', 'Simulated score (a.u.)', 'Synthetic value',
          'AI基因表达量', 'WT only', 'NOT_VERIFIED_GENE']
  errors=m.validate({'text_contract':{'allow_headings':False,'allowed_text':labels}},schema)
  self.assertFalse(any('text_contract.' in e for e in errors))
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
 def test_inside_top_legend_is_a_supported_layout_choice(self):
  errors=m.validate({'legend':{'place':'inside_top','shared':True},'layout_contract':{'data_bbox':'x 17-87 mm; y 21-44 mm','legend_bbox':'x 22-79 mm; y 46-49 mm'}},schema)
  self.assertNotIn('legend.place must reserve space outside dense data or use direct labels',errors)
 def test_unknown_legend_position_is_rejected(self):
  errors=m.validate({'legend':{'place':'arbitrary','shared':True}},schema)
  self.assertIn('legend.place must use a supported reserved or direct-label location',errors)
 def test_font_contract_requires_final_size_roles_and_hierarchy(self):
  font={'family':'Arial','resolved_font_file':'runtime_systemfonts_path',
        'fallback_policy':'fail','warning_policy':'fail',
        'all_layers_inherit_policy':'fail_if_any_layer_unverified',
        'rendered_face_check':'png_visual_plus_vector_metadata'}
  errors=m.validate({'font_contract':font},schema)
  self.assertTrue(any('font_contract.size_roles_pt is required' in e for e in errors))
  font.update({'minimum_final_text_pt':5,'size_basis':'final_output_size',
               'size_roles_pt':{'axis_text':4.5,'axis_title':7,'legend_text':6,
                                'strip_text':7,'annotation_text':6,'panel_label':8}})
  errors=m.validate({'font_contract':font},schema)
  self.assertTrue(any('below minimum_final_text_pt' in e for e in errors))
  font['size_roles_pt']['axis_text']=7.5
  font['size_roles_pt']['axis_title']=7
  errors=m.validate({'font_contract':font},schema)
  self.assertTrue(any('axis_title must be at least axis_text' in e for e in errors))
 def test_output_size_rejects_oversized_canvas_for_declared_column_class(self):
  size={'width_mm':183,'height_mm':120,'formats':['png'],
        'size_class':'single-column','size_basis':'final_physical_output',
        'size_rationale':{'panel_count':1,'density':'low','longest_label_chars':9,
                          'recommended_class':'single-column','selection_reason':'one simple panel',
                          'override_basis':''}}
  errors=m.validate({'output_size':size,'reference_analysis':self.reference_analysis(),
                     'text_contract':{'allowed_text':['Cell type'],'allow_headings':False}},schema)
  self.assertTrue(any('single-column width must be 89..90 mm' in e for e in errors))
 def test_output_size_class_is_derived_from_panel_density(self):
  analysis=self.reference_analysis()
  analysis['panels']=[{'id':f'p{i}','role':'evidence','position':f'cell {i}'} for i in range(4)]
  size={'width_mm':90,'height_mm':75,'formats':['png'],
        'size_class':'single-column','size_basis':'final_physical_output',
        'size_rationale':{'panel_count':4,'density':'high','longest_label_chars':9,
                          'recommended_class':'single-column','selection_reason':'four panels',
                          'override_basis':''}}
  errors=m.validate({'output_size':size,'reference_analysis':analysis,
                     'text_contract':{'allowed_text':['Cell type'],'allow_headings':False}},schema)
  self.assertTrue(any('recommended_class must be double-column' in e for e in errors))
 def test_output_size_accepts_nature_double_column_contract(self):
  analysis=self.reference_analysis()
  analysis['panels']=[{'id':f'p{i}','role':'evidence','position':f'cell {i}'} for i in range(4)]
  size={'width_mm':183,'height_mm':120,'formats':['png'],
        'size_class':'double-column','size_basis':'final_physical_output',
        'size_rationale':{'panel_count':4,'density':'high','longest_label_chars':9,
                          'recommended_class':'double-column','selection_reason':'dense four-panel figure',
                          'override_basis':''}}
  errors=m.validate({'output_size':size,'reference_analysis':analysis,
                     'text_contract':{'allowed_text':['Cell type'],'allow_headings':False}},schema)
  self.assertFalse(any(e.startswith('output_size.') for e in errors))
 def test_two_low_density_panels_may_remain_single_column(self):
  analysis=self.reference_analysis()
  analysis['panels']=[{'id':f'p{i}','role':'evidence','position':f'row {i}'} for i in range(2)]
  size={'width_mm':90,'height_mm':120,'formats':['png'],
        'size_class':'single-column','size_basis':'final_physical_output',
        'size_rationale':{'panel_count':2,'density':'low','longest_label_chars':9,
                          'recommended_class':'single-column','selection_reason':'two sparse aligned panels',
                          'override_basis':''}}
  errors=m.validate({'output_size':size,'reference_analysis':analysis,
                     'text_contract':{'allowed_text':['Cell type'],'allow_headings':False}},schema)
  self.assertFalse(any('recommended_class' in e or 'size_class must equal' in e for e in errors))
if __name__=='__main__':unittest.main()
