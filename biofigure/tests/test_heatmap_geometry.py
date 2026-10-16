"""Displayed heatmap cells must satisfy the physical geometry contract."""
import copy
import importlib.util
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    'heatmap_geometry', ROOT / 'scripts' / 'heatmap_geometry.py')
geometry = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(geometry)


def design(rows=20, columns=20, shape='square'):
    contract = {
        'policy_id': 'heatmap-cells-v1',
        'shape': shape,
        'rows': rows,
        'columns': columns,
        'measurement_basis': 'final_body_viewports_mm',
        'max_relative_error': .01,
    }
    if shape == 'dense-overview':
        contract['density_reason'] = '5000 displayed genes; read modules, not individual cells'
    return {
        'selected_pattern': 'MAT-heatmap',
        'reference_analysis': {'figure_family': 'rectangular expression heatmap'},
        'heatmap_cell_contract': contract,
    }


def measured(rows=20, columns=20, width=40., height=40., panel_id='main', **extra):
    return {
        'panel_id': panel_id,
        'measurement_method': 'final_body_viewports_mm',
        'rows': rows,
        'columns': columns,
        'body_width_mm': width,
        'body_height_mm': height,
        'cell_width_mm': width / columns,
        'cell_height_mm': height / rows,
        **extra,
    }


