#!/usr/bin/env python3
"""Create a Chinese type view using renamed relative links to preserved sources."""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import os
import tempfile
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VIEW = ROOT / 'library/按图型检索'
TOOL = 'biofigure-type-library-v1'
MANIFEST = '01_链接清单.json'
TABLE = '00_分类总索引.tsv'


def _component(value):
    value = str(value)
    if not value or value in {'.', '..'} or '/' in value or '\\' in value or '\x00' in value:
        raise ValueError('unsafe library name: ' + value)
    if len(value.encode('utf-8')) > 200:
        raise ValueError('unsafe library name length: ' + value)
    return value


def _safe_alias(value):
    if not isinstance(value, str) or '\\' in value or '\x00' in value:
        raise ValueError('unsafe alias: ' + str(value))
    path = Path(value)
    if path.is_absolute() or not path.parts or any(x in {'.', '..'} for x in path.parts):
        raise ValueError('unsafe alias: ' + str(value))
    return path


def _digest(path, cache):
    path = path.resolve()
    if path not in cache:
        cache[path] = hashlib.sha256(path.read_bytes()).hexdigest()
    return cache[path]


def plan_library(catalog, view_root=VIEW, *, skill_root=ROOT):
    """Check all source bytes and names before writing a single library entry."""
    view_root, skill_root = Path(view_root).absolute(), Path(skill_root).resolve()
    links, cases, ids, aliases, hashes = [], [], set(), set(), {}
    for card in catalog['cards']:
        method_id = card['method_id']
        if method_id in ids:
            raise ValueError('duplicate method ID: ' + method_id)
        ids.add(method_id)
        name = _component(card['display_name'])
        categories = list(dict.fromkeys(_component(x) for x in card['categories']))
        if card['primary_category'] not in categories:
            raise ValueError('primary category missing: ' + method_id)
        row = {k: card.get(k) for k in ('method_id', 'title', 'display_name', 'primary_category',
            'classification_status', 'classification_basis', 'source_record', 'archive_status', 'archive_note')}
        row.update(categories=categories, warnings=card.get('warnings', []),
                   validation_status='NOT_VERIFIED', input_compatibility='NOT_ASSESSED',
                   source_images=card.get('source_images', []), code_files=card.get('code_files', []))
        record = card.get('source_record')
        if record:
            record_path = (skill_root / record).resolve()
            if not record_path.is_file():
                raise ValueError('missing source record: ' + str(record_path))
            row['source_record_sha256'] = _digest(record_path, hashes)
        for role, field, folder, label in (
                ('image', 'source_images', '来源图', '来源页候选'),
                ('code', 'code_files', '对应代码', '代码')):
            for number, asset in enumerate(card.get(field, []), 1):
                source = (skill_root / asset['path']).resolve()
                if not source.is_file():
                    raise ValueError('missing source asset: ' + str(source))
                if source.is_relative_to(view_root.resolve()):
                    raise ValueError('source asset inside generated view: ' + str(source))
                current_hash = _digest(source, hashes)
                if asset.get('sha256') and current_hash != asset['sha256']:
                    raise ValueError('source hash mismatch: ' + str(source))
                locator = ''
                if role == 'code' and asset.get('start') is not None:
                    start, end = asset['start'], asset.get('end', '')
                    locator = '_行' + str(start) + '-' + str(end)
                elif role == 'code' and asset.get('cell') is not None:
                    locator = '_单元' + str(asset['cell'])
                filename = _component(name + '_' + label + f'{number:02d}' + locator + source.suffix)
                for category in categories:
                    alias = Path(category) / folder / name / filename
                    if str(alias) in aliases:
                        raise ValueError('duplicate library alias: ' + str(alias))
                    aliases.add(str(alias))
                    item = dict(asset, method_id=method_id, category=category, role=role, managed=True,
                        alias=str(alias), original_path=asset['path'],
                        target=os.path.relpath(source, view_root / alias.parent), current_sha256=current_hash)
                    links.append(item)
        cases.append(row)
    counts = Counter(x['primary_category'] for x in cases)
    cross_counts = Counter(category for x in cases for category in x['categories'])
    return {'schema_version': 1, 'generator': TOOL, 'case_count': len(cases),
        'link_count': len(links), 'primary_counts': dict(sorted(counts.items())),
        'cross_category_counts': dict(sorted(cross_counts.items())), 'cases': cases, 'links': links,
        'boundary': 'Renamed relative links for browsing. Execute code at original_path. Metadata categories, source candidates and code bindings are not visual validation or confirmed figure-code pairing.'}


def _check_parents(path):
    for parent in (path, *path.parents):
        if parent.is_symlink():
            raise ValueError('symlink directory conflict: ' + str(parent))
        if parent.exists() and not parent.is_dir():
            raise ValueError('directory conflict: ' + str(parent))


def _atomic_write(path, content):
    with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=path.parent,
                                    prefix=path.name + '.', delete=False, newline='') as stream:
        stream.write(content)
        temporary = stream.name
    os.replace(temporary, path)


def _index_content(plan):
    fields = ['method_id', 'display_name', 'primary_category', 'categories', 'title',
              'classification_status', 'classification_basis', 'source_record', 'source_record_sha256',
              'archive_status', 'archive_note', 'source_images', 'code_files', 'warnings',
              'validation_status', 'input_compatibility']
    stream = io.StringIO(newline='')
    writer = csv.DictWriter(stream, fieldnames=fields, delimiter='\t', lineterminator='\n', extrasaction='ignore')
    writer.writeheader()
    for row in plan['cases']:
        writer.writerow({k: json.dumps(v, ensure_ascii=False, separators=(',', ':'))
                         if isinstance(v, (list, dict)) else v for k, v in row.items()})
    return stream.getvalue()


