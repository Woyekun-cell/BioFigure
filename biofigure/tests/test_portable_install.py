"""Public package regressions: omitted files must not borrow the developer checkout."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import sys
import shutil
import subprocess
import os


AUDITOR = Path(__file__).resolve().parents[1] / 'scripts/audit_portable_install.py'


class PortableInstallTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / 'biofigure'
        self.root.mkdir()
        self.write('SKILL.md', '# BioFigure fixture\n')
        self.write('manifest.yaml', 'version: 3.8.0\n')
        self.write('atlas/learned-method-index.json', json.dumps({'entries': [
            {'method_id': 'SOURCE-ONLY', 'mandatory_read_set': ['library/unpublished.R']}
        ]}))
        self.write('examples/demo/run.py', 'import argparse\nargparse.ArgumentParser().parse_args()\n')
        self.write('examples/demo/data.csv', 'sample,value\ns1,1\n')
        self.write('examples/demo/provenance.json', '{"origin":"BioFigure-owned simulated data","license":"MIT"}\n')
        self.case = {'id': 'demo', 'title': 'Own simulated fixture', 'status': 'runnable',
                     'entrypoint': 'examples/demo/run.py',
                     'command': ['python3', '{skill_root}/examples/demo/run.py', '--output-dir', '{output_dir}'],
                     'provenance': 'examples/demo/provenance.json',
                     'files': [self.binding(x, role) for x, role in [
                         ('examples/demo/run.py', 'code'), ('examples/demo/data.csv', 'input'),
                         ('examples/demo/provenance.json', 'provenance')]],
                     'dependencies': [], 'limitations': ['Simulation only; current output needs visual review.']}
        self.save()

    def write(self, relative, text):
        target = self.root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)

    def binding(self, relative, role):
        return {'path': relative, 'sha256': hashlib.sha256((self.root / relative).read_bytes()).hexdigest(),
                'role': role, 'license': 'MIT', 'origin': 'BioFigure-owned'}

    def save(self):
        self.write('public-cases.json', json.dumps({'schema_version': 1, 'skill_version': '3.8.0', 'cases': [self.case]}))

    def auditor(self):
        self.assertTrue(AUDITOR.is_file(), 'portable install auditor is not implemented')
        spec = importlib.util.spec_from_file_location('portable_auditor', AUDITOR)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_reference_only_catalog_is_reported_without_blocking_original_case(self):
        report = self.auditor().audit(self.root)
        self.assertEqual(report['status'], 'PASS', report['errors'])
        self.assertEqual(report['learning_catalog']['source_materials_unavailable'], 1)
        self.assertFalse(report['scientific_or_visual_pass_inferred'])

    def test_missing_input_fails_and_cannot_borrow_parent_copy(self):
        (self.root / 'examples/demo/data.csv').unlink()
        (self.root.parent / 'data.csv').write_text('sample,value\ns1,1\n')
        report = self.auditor().audit(self.root)
        self.assertEqual(report['status'], 'FAIL')
        self.assertTrue(any('missing-file' in e for e in report['errors']))

    def test_tampered_input_fails_hash(self):
        self.write('examples/demo/data.csv', 'sample,value\ns1,999\n')
        report = self.auditor().audit(self.root)
        self.assertTrue(any('hash-mismatch' in e for e in report['errors']))

    def test_parent_repo_file_is_not_a_portable_material(self):
        (self.root.parent / 'outside.csv').write_text('x\n1\n')
        self.case['files'][1]['path'] = '../outside.csv'
        self.save()
        report = self.auditor().audit(self.root)
        self.assertTrue(any('path-escape' in e for e in report['errors']))

    def test_declared_runtime_cannot_borrow_an_excluded_cache(self):
        self.write('cache/private.csv', 'x\n1\n')
        self.case['files'][1] = self.binding('cache/private.csv', 'input')
        self.save()
        report = self.auditor().audit(self.root)
        self.assertEqual(report['status'], 'FAIL')
        self.assertTrue(any('excluded-runtime-path' in e for e in report['errors']))

    def test_symlink_cannot_escape_skill(self):
        outside = self.root.parent / 'outside.csv'
        outside.write_text('x\n1\n')
        path = self.root / 'examples/demo/data.csv'
        path.unlink()
        path.symlink_to(outside)
        report = self.auditor().audit(self.root)
        self.assertTrue(any('symlink-escape' in e for e in report['errors']))

    def test_unknown_license_is_not_runnable_authorization(self):
        self.case['files'][1]['license'] = 'NOASSERTION'
        self.save()
        report = self.auditor().audit(self.root)
        self.assertTrue(any('unresolved-license' in e for e in report['errors']))

    def test_nonredistributable_input_cannot_reenter_distribution(self):
        manifest = json.loads((self.root / 'public-cases.json').read_text())
        manifest['distribution_exclusions'] = [{'path': 'examples/demo/forbidden.csv',
                                               'reason': 'No input license granted.'}]
        self.write('public-cases.json', json.dumps(manifest))
        self.write('examples/demo/forbidden.csv', 'x\n1\n')
        report = self.auditor().audit(self.root)
        self.assertTrue(any('excluded-file-distributed' in e for e in report['errors']))

    def test_changed_shared_runtime_is_not_hidden_by_case_manifest(self):
        manifest = json.loads((self.root / 'public-cases.json').read_text())
        manifest['shared_runtime_files'] = [self.binding('manifest.yaml', 'config')]
        self.write('public-cases.json', json.dumps(manifest))
        self.write('manifest.yaml', 'version: changed\n')
        report = self.auditor().audit(self.root)
        self.assertTrue(any('shared-runtime: hash-mismatch' in e for e in report['errors']))

    def test_reference_only_case_requires_reason_but_not_unpublished_files(self):
        self.case.update(status='reference-only', limitations=['Author code license not granted.'])
        self.case['files'][1]['path'] = 'library/not-distributed.csv'
        self.save()
        report = self.auditor().audit(self.root)
        self.assertEqual(report['status'], 'PASS', report['errors'])
        self.assertEqual(report['cases'][0]['status'], 'reference-only')

    def test_blocked_case_keeps_truthful_failure_without_runtime_certification(self):
        self.case.update(status='blocked', limitations=['Fresh square-cell geometry gate failed.'])
        self.save()
        report = self.auditor().audit(self.root)
        self.assertEqual(report['status'], 'PASS', report['errors'])
        self.assertEqual(report['case_counts'], {'blocked': 1})
        self.assertFalse(report['cases'][0]['runtime_execution_verified'])

    def test_expected_public_case_cannot_be_silently_dropped(self):
        manifest = json.loads((self.root / 'public-cases.json').read_text())
        manifest['expected_case_ids'] = ['demo', 'omitted']
        self.write('public-cases.json', json.dumps(manifest))
        report = self.auditor().audit(self.root)
        self.assertTrue(any('expected-case-id-mismatch' in e for e in report['errors']))

    def test_required_preview_must_exist_and_be_hash_bound(self):
        self.case['preview_files'] = ['examples/demo/figures/demo.png']
        self.case['expected_preview_formats'] = ['png', 'pdf']
        self.save()
        report = self.auditor().audit(self.root)
        self.assertTrue(any('missing-required-preview' in e for e in report['errors']))
        self.assertTrue(any('preview-not-bound' in e for e in report['errors']))

    def test_machine_path_in_any_distributed_file_fails_privacy_scan(self):
        self.write('atlas/leak.txt', '/' + 'Users/' + 'private-user/private-project/input.csv')
        report = self.auditor().audit(self.root)
        self.assertTrue(any('machine-path' in e for e in report['errors']))

    def test_active_python_skill_parent_dependency_fails(self):
        self.write('examples/demo/run.py', 'source = SKILL.parent / "docs" / "private.png"\n')
        self.case['files'][0] = self.binding('examples/demo/run.py', 'code')
        self.save()
        report = self.auditor().audit(self.root)
        self.assertTrue(any('parent-runtime-dependency' in e for e in report['errors']))

    def test_unlisted_example_provenance_is_not_silently_omitted(self):
        self.write('examples/forgotten/provenance.json', '{}')
        report = self.auditor().audit(self.root)
        self.assertTrue(any('unlisted-public-case' in e for e in report['errors']))

    def test_dry_fresh_install_rechecks_only_isolated_skill(self):
        report = self.auditor().dry_fresh_install(self.root)
        self.assertEqual(report['status'], 'PASS', report['errors'])
        self.assertTrue(report['dry_fresh_install']['skill_only_copy'])
        self.assertFalse(report['dry_fresh_install']['parent_repository_copied'])

    def test_dry_fresh_install_preserves_dependency_failure(self):
        self.case['files'][1]['path'] = '../outside.csv'
        (self.root.parent / 'outside.csv').write_text('x\n1\n')
        self.save()
        report = self.auditor().dry_fresh_install(self.root)
        self.assertEqual(report['status'], 'FAIL')
        self.assertTrue(any('path-escape' in e for e in report['errors']))

    def test_cannabis_public_reference_is_bundled_inside_skill(self):
        skill = AUDITOR.parents[1]
        for name in ('cannabis-cassette', 'cannabis-chr7'):
            case = skill / 'examples/genomics-gallery-20261011' / name
            profile = json.loads((case / 'data/metadata/public-replay.json').read_text())
            reference = (skill / profile['source_asset']).resolve()
            self.assertTrue(reference.is_relative_to(skill), name + ' borrows parent repository')
            self.assertTrue(reference.is_file(), name + ' reference not distributed')

    def test_cannabis_cannot_infer_source_view_or_create_render_output(self):
        skill = AUDITOR.parents[1]
        for name in ('cannabis-cassette', 'cannabis-chr7'):
            case = skill / 'examples/genomics-gallery-20261011' / name
            for entry in ('reproduce.py', 'prepare_spec.py'):
                output = Path(self.tmp.name) / (name + entry)
                result = subprocess.run([sys.executable, str(case/'scripts'/entry),
                                         '--output-dir', str(output)], capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('--source-view-confirmed', result.stderr)
                self.assertFalse(output.exists(), 'source view was inferred and render output was created')

    def test_unavailable_archival_installer_fails_before_creating_library(self):
        skill = AUDITOR.parents[1]
        script = skill/'examples/genomics-gallery-20261011/ohca-microc/scripts/install_native.py'
        library = Path(self.tmp.name)/'no-archival-source-library'
        result = subprocess.run([sys.executable, str(script), str(library)], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('ARCHIVAL_HELPER_UNAVAILABLE', result.stderr)
        self.assertFalse(library.exists())

    def test_public_profile_overlay_preserves_history_and_binds_bundled_files(self):
        skill = AUDITOR.parents[1]
        sys.path.insert(0, str(skill / 'scripts'))
        self.addCleanup(lambda: sys.path.remove(str(skill / 'scripts')))
        import build_learned_method_index as builder
        self.assertTrue(hasattr(builder, 'overlay_public_profiles'), 'public profile overlay is missing')
        self.write('benchmark/cases/demo.json', json.dumps({'case_id': 'demo', 'public_execution_profile': {'scope': 'Own fixed-table replay only'}}))
        self.write('examples/demo/data/metadata/public-replay.json', json.dumps({'method_id': 'DEMO', 'source_asset': 'examples/demo/data.csv', 'scope': 'No full-paper qualification'}))
        original = {'entries': [{'method_id': 'DEMO', 'source_record': 'benchmark/cases/demo.json',
            'source_sha256': 'old', 'mandatory_read_set': ['library/private.R'],
            'material_binding': {'bound': []}, 'learned_contract': {'historical_flag': 'NOT_VERIFIED'}}]}
        overlaid = builder.overlay_public_profiles(original, root=self.root)
        entry = overlaid['entries'][0]
        self.assertIn('library/private.R', entry['archival_source_dependencies']['mandatory_read_set'])
        self.assertNotIn('library/private.R', entry['mandatory_read_set'])
        self.assertIn('examples/demo/data.csv', entry['mandatory_read_set'])
        self.assertEqual(entry['learned_contract']['historical_flag'], 'NOT_VERIFIED')
        self.assertEqual(entry['public_execution_profile']['scope'], 'No full-paper qualification')

    def test_gallery_builder_keeps_chinese_and_english_readmes_separate(self):
        path = AUDITOR.parents[2] / 'tools/build_gallery.py'
        spec = importlib.util.spec_from_file_location('portable_gallery_builder', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        generated = module.generate()
        chinese = generated['README.md'].split('## 分类图廊', 1)[1].split('## 绘图方法', 1)[0]
        self.assertNotIn('<br>', chinese)
        self.assertIn('README.en.md', generated)
        self.assertIn('77', generated['README.en.md'])

    def test_r_dependency_check_never_creates_requested_library(self):
        script = AUDITOR.parent / 'install_public_dependencies.R'
        self.assertTrue(script.is_file(), 'public dependency checker is missing')
        if not shutil.which('Rscript'):
            self.skipTest('Rscript unavailable; no runtime check claimed')
        library = Path(self.tmp.name) / 'must-not-be-created'
        result = subprocess.run(['Rscript', str(script), '--check', '--library', str(library)],
                                capture_output=True, text=True)
        self.assertIn(result.returncode, (0, 2), result.stderr)
        report = json.loads(result.stdout)
        self.assertIn(report['status'], ('READY', 'NEEDS_DEPENDENCIES', 'NEEDS_FONT', 'NEEDS_GHOSTSCRIPT'))
        self.assertFalse(library.exists(), 'read-only dependency check installed or created a library')

    def test_dependency_check_rejects_wrong_r_version_without_installing(self):
        if not shutil.which('Rscript'):
            self.skipTest('Rscript unavailable')
        fixture = Path(self.tmp.name)/'locked-runtime'
        (fixture/'scripts').mkdir(parents=True)
        (fixture/'static/core').mkdir(parents=True)
        for name in ('install_public_dependencies.R', 'figure_style.R'):
            shutil.copyfile(AUDITOR.parent/name, fixture/'scripts'/name)
        lock = (AUDITOR.parents[1]/'static/core/public-runtime-versions.tsv').read_text(encoding='utf-8')
        lock = '\n'.join('R\t99.0.0\t99.0.0\truntime' if line.startswith('R\t') else line
                         for line in lock.splitlines())+'\n'
        (fixture/'static/core/public-runtime-versions.tsv').write_text(lock,encoding='utf-8')
        library = Path(self.tmp.name)/'wrong-version-no-library'
        result = subprocess.run(['Rscript',str(fixture/'scripts/install_public_dependencies.R'),
                                 '--check','--profile','portable','--library',str(library)],
                                capture_output=True,text=True)
        self.assertEqual(result.returncode,2,result.stderr)
        self.assertEqual(json.loads(result.stdout)['status'],'NEEDS_R_VERSION')
        self.assertFalse(library.exists())

    def test_all_public_dependency_profile_declares_pinned_sources(self):
        if not shutil.which('Rscript'):
            self.skipTest('Rscript unavailable')
        library = Path(self.tmp.name)/'all-public-read-only-library'
        result = subprocess.run(['Rscript',str(AUDITOR.parent/'install_public_dependencies.R'),
                                 '--check','--profile','all-public','--library',str(library)],
                                capture_output=True,text=True)
        self.assertIn(result.returncode,(0,2),result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report['profile'],'all-public')
        self.assertEqual({p['package'] for p in report['native_sources']},{'HiCExperiment','HiContacts'})
        self.assertTrue(all(len(p['source_sha256'])==64 for p in report['native_sources']))
        self.assertFalse(library.exists())

    def test_png_only_dependency_check_does_not_require_ghostscript(self):
        if not shutil.which('Rscript'):
            self.skipTest('Rscript unavailable')
        result = subprocess.run([shutil.which('Rscript'), str(AUDITOR.parent / 'install_public_dependencies.R'),
                                 '--check', '--formats', 'png'], capture_output=True, text=True)
        report = json.loads(result.stdout)
        self.assertIn('ghostscript', report, 'PNG/PDF dependency split is missing')
        self.assertFalse(report['ghostscript']['required'])
        self.assertNotEqual(report['status'], 'NEEDS_GHOSTSCRIPT')


if __name__ == '__main__':
    unittest.main()
