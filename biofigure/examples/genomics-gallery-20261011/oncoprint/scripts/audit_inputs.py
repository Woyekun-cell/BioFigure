#!/usr/bin/env python3
"""Independent synthetic raw-event/metadata to plotting-table audit.

Uses Python sets and lexicographic tuples independently of the R preparation.
The default writes one permanent QC record; --check-only is read-only.
"""
import argparse
import csv
import hashlib
import json
from collections import defaultdict
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('root', type=Path)
parser.add_argument('--check-only', action='store_true')
args = parser.parse_args()
root = args.root.resolve()
def read(relative):
    with (root / relative).open(newline='') as handle:
        return list(csv.DictReader(handle))
events = read('data/raw/simulated_events.csv')
metadata = read('data/raw/simulated_sample_metadata.csv')
matrix_path = root / 'results/plot_data/oncoprint_simulated_matrix.csv'
with matrix_path.open(newline='') as handle:
    reader = csv.DictReader(handle)
    matrix_header = reader.fieldnames
    matrix = list(reader)
sample_order = read('results/plot_data/oncoprint_simulated_sample_order.csv')
frequency = read('results/plot_data/oncoprint_simulated_gene_frequency.csv')
counts = read('results/plot_data/oncoprint_simulated_sample_counts.csv')
checks = {}
def check(name, condition):
    checks[name] = bool(condition)
    if not condition:
        raise AssertionError(name)
samples = [row['sample_id'] for row in metadata]
check('144_unique_synthetic_tumours', len(samples) == len(set(samples)) == 144)
check('all_sample_metadata_explicitly_simulated', all(row['simulation'] == 'TRUE' for row in metadata))
check('all_events_explicitly_simulated', all(row['simulated'] == 'TRUE' for row in events))
types = ('Missense', 'Frameshift', 'Nonsense', 'Splice', 'In_frame')
keys = [(row['sample_id'], row['gene'], row['event_type']) for row in events]
check('raw_event_keys_unique', len(keys) == len(set(keys)))
check('known_event_types_and_samples', all(t in types and s in samples for s, g, t in keys))
raw_sets = defaultdict(set)
for sample, gene, event in keys:
    raw_sets[gene, sample].add(event)
genes = {gene for sample, gene, event in keys}
check('12_unique_genes', len(genes) == len(matrix) == 12)
check('1728_cells_no_empty_tumour_filter', len(matrix_header[1:]) == 144 and set(matrix_header[1:]) == set(samples))
gene_rank = sorted(genes, key=lambda gene: (-sum(bool(raw_sets[gene, sample]) for sample in samples), gene))
check('raw_derived_frequency_gene_order', [row['gene'] for row in matrix] == gene_rank)
metadata_by_id = {row['sample_id']: row for row in metadata}
ordered_samples = sorted(samples, key=lambda sample: (
    metadata_by_id[sample]['cohort'],
    tuple(-int(bool(raw_sets[gene, sample])) for gene in gene_rank), sample))
check('raw_derived_binary_lexicographic_sample_order', matrix_header[1:] == ordered_samples)
check('cohort_counts_48_each', all(sum(row['cohort'] == group for row in metadata) == 48 for group in ('A', 'B', 'C')))
check('metadata_same_sample_order', [row['sample_id'] for row in sample_order] == ordered_samples)
check('metadata_contiguous_column_index', [int(row['column_index']) for row in sample_order] == list(range(1, 145)))
check('metadata_categories_preserved_by_key', all(
    all(row[field] == metadata_by_id[row['sample_id']][field] for field in ('cohort', 'sex', 'smoking'))
    for row in sample_order))
for row in matrix:
    for sample in ordered_samples:
        actual = row[sample].split(';') if row[sample] else []
        expected = [event for event in types if event in raw_sets[row['gene'], sample]]
        check('cell_' + row['gene'] + '_' + sample, actual == expected)
check('frequency_table_key_order', [row['gene'] for row in frequency] == gene_rank)
for index, row in enumerate(frequency, 1):
    numerator = sum(bool(raw_sets[row['gene'], sample]) for sample in samples)
    check('frequency_' + row['gene'], int(row['altered_tumours']) == numerator and
          int(row['assayed_tumours']) == 144 and int(row['row_index']) == index and
          abs(float(row['frequency_percent']) - 100 * numerator / 144) < 1e-10)
check('per_sample_count_order', [row['sample_id'] for row in counts] == ordered_samples)
for row in counts:
    sample = row['sample_id']
    check('count_' + sample, int(row['altered_genes']) == sum(bool(raw_sets[gene, sample]) for gene in genes) and
          int(row['distinct_events']) == sum(len(raw_sets[gene, sample]) for gene in genes))
nonempty = sum(bool(raw_sets[gene, sample]) for gene in genes for sample in samples)
multi = sum(len(raw_sets[gene, sample]) > 1 for gene in genes for sample in samples)
zero = sum(not any(raw_sets[gene, sample] for gene in genes) for sample in samples)
check('multi_event_and_zero_event_tumours_retained', multi > 0 and zero >= 9)
files = [p for p in (root / 'data/raw').glob('*.csv')] + [p for p in (root / 'results/plot_data').glob('*.csv')]
record = {'status': 'PASS', 'scope': 'Independent numeric and table audit of explicitly simulated inputs; not figure fidelity',
          'check_count': len(checks), 'counts': {'tumours': 144, 'genes': 12, 'cells': 1728, 'events': len(events),
          'altered_cells': nonempty, 'multi_event_cells': multi, 'zero_event_tumours': zero},
          'checks': checks, 'sha256': {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files)}}
if not args.check_only:
    (root / 'evidence/independent-input-audit.json').write_text(json.dumps(record, indent=2) + '\n', encoding="utf-8")
print(json.dumps({key: record[key] for key in ('status', 'check_count', 'counts')}))
