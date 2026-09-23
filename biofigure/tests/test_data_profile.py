"""Scientific data boundaries, without asserting model chart-choice quality."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/profile_figure_data.py'
spec = importlib.util.spec_from_file_location('data_profile', SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class DataProfileTests(unittest.TestCase):
    def run_profile(self, content, suffix='.csv', **kwargs):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / ('data' + suffix)
            path.write_text(content, encoding='utf-8-sig')
            return module.profile(path, **kwargs)

    def test_technical_rows_not_biological_n(self):
        result = self.run_profile('id,group,y\na,A,1\na,A,2\nb,A,3\nb,A,4\n',
                                  groups=['group'], unit='id')
        self.assertEqual(result['groups'][0]['rows'], 4)
        self.assertEqual(result['groups'][0]['unique_declared_units'], 2)
        self.assertEqual(result['groups'][0]['extra_rows_per_unit_group_key'], 2)

    def test_numeric_id_not_auto_measurement(self):
        result = self.run_profile('id,y\n001,3\n002,4\n')
        self.assertEqual(result['columns']['id']['semantic_role'], 'unresolved')
        self.assertIsNone(result['unique_declared_units_total'])

    def test_paired_rows_count_subjects_once_globally(self):
        result = self.run_profile('id,time,y\na,0,1\na,1,2\nb,0,3\nb,1,4\n',
                                  groups=['time'], unit='id')
        self.assertEqual(result['unique_declared_units_total'], 2)
        self.assertEqual([x['unique_declared_units'] for x in result['groups']], [2, 2])

    def test_summary_table_not_reconstructed(self):
        result = self.run_profile('group,mean,SD,n\nA,5,1,10\nB,8,2,10\n')
        self.assertEqual(result['rows'], 2)
        self.assertIsNone(result['unique_declared_units_total'])
        self.assertNotIn('recommended', result)

    def test_na_label_preserved_unless_declared(self):
        text = 'group,y\nNA,0\nB,\n'
        default = self.run_profile(text)
        explicit = self.run_profile(text, missing_tokens=['NA'])
        self.assertEqual(default['columns']['group']['missing_rows'], 0)
        self.assertEqual(explicit['columns']['group']['missing_rows'], 1)
        self.assertEqual(default['columns']['y']['finite_numeric_summary']['zeros'], 1)

    def test_tsv_nonfinite_and_missing_units(self):
        result = self.run_profile('id\ty\na\tInf\n\tNaN\nb\t-2\n', suffix='.tsv', unit='id')
        self.assertEqual(result['columns']['y']['nonfinite_numeric_rows'], 2)
        self.assertEqual(result['groups'][0]['missing_unit_rows'], 1)
        self.assertEqual(result['columns']['y']['finite_numeric_summary']['min'], -2)

    def test_malformed_input_rejected(self):
        for text in ['', 'x,x\n1,2\n', 'x,y\n1\n', 'x,y\n', ',x\n1,2\n']:
            with self.subTest(text=text), self.assertRaises(ValueError):
                self.run_profile(text)

    def test_unknown_group_rejected(self):
        with self.assertRaisesRegex(ValueError, 'unknown column'):
            self.run_profile('x\n1\n', groups=['group'])


if __name__ == '__main__':
    unittest.main()
