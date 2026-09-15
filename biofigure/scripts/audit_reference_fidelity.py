#!/usr/bin/env python3
"""Audit an evidence bundle, or report historical inventory without promoting it."""
import argparse
import json
from pathlib import Path
from benchmark_core import inventory, validate_bundle


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--bundle', type=Path)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    try:
        result = validate_bundle(json.loads(args.bundle.read_text()), args.root) if args.bundle else inventory(args.root)
    except (OSError, ValueError, TypeError, KeyError) as exc:
        result = {'status': 'FAIL', 'errors': [str(exc)]}
    payload = json.dumps(result, ensure_ascii=False, indent=2) + '\n'
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload)
    print(payload, end='')
    return int(bool(result.get('errors')))


if __name__ == '__main__':
    raise SystemExit(main())
