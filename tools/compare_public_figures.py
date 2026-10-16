"""Bounded raster regression checks; never substitute for actual visual inspection."""
from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter

CASES = ('boxplot', 'heatmap', 'dense-heatmap', 'bubble', 'volcano', 'synteny', 'phylogeny')


def count(mask):
    return sum(mask.histogram()[1:])


def ink(image):
    r, g, b = image.split()
    return ImageChops.darker(ImageChops.darker(r, g), b).point(lambda x: 255 if x < 242 else 0)


def palette(image):
    # Chromatic pixels only: differences in glyph antialiasing do not alter palettes.
    bins = Counter()
    for r, g, b in image.get_flattened_data():
        if max(r, g, b) - min(r, g, b) >= 25 and min(r, g, b) < 225:
            bins[(r // 32, g // 32, b // 32)] += 1
    total = sum(bins.values())
    return {key: value / total for key, value in bins.items()} if total else {}


def compare(reference: Path, candidate: Path):
    with Image.open(reference) as opened:
        a = opened.convert('RGB')
    with Image.open(candidate) as opened:
        b = opened.convert('RGB')
    errors = []
    if abs((a.width / a.height) / (b.width / b.height) - 1) > .006:
        errors.append('physical aspect ratio changed')
    # Normalize only raster sampling, not layout/aspect; permit at most rounding above.
    size = (min(a.width, 1000), round(a.height * min(a.width, 1000) / a.width))
    a = a.resize(size, Image.Resampling.LANCZOS)
    b = b.resize(size, Image.Resampling.LANCZOS)
    ma, mb = ink(a), ink(b)
    if not count(ma) or not count(mb):
        return {'status': 'FAIL', 'errors': errors + ['empty figure or reference']}
    da, db = ma.filter(ImageFilter.MaxFilter(5)), mb.filter(ImageFilter.MaxFilter(5))
    reference_coverage = count(ImageChops.multiply(ma, db)) / count(ma)
    candidate_coverage = count(ImageChops.multiply(mb, da)) / count(mb)
    if min(reference_coverage, candidate_coverage) < .90:
        errors.append('foreground position/coverage changed')
    # Local check prevents a mostly white canvas masking a missing small legend.
    local = []
    for y in range(0, size[1], max(1, size[1] // 8)):
        for x in range(0, size[0], max(1, size[0] // 6)):
            rect = (x, y, min(size[0], x + max(1, size[0] // 6)), min(size[1], y + max(1, size[1] // 8)))
            aa, bb = ma.crop(rect), db.crop(rect)
            if count(aa) >= 40:
                local.append(count(ImageChops.multiply(aa, bb)) / count(aa))
    if local and min(local) < .65:
        errors.append('a local plot/label/legend region is missing or displaced')
    pa, pb = palette(a), palette(b)
    overlap = sum(min(value, pb.get(key, 0)) for key, value in pa.items())
    if pa and overlap < .85:
        errors.append('chromatic palette/area distribution changed')
    return {'status': 'FAIL' if errors else 'PASS', 'errors': errors,
            'reference_coverage': reference_coverage, 'candidate_coverage': candidate_coverage,
            'minimum_local_coverage': min(local) if local else None, 'palette_overlap': overlap,
            'reference': str(reference), 'candidate': str(candidate)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference-root', type=Path, required=True)
    parser.add_argument('--candidate-root', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    results = {}
    for case in CASES:
        reference = args.reference_root / case / 'figures' / f'{case}.png'
        candidates = sorted((args.candidate_root / case).rglob(f'{case}.png'))
        if not reference.is_file() or len(candidates) != 1:
            results[case] = {'status': 'FAIL', 'errors': ['expected exactly one reference and candidate PNG']}
        else:
            results[case] = compare(reference, candidates[0])
    report = {'schema_version': 1, 'status': 'PASS' if all(r['status'] == 'PASS' for r in results.values()) else 'FAIL',
              'scope': 'bounded raster regression only', 'visual_inspection': 'NOT_RUN',
              'checkpoint_pass_inferred': False, 'cases': results}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(json.dumps({'status': report['status'], 'report': str(args.report)}))
    return int(report['status'] != 'PASS')


if __name__ == '__main__':
    raise SystemExit(main())
