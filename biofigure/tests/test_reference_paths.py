"""Reference paths keep task documents separate from the installed Skill."""
import contextlib
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'scripts/reference_paths.py'


@contextlib.contextmanager
def at_directory(path):
    previous = Path.cwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(previous)


class ReferencePathTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='biofigure-reference-paths-')
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name).resolve()
        self.project = self.base / 'task-project'
        self.document = self.project / 'work/call/design.yaml'
        self.document.parent.mkdir(parents=True)
        self.document.write_text('schema_version: fixture\n')
        self.other = self.base / 'unrelated-cwd'
        self.other.mkdir()
        self.install = self.base / 'skills/biofigure'
        self.install.mkdir(parents=True)

    def helper(self):
        self.assertTrue(HELPER.is_file(), 'Task reference path resolver is not implemented')
        spec = importlib.util.spec_from_file_location('biofigure_reference_path_unit', HELPER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_document_relative_file_is_independent_of_cwd_and_installation(self):
        module = self.helper()
        source = self.document.parent / 'source-lock.json'
        source.write_text('{}')
        for cwd in (self.project, self.document.parent, self.other):
            with self.subTest(cwd=cwd), at_directory(cwd):
                self.assertEqual(module.resolve_reference_path('source-lock.json', document_path=self.document), source)

    def test_absolute_file_is_independent_of_cwd(self):
        module = self.helper()
        source = self.project / 'absolute-lock.json'
        source.write_text('{}')
        for cwd in (self.project, self.document.parent, self.other):
            with self.subTest(cwd=cwd), at_directory(cwd):
                self.assertEqual(module.resolve_reference_path(str(source), document_path=self.document), source)

    def test_explicit_project_root_resolves_project_relative_file(self):
        module = self.helper()
        source = self.project / 'work/source-lock.json'
        source.write_text('{}')
        for cwd in (self.project, self.document.parent, self.other):
            with self.subTest(cwd=cwd), at_directory(cwd):
                self.assertEqual(module.resolve_reference_path('work/source-lock.json', document_path=self.document,
                                                             project_root=self.project), source)

    def test_two_distinct_existing_contextual_files_are_ambiguous(self):
        module = self.helper()
        (self.document.parent / 'source-lock.json').write_text('document copy')
        (self.project / 'source-lock.json').write_text('project copy')
        with self.assertRaisesRegex(ValueError, 'ambiguous'):
            module.resolve_reference_path('source-lock.json', document_path=self.document, project_root=self.project)

    def test_two_contexts_pointing_to_same_file_are_not_ambiguous(self):
        module = self.helper()
        source = self.document.parent / 'source-lock.json'
        source.write_text('{}')
        self.assertEqual(module.resolve_reference_path('source-lock.json', document_path=self.document,
                                                      project_root=self.document.parent), source)

    def test_missing_document_file_does_not_borrow_unrelated_cwd_file(self):
        module = self.helper()
        (self.other / 'source-lock.json').write_text('unrelated file')
        with at_directory(self.other):
            resolved = module.resolve_reference_path('source-lock.json', document_path=self.document)
        self.assertEqual(resolved, self.document.parent / 'source-lock.json')
        self.assertFalse(resolved.is_file())

    def test_no_context_keeps_legacy_cli_relative_paths(self):
        module = self.helper()
        source = self.other / 'source-lock.json'
        source.write_text('{}')
        with at_directory(self.other):
            self.assertEqual(module.resolve_reference_path('source-lock.json'), source)

    def test_empty_reference_path_is_rejected(self):
        module = self.helper()
        for value in ('', '   ', None):
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, 'non-empty'):
                module.resolve_reference_path(value, document_path=self.document)

    def test_relative_declared_project_root_is_based_on_lock_directory(self):
        module = self.helper()
        lock = self.document.parent / 'source-lock.json'
        for cwd in (self.project, self.document.parent, self.other):
            with self.subTest(cwd=cwd), at_directory(cwd):
                self.assertEqual(module.resolve_project_root('../..', document_path=lock), self.project)

    def test_empty_project_root_never_defaults_to_cwd(self):
        module = self.helper()
        for value in ('', '   ', None):
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, 'non-empty'):
                module.resolve_project_root(value, document_path=self.document)

    def test_project_root_must_be_existing_directory(self):
        module = self.helper()
        for value in (str(self.project / 'missing'), str(self.document)):
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, 'directory'):
                module.resolve_project_root(value, document_path=self.document)


