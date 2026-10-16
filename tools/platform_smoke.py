#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Cold Skill-only platform execution. Technical checks never sign visual CP4."""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import importlib.util
import json
import math
import os
from pathlib import Path
import platform
import re
import random
import shutil
import statistics
import subprocess
import sys
import tarfile
import venv

PORTABLE_CASES = ('boxplot', 'heatmap', 'dense-heatmap', 'bubble', 'volcano', 'synteny', 'phylogeny')


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load_json(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def write_json(path, value):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def contained(root, relative):
    root = Path(root).resolve()
    path = (root / relative).resolve()
    if not path.is_relative_to(root) or path == root:
        raise ValueError(f'Bound path is outside the Skill: {relative}')
    return path


def verify_bound_files(root, bindings):
    for binding in bindings:
        path = contained(root, binding['path'])
        if not path.is_file() or sha(path) != binding['sha256']:
            raise ValueError(f'SHA-256 mismatch or missing bound file: {binding["path"]}')


def verify_source_review(skill, case_id, source_asset, review):
    if (review.get('schema_version') != 1 or review.get('scope') != 'reference-source-inspection-only'
            or not review.get('reviewer') or not review.get('reviewed_at')):
        raise ValueError('A recorded actual source inspection is required for replay')
    cases = [row for row in review.get('cases', []) if row.get('case_id') == case_id]
    if len(cases) != 1 or not cases[0].get('observations'):
        raise ValueError(f'Missing actual source inspection: {case_id}')
    files = cases[0].get('files', [])
    if source_asset not in [row.get('path') for row in files] or any(row.get('viewed') is not True for row in files):
        raise ValueError(f'Source was not actually viewed: {case_id}')
    verify_bound_files(skill, files)
    return {'scope': 'Reference source bytes only; candidate output has not been visually reviewed.',
            'source_asset': source_asset, 'reviewer': review['reviewer'], 'reviewed_at': review['reviewed_at']}


def make_summary(results, errors, commit):
    return {'schema_version': 1, 'status': 'FAIL' if errors else 'TECHNICAL_PASS_PENDING_VISUAL_REVIEW',
            'commit': commit, 'platform': platform.platform(), 'python_version': platform.python_version(),
            'results': results, 'errors': errors, 'visual_review': 'NOT_RUN', 'cp4_certified': False,
            'boundary': 'Current platform execution, statistics and export checks only. The actual generated PNG/PDF must still be viewed. No publication acceptance, new-input qualification or all-omics certification is inferred.'}


def merge_phase_summary(previous, results, errors, commit):
    if previous.get('commit') != commit:
        raise ValueError('Previous original-phase evidence belongs to a different commit')
    summary = make_summary([*previous.get('results', []), *results], [*previous.get('errors', []), *errors], commit)
    summary['requested_scope'] = 'portable-original-external-and-retained-replays'
    summary['phases'] = {**previous.get('phases', {}),
                         'replays': {'status': 'FAIL' if errors else 'TECHNICAL_PASS_PENDING_VISUAL_REVIEW',
                                     'case_ids': [row['case'] for row in results], 'errors': errors}}
    return summary


def execute(command, cwd, log_path, *, env=None):
    result = subprocess.run([str(value) for value in command], cwd=cwd, env=env,
                            text=True, encoding='utf-8', errors='replace', capture_output=True)
    write_json(log_path, {'command': [str(value) for value in command], 'returncode': result.returncode,
                          'stdout': result.stdout, 'stderr': result.stderr})
    if result.returncode:
        raise RuntimeError(f'Command failed ({result.returncode}); see {log_path}: {result.stderr[-2500:]}')
    return result


def tree_hashes(root):
    return {path.relative_to(root).as_posix(): sha(path) for path in sorted(Path(root).rglob('*')) if path.is_file()}


def prepare(repository, work, install_python_deps=False, write_github_env=False):
    repository, work = repository.resolve(), work.resolve()
    skill = work / 'installed skills' / 'biofigure'
    if skill.exists():
        raise ValueError('Cold installation target already exists; choose a new work root')
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repository, text=True, encoding='utf-8', errors='replace').strip()
    archive = subprocess.check_output(['git', 'archive', '--format=tar', f'{commit}:biofigure'], cwd=repository)
    skill.mkdir(parents=True)
    with tarfile.open(fileobj=io.BytesIO(archive), mode='r:') as bundle:
        for member in bundle.getmembers():
            path = contained(skill, member.name)
            if member.isdir():
                path.mkdir(parents=True, exist_ok=True)
            elif member.isfile():
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(bundle.extractfile(member).read())
            else:
                raise ValueError(f'Skill archive contains a nonregular member: {member.name}')
    manifest = load_json(skill / 'public-cases.json')
    verify_bound_files(skill, manifest['shared_runtime_files'])
    for case in manifest['cases']:
        verify_bound_files(skill, case.get('files', []))
    environment = work / 'python environment'
    venv.EnvBuilder(with_pip=True).create(environment)
    python = environment / ('Scripts/python.exe' if os.name == 'nt' else 'bin/python')
    if install_python_deps:
        execute([python, '-m', 'pip', 'install', '-r', skill / 'requirements.txt',
                 '-r', repository / 'tools/platform-requirements.txt'], work, work / 'python-install.json')
    (work / 'unrelated cwd 中文').mkdir()
    state = {'schema_version': 1, 'commit': commit, 'skill_root': str(skill), 'python': str(python),
             'repository_root': str(repository), 'work_root': str(work), 'skill_snapshot': tree_hashes(skill)}
    write_json(work / 'installation.json', state)
    if write_github_env:
        env_path = os.environ.get('GITHUB_ENV')
        if not env_path:
            raise ValueError('--write-github-env requires the GitHub Actions environment')
        with open(env_path, 'a', encoding='utf-8') as handle:
            for key, value in {'BIOFIGURE_SKILL_ROOT': skill, 'BIOFIGURE_PYTHON': python, 'BIOFIGURE_PLATFORM_WORK': work}.items():
                handle.write(f'{key}={value}\n')
    return {key: value for key, value in state.items() if key != 'skill_snapshot'}


