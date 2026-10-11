"""Retrieve and validate locked templates. No visual or transfer certification."""
from __future__ import annotations
import copy
import hashlib
import json
import importlib.util
import subprocess
from PIL import Image
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parents[1]
INDEX = ROOT / 'atlas/reusable-template-index.json'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def records():
    return json.loads(INDEX.read_text(encoding='utf-8'))['cases']


def get_case(case_id):
    for case in records():
        if case['case_id'] == case_id:
            return case
    raise ValueError('unknown locked reusable case: ' + str(case_id))


def check_case(case):
    errors = []
    for record in case['bound_records']:
        path = ROOT / record['path']
        if not path.is_file() or sha(path) != record['sha256']:
            errors.append('template record changed: ' + record['path'])
    base = ROOT / case['template_root']
    baseline = json.loads((ROOT / case['baseline']).read_text())
    for record in baseline['bound_files']:
        path = base.parent / record['path']
        if not path.is_file() or sha(path) != record['sha256']:
            errors.append('locked template input changed: ' + record['path'])
    return errors


def retrieve(request):
    explicit = request.get('reusable_case_id')
    text = ' '.join(str(request.get(k) or '') for k in ('figure_task', 'data_shape', 'pattern_id')).casefold()
    source = request.get('primary_source')
    candidates = []
    for case in records():
        exact = (explicit == case['case_id'] or (source and Path(str(source)).resolve() == (ROOT / case['source_figure']).resolve()))
        matches = exact or all(any(cue.casefold() in text for cue in group) for group in case['cue_groups'])
        if matches and request.get('backend') == case['backend']:
            item = dict(case, match_kind='exact' if exact else 'method_candidate', integrity_errors=check_case(case))
            candidates.append(item)
    if explicit and not any(c['case_id'] == explicit for c in candidates):
        raise ValueError('requested reusable template is unknown or incompatible with backend')
    return {'schema_version': 1, 'index_sha256': sha(INDEX), 'mode': 'new_task',
            'candidates': sorted(candidates, key=lambda c: (c['match_kind'] != 'exact', c['case_id'])),
            'boundary': 'Fixed-fixture repeatability only. New data, model transfer and user acceptance are separate.'}


def visual_spec(spec):
    """Only operational CP2 identifiers may change during canonical fixture replay."""
    result = copy.deepcopy(spec)
    evidence = result.get('reference_evidence', {})
    for key in ('preparation_id', 'preparation_request', 'selected_method_case_id', 'template_reuse'):
        evidence.pop(key, None)
    return result


def validate_report(path, case_id, preparation_id):
    report = json.loads(Path(path).read_text(encoding='utf-8'))
    errors = []
    if report.get('schema_version') != 1 or report.get('status') != 'PASS' or report.get('case_id') != case_id:
        errors.append('template replay did not pass for selected case')
    if report.get('for_preparation_id') != preparation_id:
        errors.append('template replay belongs to another preparation')
    if report.get('index_sha256') != sha(INDEX):
        errors.append('template replay index changed')
    if report.get('independent_R_processes') != 2 or any(report.get(k) is not True for k in ('png_pixel_identical', 'pdf_raster_identical', 'semantic_geometry_identical', 'environment_lock_checked')):
        errors.append('template replay lacks two independent PNG/PDF regressions')
    for record in report.get('bound_files', []):
        p = Path(record['path'])
        if not p.is_file() or sha(p) != record['sha256']:
            errors.append('template replay evidence changed: ' + str(p))
    if not report.get('bound_files'):
        errors.append('template replay has no bound evidence')
    case = get_case(case_id)
    base = ROOT / case['template_root']
    required = [INDEX, ROOT / case['baseline'], base.parent / 'metadata/simulation-environment-lock.json',
                *[ROOT / 'scripts' / n for n in ('run_template_replay.py', 'prepare_figure.py', 'reuse_templates.py', 'authorize_render.py', 'validate_checkpoints.py')]]
    bound_paths = {Path(r['path']).resolve() for r in report.get('bound_files', [])}
    if not {p.resolve() for p in required}.issubset(bound_paths):
        errors.append('template replay omits required execution/environment bindings')
    runs = report.get('process_records', [])
    if len(runs) != 2 or len({r.get('pid') for r in runs}) != 2 or any(not isinstance(r.get('pid'), int) for r in runs):
        errors.append('template replay omits two distinct process records')
        return errors + check_case(case)
    baseline = json.loads((ROOT / case['baseline']).read_text())
    def actual_pixels(p):
        with Image.open(p) as im:
            rgb = im.convert('RGB')
            return {'size': list(rgb.size), 'rgb_sha256': hashlib.sha256(rgb.tobytes()).hexdigest()}
    for run in runs:
        for role in ('authorization', 'consumption_marker', 'render_log', 'png', 'pdf', 'pdf_preview', 'geometry', 'render_receipt'):
            record = run.get(role, {})
            p = Path(record.get('path', ''))
            if not p.is_file() or sha(p) != record.get('sha256'):
                errors.append('template replay process evidence missing/changed: ' + role)
        if errors:
            continue
        auth = json.loads(Path(run['authorization']['path']).read_text())
        technical = json.loads(Path(run['render_receipt']['path']).read_text())
        if auth.get('consumed') is not True or technical.get('status') != 'PASS' or Path(run['consumption_marker']['path']).read_text().strip() != auth.get('authorization_id'):
            errors.append('template replay missing consumed authorization or technical PASS')
        if actual_pixels(run['png']['path']) != baseline['image'] or actual_pixels(run['pdf_preview']['path']) != baseline['pdf_image']:
            errors.append('template replay pixels differ from reviewed baseline')
        if json.loads(Path(run['geometry']['path']).read_text()) != baseline['geometry']:
            errors.append('template replay semantic geometry differs from reviewed baseline')
    # Recheck the actual runtime at CP2; a previous environment claim is insufficient.
    environment_path = base.parent / 'metadata/simulation-environment-lock.json'
    expected = json.loads(environment_path.read_text())
    actual = json.loads(subprocess.run(['Rscript', '--vanilla', str(base.parent / 'scripts/capture_environment.R')], check=True, capture_output=True, text=True).stdout)
    actual['font_sha256'] = {p: sha(p) for p in actual['font_files']}
    if actual != expected:
        errors.append('current environment differs from reviewed lock')
    return errors + check_case(case)


