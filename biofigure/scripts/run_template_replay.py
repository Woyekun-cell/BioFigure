#!/usr/bin/env python3
"""Replay a canonical fixture twice in work/, preserving the reviewed originals."""
from __future__ import annotations
import argparse
import importlib.util
import json
import shutil
import subprocess
import sys
import uuid
from pathlib import Path
import yaml
from PIL import Image
from prepare_figure import prepare
from reuse_templates import ROOT, INDEX, get_case, check_case, sha


def pixels(path):
    with Image.open(path) as im:
        rgb = im.convert('RGB')
        import hashlib
        return {'size': list(rgb.size), 'rgb_sha256': hashlib.sha256(rgb.tobytes()).hexdigest()}


def run(case_id, preparation_path, output, work_root=None):
    case = get_case(case_id)
    errors = check_case(case)
    if errors:
        raise ValueError('; '.join(errors))
    task_receipt = json.loads(Path(preparation_path).read_text())
    if not any(c['case_id'] == case_id for c in task_receipt.get('reusable_templates', {}).get('candidates', [])):
        raise ValueError('template is not a candidate for this preparation')
    verifier_path = ROOT / 'benchmark/library/topjournal/scripts/verify_simulation.py'
    module_spec = importlib.util.spec_from_file_location('locked_fixture_verifier', verifier_path)
    verifier = importlib.util.module_from_spec(module_spec)
    module_spec.loader.exec_module(verifier)
    verifier.check_environment()
    verifier.verify(case['issue'])
    base = ROOT / case['template_root']
    baseline = json.loads((ROOT / case['baseline']).read_text())
    work_root = Path(work_root or ROOT.parent / 'work/current/template-replay')
    work_root = work_root.resolve()
    if (ROOT.parent / 'work').resolve() not in work_root.parents and work_root != (ROOT.parent / 'work').resolve():
        raise ValueError('fixture replay work directory must be under project work/')
    workspace = work_root / (case_id + '-' + uuid.uuid4().hex[:10])
    staged_skill = workspace / 'biofigure'
    staged_base = staged_skill / 'benchmark/library/topjournal'
    staged_case = staged_base / base.name
    shutil.copytree(base, staged_case, ignore=shutil.ignore_patterns('render_runtime', 'render.log'))
    # The renderer locates scripts four parents above its case. Runtime APIs resolve
    # to the current skill; case data and all output writes stay in this mirror.
    (staged_skill / 'scripts').symlink_to(ROOT / 'scripts', target_is_directory=True)
    (staged_skill / 'static').symlink_to(ROOT / 'static', target_is_directory=True)
    shutil.copytree(base.parent / 'scripts', staged_base / 'scripts')
    request = yaml.safe_load((ROOT / case['request']).read_text())
    receipt = prepare(request, fixture_replay_case_id=case_id)
    metadata = staged_case / 'data/metadata'
    receipt_path = metadata / 'preparation-receipt.json'
    receipt_path.write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
    design_path = metadata / 'design-spec.yaml'
    design = yaml.safe_load(design_path.read_text())
    evidence = design['reference_evidence']
    evidence.update(preparation_id=receipt['preparation_id'], preparation_request=receipt['request'],
                    selected_method_case_id=receipt['selected_reference_candidates']['planner_selected'])
    design_path.write_text(yaml.safe_dump(design, allow_unicode=True, sort_keys=False))
    inputs = {86: ['pathways.csv'], 89: ['genes.csv'], 97: ['MAG_tree.nwk', 'arg_samples.csv', 'mag_abundance.csv'], 98: ['fungi.csv', 'prokaryotes.csv']}[case['issue']]
    sources = [staged_case / 'scripts/render.R', ROOT / 'scripts/figure_style.R', staged_base / 'scripts/render_simulation_common.R', *[staged_case / 'results/plot_data' / n for n in inputs]]
    if case['issue'] == 86:
        sources.append(metadata / 'node_colors.json')
    matches = []
    process_records = []
    def record(p):
        return {'path': str(p.resolve()), 'sha256': sha(p)}
    for iteration in range(2):
        authorization = workspace / f'authorization-{iteration}.json'
        cmd = [sys.executable, str(ROOT / 'scripts/authorize_render.py'), '--receipt', str(receipt_path), '--design-spec', str(design_path), '--output', str(authorization)]
        for source in sources:
            cmd += ['--source', str(source)]
        subprocess.run(cmd, check=True, capture_output=True, text=True)
        rendered = subprocess.Popen(['Rscript', '--vanilla', str(staged_case / 'scripts/render.R'), str(workspace), str(authorization)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        stdout, stderr = rendered.communicate()
        log = workspace / f'render-{iteration}.log'
        log.write_text(stdout + '\n' + stderr)
        if rendered.returncode:
            raise RuntimeError(f'fixture renderer failed; see {workspace / f"render-{iteration}.log"}')
        png = staged_case / 'evidence/reproduction.png'
        pdf = staged_case / 'results/figures/reproduction.pdf'
        preview = workspace / f'pdf-{iteration}'
        subprocess.run(['pdftoppm', '-r', '120', '-png', '-singlefile', str(pdf), str(preview)], check=True, capture_output=True)
        geometry = json.loads((staged_case / 'evidence/geometry-checks.json').read_text())
        match = pixels(png) == baseline['image'] and pixels(preview.with_suffix('.png')) == baseline['pdf_image'] and geometry == baseline['geometry']
        if not match:
            raise ValueError('fixed-fixture PNG/PDF pixels or semantic geometry differ; reviewed baseline was not changed')
        matches.append(True)
        iteration_files = {'png': png, 'pdf': pdf, 'geometry': staged_case / 'evidence/geometry-checks.json',
                           'render_receipt': staged_case / 'evidence/reproduction.png.render.json'}
        iteration_record = {'pid': rendered.pid, 'ordinal': iteration,
                            'authorization': record(authorization),
                            'consumption_marker': record(authorization.with_suffix('.json.consumed')),
                            'render_log': record(log), 'pdf_preview': record(preview.with_suffix('.png'))}
        for role, source in iteration_files.items():
            destination = workspace / f'{role}-{iteration}{source.suffix}'
            shutil.copy2(source, destination)
            iteration_record[role] = record(destination)
        process_records.append(iteration_record)
    # Complete binding includes canonical inputs, current execution APIs and fresh
    # rendered evidence. Replacing a renderer or deleting evidence invalidates CP2.
    bound = [INDEX, ROOT / case['baseline'], verifier_path, base.parent / 'metadata/simulation-environment-lock.json', ROOT / 'scripts/run_template_replay.py',
             ROOT / 'scripts/prepare_figure.py', ROOT / 'scripts/reuse_templates.py',
             ROOT / 'scripts/authorize_render.py', ROOT / 'scripts/validate_checkpoints.py',
             Path(preparation_path), receipt_path, design_path, *sources,
             staged_case / 'evidence/reproduction.png', staged_case / 'results/figures/reproduction.pdf',
             staged_case / 'evidence/geometry-checks.json', workspace / 'pdf-1.png']
    report = {'schema_version': 1, 'status': 'PASS', 'case_id': case_id,
              'for_preparation_id': task_receipt['preparation_id'], 'index_sha256': sha(INDEX),
              'independent_R_processes': len(matches), 'png_pixel_identical': True, 'pdf_raster_identical': True,
              'semantic_geometry_identical': True, 'environment_lock_checked': True,
              'process_records': process_records,
              'bound_files': [{'path': str(p.resolve()), 'sha256': sha(p)} for p in bound],
              'scope': case['scope'], 'original_case_unchanged': True, 'user_acceptance': 'pending'}
    Path(output).parent.mkdir(parents=True, exist_ok=True)
    Path(output).write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case-id', required=True)
    parser.add_argument('--preparation-receipt', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--work-root', type=Path)
    args = parser.parse_args()
    try:
        result = run(args.case_id, args.preparation_receipt, args.output, args.work_root)
        print(json.dumps({k: result[k] for k in ('case_id', 'status', 'independent_R_processes', 'png_pixel_identical', 'pdf_raster_identical')}))
        return 0
    except Exception as exc:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps({'status': 'REVISE', 'case_id': args.case_id, 'errors': [str(exc)]}, ensure_ascii=False, indent=2) + '\n')
        print(str(exc), file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
