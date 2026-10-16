"""Physical cell geometry for displayed rectangular matrices, not whole canvases."""
from __future__ import annotations

import math
import re

POLICY_ID = 'heatmap-cells-v1'
MAX_SMALL_DIMENSION = 200  # Routing default, not a biological/journal standard.


def requires_cell_geometry(doc: dict) -> bool:
    if not isinstance(doc, dict):
        return False
    if 'heatmap_cell_contract' in doc:
        return True
    analysis = doc.get('reference_analysis', {}) or {}
    family = str(analysis.get('figure_family', ''))
    # Polar sectors do not have rectangular cells. They require a separate
    # source/geometry decision; do not label their sectors as square cells.
    topology = analysis.get('spatial_topology', {}) or {}
    if topology.get('coordinate_system') in {'polar', 'circular'}:
        return False
    task = str(doc.get('figure_task', ''))
    description = family + ' ' + task
    if re.search(r'(?:dot|bubble)[ _-]?(?:plot|matrix)|气泡|点阵', description, re.I):
        return False  # A bubble matrix is not a rectangular-cell heatmap.
    renderer = doc.get('renderer', {}) or {}
    native = any(str(renderer.get(key, '')).casefold() in {'complexheatmap','pheatmap','corrplot'}
                 for key in ('backend','package','name')) if isinstance(renderer,dict) else False
    return (str(doc.get('selected_pattern', '')).startswith('MAT-')
            or native or bool(re.search(r'heat[ _-]?map|热图|correlation[ _-]?matrix|contact[ _-]?matrix|相关.*矩阵|接触矩阵', description, re.I)))


def positive(value):
    return type(value) in (int, float) and math.isfinite(value) and value > 0


def validate_cell_contract(doc: dict) -> list[str]:
    if not requires_cell_geometry(doc):
        return []
    c = doc.get('heatmap_cell_contract')
    prefix = 'heatmap_cell_contract'
    if not isinstance(c, dict):
        return [prefix + ' required for rectangular heatmaps']
    errors = []
    if c.get('policy_id') != POLICY_ID or c.get('measurement_basis') != 'final_body_viewports_mm':
        errors.append(prefix + ' requires the current policy and final_body_viewports_mm measurement')
    for key in ('rows', 'columns'):
        if type(c.get(key)) is not int or c[key] <= 0:
            errors.append(prefix + '.' + key + ' must count the actually displayed matrix')
    mode = c.get('shape')
    if mode not in {'square', 'dense-overview'}:
        errors.append(prefix + '.shape must be square or explicit dense-overview')
    tolerance = c.get('max_relative_error')
    if not positive(tolerance) or tolerance > .01:
        errors.append(prefix + '.max_relative_error must be positive and <=0.01')
    if (mode == 'dense-overview' and all(type(c.get(k)) is int for k in ('rows', 'columns'))
            and max(c['rows'], c['columns']) <= MAX_SMALL_DIMENSION):
        errors.append(prefix + ': small displayed matrices require square cells; dense-overview is not an exemption')
    if mode == 'dense-overview' and not str(c.get('density_reason', '')).strip():
        errors.append(prefix + '.density_reason must explain why individual cells are not the reading target')
    return errors


def validate_cell_metrics(metrics, doc: dict) -> list[str]:
    errors = validate_cell_contract(doc)
    if not isinstance(metrics, list) or not metrics:
        return errors + ['heatmap_cells requires nonempty actual per-panel/per-slice measurements']
    c = doc.get('heatmap_cell_contract') or {}
    mode = c.get('shape', 'square')
    tolerance = c.get('max_relative_error', .01)
    if not positive(tolerance) or tolerance > .01:
        tolerance = .01
    ids = set()
    coverage = {}
    for index, item in enumerate(metrics):
        p = f'heatmap_cells[{index}]'
        if not isinstance(item, dict):
            errors.append(p + ' must be a measurement mapping')
            continue
        if not item.get('panel_id') or item['panel_id'] in ids:
            errors.append(p + '.panel_id must identify a unique body/slice')
        ids.add(str(item.get('panel_id')))
        if item.get('measurement_method') != 'final_body_viewports_mm':
            errors.append(p + ' must measure actual final body viewports, not data units or canvas ratio')
        counts_ok = all(type(item.get(k)) is int and item[k] > 0 for k in ('rows', 'columns'))
        dimensions_ok = all(positive(item.get(k)) for k in ('body_width_mm', 'body_height_mm', 'cell_width_mm', 'cell_height_mm'))
        if not counts_ok or not dimensions_ok:
            errors.append(p + ' requires finite physical sizes and positive displayed row/column counts')
            continue
        for axis, count in (('width', 'columns'), ('height', 'rows')):
            expected = item['body_' + axis + '_mm'] / item[count]
            if not math.isclose(expected, item['cell_' + axis + '_mm'], rel_tol=1e-6, abs_tol=1e-9):
                errors.append(p + ' cell dimensions disagree with measured body/counts')
        full_rows = item.get('matrix_rows', item['rows'])
        full_columns = item.get('matrix_columns', item['columns'])
        if (type(full_rows) is not int or type(full_columns) is not int
                or full_rows < item['rows'] or full_columns < item['columns']):
            errors.append(p + ' invalid displayed full-matrix counts')
            continue
        if c and (full_rows != c.get('rows') or full_columns != c.get('columns')):
            errors.append(p + ' displayed matrix counts differ from Design Spec; raw input counts cannot exempt a small subset')
        group = str(item.get('matrix_id', 'main'))
        recorded = coverage.setdefault(group, {'rows': full_rows, 'columns': full_columns, 'cells': 0})
        if recorded['rows'] != full_rows or recorded['columns'] != full_columns:
            errors.append(p + ' slices disagree on displayed full-matrix counts')
        recorded['cells'] += item['rows'] * item['columns']
        if mode == 'dense-overview':
            if max(full_rows, full_columns) <= MAX_SMALL_DIMENSION:
                errors.append(p + ' small displayed matrix cannot use dense-overview')
        elif abs(item['cell_width_mm'] / item['cell_height_mm'] - 1) > tolerance + 1e-9:
            errors.append(p + ' cells are not physically square')
    for group, record in coverage.items():
        if record['cells'] != record['rows'] * record['columns']:
            errors.append('heatmap_cells ' + group + ' slices do not completely cover the displayed matrix; raw counts cannot authorize a small subset')
    return errors
