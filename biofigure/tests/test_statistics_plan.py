import copy
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('statistics_plan', ROOT/'scripts/validate_statistics_plan.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

def ready():
    return {'mode':'compute','status':'ready','question':'Treatment minus control mean',
            'intent_source':'user','intent_evidence':'User specified the control contrast',
            'estimand':'mean_difference','alternative':'two.sided','goal':'planned_contrasts',
            'method':'welch_t','formula':'y ~ group','rationale':'Independent continuous observations',
            'design':{'outcome_type':'continuous','response':'y','factors':['group'],'factor_levels':{'group':['control','treatment']},'covariates':[],
                      'independent_unit':'animal_id','dependence':'independent','evidence':'Sample dictionary',
                      'technical_replicates':'aggregated with QC','missing_policy':'explicit preprocessing',
                      'outlier_policy':'none removed','scale':'original'},
            'contrasts':['treatment minus control'],'diagnostics':['distribution, influential points, effective n'],
            'multiplicity':{'method':'none','family':'single prespecified contrast','n_tests':1},
            'results':{'table':'comparisons.csv','effect':'lhs_minus_rhs','interval_scope':'pointwise_95',
                       'annotation_source':'same_results_table'}}

class StatisticsPlanTests(unittest.TestCase):
    def test_declared_independent_welch_plan(self):
        self.assertEqual(m.validate_plan(ready()),[])
    def test_unclear_analysis_intent_blocks(self):
        p=ready();p['status']='needs_user_intent';p['goal']='unknown'
        self.assertTrue(any('intent' in e for e in m.validate_plan(p)))
    def test_pseudoreplication_method_mismatch(self):
        p=ready();p['design'].update(dependence='nested',dependence_id='animal_id')
        self.assertIn('selected method ignores the declared dependence structure',m.validate_plan(p))
    def test_two_factor_design_not_independent_oneway(self):
        p=ready();p['design']['factors']=['treatment','time'];p['method']='anova_oneway'
        self.assertTrue(any('multi-factor' in e for e in m.validate_plan(p)))
    def test_interaction_requires_interaction_terms(self):
        p=ready();p['design']['factors']=['treatment','time'];p['design']['factor_levels']={'treatment':['control','treated'],'time':['early','late']};p.update(method='factorial_lm',goal='interaction')
        self.assertTrue(any('interaction intent' in e for e in m.validate_plan(p)))
        p['interaction_terms']=['treatment:time'];p['formula']='y ~ treatment * time'
        self.assertEqual(m.validate_plan(p),[])
    def test_paired_design_needs_actual_id(self):
        p=ready();p['method']='paired_t';p['design']['dependence']='paired'
        self.assertTrue(any('dependence_id' in e for e in m.validate_plan(p)))
        p['design']['dependence_id']='animal_id';self.assertEqual(m.validate_plan(p),[])
    def test_welch_not_ordinary_tukey(self):
        p=ready();p['method']='welch_anova';p['multiplicity'].update(method='tukey',n_tests=3)
        self.assertTrue(any('Tukey' in e for e in m.validate_plan(p)))
    def test_family_and_adjustment_required(self):
        p=ready();p['multiplicity'].update(n_tests=3,family='')
        self.assertTrue(any('multiple tests' in e for e in m.validate_plan(p)))
        self.assertTrue(any('family' in e for e in m.validate_plan(p)))
    def test_equivalence_not_ordinary_t_test(self):
        p=ready();p.update(goal='equivalence',equivalence_margin_basis='maximum meaningful difference 1 unit')
        self.assertTrue(any('ordinary difference tests' in e for e in m.validate_plan(p)))
    def test_noncontinuous_outcome_not_anova(self):
        p=ready();p['design']['outcome_type']='binary'
        self.assertTrue(any('outcome' in e for e in m.validate_plan(p)))
    def test_statistics_required_cannot_skip_plan_or_declare_descriptive(self):
        self.assertTrue(m.validate_document({'statistics_required':True}))
        self.assertTrue(m.validate_document({'statistics_required':True,'statistics_plan':{
            'mode':'descriptive','status':'ready','reason':'QC','significance_annotations':False}}))
    def test_existing_results_hash_verified(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'stats.csv';path.write_text('p_adj\n0.01\n')
            p={'mode':'existing','status':'ready','recompute':False,'source':{
                'path':'stats.csv','sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                'p_semantics':'adjusted','comparison_mapping':'comparison IDs',
                'provenance':'verified upstream analysis'}}
            self.assertEqual(m.validate_plan(p,directory),[])
            path.write_text('p_adj\n0.9\n');self.assertTrue(any('hash' in e for e in m.validate_plan(p,directory)))
    def test_bad_types_do_not_crash(self):
        for factors in ([{}],['A','A'],None):
            p=ready();p['design']['factors']=factors
            self.assertTrue(m.validate_plan(p))
    def test_malformed_enum_fields_fail_without_crashing(self):
        for field in ('mode','goal','method','intent_source','alternative'):
            p=ready();p[field]={}
            self.assertTrue(m.validate_plan(p))
    def test_boolean_not_number_of_tests(self):
        p=ready();p['multiplicity']['n_tests']=True;self.assertTrue(m.validate_plan(p))
    def test_plot_annotation_source_bound(self):
        p=ready();p['results']['annotation_source']='manually typed stars'
        self.assertTrue(any('same statistical results' in e for e in m.validate_plan(p)))
    def test_two_group_method_rejects_three_levels(self):
        p=ready();p['design']['factor_levels']['group'].append('dose2')
        self.assertTrue(any('exactly two' in e for e in m.validate_plan(p)))
    def test_preparation_inference_cannot_be_disabled_in_spec(self):
        doc={'reference_evidence':{'preparation_request':{'statistics_required':True}}}
        self.assertTrue(any('cannot be omitted' in e for e in m.validate_document(doc)))
    def test_statistical_request_routes_and_binds_flag(self):
        import sys
        sys.path.insert(0,str(ROOT/'scripts'))
        from prepare_figure import prepare
        request={'figure_task':'compare treatment effects','data_shape':'independent group and numeric response',
            'primary_domain':'imaging-assay','primary_role':'comparison','backend':'R','deliverable':'quick-png',
            'operation':'select','statistics_required':True}
        from route_figure import route
        self.assertIn('references/statistics-workflow.md',route(request)['modules'])
        self.assertIs(prepare(request)['request']['statistics_required'],True)
        with self.assertRaises(ValueError): route(dict(request,statistics_required='true'))
    def test_design_spec_integration(self):
        ds=importlib.util.spec_from_file_location('design_statistical_gate',ROOT/'scripts/validate_design_spec.py')
        dm=importlib.util.module_from_spec(ds);ds.loader.exec_module(dm)
        import yaml
        schema=yaml.safe_load((ROOT/'schemas/figure-design-spec.schema.yaml').read_text())
        errors=dm.validate({'statistics_required':True},schema)
        self.assertTrue(any('needs statistics_plan' in e for e in errors))

if __name__=='__main__': unittest.main()
