#!/usr/bin/env python3
"""Validate a preregistered cross-model run ledger; does not execute model sessions."""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
import math
import statistics
from itertools import combinations
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parents[1]
PROTOCOL = ROOT / 'benchmark/cross-model/protocol.yaml'
CASES = ROOT / 'benchmark/cross-model/cases'


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_protocol():
    return yaml.safe_load(PROTOCOL.read_text(encoding='utf-8'))


def _load_checkpoint_validator():
    path = ROOT / 'scripts/validate_checkpoints.py'
    spec = importlib.util.spec_from_file_location('cross_model_checkpoint_validator', path)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


def validate_run_evidence(row: dict, base_dir: Path | None = None) -> list[str]:
    """Validate file hashes and derive CP3/CP4 status from the real ledger."""
    errors = []
    required = ('renderer_source', 'png', 'render_receipt', 'design_spec',
                'preparation_receipt', 'checkpoint_ledger', 'inspection_evidence')
    required = required + ('run_manifest',)
    evidence = row.get('evidence')
    if not isinstance(evidence, dict):
        return ['INCOMPLETE: actual artifact evidence map required; missing roles: ' + ', '.join(required)]
    files = {}
    for role in required:
        item = evidence.get(role)
        if not isinstance(item, dict) or not isinstance(item.get('path'), str) or not item.get('path'):
            errors.append(f'INCOMPLETE: artifact evidence path missing: {role}')
            continue
        path = Path(item['path']).expanduser()
        if not path.is_absolute():
            path = ((base_dir or Path.cwd()) / path).resolve()
        if not path.is_file() or not SHA256_RE.fullmatch(str(item.get('sha256', ''))) or sha(path) != item.get('sha256'):
            errors.append(f'INCOMPLETE: artifact evidence missing or SHA-256 mismatch: {role}')
            continue
        files[role] = path.resolve()
    if len(files) != len(required):
        return errors
    try:
        checkpoint = _load_checkpoint_validator()
        receipt_doc = json.loads(files['render_receipt'].read_text(encoding='utf-8'))
        prep_doc = json.loads(files['preparation_receipt'].read_text(encoding='utf-8'))
        spec_doc = yaml.safe_load(files['design_spec'].read_text(encoding='utf-8'))
        ledger = yaml.safe_load(files['checkpoint_ledger'].read_text(encoding='utf-8'))
        inspection = yaml.safe_load(files['inspection_evidence'].read_text(encoding='utf-8'))
        manifest = json.loads(files['run_manifest'].read_text(encoding='utf-8'))
        errors.extend(validate_run_manifest(row, evidence, manifest, files['run_manifest'], base_dir=base_dir))
        if files['png'].suffix.lower() != '.png':
            errors.append('INCOMPLETE: evidence png path is not a PNG')
        if not any(Path(str(item.get('path', ''))).expanduser().resolve() == files['renderer_source']
                   and item.get('sha256') == sha(files['renderer_source'])
                   for item in receipt_doc.get('sources', []) if isinstance(item, dict)):
            errors.append('INCOMPLETE: renderer source is not bound by render receipt')
        checkpoint_entries = ledger.get('checkpoints', [])
        cp2 = checkpoint_entries[2].get('evidence', {})
        cp3 = checkpoint_entries[3].get('evidence', {})
        cp4 = checkpoint_entries[4].get('evidence', {})
        if Path(str(cp2.get('design_spec', ''))).expanduser().resolve() != files['design_spec']:
            errors.append('INCOMPLETE: checkpoint ledger does not reference the evidence Design Spec')
        if Path(str(cp2.get('preparation_receipt', ''))).expanduser().resolve() != files['preparation_receipt']:
            errors.append('INCOMPLETE: checkpoint ledger does not reference the evidence preparation receipt')
        if Path(str(cp3.get('render_receipt', ''))).expanduser().resolve() != files['render_receipt']:
            errors.append('INCOMPLETE: checkpoint ledger does not reference the evidence render receipt')
        if Path(str(cp3.get('artifact', ''))).expanduser().resolve() != files['png']:
            errors.append('INCOMPLETE: checkpoint ledger does not reference the evidence PNG')
        if Path(str(cp4.get('inspection_evidence', ''))).expanduser().resolve() != files['inspection_evidence']:
            errors.append('INCOMPLETE: checkpoint ledger does not reference the evidence inspection file')
        errors.extend('CP2: ' + message for message in checkpoint.validate_preparation_receipt(str(files['preparation_receipt']), spec_doc))
        errors.extend('CP3: ' + message for message in checkpoint.validate_render_receipt(
            str(files['render_receipt']), files['png'], files['design_spec'], files['preparation_receipt']))
        errors.extend('CP4: ' + message for message in checkpoint.validate_inspection_evidence(
            inspection, spec_doc, files['render_receipt']))
        gate_errors = checkpoint.validate(ledger, checkpoint.load(checkpoint.DEFINITION))
        errors.extend('checkpoint ledger: ' + message for message in gate_errors)
        if checkpoint_entries[3].get('status') != 'PASS' or checkpoint_entries[4].get('status') != 'PASS':
            errors.append('INCOMPLETE: CP3 and CP4 must derive PASS from the checkpoint validator')
    except Exception as exc:
        errors.append(f'INCOMPLETE: actual artifact evidence could not be validated: {type(exc).__name__}: {exc}')
    return errors