def beta_fraction(a, b, x):
    qab, qap, qam = a + b, a + 1, a - 1
    c, d = 1.0, 1 - qab * x / qap
    d = 1 / (d if abs(d) > 1e-300 else 1e-300)
    h = d
    for m in range(1, 401):
        aa = m * (b - m) * x / ((qam + 2 * m) * (a + 2 * m))
        d = 1 + aa * d
        d = d if abs(d) > 1e-300 else 1e-300
        c = 1 + aa / c
        c = c if abs(c) > 1e-300 else 1e-300
        d = 1 / d
        h *= d * c
        aa = -(a + m) * (qab + m) * x / ((a + 2 * m) * (qap + 2 * m))
        d = 1 + aa * d
        d = d if abs(d) > 1e-300 else 1e-300
        c = 1 + aa / c
        c = c if abs(c) > 1e-300 else 1e-300
        d = 1 / d
        delta = d * c
        h *= delta
        if abs(delta - 1) < 3e-14:
            return h
    raise ValueError('Incomplete beta did not converge')


def regularized_beta(x, a, b):
    if x <= 0:
        return 0.0
    if x >= 1:
        return 1.0
    factor = math.exp(math.lgamma(a + b) - math.lgamma(a) - math.lgamma(b) + a * math.log(x) + b * math.log1p(-x))
    if x < (a + 1) / (a + b + 2):
        return factor * beta_fraction(a, b, x) / a
    return 1 - factor * beta_fraction(b, a, 1 - x) / b