def validate_binding(receipt, spec):
    reuse = receipt.get('reusable_templates')
    if not isinstance(reuse, dict):
        return ['reusable template contract missing; prepare this invocation again']
    errors = []
    if reuse.get('index_sha256') != sha(INDEX):
        return ['reusable template index changed; prepare again']
    expected_retrieval = retrieve(receipt.get('request', {}))
    if reuse.get('candidates') != expected_retrieval['candidates']:
        return ['reusable template candidates differ from current request/index']
    if reuse.get('mode') not in {'new_task', 'fixed_fixture_replay'}:
        return ['unknown reusable template execution mode']
    if reuse.get('mode') == 'fixed_fixture_replay':
        case = get_case(reuse['fixture_case_id'])
        expected_request = yaml.safe_load((ROOT / case['request']).read_text())
        from prepare_figure import prepare
        # Normalize without a fixture exemption to detect changed scientific/data fields.
        expected_id = prepare(expected_request)['request_id']
        actual_id = prepare(receipt.get('request', {}))['request_id']
        if receipt.get('request_id') != expected_id or actual_id != expected_id:
            errors.append('fixture replay request differs from locked fixture')
        expected_spec = yaml.safe_load((ROOT / case['template_root'] / 'data/metadata/design-spec.yaml').read_text())
        if visual_spec(spec) != visual_spec(expected_spec):
            errors.append('fixture replay changed locked visual/scientific specification')
        return errors + check_case(case)
    candidates = reuse.get('candidates', [])
    if not candidates:
        return []
    decision = spec.get('reference_evidence', {}).get('template_reuse', {})
    if decision.get('decision') == 'not_applicable':
        if any(c['match_kind'] == 'exact' for c in candidates):
            errors.append('exact reusable template requires fresh replay')
        if not decision.get('reason') or not decision.get('data_contract_difference'):
            errors.append('template rejection needs reason and data contract difference')
        return errors
    if decision.get('decision') != 'reuse' or decision.get('case_id') not in {c['case_id'] for c in candidates}:
        return ['CP2 must bind template reuse/rejection to retrieved candidates']
    try:
        errors.extend(validate_report(decision['replay_receipt'], decision['case_id'], receipt['preparation_id']))
        if sha(decision['replay_receipt']) != decision.get('replay_sha256'):
            errors.append('template replay receipt hash differs from Design Spec')
    except Exception as exc:
        errors.append('template replay receipt invalid: ' + str(exc))
    return errors


def validate_fixture_sources(receipt, sources):
    reuse = receipt.get('reusable_templates', {})
    if reuse.get('mode') != 'fixed_fixture_replay':
        return []
    case = get_case(reuse['fixture_case_id'])
    base = ROOT / case['template_root']
    inputs = {86: ['pathways.csv'], 89: ['genes.csv'], 97: ['MAG_tree.nwk', 'arg_samples.csv', 'mag_abundance.csv'], 98: ['fungi.csv', 'prokaryotes.csv']}[case['issue']]
    expected = [base / 'scripts/render.R', ROOT / 'scripts/figure_style.R', base.parent / 'scripts/render_simulation_common.R', *[base / 'results/plot_data' / name for name in inputs]]
    if case['issue'] == 86:
        expected.append(base / 'data/metadata/node_colors.json')
    # Paths differ inside the isolated mirror. Content and complete source set must match.
    if sorted(sha(p) for p in sources) != sorted(sha(p) for p in expected):
        return ['fixture replay source set differs from locked renderer and input data']
    return check_case(case)


def audit():
    registry = json.loads((ROOT / 'benchmark/registry.json').read_text())['cases']
    stable = {c['case_id']: c for c in records()}
    rows = []
    for entry in registry:
        case = stable.get(entry['case_id'])
        errors = check_case(case) if case else []
        rows.append({'case_id': entry['case_id'], 'title': entry.get('label', ''),
                     'stable_reuse': 'LOCKED_FIXED_FIXTURE' if case and not errors else 'REVISE' if errors else 'NOT_CERTIFIED',
                     'reason': '; '.join(errors) if errors else 'locked simulation only' if case else 'no complete locked fixture indexed; historical benchmark status retained'})
    for case_id in stable.keys() - {x['case_id'] for x in rows}:
        case = stable[case_id]; errors = check_case(case)
        rows.append({'case_id': case_id, 'title': case['title'], 'stable_reuse': 'REVISE' if errors else 'LOCKED_FIXED_FIXTURE', 'reason': '; '.join(errors) or 'locked simulation only'})
    return {'scope': 'All benchmark registry records plus locked-template index; integrity inventory, not new visual recertification',
            'registered_cases': len(registry), 'locked_templates': sum(r['stable_reuse'] == 'LOCKED_FIXED_FIXTURE' for r in rows),
            'not_certified': sum(r['stable_reuse'] == 'NOT_CERTIFIED' for r in rows), 'cases': rows}
