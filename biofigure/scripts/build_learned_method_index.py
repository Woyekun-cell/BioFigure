#!/usr/bin/env python3
"""Compile every persisted learning source; never promote static study to mastery."""
from __future__ import annotations
import argparse
import hashlib
import json
import re
import yaml
import os
import copy
from pathlib import Path
from learning_materials import bind_materials, portable

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parent


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def overlay_public_profiles(index, *, root=ROOT):
    """Bind the public replay separately from retained author-source history.

    Rebinding these current packaged bytes does not award original-figure,
    new-input, stress or visual qualification. The archival dependency set stays
    queryable and is never replaced by a fabricated historical PASS.
    """
    root = Path(root)
    result = copy.deepcopy(index)
    by_id = {entry['method_id']: entry for entry in result['entries']}
    for path in sorted((root / 'examples').glob('**/data/metadata/public-replay.json')):
        profile = json.loads(path.read_text())
        entry = by_id.get(profile.get('method_id'))
        if not entry:
            continue
        case = path.parents[2]
        entry.setdefault('archival_source_dependencies', {
            'mandatory_read_set': entry.get('mandatory_read_set', []),
            'material_binding': entry.get('material_binding', {}),
            'scope': 'Historical author-source study; absent source assets are not public runtime dependencies.'})
        if profile.get('status') in {'reference-only', 'blocked'}:
            entry['public_execution_profile'] = profile
            entry['learned_contract']['public_execution_profile'] = profile
            entry['mandatory_read_set'] = entry['archival_source_dependencies']['mandatory_read_set']
            entry['material_binding'] = entry['archival_source_dependencies']['material_binding']
            source = root / entry['source_record']
            if source.is_file():
                entry['source_sha256'] = sha(source)
                result.setdefault('sources', {})[entry['source_record']] = sha(source)
            entry['claim_boundary'] = profile['unavailable_reason']
            continue
        references = [rel for rel in entry.get('mandatory_read_set', []) if rel.startswith('references/')]
        material = sorted(p.relative_to(root).as_posix() for p in case.rglob('*')
                          if p.is_file() and '__pycache__' not in p.parts and p.name != '.DS_Store')
        source_asset = profile.get('source_asset')
        if source_asset:
            material.append(source_asset)
        shared = case.parent / 'replay_public.py'
        if shared.is_file():
            material.append(shared.relative_to(root).as_posix())
        material = list(dict.fromkeys(material))
        entry['mandatory_read_set'] = list(dict.fromkeys([entry['source_record'], *references, *material]))
        source = root / entry['source_record']
        if source.is_file():
            entry['source_sha256'] = sha(source)
            result.setdefault('sources', {})[entry['source_record']] = sha(source)
        bound = [{'path': rel, 'sha256': sha(root / rel), 'recorded_path': rel,
                  'recorded_hash_verified': True} for rel in material if (root / rel).is_file()]
        entry['material_binding'] = {'bound': bound,
            'unresolved': [{'recorded_path': rel, 'expected_sha256': None} for rel in material if not (root / rel).is_file()],
            'hash_mismatches': []}
        entry['public_execution_profile'] = profile
        entry['learned_contract']['public_execution_profile'] = profile
        entry['claim_boundary'] = ('Bundled current-table own-layout replay only. Historical author-source records retained; '
                                   'original full-figure fidelity, arbitrary-input transfer, stress and current visual review are not inferred.')
    return result


