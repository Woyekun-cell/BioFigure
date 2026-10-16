"""A successful process must not masquerade as platform or visual acceptance."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'platform_smoke.py'


class PlatformSmokeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location('platform_smoke', SCRIPT)
        cls.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.module)

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def test_manifest_rejects_changed_bytes_even_when_file_exists(self):
        path = self.root / 'scripts/render.R'
        path.parent.mkdir(parents=True)
        path.write_text('x <- 1\n', encoding='utf-8')
        binding = {'path': 'scripts/render.R', 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
        self.module.verify_bound_files(self.root, [binding])
        path.write_text('x <- 2\n', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'SHA-256'):
            self.module.verify_bound_files(self.root, [binding])

    def test_manifest_rejects_path_escape(self):
        with self.assertRaisesRegex(ValueError, 'outside'):
            self.module.verify_bound_files(self.root, [{'path': '../outside', 'sha256': '0' * 64}])

    def test_replay_requires_real_inspection_of_exact_source_bytes(self):
        source = self.root / 'reference.pdf'
        source.write_bytes(b'%PDF-exact-inspected-source')
        review = {'schema_version': 1, 'scope': 'reference-source-inspection-only',
                  'reviewer': 'model', 'reviewed_at': '2026-10-16',
                  'cases': [{'case_id': 'oncoprint', 'observations': 'Reviewed all source rows and legends.',
                             'files': [{'path': 'reference.pdf', 'sha256': hashlib.sha256(source.read_bytes()).hexdigest(), 'viewed': True}]}]}
        self.module.verify_source_review(self.root, 'oncoprint', 'reference.pdf', review)
        review['cases'][0]['files'][0]['viewed'] = False
        with self.assertRaisesRegex(ValueError, 'actually viewed'):
            self.module.verify_source_review(self.root, 'oncoprint', 'reference.pdf', review)

    def test_replay_does_not_inherit_source_review_after_mutation(self):
        source = self.root / 'reference.pdf'
        source.write_bytes(b'%PDF-source')
        review = {'schema_version': 1, 'scope': 'reference-source-inspection-only', 'reviewer': 'model',
                  'reviewed_at': '2026-10-16', 'cases': [{'case_id': 'oncoprint', 'observations': 'Inspected source.',
                  'files': [{'path': 'reference.pdf', 'sha256': '0' * 64, 'viewed': True}]}]}
        with self.assertRaisesRegex(ValueError, 'SHA-256'):
            self.module.verify_source_review(self.root, 'oncoprint', 'reference.pdf', review)

    def test_summary_never_signs_visual_cp4(self):
        summary = self.module.make_summary([{'case': 'boxplot', 'status': 'TECHNICAL_PASS'}], [], 'commit')
        self.assertEqual(summary['status'], 'TECHNICAL_PASS_PENDING_VISUAL_REVIEW')
        self.assertEqual(summary['visual_review'], 'NOT_RUN')
        self.assertFalse(summary['cp4_certified'])
        self.assertEqual(self.module.make_summary([], ['missing output'], 'commit')['status'], 'FAIL')

    def test_welch_uses_raw_independent_values_and_full_interval(self):
        values = self.module.welch([1, 2, 3, 4], [3, 5, 6, 8])
        self.assertAlmostEqual(values['mean_difference'], 3.0)
        self.assertAlmostEqual(values['df'], 5.010309278350515)
        self.assertGreater(values['p_value'], 0.05)
        self.assertLess(values['p_value'], 0.1)
        self.assertLess(values['ci_low'], 0)
        self.assertGreater(values['ci_high'], 3)

    def test_native_receipt_rejects_footer_or_unbound_authorization(self):
        checks = dict.fromkeys(('font', 'text_allowlist', 'scientific_text_only', 'footer_free', 'layout', 'target_size'), True)
        receipt = {'status': 'PASS', 'backend': 'R', 'checks': checks,
                   'authorization_consumption': {'consumed': True}}
        with self.assertRaisesRegex(ValueError, 'Authorization evidence'):
            self.module.verify_native_receipt(receipt)
        checks['footer_free'] = False
        with self.assertRaisesRegex(ValueError, 'footer_free'):
            self.module.verify_native_receipt(receipt)

    def test_replay_phase_keeps_prior_original_evidence_and_does_not_mask_failure(self):
        previous = self.module.make_summary([{'case': 'boxplot', 'status': 'TECHNICAL_PASS'}], [], 'same')
        previous['phases'] = {'original': {'status': 'TECHNICAL_PASS_PENDING_VISUAL_REVIEW'}, 'replays': {'status': 'NOT_RUN'}}
        merged = self.module.merge_phase_summary(previous, [], ['specialist dependency missing'], 'same')
        self.assertEqual(merged['status'], 'FAIL')
        self.assertEqual(merged['results'][0]['case'], 'boxplot')
        self.assertEqual(merged['phases']['original']['status'], 'TECHNICAL_PASS_PENDING_VISUAL_REVIEW')
        self.assertEqual(merged['phases']['replays']['status'], 'FAIL')
        self.assertFalse(merged['cp4_certified'])

    def test_replay_phase_refuses_evidence_from_a_different_commit(self):
        previous = self.module.make_summary([], [], 'old')
        with self.assertRaisesRegex(ValueError, 'commit'):
            self.module.merge_phase_summary(previous, [], [], 'new')

    def test_canonical_validator_rejects_hash_bound_fake_pass_with_ai_footer(self):
        skill = SCRIPT.parent.parent / 'biofigure'
        bound_file = self.root / 'SKILL.md'
        bound_file.write_text('not a consumed authorization\n', encoding='utf-8')
        binding = {'path': str(bound_file), 'sha256': self.module.sha(bound_file)}
        png = self.root / 'candidate.png'
        png.write_bytes(b'fake rendered bytes')
        spec = self.root / 'design-spec.yaml'
        spec.write_text('reference_mode: original\ntext_contract:\n  allowed_text: []\n  allow_footer: false\n', encoding='utf-8')
        receipt = {'schema_version': 1, 'status': 'PASS', 'backend': 'R', 'sources': [], 'font': {},
                   'checks': dict.fromkeys(('font', 'text_allowlist', 'scientific_text_only', 'footer_free', 'layout', 'target_size'), True),
                   'authorization_consumption': {'consumed': True, 'authorization_id': '0' * 64,
                        'marker': binding, 'authorization_file': binding, 'preparation_receipt': binding},
                   'artifact': {'path': str(png), 'sha256': self.module.sha(png)},
                   'target_min_text_pt': 1, 'rendered_text': ['Generated by AI; QA PASS']}
        path = self.root / 'candidate.png.render.json'
        path.write_text(json.dumps(receipt), encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'Canonical'):
            self.module.verify_canonical_receipt(skill, path, png, spec, bound_file)

    def test_curated_artifacts_do_not_copy_libraries_sources_or_fonts(self):
        project = self.root / 'projects' / 'boxplot'
        project.mkdir(parents=True)
        candidate = project / 'boxplot.png'
        candidate.write_bytes(b'current-image')
        for directory in ['R-library', 'native-source']:
            (project / directory).mkdir()
            (project / directory / 'private.ttf').write_bytes(b'font-must-not-be-uploaded')
        results = [{'case': 'boxplot', 'artifacts': [{'path': str(candidate), 'sha256': self.module.sha(candidate)}]}]
        self.module.curate_artifacts(self.root, results)
        copied = sorted(p.relative_to(self.root / 'inspection-artifacts').as_posix()
                        for p in (self.root / 'inspection-artifacts').rglob('*') if p.is_file())
        self.assertEqual(copied, ['boxplot/boxplot.png'])

    def test_replay_preparation_uses_actual_bound_path_in_both_work_layouts(self):
        for relative in ('work/preparation-receipt.json', 'work/visual-qa/preparation-receipt.json'):
            with self.subTest(relative=relative):
                path = self.root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('{"status":"PREFLIGHT_COMPLETE"}', encoding='utf-8')
                receipt = {'authorization_consumption': {'preparation_receipt': {'path': str(path), 'sha256': self.module.sha(path)}}}
                self.assertEqual(self.module.replay_preparation(self.root, receipt), path.resolve())
                receipt['authorization_consumption']['preparation_receipt']['sha256'] = '0' * 64
                with self.assertRaisesRegex(ValueError, 'preparation'):
                    self.module.replay_preparation(self.root, receipt)

    def test_replay_preparation_cannot_escape_candidate_project(self):
        path = self.root / 'reference.json'
        path.write_text('{}', encoding='utf-8')
        receipt = {'authorization_consumption': {'preparation_receipt': {'path': str(path), 'sha256': self.module.sha(path)}}}
        with self.assertRaisesRegex(ValueError, 'project'):
            self.module.replay_preparation(self.root / 'candidate-project', receipt)

    def test_special_library_override_is_explicit_and_ohca_only(self):
        self.assertEqual(self.module.parse_case_libraries([f'ohca-microc={self.root}']), {'ohca-microc': self.root.resolve()})
        with self.assertRaisesRegex(ValueError, 'only ohca-microc'):
            self.module.parse_case_libraries([f'oncoprint={self.root}'])
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            self.module.parse_case_libraries([f'ohca-microc={self.root}', f'ohca-microc={self.root}'])

    def test_cli_json_survives_non_utf8_stdout_without_masking_file_encoding(self):
        expected_path = 'C:/BioFigure 便携 test'
        error_message = '缺少目录'
        for fails in (False, True):
            with self.subTest(error=fails):
                setup = (f'm.prepare=lambda *a,**k: (_ for _ in ()).throw(ValueError({json.dumps(error_message)}))' if fails
                         else f'm.prepare=lambda *a,**k: {json.dumps({"status": "READY", "skill_root": expected_path})}')
                code = ('import importlib.util,sys\n'
                        f's=importlib.util.spec_from_file_location("smoke",{str(SCRIPT)!r})\n'
                        'm=importlib.util.module_from_spec(s);s.loader.exec_module(m)\n'
                        + setup + '\n'
                        'sys.argv=["platform_smoke.py","prepare","--repository-root",".","--work-root","mock-only"]\n'
                        'raise SystemExit(m.main())\n')
                process = subprocess.run([sys.executable, '-c', code], capture_output=True,
                    env=dict(os.environ, PYTHONIOENCODING='cp1252', PYTHONUTF8='0', PYTHONDONTWRITEBYTECODE='1'))
                self.assertEqual(process.returncode, 1 if fails else 0, process.stderr.decode('cp1252'))
                raw = process.stderr if fails else process.stdout
                self.assertTrue(raw.isascii(), 'CLI JSON must be ASCII-safe even when paths/messages contain Chinese')
                record = json.loads(raw.decode('cp1252'))
                self.assertEqual(record['error'] if fails else record['skill_root'], error_message if fails else expected_path)


if __name__ == '__main__':
    unittest.main()
