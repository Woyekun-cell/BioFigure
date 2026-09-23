#!/usr/bin/env python3
"""Describe CSV/TSV facts; semantic roles and chart choice remain contextual."""
from __future__ import annotations
import argparse
import csv
import hashlib
import io
import json
import math
from pathlib import Path
from statistics import median


def profile(path: Path, groups=(), unit=None, missing_tokens=()) -> dict:
    raw = path.read_bytes()
    delimiter = '\t' if path.suffix.lower() in {'.tsv', '.tab'} else ','
    if path.suffix.lower() not in {'.csv', '.tsv', '.tab'}:
        raise ValueError('supported input: CSV/TSV only; convert with provenance')
    records = list(csv.reader(io.StringIO(raw.decode('utf-8-sig')), delimiter=delimiter))
    if not records or not records[0]:
        raise ValueError('missing header')
    names = records[0]
    if any(not name.strip() for name in names) or len(set(names)) != len(names):
        raise ValueError('empty or duplicate column names')
    rows = records[1:]
    if not rows:
        raise ValueError('no data rows')
    if any(len(row) != len(names) for row in rows):
        raise ValueError('ragged table: row width differs from header')
    groups = list(dict.fromkeys(groups))
    for name in groups + ([unit] if unit else []):
        if name not in names:
            raise ValueError(f'unknown column: {name}')
    missing = {'', *missing_tokens}
    def absent(value):
        return value.strip() in missing
    columns = {}
    for index, name in enumerate(names):
        values = [row[index] for row in rows if not absent(row[index])]
        numbers, nonfinite, nonnumeric = [], 0, 0
        for value in values:
            try:
                number = float(value)
            except ValueError:
                nonnumeric += 1
                continue
            if math.isfinite(number):
                numbers.append(number)
            else:
                nonfinite += 1
        columns[name] = {
            'observed_type': ('empty' if not values else 'numeric' if not nonnumeric and not nonfinite
                              else 'nonfinite_numeric' if not nonnumeric else 'text_or_mixed'),
            'semantic_role': 'unresolved',
            'nonmissing_rows': len(values), 'missing_rows': len(rows)-len(values),
            'unique_nonmissing_values': len(set(values)),
            'finite_numeric_rows': len(numbers), 'nonfinite_numeric_rows': nonfinite,
            'nonnumeric_rows': nonnumeric,
            'finite_numeric_summary': ({'min': min(numbers), 'median': median(numbers),
                                        'max': max(numbers), 'zeros': numbers.count(0),
                                        'negative_rows': sum(x < 0 for x in numbers)} if numbers else None),
        }
    group_indices = [names.index(name) for name in groups]
    unit_index = names.index(unit) if unit else None
    buckets = {}
    for row in rows:
        key = tuple(None if absent(row[i]) else row[i] for i in group_indices)
        buckets.setdefault(key, []).append(row)
    group_facts = []
    for key, bucket in buckets.items():
        units = [row[unit_index] for row in bucket if not absent(row[unit_index])] if unit else []
        group_facts.append({
            'group': dict(zip(groups, key)), 'rows': len(bucket),
            'unique_declared_units': len(set(units)) if unit else None,
            'missing_unit_rows': len(bucket)-len(units) if unit else None,
            'extra_rows_per_unit_group_key': len(units)-len(set(units)) if unit else None,
        })
    return {
        'schema': 'biofigure.data-profile.v1',
        'source': {'path': str(path.resolve()), 'sha256': hashlib.sha256(raw).hexdigest(),
                   'delimiter': delimiter, 'encoding': 'utf-8-sig'},
        'rows': len(rows), 'columns': columns,
        'missing_tokens': sorted(missing),
        'duplicate_full_rows': len(rows)-len(set(map(tuple, rows))),
        'declared_unit_column': unit,
        'unique_declared_units_total': (len({row[unit_index] for row in rows
                                           if not absent(row[unit_index])}) if unit else None),
        'groups': group_facts,
        'limitations': [
            'Observed numeric type does not establish a continuous measurement; numeric IDs remain unresolved.',
            'Declared unit counts do not prove biological independence or valid pairing.',
            'Repeated unit/group keys may be time points, technical repeats, or duplicates; inspect the design.',
            'Only explicit missing tokens count as missing; other strings remain visible.',
            'No chart selection, statistical inference, or data cleaning is performed.',
        ],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path)
    parser.add_argument('--group', action='append', default=[])
    parser.add_argument('--unit')
    parser.add_argument('--missing-token', action='append', default=[])
    args = parser.parse_args()
    try:
        result = profile(args.input, args.group, args.unit, args.missing_token)
    except (ValueError, OSError, UnicodeError, csv.Error) as exc:
        parser.exit(2, f'profile error: {exc}\n')
    print(json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
