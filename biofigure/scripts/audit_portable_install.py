#!/usr/bin/env python3
"""Audit the shipped Skill and every declared public executable case.

This verifies file/rights declarations, hashes, containment and a Skill-only
copy. It does not execute R, install dependencies, infer legal permission from
an unknown license, or award scientific/source/visual qualification.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import tempfile
from collections import Counter
from pathlib import Path, PurePosixPath


EXCLUDED = {'.git', '__pycache__', '.pytest_cache', 'work', 'cache'}
TEXT_SUFFIXES = {'.py', '.r', '.rmd', '.md', '.txt', '.json', '.yaml', '.yml',
                 '.csv', '.tsv', '.sh', '.toml', '.ini', '.cfg', '.xml', '.html'}
MACHINE_PREFIXES = ('/' + 'Users/', '/' + 'home/', '/var/' + 'folders/')
SECRET_PATTERNS = (re.compile(r'gh[pousr]_[A-Za-z0-9]{30,}'),
                   re.compile(r'sk-' + r'[A-Za-z0-9_-]{30,}'),
                   re.compile(r'-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----'))
SHA = re.compile(r'^[0-9a-f]{64}$')
LICENSES = {'MIT', 'Apache-2.0', 'BSD-2-Clause', 'BSD-3-Clause', 'CC0-1.0',
            'CC-BY-4.0', 'GPL-2.0-only', 'GPL-2.0-or-later', 'GPL-3.0-only',
            'GPL-3.0-or-later', 'LGPL-3.0-only', 'LGPL-3.0-or-later',
            'Artistic-2.0', 'MPL-2.0'}
PARENT_RUNTIME = re.compile(r'\b(?:SKILL|skill|bf)\.parent\s*/')


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def file_inside(root: Path, value, errors: list[str], label: str) -> Path | None:
    if not isinstance(value, str) or not value:
        errors.append(f'{label}: missing-path')
        return None
    relative = PurePosixPath(value)
    if relative.is_absolute() or '..' in relative.parts or '\\' in value or ':' in value:
        errors.append(f'{label}: path-escape {value!r}')
        return None
    if any(part in EXCLUDED for part in relative.parts):
        errors.append(f'{label}: excluded-runtime-path {value!r}')
        return None
    path = root / value
    if not path.resolve().is_relative_to(root.resolve()):
        errors.append(f'{label}: symlink-escape {value!r}')
        return None
    if not path.is_file():
        errors.append(f'{label}: missing-file {value!r}')
        return None
    return path


def resolved_license(value) -> bool:
    return isinstance(value, str) and value in LICENSES


def scan_distribution(root: Path, errors: list[str]) -> dict:
    inventory, text_count = [], 0
    for path in sorted(root.rglob('*')):
        relative = path.relative_to(root)
        if any(part in EXCLUDED for part in relative.parts) or path.name == '.DS_Store':
            continue
        if path.is_symlink() and not path.resolve().is_relative_to(root.resolve()):
            errors.append(f'distribution: symlink-escape {relative}')
            continue
        if not path.is_file():
            continue
        inventory.append({'path': relative.as_posix(), 'bytes': path.stat().st_size,
                          'sha256': digest(path)})
        if path.suffix.lower() not in TEXT_SUFFIXES and path.name not in {'LICENSE', 'NOTICE'}:
            continue
        try:
            text = path.read_text(encoding='utf-8')
        except (UnicodeError, OSError):
            continue
        text_count += 1
        if any(prefix in text for prefix in MACHINE_PREFIXES):
            errors.append(f'distribution: machine-path {relative}')
        if any(pattern.search(text) for pattern in SECRET_PATTERNS):
            errors.append(f'distribution: possible-secret {relative}')
    manifest_bytes = json.dumps(inventory, sort_keys=True, separators=(',', ':')).encode()
    return {'file_count': len(inventory), 'text_files_scanned': text_count,
            'inventory_sha256': hashlib.sha256(manifest_bytes).hexdigest(),
            'excluded_directory_names': sorted(EXCLUDED), 'files': inventory}


def audit_case(root: Path, case: dict, errors: list[str]) -> dict:
    cid = case.get('id', '<missing-id>')
    label = f'case {cid}'
    status = case.get('status')
    if status not in {'runnable', 'reference-only', 'blocked'}:
        errors.append(f'{label}: invalid-status')
    limitations = case.get('limitations')
    if not isinstance(limitations, list) or not limitations or not all(isinstance(x, str) and x for x in limitations):
        errors.append(f'{label}: missing-scope-or-limitations')
    result = {'id': cid, 'status': status, 'limitations': limitations,
              'runtime_execution_verified': False, 'visual_review_verified': False}
    if status != 'runnable':
        return result
    entry = file_inside(root, case.get('entrypoint'), errors, label + ' entrypoint')
    provenance = file_inside(root, case.get('provenance'), errors, label + ' provenance')
    if provenance:
        try:
            if not isinstance(json.loads(provenance.read_text(encoding='utf-8')), dict):
                raise ValueError('object required')
        except (UnicodeError, ValueError):
            errors.append(f'{label}: invalid-provenance')
    files = case.get('files')
    if not isinstance(files, list) or not files:
        errors.append(f'{label}: empty-runtime-readset')
        files = []
    declared, roles = set(), set()
    for material in files:
        if not isinstance(material, dict):
            errors.append(f'{label}: invalid-material')
            continue
        relative = material.get('path')
        if relative in declared:
            errors.append(f'{label}: duplicate-material {relative}')
        declared.add(relative)
        roles.add(material.get('role'))
        path = file_inside(root, relative, errors, label + ' material')
        if not SHA.fullmatch(str(material.get('sha256', ''))):
            errors.append(f'{label}: missing-sha256 {relative}')
        elif path and digest(path) != material['sha256']:
            errors.append(f'{label}: hash-mismatch {relative}')
        if not resolved_license(material.get('license')):
            errors.append(f'{label}: unresolved-license {relative}')
        if not material.get('origin'):
            errors.append(f'{label}: missing-origin {relative}')
        if path and material.get('role') == 'code' and path.suffix == '.py':
            if PARENT_RUNTIME.search(path.read_text(encoding='utf-8')):
                errors.append(f'{label}: parent-runtime-dependency {relative}')
    if entry and case['entrypoint'] not in declared:
        errors.append(f'{label}: entrypoint-not-bound')
    if provenance and case['provenance'] not in declared:
        errors.append(f'{label}: provenance-not-bound')
    if not {'code', 'input', 'provenance'}.issubset(roles):
        errors.append(f'{label}: runtime-readset-must-bind-code-input-provenance')
    for preview in case.get('preview_files', []):
        path = file_inside(root, preview, errors, label + ' preview')
        if preview not in declared:
            errors.append(f'{label}: preview-not-bound {preview}')
        if path and path.suffix.lower() not in {'.png', '.pdf'}:
            errors.append(f'{label}: invalid-preview-format {preview}')
    expected_formats = case.get('expected_preview_formats', [])
    actual_formats = {Path(p).suffix.lower().lstrip('.') for p in case.get('preview_files', [])}
    if not set(expected_formats).issubset(actual_formats):
        errors.append(f'{label}: missing-required-preview')
    command = case.get('command')
    if not isinstance(command, list) or not command or not all(isinstance(x, str) and x for x in command):
        errors.append(f'{label}: missing-command')
    else:
        for token in command:
            if token.startswith('/') or any(prefix in token for prefix in MACHINE_PREFIXES):
                errors.append(f'{label}: nonportable-command')
            if '{skill_root}/' in token:
                file_inside(root, token.split('{skill_root}/', 1)[1], errors, label + ' command')
    dependencies = case.get('dependencies')
    if not isinstance(dependencies, list):
        errors.append(f'{label}: missing-dependency-list')
    for dep in dependencies or []:
        if not isinstance(dep, dict) or not dep.get('name') or not dep.get('source'):
            errors.append(f'{label}: incomplete-dependency')
    for item in case.get('external_inputs', []):
        if (not isinstance(item, dict) or not str(item.get('url', '')).startswith('https://')
                or not SHA.fullmatch(str(item.get('sha256', '')))
                or not resolved_license(item.get('license'))):
            errors.append(f'{label}: unresolved-external-input')
    result.update(bound_file_count=len(files), external_input_count=len(case.get('external_inputs', [])),
                  dependencies=dependencies, offline_inputs=not bool(case.get('external_inputs')))
    return result


def audit(root: Path, *, distribution_root: Path | None = None) -> dict:
    root = Path(root).resolve()
    distribution_root = Path(distribution_root).resolve() if distribution_root else root
    errors = []
    report = {'schema_version': 1, 'scope': 'portable-public-skill-install',
              'scientific_or_visual_pass_inferred': False,
              'audit_method': 'Declared public runtime readsets, SHA256, path containment, license declarations, full distribution text and symlink scan. R is not executed.',
              'cases': [], 'errors': errors}
    if not root.is_relative_to(distribution_root):
        errors.append('distribution: skill-root-outside-distribution')
    for relative in ('SKILL.md', 'manifest.yaml', 'public-cases.json'):
        file_inside(root, relative, errors, 'skill')
    try:
        manifest = json.loads((root / 'public-cases.json').read_text(encoding='utf-8'))
    except (OSError, ValueError):
        manifest = {}
        errors.append('manifest: missing-or-invalid-public-cases')
    if manifest.get('schema_version') != 1 or not isinstance(manifest.get('cases'), list):
        errors.append('manifest: unsupported-schema')
    cases = manifest.get('cases', [])
    ids = [case.get('id') for case in cases if isinstance(case, dict)]
    if len(ids) != len(cases) or len(ids) != len(set(ids)) or any(not x for x in ids):
        errors.append('manifest: missing-or-duplicate-case-id')
    if not cases:
        errors.append('manifest: no-public-cases')
    expected_ids = manifest.get('expected_case_ids', ids)
    if not isinstance(expected_ids, list) or set(expected_ids) != set(ids):
        errors.append('manifest: expected-case-id-mismatch')
    for material in manifest.get('shared_runtime_files', []):
        path = file_inside(root, material.get('path'), errors, 'shared-runtime')
        if not SHA.fullmatch(str(material.get('sha256', ''))):
            errors.append('shared-runtime: missing-sha256 ' + str(material.get('path')))
        elif path and digest(path) != material['sha256']:
            errors.append('shared-runtime: hash-mismatch ' + str(material.get('path')))
        if not resolved_license(material.get('license')) or not material.get('origin'):
            errors.append('shared-runtime: unresolved-license-or-origin ' + str(material.get('path')))
    for excluded in manifest.get('distribution_exclusions', []):
        relative = excluded.get('path', '')
        path = root / relative
        if not relative or Path(relative).is_absolute() or '..' in Path(relative).parts:
            errors.append('distribution: invalid-exclusion-path')
        elif path.exists() or path.is_symlink():
            errors.append('distribution: excluded-file-distributed ' + relative)
        if not excluded.get('reason'):
            errors.append('distribution: exclusion-reason-required ' + relative)
    for case in cases:
        if isinstance(case, dict):
            report['cases'].append(audit_case(root, case, errors))
    declared_provenance = {c.get('provenance') for c in cases if isinstance(c, dict)}
    for path in (root / 'examples').rglob('provenance.json'):
        if path.relative_to(root).as_posix() not in declared_provenance:
            errors.append(f'manifest: unlisted-public-case {path.relative_to(root)}')
    try:
        entries = json.loads((root / 'atlas/learned-method-index.json').read_text(encoding='utf-8'))['entries']
        unavailable = [e['method_id'] for e in entries if any(
            not (root / rel).is_file() or not (root / rel).resolve().is_relative_to(root)
            for rel in e.get('mandatory_read_set', []))]
        report['learning_catalog'] = {'indexed_records': len(entries),
            'source_materials_unavailable': len(unavailable),
            'catalog_reference_status': 'source-materials-unavailable' if unavailable else 'materials-present',
            'unavailable_method_ids': unavailable,
            'qualification': 'Historical records retained; catalog presence does not mean runnable or qualified.'}
    except (OSError, ValueError, KeyError, TypeError):
        errors.append('catalog: missing-or-invalid-learning-index')
    report['distribution'] = scan_distribution(distribution_root, errors)
    report['case_counts'] = dict(Counter(c['status'] for c in report['cases']))
    report['status'] = 'FAIL' if errors else 'PASS'
    return report


def dry_fresh_install(root: Path) -> dict:
    """Copy only the Skill; retain symlinks so escapes cannot become bundled files."""
    with tempfile.TemporaryDirectory(prefix='biofigure-install-audit-') as temporary:
        target = Path(temporary) / 'biofigure'
        shutil.copytree(root, target, symlinks=True, ignore=shutil.ignore_patterns(*EXCLUDED, '.DS_Store'))
        report = audit(target)
        report['dry_fresh_install'] = {'skill_only_copy': True, 'parent_repository_copied': False,
                                      'renderer_executed': False, 'dependencies_installed': False}
        return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--distribution-root', type=Path)
    parser.add_argument('--dry-fresh-install', action='store_true')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if args.dry_fresh_install and args.distribution_root:
        parser.error('--dry-fresh-install copies only the Skill; audit the full distribution separately')
    report = dry_fresh_install(args.root) if args.dry_fresh_install else audit(args.root, distribution_root=args.distribution_root)
    payload = json.dumps(report, ensure_ascii=False, indent=2) + '\n'
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload, encoding='utf-8')
        print(json.dumps({k: report.get(k) for k in ('status', 'scope', 'case_counts', 'errors')}, ensure_ascii=False))
    else:
        print(payload, end='')
    return 0 if report['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
