#!/usr/bin/env python3
"""Retrieve reviewed figure-level references without copying their artwork."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys

import yaml


ROOT = Path(__file__).resolve().parents[1]
CORPUS = ROOT / "atlas/top-journal-corpus.yaml"


def norm(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", str(value).lower())


def tokens(value) -> set[str]:
    if isinstance(value, list):
        value = " ".join(map(str, value))
    return {norm(x) for x in re.findall(r"[A-Za-z0-9-]+", str(value)) if len(norm(x)) > 1}


def retrieve(domain: str, task: str, pattern: str | None, limit: int) -> dict:
    entries = yaml.safe_load(CORPUS.read_text(encoding="utf-8"))["entries"]
    domain_n, task_tokens, pattern_n = norm(domain), tokens(task), norm(pattern or "")
    ranked = []
    for entry in entries:
        domains = {norm(x) for x in entry["domains"]}
        if domain_n not in domains:
            continue
        score = 10
        reasons = ["domain_match"]
        declared_tasks = tokens(entry["scientific_tasks"])
        overlap = len(task_tokens & declared_tasks)
        pattern_match = bool(pattern_n and pattern_n in {norm(x) for x in entry.get("patterns", [])})
        if not overlap and not pattern_match:
            continue
        score += 3 * overlap
        if overlap:
            reasons.append(f"task_overlap={overlap}")
        if pattern_match:
            score += 6
            reasons.append("pattern_match")
        if entry.get("code_status") in {"all-figure-code-available", "detailed-figure-code-available", "majority-analysis-code-available"}:
            score += 2
            reasons.append("strong_code_trace")
        ranked.append((score, entry["atlas_id"], reasons, entry))
    ranked.sort(key=lambda item: (-item[0], item[1]))
    selected = []
    for score, _, reasons, entry in ranked[:limit]:
        selected.append({
            "atlas_id": entry["atlas_id"], "journal": entry["journal"],
            "figure_locator": entry["figure_locator"], "paper_url": entry["paper_url"],
            "code_url": entry.get("code_url"), "code_status": entry["code_status"],
            "data_url": entry.get("data_url"), "code_revision": entry.get("code_revision"),
            "code_path": entry.get("code_path"), "article_license_status": entry["article_license_status"],
            "code_license_status": entry["code_license_status"],
            "license_status": entry["license_status"], "review_status": entry["review_status"],
            "reviewed_at": str(entry["reviewed_at"]), "actual_figure_reviewed": entry["actual_figure_reviewed"],
            "figure_asset_url": entry["figure_asset_url"], "asset_sha256": entry["asset_sha256"],
            "domains": entry["domains"], "scientific_tasks": entry["scientific_tasks"],
            "visual_observations": entry["visual_observations"],
            "transferable_decisions": entry["transferable_decisions"],
            "do_not_transfer": entry["do_not_transfer"],
            "score": score, "selection_reasons": reasons,
        })
    return {
        "query": {"domain": domain, "task": task, "pattern": pattern, "limit": limit},
        "selection_basis": "reviewed figure-level domain/task/pattern evidence; journal name alone adds no score",
        "references": selected,
        "evidence_gap": not bool(selected),
        "boundary": "transfer design grammar only; do not copy artwork, data, or paper-specific narrative",
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--domain", required=True)
    parser.add_argument("--task", required=True)
    parser.add_argument("--pattern")
    parser.add_argument("--limit", type=int, default=3)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    if not 1 <= args.limit <= 5:
        print("limit must be between 1 and 5", file=sys.stderr)
        return 2
    payload = retrieve(args.domain, args.task, args.pattern, args.limit)
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print(yaml.safe_dump(payload, sort_keys=False, allow_unicode=True))
    return 0 if payload["references"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