def welch(reference, treatment):
    n0, n1 = len(reference), len(treatment)
    v0, v1 = statistics.variance(reference) / n0, statistics.variance(treatment) / n1
    se = math.sqrt(v0 + v1)
    df = (v0 + v1) ** 2 / (v0 ** 2 / (n0 - 1) + v1 ** 2 / (n1 - 1))
    difference = statistics.mean(treatment) - statistics.mean(reference)
    probability = lambda t: regularized_beta(df / (df + t * t), df / 2, 0.5)
    lo, hi = 0.0, 1000.0
    for _ in range(100):
        middle = (lo + hi) / 2
        if probability(middle) > 0.05:
            lo = middle
        else:
            hi = middle
    half = (lo + hi) / 2 * se
    return dict(n_reference=n0, n_treatment=n1, mean_difference=difference,
                ci_low=difference - half, ci_high=difference + half, p_value=probability(abs(difference) / se), df=df)


def csv_rows(path):
    with open(path, newline='', encoding='utf-8-sig') as handle:
        return list(csv.DictReader(handle))


def verify_statistics(skill, output, case, data_source=None):
    if case == 'boxplot':
        rows = csv_rows(data_source or skill / 'examples/portable/boxplot/data.csv')
        groups = list(dict.fromkeys(row['Group'] for row in rows))
        expected = welch(*[[float(row['Expression']) for row in rows if row['Group'] == group] for group in groups])
        actual = csv_rows(output / '_audit/statistics.csv')[0]
        for key, value in expected.items():
            if not math.isclose(float(actual[key]), value, rel_tol=1e-9, abs_tol=1e-12):
                raise ValueError(f'Independent Welch disagreement: {key}')
        return {'method': 'Independent Python Welch, incomplete-beta P and bisection t interval', 'values': expected}
    if case == 'volcano':
        source = csv_rows(skill / 'examples/portable/volcano/data.csv')
        actual = csv_rows(output / '_audit/statistics.csv')
        if len(source) != 2000 or len(actual) != len(source):
            raise ValueError('Volcano must preserve all 2000 supplied feature IDs')
        p = [math.erfc(abs(float(row['log2FC']) / float(row['SE'])) / math.sqrt(2)) for row in source]
        order = sorted(range(len(p)), key=p.__getitem__)
        adjusted = [0.0] * len(p)
        running = 1.0
        for rank in range(len(p), 0, -1):
            index = order[rank - 1]
            running = min(running, p[index] * len(p) / rank)
            adjusted[index] = running
        for original, rendered, expected_p, expected_q in zip(source, actual, p, adjusted):
            if original['Gene'] != rendered['Gene']:
                raise ValueError('Volcano ID/order drift')
            for key, value in [('P', expected_p), ('FDR', expected_q)]:
                if not math.isclose(float(rendered[key]), value, rel_tol=1e-9, abs_tol=1e-14):
                    raise ValueError(f'Independent full-feature BH disagreement: {key}')
        return {'method': 'Independent erfc Wald probabilities and full-2000-feature monotone BH', 'features': len(p)}
    return {'method': 'Descriptive figure; no invented significance test'}


