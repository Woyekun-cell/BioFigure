import io
from PIL import Image, ImageDraw
import copy
import hashlib
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

MODULE = Path(__file__).resolve().parents[1] / 'scripts/benchmark_core.py'
spec = importlib.util.spec_from_file_location('benchmark_core_test', MODULE)
core = importlib.util.module_from_spec(spec)
spec.loader.exec_module(core)


class BenchmarkTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        def file(name, data=b'evidence'):
            (self.root / name).write_bytes(data)
            return {'path': name, 'sha256': core.digest(self.root / name)}
        self.file = file
        png = Image.new('RGB',(32,32),'white')
        ImageDraw.Draw(png).rectangle((4,4,20,20),fill='blue')
        stream = io.BytesIO(); png.save(stream,format='PNG'); png_bytes = stream.getvalue()
        c = {'case_id': 'fixture', 'mode': 'reproduction', 'family': 'ridge-bipolar',
             'required_structures': ['ridge', 'aligned-bars'], 'packages': ['ggridges'],
             'scientific_checks': ['sign-counts'], 'reference': file('reference.png', png_bytes),
             'learning': {k: 'explicit test method' for k in ('input_contract','transform','join_order','package_roles','layout_rules','failure_modes')}}
        receipt = {'runner': 'biofigure-benchmark-v2', 'fresh_directory': True, 'case_id': 'fixture',
                   'contract': file('contract.json', json.dumps(c).encode()), 'script': file('render.R'),
                   'inputs': [file('input.csv')], 'log': file('run.log'), 'environment': file('environment.txt'),
                   'exit_code': 0, 'elapsed_seconds': 1, 'packages': {'ggridges':'test'},
                   'artifacts':[file('output.png', png_bytes)],
                   'scientific_results': {'sign-counts': {'status':'pass','evidence':'checked against raw signed values'}}}
        review = {'reviewer':'test fixture observer', 'reviewed_at':'2026-09-14', 'family':'ridge-bipolar',
                  'observed_structures':['ridge','aligned-bars'], 'comparison':file('comparison.png',png_bytes),
                  'defects':dict.fromkeys(['overlap','clipping','missing_glyphs'],False),
                  'dimensions':{d:{'status':'pass','evidence':'fixture object observation', 'reference_region':[0,0,1,1],'output_region':[0,0,1,1]} for d in core.DIMENSIONS}}
        self.bundle = {'contract':c, 'receipt':receipt, 'review':review}
        self.bind()

    def bind(self):
        self.bundle['review']['receipt_sha256'] = hashlib.sha256(json.dumps(self.bundle['receipt'],sort_keys=True,ensure_ascii=False).encode()).hexdigest()

    def errors(self):
        return core.validate_bundle(self.bundle,self.root)['errors']

    def test_complete_fixture_is_accepted_as_evidence_only(self):
        self.assertEqual(self.errors(), [])

    def test_registry_rechecks_current_artifact_before_promotion(self):
        (self.root/'benchmark').mkdir()
        (self.root/'bundle.json').write_text(json.dumps(self.bundle))
        (self.root/'benchmark/registry.json').write_text(json.dumps({'cases':[{'case_id':'fixture','bundle':'bundle.json'}]}))
        self.assertEqual(core.registry_results(self.root)['fixture']['tracks']['reproduction']['status'],'PASS')
        self.assertEqual(core.registry_results(self.root)['fixture']['status'],'PENDING')
        (self.root/'output.png').write_bytes(b'changed after registration')
        self.assertEqual(core.registry_results(self.root)['fixture']['status'],'FAIL')

    def test_registry_duplicate_ids_rejected(self):
        (self.root/'benchmark').mkdir()
        (self.root/'benchmark/registry.json').write_text(json.dumps({'cases':[{'case_id':'a'},{'case_id':'a'}]}))
        with self.assertRaises(ValueError):
            core.registry_results(self.root)

    def test_real_output_mutation_invalidates_review(self):
        (self.root/'output.png').write_bytes(b'changed')
        self.assertIn('artifact: stale hash',self.errors())

    def test_real_script_mutation_invalidates_run(self):
        (self.root/'render.R').write_text('new code')
        self.assertIn('script: stale hash', self.errors())

    def test_missing_panel_is_rejected_even_with_six_passes(self):
        self.bundle['review']['observed_structures']=['ridge']
        self.assertIn('review: missing required structure',self.errors())

    def test_wrong_family_is_rejected(self):
        self.bundle['review']['family']='volcano'
        self.assertIn('review: wrong family',self.errors())

    def test_failed_run_is_rejected_even_after_resigning(self):
        self.bundle['receipt']['exit_code']=1
        self.bind()
        self.assertIn('runtime: nonzero or missing exit code',self.errors())

    def test_statistics_cannot_be_overridden_by_visual_pass(self):
        self.bundle['receipt']['scientific_results']={}
        self.bind()
        self.assertIn('science: unverified sign-counts',self.errors())

    def test_empty_visual_evidence_rejected(self):
        self.bundle['review']['dimensions']['typography']['evidence']=''
        self.assertIn('review: typography not evidenced PASS',self.errors())

    def test_overlap_and_out_of_range_region_rejected(self):
        self.bundle['review']['defects']['overlap']=True
        self.bundle['review']['dimensions']['annotation']['output_region']=[0,0,2,1]
        self.assertIn('review: unresolved overlap',self.errors())
        self.assertIn('review: annotation invalid output_region',self.errors())

    def test_transfer_requires_generation_isolation(self):
        self.bundle['contract']['mode']='transfer'
        self.bundle['receipt']['contract']=self.file('contract.json',json.dumps(self.bundle['contract']).encode())
        self.bind()
        self.assertIn('transfer: no enforced generation isolation',self.errors())

    def test_missing_file_and_path_escape_rejected(self):
        self.bundle['review']['comparison']={'path':'../missing','sha256':'x'}
        self.assertIn('comparison: missing or out-of-root file',self.errors())

    def test_blank_png_rejected_even_with_current_hash(self):
        Image.new('RGB',(32,32),'white').save(self.root/'output.png')
        self.bundle['receipt']['artifacts'][0]['sha256']=core.digest(self.root/'output.png')
        self.bind()
        self.assertIn('artifact: blank PNG',self.errors())

    def test_contract_cannot_be_changed_after_run(self):
        self.bundle['contract']['required_structures']=['ridge']
        self.assertIn('contract: in-memory/file mismatch',self.errors())

    def test_repeated_structure_ids_rejected(self):
        self.bundle['contract']['required_structures']=['ridge','ridge']
        self.assertIn('contract: empty or duplicate structures',self.errors())

    def test_package_not_available_rejected(self):
        self.bundle['receipt']['packages']={}
        self.bind()
        self.assertIn('package: missing version ggridges',self.errors())


if __name__ == '__main__':
    unittest.main()