SHA256_RE = __import__('re').compile(r'^[0-9a-f]{64}$')


def validate_run_manifest(row: dict, evidence: dict, manifest: dict, manifest_path: Path,
                          base_dir: Path | None = None) -> list[str]:
    errors = []
    expected_key = {'blind_id': row.get('blind_id'), 'case_id': row.get('case_id'), 'repeat': row.get('repeat')}
    actual_key = {field: manifest.get(field) for field in expected_key}
    if (manifest.get('schema_version') != 1 or actual_key != expected_key or manifest.get('run_key') != expected_key
            or manifest.get('run_id') != row.get('run_id') or not manifest.get('run_id')):
        errors.append('INCOMPLETE: run manifest run_key or run_id differs from report row')
    if manifest.get('input_sha256') != row.get('input_sha256'):
        errors.append('INCOMPLETE: run manifest input_sha256 differs from report row')
    expected_evidence = {key: value for key, value in evidence.items() if key != 'run_manifest'}
    expected_evidence['reviews'] = row.get('reviews')
    if manifest.get('evidence') != expected_evidence:
        errors.append('INCOMPLETE: run manifest evidence paths/hashes differ from report row')
    if row.get('evidence', {}).get('run_manifest', {}).get('path'):
        item = row['evidence']['run_manifest']
        path = Path(item['path']).expanduser()
        if not path.is_absolute(): path = ((base_dir or Path.cwd()) / path).resolve()
        if path.resolve() != manifest_path.resolve():
            errors.append('INCOMPLETE: report row references a different run manifest path')
    return errors


