#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Generate the seven BioFigure-owned synthetic public inputs, using fixed seeds."""
from pathlib import Path
import argparse
import csv
import hashlib
import json
import math
import random

CASES = ('boxplot', 'heatmap', 'dense-heatmap', 'bubble', 'volcano', 'synteny', 'phylogeny')


def generate(output_root):
    output_root = Path(output_root)
    for index, case in enumerate(CASES):
        seed = 2026101600 + index
        rng = random.Random(seed)
        folder = output_root / case
        folder.mkdir(parents=True, exist_ok=True)
        metadata = {'schema_version': 1, 'case_id': case, 'synthetic': True, 'seed': seed,
                    'independence': 'not_applicable', 'experimental_unit': 'synthetic entity',
                    'comparison': None, 'limitations': ['Entirely synthetic; no species, mechanism, pathway activity or biological conclusion is established.']}
        if case == 'boxplot':
            header = ['Sample', 'Group', 'Expression']
            rows = [[f'{group[0]}{i + 1:02d}', group, round(rng.gauss(mean, 0.8), 6)]
                    for group, mean in [('Control', 5.0), ('Treatment', 6.3)] for i in range(12)]
            metadata.update(experimental_unit='independent synthetic biological sample', independence='independent',
                            groups=['Control', 'Treatment'], sample_counts={'Control': 12, 'Treatment': 12},
                            comparison='Treatment - Control', units='arbitrary units',
                            generation='Independent Gaussian draws: Control mean 5.0, Treatment mean 6.3, SD 0.8.',
                            technical_replicates='none', statistics='Two-sided Welch two-sample t-test; one prespecified comparison.')
        elif case in ('heatmap', 'dense-heatmap'):
            n_genes, n_samples = (24, 12) if case == 'heatmap' else (5000, 20)
            header = ['Gene'] + [f'S{i + 1:02d}' for i in range(n_samples)]
            rows = []
            for gene in range(n_genes):
                module = gene % 3
                values = [round(1.3 * math.sin((sample / n_samples) * 2 * math.pi + module * 2.1) + rng.gauss(0, .3), 6)
                          for sample in range(n_samples)]
                rows.append([f'Gene_{gene + 1:03d}'] + values)
            metadata.update(experimental_unit='synthetic sample', rows=n_genes, columns=n_samples,
                            groups=['Control', 'Low', 'High', 'Recovery'], sample_groups={name: ['Control', 'Low', 'High', 'Recovery'][i // (n_samples // 4)] for i, name in enumerate(header[1:])},
                            units='synthetic standardized expression', generation='Three sine-pattern modules plus independent Gaussian noise SD 0.3.',
                            displayed_matrix={'rows': n_genes, 'columns': n_samples}, statistics='Descriptive expression pattern only; no differential inference.')
        elif case == 'bubble':
            header = ['Gene', 'Group', 'Average', 'Fraction']
            rows = [[f'Gene_{gene + 1:02d}', f'Type_{group + 1}', round(-1.5 + 3.0 * (gene % 4 == group) + rng.uniform(-.3, .3), 6),
                     round(20 + 65 * (gene % 4 == group) + 10 * rng.random(), 6)]
                    for gene in range(12) for group in range(4)]
            metadata.update(experimental_unit='synthetic group summary', groups=[f'Type_{i + 1}' for i in range(4)],
                            units={'Average': 'arbitrary units', 'Fraction': 'percentage from 0 to 100'},
                            generation='Deterministic marker preference plus uniform noise; summaries are not reconstructed cell-level measurements.',
                            statistics='Descriptive summaries only; cell fractions do not establish cell abundance.')
        elif case == 'volcano':
            header = ['Gene', 'log2FC', 'SE']
            rows = [[f'Gene_{i + 1:04d}', round(rng.gauss((-1.9 if i < 100 else 1.9 if i < 200 else 0), .55), 6), round(.22 + .25 * rng.random(), 6)] for i in range(2000)]
            metadata.update(experimental_unit='synthetic model estimate; no raw biological samples provided',
                            comparison='Treatment - Control', units={'log2FC': 'log2 ratio Treatment / Control', 'SE': 'model standard error of log2FC'},
                            generation='200 shifted and 1800 null-like Gaussian effect estimates, independent positive uniform standard errors.',
                            statistics='Two-sided normal Wald p values from log2FC/SE, BH adjustment over all 2000 features; simulated model outputs only.',
                            thresholds={'absolute_log2FC': 1, 'BH_q': .05})
        elif case == 'synteny':
            header = ['AChr', 'AStart', 'AEnd', 'BChr', 'BStart', 'BEnd', 'ALength', 'BLength']
            rows = []
            for chromosome in range(6):
                for block in range(12):
                    a = 4_000_000 + block * 7_500_000
                    b = 5_000_000 + ((block * 5) % 12 if chromosome else block) * 7_500_000
                    rows.append([f'A_chr{chromosome + 1}', a, a + 5_000_000, f'B_chr{chromosome + 1}', b, b + 5_000_000, 100_000_000, 100_000_000])
            metadata.update(experimental_unit='synthetic genome pair', units='base pairs; 0-based half-open intervals',
                            generation='72 explicitly paired coordinate blocks on six 100 Mb chromosomes per genome.',
                            statistics='Coordinate relationships only; no sequence alignment or rearrangement inference.',
                            assemblies={'A': 'synthetic-A-v1', 'B': 'synthetic-B-v1'})
        else:
            header = ['Newick']
            rows = [['((((Taxon_A:0.12,Taxon_B:0.16):0.18,(Taxon_C:0.14,Taxon_D:0.20):0.12):0.20,(Taxon_E:0.16,Taxon_F:0.13):0.22):0.18,(((Taxon_G:0.18,Taxon_H:0.17):0.14,(Taxon_I:0.15,Taxon_J:0.19):0.16):0.18,(Taxon_K:0.16,Taxon_L:0.13):0.22):0.20);']]
            metadata.update(experimental_unit='synthetic taxon', units='arbitrary units; synthetic branch lengths',
                            generation='Hand-constructed bifurcating 12-tip Newick tree; no alignment or tree estimation.',
                            statistics='Topology and branch lengths are input values; support is not provided.',
                            tip_groups={f'Taxon_{letter}': 'Clade 1' if letter < 'G' else 'Clade 2' for letter in 'ABCDEFGHIJKL'})
        target = folder / 'data.csv'
        with target.open('w', newline='') as handle:
            writer = csv.writer(handle, lineterminator='\n')
            writer.writerow(header)
            writer.writerows(rows)
        provenance = {'schema_version': 1, 'case_id': case, 'origin': 'BioFigure-owned synthetic data', 'creator': 'BioFigure contributors',
                      'license': 'MIT', 'synthetic': True, 'seed': seed, 'generator': 'examples/portable/generate_inputs.py',
                      'input_sha256': hashlib.sha256(target.read_bytes()).hexdigest(), 'third_party_materials': [],
                      'scope': 'First-party demonstration input; rendering does not imply scientific or visual acceptance.'}
        (folder / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')
        (folder / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-root', type=Path, default=Path(__file__).resolve().parent)
    generate(parser.parse_args().output_root)
