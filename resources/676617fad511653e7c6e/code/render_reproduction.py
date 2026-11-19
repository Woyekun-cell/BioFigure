#!/usr/bin/env python3
"""Replay frozen, genuinely recomputed CellRank inputs using the original renderers.

This never estimates a new fate model and never reads source pixels as plot data.
Run with the pinned 2021 scientific environment; see setup_original_environment.sh.
"""
import argparse
import hashlib
import json
import time
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.collections import PathCollection
from matplotlib.text import Text
import numpy as np
import pandas as pd
from anndata import AnnData
import cellrank as cr
from cellrank.tl import Lineage
import scanpy as sc
import scvelo as scv

GENES = ['Bpifb1', 'Krt5', 'Trp63']
FORMAL_ORDER = ['Neuroendocrine', 'Krt8+ ADI', 'AT2 activated',
                'Mki67+ proliferation', 'Basal', 'Goblet', 'Ciliated',
                'Ciliated activated_1', 'Ciliated activated_2']
FONT = Path('/System/Library/Fonts/Supplemental/Arial.ttf')
WIDTH, HEIGHT = 180., 115.


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def rect(x, y, w, h):
    """Physical mm, bottom left."""
    return [x / WIDTH, y / HEIGHT, w / WIDTH, h / HEIGHT]


def load_inputs(folder):
    meta = json.loads((folder / 'lung-fate-metadata.json').read_text())
    fate = pd.read_csv(folder / 'lung-fate.csv', index_col='cell_id')
    sub = pd.read_csv(folder / 'goblet-basal-stage-expression.csv', index_col='cell_id')
    assert fate.index.is_unique and sub.index.is_unique
    assert len(fate) == 24882 and len(sub) == 1239
    assert set(sub.clusters) == {'Goblet', 'Basal'}
    names, colors = meta['lineage_names'], meta['lineage_colors']
    assert len(names) == 9 and set(names) == set(FORMAL_ORDER), names
    P = fate[names].values
    assert np.isfinite(P).all() and P.min() >= -1e-10
    np.testing.assert_allclose(P.sum(1), 1, atol=1e-4)
    full = AnnData(np.empty((len(fate), 0)), obs=pd.DataFrame(index=fate.index))
    full.obs['clusters'] = pd.Categorical(fate.clusters,
                                         categories=meta['cluster_categories'])
    full.uns['clusters_colors'] = meta['cluster_colors']
    full.obsm['to_terminal_states'] = Lineage(P, names=names, colors=colors)
    # Original bdata.raw.X is float32. Restore that dtype after CSV parsing so
    # Scanpy's group means retain the original aggregation rounding semantics.
    b = AnnData(sub[GENES].values.astype(np.float32),
                obs=sub.drop(columns=GENES).copy(), var=pd.DataFrame(index=GENES))
    b.obs['clusters'] = pd.Categorical(b.obs.clusters, categories=['Basal', 'Goblet'])
    keyed = dict(zip(meta['cluster_categories'], meta['cluster_colors']))
    b.uns['clusters_colors'] = [keyed[k] for k in b.obs.clusters.cat.categories]
    b.obs['stage'] = pd.Categorical(b.obs.stage, categories=['stage 1', 'stage 2', 'stage 3'])
    b.raw = b.copy()
    return full, b, meta


def summarize_text(fig):
    renderer = fig.canvas.get_renderer()
    result = []
    hidden_axis_text = set()
    for ax in fig.axes:
        for axis in [ax.xaxis, ax.yaxis]:
            if not ax.axison or not axis.get_visible():
                hidden_axis_text.update(id(t) for t in axis.findobj(Text))
    for text in fig.findobj(Text):
        if id(text) not in hidden_axis_text and text.get_visible() and text.get_text().strip():
            box = text.get_window_extent(renderer)
            result.append({'text': text.get_text(), 'font_pt': text.get_fontsize(),
                           'font_family': text.get_fontfamily(),
                           'bbox_mm': [v / fig.dpi * 25.4 for v in box.bounds]})
    return result


