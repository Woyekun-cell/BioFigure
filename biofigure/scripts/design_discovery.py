"""Reference-first design discovery without requiring private paper archives.

Discovery is mandatory; adopting an external method still uses its existing
source/replay contract. Review attestations are workflow evidence, not proof of
human attention or a replacement for final-size visual inspection.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
POLICY = 'reference-first-v1'
REVIEW_KEYS = ('structure', 'code', 'data_mapping', 'typography', 'legend_and_layout', 'adaptation')


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def discover(request, query):
    from run_public_example import CASES
    selected_pattern = request.get('pattern_id')
    index = ROOT / 'patterns/index.yaml'
    if index.is_file():
        import yaml
        patterns = yaml.safe_load(index.read_text(encoding='utf-8'))['patterns']
        matching = [row for row in patterns if row['pattern_id'] == selected_pattern] if selected_pattern else [
            row for row in patterns if row.get('task') == request.get('figure_task')]
        pattern = matching[0] if len(matching) == 1 else {}
        selected_pattern = pattern.get('pattern_id', selected_pattern)
        query += ' ' + ' '.join(pattern.get('tags', []))
    candidates = []
    for case, values in CASES.items():
        if selected_pattern != values[0]:
            continue
        folder = f'examples/portable/{case}'
        files = [{'role': role, 'path': path, 'sha256': digest(ROOT / path)}
                 for role, path in (
                     ('figure', f'{folder}/figures/{case}.png'), ('code', 'examples/portable/render.R'),
                     ('metadata', f'{folder}/metadata.json'), ('provenance', f'{folder}/provenance.json'))
                 if (ROOT / path).is_file()]
        if len(files) == 4:
            provenance = json.loads((ROOT / folder / 'provenance.json').read_text(encoding='utf-8'))
            if provenance.get('license') != 'MIT' or provenance.get('origin') != 'BioFigure-owned synthetic data':
                continue
            candidates.append({'candidate_id': 'PUBLIC-' + case, 'kind': 'packaged-example',
                'pattern_id': values[0], 'case': case, 'files': files, 'license': 'MIT',
                'qualification': 'paired public recipe; current input and final visual quality must be reviewed anew'})
    # Rank compact metadata in memory: no full-library preload, corpus mutation,
    # download, or missing-private-file requirement during original preparation.
    archive = {'status': 'UNAVAILABLE', 'results': [], 'reason': 'Optional learning index is not installed.'}
    catalog_path = ROOT / 'atlas/figure-reference-catalog.json'
    if catalog_path.is_file():
        try:
            from figure_reference_search import rank_catalog
            cards = rank_catalog(json.loads(catalog_path.read_text(encoding='utf-8')), query, 3)
            archive = {'status': 'SEARCHED', 'results': [
                {key: card.get(key) for key in ('method_id', 'title', 'type_tags', 'warnings', 'recorded_adapter_registration')}
                for card in cards], 'reason': 'Candidates only; selected learned methods require their full source/code and fresh reuse binding.'}
        except (OSError, ValueError, KeyError, TypeError) as exc:
            archive['reason'] = 'Optional metadata unavailable: ' + str(exc)
    templates = {'status': 'UNAVAILABLE', 'results': []}
    if (ROOT / 'atlas/reusable-template-index.json').is_file():
        from reuse_templates import check_case
        text = ' '.join(str(request.get(key) or '') for key in ('figure_task', 'data_shape', 'pattern_id')).casefold()
        rows = json.loads((ROOT / 'atlas/reusable-template-index.json').read_text(encoding='utf-8'))['cases']
        matched = []
        for row in rows:
            if row.get('backend') != request.get('backend') or not all(any(cue.casefold() in text for cue in group) for group in row['cue_groups']):
                continue
            try:
                problems = check_case(row)
            except (OSError, ValueError, KeyError) as exc:
                problems = [str(exc)]
            matched.append({'case_id': row['case_id'], 'availability': 'UNAVAILABLE' if problems else 'INTEGRITY_CHECKED',
                            'problems': problems, 'qualification': 'fixed-fixture only; actual reuse needs its original source-mode contract'})
        templates = {'status': 'UNAVAILABLE' if any(row['problems'] for row in matched) else 'SEARCHED',
                     'candidates': matched, 'reason': 'Optional fixed fixtures; missing private archives never block original design.'}
    return {'policy_id': POLICY, 'query': query, 'candidates': candidates,
            'optional_archive_search': archive, 'locked_template_search': templates,
            'required_action': 'review-paired-figure-and-code' if candidates else 'document-pattern-fallback',
            'claim_boundary': 'Discovery, source learning, fixed-input replay, new-input adaptation and visual acceptance are separate.'}


def material_paths(discovery):
    paths = {row['path'] for candidate in discovery['candidates'] for row in candidate['files']}
    for name in ('atlas/figure-reference-catalog.json', 'atlas/reusable-template-index.json'):
        if (ROOT / name).is_file():
            paths.add(name)
    return paths


def validate_review(discovery, doc):
    prefix = 'reference_evidence.design_precedent'
    errors = []
    review = doc.get('reference_evidence', {}).get('design_precedent')
    if not isinstance(review, dict) or review.get('policy_id') != POLICY:
        return [prefix + ' requires current reference-first-v1 template/code review']
    if not isinstance(discovery, dict) or discovery.get('policy_id') != POLICY:
        return [prefix + ' has no current mandatory discovery receipt; prepare again']
    decisions = review.get('review', {})
    for key in REVIEW_KEYS:
        value = decisions.get(key) if isinstance(decisions, dict) else None
        if not isinstance(value, str) or value.strip().casefold().strip('.。!！') in {'', 'pass', 'ok', 'done', 'n/a', 'na', 'yes', 'true', '已检查', '通过', '符合', '完成', '无'}:
            errors.append(prefix + '.review.' + key + ' requires a concrete current-input design/code decision')
    candidates = discovery.get('candidates', [])
    strategy = review.get('strategy')
    if strategy == 'pattern-fallback':
        rejected = review.get('rejected_candidates', [])
        if not isinstance(rejected, list) or any(not isinstance(row, dict) or not str(row.get('reason', '')).strip() for row in rejected):
            errors.append(prefix + '.rejected_candidates requires candidate IDs and scientific/design rejection reasons')
        else:
            ids = {row.get('candidate_id') for row in candidates}
            ids.update(row.get('method_id') for row in discovery.get('optional_archive_search', {}).get('results', []))
            ids.update(row.get('case_id') for row in discovery.get('locked_template_search', {}).get('candidates', []))
            if not ids <= {row.get('candidate_id') for row in rejected}:
                errors.append(prefix + '.rejected_candidates must explain every discovered candidate before Pattern fallback')
        if not str(review.get('fallback_reason', '')).strip():
            errors.append(prefix + '.fallback_reason must explain the new design and missing reference/code scope')
        return errors
    if strategy not in {'reviewed-reference', 'packaged-replay'}:
        return errors + [prefix + '.strategy must be reviewed-reference, packaged-replay, or pattern-fallback']
    selected = next((row for row in candidates if row.get('candidate_id') == review.get('candidate_id')), None)
    if not selected:
        return errors + [prefix + '.candidate_id was not discovered for this Pattern; use the learned/source contract for external adoption']
    if review.get('files') != selected.get('files'):
        errors.append(prefix + '.files must bind the exact discovered figure, code, metadata and provenance hashes')
    for row in selected.get('files', []):
        path = (ROOT / row['path']).resolve()
        if ROOT.resolve() not in path.parents or not path.is_file() or digest(path) != row.get('sha256'):
            errors.append(prefix + '.files changed or escaped the Skill root: ' + row['path'])
    if strategy == 'reviewed-reference':
        inspection = review.get('inspection', {})
        for key in ('figure_opened', 'code_read'):
            if not isinstance(inspection, dict) or inspection.get(key) is not True:
                errors.append(prefix + '.inspection.' + key + ' requires actual current source inspection before coding')
    return errors


def validate_renderer_sources(receipt, doc, sources):
    review = doc.get('reference_evidence', {}).get('design_precedent', {})
    if review.get('strategy') != 'packaged-replay':
        return []
    errors = validate_review(receipt.get('design_discovery'), doc)
    code = [row for row in review.get('files', []) if row.get('role') == 'code']
    actual = {digest(path) for path in sources if Path(path).is_file()}
    if not code or any(row['sha256'] not in actual for row in code):
        errors.append('design_precedent packaged-replay requires the exact discovered recipe renderer; new code needs reviewed-reference')
    allowed_code = {(ROOT / name).resolve() for name in (
        'examples/portable/render.R', 'scripts/figure_style.R', 'scripts/run_public_example.py')}
    paths = {Path(path).resolve() for path in sources}
    extras = paths - allowed_code
    if extras:
        # Bind roles/locations, never guess whether a file is code by extension.
        configs = [path for path in extras if path.name == 'render-config.json']
        if len(configs) != 1:
            return errors + ['design_precedent packaged-replay permits only the sealed recipe source set and its declared data/configuration']
        try:
            config_path = configs[0]
            config = json.loads(config_path.read_text(encoding='utf-8'))
            audit = config_path.parent
            candidate = next(row for row in receipt['design_discovery']['candidates'] if row['candidate_id'] == review['candidate_id'])
            analysis_path = audit / 'analysis.json'
            analysis = json.loads(analysis_path.read_text(encoding='utf-8'))
            design_path = Path(config['design_spec_path']).resolve()
            if config.get('case') != candidate['case'] or design_path.parent != audit or design_path.name != 'design-spec.yaml':
                raise ValueError('recipe case or Design Spec path differs from the sealed runner')
            import yaml
            if yaml.safe_load(design_path.read_text(encoding='utf-8')) != doc:
                raise ValueError('recipe configuration points to another Design Spec')
            allowed = allowed_code | {config_path, analysis_path, Path(config['input_path']).resolve(),
                                      Path(config['metadata_path']).resolve()}
            statistics = analysis.get('statistics')
            if statistics:
                path = Path(statistics['path'])
                allowed.add(path.resolve() if path.is_absolute() else (audit / path).resolve())
            if (audit / 'heatmap-values.csv').is_file():
                allowed.add(audit / 'heatmap-values.csv')
            if paths != allowed:
                raise ValueError('source roles/paths differ from the sealed runner; new renderer dependencies are forbidden')
        except (OSError, ValueError, KeyError, TypeError, StopIteration) as exc:
            errors.append('design_precedent packaged-replay source contract invalid: ' + str(exc))
    return errors
