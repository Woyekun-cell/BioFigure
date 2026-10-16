#!/usr/bin/env python3
"""Audit the portable selected-gallery release, not scientific corpus fidelity.

The full scientific benchmark auditor remains a separate, stricter workflow.
This script checks public files and bindings without opening private evidence.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import struct
import sys
import zlib
from pathlib import Path, PurePosixPath

sys.dont_write_bytecode = True
EXCLUDED_PARTS = {'.git', 'work', 'cache', '__pycache__', '.pytest_cache'}
SHA256_RE = re.compile(r'^[0-9a-f]{64}$')
SEMVER = r'(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)'
PATH_PREFIXES = ('/' + 'Users/', '/' + 'home/', '/var/' + 'folders/')


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def error(errors: list[str], code: str, detail: object) -> None:
    errors.append(f'{code}: {detail}')


def nonempty(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def file_path(root: Path, value: object, code: str, errors: list[str]) -> Path | None:
    """Require a portable relative file, including after symlink resolution."""
    if not nonempty(value):
        error(errors, code, 'missing relative file path')
        return None
    relative = PurePosixPath(value)
    if (relative.is_absolute() or '..' in relative.parts or '\\' in value
            or ':' in value or any(part in EXCLUDED_PARTS for part in relative.parts)):
        error(errors, code, f'nonpublic or unsafe relative path {value!r}')
        return None
    path = root / value
    try:
        path.resolve().relative_to(root.resolve())
        if not path.is_file():
            raise FileNotFoundError
    except (OSError, ValueError):
        error(errors, code, f'missing file or path escape {value!r}')
        return None
    return path


def json_file(root: Path, relative: str, code: str, errors: list[str]) -> dict:
    path = file_path(root, relative, code, errors)
    if path is None:
        return {}
    try:
        data = json.loads(path.read_text(encoding='utf-8'))
        if not isinstance(data, dict):
            raise ValueError('top level must be an object')
        return data
    except (OSError, UnicodeError, ValueError) as exc:
        error(errors, code, f'{relative}: {type(exc).__name__}')
        return {}


def png_dimensions(path: Path) -> list[int]:
    """Verify the PNG signature and IHDR CRC; this is not decoded-pixel QA."""
    with path.open('rb') as stream:
        header = stream.read(33)
    if len(header) != 33 or header[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('invalid PNG signature or truncated IHDR')
    if struct.unpack('>I', header[8:12])[0] != 13 or header[12:16] != b'IHDR':
        raise ValueError('first chunk must be 13-byte IHDR')
    if zlib.crc32(header[12:29]) & 0xffffffff != struct.unpack('>I', header[29:33])[0]:
        raise ValueError('IHDR CRC mismatch')
    width, height, depth, colour, compression, filtering, interlace = struct.unpack('>IIBBBBB', header[16:29])
    allowed_depths = {0: {1, 2, 4, 8, 16}, 2: {8, 16}, 3: {1, 2, 4, 8}, 4: {8, 16}, 6: {8, 16}}
    if not (width and height and depth in allowed_depths.get(colour, set())
            and compression == 0 and filtering == 0 and interlace in {0, 1}):
        raise ValueError('invalid dimensions or IHDR encoding')
    return [width, height]


def list_field(value: object, code: str, detail: str, errors: list[str], *, allow_empty: bool = False) -> list:
    if not isinstance(value, list) or (not value and not allow_empty):
        error(errors, code, f'{detail} must be a {"possibly empty " if allow_empty else "nonempty "}list')
        return []
    return value


def audit_gallery(root: Path, catalog: dict, errors: list[str]) -> tuple[dict, dict]:
    categories = list_field(catalog.get('categories'), 'gallery_categories', 'categories', errors)
    slugs = [item.get('slug') for item in categories if isinstance(item, dict)]
    if len(slugs) != len(categories) or any(not nonempty(slug) for slug in slugs) or len(set(slugs)) != len(slugs):
        error(errors, 'gallery_categories', 'category slugs must be nonempty and unique')
    figures = list_field(catalog.get('figures'), 'gallery_figures', 'figures', errors)
    by_id, images, subtypes, dimensions = {}, set(), set(), {}
    for index, row in enumerate(figures):
        if not isinstance(row, dict):
            error(errors, 'gallery_row', index)
            continue
        gallery_id, image, category, subtype = (row.get(key) for key in ('id', 'image', 'category', 'subtype'))
        if not nonempty(gallery_id) or gallery_id in by_id:
            error(errors, 'gallery_duplicate_id', f'row {index}: {gallery_id!r}')
        else:
            by_id[gallery_id] = row
        if not nonempty(image) or image in images:
            error(errors, 'gallery_duplicate_image', f'row {index}: {image!r}')
        if isinstance(image, str):
            images.add(image)
        if category not in slugs or not nonempty(subtype):
            error(errors, 'gallery_category_subtype', f'row {index}')
        elif (category, subtype) in subtypes:
            error(errors, 'gallery_duplicate_subtype', f'{category}: {subtype}')
        else:
            subtypes.add((category, subtype))
        image_path = file_path(root, image, 'gallery_image_path', errors)
        if image_path is not None:
            expected = row.get('sha256')
            if not isinstance(expected, str) or not SHA256_RE.fullmatch(expected) or sha256(image_path) != expected:
                error(errors, 'gallery_hash_mismatch', gallery_id)
            try:
                dimensions[gallery_id] = png_dimensions(image_path)
                if 'pixels' in row and row['pixels'] != dimensions[gallery_id]:
                    error(errors, 'gallery_png_header', f'{gallery_id}: declared pixels differ from IHDR')
            except (OSError, ValueError) as exc:
                error(errors, 'gallery_png_header', f'{gallery_id}: {exc}')
        scripts = list_field(row.get('scripts'), 'gallery_script', f'{gallery_id} scripts', errors)
        for script in scripts:
            file_path(root, script, 'gallery_script', errors)
    return ({'figure_count': len(figures), 'category_count': len(slugs),
             'png_header_dimensions': dimensions, 'decoded_pixel_hashes_verified': False}, by_id)


def nonempty_csv(path: Path) -> bool:
    with path.open(encoding='utf-8-sig', newline='') as stream:
        delimiter = '\t' if path.suffix.lower() == '.tsv' else ','
        rows = csv.reader(stream, delimiter=delimiter)
        header = next(rows, [])
        return bool(header) and any(any(cell.strip() for cell in row) for row in rows)


def audit_refresh(root: Path, refresh: dict, by_id: dict, errors: list[str]) -> dict:
    if refresh.get('schema_version') != 1 or refresh.get('scope') != 'selected-gallery-release':
        error(errors, 'refresh_manifest', 'expected schema_version=1 and selected-gallery-release scope')
    artifacts = list_field(refresh.get('artifacts'), 'refresh_manifest', 'artifacts', errors)
    artifact_ids, case_ids = set(), set()
    for index, artifact in enumerate(artifacts):
        if not isinstance(artifact, dict):
            error(errors, 'refresh_artifact', index)
            continue
        gallery_id, case_id = artifact.get('gallery_id'), artifact.get('case_id')
        if not nonempty(gallery_id) or gallery_id in artifact_ids:
            error(errors, 'refresh_gallery_id', f'row {index}: missing or duplicate')
        else:
            artifact_ids.add(gallery_id)
        if not nonempty(case_id) or case_id in case_ids:
            error(errors, 'refresh_case_id', f'row {index}: missing or duplicate')
        else:
            case_ids.add(case_id)
        row = by_id.get(gallery_id, {})
        if not row or row.get('image') != artifact.get('image'):
            error(errors, 'refresh_catalog_binding', gallery_id)
        bindings = {}
        for binding in list_field(artifact.get('files'), 'refresh_files', f'{gallery_id} files', errors):
            if not isinstance(binding, dict):
                error(errors, 'refresh_files', gallery_id)
                continue
            relative, expected = binding.get('path'), binding.get('sha256')
            path = file_path(root, relative, 'refresh_file_path', errors)
            if not isinstance(relative, str):
                continue
            if relative in bindings:
                error(errors, 'refresh_duplicate_binding', relative)
            bindings[relative] = expected
            if not isinstance(expected, str) or not SHA256_RE.fullmatch(expected) or (path is not None and sha256(path) != expected):
                error(errors, 'refresh_file_hash', relative)
        references = [artifact.get('image'), artifact.get('pdf')]
        scripts = list_field(artifact.get('scripts'), 'refresh_scripts', f'{gallery_id} scripts', errors)
        plot_data = list_field(artifact.get('plot_data'), 'refresh_plot_data', f'{gallery_id} plot_data', errors)
        references.extend(scripts + plot_data)
        if isinstance(row.get('scripts'), list) and not set(scripts).issubset(row['scripts']):
            error(errors, 'refresh_catalog_scripts', gallery_id)
        provenance = artifact.get('provenance')
        scope = None
        provenance_path = provenance if isinstance(provenance, str) else provenance.get('path') if isinstance(provenance, dict) else None
        if provenance_path is not None:
            references.append(provenance_path)
            document = json_file(root, provenance_path, 'refresh_provenance', errors)
            scope = document.get('scope')
            if isinstance(provenance, dict) and 'scope' in provenance and provenance['scope'] != scope:
                error(errors, 'refresh_provenance_scope', f'{gallery_id}: inline and file scope differ')
        else:
            error(errors, 'refresh_provenance', f'{gallery_id}: requires a hash-bound JSON path')
        if not nonempty(scope):
            error(errors, 'refresh_provenance_scope', gallery_id)
        for relative in references:
            if not isinstance(relative, str) or relative not in bindings:
                error(errors, 'refresh_unbound_reference', f'{gallery_id}: {relative!r}')
            file_path(root, relative, 'refresh_reference_path', errors)
        if artifact.get('image') in bindings and bindings[artifact['image']] != row.get('sha256'):
            error(errors, 'refresh_catalog_hash', gallery_id)
        pdf = file_path(root, artifact.get('pdf'), 'refresh_pdf_path', errors)
        if pdf is not None:
            with pdf.open('rb') as stream:
                if stream.read(5) != b'%PDF-':
                    error(errors, 'refresh_pdf_header', gallery_id)
        for relative in plot_data:
            path = file_path(root, relative, 'refresh_plot_data_path', errors)
            if path is not None:
                try:
                    if not nonempty_csv(path):
                        error(errors, 'refresh_plot_data_empty', relative)
                except (OSError, UnicodeError, csv.Error):
                    error(errors, 'refresh_plot_data_empty', f'{relative}: unreadable CSV/TSV')
    replacements = list_field(refresh.get('replacements'), 'refresh_replacements', 'replacements', errors, allow_empty=True)
    replacement_ids = set()
    for replacement in replacements:
        if not isinstance(replacement, dict):
            error(errors, 'refresh_replacements', 'replacement must be an object')
            continue
        gallery_id = replacement.get('gallery_id')
        if not nonempty(gallery_id) or gallery_id in replacement_ids:
            error(errors, 'replacement_gallery_id', 'missing or duplicate')
        else:
            replacement_ids.add(gallery_id)
        if gallery_id not in artifact_ids or gallery_id not in by_id:
            error(errors, 'replacement_gallery_id', f'{gallery_id}: not in refreshed catalog artifacts')
        previous, current = replacement.get('previous_sha256'), replacement.get('current_sha256')
        archive = file_path(root, replacement.get('archive_path'), 'replacement_archive_path', errors)
        if not isinstance(previous, str) or not SHA256_RE.fullmatch(previous) or (archive is not None and sha256(archive) != previous):
            error(errors, 'replacement_archive_hash', gallery_id)
        if not isinstance(current, str) or not SHA256_RE.fullmatch(current) or current != by_id.get(gallery_id, {}).get('sha256'):
            error(errors, 'replacement_current_hash', gallery_id)
        if not nonempty(replacement.get('git_snapshot_tag')):
            error(errors, 'replacement_snapshot_tag', gallery_id)
    new_count = refresh.get('new_figures')
    if type(new_count) is not int or new_count < 0 or new_count != len(artifact_ids - replacement_ids):
        error(errors, 'refresh_new_figure_count', 'declared count differs from non-replacement artifacts')
    return {'artifact_count': len(artifacts), 'replacement_count': len(replacements),
            'new_figure_count': new_count, 'snapshot_tags_verified': 'record presence only; archive bytes are SHA256-verified'}


def audit_versions(root: Path, errors: list[str]) -> dict:
    patterns = {
        'biofigure/manifest.yaml': r'^version:\s*[\"\']?' + SEMVER,
        'biofigure/SKILL.md': r'BioFigure[ -]+' + SEMVER,
        'README.md': r'BioFigure[ -]+' + SEMVER,
        'docs/HANDBOOK.zh-CN.md': r'BioFigure[ -]+' + SEMVER,
        'docs/HANDBOOK.en.md': r'BioFigure[ -]+' + SEMVER,
    }
    versions = {}
    for relative, pattern in patterns.items():
        path = file_path(root, relative, 'version_file', errors)
        if path is None:
            continue
        content = path.read_text(encoding='utf-8')
        badge_versions = []
        if relative == 'README.md':
            # Shields separates the label, version and colour with hyphens.
            # Remove complete badge URLs before parsing ordinary version text.
            badge = re.compile(r'https?://img\.shields\.io/badge/BioFigure-' + SEMVER + r'-[^/\s?)]+(?:\?[^\s)]+)?')
            badge_versions = badge.findall(content)
            content = badge.sub('', content)
        matches = badge_versions + re.findall(pattern, content, re.MULTILINE)
        if not matches or len(set(matches)) != 1:
            error(errors, 'version_mismatch', f'{relative}: missing or conflicting version')
        else:
            versions[relative] = matches[0]
    if len(versions) != len(patterns) or len(set(versions.values())) != 1:
        error(errors, 'version_mismatch', 'manifest, skill, README and both handbooks must agree')
    return {'values': versions}


def audit_benchmark_ids(root: Path, errors: list[str]) -> dict:
    registry = json_file(root, 'biofigure/benchmark/registry.json', 'registry', errors)
    graph = json_file(root, 'biofigure/atlas/unified-capability-graph.json', 'graph', errors)
    cases = list_field(registry.get('cases'), 'registry_graph_case_ids', 'registry cases', errors)
    nodes = list_field(graph.get('nodes'), 'registry_graph_case_ids', 'graph nodes', errors)
    case_ids = [row.get('case_id') for row in cases if isinstance(row, dict)]
    graph_ids = [row.get('id') for row in nodes if isinstance(row, dict) and row.get('kind') == 'case']
    if (len(case_ids) != len(cases) or any(not nonempty(value) for value in case_ids + graph_ids)
            or len(set(case_ids)) != len(case_ids) or len(set(graph_ids)) != len(graph_ids)
            or set(case_ids) != set(graph_ids)):
        error(errors, 'registry_graph_case_ids', 'registry and graph case IDs must be unique and identical')
    return {'status': 'INCOMPLETE', 'scope': 'V2 scientific benchmark not assessed by public file audit',
            'registry_case_count': len(case_ids), 'graph_case_count': len(graph_ids),
            'private_evidence_opened': False, 'fidelity_upgrade': False}


def audit_public_files(root: Path, errors: list[str]) -> dict:
    scanned = 0
    for path in sorted(root.rglob('*')):
        relative = path.relative_to(root)
        if any(part in EXCLUDED_PARTS for part in relative.parts):
            continue
        if path.name == '.DS_Store' or '__pycache__' in relative.parts or path.suffix.lower() == '.pyc':
            error(errors, 'public_file_hygiene', relative.as_posix())
            continue
        if not path.is_file():
            continue
        try:
            path.resolve().relative_to(root.resolve())
        except ValueError:
            error(errors, 'public_path_escape', relative.as_posix())
            continue
        try:
            raw = path.read_bytes()
            if b'\0' in raw:
                continue
            content = raw.decode('utf-8')
        except UnicodeError:
            continue
        except OSError:
            error(errors, 'public_file_read', relative.as_posix())
            continue
        scanned += 1
        for line_number, line in enumerate(content.splitlines(), 1):
            if any(prefix in line for prefix in PATH_PREFIXES):
                error(errors, 'absolute_path_leak', f'{relative.as_posix()}:{line_number}')
    return {'text_files_scanned': scanned, 'excluded_directory_names': sorted(EXCLUDED_PARTS)}


def audit_public_release(root: Path | str) -> dict:
    root, errors = Path(root).resolve(), []
    catalog = json_file(root, 'docs/gallery/catalog.json', 'gallery_catalog', errors)
    gallery, by_id = audit_gallery(root, catalog, errors)
    # New releases declare a new current inventory. Historical SHA records stay
    # untouched instead of being rewritten to conceal withdrawn rights-limited files.
    marker_path = root / 'docs/gallery/current-release.json'
    current_refresh = 'docs/gallery/refresh-20261011.json'
    if marker_path.is_file():
        marker = json_file(root, 'docs/gallery/current-release.json', 'refresh_manifest', errors)
        if marker.get('schema_version') != 1:
            error(errors, 'refresh_manifest', 'invalid current release marker')
        current_refresh = marker.get('current_refresh_manifest')
    refresh = json_file(root, current_refresh, 'refresh_manifest', errors)
    refreshed = audit_refresh(root, refresh, by_id, errors)
    versions = audit_versions(root, errors)
    benchmark = audit_benchmark_ids(root, errors)
    files = audit_public_files(root, errors)
    return {'schema_version': 1, 'scope': 'selected-gallery-release',
            'status': 'FAIL' if errors else 'PASS', 'whole_corpus_fidelity_certified': False,
            'gallery': gallery, 'refresh': refreshed, 'versions': versions,
            'benchmark': benchmark, 'public_files': files, 'errors': errors}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path, help='Write a JSON report only when explicitly supplied')
    args = parser.parse_args()
    report = audit_public_release(args.root)
    rendered = json.dumps(report, ensure_ascii=False, indent=2) + '\n'
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding='utf-8')
    print(rendered, end='')
    return 0 if report['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
