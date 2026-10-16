import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class TestProfileTests(unittest.TestCase):
    def runner(self):
        path = ROOT / 'scripts/run_public_tests.py'
        self.assertTrue(path.is_file(), 'Explicit public/archive test profiles are not implemented')
        spec = importlib.util.spec_from_file_location('public_test_profiles', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_public_profile_keeps_core_gates_and_reports_archival_not_run(self):
        runner = self.runner()
        tests = runner.discover()
        selected, deferred = runner.select_profile(tests, 'public')
        selected_ids = [test.id() for test in selected]
        self.assertTrue(any(name.startswith('test_reference_modes.') for name in selected_ids))
        self.assertTrue(any(name.startswith('test_statistics_plan.') for name in selected_ids))
        self.assertTrue(any(name.startswith('test_heatmap_geometry.') for name in selected_ids))
        self.assertTrue(any(name.startswith('test_render_authorization.') for name in selected_ids))
        self.assertTrue(any(name.startswith('test_public_examples.') for name in selected_ids))
        self.assertTrue(deferred)
        self.assertTrue(all(row['status'] == 'NOT_RUN' and row['reason'] and row['inputs'] for row in deferred))
        all_selected, all_deferred = runner.select_profile(tests, 'all')
        self.assertEqual(len(all_selected), len(tests))
        self.assertEqual(all_deferred, [])

    def test_archive_profile_only_runs_explicit_archive_dependencies(self):
        runner = self.runner()
        tests = runner.discover()
        public, deferred = runner.select_profile(tests, 'public')
        archive, ignored = runner.select_profile(tests, 'archive')
        self.assertEqual({test.id() for test in archive}, {row['test'] for row in deferred})
        self.assertEqual(len(public) + len(archive), len(tests))


if __name__ == '__main__':
    unittest.main()
