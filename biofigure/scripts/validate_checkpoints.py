#!/usr/bin/env python3
"""Validate ordered, evidence-bound BioFigure checkpoints."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
import math
import subprocess

import yaml


ROOT = Path(__file__).resolve().parents[1]
DEFINITION = ROOT / "checkpoints/checkpoints.yaml"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
DETECTED_KEYS = {"overlap", "clipping", "missing_glyph", "font_fallback", "legend_overlap", "non_white_background", "unrequested_text"}
REPRO_CORPUS = ROOT / "atlas/reproduction-derived-corpus.json"


def load(path: Path):
    with path.open(encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_reproduction_receipt(receipt_path: str, corpus: Path = REPRO_CORPUS) -> list[str]:
    errors = []
    try:
        receipt = json.loads(Path(receipt_path).read_text())
        if receipt.get('schema_version') != 1 or not str(receipt.get('query','')).strip():
            errors.append('reproduction receipt version/query invalid')
        bound = receipt.get('corpus', {})
        if Path(str(bound.get('path',''))).resolve() != corpus.resolve() or not corpus.is_file() or bound.get('sha256') != digest(corpus):
            errors.append('reproduction receipt corpus missing or changed')
        results = receipt.get('results')
        if not isinstance(results,list) or not 1 <= len(results) <= 5 or any(not isinstance(x,dict) or not x.get('case_id') for x in results):
            errors.append('reproduction receipt requires 1-5 cases')
        contract = receipt.get('generation_contract', {})
        if contract.get('author_material_access') not in {'forbidden','authorized-inspection-no-copy'} or contract.get('implementation') != 'new-script-from-user-data-and-derived-patterns':
            errors.append('reproduction access/implementation contract invalid')
        if contract.get('author_material_access') == 'authorized-inspection-no-copy' and contract.get('blind_generation') is True:
            errors.append('source-exposed reproduction cannot claim blind generation')
        if 'source_code' in json.dumps(receipt,ensure_ascii=False):
            errors.append('reproduction receipt exposes source code')
    except Exception as exc:
        errors.append(f'reproduction receipt unreadable: {exc}')
    return errors


def validate_render_receipt(receipt_path: str, artifact: Path, design_spec: Path | None = None) -> list[str]:
    """Check freshness and completeness, not authenticity of model-written attestations."""
    errors = []
    try:
        receipt = json.loads(Path(receipt_path).read_text())
        if receipt.get('schema_version') != 1 or receipt.get('status') != 'PASS':
            errors.append('render receipt version/status invalid')
        if receipt.get('backend') not in {'R', 'Python'}:
            errors.append('render receipt backend invalid')
        path_base = receipt.get('path_base')
        repository_root = ROOT.parent.resolve()
        def bound_path(item):
            if not isinstance(item, dict):
                return None
            p = Path(str(item.get('path', '')))
            if not p.is_absolute():
                if path_base != 'repository-root':
                    return None
                p = (repository_root / p).resolve()
                if p != repository_root and repository_root not in p.parents:
                    return None
            else:
                p = p.resolve()
            return p if p.is_file() and digest(p) == item.get('sha256') else None
        def bound(item):
            return bound_path(item) is not None
        image = receipt.get('artifact', {})
        if not bound(image) or bound_path(image) != artifact.resolve():
            errors.append('render receipt artifact mismatch')
        sources = receipt.get('sources')
        if not isinstance(sources, list) or not sources or not all(bound(x) for x in sources):
            errors.append('render receipt source missing or changed')
        if not isinstance(sources, list) or not any(isinstance(x, dict) and Path(str(x.get('path', ''))).suffix.lower() in {'.r', '.py'} for x in sources):
            errors.append('render receipt must bind renderer source code')
        if receipt.get('renderer') == 'ggplot2':
            names = [Path(str(x.get('path', ''))).name for x in sources if isinstance(x, dict)] if isinstance(sources, list) else []
            if 'figure_style.R' not in names or not any(n.lower().endswith('.r') and n != 'figure_style.R' for n in names):
                errors.append('ggplot2 receipt must bind plot source and figure_style.R')
        if design_spec is not None and (not isinstance(sources, list) or not any(
                bound_path(x) == design_spec.resolve() for x in sources if isinstance(x, dict))):
            errors.append('render receipt must bind current design spec')
        font = receipt.get('font', {})
        if not bound(font) or font.get('family') not in {'Arial', 'Helvetica'}:
            errors.append('render receipt font invalid')
        checks = receipt.get('checks', {})
        if not isinstance(checks, dict) or any(checks.get(k) is not True for k in ('font', 'text_allowlist', 'layout', 'target_size')):
            errors.append('render receipt checks incomplete')
        size = receipt.get('target_min_text_pt')
        if type(size) not in (int, float) or not math.isfinite(size) or size < 5:
            errors.append('render receipt target text below 5 pt or invalid')
        elif size < 6 and not str(receipt.get('text_size_authorization') or '').strip():
            errors.append('render receipt text below 6 pt requires documented basis')
    except Exception as exc:
        errors.append(f'render receipt unreadable: {exc}')
    return errors


def validate(ledger: dict, definition: dict) -> list[str]:
    errors: list[str] = []
    if not isinstance(ledger, dict):
        return ["ledger must be a mapping"]
    for key in ("schema_version", "artifact_id", "mode", "checkpoints"):
        if key not in ledger:
            errors.append(f"ledger missing: {key}")
    gates = definition.get("checkpoints", []) if isinstance(definition, dict) else []
    expected = [gate.get("id") for gate in gates]
    entries = ledger.get("checkpoints")
    if not isinstance(entries, list):
        return errors + ["checkpoints must be a list"]
    received = [entry.get("id") if isinstance(entry, dict) else None for entry in entries]
    if received != expected:
        errors.append(f"checkpoint order must be {expected}; got {received}")
        return errors

    allowed = set(definition.get("status_enum", []))
    blocker: tuple[str, str] | None = None
    cp3_digest: str | None = None
    for gate, entry in zip(gates, entries):
        checkpoint_id = gate["id"]
        status = entry.get("status")
        evidence = entry.get("evidence")
        failures = entry.get("failures")
        next_action = entry.get("next_action")
        if status not in allowed:
            errors.append(f"{checkpoint_id} invalid status: {status}")
            continue
        if not isinstance(evidence, dict):
            errors.append(f"{checkpoint_id} evidence must be a mapping")
            evidence = {}
        if not isinstance(failures, list):
            errors.append(f"{checkpoint_id} failures must be a list")
            failures = []
        if not isinstance(next_action, str) or not next_action.strip():
            errors.append(f"{checkpoint_id} next_action must be non-empty")
        if blocker and status == "PASS":
            errors.append(f"{checkpoint_id} cannot PASS after {blocker[0]}={blocker[1]}")
        if status in {"REVISE", "STOP"}:
            if not failures:
                errors.append(f"{checkpoint_id} {status} requires failures")
            if not blocker:
                blocker = (checkpoint_id, status)
        elif status == "NOT_RUN" and not blocker:
            errors.append(f"{checkpoint_id} cannot be NOT_RUN without an earlier blocker")
            blocker = (checkpoint_id, status)
        elif status == "PASS":
            missing = [key for key in gate.get("required_evidence", []) if key not in evidence]
            if missing:
                errors.append(f"{checkpoint_id} evidence missing: {', '.join(missing)}")

        if status != "PASS":
            continue
        if checkpoint_id == "CP0":
            for key in ("scientific_question", "figure_task", "claim_boundary"):
                if not isinstance(evidence.get(key), str) or not evidence[key].strip():
                    errors.append(f"CP0 {key} must be non-empty")
            if evidence.get("unresolved_critical_fields") != []:
                errors.append("CP0 cannot PASS with unresolved_critical_fields")
        if checkpoint_id == "CP1":
            if evidence.get("sample_mapping_checked") is not True:
                errors.append("CP1 sample_mapping_checked must be true")
            for key in ("replicate_unit", "scale_and_transform", "statistics_contract", "coordinate_contract"):
                if not isinstance(evidence.get(key), str) or not evidence[key].strip():
                    errors.append(f"CP1 {key} must be non-empty")
        if checkpoint_id == "CP2":
            spec_path = Path(str(evidence.get('design_spec', ''))).expanduser()
            if not spec_path.is_file():
                errors.append('CP2 design_spec file required')
            else:
                result = subprocess.run([sys.executable, str(ROOT/'scripts/validate_design_spec.py'), str(spec_path)], capture_output=True, text=True)
                if result.returncode:
                    errors.append('CP2 actual design validation failed: ' + result.stdout.strip())
            if not isinstance(evidence.get("selected_pattern"), str) or not evidence["selected_pattern"].strip():
                errors.append("CP2 selected_pattern must be non-empty")
            errors.extend(validate_reproduction_receipt(str(evidence.get('reproduction_retrieval_receipt',''))))
            for key, wanted in (("design_spec_validation", "PASS"), ("renderer_available", True), ("layout_slots_reserved", True)):
                if evidence.get(key) != wanted:
                    errors.append(f"CP2 {key} must be {wanted}")
        if checkpoint_id == "CP3":
            path = Path(str(evidence.get("artifact", ""))).expanduser()
            cp2 = entries[2].get('evidence', {})
            errors.extend(validate_render_receipt(str(evidence.get('render_receipt', '')), path,
                          Path(str(cp2.get('design_spec', '')))))
            claimed = str(evidence.get("artifact_sha256", ""))
            if not path.is_file():
                errors.append("CP3 artifact missing")
            elif not SHA256.fullmatch(claimed) or digest(path) != claimed:
                errors.append("CP3 artifact_sha256 mismatch")
            else:
                cp3_digest = claimed
            if evidence.get("artifact_opened") is not True or evidence.get("viewer_method") not in {"direct-open", "contact-sheet-open"}:
                errors.append("CP3 requires an actual viewer-open record")
            if evidence.get("target_size_checked") is not True:
                errors.append("CP3 target_size_checked must be true")
            detected = evidence.get("detected")
            if not isinstance(detected, dict) or not DETECTED_KEYS <= set(detected):
                errors.append("CP3 detected fields incomplete")
            elif any(detected[key] is not False for key in DETECTED_KEYS):
                errors.append("CP3 cannot PASS with a detected hard failure")
        if checkpoint_id == "CP4":
            cp2 = entries[2].get('evidence', {})
            cp3 = entries[3].get('evidence', {})
            command = [sys.executable, str(ROOT/'scripts/run_critics.py'), '--artifact', str(cp3.get('artifact', '')),
                       '--pattern', str(cp2.get('selected_pattern', '')), '--mode', 'publication',
                       '--inspection-evidence', str(evidence.get('inspection_evidence', '')),
                       '--design-spec', str(cp2.get('design_spec', '')), '--json']
            spec_path = Path(str(cp2.get('design_spec', '')))
            try:
                spec_doc = load(spec_path)
                biology = spec_doc.get('biology_contract', {})
                for key in ('primary_domain', 'secondary_domain'):
                    if biology.get(key): command.extend(['--domain', str(biology[key])])
                result = subprocess.run(command, capture_output=True, text=True)
                if result.returncode:
                    errors.append('CP4 actual critic validation failed: ' + result.stdout.strip() + result.stderr.strip())
            except Exception as exc:
                errors.append(f'CP4 critic execution failed: {exc}')
            if evidence.get("critic_status") != "PASS" or evidence.get("qa_status") != "PASS":
                errors.append("CP4 critic_status and qa_status must be PASS")
            if not isinstance(evidence.get("simulation_disclosed"), bool):
                errors.append("CP4 simulation_disclosed must be boolean")
            deliverables = evidence.get("deliverables")
            if not isinstance(deliverables, list) or not deliverables:
                errors.append("CP4 deliverables must be non-empty")
            else:
                observed = set()
                for item in deliverables:
                    if not isinstance(item, dict):
                        errors.append("CP4 deliverable must be a mapping")
                        continue
                    path = Path(str(item.get("path", ""))).expanduser()
                    if path.suffix.lower() == '.png' and path.resolve() != Path(str(cp3.get('artifact', ''))).resolve():
                        errors.append('CP4 each PNG requires its own inspected ledger')
                    claimed = str(item.get("sha256", ""))
                    if not path.is_file() or not SHA256.fullmatch(claimed) or digest(path) != claimed:
                        errors.append(f"CP4 deliverable hash mismatch: {path}")
                    else:
                        observed.add(claimed)
                if cp3_digest and cp3_digest not in observed:
                    errors.append("CP4 deliverables do not include the inspected artifact")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("ledger", type=Path)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    try:
        ledger = load(args.ledger)
        errors = validate(ledger, load(DEFINITION))
        if not errors and not all(entry.get('status') == 'PASS' for entry in ledger['checkpoints']):
            errors.append('ledger is structurally valid but release is blocked; all checkpoints must PASS')
    except Exception as exc:
        errors = [str(exc)]
    payload = {"status": "PASS" if not errors else "FAIL", "errors": errors}
    print(json.dumps(payload, ensure_ascii=False, indent=2) if args.json else ("CHECKPOINTS_OK" if not errors else "CHECKPOINTS_FAIL\n" + "\n".join(errors)))
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
