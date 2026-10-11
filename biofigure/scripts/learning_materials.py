"""Resolve recorded learning materials without changing original source records."""
from __future__ import annotations
import hashlib
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILE_KEYS = {'path', 'file', 'script', 'script_path', 'local_source', 'local_asset',
             'asset', 'artifact', 'artifact_path', 'renderer', 'renderer_path',
             'source_image', 'source_path', 'reproduction_png', 'comparison_png', 'reproduction_evidence'}
SUFFIXES = {'.r', '.rmd', '.rdata', '.py', '.png', '.jpg', '.jpeg', '.pdf', '.json', '.yaml', '.yml',
            '.txt', '.csv', '.tsv', '.md', '.xml', '.rds', '.h5ad', '.nwk', '.newick',
            '.webp', '.svg', '.avif', '.ipynb', '.sh', ''}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def portable(value):
    if isinstance(value, dict):
        return {k: portable(v) for k, v in value.items()}
    if isinstance(value, list):
        return [portable(v) for v in value]
    if isinstance(value, str):
        for base in (ROOT, ROOT.parent, ROOT.parent.parent):
            value = value.replace(str(base) + '/', os.path.relpath(base, ROOT).rstrip('/') + '/')
    return value


def recorded_files(value, key=''):
    if isinstance(value, dict):
        for name, item in value.items():
            if name in FILE_KEYS and isinstance(item, str):
                yield item.split('#', 1)[0], value.get('sha256') or value.get('artifact_sha256')
            else:
                yield from recorded_files(item, name)
    elif isinstance(value, list):
        for item in value:
            if key == 'renderer_candidates' and isinstance(item, str):
                yield '../' + item, None
            else:
                yield from recorded_files(item, key)


def bind_materials(detail, roots=()):
    roots = tuple(dict.fromkeys((ROOT, ROOT.parent, *roots)))
    bound, unresolved, changed = {}, [], []
    for raw, expected in recorded_files(detail):
        if raw.startswith(('http:', 'https:', 'app:', 'doi:')) or Path(raw).suffix.lower() not in SUFFIXES:
            continue
        path = Path(raw)
        candidates = [path] if path.is_absolute() else [root / path for root in roots]
        # Migrated artifacts retain their identity, not their old directory name.
        if expected and path.suffix.lower() in {'.png', '.jpg', '.jpeg', '.webp'}:
            candidates += [ROOT / 'benchmark/library/scidraw' / folder / path.name
                           for folder in ('figures', 'sources', 'evidence/comparison')]
            candidates += [ROOT / 'benchmark/library/topjournal/figures' / path.name]
        existing = list(dict.fromkeys(p.resolve() for p in candidates if p.is_file()))
        matches = [p for p in existing if not expected or digest(p) == expected]
        if not matches:
            (changed if existing else unresolved).append({'recorded_path': portable(raw), 'expected_sha256': expected})
            continue
        # Prefer the declared contextual path; no heuristic basename matching.
        selected = matches[0]
        relative = os.path.relpath(selected, ROOT)
        bound[relative] = {'path': relative, 'sha256': digest(selected), 'recorded_path': portable(raw),
                           'recorded_hash_verified': bool(expected)}
    return {'bound': list(bound.values()), 'unresolved': unresolved, 'hash_mismatches': changed}
