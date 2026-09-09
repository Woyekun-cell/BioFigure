#!/usr/bin/env python3
"""Retrieve optional SciDraw-derived cases without exposing or executing source code."""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CORPUS = ROOT / "atlas/scidraw-derived-corpus.json"


def tokens(value: str) -> list[str]:
    normalized = re.sub(r"[^0-9a-zA-Z_+\-\u4e00-\u9fff]+", " ", value.lower())
    parts = [x for x in normalized.split() if x]
    chinese = [c for x in parts for c in re.findall(r"[\u4e00-\u9fff]{2,}", x)]
    return list(dict.fromkeys(parts + chinese))


def searchable(case: dict) -> dict[str, str]:
    code = case["code_analysis"]
    return {
        "title": case["title"].lower(),
        "category": case["category"].lower(),
        "packages": " ".join(code["packages"]).lower(),
        "primitives": " ".join(code["plot_primitives"]).lower(),
        "layout": " ".join(code["layout_controls"]).lower(),
        "statistics": " ".join(code["statistics"]).lower(),
    }


def score_case(case: dict, query: str) -> float:
    fields = searchable(case)
    weights = {"title": 7, "category": 4, "packages": 8, "primitives": 5, "layout": 3, "statistics": 2}
    score = 0.0
    q = query.lower().strip()
    if q and q in f"{fields['category']} {fields['title']}":
        score += 12
    for token in tokens(query):
        for field, weight in weights.items():
            if token in fields[field]:
                score += weight
    if score <= 0:
        return 0.0
    status = case["status"]
    score += {"ok": 2, "needs_review": -3, "failed": -8, "no_code": -8, "no_content": -8, "no_public_url": -5}.get(status, -2)
    if case["visual_match"]["status"] == "matched":
        score += 2
    if code_file_count := case["code_analysis"].get("file_count", 0):
        score += min(code_file_count, 3) * 0.25
    return score


def retrieve(query: str, limit: int = 5) -> dict:
    corpus = json.loads(CORPUS.read_text(encoding="utf-8"))
    visuals = {v["visual_id"]: v for v in corpus["visuals"]}
    ranked = sorted(((score_case(case, query), case) for case in corpus["cases"]), key=lambda x: (-x[0], x[1]["case_id"]))
    results = []
    for score, case in ranked:
        if score <= 0:
            continue
        item = {key: case[key] for key in ("case_id", "category", "title", "source_url", "status", "code_analysis", "visual_match")}
        item["visual_candidates"] = [visuals[v] for v in case["visual_match"]["visual_ids"] if v in visuals]
        item["requires_actual_image_review"] = True
        item["score"] = round(score, 2)
        item["transfer_policy"] = "inspect_then_distill_never_copy"
        results.append(item)
        if len(results) >= limit:
            break
    return {
        "query": query,
        "evidence_status": "optional_reference_not_ground_truth",
        "source_precedence": "scientific_contract_and_official_guidance",
        "results": results,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--query", required=True)
    parser.add_argument("--limit", type=int, default=5)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    payload = retrieve(args.query, max(1, min(args.limit, 20)))
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        for item in payload["results"]:
            print(f"{item['case_id']}\t{item['score']}\t{item['status']}\t{item['category']}\t{item['title']}")
    return 0 if payload["results"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
