#!/usr/bin/env python3
"""Run a trusted local R script in a new directory and bind observable artifacts."""
import argparse
import json
import shutil
import subprocess
import time
from pathlib import Path
from benchmark_core import digest


def run(contract_path, script_path, output, inputs=(), timeout=180):
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    contract = json.loads(Path(contract_path).read_text())
    shutil.copy2(contract_path, output / 'contract.json')
    shutil.copy2(script_path, output / 'render.R')
    staged = []
    for source, target in inputs:
        target_path = (output / target).resolve()
        if not target_path.is_relative_to(output) or target_path.exists():
            raise ValueError('input destination escapes run or already exists')
        target_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target_path)
        staged.append(target_path)
    record = lambda path: {'path': str(path.relative_to(output)), 'sha256': digest(path)}
    # Fingerprints captured before execution; mutation during execution is rejected by audit.
    script_record = record(output / 'render.R')
    contract_record = record(output / 'contract.json')
    input_records = [record(p) for p in staged]
    started = time.monotonic()
    with (output / 'run.log').open('w') as log:
        try:
            proc = subprocess.run(['Rscript', '--vanilla', 'render.R'], cwd=output, stdout=log, stderr=subprocess.STDOUT, timeout=timeout)
            code = proc.returncode
        except subprocess.TimeoutExpired:
            code = 124
            log.write('\nbenchmark timeout\n')
    elapsed = time.monotonic() - started
    # Probe installed versions separately: it does not prove which function the renderer called.
    package_names = contract.get('packages', [])
    pkg_expr = ','.join(json.dumps(name) for name in package_names)
    probe = f'for(p in c({pkg_expr})) if(requireNamespace(p,quietly=TRUE)) cat(p,as.character(packageVersion(p)),sep="\\t",fill=TRUE); sessionInfo()'
    environment = subprocess.run(['Rscript', '--vanilla', '-e', probe], cwd=output, capture_output=True, text=True, timeout=60)
    (output / 'environment.txt').write_text(environment.stdout + environment.stderr)
    packages = {}
    for line in environment.stdout.splitlines():
        fields = line.split('\t')
        if len(fields) == 2 and fields[0] in package_names:
            packages[fields[0]] = fields[1].strip()
    artifacts = [record(p) for p in sorted((output / 'results').rglob('*')) if p.is_file()]
    receipt = {'runner': 'biofigure-benchmark-v2', 'fresh_directory': True, 'case_id': contract['case_id'],
               'contract': contract_record, 'script': script_record, 'inputs': input_records,
               'exit_code': code, 'elapsed_seconds': elapsed, 'log': record(output / 'run.log'),
               'environment': record(output / 'environment.txt'), 'packages': packages,
               'artifacts': artifacts, 'scientific_results': {},
               'generation_mode': 'existing-script-rerun', 'function_execution': 'not-instrumented'}
    (output / 'receipt.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
    return receipt


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--contract', required=True, type=Path)
    p.add_argument('--script', required=True, type=Path)
    p.add_argument('--output', required=True, type=Path)
    p.add_argument('--input', action='append', default=[], help='source=relative_destination')
    p.add_argument('--timeout', type=int, default=180)
    a = p.parse_args()
    result = run(a.contract, a.script, a.output, [x.split('=', 1) for x in a.input], a.timeout)
    print(json.dumps({'exit_code': result['exit_code'], 'elapsed_seconds': result['elapsed_seconds'], 'artifacts': len(result['artifacts'])}))
    raise SystemExit(result['exit_code'])
