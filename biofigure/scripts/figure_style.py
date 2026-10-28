"""Authorized Matplotlib Figure export; receipts certify technical preflight only."""
from __future__ import annotations

import hashlib
import json
import math
import os
from pathlib import Path
import re
import sys
import tempfile
import warnings
import xml.etree.ElementTree as ET

import matplotlib as mpl
from matplotlib import cbook, font_manager
from matplotlib.backends.backend_agg import FigureCanvasAgg
from matplotlib.figure import Figure
from matplotlib.ft2font import FT2Font
from matplotlib.legend import Legend
from matplotlib.text import Text
from PIL import Image, __version__ as PILLOW_VERSION
import yaml

ROOT = Path(os.environ.get('BIOFIGURE_SKILL_ROOT', Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(ROOT / 'scripts'))
from authorize_render import consume
from figure_text_policy import (TEXT_POLICY_ID, FOOTER_POLICY_ID, validate_figure_text,
                                validate_footer_contract)
from heatmap_geometry import requires_cell_geometry
from validate_checkpoints import validate_render_receipt


def _bound(path):
    path = Path(path).resolve(strict=True)
    return {'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def bf_font(family='Arial'):
    """Resolve a real publication font; never silently choose a fallback family."""
    if family not in {'Arial', 'Helvetica'}:
        raise ValueError('font must be Arial or Helvetica')
    try:
        path = font_manager.findfont(font_manager.FontProperties(family=family), fallback_to_default=False)
        if FT2Font(path).family_name != family:
            raise ValueError('font fallback detected')
        return {**_bound(path), 'family': family}
    except (OSError, RuntimeError, ValueError) as exc:
        raise ValueError(f'requested font is unavailable or substituted: {family}') from exc


def bf_style(font=None, size=7):
    """Return an rc_context for creating a Figure with verified font and white space."""
    font = bf_font() if font is None else font
    if font.get('family') not in {'Arial', 'Helvetica'} or _bound(font['path'])['sha256'] != font.get('sha256'):
        raise ValueError('font metadata missing or changed')
    if FT2Font(font['path']).family_name != font['family']:
        raise ValueError('font fallback detected')
    if type(size) not in (int, float) or not math.isfinite(size) or size < 5:
        raise ValueError('font size must be finite and at least 5 pt')
    return mpl.rc_context({'font.family': [font['family']], 'font.sans-serif': [font['family']],
        'font.size': size, 'axes.labelsize': size, 'axes.titlesize': size, 'xtick.labelsize': size,
        'ytick.labelsize': size, 'legend.fontsize': size, 'legend.title_fontsize': size,
        'figure.facecolor': 'white', 'axes.facecolor': 'white', 'savefig.facecolor': 'white',
        'savefig.edgecolor': 'white', 'savefig.transparent': False, 'savefig.bbox': None,
        'pdf.fonttype': 42, 'pdf.use14corefonts': False, 'svg.fonttype': 'none', 'text.usetex': False})


def _boxes_check(boxes, width, height, allowed_pairs):
    seen = set()
    for box in boxes:
        if (not isinstance(box, dict) or not isinstance(box.get('id'), str) or not box['id']
                or box['id'] in seen or any(not isinstance(box.get(k), (int, float)) or isinstance(box[k], bool)
                or not math.isfinite(box[k]) for k in ('x', 'y', 'w', 'h'))):
            raise ValueError('layout boxes require unique ids and finite x/y/w/h in mm')
        seen.add(box['id'])
        if (min(box['x'], box['y']) < 0 or min(box['w'], box['h']) <= 0
                or box['x'] + box['w'] > width + 1e-6 or box['y'] + box['h'] > height + 1e-6):
            raise ValueError(f"layout outside canvas: {box['id']}")
    for index, a in enumerate(boxes):
        for b in boxes[index + 1:]:
            key = ':'.join(sorted((a['id'], b['id'])))
            if (min(a['x'] + a['w'], b['x'] + b['w']) > max(a['x'], b['x']) + 1e-6
                    and min(a['y'] + a['h'], b['y'] + b['h']) > max(a['y'], b['y']) + 1e-6
                    and key not in allowed_pairs):
                raise ValueError('layout overlap: ' + key)


def _unsupported_text_check(fig):
    # These paths bypass RendererAgg.draw_text and its measured text audit.
    for text in fig.findobj(Text):
        if not text.get_visible() or not text.get_text().strip():
            continue
        if text.get_path_effects():
            raise ValueError('Text path effects require a separate documented glyph audit')
        if text.get_usetex():
            raise ValueError('math/TeX text requires a separate documented glyph audit')


def _figure_state(fig):
    # Export uses several renderers; callbacks must not change the audited object.
    positioned = set(fig.texts) | {text for ax in fig.axes for text in ax.texts}
    return ([
        (id(text), text.get_text(), text.get_visible(),
         text.get_fontproperties().get_fontconfig_pattern(),
         tuple(text.get_position()) if text in positioned else None,
         text.get_rotation(), text.get_alpha(), text.get_usetex(), text.get_parse_math(),
         tuple(text.get_path_effects()))
        for text in fig.findobj(Text)], tuple(fig.get_size_inches()), fig.get_facecolor(),
        [(tuple(ax.get_position().bounds), ax.get_facecolor(), ax.get_visible()) for ax in fig.axes])


def bf_render(fig, png_path, *, design_spec, authorization, source_files, dpi=300,
              boxes=None, allowed_pairs=()):
    """Export this Figure at its authorized final mm, then write PNG.render.json.

    source_files must match the authorization order and include this helper's
    own file and a separate plot.py. Optional boxes are physical mm slots;
    actual text/axes/legend extents are always checked after an Agg draw.
    """
    png_path = Path(png_path).resolve()
    receipt_path = Path(str(png_path) + '.render.json')
    if authorization is None or not Path(authorization).is_file():
        raise ValueError('current single-use render authorization is required')
    authorization, design_spec = Path(authorization).resolve(), Path(design_spec).resolve()
    sources = [Path(path).resolve() for path in source_files]
    if Path(__file__).resolve() not in sources:
        raise ValueError('authorization sources must bind this figure_style.py helper')
    if not any(path.suffix == '.py' and path != Path(__file__).resolve() for path in sources):
        raise ValueError('authorization sources must bind a separate plot.py source')
    if design_spec in sources or len(set(sources)) != len(sources):
        raise ValueError('source_files must be unique; pass Design Spec separately')
    consume(authorization, design_spec, sources)
    receipt_path.unlink(missing_ok=True)
    source_records = [_bound(path) for path in [*sources, design_spec]]
    design = yaml.safe_load(design_spec.read_text(encoding='utf-8'))
    if (design.get('backend_lock', {}).get('backend') != 'Python'
            or design.get('renderer', {}).get('language') != 'Python'
            or design.get('renderer', {}).get('backend') != 'matplotlib'):
        raise ValueError('Design Spec must lock Python and the matplotlib renderer')
    if requires_cell_geometry(design):
        raise ValueError('Matplotlib rectangular heatmaps require a dedicated measured cell-geometry adapter')
    if not isinstance(fig, Figure):
        raise ValueError('bf_render requires one Matplotlib Figure')
    if png_path.suffix.lower() != '.png':
        raise ValueError('png_path must end in .png')
    if type(dpi) not in (int, float) or not math.isfinite(dpi) or dpi < 72:
        raise ValueError('dpi must be finite and at least 72')
    target = design['output_size']
    width, height = target['width_mm'], target['height_mm']
    if (not math.isclose(fig.get_figwidth() * 25.4, width, abs_tol=.01)
            or not math.isclose(fig.get_figheight() * 25.4, height, abs_tol=.01)):
        raise ValueError('Figure canvas size differs from authorized final physical size')
    formats = target.get('formats', [])
    if (not isinstance(formats, list) or 'png' not in formats or set(formats) - {'png', 'pdf', 'svg'}
            or not set(design['deliverable_contract']['required_formats']).issubset(formats)):
        raise ValueError('Matplotlib export formats must be png/pdf/svg and include required formats')
    contract = design.get('text_contract', {})
    allowed = contract.get('allowed_text')
    if not isinstance(allowed, list) or not all(isinstance(label, str) for label in allowed):
        raise ValueError('authorized Design Spec must declare text_contract.allowed_text strings')
    errors = validate_figure_text(allowed) + validate_footer_contract(contract)
    if errors:
        raise ValueError('; '.join(errors))
    font_contract = design['font_contract']
    font = bf_font(font_contract['family'])
    minimum = font_contract['minimum_final_text_pt']
    size_basis = font_contract.get('text_size_authorization') or font_contract.get('minimum_text_basis')
    if type(minimum) not in (int, float) or not math.isfinite(minimum) or minimum < 5:
        raise ValueError('minimum_final_text_pt must be finite and at least 5 pt')
    if minimum < 6 and not str(size_basis or '').strip():
        raise ValueError('text below 6 pt requires documented font_contract.text_size_authorization')
    if any(tuple(artist.get_facecolor()) != (1., 1., 1., 1.) for artist in [fig, *fig.axes]):
        raise ValueError('figure and panel background must be opaque white')
    boxes = [] if boxes is None else list(boxes)
    _boxes_check(boxes, width, height, set(allowed_pairs))
    old_canvas, old_dpi = fig.canvas, fig.dpi
    temporary_outputs = []
    receipt_temporary = None
    try:
        fig.set_dpi(dpi)
        canvas = FigureCanvasAgg(fig)
        renderer = canvas.get_renderer()
        actual, metrics, files = [], [], {}
        original_draw_text = renderer.draw_text
        titles = [getattr(fig, '_suptitle', None)] + [title for ax in fig.axes
            for title in (ax.title, getattr(ax, '_left_title', None), getattr(ax, '_right_title', None))]

        def audited_draw_text(gc, x, y, text, prop, angle, ismath=False, mtext=None):
            if mtext is None:
                raise ValueError('renderer text without a Text artist cannot be audited')
            if not text.strip():
                return original_draw_text(gc, x, y, text, prop, angle, ismath, mtext=mtext)
            label = mtext.get_text()
            if ismath or mtext.get_usetex() or (mtext.get_parse_math() and cbook.is_math_text(label)):
                raise ValueError('math/TeX text requires a separate documented glyph audit')
            if mtext in titles and not contract.get('allow_headings', False):
                raise ValueError('unrequested title/subtitle/tag')
            if re.search(r'(^|[-_.])(caption|footer|footnote)([-_.]|$)', mtext.get_gid() or '', re.I):
                raise ValueError('canvas caption/footer Text artist is forbidden')
            prohibited = validate_figure_text([label], 'actual rendered text')
            if prohibited:
                raise ValueError('; '.join(prohibited))
            if label not in allowed:
                raise ValueError('unapproved figure text: ' + label)
            path = Path(font_manager.findfont(prop, fallback_to_default=False)).resolve()
            face = FT2Font(str(path))
            if face.family_name != font['family']:
                raise ValueError('text font mismatch or font fallback: ' + label)
            glyphs = face.get_charmap()
            if any(ord(char) not in glyphs for char in label if char not in '\n\r\t'):
                raise ValueError('missing glyph in selected font: ' + label)
            size = mtext.get_fontsize()
            if not math.isfinite(size) or size < minimum:
                raise ValueError('text too small at final physical size: ' + label)
            bbox = mtext.get_window_extent(renderer)
            if (not all(math.isfinite(value) for value in bbox.extents)
                    or bbox.x0 < -.01 or bbox.y0 < -.01
                    or bbox.x1 > fig.bbox.width + .01 or bbox.y1 > fig.bbox.height + .01):
                raise ValueError('text outside canvas: ' + label)
            if mtext not in actual:
                actual.append(mtext)
                files[str(path)] = _bound(path)
                metrics.append({'id': mtext.get_gid() or f'text-{len(metrics)}', 'text': label,
                    'font': {**files[str(path)], 'family': face.family_name}, 'size_pt': size,
                    'x': bbox.x0 * 25.4 / dpi, 'y': bbox.y0 * 25.4 / dpi,
                    'w': bbox.width * 25.4 / dpi, 'h': bbox.height * 25.4 / dpi})
            return original_draw_text(gc, x, y, text, prop, angle, ismath, mtext=mtext)

        renderer.draw_text = audited_draw_text
        with warnings.catch_warnings():
            warnings.simplefilter('error')
            _unsupported_text_check(fig)
            canvas.draw()
            _unsupported_text_check(fig)
        if not metrics:
            raise ValueError('at least one visible Text artist is required for text-size evidence')
        _boxes_check([{key: row[key] for key in ('id', 'x', 'y', 'w', 'h')} for row in metrics],
                     width, height, set(allowed_pairs))
        artist_boxes = []
        for index, ax in enumerate(fig.axes):
            if not ax.get_visible():
                continue
            bbox = ax.get_window_extent(renderer)
            artist_boxes.append({'id': ax.get_gid() or f'axes-{index}', 'x': bbox.x0 * 25.4 / dpi,
                'y': bbox.y0 * 25.4 / dpi, 'w': bbox.width * 25.4 / dpi, 'h': bbox.height * 25.4 / dpi})
        _boxes_check(artist_boxes, width, height, set(allowed_pairs))
        for index, legend in enumerate(fig.findobj(Legend)):
            if not legend.get_visible():
                continue
            bbox = legend.get_window_extent(renderer)
            legend_box = {'id': legend.get_gid() or f'legend-{index}', 'x': bbox.x0 * 25.4 / dpi,
                'y': bbox.y0 * 25.4 / dpi, 'w': bbox.width * 25.4 / dpi, 'h': bbox.height * 25.4 / dpi}
            _boxes_check([*artist_boxes, legend_box], width, height, set(allowed_pairs))
        png_path.parent.mkdir(parents=True, exist_ok=True)
        renderer.draw_text = original_draw_text
        audited_state = _figure_state(fig)
        with mpl.rc_context({'pdf.fonttype': 42, 'pdf.use14corefonts': False, 'svg.fonttype': 'none',
                'savefig.bbox': None, 'text.usetex': False}), warnings.catch_warnings():
            warnings.simplefilter('error')
            for fmt in dict.fromkeys(formats):
                handle = tempfile.NamedTemporaryFile(prefix='.biofigure-', suffix='.' + fmt,
                    dir=png_path.parent, delete=False)
                handle.close()
                temporary = Path(handle.name)
                destination = png_path.with_suffix('.' + fmt)
                temporary_outputs.append((temporary, destination, fmt))
                fig.savefig(temporary, format=fmt, dpi=dpi, facecolor='white', edgecolor='white',
                            transparent=False, bbox_inches=None)
                _unsupported_text_check(fig)
                if _figure_state(fig) != audited_state:
                    raise ValueError('Figure changed between measured preflight and export; render a static Figure')
                if fmt == 'png':
                    with Image.open(temporary) as image:
                        if (abs(image.width - width / 25.4 * dpi) > 1
                                or abs(image.height - height / 25.4 * dpi) > 1):
                            raise ValueError('exported PNG canvas size differs from authorized size')
                elif fmt == 'pdf':
                    data = temporary.read_bytes()
                    if b'/FontFile2' not in data or b'/Subtype /Type3' in data:
                        raise ValueError('PDF must embed TrueType fonts without outlined Type3 text')
                elif not list(ET.parse(temporary).iter('{http://www.w3.org/2000/svg}text')):
                    raise ValueError('SVG must retain editable text')
        if source_records != [_bound(path) for path in [*sources, design_spec]]:
            raise ValueError('source changed during rendering')
        if any(_bound(record['path']) != record for record in files.values()):
            raise ValueError('font changed during rendering')
        exports = []
        for temporary, destination, fmt in temporary_outputs:
            temporary.replace(destination)
            exports.append({**_bound(destination), 'format': fmt})
        auth = json.loads(authorization.read_text(encoding='utf-8'))
        receipt = {'schema_version': 1, 'status': 'PASS', 'backend': 'Python', 'renderer': 'matplotlib',
            'renderer_entrypoint': 'biofigure-matplotlib-v1', 'artifact': _bound(png_path),
            'runtime': {'python': sys.version.split()[0], 'matplotlib': mpl.__version__, 'pillow': PILLOW_VERSION},
            'sources': source_records, 'exports': exports,
            'inspection_binding_policy': 'render-receipt-sha256-v1',
            'authorization_consumption': {'consumed': True, 'authorization_id': auth['authorization_id'],
                'marker': _bound(str(authorization) + '.consumed'), 'authorization_file': _bound(authorization),
                'preparation_receipt': auth['bound']['receipt']},
            'font': font, 'font_files': list(files.values()), 'rendered_text': list(dict.fromkeys(row['text'] for row in metrics)),
            'text_metrics': metrics, 'text_policy_id': TEXT_POLICY_ID, 'footer_policy_id': FOOTER_POLICY_ID,
            'checks': {'font': True, 'text_allowlist': True, 'scientific_text_only': True,
                'footer_free': True, 'layout': True, 'target_size': True, 'cell_geometry': False},
            'target_min_text_pt': min(row['size_pt'] for row in metrics), 'min_text_pt': minimum,
            'text_size_authorization': size_basis, 'target_width_mm': width,
            'target_size': {**{key: target[key] for key in ('width_mm', 'height_mm', 'size_class', 'size_basis')},
                'override_basis': target.get('size_rationale', {}).get('override_basis')},
            'device': {'width_mm': width, 'height_mm': height, 'dpi': dpi},
            'boxes': boxes, 'artist_boxes': artist_boxes, 'heading_authorization': contract.get('allow_headings', False),
            'scope': 'technical preflight only; separate actual inspection and critics required'}
        receipt_temporary = receipt_path.with_suffix(receipt_path.suffix + '.tmp')
        receipt_temporary.write_text(json.dumps(receipt, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
        errors = validate_render_receipt(str(receipt_temporary), png_path, design_spec)
        if errors:
            raise ValueError('render receipt validation failed: ' + '; '.join(errors))
        receipt_temporary.replace(receipt_path)
        return receipt
    finally:
        fig.set_dpi(old_dpi)
        fig.set_canvas(old_canvas)
        for temporary, _, _ in temporary_outputs:
            temporary.unlink(missing_ok=True)
        if receipt_temporary is not None:
            receipt_temporary.unlink(missing_ok=True)
