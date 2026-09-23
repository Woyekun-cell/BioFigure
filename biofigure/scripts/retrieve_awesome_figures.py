#!/usr/bin/env python3
"""Find catalog candidates without treating them as reviewed figure evidence."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re


CORPUS = Path(__file__).resolve().parents[1] / "atlas/awesome-scientific-figure-candidates.json"


def words(value: str) -> set[str]:
    return set(re.findall(r"[a-z0-9]+", value.lower()))


def retrieve(domain: str, task: str, limit: int = 3) -> dict:
    if not 1 <= limit <= 5:
        raise ValueError("limit must be between 1 and 5")
    if not task.strip():
        raise ValueError("task must be non-empty")
    corpus = json.loads(CORPUS.read_text(encoding="utf-8"))
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
    return {
        "query": {"domain": domain, "task": task, "limit": limit},
        "source_repository": corpus["source_repository"],
        "source_revision": corpus["source_revision"],
        "candidate_references": [item[2] for item in matches[:limit]],
        "verified_reference_evidence_gap": True,
        "boundary": "Catalog metadata and inferred tasks only; inspect original article, figure, data, code and rights before method promotion."
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--domain", required=True)
    parser.add_argument("--task", required=True)
    parser.add_argument("--limit", type=int, default=3)
    args = parser.parse_args()
    print(json.dumps(retrieve(args.domain, args.task, args.limit), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
