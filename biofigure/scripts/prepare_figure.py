#!/usr/bin/env python3
"""Deterministic pre-code retrieval gate for cross-model BioFigure consistency.

This script reads only the request metadata and BioFigure's local indexes. It does
not read user data, render figures, or infer scientific conclusions.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
import sys
import uuid
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from route_figure import route
from plan_figure_method import compile_plan
from retrieve_reproduction import retrieve as retrieve_reproduction
from retrieve_scidraw import retrieve as retrieve_scidraw
from retrieve_capabilities import retrieve as retrieve_capabilities
from reuse_templates import retrieve as retrieve_templates
from retrieve_learned_methods import retrieve as retrieve_learned

_ref_spec = importlib.util.spec_from_file_location('biofigure_references', ROOT / 'scripts/retrieve_references.py')
_ref_module = importlib.util.module_from_spec(_ref_spec)
assert _ref_spec and _ref_spec.loader
_ref_spec.loader.exec_module(_ref_module)
retrieve_top_journal = _ref_module.retrieve

DOMAIN_ALIASES = {
    'transcriptomics-metabolomics-multiomics': ['multi-omics', 'single-cell', 'matrix'],
    'single-cell-spatial': ['single-cell', 'matrix'],
    'chromatin-epigenome': ['chromatin', 'genomics'],
    'genome-sequence-variation': ['genomics', 'structural-variation', 'comparative-genomics'],
    'phylogeny-synteny-gene-family': ['comparative-genomics', 'genomics'],
    'imaging-assay': ['distribution', 'single-cell'],
    'machine-learning': ['genomics', 'single-cell'],
    'schematic-mechanism': ['multi-omics', 'genomics'],
    'multipanel': ['multi-omics', 'single-cell', 'matrix'],
}


def finalize_receipt(result: dict) -> dict:
    result.pop('preparation_id', None)
    result.pop('planning_id', None)
    result.pop('invocation_id', None)
    result['planning_id'] = hashlib.sha256(json.dumps(result, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
    result['invocation_id'] = uuid.uuid4().hex
    result['preparation_id'] = hashlib.sha256(json.dumps(result, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
    return result


def prepare(request: dict, *, fixture_replay_case_id: str | None = None) -> dict:
    if not isinstance(request, dict):
        raise ValueError('request must be a mapping')
    request_schema = yaml.safe_load((ROOT / 'schemas/figure-request.schema.yaml').read_text(encoding='utf-8'))
    missing = [key for key in request_schema['required'] if key not in request or request[key] is None]
    if missing:
        raise ValueError('request schema missing required fields: ' + ', '.join(missing))
    for key in ('figure_task',):
        if not isinstance(request.get(key), str) or not request[key].strip():
            raise ValueError(f'{key} must be a non-empty string')
    family_aliases = {'genome distribution': 'genome', 'genome-distribution': 'genome', 'heatmap': 'matrix',
                      'time_series': 'time-series', 'single_cell': 'single-cell'}
    if isinstance(request.get('figure_family', ''), str):
        request['figure_family'] = family_aliases.get(request.get('figure_family', '').strip().lower(), request.get('figure_family', '').strip().lower())
    else:
        raise ValueError('figure_family must be a string')
    if request['figure_family'] and request['figure_family'] not in request_schema['figure_family']:
        raise ValueError('figure_family must be an explicit supported value')
    for key in ('required_tools', 'required_permissions', 'available_tools', 'available_permissions'):
        if key in request and (not isinstance(request[key], list) or not all(isinstance(x, str) and x for x in request[key])):
            raise ValueError(f'{key} must be a list of strings')
    unavailable_tools = sorted(set(request.get('required_tools', [])) - set(request.get('available_tools', [])))
    unavailable_permissions = sorted(set(request.get('required_permissions', [])) - set(request.get('available_permissions', [])))
    if 'statistics_required' in request and type(request['statistics_required']) is not bool:
        raise ValueError('statistics_required must be boolean')
    normalized_request = {key: request.get(key) for key in (
        'figure_task', 'figure_family', 'data_shape', 'pattern_id', 'primary_source',
        'primary_domain', 'primary_role', 'backend', 'deliverable', 'operation', 'use_personal_style')}
    if 'statistics_required' in request:
        normalized_request['statistics_required'] = request['statistics_required']
    for key in ('secondary_domains', 'secondary_roles', 'reference_sources'):
        if key in request:
            normalized_request[key] = sorted(set(request[key]))
    for key in ('required_tools', 'available_tools', 'required_permissions', 'available_permissions',
                'declared_tools', 'declared_permissions'):
        if key in request:
            normalized_request[key] = sorted(set(request[key]))
    volatile_request_fields = {'model_label','model_name','working_directory','cwd','timestamp'}
    for key, value in request.items():
        if key not in normalized_request and key not in volatile_request_fields:
            normalized_request[key] = value
    request_id = hashlib.sha256(json.dumps(normalized_request, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
    if unavailable_tools or unavailable_permissions:
        return finalize_receipt({'schema_version': 1, 'status': 'BLOCKED_CAPABILITY', 'request_id': request_id,
                'missing_tools': unavailable_tools, 'missing_permissions': unavailable_permissions,
                'code_gate': 'BLOCKED', 'claim_boundary': 'No renderer code is authorized.'})
    task = request.get('figure_task')
    if not isinstance(task, str) or not task.strip():
        raise ValueError('figure_task is required; do not guess a chart from a vague request')
    family = request.get('figure_family', '')
    shape = request.get('data_shape', '')
    pattern = request.get('pattern_id', '')
    query = ' '.join(str(x).strip() for x in (task, family, shape, pattern) if isinstance(x, str) and x.strip())
    routed = route(request)
    if not str(shape).strip():
        return finalize_receipt({'schema_version': 1, 'status': 'NEEDS_SPEC', 'request_id': request_id,
                'request': normalized_request, 'selected_reference_candidates': {'planner_selected': None},
                'method_plan': {'planning_status': 'NEEDS_SPEC', 'selected_case': None},
                'code_gate': 'BLOCKED',
                'required_next_steps': ['resolve missing scientific/data fields; do not infer unknown measurements']})
    if not family:
        return finalize_receipt({'schema_version': 1, 'status': 'READY_FOR_CHART_SELECTION', 'request_id': request_id,
                'request': normalized_request, 'selected_reference_candidates': {'planner_selected': None},
                'method_plan': {'planning_status': 'CHART_SELECTION_REQUIRED', 'selected_case': None},
                'code_gate': 'BLOCKED_UNTIL_CHART_SELECTION_AND_CP2',
                'required_next_steps': ['analyze the scientific question and data shape, then propose a preferred chart and alternatives; validate the selected chart Design Spec before code']})
    method_plan = compile_plan(query, request.get('primary_source'), request.get('pangenome_context'))
    if method_plan.get('learning_contract') and family != method_plan['families'][0]:
        method_plan['planning_status'] = 'NEEDS_SPEC'
        method_plan['missing'] = ['figure_family conflicts with the pangenome scientific intent; expected '+method_plan['families'][0]]
    reproduction = retrieve_reproduction(query, limit=5)
    scidraw = retrieve_scidraw(query, limit=5)
    capability = retrieve_capabilities(query, limit=8)
    reusable_templates = retrieve_templates(normalized_request)
    learned_methods = retrieve_learned(query, case_id=request.get('learned_method_id'))
    if request.get('learned_method_id'):
        from retrieve_learned_methods import plan_from_learned
        method_plan = plan_from_learned(learned_methods['results'][0], query, family, method_plan)
    if fixture_replay_case_id:
        reusable_templates['mode'] = 'fixed_fixture_replay'
        reusable_templates['fixture_case_id'] = fixture_replay_case_id
    top_refs = []
    for domain in DOMAIN_ALIASES.get(request['primary_domain'], []):
        result = retrieve_top_journal(domain, task, pattern or None, 3)
        top_refs.extend(result['references'])
    seen = set()
    top_refs = [x for x in top_refs if not (x['atlas_id'] in seen or seen.add(x['atlas_id']))]
    registry_status = {
        'PASS': sum(bool(x.get('benchmark_eligible')) for x in reproduction['results']),
        'method_only_or_pending': sum(not bool(x.get('benchmark_eligible')) for x in reproduction['results']),
        'scope': 'only retrieved reproduction candidates; not the full benchmark registry',
    }
    reference_candidates = {
        'reproduction': [x['case_id'] for x in reproduction['results']],
        'scidraw': [x['case_id'] for x in scidraw['results']],
        'top_journal': [x['atlas_id'] for x in top_refs],
        'capability_graph': [x['case_id'] for x in capability['results']],
        'planner_selected': (method_plan.get('selected_case') or {}).get('case_id'),
    }
    bound_material = {
        'SKILL.md', 'manifest.yaml', 'static/core/execution-contract.yaml', 'schemas/figure-request.schema.yaml', 'schemas/figure-design-spec.schema.yaml',
        'checkpoints/checkpoints.yaml', 'scripts/prepare_figure.py', 'scripts/route_figure.py',
        'scripts/plan_figure_method.py', 'scripts/retrieve_reproduction.py', 'scripts/retrieve_scidraw.py',
        'scripts/retrieve_capabilities.py', 'scripts/retrieve_references.py', 'scripts/benchmark_core.py',
        'scripts/validate_design_spec.py', 'scripts/validate_checkpoints.py',
        'atlas/reproduction-derived-corpus.json', 'atlas/reproduction-methods.json',
        'atlas/scidraw-derived-corpus.json', 'atlas/scidraw-visual-grammar.yaml',
        'atlas/scidraw-source-compared-methods.json', 'atlas/scidraw-review-evidence.json',
        'atlas/scidraw-batch2-methods.json', 'atlas/scidraw-batch2-review-evidence.json',
        'atlas/scidraw-learning-ten-20260925.json', 'atlas/scidraw-learning-ten-20260925-02.json',
        'atlas/top-journal-corpus.yaml', 'atlas/unified-capability-graph.json',
        'atlas/family-execution-contracts.yaml', 'atlas/index.yaml', 'patterns/index.yaml',
        'renderer-registry.yaml', 'benchmark/registry.json',
        'scripts/plan_pangenome_figure.py',
        'atlas/reusable-template-index.json', 'scripts/reuse_templates.py',
        'scripts/run_template_replay.py', 'references/stable-template-reuse.md',
        'atlas/learned-method-index.json', 'scripts/retrieve_learned_methods.py',
        'scripts/build_learned_method_index.py', 'scripts/learning_materials.py',
        'scripts/figure_reference_search.py',
        'scripts/figure_library_categories.py',
        'references/all-learning-transfer.md', 'references/all-learning-audit-defects.md',
        'atlas/learned-method-validations.json', 'scripts/validate_learned_reuse.py',
        'atlas/source-syntax-audit.json',
        *[rel for entry in learned_methods['results'] for rel in entry['mandatory_read_set'] if '..' not in Path(rel).parts],
        *routed['modules'],
    }
    source_hashes = {name: hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
                     for name in sorted(bound_material) if (ROOT/name).is_file()}
    missing_material = sorted(name for name in bound_material if not (ROOT/name).is_file())
    preflight_complete = method_plan.get('planning_status') in {'METHOD_CANDIDATE', 'SOURCE_CANDIDATE'} and bool(query) and not missing_material
    result = {
        'schema_version': 1,
        'status': 'PREFLIGHT_COMPLETE' if preflight_complete else 'NEEDS_REFERENCE',
        'request': normalized_request,
        'query': query,
        'request_id': request_id,
        'capabilities': {'required_tools': sorted(request.get('required_tools', [])),
                         'available_tools': sorted(request.get('available_tools', [])),
                         'required_permissions': sorted(request.get('required_permissions', [])),
                         'available_permissions': sorted(request.get('available_permissions', []))},
        'route': routed,
        'method_plan': method_plan,
        'source_hashes': source_hashes,
        'missing_material': missing_material,
        'retrievals': {
            'reproduction': reproduction,
            'scidraw': scidraw,
            'capability_benchmark': capability,
            'top_journal': {'references': top_refs, 'evidence_gap': not bool(top_refs),
                            'boundary': 'Only the returned reviewed figure records; no journal-name style inference.'},
        },
        'selected_reference_candidates': reference_candidates,
        'benchmark_summary': registry_status,
        'reusable_templates': reusable_templates,
        'learned_methods': learned_methods,
        'code_gate': 'BLOCKED_UNTIL_REFERENCE_ANALYSIS_AND_CP2',
        'pre_code_gate': routed['pre_code_gate'],
        'required_next_steps': [
            'open the selected source figure(s) and inspect the original-size image',
            'read the cited method/layout notes and source code when available',
            'record panels, elements, mappings, coordinates, alignment and reading order in reference_analysis',
            'compare candidate patterns and record adopted and rejected elements in the Design Spec',
            'run validate_design_spec.py; only then start writing renderer code',
            'if a locked template matches, run run_template_replay.py for this preparation and bind template_reuse; new data still needs fresh final-size review',
            'read every relevant learned method contract/source and bind adopted/rejected candidates, input adaptation and prior defects in learned_method_reuse',
        ],
        'claim_boundary': 'A retrieval hit is a candidate, not proof of visual mastery. Benchmark PASS, source fidelity, and user approval remain separate states.',
    }
    if method_plan.get('planning_status') == 'NEEDS_SPEC':
        result['status'] = 'NEEDS_SPEC'
        result['code_gate'] = 'BLOCKED'
        result['required_next_steps'] = ['resolve missing scientific/data fields; do not infer unknown measurements']
    return finalize_receipt(result)


def main() -> int:
    parser = argparse.ArgumentParser(description='Prepare one chart task by searching BioFigure references and benchmark evidence before coding.')
    parser.add_argument('request', type=Path, help='YAML request with figure_task, domain, role, backend, deliverable')
    parser.add_argument('--output', type=Path, required=True, help='write the preparation receipt JSON')
    args = parser.parse_args()
    try:
        raw = args.request.read_text(encoding='utf-8')
        request = yaml.safe_load(raw)
        result = prepare(request)
    except Exception as exc:
        raw = locals().get('raw', '')
        request_id = hashlib.sha256(raw.encode()).hexdigest()
        result = finalize_receipt({'schema_version': 1, 'status': 'INVALID_REQUEST',
                                   'request_id': request_id, 'code_gate': 'BLOCKED',
                                   'errors': [f'{type(exc).__name__}: {exc}'],
                                   'claim_boundary': 'No renderer code is authorized.'})
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + '\n', encoding='utf-8')
    method_plan = result.get('method_plan')
    print(json.dumps({'status': result.get('status', 'INVALID_REQUEST'),
                      'preparation_id': result.get('preparation_id'),
                      'method_plan': method_plan.get('planning_status') if isinstance(method_plan, dict) else None,
                      'code_gate': result.get('code_gate', 'BLOCKED'),
                      'output': str(args.output)}, ensure_ascii=False))
    return 0 if result['status'] == 'PREFLIGHT_COMPLETE' else 2


if __name__ == '__main__':
    raise SystemExit(main())