def verify_pdf(path, width_mm, height_mm, min_pt=6):
    import pymupdf
    with pymupdf.open(path) as doc:
        if len(doc) != 1:
            raise ValueError(f'Exactly one final PDF page required: {path}')
        page = doc[0]
        physical = [page.rect.width * 25.4 / 72, page.rect.height * 25.4 / 72]
        if any(abs(a - b) > 0.003 for a, b in zip(physical, [width_mm, height_mm])):
            raise ValueError(f'PDF physical size mismatch: {physical} vs {[width_mm, height_mm]}')
        fonts = page.get_fonts(full=True)
        if not fonts or any('arial' not in item[3].lower() for item in fonts):
            raise ValueError(f'PDF substituted a non-Arial font: {fonts}')
        for item in fonts:
            if item[0] <= 0 or not doc.extract_font(item[0])[3]:
                raise ValueError(f'PDF font is not embedded: {item[3]}')
        spans = [span for block in page.get_text('dict')['blocks'] if 'lines' in block
                 for line in block['lines'] for span in line['spans'] if span['text'].strip()]
        if not spans or min(span['size'] for span in spans) < min_pt - 0.05:
            raise ValueError('Missing or undersized PDF text')
        if any(span['bbox'][0] < -0.1 or span['bbox'][1] < -0.1 or span['bbox'][2] > page.rect.width + 0.1
               or span['bbox'][3] > page.rect.height + 0.1 for span in spans):
            raise ValueError('PDF text extends outside the page')
        preview = Path(path).parent / 'qa' / f'{Path(path).stem}-pdf-page-1.png'
        preview.parent.mkdir(exist_ok=True)
        page.get_pixmap(matrix=pymupdf.Matrix(2, 2), alpha=False).save(str(preview))
        return {'pages': 1, 'width_mm': physical[0], 'height_mm': physical[1],
                'font_names': sorted({item[3] for item in fonts}), 'all_fonts_embedded': True,
                'minimum_text_pt': min(span['size'] for span in spans),
                'inspection_preview': {'path': str(preview), 'sha256': sha(preview)}}


def verify_native_receipt(receipt):
    if receipt.get('status') != 'PASS' or receipt.get('backend') != 'R':
        raise ValueError('A successful current R native receipt is required')
    for check in ('font', 'text_allowlist', 'scientific_text_only', 'footer_free', 'layout', 'target_size'):
        if receipt.get('checks', {}).get(check) is not True:
            raise ValueError(f'Native technical gate did not pass: {check}')
    if not receipt.get('authorization_consumption', {}).get('consumed'):
        raise ValueError('Fresh one-use authorization was not consumed')
    consumption = receipt['authorization_consumption']
    for key in ('marker', 'authorization_file', 'preparation_receipt'):
        binding = consumption.get(key, {})
        path = Path(binding.get('path', ''))
        if not path.is_file() or binding.get('sha256') != sha(path):
            raise ValueError(f'Authorization evidence missing or changed: {key}')
    artifact = receipt.get('artifact', {})
    if not Path(artifact.get('path', '')).is_file() or artifact.get('sha256') != sha(artifact['path']):
        raise ValueError('Canonical PNG differs from native render receipt')
    for binding in receipt.get('sources', []):
        path = Path(binding['path'])
        if not path.is_file() or sha(path) != binding['sha256']:
            raise ValueError('Current renderer input/source binding drifted')


def verify_canonical_receipt(skill, receipt_path, png, spec, preparation):
    """Use the installed gate, including real authorization contents and text policy."""
    for path in (receipt_path, png, spec, preparation):
        if not Path(path).is_file():
            raise ValueError(f'Canonical validation input missing: {path}')
    script = skill / 'scripts/validate_checkpoints.py'
    module_spec = importlib.util.spec_from_file_location('biofigure_platform_current_gate', script)
    module = importlib.util.module_from_spec(module_spec)
    module_spec.loader.exec_module(module)
    errors = module.validate_render_receipt(str(receipt_path), Path(png), Path(spec), Path(preparation))
    if errors:
        raise ValueError('Canonical render-receipt validation failed: ' + '; '.join(errors))