def validate_review_evidence(references: list, artifact_sha256: str, inspection: dict,
                            base_dir: Path | None = None, run_key: dict | None = None,
                            run_id: str | None = None, input_sha256: str | None = None) -> tuple[list[str], dict]:
    """Load independent reviewer records, bind them to CP4 evidence, and derive run outcomes."""
    errors = []
    derived = {'score_rows': [], 'scientific_hard_errors': 0, 'missing_deliverables': 0,
               'first_pass': False, 'hard_visual_defects': 0, 'reviewer_ids': []}
    checkpoint = _load_checkpoint_validator()
    dimensions = load_protocol().get('review_dimensions', [])
    minimum = load_protocol().get('blind_reviewers_minimum', 2)
    if not isinstance(references, list) or len(references) < minimum:
        return [f'INCOMPLETE: at least {minimum} hashed reviewer files are required'], derived
    cp4_records = inspection.get('review_records') if isinstance(inspection, dict) else None
    if not isinstance(cp4_records, list):
        return ['INCOMPLETE: CP4 inspection evidence must contain review_records'], derived
    for field, wanted in (('run_id', run_id), ('blind_id', (run_key or {}).get('blind_id')),
                          ('case_id', (run_key or {}).get('case_id')), ('repeat', (run_key or {}).get('repeat')),
                          ('input_sha256', input_sha256), ('artifact_sha256', artifact_sha256)):
        if inspection.get(field) != wanted or wanted is None or (field == 'repeat' and type(inspection.get(field)) is not int):
            errors.append(f'INCOMPLETE: CP4 inspection {field} does not bind this run')
    minimum = load_protocol().get('blind_reviewers_minimum', 2)
    if len(cp4_records) != len(references):
        errors.append('INCOMPLETE: CP4 review_records count must equal independent review file count')
    cp4_ids = [item.get('review', {}).get('reviewer_id') for item in cp4_records
               if isinstance(item, dict) and isinstance(item.get('review'), dict)]
    if len(cp4_ids) != len(cp4_records) or len(set(cp4_ids)) != len(cp4_ids):
        errors.append('INCOMPLETE: CP4 review_records reviewer_id values must be present and unique')
    loaded = []
    for index, reference in enumerate(references):
        if (not isinstance(reference, dict) or not isinstance(reference.get('path'), str)
                or not reference.get('path') or not SHA256_RE.fullmatch(str(reference.get('sha256', '')))):
            errors.append(f'INCOMPLETE: review file path and SHA-256 required at index {index}')
            continue
        path = Path(reference['path']).expanduser()
        if not path.is_absolute():
            path = ((base_dir or Path.cwd()) / path).resolve()
        if not path.is_file() or sha(path) != reference['sha256']:
            errors.append(f'INCOMPLETE: reviewer file missing or SHA-256 mismatch: {path}')
            continue
        try:
            if path.suffix.lower() == '.json':
                review = json.loads(path.read_text(encoding='utf-8'))
            else:
                review = yaml.safe_load(path.read_text(encoding='utf-8'))
        except Exception as exc:
            errors.append(f'INCOMPLETE: reviewer file unreadable: {path}: {exc}')
            continue
        if not isinstance(review, dict):
            errors.append(f'INCOMPLETE: reviewer record must be a mapping: {path}')
            continue
        reviewer_id = review.get('reviewer_id')
        if not isinstance(reviewer_id, str) or not reviewer_id.strip() or reviewer_id in derived['reviewer_ids']:
            errors.append(f'INCOMPLETE: reviewer IDs must be present and unique: {path}')
        else:
            derived['reviewer_ids'].append(reviewer_id)
        if review.get('schema_version') != 1 or review.get('reviewer_type') not in {'human', 'model'}:
            errors.append(f'INCOMPLETE: review schema or reviewer_type invalid: {path}')
        if review.get('judgment') not in {'PASS', 'REVISE', 'FAIL'}:
            errors.append(f'INCOMPLETE: reviewer judgment invalid: {path}')
        if review.get('artifact_sha256') != artifact_sha256:
            errors.append(f'INCOMPLETE: reviewer artifact hash differs from PNG: {path}')
        for field, wanted in (('blind_id', (run_key or {}).get('blind_id')),
                              ('case_id', (run_key or {}).get('case_id')),
                              ('repeat', (run_key or {}).get('repeat')),
                              ('run_id', run_id), ('input_sha256', input_sha256)):
            if review.get(field) != wanted or wanted is None or (field == 'repeat' and type(review.get(field)) is not int):
                errors.append(f'INCOMPLETE: reviewer {field} does not bind this run: {path}')
        if type(review.get('first_pass')) is not bool:
            errors.append(f'INCOMPLETE: reviewer first_pass must be boolean: {path}')
        scores = review.get('scores')
        if (not isinstance(scores, dict) or set(scores) != set(dimensions)
                or any(type(scores.get(d)) is not int or not 1 <= scores[d] <= 5 for d in dimensions)):
            errors.append(f'INCOMPLETE: six 1-5 review scores required: {path}')
            scores = {}
        scientific = review.get('scientific_hard_errors')
        missing = review.get('missing_deliverables')
        coordinates = review.get('defect_coordinates')
        if not isinstance(scientific, list) or any(not isinstance(x, str) or not x.strip() for x in scientific):
            errors.append(f'INCOMPLETE: scientific_hard_errors must be a list of findings: {path}')
            scientific = []
        if not isinstance(missing, list) or any(not isinstance(x, str) or not x.strip() for x in missing):
            errors.append(f'INCOMPLETE: missing_deliverables must be a list of findings: {path}')
            missing = []
        if not isinstance(coordinates, list):
            errors.append(f'INCOMPLETE: defect_coordinates must be a list: {path}')
            coordinates = []
        elif any(not isinstance(c, dict) or c.get('severity') not in {'hard', 'minor'} for c in coordinates):
            errors.append(f'INCOMPLETE: each defect coordinate requires severity hard or minor: {path}')
        if review.get('judgment') == 'PASS' and (
                scientific or missing or any(isinstance(c, dict) and c.get('severity') == 'hard' for c in coordinates)):
            errors.append(f'INCOMPLETE: PASS judgment conflicts with hard defects, scientific errors, or missing deliverables: {path}')
        revision_count = inspection.get('revision_count') if isinstance(inspection, dict) else None
        if type(revision_count) is not int or revision_count < 0:
            errors.append(f'INCOMPLETE: CP4 revision_count must be a non-negative integer (boolean excluded): {path}')
            has_revision = False
        else:
            has_revision = revision_count > 0
        if review.get('first_pass') is True and (review.get('judgment') != 'PASS' or has_revision):
            errors.append(f'INCOMPLETE: first_pass=true conflicts with judgment or CP4 revision history: {path}')
        if review.get('judgment') == 'PASS' and review.get('first_pass') is False and revision_count == 0:
            errors.append(f'INCOMPLETE: PASS judgment with first_pass=false requires recorded CP4 revision history: {path}')
        review_for_cp4 = dict(inspection)
        review_for_cp4.update({'artifact_sha256': artifact_sha256,
            'reviewer_id': reviewer_id or 'missing-reviewer', 'reviewer_type': review.get('reviewer_type'),
            'judgment': review.get('judgment'), 'defect_coordinates': coordinates})
        errors.extend(f'review CP4 evidence: {message}' for message in checkpoint.validate_inspection_evidence(review_for_cp4))
        loaded.append((reference, path.resolve(), review, scores, scientific, missing, coordinates))
    if len(derived['reviewer_ids']) != len(references):
        errors.append('INCOMPLETE: one unique reviewer ID is required per review file')
    if len(loaded) < minimum:
        return errors, derived
    cp4_by_id = {}
    for item in cp4_records:
        if isinstance(item, dict) and isinstance(item.get('review'), dict):
            reviewer_id = item['review'].get('reviewer_id')
            if reviewer_id in cp4_by_id:
                errors.append(f'INCOMPLETE: duplicate CP4 reviewer record: {reviewer_id}')
            else:
                cp4_by_id[reviewer_id] = item
    for reference, path, review, scores, scientific, missing, coordinates in loaded:
        record = cp4_by_id.get(review.get('reviewer_id'))
        expected_path = str(path)
        review_file_record = record.get('review_file', {}) if isinstance(record, dict) else {}
        cp4_path = Path(str(review_file_record.get('path', ''))).expanduser() if isinstance(review_file_record, dict) else Path('')
        if not cp4_path.is_absolute():
            cp4_path = ((base_dir or Path.cwd()) / cp4_path).resolve()
        if (not isinstance(record, dict) or not isinstance(review_file_record, dict)
                or review_file_record.get('sha256') != reference['sha256']
                or str(cp4_path.resolve()) != expected_path
                or record.get('review') != review):
            errors.append(f"INCOMPLETE: reviewer file record differs from CP4 inspection: {review.get('reviewer_id')}")
        if scores:
            avg = round(statistics.mean(scores[d] for d in dimensions))
            derived['score_rows'].append({'reviewer_id': review.get('reviewer_id'), 'scores': scores, 'aggregate': avg})
    if set(cp4_by_id) != set(derived['reviewer_ids']):
        errors.append('INCOMPLETE: CP4 inspection reviewer roster differs from hashed review files')
    derived['scientific_hard_errors'] = len({finding.strip() for item in loaded for finding in item[4]})
    derived['missing_deliverables'] = len({finding.strip() for item in loaded for finding in item[5]})
    derived['first_pass'] = all(item[2].get('first_pass') is True for item in loaded)
    derived['hard_visual_defects'] = int(any(coord.get('severity') == 'hard' for item in loaded for coord in item[6] if isinstance(coord, dict)))
    return errors, derived