class IsolatedPrimarySourceLockTests(unittest.TestCase):
    """Copy only import dependencies; no library or benchmark archive is copied."""
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='biofigure-primary-lock-')
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name).resolve()
        self.project = self.base / 'task-project'
        self.call = self.project / 'work/call'
        self.call.mkdir(parents=True)
        self.unrelated = self.base / 'unrelated-cwd'
        self.unrelated.mkdir()
        self.install = self.base / 'skills/biofigure'
        script_dir = self.install / 'scripts'
        script_dir.mkdir(parents=True)
        for name in ('validate_checkpoints.py', 'figure_text_policy.py', 'heatmap_geometry.py', 'reference_modes.py'):
            shutil.copy2(ROOT / 'scripts' / name, script_dir / name)
        if HELPER.is_file():
            shutil.copy2(HELPER, script_dir / HELPER.name)
        sys.path.insert(0, str(script_dir))
        self.addCleanup(sys.path.remove, str(script_dir))
        spec = importlib.util.spec_from_file_location('biofigure_isolated_primary_lock', script_dir / 'validate_checkpoints.py')
        self.validator = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.validator)
        self.source = {'title': 'Path fixture', 'doi': '10.0000/path-fixture', 'url': 'https://example.org/path-fixture',
                       'figure': '2', 'panel': 'b'}
        files = []
        for role, filename in (('figure_asset', 'figure.png'), ('author_code', 'author.R'), ('source_data', 'source.csv')):
            path = self.project / 'work/source-assets' / filename
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(role + '\n')
            files.append({'role': role, 'path': str(path.relative_to(self.project)),
                          'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
        self.lock = {'schema_version': 1, 'kind': 'primary-source-lock', 'query': 'fixture',
                     'project_root': str(self.project), 'primary_source': self.source, 'source_files': files,
                     'source_mapping': [{'panel': '2b', 'author_code': 'author_code', 'source_data': 'source_data'}],
                     'inspection': {'original_figure_opened': True},
                     'generation_contract': {'author_material_access': 'authorized-inspection-no-copy',
                         'implementation': 'new-script-from-user-data-and-derived-patterns', 'blind_generation': False}}
        self.lock_path = self.call / 'source-lock.json'

    def write_lock(self):
        self.lock_path.write_text(json.dumps(self.lock))

    def test_absolute_project_root_lock_survives_three_cwds(self):
        self.write_lock()
        for cwd in (self.project, self.call, self.unrelated):
            with self.subTest(cwd=cwd), at_directory(cwd):
                self.assertEqual(self.validator.validate_reproduction_receipt(str(self.lock_path)), [])

    def test_relative_project_root_lock_survives_three_cwds(self):
        self.lock['project_root'] = '../..'
        self.write_lock()
        for cwd in (self.project, self.call, self.unrelated):
            with self.subTest(cwd=cwd), at_directory(cwd):
                self.assertEqual(self.validator.validate_reproduction_receipt(str(self.lock_path)), [])

    def test_empty_project_root_is_rejected(self):
        self.lock['project_root'] = ''
        self.write_lock()
        with at_directory(self.project):
            errors = self.validator.validate_reproduction_receipt(str(self.lock_path))
        self.assertTrue(errors, 'An empty root must not silently become the current project')

    def test_changed_source_data_is_still_rejected(self):
        self.write_lock()
        (self.project / self.lock['source_files'][2]['path']).write_text('changed source data\n')
        errors = self.validator.validate_reproduction_receipt(str(self.lock_path))
        self.assertTrue(any('hash changed' in error for error in errors), errors)

    def test_source_path_escape_is_still_rejected(self):
        outside = self.base / 'outside.png'
        outside.write_text('outside')
        self.lock['source_files'][0].update(path='../outside.png', sha256=hashlib.sha256(outside.read_bytes()).hexdigest())
        self.write_lock()
        errors = self.validator.validate_reproduction_receipt(str(self.lock_path))
        self.assertTrue(any('escapes project root' in error for error in errors), errors)

    def test_symlink_escape_is_still_rejected(self):
        outside = self.base / 'outside.png'
        outside.write_text('outside')
        link = self.project / 'work/source-assets/linked.png'
        link.symlink_to(outside)
        self.lock['source_files'][0].update(path=str(link.relative_to(self.project)), sha256=hashlib.sha256(outside.read_bytes()).hexdigest())
        self.write_lock()
        errors = self.validator.validate_reproduction_receipt(str(self.lock_path))
        self.assertTrue(any('escapes project root' in error for error in errors), errors)


if __name__ == '__main__':
    unittest.main()