def build():
    entries = []
    sources = {}
    def add(path, method_id, collection, title, detail, parent=None, references=(), material_roots=()):
        sources[str(path.relative_to(ROOT))] = sha(path)
        context = path.parents[2] if 'library' in path.parts and 'metadata' in path.parts else ROOT
        binding = bind_materials(detail, (context, context / 'sources', context / 'sources/author-code', *material_roots))
        read_set = list(dict.fromkeys([str(path.relative_to(ROOT)), *references,
                                     'references/all-learning-audit-defects.md', *[r['path'] for r in binding['bound']]]))
        entries.append({'method_id': method_id, 'collection': collection, 'parent_case': parent,
                        'title': title, 'source_record': str(path.relative_to(ROOT)),
                        'source_sha256': sha(path), 'mandatory_read_set': read_set,
                        'search_text': ' '.join((method_id, title, collection, str(parent or ''), json.dumps(portable(detail), ensure_ascii=False))),
                        'learned_contract': portable(detail), 'material_binding': binding,
                        'transfer_status': 'NOT_VERIFIED', 'stress_status': 'NOT_VERIFIED',
                        'claim_boundary': 'Source/code/visual study is reusable guidance; new-input rendering and final-size review are required.'})
    scidraw = ROOT / 'atlas/scidraw-derived-corpus.json'
    from retrieve_scidraw import learned_records, bound_pngs
    scidraw_data = json.loads(scidraw.read_text())
    scidraw_resources = learned_records(scidraw_data)
    archive_root = PROJECT.parent / 'Project_003_SciDraw代码分类抓取器/output/SciDraw代码分类包/按图表类型'
    archive_by_case = {}
    for metadata in sorted(archive_root.rglob('metadata.json')):
        record = json.loads(metadata.read_text())
        key = (record.get('图表类型'), record.get('图表命名'), record.get('原文URL'))
        if key in archive_by_case:
            raise ValueError('ambiguous original archive binding: ' + str(key))
        archive_by_case[key] = (metadata, record)
    visuals = {v['visual_id']: v for v in scidraw_data['visuals']}
    learning = {}
    for path in sorted((ROOT / 'atlas').glob('scidraw-learning-ten*.json')):
        sources[str(path.relative_to(ROOT))] = sha(path)
        for case in json.loads(path.read_text())['cases']:
            learning.setdefault(case['case_id'], []).append({'record': str(path.relative_to(ROOT)), 'evidence': case})
    for case in scidraw_data['cases']:
        detail = dict(case, accumulated_implementation_evidence=learning.get(case['case_id'], []),
                      all_method_records=scidraw_resources.get(case['case_id'], []))
        reviewed_material = []
        for method in detail['all_method_records']:
            for image in bound_pngs(method):
                for name, hash_key in (('source_image_path', 'source_image_sha256'), ('comparison_path', 'comparison_sha256')):
                    if image.get(name):
                        reviewed_material.append({'path': os.path.relpath(image[name], ROOT), 'sha256': image[hash_key]})
        detail['source_compared_materials'] = reviewed_material
        metadata, record = archive_by_case.get((case['category'], case['title'], case['source_url']), (None, {}))
        paths = [metadata.parent / p for p in record.get('代码文件', [])] if metadata else []
        detail['source_code_files'] = [{'path': os.path.relpath(p, ROOT), 'sha256': sha(p)} for p in paths if p.is_file()]
        detail['source_code_gap'] = case['code_analysis'].get('file_count', 0) - len(detail['source_code_files'])
        detail['external_visual_sources'] = [visuals[v] for v in case['visual_match']['visual_ids'] if v in visuals]
        if metadata:
            detail['original_archive_metadata'] = {'path': os.path.relpath(metadata, ROOT), 'sha256': sha(metadata)}
        reference = PROJECT / 'data/reference/scidraw' / (case['case_id'] + '.png')
        detail['source_reference_images'] = ([{'path': os.path.relpath(reference, ROOT), 'sha256': sha(reference),
                                               'pairing_status': 'stored-case-reference; inspect against current scientific task'}]
                                             if reference.is_file() else [])
        add(scidraw, case['case_id'], 'scidraw', case['title'], detail,
            references=('references/scidraw-benchmark-index.md', 'references/scidraw-learning.md'))
    top = ROOT / 'benchmark/library/topjournal/metadata/case_method_catalog.json'
    methods = json.loads((ROOT / 'atlas/reproduction-methods.json').read_text())['cases']
    by_issue = {c['issue']: c for c in methods}
    candidates = json.loads((ROOT / 'library/topjournal-corpus/results/plot_data/biofigure_candidates.json').read_text())
    source_by_issue = {c['issue']: c for c in candidates}
    for case in json.loads(top.read_text())['cases']:
        issue = case['issue']
        # Historical training numbers differ from article issue numbers. Do not
        # guess a one-page mapping from the numeric interval.
        refs = tuple('references/method-family-' + tag + '.md' for tag in ('001-020', '021-043', '044-053', '054-063', '064-080')) if issue <= 80 else ('references/topjournal-081-100-learning.md',)
        detail = dict(case, source_image_files=source_by_issue.get(issue, {}).get('image_files', []),
                      historical_method_record=by_issue.get(issue, {}),
                      state_conflict_policy='preserve every record; do not inherit old PASS as transfer ability')
        add(top, f'REPRO-{issue:03d}', 'topjournal', case['title'], detail, references=(*refs, 'references/reproduction-learning.md'),
            material_roots=(ROOT / 'library/topjournal-corpus', ROOT / f'benchmark/library/topjournal/issue_{issue:03d}'))
    sources['atlas/reproduction-methods.json'] = sha(ROOT / 'atlas/reproduction-methods.json')
    # Manifest-level records remain available even when no per-panel recipe exists.
    for path in sorted((ROOT / 'library').glob('*/*/data/metadata/source-manifest.json')):
        case_root = path.parents[2]
        data = json.loads(path.read_text())
        slug = case_root.name
        case_id = str(data.get('case_id') or data.get('case') or slug)
        ref = 'references/' + slug + ('-single-cell-learning.md' if 'single-cell' in path.parts else '-learning.md')
        if not (ROOT / ref).exists():
            ref = 'references/benchmark-learning-index.md'
        title = data.get('title') or data.get('study') or data.get('article', {}).get('doi') or slug
        add(path, 'PAPER-' + slug, path.parts[-5], str(title), data, references=(ref,))
        for number, recipe in enumerate(data.get('plot_recipes', []), 1):
            recipe = dict(recipe, parent_source_assets=data.get('source_assets', data.get('files', [])))
            recipe_id = recipe.get('id') or recipe.get('recipe_id') or 'PAPER-' + slug + f'-RECIPE-{number:02d}'
            add(path, recipe_id, path.parts[-5], str(recipe.get('question') or recipe.get('published_reference') or recipe_id), recipe,
                parent=case_id, references=(ref,))
    path = ROOT / 'library/nature-genomics-multiomics/data/metadata/cases.json'
    for case in json.loads(path.read_text())['cases']:
        add(path, case['case_id'], 'nature-genomics-multiomics', case['project'], case,
            references=('references/nature-genomics-multiomics-learning.md',))
        for n, figure in enumerate(case.get('figures', []), 1):
            figure = dict(figure, code_bindings=[case['code_bindings'][i] for i in figure.get('code_binding_indices', [])])
            add(path, case['case_id'] + f'-FIG-{n:02d}', 'nature-genomics-multiomics', case['project'] + ' ' + figure['figure_locator'], figure,
                parent=case['case_id'], references=('references/nature-genomics-multiomics-learning.md',))
    path = ROOT / 'library/pangenome/tomato-superpangenome/data/metadata/paradigms.json'
    for recipe in json.loads(path.read_text())['paradigms']:
        detail = dict(recipe, source_figures=[{'path': 'evidence/Fig' + str(i) + '.png'} for i in range(1, 5)])
        add(path, recipe['id'], 'pangenome', 'tomato pangenome ' + recipe['question'], detail, parent='TOMATO-SPG-2023',
            references=('references/pangenome-learning.md', 'library/pangenome/tomato-superpangenome/data/metadata/source-audit.json',
                        'library/pangenome/tomato-superpangenome/data/metadata/pipeline-interfaces.json'),
            material_roots=(ROOT / 'library/pangenome/tomato-superpangenome/sources/author-code',))
    for name in ('main-panel-contracts.json', 'supplement-panel-contracts.json'):
        path = ROOT / 'library/freeze-tolerance/msad040/data/metadata' / name
        data = json.loads(path.read_text())
        sequence = data if isinstance(data, list) else data.get('figures', data.get('panels', data.get('contracts', [])))
        if isinstance(sequence, dict):
            sequence = [dict(value, id=key) for key, value in sequence.items()]
        for i, recipe in enumerate(sequence, 1):
            locator = str(recipe.get('id') or (str(recipe.get('figure', '')) + str(recipe.get('panel', ''))) or i)
            add(path, 'MBE-' + name.split('-')[0].upper() + '-' + locator, 'freeze-tolerance', 'msad040 ' + locator,
                recipe, parent='msad040', references=('references/msad040-visualization-learning.md',))
    path = ROOT / 'atlas/awesome-scientific-figure-visual-study.json'
    for figure in json.loads(path.read_text())['entries']:
        url = figure['source_image_url']
        relative = url.split('/figures/', 1)[-1] if '/figures/' in url else None
        image = PROJECT / 'work/2026-09-23-asf-study/source/figures' / relative if relative else PROJECT / 'work/2026-09-23-asf-study/external-Fig3.png'
        figure = dict(figure, local_reference_image={'path': os.path.relpath(image, ROOT), 'sha256': figure['source_image_sha256']})
        add(path, figure['id'], 'awesome-visual', figure['catalog_heading'] + ' ' + figure['figure_locator'], figure,
            references=('references/awesome-scientific-figure-learning.md',))
    path = ROOT / 'atlas/awesome-scientific-figure-layout-recipes.json'
    for recipe in json.loads(path.read_text())['recipes']:
        figures = json.loads((ROOT / 'atlas/awesome-scientific-figure-visual-study.json').read_text())['entries']
        source_images = []
        for figure in figures:
            if figure['id'] in recipe['source_figure_ids']:
                relative = figure['source_image_url'].split('/figures/', 1)[-1] if '/figures/' in figure['source_image_url'] else None
                image = PROJECT / 'work/2026-09-23-asf-study/source/figures' / relative if relative else PROJECT / 'work/2026-09-23-asf-study/external-Fig3.png'
                source_images.append({'path': os.path.relpath(image, ROOT), 'sha256': figure['source_image_sha256']})
        recipe = dict(recipe, local_reference_images=source_images)
        add(path, 'ASF-RECIPE-' + recipe['id'], 'awesome-layout', recipe['id'], recipe,
            references=('references/awesome-scientific-figure-learning.md',))
    # Benchmark case records preserve the six-project and source-exposed additions.
    registry = json.loads((ROOT / 'benchmark/registry.json').read_text())['cases']
    for path in sorted((ROOT / 'benchmark/cases').glob('*.json')):
        data = json.loads(path.read_text())
        case_id = data.get('case_id')
        if case_id:
            roots = tuple((ROOT / r['bundles']['reproduction']).parent for r in registry
                          if r.get('method_id', r['case_id']) == case_id and r.get('bundles', {}).get('reproduction'))
            add(path, 'BENCH-' + path.stem, 'source-benchmark', data.get('label') or data.get('title') or case_id, data,
                references=('references/benchmark-case-method.md',), material_roots=roots)
    for record in registry:
        relative = record.get('bundles', {}).get('reproduction')
        if not relative:
            continue
        path = ROOT / relative
        bundle = json.loads(path.read_text())
        add(path, 'EVIDENCE-' + record['case_id'], 'accepted-reproduction-contract', record['label'], bundle,
            references=('references/benchmark-case-method.md',), material_roots=(path.parent,))
    for path in sorted((ROOT / 'benchmark/library/core-examples').glob('**/design-spec.yaml')):
        data = yaml.safe_load(path.read_text())
        relative = path.relative_to(ROOT / 'benchmark/library/core-examples').as_posix()
        add(path, 'CORE-' + relative.replace('/design-spec.yaml', '').replace('/', '-'), 'core-examples',
            str(data.get('figure_task') or data.get('figure_id') or relative), data,
            references=('references/benchmark-case-method.md',), material_roots=(path.parent, path.parents[2]))
    # Keep unique prior evidence referenced from work/ visible and protected until
    # it is migrated with hash identity; do not mislabel it as regenerable cache.
    work = PROJECT / 'work/2026-09-26-six-repositories'
    for folder in sorted(work.glob('*')):
        if not folder.is_dir():
            continue
        specs = list(folder.glob('design-spec.yaml'))
        if not specs:
            continue
        path = specs[0]
        data = yaml.safe_load(path.read_text())
        data['renderer_candidates'] = [str(p.relative_to(PROJECT)) for p in sorted(folder.glob('*.R'))]
        rel = str(path.relative_to(PROJECT))
        entries.append({'method_id': 'SIX-PROJECT-' + folder.name, 'collection': 'six-project',
                        'title': folder.name, 'source_record': '../' + rel, 'source_sha256': sha(path),
                        'mandatory_read_set': ['../' + rel, 'references/six-project-benchmark-learning.md',
                                               'references/all-learning-audit-defects.md',
                                               *['../' + x for x in data['renderer_candidates']]],
                        'search_text': json.dumps(portable(data), ensure_ascii=False), 'learned_contract': portable(data),
                        'material_binding': bind_materials(data, (folder,)),
                        'transfer_status': 'NOT_VERIFIED', 'stress_status': 'NOT_VERIFIED',
                        'claim_boundary': 'Unique work evidence must be preserved; source-exposed study does not prove independent transfer.'})
        sources['../' + rel] = sha(path)
    path = ROOT / 'atlas/nature-figure-source-audit.json'
    if path.exists():
        add(path, 'SIX-PROJECT-nature-figure-audit', 'six-project', 'nature-figure methods audit', json.loads(path.read_text()),
            references=('references/six-project-benchmark-learning.md',))
    unique = {entry['method_id']: entry for entry in entries}
    if len(unique) != len(entries):
        from collections import Counter
        raise ValueError('duplicate learned method IDs: ' + str([k for k, n in Counter(e['method_id'] for e in entries).items() if n > 1]))
    counts = {}
    for entry in entries:
        counts[entry['collection']] = counts.get(entry['collection'], 0) + 1
    return overlay_public_profiles(json.loads(json.dumps({'schema_version': 1, 'policy': 'all persisted source learning; fixed fixture and independent transfer remain separate',
            'sources': sources, 'coverage': counts, 'entry_count': len(entries), 'entries': entries}, ensure_ascii=False)))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'atlas/learned-method-index.json')
    parser.add_argument('--refresh-public-profiles', action='store_true',
                        help='Refresh only bundled public execution bindings while retaining the shipped historical catalog; no private archives required.')
    args = parser.parse_args()
    result = overlay_public_profiles(json.loads(args.output.read_text())) if args.refresh_public_profiles else build()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    if args.output.resolve() == (ROOT / 'atlas/learned-method-index.json').resolve():
        from find_figure_reference import load_catalog
        load_catalog(refresh=True)
    print(json.dumps({'entry_count': result['entry_count'], 'coverage': result['coverage']}, ensure_ascii=False))
