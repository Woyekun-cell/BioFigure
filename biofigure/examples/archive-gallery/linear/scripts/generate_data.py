#!/usr/bin/env python3
"""Create illustrative independent x-y observations; no experimental meaning."""
import csv
import random
from pathlib import Path

SEED = 20260919
OUTPUT = Path(__file__).resolve().parents[1] / 'results/plot_data/linear_scatter.csv'
random_generator = random.Random(SEED)
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
with OUTPUT.open('w', encoding='utf-8', newline='') as output:
    writer = csv.writer(output)
    writer.writerow(['observation_id', 'x', 'y'])
    for i in range(320):
        x = round(random_generator.uniform(0.4, 9.6), 3)
        y = round(1.8 + 0.68 * x + random_generator.gauss(0, 1.15), 3)
        writer.writerow([f'S{i + 1:02d}', x, y])