def check_terminal_label_rectangles(ax, renderer, dpi):
    """Check rotated text rectangles, avoiding misleading axis-aligned boxes."""
    words = []
    for t in ax.texts:
        center = t.get_transform().transform(t.get_position())
        width, height, _ = renderer.get_text_width_height_descent(
            t.get_text(), t.get_fontproperties(), ismath=False)
        height = max(height, t.get_fontsize() * dpi / 72)
        angle = np.deg2rad(t.get_rotation())
        u = np.array([np.cos(angle), np.sin(angle)])
        v = np.array([-np.sin(angle), np.cos(angle)])
        words.append((t.get_text(), center, u, v, width/2, height/2))
    min_gap = float('inf')
    for i, a in enumerate(words):
        for b in words[i+1:]:
            gaps = []
            for axis in [a[2], a[3], b[2], b[3]]:
                half_a = abs(axis@a[2])*a[4] + abs(axis@a[3])*a[5]
                half_b = abs(axis@b[2])*b[4] + abs(axis@b[3])*b[5]
                gaps.append(abs(axis@(b[1]-a[1])) - half_a - half_b)
            gap_mm = max(gaps) / dpi * 25.4
            if gap_mm <= 0:
                raise RuntimeError('Terminal labels overlap: '+a[0]+' / '+b[0])
            min_gap = min(min_gap, gap_mm)
    return min_gap


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--inputs', type=Path,
                        default=Path(__file__).resolve().parents[1] / 'data' / 'derived')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    started = time.time()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    assert FONT.is_file(), FONT
    font_manager.fontManager.addfont(str(FONT))
    resolved = Path(font_manager.findfont('Arial', fallback_to_default=False))
    assert resolved.name == FONT.name, resolved
    scv.settings.set_figure_params('scvelo', dpi_save=300, dpi=150,
                                  transparent=False, fontsize=10, color_map='viridis')
    plt.rcParams.update({'font.family': 'Arial', 'font.size': 10,
                         'axes.labelsize': 10, 'axes.titlesize': 10,
                         'xtick.labelsize': 10, 'ytick.labelsize': 10,
                         'legend.fontsize': 10, 'pdf.fonttype': 42,
                         'ps.fonttype': 42, 'svg.fonttype': 'none',
                         'axes.linewidth': .45, 'savefig.facecolor': 'white'})
    full, b, meta = load_inputs(args.inputs)

    # Native computation and drawing. Explicit order resolves the source notebook's
    # vertical reflection relative to the published manuscript. No coordinates traced.
    cr.pl.circular_projection(full, keys=['clusters'], ncols=1,
                              lineages=FORMAL_ORDER, lineage_order='default',
                              normalize_by_mean=True, legend_loc='none',
                              figsize=(WIDTH / 25.4, HEIGHT / 25.4), title='',
                              s=15, label_distance=1.30,
                              text_kwargs={'fontsize': 8.5})
    fig = plt.gcf()
    circle = fig.axes[0]
    circle.set_position(rect(3, 20, 85, 85))
    circle.set_xlim(-1.37, 1.37)
    circle.set_ylim(-1.37, 1.37)
    circle.set_aspect('equal', adjustable='box')
    # Original native edge width=2pt came from a 40-inch source figure. Fit the
    # same edge geometry to the final physical scale while preserving colors.
    for col in circle.collections:
        if not isinstance(col, PathCollection):
            col.set_linewidth(.9)

    scatter = fig.add_axes(rect(104, 59, 70, 51.03))
    scv.pl.scatter(b, x='palantir_pseudotime', y='basal_probability',
                   color='clusters', show=False, ax=scatter, size=44,
                   title='', legend_loc='none', frameon=True)
    scatter.set(xlim=(-.05, 1.05), ylim=(-.04, 1.04),
                xlabel='Pseudotime', ylabel='Basal probability')
    scatter.set_xticks([0, 1]); scatter.set_yticks([0, 1])
    scatter.set_xticklabels(['0', '1']); scatter.set_yticklabels(['0', '1'])
    scatter.axhline(.66, ls='--', color='#333333', lw=1.0)
    for x in [0, 1/3, 2/3, 1]:
        scatter.axvline(x, ls='--', color='#333333', lw=1.0)
    for x, y, label in [(1/6, .96, 'Stage 1'), (.5, .72, 'Stage 2'),
                         (5/6, .72, 'Stage 3')]:
        scatter.text(x, y, label, ha='center', va='center', fontsize=10)

    # Native Scanpy aggregation and nonlinear dot-size scaling on the raw matrix.
    # The ax must be a SubplotSpec because Scanpy creates nested gridspecs.
    gs = fig.add_gridspec(1, 1, left=102/WIDTH, right=177/WIDTH,
                          bottom=10/HEIGHT, top=35/HEIGHT)
    slot = fig.add_subplot(gs[0, 0])
    dp = sc.pl.dotplot(b, var_names=GENES, groupby='stage', use_raw=True,
                      cmap='Reds', ax=slot, return_fig=True, show=False)
    # Manuscript assembly scales native 200-pt-area dots; scale all data and
    # legend dots together while retaining the exact fraction^1.5 encoding.
    dp.style(cmap='Reds', largest_dot=120, dot_max=.8)
    dp.make_figure()
    axes = dp.get_axes()
    dots = axes['mainplot_ax']
    dots.set_position(rect(117, 23, 17.18, 17.18))
    dots.set_aspect('equal', adjustable='box')
    dots.set_ylabel('')
    dots.set_yticklabels(['Stage 1', 'Stage 2', 'Stage 3'])
    for spine in dots.spines.values():
        spine.set_visible(True); spine.set_linewidth(.4)
    axes['size_legend_ax'].set_position(rect(139, 31, 35, 13))
    axes['color_legend_ax'].set_position(rect(141, 11, 30, 3))
    # Matplotlib3.4 colorbar axes deliberately disable set_xticks. Use the
    # native Colorbar object so labels retain their true expression positions.
    colorbar = axes['color_legend_ax'].xaxis.get_major_locator()._colorbar
    colorbar.set_ticks([.5, 1.])
    colorbar.set_ticklabels(['0.5', '1.0'])
    fig.text(2/WIDTH, 110/HEIGHT, 'c', fontsize=12, fontweight='bold')
    fig.text(96/WIDTH, 110/HEIGHT, 'e', fontsize=12, fontweight='bold')
    # Scanpy uses relative named sizes for several legend objects; bind all to the
    # reviewed final physical font sizes, without shrinking any to conceal overlap.
    for text in fig.findobj(Text):
        text.set_fontfamily('Arial')
        if text in circle.texts:
            text.set_fontsize(8.5)
        elif text.get_text() in ['c', 'e']:
            text.set_fontsize(12)
        else:
            text.set_fontsize(10)
    for ax in fig.axes:
        ax.tick_params(width=.4, length=2, pad=2)
    fig.canvas.draw()
    terminal_label_gap = check_terminal_label_rectangles(circle, fig.canvas.get_renderer(), fig.dpi)
    edge_points = np.concatenate([np.asarray(c.get_segments()).reshape(-1, 2)
                                  for c in circle.collections
                                  if not isinstance(c, PathCollection)])
    edge_mm = circle.transData.transform(edge_points) / fig.dpi * 25.4
    circle_body = [*edge_mm.min(0), *(edge_mm.max(0)-edge_mm.min(0))]
    dot_body = np.asarray(dots.get_window_extent().bounds) / fig.dpi * 25.4

    P = full.obsm['to_terminal_states'][FORMAL_ORDER].X
    weights = P / P.mean(0)
    weights /= weights.sum(1)[:, None]
    theta = np.arange(9) * 2 * np.pi / 9
    expected = weights @ np.c_[np.cos(theta), np.sin(theta)]
    actual = full.obsm['X_fate_simplex_fwd']
    np.testing.assert_allclose(actual, expected, rtol=1e-12, atol=1e-12)
    pd.DataFrame(actual, index=full.obs_names, columns=['x', 'y']).to_csv(
        args.output.with_suffix('.coordinates.csv'), index_label='cell_id')
    expected_mean = pd.read_csv(args.inputs / 'stage-dotplot-mean.csv', index_col=0)
    expected_frac = pd.read_csv(args.inputs / 'stage-dotplot-fraction.csv', index_col=0)
    np.testing.assert_array_equal(dp.dot_color_df.loc[expected_mean.index, GENES].values.astype(np.float32),
                                 expected_mean[GENES].values.astype(np.float32))
    np.testing.assert_allclose(dp.dot_size_df.loc[expected_frac.index, GENES],
                               expected_frac[GENES], rtol=1e-10, atol=1e-12)
    assert dp.cmap == 'Reds'
    np.testing.assert_allclose(colorbar.get_ticks(), [.5, 1.], atol=0, rtol=0)
    dot_marks = [c for c in dots.collections if isinstance(c, PathCollection)]
    assert len(dot_marks) == 1 and len(dot_marks[0].get_offsets()) == 9
    expected_colors = plt.get_cmap('Reds')(colorbar.norm(dp.dot_color_df.values.ravel()))
    np.testing.assert_allclose(dot_marks[0].get_facecolors(), expected_colors, atol=1e-12)
    expected_sizes = (dp.dot_size_df.values.ravel() / .8)**1.5 * 120
    np.testing.assert_allclose(dot_marks[0].get_sizes(), expected_sizes, atol=1e-10)
    assert sum(len(c.get_offsets()) for c in circle.collections if isinstance(c, PathCollection)) == 24882
    assert sum(len(c.get_offsets()) for c in scatter.collections if isinstance(c, PathCollection)) == 1239
    xstep = np.linalg.norm(dots.transData.transform([1.5, .5]) -
                           dots.transData.transform([.5, .5])) / fig.dpi * 25.4
    ystep = np.linalg.norm(dots.transData.transform([.5, 1.5]) -
                           dots.transData.transform([.5, .5])) / fig.dpi * 25.4
    assert abs(xstep / ystep - 1) < 1e-8
    texts = summarize_text(fig)
    outside = [t for t in texts if t['bbox_mm'][0] < -.2 or t['bbox_mm'][1] < -.2
               or t['bbox_mm'][0] + t['bbox_mm'][2] > WIDTH + .2
               or t['bbox_mm'][1] + t['bbox_mm'][3] > HEIGHT + .2]
    if outside:
        raise RuntimeError('Text outside final canvas: ' + json.dumps(outside))
    assert min(t['font_pt'] for t in texts) >= 8.5
    # Keep timestamp metadata fixed so independent frozen-input PDF hashes can
    # detect deterministic native drawing. Raster repeatability is checked apart.
    args.output.parent.mkdir(parents=True, exist_ok=True)
    for suffix in ['pdf', 'png', 'svg']:
        options = {'dpi': 300, 'facecolor': 'white', 'transparent': False}
        if suffix == 'pdf':
            options['metadata'] = {'CreationDate': None, 'ModDate': None,
                                   'Creator': 'CellRank native frozen-input replay'}
        if suffix == 'svg':
            options['metadata'] = {'Date': None}
            plt.rcParams['svg.hashsalt'] = 'cellrank-author-fig6-fixed-input'
        fig.savefig(args.output.with_suffix('.' + suffix), **options)
    audit = {'status': 'NATIVE_AUTHOR_RENDERED_REQUIRES_VISUAL_REVIEW',
             'official_cp3': 'NOT_VERIFIED_PYTHON_ADAPTER_UNAVAILABLE',
             'output_mm': [WIDTH, HEIGHT], 'cells': [full.n_obs, b.n_obs],
             'projection_formula_max_error': float(np.abs(actual-expected).max()),
             'formal_ccw_order': FORMAL_ORDER, 'dot_grid_spacing_mm': [xstep, ystep],
             'circle_data_bbox_mm': list(map(float, circle_body)),
             'scatter_data_bbox_mm': [104., 59., 70., 51.03],
             'dot_data_bbox_mm': list(map(float, dot_body)),
             'dot_max': float(dp.dot_max), 'dot_min': float(dp.dot_min),
             'terminal_label_min_projected_gap_mm': terminal_label_gap,
             'largest_dot': dp.largest_dot, 'size_exponent': dp.size_exponent,
             'circular_mark_area_parameter_pt2': 15,
             'circular_edge_width_pt': .9,
             'raw_expression_dtype': str(b.raw.X.dtype),
             'colorbar_limits': [colorbar.norm.vmin, colorbar.norm.vmax],
             'colorbar_ticks': list(map(float, colorbar.get_ticks())),
             'dot_cmap': dp.cmap,
             'text_extents': texts, 'font_file': str(resolved), 'font_sha256': sha(resolved),
             'input_hashes': {f.name: sha(f) for f in sorted(args.inputs.glob('*.csv'))},
             'output_hashes': {s: sha(args.output.with_suffix('.'+s)) for s in ['pdf','png','svg']},
             'runtime_seconds': time.time()-started,
             'adaptations': ['Python random seed repaired upstream, original unseeded state unavailable',
                             'Circular native lineage order fixed to published orientation',
                             'Original PDF effective typography scaled by data-body dimensions: circle8.5pt, other10pt; native marks resized; dot largest area200 to120 with shared legend',
                             'Dot fraction scale fixed at published 0 to80percent; actual data remain unclipped',
                             'Published ROI boxes omitted because corresponding selected region panel is outside scope']}
    args.output.with_suffix('.render-audit.json').write_text(json.dumps(audit, indent=2))
    print(json.dumps({k: audit[k] for k in ['status','cells','projection_formula_max_error',
                                           'dot_grid_spacing_mm','runtime_seconds']}), flush=True)
    plt.close(fig)


if __name__ == '__main__':
    main()
