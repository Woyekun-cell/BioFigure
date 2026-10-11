#!/usr/bin/env python3
"""Repeat compact discovery timing/output checks against a preserved baseline."""
import argparse
import hashlib
import json
import platform
import statistics
import subprocess
import sys
import time
from pathlib import Path

from find_figure_reference import ROOT, find, load_catalog


def run():
    project = ROOT.parent
    baseline_path = project / 'results/tables/reference-search-baseline-2026-10-11.json'
    baseline = json.loads(baseline_path.read_text())
    catalog = load_catalog(refresh=True)
    rows = []
    for old in baseline['rows']:
        query = old['query']
        times = []
        for _ in range(5):
            start = time.perf_counter()
            result = find(query)
            times.append(time.perf_counter() - start)
        start = time.perf_counter()
        cold = subprocess.run([sys.executable, str(ROOT / 'scripts/find_figure_reference.py'),
                               '--query', query], capture_output=True, text=True, check=False)
        cold_time = time.perf_counter() - start
        if cold.returncode not in (0, 1):
            raise RuntimeError(cold.stderr)
        if json.loads(cold.stdout)['results'] != result['results']:
            raise ValueError('cold/warm candidate disagreement: ' + query)
        chars = len(json.dumps(result, ensure_ascii=False))
        rows.append({'query': query, 'before_ids': old['ids'],
            'after_ids': [x['method_id'] for x in result['results']],
            'before_output_chars': old['output_chars'], 'after_output_chars': chars,
            'output_reduction_fraction': 1 - chars / old['output_chars'],
            'before_seconds_without_qualification': old['seconds_without_qualification'],
            'after_warm_median_seconds': statistics.median(times),
            'after_cold_seconds': cold_time})
    return {'schema_version': 1, 'date': '2026-10-11', 'python': platform.python_version(),
        'platform': platform.platform(), 'index_sha256': catalog['source_index_sha256'],
        'generator_sha256': catalog['generator_sha256'],
        'classifier_sha256': catalog.get('classifier_sha256'),
        'cli_sha256': catalog.get('cli_sha256'),
        'baseline_sha256': hashlib.sha256(baseline_path.read_bytes()).hexdigest(),
        'records': len(catalog['cards']),
        'full_index_bytes': (ROOT / 'atlas/learned-method-index.json').stat().st_size,
        'compact_catalog_bytes': (ROOT / 'atlas/figure-reference-catalog.json').stat().st_size,
        'median_output_reduction_fraction': statistics.median(x['output_reduction_fraction'] for x in rows),
        'median_warm_seconds': statistics.median(x['after_warm_median_seconds'] for x in rows),
        'median_cold_seconds': statistics.median(x['after_cold_seconds'] for x in rows),
        'rows': rows,
        'boundary': 'Discovery benchmark only. Before timing excludes qualification; after performs metadata discovery. These measure different stages, not end-to-end speedup. Rank relevance is checked separately; images/new-data rendering are not certified.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path,
        default=ROOT.parent / 'results/tables/reference-search-validation-2026-10-11.json')
    args = parser.parse_args()
    report = run()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: report[k] for k in ('records', 'full_index_bytes', 'compact_catalog_bytes',
        'median_output_reduction_fraction', 'median_warm_seconds', 'median_cold_seconds')}, indent=2))
