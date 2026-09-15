"""Evidence validation. This verifies records, never infers visual quality from hashes."""
from __future__ import annotations
import hashlib
import json
from PIL import Image, ImageStat
from pathlib import Path

DIMENSIONS = ('family', 'panel_topology', 'required_structures', 'typography', 'annotation', 'information_density')


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def validate_bundle(bundle, root):
    root = Path(root).resolve()
    errors = []

    def check_file(record, label):
        if not isinstance(record, dict):
            errors.append(f'{label}: missing file record')
            return None
        path = (root / record.get('path', '')).resolve()
        if not path.is_relative_to(root) or not path.is_file():
            errors.append(f'{label}: missing or out-of-root file')
            return None
        if record.get('sha256') != digest(path):
            errors.append(f'{label}: stale hash')
        if path.suffix.lower() == '.png':
            try:
                with Image.open(path) as img:
                    img.verify()
            except (OSError, ValueError):
                errors.append(f'{label}: undecodable image')
        return path

    contract = bundle.get('contract', {})
    receipt = bundle.get('receipt', {})
    review = bundle.get('review', {})
    for key in ('case_id', 'mode', 'family'):
        if not contract.get(key):
            errors.append(f'contract: missing {key}')
    if contract.get('mode') not in {'reproduction', 'source-exposed-transfer', 'transfer', 'stress'}:
        errors.append('contract: invalid mode')
    structures = contract.get('required_structures', [])
    if not structures or len(set(structures)) != len(structures):
        errors.append('contract: empty or duplicate structures')
    for key in ('input_contract', 'transform', 'join_order', 'package_roles', 'layout_rules', 'failure_modes'):
        if not contract.get('learning', {}).get(key):
            errors.append(f'learning: missing {key}')
    check_file(contract.get('reference'), 'reference')
    cp = check_file(receipt.get('contract'), 'contract binding')
    if cp:
        try:
            if json.loads(cp.read_text()) != contract:
                errors.append('contract: in-memory/file mismatch')
        except (ValueError, UnicodeError):
            errors.append('contract: invalid JSON file')
    if receipt.get('case_id') != contract.get('case_id'):
        errors.append('receipt: wrong case')
    if receipt.get('exit_code') != 0:
        errors.append('runtime: nonzero or missing exit code')
    if receipt.get('runner') != 'biofigure-benchmark-v2' or not receipt.get('fresh_directory'):
        errors.append('runtime: missing fresh run provenance')
    if not isinstance(receipt.get('elapsed_seconds'), (int, float)) or receipt.get('elapsed_seconds', -1) < 0:
        errors.append('runtime: missing duration')
    check_file(receipt.get('script'), 'script')
    check_file(receipt.get('log'), 'log')
    check_file(receipt.get('environment'), 'environment')
    for record in receipt.get('inputs', []):
        check_file(record, 'input')
    if not receipt.get('inputs'):
        errors.append('runtime: input manifest empty')
    if not contract.get('packages'):
        errors.append('contract: package requirements empty')
    versions = receipt.get('packages', {})
    for name in contract.get('packages', []):
        if not versions.get(name):
            errors.append(f'package: missing version {name}')
    artifacts = receipt.get('artifacts', [])
    if not artifacts:
        errors.append('runtime: no artifacts')
    for record in artifacts:
        path = check_file(record, 'artifact')
        if path and path.suffix.lower() == '.png':
            try:
                with Image.open(path) as image:
                    image.load()
                    if image.format != 'PNG' or min(image.size) < 16:
                        errors.append('artifact: invalid PNG dimensions')
                    if max(ImageStat.Stat(image.convert('RGB')).stddev) < 1:
                        errors.append('artifact: blank PNG')
            except (OSError, ValueError):
                errors.append('artifact: invalid PNG')
    checks = contract.get('scientific_checks', [])
    if not checks:
        errors.append('science: no predefined checks')
    for key in checks:
        item = receipt.get('scientific_results', {}).get(key, {})
        if item.get('status') != 'pass' or not item.get('evidence'):
            errors.append(f'science: unverified {key}')
    if review.get('receipt_sha256') != hashlib.sha256(json.dumps(receipt, sort_keys=True, ensure_ascii=False).encode()).hexdigest():
        errors.append('review: stale receipt binding')
    if not review.get('reviewer') or not review.get('reviewed_at'):
        errors.append('review: missing observer metadata')
    if review.get('family') != contract.get('family'):
        errors.append('review: wrong family')
    if not set(structures).issubset(review.get('observed_structures', [])):
        errors.append('review: missing required structure')
    check_file(review.get('comparison'), 'comparison')
    for dim in DIMENSIONS:
        item = review.get('dimensions', {}).get(dim, {})
        if item.get('status') != 'pass' or not item.get('evidence'):
            errors.append(f'review: {dim} not evidenced PASS')
        for key in ('reference_region', 'output_region'):
            box = item.get(key)
            if not (isinstance(box, list) and len(box) == 4 and all(isinstance(v, (int, float)) and 0 <= v <= 1 for v in box) and box[0] < box[2] and box[1] < box[3]):
                errors.append(f'review: {dim} invalid {key}')
    for defect in ('overlap', 'clipping', 'missing_glyphs'):
        if review.get('defects', {}).get(defect) is not False:
            errors.append(f'review: unresolved {defect}')
    if contract.get('mode') == 'transfer':
        holdout = contract.get('holdout', {})
        if not holdout.get('input_sha256') or holdout.get('input_sha256') not in {x.get('sha256') for x in receipt.get('inputs', [])}:
            errors.append('transfer: no bound held-out input')
        # A script-only run cannot establish a model generation access boundary.
        isolation = bundle.get('generation_isolation', {})
        check_file(isolation.get('access_log'), 'generation access log')
        if isolation.get('source_exposed') is not False or isolation.get('enforced_by') not in {'container-allowlist', 'sandbox-allowlist'}:
            errors.append('transfer: no enforced generation isolation')
    return {'case_id': contract.get('case_id'), 'mode': contract.get('mode'), 'status': 'FAIL' if errors else 'PASS', 'errors': errors,
            'boundary': 'Evidence consistency plus recorded visual observations; not an independent aesthetic judgment or proof of model learning.'}