def validate_report(report: dict, base_dir: Path | None = None) -> list[str]:
    errors = []
    report.pop('computed_metrics', None)
    protocol = load_protocol()
    if protocol.get('execution_ready') is not True:
        errors.append('frozen conditions are incomplete; real model execution is blocked')
    if report.get('protocol_sha256') != sha(PROTOCOL):
        errors.append('protocol hash mismatch')
    threshold = protocol.get('acceptance_thresholds', {})
    threshold_hash = hashlib.sha256(json.dumps(threshold, sort_keys=True).encode()).hexdigest()
    if report.get('thresholds_sha256') != threshold_hash:
        errors.append('threshold hash changed or threshold drift')
    fixed = protocol.get('fixed_conditions', {})
    for field in ('skill_commit', 'prompt_sha256', 'package_lock_sha256', 'toolset', 'permission_profile', 'cpu_limit'):
        value = fixed.get(field)
        if value in (None, '', [], {}) or (isinstance(value, str) and value.startswith('UNSET')):
            errors.append(f'frozen condition not preregistered: {field}')
    runs = report.get('runs')
    if not isinstance(runs, list) or not runs:
        return errors + ['INCOMPLETE: report contains no run rows or reviewer scores']
    if any('model_label' in row or 'model_name' in row for row in runs if isinstance(row, dict)):
        errors.append('model_label leakage in blind run rows')
    expected_repeats = protocol['repeats_per_model_case']
    expected_cases = {case['case_id'] for case in protocol['cases']}
    models = set(protocol['model_blind_ids'])
    expected = {(m, c, r) for m in models for c in expected_cases for r in range(1, expected_repeats + 1)}
    observed = set()
    per_pair = {}
    dimensions = protocol.get('review_dimensions', [])
    score_values = {dimension: [] for dimension in dimensions}
    paired_scores = {}
    reviewer_pairs = []
    reviewer_roster = None
    first_pass_values = []
    receipt_values = []
    scientific_errors = 0
    scientific_count = 0
    missing_deliverables = 0
    missing_count = 0
    hard_defect_rows = 0
    defect_count = 0
    complete_rows = 0
    seen_run_ids = set()
    seen_evidence_paths = {}
    for row in runs:
        if not isinstance(row, dict):
            continue
        key = (row.get('blind_id'), row.get('case_id'), row.get('repeat'))
        if type(row.get('repeat')) is not int:
            errors.append(f'INCOMPLETE: repeat must be an integer for run_key: {key}')
        run_id = row.get('run_id')
        if not isinstance(run_id, str) or not run_id.strip() or run_id in seen_run_ids:
            errors.append(f'INCOMPLETE: run_id must be present and unique for {key}')
        else:
            seen_run_ids.add(run_id)
        evidence_map = row.get('evidence', {}) if isinstance(row.get('evidence'), dict) else {}
        unique_refs = [('evidence.' + role, evidence_map.get(role)) for role in
                       ('renderer_source', 'design_spec', 'preparation_receipt', 'png', 'render_receipt',
                        'checkpoint_ledger', 'inspection_evidence', 'run_manifest')]
        unique_refs.extend((f'reviews[{i}]', ref) for i, ref in enumerate(row.get('reviews', []) if isinstance(row.get('reviews'), list) else []))
        for role, ref in unique_refs:
            if not isinstance(ref, dict) or not isinstance(ref.get('path'), str):
                continue
            ref_path = Path(ref['path']).expanduser()
            if not ref_path.is_absolute(): ref_path = ((base_dir or Path.cwd()) / ref_path).resolve()
            canonical_path = str(ref_path.resolve())
            if canonical_path in seen_evidence_paths:
                errors.append(f'INCOMPLETE: evidence path reused across run rows: {canonical_path}')
            else:
                seen_evidence_paths[canonical_path] = (key, role)
        if key in observed:
            errors.append(f'duplicate run row: {key}')
        observed.add(key)
        if key[0] not in models or key[1] not in expected_cases or key[2] not in range(1, expected_repeats + 1):
            errors.append(f'unexpected or malformed run key: {key}')
        if row.get('status') not in {'PASS', 'FAIL', 'BLOCKED'}:
            errors.append(f'failed or missing runs: invalid status for {key}')
        if row.get('status') != 'PASS' and not row.get('failure_reason'):
            errors.append(f'failed or missing runs: failure reason omitted for {key}')
        if 'receipt_consistent' in row:
            errors.append(f'INCOMPLETE: self-reported receipt_consistent is ignored for {key}')
        evidence_errors = validate_run_evidence(row, base_dir)
        errors.extend(f'{key}: {message}' for message in evidence_errors)
        aggregate_fields = ('scientific_hard_errors', 'missing_deliverables', 'first_pass', 'hard_visual_defects')
        if any(field in row for field in aggregate_fields):
            errors.append(f'INCOMPLETE: row-level review aggregates are ignored; derive from review files for {key}')
        reviews = row.get('reviews')
        evidence = row.get('evidence', {}) if isinstance(row.get('evidence'), dict) else {}
        try:
            inspection_path = Path(evidence['inspection_evidence']['path']).expanduser()
            if not inspection_path.is_absolute(): inspection_path = ((base_dir or Path.cwd()) / inspection_path).resolve()
            inspection = yaml.safe_load(inspection_path.read_text(encoding='utf-8'))
            artifact_hash = evidence['png']['sha256']
        except Exception:
            inspection, artifact_hash = {}, ''
        review_errors, derived = validate_review_evidence(reviews, artifact_hash, inspection, base_dir,
            {'blind_id': key[0], 'case_id': key[1], 'repeat': key[2]}, run_id, row.get('input_sha256'))
        errors.extend(f'{key}: {message}' for message in review_errors)
        reviewer_ids = derived['reviewer_ids']
        if reviewer_ids:
            if reviewer_roster is None: reviewer_roster = set(reviewer_ids)
            elif set(reviewer_ids) != reviewer_roster:
                errors.append(f'INCOMPLETE: reviewer roster differs across run matrix for {key}')
        row_aggregate = [review['aggregate'] for review in derived['score_rows']]
        if row_aggregate:
            for review in derived['score_rows']:
                for dimension in dimensions:
                    score_values[dimension].append(review['scores'][dimension])
        if not review_errors and len(row_aggregate) >= protocol.get('blind_reviewers_minimum', 2):
            reviewer_pairs.extend(combinations(row_aggregate, 2))
            paired_scores[(key[1], key[2], key[0])] = statistics.mean(
                statistics.mean(review['scores'][d] for d in dimensions) for review in derived['score_rows'])
            complete_rows += 1
            first_pass_values.append(derived['first_pass'])
            scientific_errors += derived['scientific_hard_errors']
            scientific_count += 1
            missing_deliverables += derived['missing_deliverables']
            missing_count += 1
            hard_defect_rows += derived['hard_visual_defects']
            defect_count += 1
        receipt_values.append(not evidence_errors)
        pair = (key[1], key[2])
        for field in ('skill_commit', 'prompt_sha256', 'package_lock_sha256', 'canvas_mm', 'dpi', 'seed',
                      'toolset', 'permission_profile', 'reasoning_effort', 'cpu_limit', 'wall_time_limit_seconds'):
            if row.get(field) in (None, '', [], {}):
                errors.append(f'frozen condition missing {field} for {key}')
        case_doc = next((c for c in protocol['cases'] if c['case_id'] == key[1]), {})
        if row.get('input_sha256') != case_doc.get('input_sha256'):
            errors.append(f'input hash differs from frozen case: {key}')
        if (row.get('canvas_mm') != case_doc.get('canvas_mm') or row.get('dpi') != case_doc.get('dpi')
                or row.get('seed') != case_doc.get('seed')):
            errors.append(f'canvas, DPI, or seed differs from frozen case: {key}')
        for field in ('skill_commit', 'prompt_sha256', 'package_lock_sha256', 'toolset', 'permission_profile', 'cpu_limit'):
            if fixed.get(field) not in (None, '', [], {}) and row.get(field) != fixed.get(field):
                errors.append(f'run violates frozen condition {field}: {key}')
        signature = (row.get('input_sha256'), json.dumps(row.get('toolset'), sort_keys=True),
                     row.get('permission_profile'), row.get('prompt_sha256'), row.get('skill_commit'),
                     row.get('package_lock_sha256'), json.dumps(row.get('canvas_mm')),
                     row.get('seed'), row.get('reasoning_effort'), row.get('cpu_limit'), row.get('wall_time_limit_seconds'))
        per_pair.setdefault(pair, set()).add(signature)
    if observed != expected:
        errors.append(f'failed or missing runs: expected {len(expected)} rows, got {len(observed)}')
    if any(len(signatures) > 1 for signatures in per_pair.values()):
        errors.append('unequal inputs, tools, permissions, or prompts across model runs')
    if any(row.get('status') != 'PASS' for row in runs if isinstance(row, dict)):
        errors.append('INCOMPLETE: non-PASS run rows cannot contribute to quality metrics')
        return errors
    if (observed != expected or complete_rows != len(expected) or any(not score_values[d] for d in dimensions)
            or len(receipt_values) != len(expected) or not all(receipt_values) or len(first_pass_values) != len(expected)
            or scientific_count != len(expected) or missing_count != len(expected) or defect_count != len(expected)):
        errors.append('INCOMPLETE: complete run and two-reviewer score matrix required before any benchmark result')
        return errors
    metrics = {
        'gate_receipt_consistency': sum(receipt_values) / len(receipt_values),
        'scientific_hard_errors': scientific_errors,
        'missing_deliverables': missing_deliverables,
        'first_pass_rate': sum(first_pass_values) / len(first_pass_values),
        'median_each_dimension': {d: statistics.median(score_values[d]) for d in dimensions},
        'hard_visual_defect_rate': hard_defect_rows / len(runs),
    }
    metrics['weighted_kappa'] = weighted_kappa(reviewer_pairs)
    blind_ids = protocol.get('model_blind_ids', [])
    differences = []
    if len(blind_ids) == 2:
        case_repeat_pairs = {(c, r) for c in expected_cases for r in range(1, expected_repeats + 1)}
        for case_id, repeat in case_repeat_pairs:
            left = paired_scores.get((case_id, repeat, blind_ids[0]))
            right = paired_scores.get((case_id, repeat, blind_ids[1]))
            if left is not None and right is not None:
                differences.append(left-right)
    if len(differences) < 2:
        errors.append('INCOMPLETE: paired model scores are required for mean difference and CI')
    else:
        mean_diff = statistics.mean(differences)
        ci_margin = 1.96 * statistics.stdev(differences) / (len(differences) ** 0.5)
        metrics['mean_paired_difference_abs'] = abs(mean_diff)
        metrics['paired_difference_95ci_abs'] = max(abs(mean_diff-ci_margin), abs(mean_diff+ci_margin))
    report['computed_metrics'] = metrics
    thresholds = protocol['acceptance_thresholds']
    checks = [
        ('gate_receipt_consistency', metrics['gate_receipt_consistency'] >= thresholds['gate_receipt_consistency']),
        ('scientific_hard_errors', metrics['scientific_hard_errors'] <= thresholds['scientific_hard_errors']),
        ('missing_deliverables', metrics['missing_deliverables'] <= thresholds['missing_deliverables']),
        ('first_pass_rate_min', metrics['first_pass_rate'] >= thresholds['first_pass_rate_min']),
        ('median_each_dimension_min', min(metrics['median_each_dimension'].values()) >= thresholds['median_each_dimension_min']),
        ('hard_visual_defect_rate_max', metrics['hard_visual_defect_rate'] <= thresholds['hard_visual_defect_rate_max']),
        ('weighted_kappa_min', metrics['weighted_kappa'] >= thresholds['weighted_kappa_min']),
    ]
    if 'mean_paired_difference_abs' in metrics:
        checks += [('mean_paired_difference_abs_max', metrics['mean_paired_difference_abs'] <= thresholds['mean_paired_difference_abs_max']),
                   ('paired_difference_95ci_abs_max', metrics['paired_difference_95ci_abs'] <= thresholds['paired_difference_95ci_abs_max'])]
    errors.extend(f'acceptance threshold failed: {name}' for name, passed in checks if not passed)
    return errors


