#!/usr/bin/env python3
"""Retrieve optional SciDraw-derived cases without exposing or executing source code."""
from __future__ import annotations

import argparse
import json
import re
import hashlib
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CORPUS = ROOT / "atlas/scidraw-derived-corpus.json"
METHODS = ROOT / "atlas/scidraw-source-compared-methods.json"

# Explicit semantics audited against the stored corpus and original review URL.
# The two ambiguous historical pairings remain unverified, never inherited PASS.
METHOD_CASES = {'SCIDRAW-RCS-001': 'SCICASE-038', 'SCIDRAW-RIDGE-BIPOLAR-001': 'SCICASE-149',
                'SCIDRAW-PCOA-MARGINAL-001': 'SCICASE-062', 'SCIDRAW-SWIMMER-001': 'SCICASE-075',
                'SCIDRAW-CHORD-TRACK-001': 'SCICASE-154', 'SCIDRAW-VOLCANO-GSEA-001': 'SCICASE-045',
                'SCIDRAW-TERNARY-001': 'SCICASE-071', 'SCIDRAW-CORRPLOT-001': 'SCICASE-014'}


def learned_records(corpus):
    by_case = {}
    title_map = {}
    for c in corpus['cases']:
        title_map.setdefault(c['title'], []).append(c['case_id'])
    for method in json.loads(METHODS.read_text())['cases']:
        case_id = METHOD_CASES.get(method['id'])
        if case_id:
            by_case.setdefault(case_id, []).append(dict(method, record_source=str(METHODS.relative_to(ROOT)),
                pairing_status='semantics-derived-needs-pairing-review' if method['id'] in {'SCIDRAW-TERNARY-001', 'SCIDRAW-CORRPLOT-001'} else 'explicit-semantic-binding'))
    path = ROOT / 'atlas/scidraw-batch2-methods.json'
    for method in json.loads(path.read_text())['cases']:
        matches = title_map.get(method['label'], [])
        if len(matches) == 1:
            by_case.setdefault(matches[0], []).append(dict(method, record_source=str(path.relative_to(ROOT)), pairing_status='unique-source-title-binding'))
    for path in sorted((ROOT / 'atlas').glob('scidraw-learning-ten*.json')):
        for case in json.loads(path.read_text())['cases']:
            by_case.setdefault(case['case_id'], []).append(dict(case, record_source=str(path.relative_to(ROOT))))
    return by_case


@lru_cache(maxsize=1)
def image_hash_locations():
    result = {}
    archive = ROOT / 'benchmark/library/scidraw'
    for folder in ('sources', 'figures', 'evidence/comparison'):
        for p in sorted((archive / folder).rglob('*')):
            if not p.is_file() or p.suffix.lower() not in {'.png', '.jpg', '.jpeg', '.webp', '.avif'}:
                continue
            result.setdefault(hashlib.sha256(p.read_bytes()).hexdigest(), []).append(str(p.resolve()))
    return result


def bound_pngs(method):
    """Resolve migrated filenames only when the original recorded SHA matches."""
    records = []
    for item in method.get('validated_pngs', []):
        if not isinstance(item, dict):
            continue
        original = Path(item['path'])
        candidates = [ROOT / original, ROOT.parent / original, ROOT / 'benchmark/library/scidraw/figures' / original.name]
        matches = [p for p in candidates if p.is_file() and hashlib.sha256(p.read_bytes()).hexdigest() == item.get('sha256')]
        locations = image_hash_locations()
        source = locations.get(item.get('source_image_sha256'), [])
        comparison = locations.get(item.get('comparison_sha256'), [])
        records.append(dict(item, resolved_path=str(matches[0].resolve()) if matches else None,
                            hash_verified=bool(matches), source_image_path=source[0] if source else None,
                            source_hash_verified=bool(source), comparison_path=comparison[0] if comparison else None,
                            comparison_hash_verified=bool(comparison)))
    return records


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


def retrieve(query: str, limit: int = 5, require_validated: bool = False) -> dict:
    corpus = json.loads(CORPUS.read_text(encoding="utf-8"))
    methods = learned_records(corpus)
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
        resources = methods.get(case['case_id'], [])
        item['learned_resources'] = resources
        method = next((m for m in resources if 'runtime_status' in m), {})
        item["source_compared_method"] = method
        item['bound_pngs'] = bound_pngs(method)
        item['repeatable_transfer_status'] = 'NOT_VERIFIED'
        # Historical source review is insufficient when source pairing, migrated
        # source images or a later critical review remain unresolved.
        item["high_fidelity_eligible"] = (
            method.get("runtime_status") == "source-compared-png"
            and method.get("review_status") == "pass"
            and bool(item['bound_pngs'])
            and all(p['hash_verified'] for p in item['bound_pngs'])
            and all(p['source_hash_verified'] and p['comparison_hash_verified'] for p in item['bound_pngs'])
            and method.get('pairing_status') == 'unique-source-title-binding'
        )
        if require_validated and not item["high_fidelity_eligible"]:
            continue
        results.append(item)
        if len(results) >= limit:
            break
    return {
        "query": query,
        "evidence_status": "optional_reference_not_ground_truth",
        "source_precedence": "scientific_contract_and_official_guidance",
        "retrieval_policy": {
            "require_validated": require_validated,
            "high_fidelity_rule": "runtime_status=source-compared-png and review_status=pass",
        },
        "results": results,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--query", required=True)
    parser.add_argument("--limit", type=int, default=5)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--require-validated", action="store_true")
    args = parser.parse_args()
    payload = retrieve(args.query, max(1, min(args.limit, 20)), args.require_validated)
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        for item in payload["results"]:
            print(f"{item['case_id']}\t{item['score']}\t{item['status']}\t{item['category']}\t{item['title']}")
    return 0 if payload["results"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