def curate_artifacts(work, results):
    """Copy only inspected candidate assets and selected small technical records."""
    projects = (work / 'projects').resolve()
    target = work / 'inspection-artifacts'
    for result in results:
        cid = result['case']
        project = projects / cid
        candidates = list(result.get('artifacts', []))
        pdf = result.get('pdf')
        if isinstance(pdf, dict) and pdf.get('inspection_preview'):
            candidates.append(pdf['inspection_preview'])
        for item in candidates:
            path = Path(item['path']).resolve()
            if (not path.is_relative_to(projects) or path.suffix.lower() not in {'.png', '.pdf'}
                    or not path.is_file() or sha(path) != item['sha256']):
                raise ValueError('Only current hash-bound project PNG/PDF may be uploaded')
            destination = target / cid / path.name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, destination)
        for relative in ('_audit/design-spec.yaml', '_audit/preparation.json', '_audit/statistics.csv',
                         '_audit/cp2-validation.json', 'data/metadata/design-spec.yaml',
                         'data/metadata/preparation-receipt.json', 'work/preparation-receipt.json',
                         'work/visual-qa/preparation-receipt.json'):
            path = project / relative
            if path.is_file():
                destination = target / cid / 'technical' / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, destination)
        for artifact in result.get('artifacts', []):
            sidecar = Path(artifact['path'] + '.render.json')
            if sidecar.is_file() and sidecar.resolve().is_relative_to(projects):
                destination = target / cid / 'technical' / sidecar.name
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(sidecar, destination)


def verify_portable_output(skill, output, case, *, data_source=None, formats=('png', 'pdf')):
    analysis = load_json(output / '_audit/analysis.json')
    cp2 = load_json(output / '_audit/cp2-validation.json')
    receipt = load_json(output / f'{case}.png.render.json')
    if cp2.get('status') != 'PASS' or cp2.get('errors'):
        raise ValueError('Fresh CP2 did not pass')
    verify_canonical_receipt(skill, output / f'{case}.png.render.json', output / f'{case}.png',
                             output / '_audit/design-spec.yaml', output / '_audit/preparation.json')
    verify_native_receipt(receipt)
    if Path(receipt['artifact']['path']).resolve() != (output / f'{case}.png').resolve():
        raise ValueError('The canonical receipt points outside the requested candidate output')
    if case in ('heatmap', 'dense-heatmap'):
        sys.path.insert(0, str(skill / 'scripts'))
        import heatmap_geometry
        import yaml
        spec = yaml.safe_load((output / '_audit/design-spec.yaml').read_text(encoding='utf-8'))
        errors = heatmap_geometry.validate_cell_metrics(receipt['heatmap_cells'], spec)
        if errors or receipt['checks'].get('cell_geometry') is not True:
            raise ValueError('Physical heatmap-cell contract failed: ' + '; '.join(errors))
    if 'pdf' not in formats and (list(output.rglob('*.pdf')) or list(output.rglob('*.svg'))):
        raise ValueError('PNG-only request produced an unwanted PDF or SVG')
    return {'case': case, 'status': 'TECHNICAL_PASS', 'visual_review': 'NOT_RUN',
            'statistics': verify_statistics(skill, output, case, data_source=data_source),
            'pdf': verify_pdf(output / f'{case}.pdf', analysis['width_mm'], analysis['height_mm']) if 'pdf' in formats else 'NOT_REQUESTED',
            'artifacts': [{'path': str(output / f'{case}.{ext}'), 'sha256': sha(output / f'{case}.{ext}')} for ext in formats]}