def weighted_kappa(pairs: list[tuple[int, int]]) -> float:
    if not pairs:
        return 0.0
    categories = range(1, 6)
    n = len(pairs)
    observed = sum(abs(a-b)/4 for a,b in pairs) / n
    left = {k:sum(a==k for a,_ in pairs)/n for k in categories}
    right = {k:sum(b==k for _,b in pairs)/n for k in categories}
    expected = sum(left[i]*right[j]*abs(i-j)/4 for i in categories for j in categories)
    return 1.0 if expected == 0 and observed == 0 else 0.0 if expected == 0 else 1-observed/expected


def validate_protocol() -> list[str]:
    protocol = load_protocol()
    errors = []
    cases = protocol.get('cases', [])
    family_counts = {}
    for case in cases:
        family_counts[case.get('family')] = family_counts.get(case.get('family'), 0) + 1
        if not case.get('input_sha256') or len(case['input_sha256']) != 64:
            errors.append(f"case lacks frozen input hash: {case.get('case_id')}")
        if case.get('exposure') not in {'transfer', 'source-exposed'}:
            errors.append(f"case exposure invalid: {case.get('case_id')}")
        case_path = CASES / f"{case.get('case_id')}.yaml"
        if not case_path.is_file():
            errors.append(f"missing case definition: {case.get('case_id')}")
        else:
            case_doc = yaml.safe_load(case_path.read_text(encoding='utf-8'))
            if case_doc != case:
                errors.append(f"case file differs from preregistration: {case.get('case_id')}")
        if case.get('input_path'):
            input_path = CASES.parent / case['input_path']
            if not input_path.is_file() or sha(input_path) != case.get('input_sha256'):
                errors.append(f"input hash mismatch: {case.get('case_id')}")
        available = case.get('available_materials', [])
        if not available:
            errors.append(f"case has no auditable available materials: {case.get('case_id')}")
        for material in available:
            material_path = CASES.parent / material.get('path', '')
            if not material_path.is_file() or sha(material_path) != material.get('sha256'):
                errors.append(f"material hash mismatch: {case.get('case_id')}")
        if case.get('exposure') == 'transfer' and not case.get('forbidden_materials'):
            errors.append(f"transfer case must state forbidden source materials: {case.get('case_id')}")
        if case.get('exposure') == 'source-exposed' and not case.get('permitted_materials'):
            errors.append(f"source-exposed case must state permitted materials: {case.get('case_id')}")
    if len(family_counts) < 4 or any(count < 2 for count in family_counts.values()):
        errors.append('protocol requires four families and paired transfer/source-exposed cases')
    if protocol.get('repeats_per_model_case') != 3:
        errors.append('protocol must freeze three independent repeats')
    if len(set(protocol.get('model_blind_ids', []))) != len(protocol.get('model_blind_ids', [])) or not protocol.get('model_blind_ids'):
        errors.append('model blind IDs must be non-empty and unique')
    if not protocol.get('acceptance_thresholds'):
        errors.append('thresholds must be preregistered')
    return errors


