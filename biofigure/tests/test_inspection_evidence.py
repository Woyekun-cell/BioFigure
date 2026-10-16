import importlib.util
import math
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('checkpoint_evidence', ROOT / 'scripts/validate_checkpoints.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class InspectionEvidenceTests(unittest.TestCase):
    @staticmethod
    def final_size_checks(status='PASS'):
        return {'target_size_opened': True, 'checks': {
            key: {'status': status, 'evidence': f'{key} checked on final-size PNG', 'colored_data_marks': True}
            for key in ('typography_size', 'typography_position', 'label_overlap',
                        'legend_overlap', 'clipping', 'panel_alignment',
                        'figure_text_proportion', 'semantic_color', 'footer_absent')
        }}

    def test_monochrome_or_unchecked_color_cannot_receive_visual_pass(self):
        evidence = {'artifact_sha256':'a'*64,'first_render_sha256':'a'*64,
                    'artifact_path':'/tmp/final.png','first_render_path':'/tmp/final.png',
                    'target_size':{'width_mm':90,'height_mm':70},'reviewer_type':'model',
                    'reviewer_id':'reviewer-01','judgment':'PASS','defect_coordinates':[],
                    'viewer_method':'direct-open','revision_count':0,
                    'final_size_checks':self.final_size_checks()}
        evidence['final_size_checks']['checks']['semantic_color'] = {
            'status':'PASS','evidence':'black and grey data marks only','colored_data_marks':False}
        self.assertTrue(any('colored_data_marks' in error for error in module.validate_inspection_evidence(evidence)))
        evidence['final_size_checks']['checks']['semantic_color']['colored_data_marks'] = True
        self.assertEqual(module.validate_inspection_evidence(evidence), [])
        del evidence['final_size_checks']['checks']['semantic_color']
        self.assertTrue(any('semantic_color' in error for error in module.validate_inspection_evidence(evidence)))

    def test_missing_first_render_size_coordinates_or_reviewer_type_is_rejected(self):
        errors = module.validate_inspection_evidence({})
        for phrase in ('first_render', 'target_size', 'reviewer_type', 'defect_coordinates', 'artifact_sha256'):
            self.assertTrue(any(phrase in error for error in errors), phrase)
    def test_visual_pass_requires_an_actual_no_footer_observation(self):
        evidence = {'artifact_sha256':'a'*64,'first_render_sha256':'a'*64,
                    'artifact_path':'/tmp/final.png','first_render_path':'/tmp/final.png',
                    'target_size':{'width_mm':90,'height_mm':70},'reviewer_type':'model',
                    'reviewer_id':'reviewer-01','judgment':'PASS','defect_coordinates':[],
                    'viewer_method':'direct-open','revision_count':0,
                    'final_size_checks':self.final_size_checks()}
        evidence['final_size_checks']['checks'].pop('footer_absent',None)
        self.assertTrue(any('footer_absent' in error for error in module.validate_inspection_evidence(evidence)))

    def test_visual_pass_requires_named_human_or_model_reviewer_and_structured_coordinates(self):
        valid = {'artifact_sha256':'a'*64,'first_render_sha256':'b'*64,
                 'artifact_path':'/tmp/final.png','first_render_path':'/tmp/first.png',
                 'target_size':{'width_mm':90,'height_mm':70},'reviewer_type':'human',
                 'reviewer_id':'reviewer-01','judgment':'PASS','defect_coordinates':[],
                 'viewer_method':'direct-open','revision_count':1,
                 'final_size_checks':self.final_size_checks()}
        self.assertEqual(module.validate_inspection_evidence(valid), [])
        automated = dict(valid, reviewer_type='automated')
        self.assertTrue(any('human or model' in e for e in module.validate_inspection_evidence(automated)))
        malformed = dict(valid, defect_coordinates=[{'issue':'overlap','x':2}])
        self.assertTrue(any('coordinates' in e for e in module.validate_inspection_evidence(malformed)))
        same = dict(valid, first_render_path='/tmp/final.png')
        self.assertTrue(any('different' in e for e in module.validate_inspection_evidence(same)))

    def test_defect_coordinates_must_be_finite_normalized_and_inside_canvas(self):
        valid = {'artifact_sha256':'a'*64,'first_render_sha256':'b'*64,
                 'artifact_path':'/tmp/final.png','first_render_path':'/tmp/first.png',
                 'target_size':{'width_mm':90,'height_mm':70},'reviewer_type':'human',
                 'reviewer_id':'reviewer-01','judgment':'REVISE',
                 'defect_coordinates':[{'issue':'overlap','x':0.5,'y':0.8,'unit':'normalized'}],
                 'viewer_method':'direct-open','revision_count':0,
                 'final_size_checks':self.final_size_checks('FAIL')}
        self.assertEqual(module.validate_inspection_evidence(valid), [])
        for coordinate in (
            {'issue':'bad','x':-0.1,'y':0.5,'unit':'normalized'},
            {'issue':'bad','x':1.01,'y':0.5,'unit':'normalized'},
            {'issue':'bad','x':0.5,'y':math.inf,'unit':'normalized'},
            {'issue':'bad','x':0.5,'y':float('nan'),'unit':'normalized'},
            {'issue':'bad','x':0.5,'y':0.5,'unit':'px'},
        ):
            errors = module.validate_inspection_evidence(dict(valid, defect_coordinates=[coordinate]))
            self.assertTrue(any('normalized' in e or 'finite' in e or '0..1' in e for e in errors), coordinate)

    def test_revision_count_rejects_boolean_even_though_bool_is_an_int_subclass(self):
        valid = {'artifact_sha256':'a'*64,'first_render_sha256':'b'*64,
                 'artifact_path':'/tmp/final.png','first_render_path':'/tmp/first.png',
                 'target_size':{'width_mm':90,'height_mm':70},'reviewer_type':'human',
                 'reviewer_id':'reviewer-01','judgment':'PASS','defect_coordinates':[],
                 'viewer_method':'direct-open','revision_count':True,
                 'final_size_checks':self.final_size_checks()}
        errors = module.validate_inspection_evidence(valid)
        self.assertTrue(any('revision_count must be a non-negative integer' in error for error in errors))

    def test_visual_pass_requires_complete_final_size_typography_and_position_checks(self):
        base = {'artifact_sha256':'a'*64,'first_render_sha256':'a'*64,
                'artifact_path':'/tmp/final.png','first_render_path':'/tmp/final.png',
                'target_size':{'width_mm':90,'height_mm':70},'reviewer_type':'human',
                'reviewer_id':'reviewer-01','judgment':'PASS','defect_coordinates':[],
                'viewer_method':'direct-open','revision_count':0}
        errors = module.validate_inspection_evidence(base)
        self.assertTrue(any('final_size_checks' in error for error in errors))
        failed = dict(base, final_size_checks=self.final_size_checks())
        failed['final_size_checks']['checks']['typography_position'] = {
            'status':'FAIL','evidence':'axis label touches panel border'}
        errors = module.validate_inspection_evidence(failed)
        self.assertTrue(any('typography_position must PASS' in error for error in errors))

    def test_visual_pass_requires_figure_text_proportion_check(self):
        checks = self.final_size_checks()
        del checks['checks']['figure_text_proportion']
        evidence = {'artifact_sha256':'a'*64,'first_render_sha256':'b'*64,
                    'artifact_path':'/tmp/final.png','first_render_path':'/tmp/first.png',
                    'target_size':{'width_mm':90,'height_mm':70},'reviewer_type':'model',
                    'reviewer_id':'reviewer-02','judgment':'PASS','defect_coordinates':[],
                    'viewer_method':'direct-open','revision_count':1,
                    'final_size_checks':checks}
        errors = module.validate_inspection_evidence(evidence)
        self.assertTrue(any('figure_text_proportion' in error for error in errors))


if __name__ == '__main__':
    unittest.main()