class HeatmapGeometryTests(unittest.TestCase):
    def test_rectangular_heatmap_requires_an_explicit_contract(self):
        for doc in (
            {'selected_pattern': 'MAT-correlation'},
            {'reference_analysis': {'figure_family': 'heatmap'}},
            {'figure_task': '表达热图'},
        ):
            with self.subTest(doc=doc):
                self.assertTrue(geometry.requires_cell_geometry(doc))
                self.assertTrue(geometry.validate_cell_contract(doc))

    def test_small_displayed_matrix_passes_only_with_square_physical_cells(self):
        doc = design()
        self.assertEqual(geometry.validate_cell_contract(doc), [])
        self.assertEqual(geometry.validate_cell_metrics([measured()], doc), [])
        # A square canvas does not help when the actual heatmap body is wide.
        errors = geometry.validate_cell_metrics([measured(width=60.)], doc)
        self.assertTrue(any('physically square' in error for error in errors))

    def test_dense_5000_by_20_allows_flat_cells_but_requires_actual_measurements(self):
        doc = design(rows=5000, shape='dense-overview')
        self.assertEqual(geometry.validate_cell_contract(doc), [])
        self.assertEqual(geometry.validate_cell_metrics(
            [measured(rows=5000, width=60., height=100.)], doc), [])
        for missing in (None, [], {}, 'canvas is square'):
            with self.subTest(missing=missing):
                self.assertTrue(geometry.validate_cell_metrics(missing, doc))
        doc['heatmap_cell_contract'].pop('density_reason')
        self.assertTrue(geometry.validate_cell_contract(doc))

    def test_small_matrix_cannot_claim_dense_exemption(self):
        doc = design(shape='dense-overview')
        self.assertTrue(geometry.validate_cell_contract(doc))
        self.assertTrue(geometry.validate_cell_metrics([measured(width=60.)], doc))

    def test_raw_5000_rows_cannot_exempt_an_actually_displayed_20_row_subset(self):
        doc = design(rows=5000, shape='dense-overview')
        errors = geometry.validate_cell_metrics([measured(width=60.)], doc)
        self.assertTrue(any('displayed matrix counts differ' in error for error in errors))
        self.assertTrue(any('small displayed matrix' in error for error in errors))

    def test_scalar_full_counts_cannot_disguise_one_20_by_20_subset_as_5000_genes(self):
        doc = design(rows=5000, shape='dense-overview')
        # Merely claiming the full matrix is large must not make this one
        # measured 20-row viewport a valid 5000-row split-matrix overview.
        subset = measured(width=60., matrix_rows=5000, matrix_columns=20)
        self.assertTrue(geometry.validate_cell_metrics([subset], doc))

    def test_declared_cell_size_must_equal_actual_body_divided_by_displayed_counts(self):
        for key in ('cell_width_mm', 'cell_height_mm'):
            with self.subTest(key=key):
                item = measured()
                item[key] *= 2
                errors = geometry.validate_cell_metrics([item], design())
                self.assertTrue(any('body/counts' in error for error in errors))

    def test_contract_rejects_non_integer_nonfinite_and_boolean_counts(self):
        for key in ('rows', 'columns'):
            for value in (float('nan'), float('inf'), -float('inf'), True, False, 20.0, 0, -1):
                with self.subTest(key=key, value=value):
                    doc = design()
                    doc['heatmap_cell_contract'][key] = value
                    self.assertTrue(geometry.validate_cell_contract(doc))

    def test_actual_measurements_reject_invalid_counts_and_nonfinite_physical_sizes(self):
        for key in ('rows', 'columns', 'matrix_rows', 'matrix_columns'):
            for value in (float('nan'), float('inf'), -float('inf'), True, False, 0, -1):
                with self.subTest(key=key, value=value):
                    item = measured()
                    item[key] = value
                    self.assertTrue(geometry.validate_cell_metrics([item], design()))
        for key in ('body_width_mm', 'body_height_mm', 'cell_width_mm', 'cell_height_mm'):
            for value in (float('nan'), float('inf'), -float('inf'), True, False, 0, -1):
                with self.subTest(key=key, value=value):
                    item = measured()
                    item[key] = value
                    self.assertTrue(geometry.validate_cell_metrics([item], design()))

    def test_native_split_matrix_accepts_actual_per_slice_viewport_measurements(self):
        doc = design(rows=40, columns=30)
        slices = [
            measured(rows=10, columns=30, width=60., height=20., panel_id='row-slice-1',
                     matrix_rows=40, matrix_columns=30),
            measured(rows=30, columns=30, width=60., height=60., panel_id='row-slice-2',
                     matrix_rows=40, matrix_columns=30),
        ]
        self.assertEqual(geometry.validate_cell_metrics(slices, doc), [])
        broken = copy.deepcopy(slices)
        broken[1] = measured(rows=30, columns=30, width=60., height=45., panel_id='row-slice-2',
                             matrix_rows=40, matrix_columns=30)
        self.assertTrue(geometry.validate_cell_metrics(broken, doc))

    def test_data_units_canvas_ratios_and_reused_slice_ids_are_not_measurement_evidence(self):
        for method in ('data_units', 'canvas_ratio', None):
            with self.subTest(method=method):
                item = measured()
                item['measurement_method'] = method
                self.assertTrue(geometry.validate_cell_metrics([item], design()))
        self.assertTrue(geometry.validate_cell_metrics([measured(), measured()], design()))

    def test_contract_policy_shape_and_tolerance_are_enforced(self):
        for key, value in (
            ('policy_id', 'obsolete'), ('measurement_basis', 'canvas_ratio'),
            ('shape', 'automatic'), ('max_relative_error', .02),
            ('max_relative_error', 0), ('max_relative_error', float('nan')),
            ('max_relative_error', float('inf')), ('max_relative_error', True),
        ):
            with self.subTest(key=key, value=value):
                doc = design()
                doc['heatmap_cell_contract'][key] = value
                self.assertTrue(geometry.validate_cell_contract(doc))

    def test_scatter_and_polar_heatmap_are_not_forced_into_rectangular_cell_geometry(self):
        for doc in (
            {'selected_pattern': 'SCAT-scatter', 'reference_analysis': {'figure_family': 'scatter'}},
            {'selected_pattern': 'MAT-polar-heatmap', 'reference_analysis': {
                'figure_family': 'circular heatmap', 'spatial_topology': {'coordinate_system': 'polar'}}},
            {'reference_analysis': {'figure_family': 'circular heatmap',
                                    'spatial_topology': {'coordinate_system': 'circular'}}},
        ):
            with self.subTest(doc=doc):
                self.assertFalse(geometry.requires_cell_geometry(doc))
                self.assertEqual(geometry.validate_cell_contract(doc), [])

    def test_semantic_matrix_roles_require_geometry_even_with_learned_pattern_ids(self):
        for doc in (
            {'selected_pattern': 'LEARNED-correlation-source',
             'reference_analysis': {'figure_family': 'correlation matrix'},
             'renderer': {'backend': 'ComplexHeatmap', 'language': 'R'}},
            {'selected_pattern': 'LEARNED-hic-source',
             'figure_task': 'Hi-C contact matrix',
             'reference_analysis': {'figure_family': 'chromosome contact matrix'},
             'renderer': {'backend': 'native-grid', 'language': 'R'}},
        ):
            with self.subTest(doc=doc):
                self.assertTrue(geometry.requires_cell_geometry(doc))
                self.assertTrue(geometry.validate_cell_contract(doc))

    def test_dot_and_bubble_matrices_do_not_inherit_square_tile_requirements(self):
        for family in ('dot matrix', 'bubble matrix'):
            doc = {
                'selected_pattern': 'MAT-bubble-expression',
                'reference_analysis': {'figure_family': family,
                                       'spatial_topology': {'coordinate_system': 'cartesian'}},
                'renderer': {'backend': 'ggplot2', 'language': 'R'},
            }
            with self.subTest(family=family):
                self.assertFalse(geometry.requires_cell_geometry(doc))
                self.assertEqual(geometry.validate_cell_contract(doc), [])


if __name__ == '__main__':
    unittest.main()
