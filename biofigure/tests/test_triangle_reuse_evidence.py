"""Binding tests only: fixtures do not assert real scientific or visual acceptance."""
import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import validate_learned_reuse as reuse
from benchmark_core import digest
from validate_learned_reuse import validate_layout_density, validate_triangle_layout_audit


class TriangleReuseEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.project = Path(self.temp.name).resolve()
        self.root = self.project / 'biofigure'
        self.root.mkdir()
        self.run = self.root / 'run'
        self.run.mkdir()
        self.auditor = self.project / 'scripts/audit_triangle_layout.py'
        self.auditor.parent.mkdir()
        self.auditor.write_text('# Fixture auditor identity; no real PDF acceptance.\n')
        patcher = patch.object(reuse, 'ROOT', self.root)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.pdf = self.run / 'figure.pdf'
        self.pdf.write_bytes(b'PDF binding fixture, not a real figure')
        self.geometry = self.run / 'geometry.json'
        self.geometry.write_text(json.dumps({'triangle_vertices_mm': [[30, 50], [80, 50], [55, 25]]}))
        self.audit = self.run / 'triangle-layout-audit.json'
        self.report = {'pdf_sha256': digest(self.pdf), 'geometry_sha256': digest(self.geometry),
            'auditor_sha256': digest(self.auditor), 'actual_triangle_overlap_count': 0,
            'text_collision_count': 0, 'outside_page_count': 0, 'status': 'PASS', 'errors': []}
        self.contract = {'case_id': 'SCICASE-019', 'adapter_version': 3,
            'reference': {'sha256': 'a' * 64},
            'source_density_contract': {'source_reference_sha256': 'a' * 64,
                'source_observations': {k: 'Test binding fixture only.' for k in
                    ('outer_margins', 'row_or_cell_spacing', 'panel_gaps', 'legend_packing', 'intentional_whitespace')}}}
        self.save_report()

    def binding(self, path):
        return {'path': str(path.relative_to(self.run)), 'sha256': digest(path)}

    def save_report(self):
        self.audit.write_text(json.dumps(self.report))
        self.receipt = {'artifacts': [self.binding(p) for p in (self.pdf, self.geometry, self.audit)]}
        self.review = {'triangle_layout_audit': self.binding(self.audit),
            'layout_density_metrics': self.binding(self.geometry),
            'dimensions': {'information_density': {'source_layout_compared': True}}}

    def errors(self):
        return validate_triangle_layout_audit(self.contract, self.receipt, self.review, self.run)

    def test_current_bound_zero_count_report_passes_pure_binding_gate(self):
        self.assertEqual(self.errors(), [])
        self.assertEqual(validate_layout_density(self.contract, self.receipt, self.review, self.run), [])

    def test_legacy_v2_and_other_nine_cases_keep_existing_contract(self):
        for method, version in [('SCICASE-019', 2)] + [(m, 3) for m in
                ('SCICASE-001', 'SCICASE-008', 'SCICASE-011', 'SCICASE-015',
                 'SCICASE-020', 'SCICASE-024', 'SCICASE-062', 'SCICASE-071', 'SCICASE-154')]:
            with self.subTest(method=method, version=version):
                self.contract.update(case_id=method, adapter_version=version)
                self.assertEqual(validate_triangle_layout_audit(self.contract, {}, {}, self.run), [])

    def test_missing_unbound_or_stale_report_is_rejected(self):
        self.review.pop('triangle_layout_audit')
        self.assertTrue(self.errors())
        self.save_report()
        self.receipt['artifacts'].pop()
        self.assertTrue(self.errors())
        self.save_report()
        self.audit.write_text('{}')
        self.assertTrue(self.errors())
        self.save_report()
        self.review['triangle_layout_audit']['path'] = '../outside.json'
        self.assertTrue(self.errors())

    def test_nonzero_none_bool_or_missing_counts_are_rejected(self):
        for key in ('actual_triangle_overlap_count', 'text_collision_count', 'outside_page_count'):
            for value in (1, None, False, 0.0):
                with self.subTest(key=key, value=value):
                    self.report[key] = value
                    self.save_report()
                    self.assertTrue(self.errors())
            self.report[key] = 0
        self.report.pop('actual_triangle_overlap_count')
        self.save_report()
        self.assertTrue(self.errors())

    def test_fail_not_verified_and_report_errors_are_rejected(self):
        for status, errors in (('FAIL', []), ('NOT_VERIFIED', []), ('PASS', ['Unsupported font']), ('PASS', None)):
            with self.subTest(status=status, errors=errors):
                self.report.update(status=status, errors=errors)
                self.save_report()
                self.assertTrue(self.errors())

    def test_wrong_pdf_geometry_or_auditor_hash_is_rejected(self):
        for key in ('pdf_sha256', 'geometry_sha256', 'auditor_sha256'):
            with self.subTest(key=key):
                original = self.report[key]
                self.report[key] = '0' * 64
                self.save_report()
                self.assertTrue(self.errors())
                self.report[key] = original

    def test_changed_pdf_geometry_or_auditor_bytes_are_rejected(self):
        for path in (self.pdf, self.geometry, self.auditor):
            with self.subTest(path=path.name):
                old = path.read_bytes()
                path.write_bytes(old + b'changed')
                self.assertTrue(self.errors())
                path.write_bytes(old)

    def test_malformed_019_version_cannot_bypass_required_audit(self):
        for version in ('3', True, None):
            with self.subTest(version=version):
                self.contract['adapter_version'] = version
                self.assertTrue(self.errors())

    def test_explicit_revocation_rejects_only_the_exact_old_bundle_bindings(self):
        registry = self.project / 'registry.json'
        old = {'method_id': 'SCICASE-019', 'bundles': {
            k: {'path': k + '/old-bundle.json', 'sha256': 'a' * 64}
            for k in ('new_input', 'repeat', 'stress')}}
        registry.write_text(json.dumps({'records': [], 'revoked_history': [{
            'method_id': 'SCICASE-019', 'previous_record': old}]}))
        material = self.root / 'method.json'
        material.write_text('{}')
        entry = {'method_id': 'SCICASE-019', 'source_record': 'method.json', 'source_sha256': digest(material)}
        record = dict(old, source_material=reuse.material_hashes(entry))
        revoked_error = 'explicitly revoked visual evidence; render/review a new version'
        with patch.object(reuse, 'REGISTRY', registry):
            self.assertEqual(reuse.validate(record, entry), {'status': 'FAIL', 'errors': [revoked_error]})
            new = copy.deepcopy(record)
            new['bundles']['new_input']['path'] = 'new-version/new-bundle.json'
            self.assertNotIn(revoked_error, reuse.validate(new, entry)['errors'])
            other = copy.deepcopy(record)
            other['method_id'] = 'SCICASE-020'
            self.assertNotIn(revoked_error, reuse.validate(other, entry)['errors'])
        # No registry is valid for isolated unit fixtures; normal bundle gates
        # still run rather than manufacturing a PASS.
        with patch.object(reuse, 'REGISTRY', self.project / 'missing-registry.json'):
            self.assertNotIn(revoked_error, reuse.validate(record, entry)['errors'])


class SourceDensityEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.project = Path(self.temp.name).resolve()
        self.root = self.project / 'biofigure'
        self.root.mkdir()
        p = patch.object(reuse, 'ROOT', self.root)
        p.start()
        self.addCleanup(p.stop)
        self.source = self.root / 'source.png'
        self.source.write_bytes(b'Source image hash fixture only')
        self.density_path = self.root / 'density54-validation.json'
        self.difference_path = self.root / 'source-difference-review.json'
        self.density = {'method_id': 'SCICASE-019', 'synthetic': True, 'status': 'PASS',
                        'source_reference': self.binding(self.source)}
        self.save()

    def binding(self, path):
        return {'path': str(path.relative_to(self.project)), 'sha256': digest(path)}

    def save(self):
        self.density_path.write_text(json.dumps(self.density))
        self.difference = {'method_id': 'SCICASE-019', 'adapter_status': 'PASS',
            'high_fidelity_status': 'NOT_VERIFIED', 'source_reference': self.binding(self.source),
            'density_benchmark': self.binding(self.density_path)}
        self.difference_path.write_text(json.dumps(self.difference))
        self.review = {'source_difference_review': self.binding(self.difference_path)}

    def evidence(self):
        return reuse.source_review_evidence(self.review, 'SCICASE-019', digest(self.source))

    def test_density_locator_is_root_relative_and_does_not_certify_source_fidelity(self):
        errors, evidence = self.evidence()
        self.assertEqual(errors, [])
        self.assertEqual(evidence['source_density_benchmark'],
                         {'path': 'density54-validation.json', 'sha256': digest(self.density_path)})
        self.assertEqual(evidence['high_fidelity_status'], 'NOT_VERIFIED')

    def test_wrong_method_real_data_failure_or_source_are_rejected(self):
        for field, value in (('method_id', 'SCICASE-020'), ('synthetic', False),
                             ('status', 'FAIL'), ('source_reference', {'path': 'biofigure/missing.png', 'sha256': '0'*64})):
            with self.subTest(field=field):
                old = self.density[field]
                self.density[field] = value
                self.save()
                self.assertTrue(self.evidence()[0])
                self.density[field] = old

    def test_changed_missing_or_invalid_density_report_is_rejected(self):
        for kind in ('changed', 'missing', 'json'):
            with self.subTest(kind=kind):
                self.save()
                if kind == 'changed': self.density_path.write_text('{}')
                elif kind == 'missing': self.density_path.unlink()
                else:
                    self.density_path.write_text('not JSON')
                    self.difference['density_benchmark'] = self.binding(self.density_path)
                    self.difference_path.write_text(json.dumps(self.difference))
                    self.review['source_difference_review'] = self.binding(self.difference_path)
                self.assertTrue(self.evidence()[0])


if __name__ == '__main__':
    unittest.main()