def execution_blockers() -> list[str]:
    protocol = load_protocol()
    blockers = []
    if protocol.get('execution_ready') is not True:
        blockers.append('execution_ready is false; all cases are protocol templates until frozen conditions are set')
    for field in ('skill_commit','prompt_sha256','package_lock_sha256','toolset','permission_profile','cpu_limit'):
        value = protocol.get('fixed_conditions', {}).get(field)
        if value in (None, '', [], {}) or (isinstance(value,str) and value.startswith('UNSET')):
            blockers.append(f'unset execution condition: {field}')
    for case in protocol.get('cases', []):
        if case.get('exposure') != 'source-exposed':
            continue
        materials = case.get('available_materials', [])
        figure = next((x for x in materials if isinstance(x,dict) and x.get('role')=='source-figure'),None)
        code = next((x for x in materials if isinstance(x,dict) and x.get('role')=='author-code'),None)
        figure_path = CASES.parent / str((figure or {}).get('path',''))
        code_path = CASES.parent / str((code or {}).get('path',''))
        if (not figure or not figure_path.is_file() or figure_path.suffix.lower() not in {'.png','.jpg','.jpeg','.tif','.tiff','.pdf','.svg'}
                or not code or not code_path.is_file() or code_path.suffix.lower() not in {'.r','.py'}):
            blockers.append(f"{case.get('case_id')}: authentic source figure and author code are unavailable; template only")
    for family in {c.get('family') for c in protocol.get('cases', [])}:
        transfer = next((c for c in protocol.get('cases', []) if c.get('family')==family and c.get('exposure')=='transfer'),None)
        exposed = next((c for c in protocol.get('cases', []) if c.get('family')==family and c.get('exposure')=='source-exposed'),None)
        if not transfer or not exposed:
            blockers.append(f'{family}: paired transfer/source-exposed case missing')
        elif any(transfer.get(field)!=exposed.get(field) for field in ('task','input_sha256','canvas_mm','dpi','seed')):
            blockers.append(f'{family}: transfer/source-exposed task, input, canvas, DPI, or seed differ')
    return blockers


