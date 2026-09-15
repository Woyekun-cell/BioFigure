#!/usr/bin/env python3
"""Promote SciDraw methods only when their reviewed artifact evidence verifies."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
METHODS = ROOT / "atlas/scidraw-source-compared-methods.json"
EVIDENCE = ROOT / "atlas/scidraw-review-evidence.json"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def synchronize(methods: dict, evidence: dict) -> dict:
    by_id = {case["case_id"]: case for case in evidence["cases"]}
    method_ids = {case["id"] for case in methods["cases"]}
    if method_ids != set(by_id):
        raise ValueError("SciDraw method and review-evidence case IDs differ")

    for method in methods["cases"]:
        reviewed = by_id[method["id"]]
        artifact = reviewed["implementation"]
        artifact_path = REPO / artifact["artifact_path"]
        if not artifact_path.is_file():
            raise FileNotFoundError(artifact_path)
        if sha256(artifact_path) != artifact["artifact_sha256"]:
            raise ValueError(f"artifact hash mismatch: {artifact_path}")
        if reviewed["review_status"] != "pass":
            raise ValueError(f"review has not passed: {method['id']}")

        method["runtime_status"] = "source-compared-png"
        method["review_status"] = "pass"
        method["reviewed_at"] = evidence["reviewed_at"]
        method["validation_note"] = (
            "Current PNG was inspected beside its code-bound source image; "
            "object-level findings and hashes are recorded in "
            "atlas/scidraw-review-evidence.json."
        )
        method["validated_pngs"] = [{
            "path": artifact["artifact_path"],
            "sha256": artifact["artifact_sha256"],
            "pixels": artifact["artifact_pixels"],
            "source_image_sha256": reviewed["source"]["image_sha256"],
            "comparison_sha256": reviewed["comparison_sha256"],
        }]
        method["claim_boundary"] = "method-and-layout precedent using fixed-seed simulated data"
        if method["id"] == "SCIDRAW-PCOA-MARGINAL-001":
            method["guardrails"] = [
                "patchwork-composite-requires-current-source-comparison-and-artifact-hash"
                if item == "patchwork-output-needs-biofigure-receipt-support-before-final-pass"
                else item
                for item in method["guardrails"]
            ]

    methods["reviewed_at"] = evidence["reviewed_at"]
    return methods


def main() -> int:
    methods = json.loads(METHODS.read_text())
    evidence = json.loads(EVIDENCE.read_text())
    synchronized = synchronize(methods, evidence)
    METHODS.write_text(json.dumps(synchronized, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"cases": len(synchronized["cases"]), "pass": len(synchronized["cases"])}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
