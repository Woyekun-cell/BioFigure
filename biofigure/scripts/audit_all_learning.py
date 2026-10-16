#!/usr/bin/env python3
"""Audit all learned sources and gates; do not infer rendering mastery from inventory."""
from __future__ import annotations
import argparse
import ast
import csv
import json
import subprocess
import tempfile
import warnings
from collections import Counter
from pathlib import Path
from retrieve_learned_methods import ROOT, INDEX, retrieve, sha
from build_learned_method_index import build
from learning_materials import portable


def audit(parse_code=False, work_root=None):
    index = json.loads(INDEX.read_text(encoding='utf-8'))
    rows, errors = [], []
    files = set()
    for entry in index['entries']:
        current = retrieve('', case_id=entry['method_id'])['results'][0]
        problems = current['missing_material'] + current['changed_bound_material']
        if current['source_record_changed']:
            problems.append(current['source_record'])
        errors.extend(entry['method_id'] + ':' + p for p in problems)
        files.update(current['mandatory_read_set'])
        rows.append({'method_id': entry['method_id'], 'collection': entry['collection'],
                     'title': entry['title'], 'source_record': entry['source_record'],
                     'source_record_sha256': entry['source_sha256'],
                     'retrieval_and_locked_material': 'PASS' if not problems else 'FAIL',
                     'mandatory_read_set': current['mandatory_read_set'],
                     'unresolved_historical_material': entry['material_binding']['unresolved'],
                     'original_hash_mismatches': entry['material_binding']['hash_mismatches'],
                     'declared_code_gap': entry['learned_contract'].get('source_code_gap'),
                     'external_visual_sources': entry['learned_contract'].get('external_visual_sources', []),
                     'transfer': entry['transfer_status'], 'stress': entry['stress_status'],
                     'qualified_reuse': current['qualified_reuse'],
                     'mastery': current['qualified_reuse']['status'],
                     'required_evidence': ['new-input-field-and-unit-mapping', 'input-driven-dimensions-and-key-alignment',
                                           'all-required-structures', 'long-labels-multiple-groups-missing-extreme-values',
                                           'shuffled-metadata-key-test', 'two-independent-runs', 'final-size-visual-review']})
    if build() != index:
        errors.append('derived index differs from current source compiler')
    syntax = []
    if parse_code:
        if work_root is None:
            raise ValueError('--work-root required for temporary syntax checks')
        work_root = Path(work_root).resolve()
        if not work_root.is_relative_to((ROOT.parent / 'work').resolve()):
            raise ValueError('temporary code audit must stay in project work/')
        work_root.mkdir(parents=True, exist_ok=True)
        r_files = sorted((ROOT / p).resolve() for p in files if Path(p).suffix.lower() == '.r')
        with tempfile.TemporaryDirectory(dir=work_root) as temp:
            listing, output = Path(temp) / 'files.txt', Path(temp) / 'syntax.tsv'
            listing.write_text('\n'.join(str(p) for p in r_files) + '\n', encoding='utf-8')
            code = ('a<-commandArgs(TRUE); z<-lapply(readLines(a[1]),function(p)tryCatch({parse(file=p);c(p,"PASS","")},'
                    'error=function(e)c(p,"FAIL",gsub("[\\t\\r\\n]+"," ",conditionMessage(e)))));'
                    'write.table(do.call(rbind,z),a[2],sep="\\t",quote=FALSE,row.names=FALSE,col.names=FALSE)')
            subprocess.run(['Rscript', '-e', code, str(listing), str(output)], check=True, capture_output=True, text=True, encoding='utf-8', errors='replace')
            for path, status, message in csv.reader(output.open(), delimiter='\t'):
                import os
                syntax.append({'path': os.path.relpath(path, ROOT), 'sha256': sha(Path(path)),
                               'language': 'R', 'status': status, 'error': portable(message)})
        for relative in sorted(files):
            path = ROOT / relative
            if path.suffix.lower() != '.py':
                continue
            try:
                with warnings.catch_warnings():
                    warnings.simplefilter('ignore', SyntaxWarning)
                    ast.parse(path.read_text(encoding='utf-8-sig'))
                status, message = 'PASS', ''
            except (SyntaxError, UnicodeError) as exc:
                status, message = 'FAIL', str(exc)
            syntax.append({'path': relative, 'sha256': sha(path), 'language': 'Python', 'status': status, 'error': portable(message)})
    return {'schema_version': 1, 'scope': 'all persisted learned source/method/panel/layout records; counts are not figure mastery',
            'index_sha256': sha(INDEX), 'coverage': index['coverage'], 'record_count': len(rows),
            'unique_required_files': len(files), 'retrieval_and_binding_status': 'PASS' if not errors else 'FAIL',
            'errors': errors, 'syntax_scope': 'parse/AST only; source scripts are not executed',
            'syntax_summary': dict(Counter(r['language'] + ':' + r['status'] for r in syntax)),
            'qualified_method_reuse': sum(r['mastery'] == 'PASS' for r in rows),
            'all_library_mastery': 'PASS' if all(r['mastery'] == 'PASS' for r in rows) else 'NOT_VERIFIED',
            'fixed_fixture_repeatability_is_separate': True, 'records': rows, 'syntax': syntax}


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', required=True, type=Path)
    p.add_argument('--parse-code', action='store_true')
    p.add_argument('--work-root', type=Path)
    args = p.parse_args()
    result = audit(args.parse_code, args.work_root)
    if args.parse_code:
        (ROOT / 'atlas/source-syntax-audit.json').write_text(json.dumps({'schema_version': 1, 'scope': 'syntax only; not runtime',
             'files': result['syntax']}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in result.items() if k not in ('records', 'syntax')}, ensure_ascii=False))