def run_smoke_cases() -> list[dict]:
    """Run two deterministic preflight cases; this does not render or test a model."""
    prep_spec = importlib.util.spec_from_file_location('biofigure_prepare_smoke', ROOT / 'scripts/prepare_figure.py')
    prep = importlib.util.module_from_spec(prep_spec)
    assert prep_spec and prep_spec.loader
    prep_spec.loader.exec_module(prep)
    cases = [yaml.safe_load((CASES / name).read_text(encoding='utf-8'))
             for name in ('distribution-transfer.yaml', 'matrix-transfer.yaml')]
    domains = {'distribution': 'imaging-assay', 'matrix': 'single-cell-spatial'}
    rows = []
    for case in cases:
        request = {'reference_mode': 'reference-guided', 'figure_task': case['task'], 'figure_family': case['family'],
                   'data_shape': case.get('data_semantics') or f"synthetic fixture {case['input_path']}",
                   'primary_domain': domains[case['family']], 'primary_role': 'comparison',
                   'backend': 'Python', 'deliverable': 'quick-png'}
        first = prep.prepare(request)
        second = prep.prepare(dict(reversed(list(request.items()))))
        if first.get('request_id') != second.get('request_id'):
            raise ValueError(f"smoke request normalization mismatch: {case['case_id']}")
        rows.append({'case_id': case['case_id'], 'status': first['status'],
                     'request_id': first['request_id'], 'preparation_id': first.get('preparation_id'),
                     'scope': 'preflight-only; no model session or render executed'})
    errors = smoke_preflight_errors(rows)
    if errors:
        raise ValueError('smoke preflight blocked: ' + '; '.join(errors))
    return rows