def registry_results(root):
    """Revalidate each track separately. One reproduction cannot certify transfer."""
    root = Path(root).resolve()
    path = root / 'benchmark/registry.json'
    data = json.loads(path.read_text()) if path.exists() else {'cases': []}
    results = {}
    for entry in data['cases']:
        case_id = entry['case_id']
        if case_id in results:
            raise ValueError(f'duplicate registry ID: {case_id}')
        tracks = {mode: {'status': 'PENDING', 'errors': []} for mode in ('reproduction','transfer','stress')}
        bindings = entry.get('bundles', {})
        if entry.get('bundle'):
            bindings = dict(bindings, reproduction=entry['bundle'])
        for mode, relative in bindings.items():
            if mode not in tracks:
                raise ValueError(f'unknown benchmark track: {mode}')
            if not relative:
                continue
            path = (root / relative).resolve()
            if not path.is_relative_to(root) or not path.is_file():
                tracks[mode] = {'status': 'FAIL', 'errors': ['registered bundle unavailable']}
                continue
            bundle = json.loads(path.read_text())
            result = validate_bundle(bundle, path.parent)
            if bundle.get('contract', {}).get('case_id') != entry.get('method_id', case_id):
                result = {'status': 'FAIL', 'errors': ['registry/bundle case mismatch']}
            if bundle.get('contract', {}).get('mode') != mode:
                result = {'status': 'FAIL', 'errors': ['registry/bundle track mismatch']}
            tracks[mode] = result
        statuses = [x['status'] for x in tracks.values()]
        status = 'PASS' if all(x == 'PASS' for x in statuses) else ('FAIL' if 'FAIL' in statuses else 'PENDING')
        results[case_id] = {'status': status, 'tracks': tracks}
    return results


def inventory(root):
    root = Path(root)
    graph = json.loads((root / 'atlas/unified-capability-graph.json').read_text())
    cases = [n for n in graph['nodes'] if n.get('kind') == 'case']
    ids = [n['id'] for n in cases]
    errors = [] if len(ids) == len(set(ids)) else ['duplicate case IDs']
    results = registry_results(root)
    if set(ids) != set(results):
        errors.append('benchmark registry does not cover the exact graph case set')
    counts = {status: sum(r['status'] == status for r in results.values()) for status in ('PASS','FAIL','PENDING')}
    return {'schema_version': 2, 'inventory_status': 'FAIL' if errors else 'PASS',
            'benchmark_status': 'PASS' if counts['PASS'] == len(cases) and cases and not errors else 'INCOMPLETE',
            'case_count': len(cases), 'legacy_pass': sum(bool(n.get('high_fidelity_eligible')) for n in cases),
            'verified_benchmark_pass': counts['PASS'], 'benchmark_failed': counts['FAIL'],
            'pending_migration': counts['PENDING'],
            'track_pass': {mode: sum(r['tracks'][mode]['status']=='PASS' for r in results.values()) for mode in ('reproduction','transfer','stress')},
            'errors': errors,
            'boundary': 'Legacy flags are not V2 evidence. Registered bundles are revalidated on every query; visual judgment remains observer evidence.'}
