#!/usr/bin/env python3
"""Query all learned contracts, not just old benchmark titles or four fixtures."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INDEX = ROOT / 'atlas/learned-method-index.json'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def retrieve(query, limit=5, case_id=None):
    data = json.loads(INDEX.read_text(encoding='utf-8'))
    from figure_reference_search import build_catalog, rank_catalog
    cards = rank_catalog(build_catalog(data), query, limit, case_id)
    by_id = {entry['method_id']: entry for entry in data['entries']}
    ranked = [(card['score'], by_id[card['method_id']], card) for card in cards]
    results = []
    syntax_path = ROOT / 'atlas/source-syntax-audit.json'
    syntax = json.loads(syntax_path.read_text(encoding='utf-8'))['files'] if syntax_path.is_file() else []
    for score, entry, card in ranked:
        item = dict(entry, score=score)
        item.pop('search_text')
        item['selection_reasons'] = card['match_reasons']
        item['retrieval_warnings'] = card['warnings']
        read_set = {rel: sha(ROOT / rel) for rel in item['mandatory_read_set'] if (ROOT / rel).is_file()}
        item['current_read_hashes'] = read_set
        item['missing_material'] = sorted(set(item['mandatory_read_set']) - set(read_set))
        item['source_record_changed'] = read_set.get(item['source_record']) != item['source_sha256']
        item['changed_bound_material'] = [r['path'] for r in item.get('material_binding', {}).get('bound', [])
                                          if read_set.get(r['path']) != r['sha256']]
        from validate_learned_reuse import qualification
        item['qualified_reuse'] = qualification(entry)
        item['known_source_syntax_issues'] = [r for r in syntax if r['path'] in item['mandatory_read_set'] and r['status'] != 'PASS']
        results.append(item)
    return {'schema_version': 1, 'index_sha256': sha(INDEX), 'query': query,
            'results': results, 'coverage': data['coverage'],
            'boundary': 'All stored learning is searchable. Retrieval coverage is not mastery or new-data transfer PASS.'}


def validate_binding(receipt, spec):
    learning = receipt.get('learned_methods')
    if not isinstance(learning, dict):
        return ['all-learning contract missing; prepare current invocation again']
    request = receipt.get('request', {})
    query = ' '.join(str(request.get(k)).strip() for k in ('figure_task', 'figure_family', 'data_shape', 'pattern_id')
                     if isinstance(request.get(k), str) and request.get(k).strip())
    if receipt.get('query') != query:
        return ['learned method query differs from normalized scientific request']
    expected = retrieve(query, case_id=request.get('learned_method_id'))
    if learning != expected:
        return ['learned methods/source notes changed or candidates do not match current task']
    if receipt.get('reusable_templates', {}).get('mode') == 'fixed_fixture_replay':
        return []  # The fixed scientific spec/source set is separately enforced.
    candidates = {x['method_id'] for x in learning['results']}
    if not candidates:
        return []
    binding = spec.get('reference_evidence', {}).get('learned_method_reuse', {})
    adopted = binding.get('adopted', [])
    rejected = binding.get('rejected', [])
    rejected_ids = {x.get('method_id') for x in rejected if x.get('reason')}
    if not isinstance(adopted, list) or not all(x in candidates for x in adopted):
        return ['learned_method_reuse.adopted must bind retrieved method IDs']
    if set(adopted) & rejected_ids or set(adopted) | rejected_ids != candidates:
        return ['CP2 must adopt or explicitly reject every learned candidate with reasons']
    if adopted and (not binding.get('data_adaptation') or not binding.get('known_failures_addressed')):
        return ['learned method reuse needs input adaptation and handling of prior defects']
    for candidate in learning['results']:
        if candidate['method_id'] in adopted and (candidate['source_record_changed'] or candidate['missing_material']
                                                  or candidate['changed_bound_material']):
            return ['adopted learned source/code/image missing or changed; audit and rebuild index before reuse']
        if candidate['method_id'] in adopted and candidate['qualified_reuse']['status'] == 'FAIL':
            return ['previously earned reuse evidence or runtime has drifted; re-audit before adopting this renderer']
        if candidate['method_id'] in adopted and candidate['qualified_reuse']['status'] == 'PASS':
            choices = [x for x in binding.get('adapter_decisions', [])
                       if isinstance(x, dict) and x.get('method_id') == candidate['method_id']]
            if len(choices) != 1:
                return ['each adopted qualified adapter requires exactly one explicit reuse or adapt decision']
            choice = choices[0]
            if choice.get('decision') == 'reuse':
                if choice.get('renderer') != candidate['qualified_reuse']['reuse_recipe']['renderer']:
                    return ['reused renderer must match the earned adapter path and SHA-256']
            elif choice.get('decision') == 'adapt':
                if not choice.get('data_contract_difference') or choice.get('new_validation_required') is not True:
                    return ['adapted adapter needs a concrete input-contract difference and fresh validation; previous PASS cannot transfer']
            else:
                return ['qualified adapter decision must be reuse or adapt']
        if candidate['method_id'] in adopted and candidate['known_source_syntax_issues']:
            resolutions = binding.get('source_issue_resolutions', [])
            resolved = {x.get('source_path') for x in resolutions if isinstance(x, dict) and x.get('resolution')}
            if not {r['path'] for r in candidate['known_source_syntax_issues']}.issubset(resolved):
                return ['adopted method must resolve each recorded source syntax issue before CP2']
    selected = request.get('learned_method_id')
    if selected and selected not in adopted:
        rejection = next((x for x in rejected if x.get('method_id') == selected), {})
        if not rejection.get('data_contract_difference') or not rejection.get('replacement_method_id'):
            return ['explicit learned method requires adoption or a concrete input-contract difference and replacement method']
    return []


def validate_adapter_sources(receipt, spec, sources):
    """Bind declared earned reuse to the actual source bytes being authorized."""
    binding = spec.get('reference_evidence', {}).get('learned_method_reuse', {})
    adopted = binding.get('adopted', [])
    actual_hashes = {sha(Path(path)) for path in sources if Path(path).is_file()}
    for candidate in receipt.get('learned_methods', {}).get('results', []):
        if candidate['method_id'] not in adopted or candidate.get('qualified_reuse', {}).get('status') != 'PASS':
            continue
        choice = next((x for x in binding.get('adapter_decisions', [])
                       if isinstance(x, dict) and x.get('method_id') == candidate['method_id']), {})
        renderer = candidate['qualified_reuse']['reuse_recipe']['renderer']
        if choice.get('decision') == 'reuse' and renderer['sha256'] not in actual_hashes:
            return ['actual renderer sources omit the earned adapter SHA-256; declared reuse is not executed reuse']
    return []


def plan_from_learned(entry, query, family, prior_plan):
    """Use the selected learned contract; never borrow unrelated package roles."""
    detail = entry['learned_contract']
    analysis = detail.get('code_analysis', {})
    inputs = {k: detail[k] for k in ('input_contract', 'data_type', 'required_fields', 'input',
              'input_and_dependencies', 'preplot', 'migration', 'migration_gaps') if detail.get(k)}
    layers = {k: detail[k] for k in ('mapping', 'layout', 'layout_contract', 'color_contract',
              'required_structure', 'required_structures', 'visual_observations', 'transferable_decisions') if detail.get(k)}
    packages = detail.get('plot_packages') or detail.get('r_packages') or detail.get('packages') or analysis.get('packages') or detail.get('packages_by_role', {})
    functions = detail.get('r_functions') or detail.get('functions') or analysis.get('plot_primitives') or []
    qualified = entry.get('qualified_reuse', {'status': 'NOT_VERIFIED'})
    return {'schema_version': 1, 'query': query, 'planning_status': 'METHOD_CANDIDATE', 'ready_to_render': False,
            'selected_case': {'case_id': entry['method_id'], 'title': entry['title'], 'source': 'learned-method',
                              'high_fidelity_eligible': False},
            'families': [family], 'data_contract': inputs or {'source_read_required': entry['mandatory_read_set']},
            'package_contract': {'specialized_first': True, 'candidates': packages, 'must_record_namespace_calls': True},
            'function_contract': functions, 'layer_contract': layers or {'source_read_required': entry['mandatory_read_set']},
            'blocking_failures': detail.get('guardrails') or detail.get('guards') or detail.get('do_not_transfer') or detail.get('migration_gaps') or [],
            'missing': ['map current input fields/units and required layers from this exact learned contract',
                        'handle source/code gaps and prior defects before CP2'],
            'mandatory_read_set': entry['mandatory_read_set'],
            'earned_reuse_recipe': qualified.get('reuse_recipe'),
            'qualified_reuse_status': qualified['status'],
            'learned_contract': detail, 'evidence_status': 'learned-method-new-input-transfer-unverified',
            'alternatives': [prior_plan] if prior_plan.get('selected_case') else [],
            'claim_policy': 'retrieval and source study do not certify new-data rendering'}


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--query', default='')
    p.add_argument('--case-id')
    p.add_argument('--limit', type=int, default=5)
    a = p.parse_args()
    print(json.dumps(retrieve(a.query, a.limit, a.case_id), ensure_ascii=False, indent=2))
