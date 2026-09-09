#!/usr/bin/env python3
"""Validate ordered, evidence-bound BioFigure checkpoints."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

import yaml


ROOT = Path(__file__).resolve().parents[1]
DEFINITION = ROOT / "checkpoints/checkpoints.yaml"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
DETECTED_KEYS = {"overlap", "clipping", "missing_glyph", "font_fallback", "legend_overlap", "non_white_background", "unrequested_text"}


def load(path: Path):
    with path.open(encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


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
            if not isinstance(evidence.get("selected_pattern"), str) or not evidence["selected_pattern"].strip():
                errors.append("CP2 selected_pattern must be non-empty")
            for key, wanted in (("design_spec_validation", "PASS"), ("renderer_available", True), ("layout_slots_reserved", True)):
                if evidence.get(key) != wanted:
                    errors.append(f"CP2 {key} must be {wanted}")
        if checkpoint_id == "CP3":
            path = Path(str(evidence.get("artifact", ""))).expanduser()
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
        errors = validate(load(args.ledger), load(DEFINITION))
    except Exception as exc:
        errors = [str(exc)]
    payload = {"status": "PASS" if not errors else "FAIL", "errors": errors}
    print(json.dumps(payload, ensure_ascii=False, indent=2) if args.json else ("CHECKPOINTS_OK" if not errors else "CHECKPOINTS_FAIL\n" + "\n".join(errors)))
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