def smoke_preflight_errors(rows: list[dict]) -> list[str]:
    errors = []
    if not rows:
        return ['no smoke cases were executed']
    for row in rows:
        if row.get('status') != 'PREFLIGHT_COMPLETE':
            errors.append(f"{row.get('case_id', 'unknown case')} status={row.get('status', 'missing')}")
    return errors


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--validate-protocol', action='store_true')
    p.add_argument('--validate-report', type=Path)
    p.add_argument('--run-smoke-cases', action='store_true')
    a = p.parse_args()
    if a.run_smoke_cases:
        try:
            rows = run_smoke_cases()
            print(json.dumps({'status': 'PASS', 'scope': 'preflight-only', 'cases': rows}, indent=2))
            return 0
        except Exception as exc:
            status = 'BLOCKED' if str(exc).startswith('smoke preflight blocked:') else 'FAIL'
            print(json.dumps({'status': status, 'errors': [str(exc)]}, indent=2))
            return 1
    if a.validate_protocol:
        errors = validate_protocol()
        blockers = execution_blockers()
        protocol_status = 'PROTOCOL_VALID' if not errors else 'PROTOCOL_INVALID'
        execution_status = 'EXECUTION_READY' if not blockers and not errors else 'EXECUTION_BLOCKED'
        print(json.dumps({'protocol_status':protocol_status,'execution_status':execution_status,
                          'errors':errors,'blockers':blockers},indent=2))
        return 0 if not errors else 1
    if a.validate_report:
        report = json.loads(a.validate_report.read_text(encoding='utf-8'))
        errors = validate_report(report, a.validate_report.resolve().parent)
        blockers = execution_blockers()
        if any(item.startswith('INCOMPLETE:') for item in errors):
            status='INCOMPLETE'
        elif blockers:
            status='BLOCKED'
        else:
            status='PASS' if not errors else 'FAIL'
        print(json.dumps({'status':status,'errors':errors,'execution_blockers':blockers,
                          'computed_metrics':report.get('computed_metrics')},indent=2))
        return 0 if status=='PASS' else 2
    print(json.dumps({'status':'FAIL','errors':['select a validation mode']},indent=2))
    return 1


if __name__ == '__main__':
    raise SystemExit(main())
