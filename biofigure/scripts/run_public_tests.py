#!/usr/bin/env python3
"""Run explicit public, private-archive, or unfiltered test profiles.

Deferred archival tests are NOT_RUN, never counted as passed. Core validator,
scientific, render, typography and public-example tests remain in public.
"""
from __future__ import annotations
import argparse
import fnmatch
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'tests/archival-tests.json'


def flatten(suite):
    for item in suite:
        if isinstance(item, unittest.TestSuite):
            yield from flatten(item)
        else:
            yield item


def discover():
    return list(flatten(unittest.defaultTestLoader.discover(str(ROOT / 'tests'), pattern='test_*.py')))


def select_profile(tests, profile):
    if profile not in {'public', 'archive', 'all'}:
        raise ValueError('profile must be public, archive, or all')
    if profile == 'all':
        return list(tests), []
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    archival = manifest['archival_tests']
    if any(not row.get('pattern') or not row.get('reason') or not row.get('inputs') for row in archival):
        raise ValueError('Every archival test classification requires a reason and actual input paths')
    selected, deferred = [], []
    for test in tests:
        matches = [row for row in archival if fnmatch.fnmatchcase(test.id(), row['pattern'])]
        is_archive = bool(matches)
        if (profile == 'archive') == is_archive:
            selected.append(test)
        elif is_archive:
            deferred.append({'test': test.id(), 'status': 'NOT_RUN',
                             'reason': matches[0]['reason'], 'inputs': matches[0]['inputs']})
    return selected, deferred


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=('public', 'archive', 'all'), default='public')
    parser.add_argument('--report', type=Path)
    parser.add_argument('--list', action='store_true')
    args = parser.parse_args(argv)
    selected, deferred = select_profile(discover(), args.profile)
    if args.list:
        print(json.dumps({'profile': args.profile, 'selected_tests': [test.id() for test in selected],
                          'not_run_archival': deferred}, ensure_ascii=False, indent=2))
        return 0
    result = unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(selected))
    report = {'profile': args.profile, 'status': 'PASS' if result.wasSuccessful() else 'FAIL',
              'tests_run': result.testsRun,
              'tests_passed': result.testsRun - len(result.failures) - len(result.errors) - len(result.skipped),
              'failures': [{'test': test.id(), 'traceback': output} for test, output in result.failures],
              'errors': [{'test': test.id(), 'traceback': output} for test, output in result.errors],
              'skipped': [{'test': test.id(), 'reason': reason} for test, reason in result.skipped],
              'not_run_archival': deferred,
              'claim_boundary': 'Only this profile was executed. NOT_RUN archival tests do not certify source replay, transfer, or visual acceptance.'}
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: report[key] for key in ('profile', 'status', 'tests_run', 'tests_passed')}, ensure_ascii=False))
    print('Archival tests NOT_RUN: ' + str(len(deferred)))
    return 0 if result.wasSuccessful() else 1


if __name__ == '__main__':
    sys.exit(main())
