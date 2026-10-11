#!/usr/bin/env python3
"""Find catalog candidates without treating them as reviewed figure evidence."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re


CORPUS = Path(__file__).resolve().parents[1] / "atlas/awesome-scientific-figure-candidates.json"
VISUAL_STUDY = Path(__file__).resolve().parents[1] / "atlas/awesome-scientific-figure-visual-study.json"
LAYOUT_RECIPES = Path(__file__).resolve().parents[1] / "atlas/awesome-scientific-figure-layout-recipes.json"


def words(value: str) -> set[str]:
    return set(re.findall(r"[a-z0-9]+", value.lower()))


def retrieve(domain: str, task: str, limit: int = 3) -> dict:
    if not 1 <= limit <= 5:
        raise ValueError("limit must be between 1 and 5")
    if not task.strip():
        raise ValueError("task must be non-empty")
    corpus = json.loads(CORPUS.read_text(encoding="utf-8"))
    study = json.loads(VISUAL_STUDY.read_text(encoding="utf-8"))
    visual_index = {(item["catalog_heading"], item["figure_locator"]): item for item in study["entries"]}
    requested = words(task)
    matches = []
    for entry in corpus["candidates"]:
        if domain not in entry["domains"]:
            continue
        declared = words(" ".join(entry["scientific_tasks_inferred"]))
        overlap = requested & declared
        if overlap:
            matches.append((len(overlap), entry["id"], entry))
    matches.sort(key=lambda item: (-item[0], item[1]))
    selected = []
    for _, _, candidate in matches[:limit]:
        item = dict(candidate)
        visual = visual_index.get((item["catalog_heading"], item["figure_locator"]))
        if visual:
            item["visual_study"] = {key: visual[key] for key in
                ("id", "visual_family", "visible_layout", "visible_color_roles", "implementation_hypothesis", "inspection_level", "source_image_sha256")}
        selected.append(item)
    return {
        "query": {"domain": domain, "task": task, "limit": limit},
        "source_repository": corpus["source_repository"],
        "source_revision": corpus["source_revision"],
        "candidate_references": selected,
        "verified_reference_evidence_gap": True,
        "boundary": "Catalog metadata and inferred tasks only; inspect original article, figure, data, code and rights before method promotion."
    }


def retrieve_layout(pattern: str, limit: int = 5) -> dict:
    if not 1 <= limit <= 5:
        raise ValueError("limit must be between 1 and 5")
    recipes = json.loads(LAYOUT_RECIPES.read_text(encoding="utf-8"))["recipes"]
    study = json.loads(VISUAL_STUDY.read_text(encoding="utf-8"))
    lookup = {item["id"]: item for item in study["entries"]}
    recipe = next((item for item in recipes if item["id"] == pattern), None)
    return {
        "query": {"pattern": pattern, "limit": limit},
        "method_card": recipe,
        "visual_references": [lookup[item] for item in recipe["source_figure_ids"][:limit]] if recipe else [],
        "visual_review_scope": study["review_scope"],
        "verified_reference_evidence_gap": True,
        "boundary": "Visual layout observed in collected images; original methods, data and fidelity remain unverified."
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--domain")
    parser.add_argument("--task")
    parser.add_argument("--pattern")
    parser.add_argument("--limit", type=int, default=3)
    args = parser.parse_args()
    if args.pattern:
        if args.domain or args.task:
            parser.error("--pattern cannot be combined with --domain/--task")
        result = retrieve_layout(args.pattern, args.limit)
    else:
        if not args.domain or not args.task:
            parser.error("--domain and --task are required without --pattern")
        result = retrieve(args.domain, args.task, args.limit)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