def external_cases(skill, projects, logs, cwd, python, environment):
    source = projects / 'external-input.csv'
    rng = random.Random(61719)
    rows = [{'Sample': f'{group}-{i:02}', 'Group': group, 'Expression': f'{rng.gauss(mean, 0.9):.7f}'}
            for group, mean in [('01', 5.0), ('1', 6.7)] for i in range(12)]
    with source.open('w', newline='', encoding='utf-8') as handle:
        writer = csv.DictWriter(handle, fieldnames=['Sample', 'Group', 'Expression'])
        writer.writeheader()
        writer.writerows(rows)
    base = [python, skill / 'scripts/run_public_example.py', 'boxplot', '--input', source,
            '--experimental-unit', 'fish', '--independence', 'independent', '--value-unit', 'mg/L']
    results, errors = [], []
    for cid, formats in [('external-png', ['png']), ('external-pdf', ['png', 'pdf'])]:
        try:
            output = projects / cid
            execute([*base, '--output-dir', output, '--formats', *formats], cwd, logs / f'{cid}.json', env=environment)
            result = verify_portable_output(skill, output, 'boxplot', data_source=source, formats=formats)
            analysis = load_json(output / '_audit/analysis.json')
            if analysis.get('groups') != ['01', '1'] or analysis.get('value_unit') != 'mg/L':
                raise ValueError('External string group IDs or measurement units were changed')
            result['case'] = cid
            result['input'] = {'path': str(source), 'sha256': sha(source), 'groups': ['01', '1'], 'value_unit': 'mg/L'}
            results.append(result)
        except Exception as exc:
            errors.append(f'{cid}: {exc}')
    duplicate = projects / 'duplicate-input.csv'
    duplicate.write_bytes(source.read_bytes().replace(b'01-01,', b'01-00,', 1))
    negative = [('missing-unit', '--value-unit'), ('missing-experimental-unit', '--experimental-unit'),
                ('missing-independence', '--independence'), ('duplicate-id', None)]
    for cid, omit in negative:
        command = list(base)
        if omit:
            index = command.index(omit)
            del command[index:index + 2]
        else:
            command[command.index('--input') + 1] = duplicate
        output = projects / f'negative-{cid}'
        command += ['--output-dir', output]
        process = subprocess.run([str(v) for v in command], cwd=cwd, env=environment,
                                 text=True, encoding='utf-8', errors='replace', capture_output=True)
        write_json(logs / f'negative-{cid}.json', {'command': [str(v) for v in command], 'returncode': process.returncode,
                                                'stdout': process.stdout, 'stderr': process.stderr})
        if process.returncode == 0 or list(output.rglob('*authorization*.json')) or list(output.rglob('*.png')):
            errors.append(f'negative-{cid}: invalid design was not refused before authorization/render')
        else:
            results.append({'case': f'negative-{cid}', 'status': 'EXPECTED_REFUSAL', 'authorization_issued': False,
                            'visual_review': 'NOT_APPLICABLE'})
    return results, errors


def replay_preparation(output, receipt):
    binding = receipt.get('authorization_consumption', {}).get('preparation_receipt', {})
    value = binding.get('path')
    if not isinstance(value, str) or not value:
        raise ValueError('Native preparation receipt binding is missing')
    path = Path(value).expanduser()
    path = (path if path.is_absolute() else output / path).resolve()
    if not path.is_relative_to(output.resolve()):
        raise ValueError('Native preparation receipt is outside the candidate project')
    if not path.is_file() or binding.get('sha256') != sha(path):
        raise ValueError('Native preparation receipt is missing or changed')
    return path


def parse_case_libraries(options):
    result = {}
    for option in options or []:
        if '=' not in option:
            raise ValueError('--case-r-library requires CASE=PATH')
        case, value = option.split('=', 1)
        if case != 'ohca-microc':
            raise ValueError('--case-r-library supports only ohca-microc; other public entrypoints do not accept --r-library')
        if case in result:
            raise ValueError('duplicate --case-r-library for ' + case)
        path = Path(value).expanduser().resolve()
        if not value or not path.is_dir():
            raise ValueError('--case-r-library must identify an existing explicit R library')
        result[case] = path
    return result


