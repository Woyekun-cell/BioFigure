"""The public OncoPrint must preserve its full matrix under the sparse-cell rule."""
import csv
import importlib.util
from pathlib import Path
import subprocess
import sys
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]
CASE = ROOT / 'examples/genomics-gallery-20261011/oncoprint'
module_spec = importlib.util.spec_from_file_location('onco_geometry', ROOT / 'scripts/heatmap_geometry.py')
geometry = importlib.util.module_from_spec(module_spec)
module_spec.loader.exec_module(geometry)


class PublicOncoprintTests(unittest.TestCase):
    def test_whole_matrix_declares_square_cells_and_three_contiguous_blocks(self):
        spec = yaml.safe_load((CASE / 'data/metadata/design-template.yaml').read_text())
        self.assertEqual(geometry.validate_cell_contract(spec), [])
        contract = spec['heatmap_cell_contract']
        self.assertEqual((contract['rows'], contract['columns'], contract['shape']), (12, 144, 'square'))
        self.assertEqual(spec['output_size']['width_mm'], 183)
        self.assertLessEqual(spec['output_size']['height_mm'], 170)
        blocks = spec['sample_block_contract']
        self.assertEqual([(b['first_column'], b['last_column']) for b in blocks], [(1, 48), (49, 96), (97, 144)])
        self.assertEqual([b['cohort'] for b in blocks], ['A', 'B', 'C'])
        self.assertNotIn('note', [e['id'] for e in spec['reference_analysis']['elements']])
        self.assertFalse(spec['text_contract']['allow_footer'])

    def test_original_scientific_audit_still_accepts_every_raw_event_and_id(self):
        result = subprocess.run([sys.executable, str(CASE / 'scripts/audit_inputs.py'), str(CASE), '--check-only'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        with (CASE / 'data/raw/simulated_events.csv').open() as handle:
            self.assertEqual(len(list(csv.DictReader(handle))), 424)

    def test_three_square_blocks_cover_full_144_but_two_blocks_fail(self):
        spec = yaml.safe_load((CASE / 'data/metadata/design-template.yaml').read_text())
        items = [dict(panel_id=f'block-{i}', matrix_id='Alteration', rows=12, columns=48,
                      matrix_rows=12, matrix_columns=144, body_width_mm=100.8, body_height_mm=25.2,
                      cell_width_mm=2.1, cell_height_mm=2.1, measurement_method='final_body_viewports_mm')
                 for i in range(3)]
        self.assertEqual(geometry.validate_cell_metrics(items, spec), [])
        self.assertTrue(geometry.validate_cell_metrics(items[:2], spec))
        items[0]['body_width_mm'] = 96
        items[0]['cell_width_mm'] = 2
        self.assertTrue(any('physically square' in e for e in geometry.validate_cell_metrics(items, spec)))


if __name__ == '__main__':
    unittest.main()
