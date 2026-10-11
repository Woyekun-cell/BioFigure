import json
import sys
import unittest
import tempfile
from unittest.mock import patch
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import validate_learned_reuse as reuse
from validate_learned_reuse import validate, qualification, material_hashes, source_review_evidence
from benchmark_core import digest


class LearnedQualificationTests(unittest.TestCase):
    def setUp(self):
        self.entry = json.loads((ROOT / 'atlas/learned-method-index.json').read_text())['entries'][0]

    def test_source_study_never_qualifies_itself(self):
        # Source study alone has no qualification record, regardless of which
        # methods happen to be registered in the current local workspace.
        with patch.object(reuse, 'REGISTRY') as registry:
            registry.read_text.return_value = '{"records": []}'
            self.assertEqual(qualification(self.entry)['status'], 'NOT_VERIFIED')

    def test_declared_pass_without_real_new_input_repeat_stress_fails(self):
        record = {'method_id': self.entry['method_id'], 'status': 'PASS',
                  'source_material': material_hashes(self.entry), 'bundles': {}}
        result = validate(record, self.entry)
        self.assertEqual(result['status'], 'FAIL')
        self.assertEqual(len(result['errors']), 3)

    def test_other_method_and_current_source_drift_cannot_inherit_pass(self):
        record = {'method_id': 'other-method', 'source_material': {}}
        self.assertIn('method/source material binding stale', validate(record, self.entry)['errors'])


class SourceReviewReuseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.project = Path(self.temp.name).resolve()
        self.root = self.project / 'biofigure'
        self.root.mkdir()
        self.addCleanup(patch.stopall)
        patch.object(reuse, 'ROOT', self.root).start()
        self.method = 'SCICASE-TEST'
        self.source = self.root / 'source.png'
        Image.new('RGB', (20, 20), 'white').save(self.source)
        self.pdf = self.project / 'comparison.pdf'
        Image.new('RGB', (20, 20), 'white').save(self.pdf, 'PDF')
        self.difference_path = self.root / 'source-difference-review.json'
        self.parent_path = self.root / 'parent-review.json'
        self.difference = {'method_id': self.method, 'adapter_status': 'PASS',
            'high_fidelity_status': 'NOT_VERIFIED', 'source_reference': self.binding(self.source),
            'comparison_document': dict(self.binding(self.pdf), page=1)}
        self.refresh_reviews()

    def binding(self, path):
        return {'path': str(path.relative_to(self.project)), 'sha256': digest(path)}

    def refresh_reviews(self):
        self.difference_path.write_text(json.dumps(self.difference))
        self.parent = {'method_id': self.method, 'status': 'PASS',
            'high_fidelity_status': self.difference.get('high_fidelity_status'),
            'source_reference': self.difference['source_reference'],
            'source_difference_review': self.binding(self.difference_path)}
        self.parent_path.write_text(json.dumps(self.parent))
        self.review = {'parent_review': self.binding(self.parent_path),
            'source_difference_review': self.binding(self.difference_path),
            'high_fidelity_status': self.difference.get('high_fidelity_status')}

    def evidence(self, review=None):
        return source_review_evidence(self.review if review is None else review,
                                     self.method, digest(self.source))

    def test_legacy_without_project_reviews_keeps_previous_contract(self):
        self.assertEqual(self.evidence({}), ([], {}))

    def test_current_project_reviews_expose_root_relative_real_bindings(self):
        errors, evidence = self.evidence()
        self.assertEqual(errors, [])
        self.assertEqual(evidence['source_reference'], {'path': 'source.png', 'sha256': digest(self.source)})
        self.assertEqual(evidence['parent_review']['path'], 'parent-review.json')
        self.assertEqual(evidence['source_difference_review']['path'], 'source-difference-review.json')
        self.assertEqual(evidence['source_comparison_document'],
                         {'path': '../comparison.pdf', 'sha256': digest(self.pdf), 'page': 1})
        self.assertEqual(evidence['high_fidelity_status'], 'NOT_VERIFIED')

    def test_missing_changed_or_malformed_project_review_is_rejected(self):
        for key in ('parent_review', 'source_difference_review'):
            for kind in ('missing', 'hash', 'absolute', 'outside', 'shape'):
                with self.subTest(key=key, kind=kind):
                    review = json.loads(json.dumps(self.review))
                    if kind == 'missing': review[key]['path'] = 'missing.json'
                    elif kind == 'hash': review[key]['sha256'] = '0' * 64
                    elif kind == 'absolute': review[key]['path'] = str(self.parent_path)
                    elif kind == 'outside': review[key]['path'] = '../outside.json'
                    else: review[key] = None
                    self.assertTrue(self.evidence(review)[0])
        self.difference_path.write_text('{}')
        self.assertTrue(self.evidence()[0])

    def test_method_drift_adapter_failure_and_missing_fidelity_are_rejected(self):
        for field, value in (('method_id', 'another-method'), ('adapter_status', 'FAIL'),
                             ('high_fidelity_status', None)):
            with self.subTest(field=field):
                original = self.difference[field]
                self.difference[field] = value
                self.refresh_reviews()
                self.assertTrue(self.evidence()[0])
                self.difference[field] = original
        self.refresh_reviews()
        self.parent['method_id'] = 'another-method'
        self.parent_path.write_text(json.dumps(self.parent))
        self.review['parent_review'] = self.binding(self.parent_path)
        self.assertTrue(self.evidence()[0])

    def test_high_fidelity_status_comes_from_record_not_adapter_pass(self):
        self.difference['high_fidelity_status'] = 'FAIL'
        self.refresh_reviews()
        errors, evidence = self.evidence()
        self.assertEqual(errors, [])
        self.assertEqual(evidence['high_fidelity_status'], 'FAIL')
        self.review['high_fidelity_status'] = 'PASS'
        self.assertTrue(self.evidence()[0])

    def test_source_and_comparison_pdf_drift_or_invalid_page_are_rejected(self):
        for field, mutation in (('source_reference', {'sha256': '0' * 64}),
                                ('comparison_document', {'sha256': '0' * 64}),
                                ('comparison_document', {'path': 'missing.pdf'}),
                                ('comparison_document', {'page': 0}),
                                ('comparison_document', {'page': True}),
                                ('comparison_document', {'page': 2})):
            with self.subTest(field=field, mutation=mutation):
                old = self.difference[field].copy()
                self.difference[field].update(mutation)
                self.refresh_reviews()
                self.assertTrue(self.evidence()[0])
                self.difference[field] = old
        self.refresh_reviews()
        self.pdf.write_bytes(b'changed PDF')
        self.assertTrue(self.evidence()[0])

    def test_validate_invokes_project_binding_gate_before_qualification(self):
        library = self.root / 'benchmark/library'
        library.mkdir(parents=True)
        source_record = self.root / 'method.json'
        source_record.write_text('{}')
        entry = {'method_id': self.method, 'source_record': 'method.json',
                 'source_sha256': digest(source_record)}
        record = {'method_id': self.method, 'source_material': material_hashes(entry), 'bundles': {}}
        for key, mode in (('new_input', 'source-exposed-transfer'),
                          ('repeat', 'source-exposed-transfer'), ('stress', 'stress')):
            path = library / key / 'bundle.json'
            path.parent.mkdir()
            bundle = {'contract': {'case_id': self.method, 'mode': mode,
                'reference': {'sha256': digest(self.source)},
                'scientific_checks': sorted(reuse.TRANSFER_CHECKS)}, 'review': self.review}
            path.write_text(json.dumps(bundle))
            record['bundles'][key] = {'path': str(path.relative_to(self.root)), 'sha256': digest(path)}
        self.difference_path.unlink()
        with patch.object(reuse, 'validate_bundle', return_value={'errors': []}), \
             patch.object(reuse, 'validate_layout_density', return_value=[]), \
             patch.object(reuse, 'validate_typography', return_value=[]):
            result = validate(record, entry)
            self.assertEqual(result['status'], 'FAIL')
            self.assertTrue(any('source difference review' in e for e in result['errors']))
            source_record.write_text('changed source material')
            result = validate(record, entry)
            self.assertTrue(any('locked learned material missing or changed' in e for e in result['errors']))

    def test_qualification_exposes_review_recipe_and_fresh_source_comparison_policy(self):
        run = self.root / 'benchmark/library/new'
        run.mkdir(parents=True)
        for name in ('render.R', 'contract.json', 'values.csv'):
            (run / name).write_text('fixture')
        bind = lambda name: {'path': name, 'sha256': digest(run / name)}
        bundle = {'review': self.review, 'contract': {'reference': {'sha256': digest(self.source)},
            'learning': {k: 'example' for k in ('input_contract', 'transform', 'layout_rules', 'failure_modes')}},
            'receipt': {'script': bind('render.R'), 'contract': bind('contract.json'), 'inputs': [bind('values.csv')]}}
        bundle_path = run / 'bundle.json'
        bundle_path.write_text(json.dumps(bundle))
        registry = self.root / 'registry.json'
        registry.write_text(json.dumps({'records': [{'method_id': self.method,
            'bundles': {'new_input': {'path': str(bundle_path.relative_to(self.root)), 'sha256': digest(bundle_path)}},
            'runtime_environment': {}}]}))
        with patch.object(reuse, 'REGISTRY', registry), \
             patch.object(reuse, 'validate', return_value={'status': 'PASS', 'errors': []}):
            result = qualification({'method_id': self.method})
        recipe = result['reuse_recipe']
        self.assertEqual(recipe['high_fidelity_status'], 'NOT_VERIFIED')
        self.assertEqual(recipe['source_comparison_document']['page'], 1)
        self.assertTrue(all(word in recipe['new_data_policy'] for word in ('fresh CP2', 'source', 'PNG', 'PDF')))
        self.difference_path.unlink()
        with patch.object(reuse, 'REGISTRY', registry), \
             patch.object(reuse, 'validate', return_value={'status': 'PASS', 'errors': []}):
            self.assertEqual(qualification({'method_id': self.method})['status'], 'FAIL')


if __name__ == '__main__':
    unittest.main()