def verify_replay_output(skill, output, case):
    receipts = list((output / 'work').rglob('*.png.render.json'))
    if len(receipts) != 1:
        raise ValueError(f'Exactly one fresh candidate native receipt required: {case}')
    receipt = load_json(receipts[0])
    preparation = replay_preparation(output, receipt)
    verify_canonical_receipt(skill, receipts[0], Path(receipt['artifact']['path']),
                             output / 'data/metadata/design-spec.yaml', preparation)
    verify_native_receipt(receipt)
    if not Path(receipt['artifact']['path']).resolve().is_relative_to(output.resolve()):
        raise ValueError('Replay native receipt points outside the candidate project')
    pdfs = list((output / 'results/figures').glob('*.pdf'))
    if len(pdfs) != 1:
        raise ValueError(f'Exactly one final candidate PDF required: {case}')
    target = receipt['target_size']
    pdf = verify_pdf(pdfs[0], target['width_mm'], target['height_mm'])
    cell_status = 'NOT_APPLICABLE'
    if case == 'oncoprint':
        import yaml
        sys.path.insert(0, str(skill / 'scripts'))
        import heatmap_geometry
        spec = yaml.safe_load((output / 'data/metadata/design-spec.yaml').read_text(encoding='utf-8'))
        issues = heatmap_geometry.validate_cell_metrics(receipt['heatmap_cells'], spec)
        if issues or receipt['checks'].get('cell_geometry') is not True:
            raise ValueError('OncoPrint physical square cells failed: ' + '; '.join(issues))
        cell_status = 'MEASURED_PASS'
    elif case == 'ohca-microc':
        cell_status = 'NOT_MEASURED_BY_THIS_CI; native contact raster; actual inspection still required'
    png = Path(receipt['artifact']['path'])
    return {'case': case, 'status': 'TECHNICAL_PASS', 'visual_review': 'NOT_RUN', 'pdf': pdf,
            'cell_geometry': cell_status, 'statistics': 'Published plotting tables; this replay does not repeat author inference.',
            'artifacts': [{'path': str(p), 'sha256': sha(p)} for p in (png, pdfs[0])]}


