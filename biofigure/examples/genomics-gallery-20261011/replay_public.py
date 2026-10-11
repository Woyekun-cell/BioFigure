#!/usr/bin/env python3
"""Fresh gated replay of published plotting tables; archived results are immutable.

This entry supports dpm-bubbles, dpm-network, sankey and oncoprint. It does not
recover author raw objects or certify original-paper fidelity. Other cases have
their own documented replay entry. Install native R dependencies before running.
"""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import shutil
import subprocess
import sys
import yaml

HERE = Path(__file__).resolve().parent
SKILL = HERE.parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('case', choices=['dpm-bubbles', 'dpm-network', 'sankey', 'oncoprint'])
    parser.add_argument('--output-dir', required=True, type=Path)
    parser.add_argument('--rscript', default='Rscript')
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--source-view-confirmed', action='store_true', help='Declare that the current own reference PDF was actually viewed for this invocation.')
    args = parser.parse_args()
    if not args.source_view_confirmed:
        parser.error('View the current case reference PDF, then pass --source-view-confirmed; no source view is inferred from a template.')
    source = HERE / args.case
    root = args.output_dir.resolve()
    if root.exists() and any(root.iterdir()):
        parser.error('--output-dir must be new or empty; archived outputs are never overwritten')
    root.mkdir(parents=True, exist_ok=True)
    for relative in ['scripts', 'data', 'results/plot_data']:
        if (source / relative).is_dir():
            shutil.copytree(source / relative, root / relative)
    for relative in ['work', 'evidence', 'results/figures', 'results/tables']:
        (root / relative).mkdir(parents=True, exist_ok=True)
    meta = root / 'data/metadata'
    profile = json.loads((meta / 'public-replay.json').read_text())
    request = meta / 'request.yaml'
    receipt = root / 'work/preparation-receipt.json'
    env = dict(os.environ, BIOFIGURE_SKILL_ROOT=str(SKILL), PYTHONDONTWRITEBYTECODE='1')
    commands = []

    def run(command):
        commands.append(command)
        subprocess.run(command, check=True, env=env)

    run([sys.executable, str(SKILL / 'scripts/prepare_figure.py'), str(request), '--output', str(receipt)])
    preparation = json.loads(receipt.read_text())
    if preparation['status'] != 'PREFLIGHT_COMPLETE':
        raise RuntimeError('Fresh public preparation is incomplete; see work/preparation-receipt.json')
    mid = profile['method_id']
    adopted = next(item for item in preparation['learned_methods']['results'] if item['method_id'] == mid)
    spec = yaml.safe_load((meta / 'design-template.yaml').read_text())
    reference = spec['reference_evidence']
    reference['preparation_id'] = preparation['preparation_id']
    reference['preparation_request'] = preparation['request']
    binding = reference['learned_source_reference']
    binding['opened_source_asset']['original_size_viewed'] = args.source_view_confirmed
    binding['source_record_sha256'] = adopted['source_sha256']
    binding['read_hashes'] = adopted['current_read_hashes']
    asset = SKILL / binding['opened_source_asset']['path']
    binding['opened_source_asset']['sha256'] = sha(asset)
    spec['project_style_contract']['registry_path'] = str(meta / 'project-style.yaml')
    spec['project_style_contract']['registry_sha256'] = sha(meta / 'project-style.yaml')
    spec['design_target']['reference'] = str(asset)
    if 'statistics_plan' in spec and spec['statistics_plan'].get('source'):
        statistics_source = root / spec['statistics_plan']['source']['path']
        spec['statistics_plan']['source']['path'] = str(statistics_source)
        spec['statistics_plan']['source']['sha256'] = sha(statistics_source)
    if 'source_density_contract' in spec:
        spec['source_density_contract']['source_asset'] = {'path': str(asset), 'sha256': sha(asset)}
    spec_path = meta / 'design-spec.yaml'
    spec_path.write_text(yaml.safe_dump(spec, allow_unicode=True, sort_keys=False))
    run([sys.executable, str(SKILL / 'scripts/validate_design_spec.py'), str(spec_path), '--preparation-receipt', str(receipt)])
    if args.prepare_only:
        print('PUBLIC_CP2_READY', root)
        return
    renderer = root / profile['public_renderer']
    generated_tables = {'dpm_fig3e_recolored_layout.csv', 'sankey_native_strata.csv'}
    input_tables = [path for path in sorted((root / 'results/plot_data').glob('*.csv')) if path.name not in generated_tables]
    sources = [renderer, SKILL / 'scripts/figure_style.R', *input_tables]
    sources.extend(sorted((root / 'data/raw').glob('*.csv')) if (root / 'data/raw').exists() else [])
    sources.extend([meta / 'source-learning.json'])
    if (meta / 'label-plan.json').is_file():
        sources.append(meta / 'label-plan.json')
    authorization = root / 'work/authorization.json'
    command = [sys.executable, str(SKILL / 'scripts/authorize_render.py'), '--receipt', str(receipt), '--design-spec', str(spec_path), '--output', str(authorization)]
    for path in sources:
        command.extend(['--source', str(path)])
    run(command)
    run([args.rscript, str(renderer), str(root), str(root / 'work'), str(authorization)])
    if args.case == 'sankey':
        run([sys.executable, str(root / 'scripts/validate_inputs.py'), str(root)])
    elif args.case == 'oncoprint':
        run([sys.executable, str(root / 'scripts/audit_inputs.py'), str(root), '--check-only'])
    record = {'schema_version': 1, 'status': 'NATIVE_RENDER_EXECUTED_FINAL_REVIEW_REQUIRED',
              'scope': profile['scope'], 'method_id': mid, 'commands': commands,
              'new_input_qualification': 'NOT_VERIFIED', 'original_whole_figure_fidelity': 'NOT_VERIFIED',
              'final_review': 'Required independently for this invocation; no archived PASS inherited',
              'outputs': [{'path': str(path.relative_to(root)), 'sha256': sha(path)} for path in sorted((root / 'results/figures').glob('*.pdf'))],
              'generated_plot_tables': [{'path': str(path.relative_to(root)), 'sha256': sha(path)} for path in sorted((root / 'results/plot_data').glob('*.csv')) if path.name in generated_tables],
              'runtime_utc': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    (root / 'evidence/public-replay-execution.json').write_text(json.dumps(record, indent=2) + '\n')
    print('PUBLIC_NATIVE_RENDER_EXECUTED', root)


if __name__ == '__main__':
    main()
