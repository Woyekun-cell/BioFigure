#!/usr/bin/env python3
"""Independently audit raw feature counts against native alluvial plot tables."""
import argparse
import csv
import hashlib
import json
from collections import Counter
from pathlib import Path


def audit(root):
    files = [root / 'data/raw/sankey_features.csv',
             root / 'results/plot_data/sankey_paths.csv',
             root / 'results/plot_data/sankey_nodes.csv',
             root / 'results/plot_data/sankey_native_strata.csv']
    raw, paths, nodes, strata = [list(csv.DictReader(p.open())) for p in files]
    stages = ['DNA_copy_number', 'RNA_expression', 'Protein_abundance']
    states = {'Low', 'Neutral', 'High'}
    checks = 0

    def check(ok, message):
        nonlocal checks
        checks += 1
        if not ok:
            raise ValueError(message)

    check(len(raw) == 1800, 'feature denominator')
    check(len({r['feature_id'] for r in raw}) == len(raw), 'duplicate feature IDs')
    for row in raw:
        for stage in stages:
            check(row[stage] in states, 'unknown or missing state')
    expected_paths = Counter(tuple(r[s] for s in stages) for r in raw)
    observed_paths = {tuple(r[s] for s in stages): int(r['n_features']) for r in paths}
    check(len(paths) == len(observed_paths) == 27, 'duplicate or missing path')
    for key, value in expected_paths.items():
        check(observed_paths.get(key) == value, f'path volume: {key}')
    check(sum(observed_paths.values()) == len(raw), 'complete path denominator')
    check(len(nodes) == len(strata) == 9, 'stratum count')
    for stage in stages:
        marginal = Counter(r[stage] for r in raw)
        stage_nodes = {r['state']: int(r['n_features']) for r in nodes if r['stage'] == stage}
        check(dict(marginal) == stage_nodes, f'node marginals: {stage}')
        stage_strata = sorted((r for r in strata if r['stage'] == stage), key=lambda r: float(r['ymin']))
        check([r['state'] for r in stage_strata] == ['Low', 'Neutral', 'High'], 'native stack order')
        last = 0.0
        for r in stage_strata:
            lower, upper, center = map(float, [r['ymin'], r['ymax'], r['y']])
            check(lower == last, 'native stack gap or overlap')
            check(upper - lower == marginal[r['state']] == int(r['count']), 'native stratum height')
            check(center == (lower + upper) / 2, 'native label center')
            check(r['count_label'] == f"n = {marginal[r['state']]}", 'direct count label')
            last = upper
        check(last == len(raw), 'shared vertical denominator')
    return {'status': 'PASS', 'checks': checks, 'features': len(raw), 'paths': len(paths),
            'strata': len(strata), 'scope': 'explicit simulated data, descriptive counts only',
            'inputs': [{'path': str(p.relative_to(root)),
                        'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in files]}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = audit(args.root)
    payload = json.dumps(result, indent=2) + '\n'
    if args.output:
        args.output.write_text(payload)
    print(json.dumps({k: v for k, v in result.items() if k != 'inputs'}))