def run(work, include_replays=False, source_review_manifest=None, only_replays=False, replay_dependency_error=None, case_r_library=None):
    work = work.resolve()
    state = load_json(work / 'installation.json')
    previous = None
    if only_replays:
        prior = work / 'platform-smoke.original.json'
        if not prior.is_file():
            raise ValueError('--only-replays requires a completed original phase; no prior success is inferred')
        previous = load_json(prior)
        if previous.get('commit') != state['commit']:
            raise ValueError('Original phase commit differs from the current installation')
        include_replays = True
    if replay_dependency_error and not only_replays:
        raise ValueError('--replay-dependency-error requires --only-replays')
    skill, python = Path(state['skill_root']), Path(state['python'])
    case_libraries = parse_case_libraries(case_r_library)
    cwd = work / 'unrelated cwd 中文'
    logs, projects = work / 'logs', work / 'projects'
    logs.mkdir(exist_ok=True)
    projects.mkdir(exist_ok=True)
    environment = dict(os.environ, PYTHONDONTWRITEBYTECODE='1', PYTHON=str(python))
    results, errors = [], []
    runtime = {}
    try:
        r_version = execute(['Rscript', '--version'], cwd, logs / 'r-version.json', env=environment)
        version_output = r_version.stdout + r_version.stderr
        if not re.search(r'\b4\.6\.1\b', version_output):
            raise ValueError('This qualification requires the pinned R 4.6.1 runtime')
        runtime['R'] = version_output.strip()
        runtime['Python_packages'] = execute([python, '-m', 'pip', 'freeze'], cwd, logs / 'python-packages.json', env=environment).stdout.splitlines()
    except Exception as exc:
        errors.append(f'runtime: {exc}')
    for case in (() if only_replays else PORTABLE_CASES):
        output = projects / case
        try:
            execute([python, skill / 'scripts/run_public_example.py', case, '--output-dir', output],
                    cwd, logs / f'{case}.json', env=environment)
            results.append(verify_portable_output(skill, output, case))
        except Exception as exc:
            errors.append(f'{case}: {exc}')
    if not only_replays:
        external_results, external_errors = external_cases(skill, projects, logs, cwd, python, environment)
        results.extend(external_results)
        errors.extend(external_errors)
    if include_replays:
        if replay_dependency_error:
            errors.append('retained replays not executed: ' + replay_dependency_error)
        elif source_review_manifest is None:
            errors.append('--include-replays requires --source-review-manifest; no actual source inspection is fabricated')
        else:
            review = load_json(source_review_manifest)
            manifest = load_json(skill / 'public-cases.json')
            for case in manifest['cases']:
                if case['id'] in PORTABLE_CASES or case['status'] != 'runnable':
                    continue
                try:
                    cid = case['id']
                    profile = load_json(skill / f'examples/genomics-gallery-20261011/{cid}/data/metadata/public-replay.json')
                    binding = verify_source_review(skill, cid, profile['source_asset'], review)
                    output = projects / cid
                    command = [str(p).replace('{skill_root}', str(skill)).replace('{output_dir}', str(output)) for p in case['command']]
                    command[0] = str(python)
                    if cid in case_libraries:
                        command.extend(['--r-library', str(case_libraries[cid])])
                    execute(command, cwd, logs / f'{cid}.json', env=environment)
                    result = verify_replay_output(skill, output, cid)
                    result['source_review'] = binding
                    if cid in case_libraries:
                        result['explicit_case_r_library'] = str(case_libraries[cid])
                    results.append(result)
                except Exception as exc:
                    errors.append(f'{case["id"]}: {exc}')
    if tree_hashes(skill) != state['skill_snapshot']:
        errors.append('Skill installation was modified by example execution')
    if only_replays:
        summary = merge_phase_summary(previous, results, errors, state['commit'])
    else:
        summary = make_summary(results, errors, state['commit'])
        summary['requested_scope'] = 'portable-original-and-external' if not include_replays else 'portable-original-external-and-retained-replays'
        summary['phases'] = {'original': {'status': 'FAIL' if errors else 'TECHNICAL_PASS_PENDING_VISUAL_REVIEW',
                                           'case_ids': [row['case'] for row in results if row['case'] in PORTABLE_CASES or row['case'].startswith(('external-', 'negative-'))]},
                             'replays': {'status': 'INCLUDED_ABOVE' if include_replays else 'NOT_RUN',
                                         'reason': 'Separate specialist dependency installation follows the portable phase.'}}
    summary['runtime'] = runtime
    try:
        curate_artifacts(work, summary['results'])
    except Exception as exc:
        summary['errors'].append('artifact curation: ' + str(exc))
        summary['status'] = 'FAIL'
    if not only_replays:
        write_json(work / 'platform-smoke.original.json', summary)
    else:
        write_json(work / 'platform-smoke.replays.json', summary)
    write_json(work / 'platform-smoke.json', summary)
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action', required=True)
    p = sub.add_parser('prepare')
    p.add_argument('--repository-root', required=True, type=Path)
    p.add_argument('--work-root', required=True, type=Path)
    p.add_argument('--install-python-deps', action='store_true')
    p.add_argument('--write-github-env', action='store_true')
    p = sub.add_parser('run')
    p.add_argument('--work-root', required=True, type=Path)
    p.add_argument('--include-replays', action='store_true')
    p.add_argument('--source-review-manifest', type=Path)
    p.add_argument('--only-replays', '--skip-original', action='store_true', help='Run only retained replays and merge with this installation\'s existing original-phase evidence')
    p.add_argument('--replay-dependency-error', help='Record a failed specialist dependency installation without deleting successful original-phase evidence')
    p.add_argument('--case-r-library', action='append', metavar='CASE=PATH', help='Explicit existing library for ohca-microc only; forwarded to that entrypoint without changing other cases')
    args = vars(parser.parse_args())
    action = args.pop('action')
    try:
        if action == 'prepare':
            result = prepare(args.pop('repository_root'), args.pop('work_root'), **args)
        else:
            result = run(args.pop('work_root'), **args)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 1 if result.get('errors') else 0
    except Exception as exc:
        print(json.dumps({'status': 'FAIL', 'error': str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
