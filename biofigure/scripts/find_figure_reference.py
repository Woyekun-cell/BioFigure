#!/usr/bin/env python3
"""Find compact source/code cards; full evidence checks happen after selection."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shlex
import sys
import tempfile
from pathlib import Path

from figure_reference_search import build_catalog, rank_catalog
from figure_library_categories import CATEGORY_LABELS

ROOT = Path(__file__).resolve().parents[1]
INDEX = ROOT / 'atlas/learned-method-index.json'
CATALOG = ROOT / 'atlas/figure-reference-catalog.json'
REGISTRY = ROOT / 'atlas/learned-method-validations.json'


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load_catalog(refresh=False, *, index_path=INDEX, catalog_path=CATALOG):
    """Invalidate derived metadata by content, including restored timestamps."""
    index_path, catalog_path = Path(index_path), Path(catalog_path)
    bindings = {
        'source_index_sha256': digest(index_path),
        'generator_sha256': digest(ROOT / 'scripts/figure_reference_search.py'),
        'classifier_sha256': digest(ROOT / 'scripts/figure_library_categories.py'),
        'cli_sha256': digest(__file__),
        'registration_sha256': digest(REGISTRY) if REGISTRY.is_file() else None,
    }
    if not refresh and catalog_path.is_file():
        try:
            catalog = json.loads(catalog_path.read_text(encoding='utf-8'))
            if all(catalog.get(k) == v for k, v in bindings.items()) and isinstance(catalog.get('cards'), list):
                return catalog
        except (ValueError, OSError):
            pass
    data = json.loads(index_path.read_text(encoding='utf-8'))
    catalog = dict(build_catalog(data), **bindings)
    registered = set()
    if REGISTRY.is_file():
        registered = {r['method_id'] for r in json.loads(REGISTRY.read_text())['records']}
    for card in catalog['cards']:
        card['recorded_adapter_registration'] = card['method_id'] in registered
    catalog_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=catalog_path.parent,
                                     prefix=catalog_path.name + '.', delete=False) as stream:
        json.dump(catalog, stream, ensure_ascii=False, separators=(',', ':'))
        stream.write('\n')
        temporary = stream.name
    os.replace(temporary, catalog_path)
    return catalog


def _locations(items, limit):
    result = []
    for item in items[:limit]:
        item = {'path': item} if isinstance(item, str) else dict(item)
        if item.get('path') and not str(item['path']).startswith(('http://', 'https://')):
            path = (ROOT / item['path']).resolve()
            item.update(path=str(path), exists=path.is_file())
        result.append(item)
    return result


def _category(value):
    if value in CATEGORY_LABELS:
        return value
    matches = [key for key, label in CATEGORY_LABELS.items()
               if value == label or value == key.split('_', 1)[-1]]
    if len(matches) == 1:
        return matches[0]
    raise ValueError('unknown or ambiguous figure type: ' + str(value) + '; use --list-types')


def list_types(refresh=False):
    catalog = load_catalog(refresh)
    return {'mode': 'type-directory', 'indexed_records': len(catalog['cards']),
        'types': [{'type': key, 'label': label,
            'primary_count': sum(c['primary_category'] == key for c in catalog['cards']),
            'including_cross_category_count': sum(key in c['categories'] for c in catalog['cards'])}
            for key, label in CATEGORY_LABELS.items()
            if any(key in c['categories'] for c in catalog['cards'])],
        'boundary': 'Categories inferred from recorded figure semantics, not visual verification. Cross-category counts overlap.'}


def find(query, limit=3, case_id=None, refresh=False, category=None):
    if not 1 <= limit <= 5:
        raise ValueError('limit must be between 1 and 5')
    catalog = load_catalog(refresh)
    category = _category(category) if category else None
    search_catalog = dict(catalog, cards=[c for c in catalog['cards'] if category in c['categories']]) if category else catalog
    if category and case_id:
        existing = next((c for c in catalog['cards'] if c['method_id'] == case_id), None)
        if existing is not None and category not in existing['categories']:
            raise ValueError('method ID does not belong to requested type: ' + case_id)
    if category and not query.strip() and not case_id:
        matches = [dict(c, score=None, match_reasons=['type_directory_browse'])
                   for c in sorted(search_catalog['cards'], key=lambda c: c['method_id'])[:limit]]
    else:
        matches = rank_catalog(search_catalog, query, limit, case_id)
    results = []
    for card in matches:
        item = {k: card.get(k) for k in ('method_id', 'title', 'contract_name', 'collection', 'type_tags',
            'domain', 'score', 'match_reasons', 'recorded_adapter_registration', 'display_name',
            'primary_category', 'categories', 'classification_status', 'classification_basis',
            'archive_status', 'archive_note')}
        warnings = card.get('warnings', [])
        urgent = [w for w in warnings if any(x in w for x in ('conflict', 'mismatch', 'ownership'))]
        item['warnings'] = list(dict.fromkeys(urgent + warnings))[:5]
        item['warnings_count'] = len(warnings)
        item['validation_status'] = 'NOT_VERIFIED'
        item['input_compatibility'] = 'NOT_ASSESSED'
        item['source_record'] = str((ROOT / card['source_record']).resolve())
        max_files = 5 if case_id else 2
        for key in ('source_images', 'code_files'):
            paths = card.get(key, [])
            item[key] = _locations(paths, max_files)
            item[key + '_count'] = len(paths)
        item['file_preview_only'] = True
        item['read_command'] = 'python3 ' + shlex.quote(str(ROOT / 'scripts/retrieve_learned_methods.py')) + \
            ' --case-id ' + shlex.quote(card['method_id'])
        results.append(item)
    return {'schema_version': 1, 'mode': 'discovery-only', 'query': query,
        'indexed_records': len(catalog['cards']), 'searched_records': len(search_catalog['cards']),
        'type_filter': category, 'results': results,
        'evidence_gap': not bool(results),
        'boundary': 'Metadata ranking only. Source-page images may be tutorial composites or reproductions; inspect provenance and code pairing. File previews are incomplete; select an ID to read the full contract, then run fresh prepare/CP2. Registration is historical, not current PASS.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--query', default='')
    parser.add_argument('--case-id')
    parser.add_argument('--limit', type=int, default=3)
    parser.add_argument('--refresh', action='store_true')
    parser.add_argument('--type', dest='category', help='Chinese category label or numbered key from --list-types')
    parser.add_argument('--list-types', action='store_true')
    args = parser.parse_args()
    try:
        if args.list_types:
            if args.query or args.case_id or args.category:
                raise ValueError('--list-types cannot be combined with --query, --case-id or --type')
            result = list_types(args.refresh)
        else:
            result = find(args.query, args.limit, args.case_id, args.refresh, args.category)
    except (ValueError, OSError) as exc:
        print(str(exc), file=sys.stderr)
        return 2
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if args.list_types or result['results'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
