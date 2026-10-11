import unittest, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from plan_figure_method import compile_plan
from prepare_figure import prepare
from route_figure import route

class PangenomePlannerTests(unittest.TestCase):
 def ctx(self,intent=None):
  c={'data_type':'family_presence','columns':['family_id','accession','presence'],'unit':'gene_family_by_accession','missing_policy':'unknown_not_absent'}
  if intent:c['intent']=intent
  return c
 def test_vague_pan_request_asks_intent(self):
  p=compile_plan('泛基因组数据画图')
  self.assertEqual(p['planning_status'],'NEEDS_SPEC')
  self.assertIn('分析',p['question'])
  self.assertIsNone(p['selected_case'])
 def test_same_data_routes_by_question(self):
  for intent,family,chart in [('composition','composition','family-class-counts'),('prevalence','distribution','family-prevalence'),('accumulation','time-series','pan-core-accumulation'),('patterns','matrix','presence-absence-heatmap')]:
   p=compile_plan('泛基因组',pangenome_context=self.ctx(intent))
   self.assertEqual(p['families'],[family]);self.assertEqual(p['subtype'],chart)
   self.assertFalse(p['ready_to_render']);self.assertFalse(p['selected_case']['high_fidelity_eligible'])
 def test_missing_intent_blocks(self):
  p=compile_plan('pangenome',pangenome_context=self.ctx())
  self.assertEqual(p['planning_status'],'NEEDS_SPEC');self.assertEqual(len(p['options']),4)
 def test_ambiguous_missingness_blocks(self):
  c=self.ctx('patterns');c.pop('missing_policy')
  self.assertEqual(compile_plan('pangenome',pangenome_context=c)['planning_status'],'NEEDS_SPEC')
 def test_missing_gwas_fields_blocks(self):
  c={'data_type':'gwas_results','intent':'association','columns':['CHR','BP'],'unit':'variant_by_trait'}
  p=compile_plan('pangenome GWAS',pangenome_context=c)
  self.assertEqual(p['planning_status'],'NEEDS_SPEC');self.assertIn('P',str(p['missing']))
 def test_unrecognized_type_does_not_fallback(self):
  p=compile_plan('pangenome',pangenome_context={'data_type':'random'})
  self.assertEqual(p['planning_status'],'NEEDS_SPEC')
 def test_neutral_descriptive_stats(self):
  p=compile_plan('pangenome',pangenome_context=self.ctx('accumulation'))
  self.assertIn('not biological replicates',p['statistics_contract'])
 def test_route_loads_learning(self):
  r=route({'primary_domain':'genome-sequence-variation','primary_role':'structure','backend':'R','deliverable':'quick-png','figure_task':'泛基因组','pangenome_context':self.ctx('patterns')})
  self.assertIn('references/pangenome-learning.md',r['modules'])
 def test_prepare_blocks_missing_intent(self):
  req={'primary_domain':'genome-sequence-variation','primary_role':'structure','backend':'R','deliverable':'quick-png','figure_task':'pangenome','figure_family':'matrix','data_shape':'family by accession presence','pangenome_context':self.ctx()}
  r=prepare(req);self.assertEqual(r['status'],'NEEDS_SPEC');self.assertEqual(r['code_gate'],'BLOCKED')
 def test_prepare_blocks_conflicting_chart_family(self):
  req={'primary_domain':'genome-sequence-variation','primary_role':'structure','backend':'R','deliverable':'quick-png','figure_task':'pangenome','figure_family':'matrix','data_shape':'family by accession presence','pangenome_context':self.ctx('accumulation')}
  self.assertEqual(prepare(req)['status'],'NEEDS_SPEC')

 def test_requested_reference_does_not_relabel_audited_source(self):
  source='https://example.org/unreviewed-paper'
  p=compile_plan('pangenome',primary_source=source,pangenome_context=self.ctx('patterns'))
  self.assertEqual(p['selected_case']['reference'],'https://www.nature.com/articles/s41588-023-01340-y')
  self.assertEqual(p['requested_primary_source'],source)
  self.assertEqual(p['requested_source_status'],'requires_independent_audit')