def organize(catalog, view_root=VIEW, *, skill_root=ROOT):
    view_root = Path(view_root).absolute()
    plan = plan_library(catalog, view_root, skill_root=skill_root)
    _check_parents(view_root)
    previous = None
    manifest_path = view_root / MANIFEST
    if manifest_path.is_symlink() or (manifest_path.exists() and not manifest_path.is_file()):
        raise ValueError('manifest conflict: ' + str(manifest_path))
    if manifest_path.is_file():
        previous = json.loads(manifest_path.read_text(encoding='utf-8'))
        if not isinstance(previous, dict) or previous.get('generator') != TOOL:
            raise ValueError('unowned manifest conflict: ' + str(manifest_path))
    # Validate every previous entry before mutation or taking ownership.
    owned = {}
    if previous is not None and not isinstance(previous.get('links'), list):
        raise ValueError('invalid previous manifest links')
    for old in (previous or {}).get('links', []):
        if not isinstance(old, dict):
            raise ValueError('invalid previous manifest link')
        _safe_alias(old.get('alias'))
        if not isinstance(old.get('target'), str) or '\x00' in old['target']:
            raise ValueError('invalid previous manifest target')
        if old['alias'] in owned:
            raise ValueError('duplicate previous manifest alias: ' + old['alias'])
        if old.get('managed') is True:
            owned[old['alias']] = old['target']
    old_directories = (previous or {}).get('managed_directories', [])
    if not isinstance(old_directories, list):
        raise ValueError('invalid previous directory list')
    for directory in old_directories:
        _safe_alias(directory)
    old_directories = set(old_directories)
    table_path = view_root / TABLE
    if table_path.is_symlink() or (table_path.exists() and (not table_path.is_file() or previous is None)):
        raise ValueError('index conflict: ' + str(table_path))
    if table_path.is_file() and hashlib.sha256(table_path.read_bytes()).hexdigest() != previous.get('table_sha256'):
        raise ValueError('modified or unowned index conflict: ' + str(table_path))
    table_content = _index_content(plan)
    plan['table_sha256'] = hashlib.sha256(table_content.encode('utf-8')).hexdigest()
    required_directories = set()
    for category in plan['cross_category_counts']:
        for folder in ('来源图', '对应代码'):
            required_directories.update((category, str(Path(category) / folder)))
            _check_parents(view_root / category / folder)
    # Preflight all destinations; refuse foreign entries without partial mutation.
    for item in plan['links']:
        path = view_root / _safe_alias(item['alias'])
        _check_parents(path.parent)
        required_directories.update(str(p) for p in Path(item['alias']).parents if str(p) != '.')
        if path.is_symlink():
            if os.readlink(path) != item['target']:
                raise ValueError('link conflict: ' + str(path))
            if owned.get(item['alias']) != item['target']:
                raise ValueError('unowned link conflict: ' + str(path))
        elif path.exists():
            raise ValueError('file conflict: ' + str(path))
    plan['managed_directories'] = sorted((old_directories & required_directories) |
        {p for p in required_directories if not (view_root / p).exists()})
    manifest_content = json.dumps(plan, ensure_ascii=False, indent=2) + '\n'
    removed, retained, stale = [], [], []
    current = {x['alias'] for x in plan['links']}
    for old in (previous or {}).get('links', []):
        if old['alias'] in current:
            continue
        path = view_root / _safe_alias(old['alias'])
        try:
            _check_parents(path.parent)
        except ValueError:
            retained.append(old['alias'])
            continue
        if old.get('managed') is True and path.is_symlink() and os.readlink(path) == old['target']:
            stale.append((path, old['alias']))
        elif path.exists() or path.is_symlink():
            retained.append(old['alias'])
    created = 0
    view_root.mkdir(parents=True, exist_ok=True)
    for category in plan['cross_category_counts']:
        for folder in ('来源图', '对应代码'):
            (view_root / category / folder).mkdir(parents=True, exist_ok=True)
    for item in plan['links']:
        path = view_root / item['alias']
        path.parent.mkdir(parents=True, exist_ok=True)
        if not path.is_symlink():
            path.symlink_to(item['target'])
            created += 1
    for path, alias in stale:
        path.unlink()
        removed.append(alias)
    removed_directories = []
    for directory in sorted(old_directories - required_directories,
                            key=lambda p: (-len(Path(p).parts), p)):
        path = view_root / directory
        try:
            _check_parents(path)
            path.rmdir()  # Removes only empty, explicitly tool-created directories.
            removed_directories.append(directory)
        except (ValueError, OSError):
            pass
    _atomic_write(table_path, table_content)
    _atomic_write(manifest_path, manifest_content)
    return {'case_count': plan['case_count'], 'link_count': plan['link_count'],
        'primary_counts': plan['primary_counts'], 'created_links': created,
        'removed_empty_owned_directories': removed_directories,
        'removed_stale_links': removed, 'retained_stale_paths': retained, 'view_root': str(view_root)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=VIEW)
    parser.add_argument('--refresh', action='store_true')
    args = parser.parse_args()
    from find_figure_reference import load_catalog
    try:
        result = organize(load_catalog(args.refresh), args.output)
    except (ValueError, OSError) as exc:
        parser.exit(2, str(exc) + '\n')
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
