#!/usr/bin/env python3
"""Issue and consume single-use authorization bound to current BioFigure inputs."""
from __future__ import annotations
import argparse
import hashlib
import json
import importlib.util
import sys
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from reference_modes import receipt_reference_mode, code_gate, mode_binding_errors


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def issue(receipt: Path, design: Path, sources: list[Path], output: Path) -> dict:
    paths = [receipt, design, *sources]
    if not paths or any(not p.is_file() for p in paths):
        raise ValueError('receipt, Design Spec, and renderer sources must exist')
    receipt_doc = json.loads(receipt.read_text(encoding='utf-8'))
    reference_mode = receipt_reference_mode(receipt_doc)
    if receipt_doc.get('status') != 'PREFLIGHT_COMPLETE' or receipt_doc.get('code_gate') != code_gate(reference_mode):
        raise ValueError('preparation receipt is not eligible for render authorization')
    design_doc = yaml.safe_load(design.read_text(encoding='utf-8'))
    mode_errors = mode_binding_errors(receipt_doc, design_doc)
    if mode_errors:
        raise ValueError('; '.join(mode_errors))
    design_spec_module_spec = importlib.util.spec_from_file_location('biofigure_authorize_design_spec', ROOT / 'scripts/validate_design_spec.py')
    design_spec_module = importlib.util.module_from_spec(design_spec_module_spec)
    assert design_spec_module_spec and design_spec_module_spec.loader
    design_spec_module_spec.loader.exec_module(design_spec_module)
    design_errors = design_spec_module.validate(design_doc, design_spec_module.load(design_spec_module.SCHEMA), spec_path=design)
    if design_errors:
        raise ValueError('Design Spec validation failed: ' + '; '.join(design_errors))
    cp_spec = importlib.util.spec_from_file_location('biofigure_authorize_cp', ROOT / 'scripts/validate_checkpoints.py')
    cp_module = importlib.util.module_from_spec(cp_spec)
    assert cp_spec and cp_spec.loader
    cp_spec.loader.exec_module(cp_module)
    binding_errors = cp_module.validate_preparation_receipt(str(receipt), design_doc)
    if reference_mode != 'original':
        from reuse_templates import validate_fixture_sources
        binding_errors.extend(validate_fixture_sources(receipt_doc, sources))
        from retrieve_learned_methods import validate_adapter_sources
        binding_errors.extend(validate_adapter_sources(receipt_doc, design_doc, sources))
    if binding_errors:
        raise ValueError('CP2 preparation binding failed: ' + '; '.join(binding_errors))
    bound = {'receipt': {'path': str(receipt.resolve()), 'sha256': sha(receipt)},
             'design_spec': {'path': str(design.resolve()), 'sha256': sha(design)},
             'sources': [{'path': str(p.resolve()), 'sha256': sha(p)} for p in sources]}
    body = {'schema_version': 1, 'status': 'AUTHORIZED', 'single_use': True, 'bound': bound,
            'reference_mode': reference_mode}
    body['authorization_id'] = hashlib.sha256(json.dumps(body, sort_keys=True).encode()).hexdigest()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(body, indent=2, sort_keys=True) + '\n', encoding='utf-8')
    return body


def consume(authorization: Path, design: Path, sources: list[Path]) -> bool:
    body = json.loads(authorization.read_text(encoding='utf-8'))
    auth_id = body.get('authorization_id')
    was_consumed = body.get('consumed') is True
    core = dict(body)
    core.pop('authorization_id', None)
    core.pop('consumed', None)
    expected = hashlib.sha256(json.dumps(core, sort_keys=True).encode()).hexdigest()
    if (body.get('schema_version') != 1 or body.get('status') != 'AUTHORIZED'
            or body.get('single_use') is not True or auth_id != expected):
        raise ValueError('authorization integrity invalid')
    if was_consumed:
        raise ValueError('authorization already consumed')
    bound = body.get('bound', {})
    current = [design, *sources]
    expected_files = [bound.get('design_spec', {}), *bound.get('sources', [])]
    if len(current) != len(expected_files):
        raise ValueError('authorization source set changed')
    for path, record in zip(current, expected_files):
        if not path.is_file() or str(path.resolve()) != record.get('path') or sha(path) != record.get('sha256'):
            raise ValueError(f'authorized input changed: {path}')
    receipt = bound.get('receipt', {})
    receipt_path = Path(receipt.get('path', ''))
    if not receipt_path.is_file() or sha(receipt_path) != receipt.get('sha256'):
        raise ValueError('preparation receipt changed')
    preparation_doc = json.loads(receipt_path.read_text(encoding='utf-8'))
    design_doc = yaml.safe_load(design.read_text(encoding='utf-8'))
    mode_errors = mode_binding_errors(preparation_doc, design_doc)
    if mode_errors or body.get('reference_mode', 'reference-guided') != receipt_reference_mode(preparation_doc):
        raise ValueError('reference_mode differs between authorization and bound inputs' + (': ' + '; '.join(mode_errors) if mode_errors else ''))
    marker = authorization.with_suffix(authorization.suffix + '.consumed')
    try:
        marker.write_text(auth_id + '\n', encoding='utf-8', exclusive=True)
    except TypeError:  # pathlib Python versions without exclusive write
        try:
            with marker.open('x', encoding='utf-8') as handle:
                handle.write(auth_id + '\n')
        except FileExistsError as exc:
            raise ValueError('authorization already consumed') from exc
    except FileExistsError as exc:
        raise ValueError('authorization already consumed') from exc
    body['consumed'] = True
    temporary = authorization.with_name(authorization.name + '.consume-tmp')
    try:
        with temporary.open('w', encoding='utf-8') as handle:
            json.dump(body, handle, indent=2, sort_keys=True)
            handle.write('\n')
            handle.flush()
        temporary.replace(authorization)
    finally:
        if temporary.exists():
            temporary.unlink()
    return True


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument('--receipt', type=Path)
    p.add_argument('--design-spec', type=Path, required=True)
    p.add_argument('--source', type=Path, action='append', required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--consume', action='store_true')
    a = p.parse_args()
    if a.consume:
        consume(a.output, a.design_spec, a.source)
        print(json.dumps({'status': 'CONSUMED'}))
    else:
        if a.receipt is None:
            p.error('--receipt is required when issuing authorization')
        result = issue(a.receipt, a.design_spec, a.source, a.output)
        print(json.dumps({'status': result['status'], 'authorization_id': result['authorization_id']}))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
