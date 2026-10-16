#!/usr/bin/env python3
"""Persist and recheck earned reuse evidence for each learned method."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
import subprocess
import tempfile
from functools import lru_cache
from pathlib import Path
from PIL import Image, ImageChops
from benchmark_core import validate_bundle, digest

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / 'atlas/learned-method-validations.json'
STRESS = {'long_labels', 'multiple_groups', 'missing_values', 'extreme_values', 'shuffled_metadata'}
TRANSFER_CHECKS = {'input_dimension_driven', 'metadata_join_by_key', 'required_structures_preserved', 'biological_unit_respected'}


@lru_cache(maxsize=32)
def current_runtime(packages):
    """Probe the current local R/package/font environment once per query process."""
    names = ','.join(json.dumps(p) for p in packages)
    expression = ('p<-c(' + names + '); v<-setNames(lapply(p,function(x)'
        'if(requireNamespace(x,quietly=TRUE))as.character(packageVersion(x)) else NA_character_),p);'
        'f<-unique(systemfonts::match_fonts(rep("Arial",3),italic=c(FALSE,FALSE,TRUE),'
        'weight=c("normal","bold","bold"))$path);'
        'cat(jsonlite::toJSON(list(r_version=as.character(getRversion()),platform=R.version$platform,'
        'system=unname(Sys.info()[c("sysname","release","machine")]),'
        'packages=v,font_files=f),auto_unbox=TRUE))')
    probe = subprocess.run(['Rscript', '--vanilla', '-e', expression], check=True,
                           capture_output=True, text=True, timeout=30, encoding='utf-8', errors='replace')
    value = json.loads(probe.stdout)
    paths = value.pop('font_files')
    paths = [paths] if isinstance(paths, str) else paths
    if not paths or any('arial' not in Path(p).name.casefold() for p in paths):
        raise ValueError('exact Arial faces unavailable; silent font fallback rejected')
    value['fonts'] = {p: digest(p) for p in paths}
    return value


@lru_cache(maxsize=32)
def pdf_pixels(path, file_hash):
    """Compare actual PDF appearance; the hash is also the cache invalidator."""
    if digest(path) != file_hash:
        raise ValueError('PDF changed before visual repeat check')
    info = subprocess.run(['pdfinfo', path], check=True, capture_output=True, text=True, timeout=30, encoding='utf-8', errors='replace')
    if not any(line.startswith('Pages:') and line.split(':', 1)[1].strip() == '1' for line in info.stdout.splitlines()):
        raise ValueError('qualified figure PDF must contain exactly one page')
    work = ROOT.parent / 'work/current/learned-reuse-audit'
    work.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=work) as temp:
        output = Path(temp) / 'preview'
        subprocess.run(['pdftoppm', '-r', '120', '-png', '-singlefile', path, str(output)],
                       check=True, capture_output=True, timeout=30)
        with Image.open(output.with_suffix('.png')) as im:
            rgb = im.convert('RGB')
            return rgb.size, hashlib.sha256(rgb.tobytes()).hexdigest()


def material_hashes(entry):
    return {entry['source_record']: entry['source_sha256'],
            **{r['path']: r['sha256'] for r in entry.get('material_binding', {}).get('bound', [])}}


def project_binding(item, label):
    """Check PROJECT-relative evidence and expose its current ROOT-relative binding."""
    if not isinstance(item, dict):
        raise ValueError(label + ': file binding missing')
    relative, expected = item.get('path'), item.get('sha256')
    if not isinstance(relative, str) or not relative.strip() or Path(relative).is_absolute():
        raise ValueError(label + ': PROJECT-relative file path required')
    project = ROOT.resolve().parent
    path = (project / relative).resolve()
    if not path.is_relative_to(project) or not path.is_file():
        raise ValueError(label + ': file missing or outside PROJECT')
    actual = digest(path)
    if expected != actual:
        raise ValueError(label + ': file SHA256 changed')
    return path, {'path': os.path.relpath(path, ROOT.resolve()), 'sha256': actual}


def source_review_evidence(review, method_id, source_sha256):
    """Recheck optional source-comparison records without promoting adapter PASS."""
    evidence, documents, errors = {}, {}, []
    for key in ('parent_review', 'source_difference_review'):
        if key not in review:
            continue
        label = key.replace('_', ' ')
        try:
            path, evidence[key] = project_binding(review[key], label)
            value = json.loads(path.read_text(encoding='utf-8'))
            if not isinstance(value, dict) or value.get('method_id') != method_id:
                raise ValueError(label + ': method binding differs')
            expected_status = 'status' if key == 'parent_review' else 'adapter_status'
            if value.get(expected_status) != 'PASS':
                raise ValueError(label + ': bounded adapter PASS not recorded')
            documents[key] = value
        except (OSError, ValueError, TypeError) as exc:
            errors.append(str(exc))
    if not documents:
        return errors, {}
    try:
        for key, value in documents.items():
            _, source = project_binding(value.get('source_reference'), key.replace('_', ' ') + ' source')
            if source['sha256'] != source_sha256:
                raise ValueError('source review: original image differs from bundle reference')
            if 'source_reference' in evidence and evidence['source_reference'] != source:
                raise ValueError('source review: original image bindings disagree')
            evidence['source_reference'] = source
        parent, difference = documents.get('parent_review'), documents.get('source_difference_review')
        if parent and difference:
            _, linked = project_binding(parent.get('source_difference_review'), 'parent source difference review')
            if linked != evidence['source_difference_review']:
                raise ValueError('source review: parent links another source difference review')
        status_record = difference if difference is not None else parent
        high_fidelity = status_record.get('high_fidelity_status')
        if not isinstance(high_fidelity, str) or not high_fidelity.strip():
            raise ValueError('source review: explicit high fidelity status missing')
        if (('high_fidelity_status' in review and review['high_fidelity_status'] != high_fidelity)
                or (parent and 'high_fidelity_status' in parent and parent['high_fidelity_status'] != high_fidelity)):
            raise ValueError('source review: high fidelity status differs from source record')
        evidence['high_fidelity_status'] = high_fidelity
        if difference and 'density_benchmark' in difference:
            path, binding = project_binding(difference['density_benchmark'], 'source density benchmark')
            density = json.loads(path.read_text(encoding='utf-8'))
            if (not isinstance(density, dict) or density.get('method_id') != method_id
                    or density.get('synthetic') is not True or density.get('status') != 'PASS'):
                raise ValueError('source density benchmark: same method, synthetic input and PASS required')
            _, source = project_binding(density.get('source_reference'), 'density benchmark source')
            if source != evidence['source_reference']:
                raise ValueError('source density benchmark: original image binding differs')
            evidence['source_density_benchmark'] = binding
        if difference and 'comparison_document' in difference:
            item = difference['comparison_document']
            path, binding = project_binding(item, 'source comparison document')
            page = item.get('page')
            if path.suffix.lower() != '.pdf' or not isinstance(page, int) or isinstance(page, bool) or page < 1:
                raise ValueError('source comparison document: PDF and positive integer page required')
            info = subprocess.run(['pdfinfo', str(path)], check=True, capture_output=True, text=True, timeout=30, encoding='utf-8', errors='replace')
            counts = [int(line.split(':', 1)[1].strip()) for line in info.stdout.splitlines() if line.startswith('Pages:')]
            if len(counts) != 1 or page > counts[0]:
                raise ValueError('source comparison document: page outside actual PDF')
            evidence['source_comparison_document'] = dict(binding, page=page)
    except (OSError, ValueError, TypeError, subprocess.SubprocessError) as exc:
        errors.append(str(exc))
    return errors, {} if errors else evidence


def triangle_layout_audit_required(contract):
    version = contract.get('adapter_version', 0)
    return (contract.get('case_id') == 'SCICASE-019' and isinstance(version, int)
            and not isinstance(version, bool) and version >= 3)


def triangle_audit_metrics_errors(value, pdf_hash, geometry_hash, auditor_hash):
    """Check bound numerical evidence; fresh PDF measurement belongs to PROJECT."""
    if not isinstance(value, dict):
        return ['triangle layout audit: report is not a mapping']
    errors = []
    for key, expected in (('pdf_sha256', pdf_hash), ('geometry_sha256', geometry_hash),
                          ('auditor_sha256', auditor_hash)):
        if value.get(key) != expected:
            errors.append('triangle layout audit: stale or wrong ' + key)
    if value.get('status') != 'PASS' or value.get('errors') != []:
        errors.append('triangle layout audit: clean measured PASS is required')
    for key in ('actual_triangle_overlap_count', 'text_collision_count', 'outside_page_count'):
        count = value.get(key)
        if not isinstance(count, int) or isinstance(count, bool) or count != 0:
            errors.append('triangle layout audit: nonzero or unmeasured ' + key)
    return errors


def validate_triangle_layout_audit(contract, receipt, review, root):
    """Only 019 v3+ needs the extra current artifact/hash gate; no PDF imports."""
    if contract.get('case_id') != 'SCICASE-019':
        return []
    version = contract.get('adapter_version', 0)
    if not isinstance(version, int) or isinstance(version, bool):
        return ['triangle layout audit: 019 adapter_version must be an integer']
    if not triangle_layout_audit_required(contract):
        return []
    try:
        root = Path(root).resolve()
        def bound(item, label):
            if (not isinstance(item, dict) or not isinstance(item.get('path'), str)
                    or not item['path'].strip() or not isinstance(item.get('sha256'), str)):
                raise ValueError('triangle layout audit: missing ' + label + ' binding')
            path = (root / item['path']).resolve()
            if not path.is_relative_to(root) or not path.is_file() or digest(path) != item['sha256']:
                raise ValueError('triangle layout audit: missing, outside bundle or stale ' + label)
            return path
        artifacts = receipt.get('artifacts', [])
        report = review.get('triangle_layout_audit')
        geometry = review.get('layout_density_metrics')
        if not isinstance(report, dict) or report not in artifacts:
            raise ValueError('triangle layout audit: report must bind a receipt artifact')
        if not isinstance(geometry, dict) or geometry not in artifacts:
            raise ValueError('triangle layout audit: geometry must bind a receipt artifact')
        pdfs = [a for a in artifacts if isinstance(a, dict) and a.get('path', '').lower().endswith('.pdf')]
        if len(pdfs) != 1:
            raise ValueError('triangle layout audit: exactly one final PDF is required')
        pdf_path = bound(pdfs[0], 'PDF')
        geometry_path = bound(geometry, 'geometry')
        report_path = bound(report, 'report')
        auditor = ROOT.parent / 'scripts/audit_triangle_layout.py'
        if not auditor.is_file():
            raise ValueError('triangle layout audit: current PROJECT auditor is missing')
        return triangle_audit_metrics_errors(json.loads(report_path.read_text(encoding='utf-8')),
            digest(pdf_path), digest(geometry_path), digest(auditor))
    except (OSError, ValueError, TypeError, AttributeError) as exc:
        return [str(exc)]


def validate_layout_density(contract, receipt, review, root):
    """Require source observations and bound render measurements, not a no-overlap proxy."""
    errors = validate_triangle_layout_audit(contract, receipt, review, root)
    density = contract.get('source_density_contract', {})
    source_hash = contract.get('reference', {}).get('sha256')
    if not isinstance(density, dict):
        return errors + ['layout: source density contract missing']
    if not source_hash or density.get('source_reference_sha256') != source_hash:
        errors.append('layout: source image binding missing or stale')
    observations = density.get('source_observations', {})
    for key in ('outer_margins', 'row_or_cell_spacing', 'panel_gaps', 'legend_packing', 'intentional_whitespace'):
        if not isinstance(observations, dict) or not isinstance(observations.get(key), str) or not observations[key].strip():
            errors.append('layout: missing source observation ' + key)
    item = review.get('dimensions', {}).get('information_density', {})
    if item.get('source_layout_compared') is not True:
        errors.append('layout: actual source/final density comparison not recorded')
    metric = review.get('layout_density_metrics', {})
    if not isinstance(metric, dict) or metric not in receipt.get('artifacts', []):
        errors.append('layout: actual renderer metrics not bound to receipt')
        return errors
    try:
        root = Path(root).resolve()
        path = (root / metric.get('path', '')).resolve()
        if not path.is_relative_to(root) or path.suffix != '.json' or not path.is_file() or digest(path) != metric.get('sha256'):
            errors.append('layout: render metrics missing, outside bundle or stale')
        else:
            value = json.loads(path.read_text(encoding='utf-8'))
            if not isinstance(value, dict) or not value:
                errors.append('layout: actual render measurements empty')
    except (OSError, ValueError, TypeError) as exc:
        errors.append('layout: invalid render measurements: ' + str(exc))
    return errors


def validate_typography(contract, receipt, review, root):
    """Bind chosen roles to actual geometry/PDF metrics and final-size observations."""
    errors = []
    chosen = contract.get('typography_contract', {})
    roles = chosen.get('size_roles_pt', {})
    if (not isinstance(roles, dict) or not roles
            or any(not isinstance(v, (int, float)) or isinstance(v, bool) or v <= 0 for v in roles.values())
            or not chosen.get('selection_basis')):
        return ['typography: final-size role sizes and adaptation basis missing']
    preset = chosen.get('preset_reference', {})
    source = (ROOT / preset.get('path', '')).resolve()
    if not source.is_relative_to(ROOT) or not source.is_file() or digest(source) != preset.get('sha256'):
        errors.append('typography: learned preset reference missing or stale')
    observed = review.get('dimensions', {}).get('typography', {})
    if not all(observed.get(k) is True for k in ('final_size_readability_reviewed', 'source_text_proportion_compared')):
        errors.append('typography: readability and source text/panel proportion not reviewed')
    for key in ('layout_density_metrics', 'pdf_font_metrics'):
        record = review.get(key, {})
        try:
            path = (Path(root).resolve() / record.get('path', '')).resolve()
            if (record not in receipt.get('artifacts', []) or not path.is_relative_to(Path(root).resolve())
                    or not path.is_file() or digest(path) != record.get('sha256')):
                errors.append('typography: unbound or stale ' + key)
                continue
            value = json.loads(path.read_text(encoding='utf-8'))
            if key == 'layout_density_metrics':
                if value.get('font_sizes_pt') != roles:
                    errors.append('typography: actual renderer roles differ from declared adaptation')
            else:
                actual = value.get('effective_point_sizes', [])
                pdfs = {a.get('sha256') for a in receipt.get('artifacts', []) if a.get('path', '').endswith('.pdf')}
                if value.get('pdf_sha256') not in pdfs or not actual or any(not isinstance(v, (int, float)) for v in actual):
                    errors.append('typography: actual final PDF point-size measurement missing')
                elif (min(actual) < min(roles.values()) - .02
                        or any(not any(abs(a-r) < .02 for r in roles.values()) for a in actual)
                        or any(not any(abs(a-r) < .02 for a in actual) for r in roles.values())):
                    errors.append('typography: measured PDF sizes differ from chosen role sizes')
        except (OSError, ValueError, TypeError, AttributeError) as exc:
            errors.append('typography: invalid measured evidence: ' + str(exc))
    return errors


def validate(record, entry):
    errors, bundles = [], {}
    try:
        if REGISTRY.is_file():
            registry = json.loads(REGISTRY.read_text(encoding='utf-8'))
            for revoked in registry.get('revoked_history', []):
                previous = revoked.get('previous_record', {})
                if (revoked.get('method_id') == record.get('method_id')
                        and previous.get('bundles') and previous['bundles'] == record.get('bundles')):
                    return {'status': 'FAIL', 'errors': [
                        'explicitly revoked visual evidence; render/review a new version']}
    except (OSError, ValueError, TypeError, AttributeError) as exc:
        return {'status': 'FAIL', 'errors': ['explicit revocation check failed: ' + str(exc)]}
    if record.get('method_id') != entry['method_id'] or record.get('source_material') != material_hashes(entry):
        errors.append('method/source material binding stale')
    for relative, expected in material_hashes(entry).items():
        if not (ROOT / relative).is_file() or digest(ROOT / relative) != expected:
            errors.append('locked learned material missing or changed: ' + relative)
    for key, mode in (('new_input', 'source-exposed-transfer'), ('repeat', 'source-exposed-transfer'), ('stress', 'stress')):
        binding = record.get('bundles', {}).get(key, {})
        path = (ROOT / binding.get('path', '')).resolve()
        if not path.is_relative_to(ROOT / 'benchmark/library') or not path.is_file() or binding.get('sha256') != digest(path):
            errors.append(key + ': missing, stale or nonpermanent bundle')
            continue
        bundle = json.loads(path.read_text(encoding='utf-8'))
        result = validate_bundle(bundle, path.parent)
        errors.extend(key + ': ' + e for e in result['errors'])
        errors.extend(key + ': ' + e for e in validate_layout_density(
            bundle.get('contract', {}), bundle.get('receipt', {}), bundle.get('review', {}), path.parent))
        errors.extend(key + ': ' + e for e in validate_typography(
            bundle.get('contract', {}), bundle.get('receipt', {}), bundle.get('review', {}), path.parent))
        source_errors, _ = source_review_evidence(bundle.get('review', {}), entry['method_id'],
                                                bundle.get('contract', {}).get('reference', {}).get('sha256'))
        errors.extend(key + ': ' + e for e in source_errors)
        if bundle.get('contract', {}).get('case_id') != entry['method_id'] or bundle.get('contract', {}).get('mode') != mode:
            errors.append(key + ': wrong method or evidence mode; fixed replay cannot qualify')
        if not TRANSFER_CHECKS.issubset(bundle.get('contract', {}).get('scientific_checks', [])):
            errors.append(key + ': missing predefined input/unit/structure/key checks')
        bundles[key] = (path, bundle)
    if len(bundles) != 3 or errors:
        return {'status': 'FAIL', 'errors': errors}
    first_path, first = bundles['new_input']
    repeat_path, repeat = bundles['repeat']
    stress_path, stress = bundles['stress']
    runtime = record.get('runtime_environment', {})
    if runtime.get('packages') != first['receipt'].get('packages'):
        errors.append('current runtime package lock does not match actual benchmark receipt')
    try:
        if runtime != current_runtime(tuple(sorted(first['receipt'].get('packages', {})))):
            errors.append('current R/package/font environment changed; earned reuse must be re-reviewed')
    except (subprocess.SubprocessError, OSError, ValueError) as exc:
        errors.append('current runtime probe failed: ' + str(exc))
    if len({p.parent for p, _ in bundles.values()}) != 3:
        errors.append('each run requires a distinct permanent directory')
    adaptation = first.get('contract', {}).get('new_input_adaptation', {})
    fixture_records = adaptation.get('source_fixture_inputs', [])
    fixture_inputs = []
    for item in fixture_records:
        path = (ROOT / item.get('path', '')).resolve()
        if (not path.is_relative_to(ROOT / 'benchmark/library') or not path.is_file()
                or digest(path) != item.get('sha256')):
            errors.append('source fixture input unavailable or stale')
        else:
            fixture_inputs.append(item['sha256'])
    actual_inputs = {x['sha256'] for x in first['receipt'].get('inputs', [])}
    if (adaptation.get('unseen_input') is not True or not adaptation.get('changed_dimensions')
            or not fixture_inputs or actual_inputs & set(fixture_inputs)):
        errors.append('new input must change dimensions and differ from recorded fixture inputs; seed-only change is insufficient')
    for key in ('script', 'inputs', 'packages'):
        a, b = first['receipt'].get(key), repeat['receipt'].get(key)
        if a != b:
            errors.append('independent repeat must preserve renderer, input and package versions: ' + key)
    pids = [b['receipt'].get('process_id') for _, b in bundles.values()]
    if not all(isinstance(p, int) and p > 0 for p in pids) or len(set(pids)) != 3:
        errors.append('three independent processes require recorded distinct process IDs')
    required_stress = {'stress_' + x for x in STRESS}
    if not required_stress.issubset(stress.get('contract', {}).get('scientific_checks', [])):
        errors.append('stress contract omits label/group/missing/extreme/shuffled-key checks')
    pngs = [[x for x in b['receipt'].get('artifacts', []) if Path(x['path']).suffix.lower() == '.png'] for b in (first, repeat)]
    if not pngs[0] or {x['path'] for x in pngs[0]} != {x['path'] for x in pngs[1]}:
        errors.append('repeat must have the same final PNG set')
    else:
        for item in pngs[0]:
            with Image.open(first_path.parent / item['path']) as a, Image.open(repeat_path.parent / item['path']) as b:
                if a.size != b.size or ImageChops.difference(a.convert('RGBA'), b.convert('RGBA')).getbbox():
                    errors.append('repeat final PNG differs: ' + item['path'])
    pdfs = [[x for x in b['receipt'].get('artifacts', []) if Path(x['path']).suffix.lower() == '.pdf'] for b in (first, repeat)]
    if not pdfs[0] or {x['path'] for x in pdfs[0]} != {x['path'] for x in pdfs[1]}:
        errors.append('repeat requires the same final PDF set')
    else:
        by_path = {x['path']: x for x in pdfs[1]}
        for item in pdfs[0]:
            other = by_path[item['path']]
            try:
                if pdf_pixels(str(first_path.parent / item['path']), item['sha256']) != pdf_pixels(str(repeat_path.parent / item['path']), other['sha256']):
                    errors.append('repeat final PDF appearance differs: ' + item['path'])
            except (OSError, ValueError, subprocess.SubprocessError) as exc:
                errors.append('PDF repeat check failed: ' + str(exc))
    return {'status': 'PASS' if not errors else 'FAIL', 'errors': errors,
            'scope': 'this method, recorded new inputs, stress scenarios, backend and environment; source-exposed reuse, not blind model learning'}


def qualification(entry):
    records = json.loads(REGISTRY.read_text(encoding='utf-8'))['records']
    matches = [r for r in records if r.get('method_id') == entry['method_id']]
    if not matches:
        return {'status': 'NOT_VERIFIED', 'errors': []}
    if len(matches) != 1:
        return {'status': 'FAIL', 'errors': ['duplicate learned method validation']}
    try:
        result = validate(matches[0], entry)
        if result['status'] == 'PASS':
            first_path = ROOT / matches[0]['bundles']['new_input']['path']
            bundle = json.loads(first_path.read_text(encoding='utf-8'))
            source_errors, source_evidence = source_review_evidence(bundle.get('review', {}), entry['method_id'],
                bundle.get('contract', {}).get('reference', {}).get('sha256'))
            if source_errors:
                raise ValueError('; '.join(source_errors))
            def bound(item):
                return {'path': os.path.relpath(first_path.parent / item['path'], ROOT), 'sha256': item['sha256']}
            result['reuse_recipe'] = {'renderer': bound(bundle['receipt']['script']),
                'contract': bound(bundle['receipt']['contract']),
                'input_examples': [bound(x) for x in bundle['receipt']['inputs']],
                'input_interface': bundle['contract']['learning']['input_contract'],
                'transform': bundle['contract']['learning']['transform'],
                'layout_rules': bundle['contract']['learning']['layout_rules'],
                'failure_modes': bundle['contract']['learning']['failure_modes'],
                'runtime_environment': matches[0]['runtime_environment'],
                'new_data_policy': 'Every new input requires fresh CP2 with current source/method bindings, a fresh source-to-output comparison, and final-size inspection of freshly rendered PNG and PDF. Prior PASS is limited to recorded inputs and environment.'}
            result['reuse_recipe'].update(source_evidence)
        return result
    except (OSError, ValueError, KeyError) as exc:
        return {'status': 'FAIL', 'errors': [str(exc)]}


def register(method_id, paths):
    index = json.loads((ROOT / 'atlas/learned-method-index.json').read_text(encoding='utf-8'))
    entry = next(e for e in index['entries'] if e['method_id'] == method_id)
    record = {'method_id': method_id, 'source_material': material_hashes(entry),
              'bundles': {k: {'path': os.path.relpath(Path(p).resolve(), ROOT), 'sha256': digest(p)} for k, p in paths.items()}}
    first = json.loads(Path(paths['new_input']).read_text(encoding='utf-8'))
    record['runtime_environment'] = current_runtime(tuple(sorted(first.get('receipt', {}).get('packages', {}))))
    result = validate(record, entry)
    if result['status'] != 'PASS':
        raise ValueError('; '.join(result['errors']))
    registry = json.loads(REGISTRY.read_text(encoding='utf-8'))
    if any(r['method_id'] == method_id for r in registry['records']):
        raise ValueError('existing qualification cannot be silently overwritten; preserve and audit previous evidence')
    registry['records'].append(record)
    temporary = REGISTRY.with_suffix('.json.tmp')
    temporary.write_text(json.dumps(registry, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    temporary.replace(REGISTRY)
    return result


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--method-id', required=True)
    p.add_argument('--new-input', required=True, type=Path)
    p.add_argument('--repeat', required=True, type=Path)
    p.add_argument('--stress', required=True, type=Path)
    a = p.parse_args()
    print(json.dumps(register(a.method_id, {'new_input': a.new_input, 'repeat': a.repeat, 'stress': a.stress}), ensure_ascii=False))
