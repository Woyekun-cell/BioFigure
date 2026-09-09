#!/usr/bin/env python3
"""Deterministic, read-only two-stage Pattern Retrieval."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys
import yaml

ROOT = Path(__file__).resolve().parents[1]
DOMAIN_ALIASES = {
    "bulk-rnaseq": {"bulk", "differential", "distribution", "matrix", "ordination", "enrichment"},
    "bulk-rna": {"bulk", "differential", "distribution", "matrix", "ordination", "enrichment"},
    "rnaseq": {"bulk", "differential", "distribution", "matrix", "ordination", "enrichment"},
    "metabolomics": {"metabolomics", "matrix", "distribution", "differential", "enrichment"},
    "multiomics": {"multiomics", "multi-omics", "matrix"},
    "atac": {"chromatin", "atac", "chip", "cutandtag", "matrix"},
    "chip": {"chromatin", "atac", "chip", "cutandtag", "matrix"},
    "chip-seq": {"chromatin", "atac", "chip", "cutandtag", "matrix"},
    "cutandtag": {"chromatin", "atac", "chip", "cutandtag", "matrix"},
}
DATA_FLAGS = {
    "pooled_cells": "pooled_cells_without_sample_summary",
    "dense_signal_matrix": "dense_signal_matrix",
    "missing_effect": "no_effect_measure",
    "missing_statistic": "no_statistical_source",
    "missing_background": "background_unknown",
    "unpaired": "unpaired_modalities",
}
TASK_STOPWORDS = {"show", "with", "and", "the", "a", "an", "of", "to", "for", "on", "as", "by", "from", "pattern", "patterns", "shared", "multiple", "one", "use", "using", "describe", "sample", "samples", "group", "groups"}
PROFILE_KEY_ALIASES = {
    "groups": "n_groups", "genes": "n_features", "features": "n_features", "points": "n_observations",
    "cells": "n_observations", "rows": "matrix.n_rows", "columns": "matrix.n_columns",
    "variables": "n_features", "metrics": "n_features", "loci": "n_features", "taxa": "n_groups",
    "sequences": "n_chromosomes", "chromosomes": "n_chromosomes", "terms": "n_features",
    "regions": "n_regions", "samples": "n_samples", "panels": "n_panels", "paired_samples": "n_samples",
}
PROFILE_KEYS = {"n_observations", "n_features", "n_groups", "n_samples", "n_conditions", "n_modalities", "n_panels", "n_regions", "n_chromosomes", "n_labels", "matrix.n_rows", "matrix.n_columns", "single_cell.n_cells", "single_cell.n_cell_types", "genomic.n_regions", "genomic.n_tracks", "genomic.n_chromosomes", "labels.n_labels", "labels.max_label_length"}


def load(path: Path):
    with path.open(encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def norm(value) -> str:
    return re.sub(r"[^a-z0-9]+", "", str(value).lower())


def words(value) -> set[str]:
    return {w for w in re.findall(r"[a-z0-9]+", str(value).lower()) if len(w) > 1}


def card_blob(card: dict, item: dict) -> set[str]:
    values = [item.get("pattern_id", ""), item.get("domain", ""), item.get("task", ""), item.get("tags", "")]
    values += [card.get("scientific_task", ""), card.get("message_type", ""), card.get("geometry", "")]
    return words(" ".join(map(str, values)))


def task_blob(card: dict, item: dict) -> set[str]:
    """Use declared task/tags for eligibility; geometry words are ranking-only."""
    values = [item.get("task", ""), item.get("tags", ""), card.get("scientific_task", []), card.get("message_type", "")]
    return words(" ".join(map(str, values)))


def token_overlap(query_tokens: set[str], declared: set[str]) -> bool:
    query_tokens -= TASK_STOPWORDS
    declared -= TASK_STOPWORDS
    for query_token in query_tokens:
        for declared_token in declared:
            if query_token == declared_token or query_token.rstrip("s") == declared_token.rstrip("s"):
                return True
    return False


def renderer_map(registry: dict) -> dict[str, str]:
    return {norm(name): name for name in registry}


def domain_match(query_domain: str | None, item: dict, card: dict) -> bool:
    if not query_domain:
        return True
    q = str(query_domain).lower()
    declared = {str(item.get("domain", "")).lower()} | {str(x).lower() for x in card.get("domain", [])}
    aliases = DOMAIN_ALIASES.get(q, {q})
    return any(norm(x) in {norm(d) for d in declared} for x in aliases)


def task_match(task: str, card: dict, item: dict) -> bool:
    if not task:
        return True
    task_n = norm(task)
    declared = {norm(item.get("task", ""))} | {norm(x) for x in card.get("scientific_task", [])}
    return task_n in declared


def flatten_profile(profile: dict | None, prefix: str = "") -> dict[str, int]:
    flat: dict[str, int] = {}
    for key, value in (profile or {}).items():
        name = f"{prefix}.{key}" if prefix else str(key)
        if isinstance(value, dict):
            flat.update(flatten_profile(value, name))
        elif isinstance(value, int) and not isinstance(value, bool):
            flat[name] = value
    return flat


def validate_profile(profile: dict | None) -> dict[str, int]:
    if profile is None:
        return {}
    if not isinstance(profile, dict):
        raise ValueError("Data Profile must be a mapping")
    flat = flatten_profile(profile)
    supplied = set()
    def walk(value, prefix=""):
        for key, item in value.items():
            name = f"{prefix}.{key}" if prefix else str(key)
            if isinstance(item, dict):
                walk(item, name)
            else:
                supplied.add(name)
                if not isinstance(item, int) or isinstance(item, bool) or item < 0:
                    raise ValueError(f"Data Profile {name} must be a non-negative integer")
    walk(profile)
    unknown = sorted(supplied - PROFILE_KEYS)
    if unknown:
        raise ValueError(f"unknown Data Profile field(s): {', '.join(unknown)}")
    equivalences = {"single_cell.n_cells": "n_observations", "single_cell.n_cell_types": "n_groups",
                    "genomic.n_regions": "n_regions", "genomic.n_chromosomes": "n_chromosomes",
                    "labels.n_labels": "n_labels"}
    for source, target in equivalences.items():
        if source in flat and target not in flat:
            flat[target] = flat[source]
    return flat


def count_match(value: int | None, rule) -> bool:
    if value is None or rule is None:
        return True
    text = str(rule).strip()
    if re.fullmatch(r"\d+", text):
        return value == int(text)
    match = re.fullmatch(r"(\d+)\s*-\s*(\d+)", text)
    if match:
        return int(match.group(1)) <= value <= int(match.group(2))
    match = re.fullmatch(r"(\d+)\s*\+", text)
    if match:
        return value >= int(match.group(1))
    return True


def constraint_flags(args: argparse.Namespace) -> set[str]:
    flags = {str(x).lower() for x in (getattr(args, "avoid", None) or [])}
    for value in getattr(args, "data_structure", None) or []:
        flags.add(DATA_FLAGS.get(norm(value), str(value).lower()))
    if getattr(args, "paired", None) == "false":
        flags.add("unpaired_modalities")
    if getattr(args, "coordinates", None) == "absent":
        flags.update({"unknown_contig", "missing_bigwig", "mixed_coordinate_systems"})
    return flags


def eligible(item: dict, card: dict, args: argparse.Namespace, renderer: str | None, registry: dict) -> tuple[bool, str]:
    if not domain_match(args.domain, item, card):
        return False, "domain_mismatch"
    if not task_match(args.task or "", card, item):
        return False, "task_mismatch"
    limits = card.get("applicable_when", {}).get("data_profile", card.get("applicable_when", {}))
    profile = validate_profile(getattr(args, "data_profile", None))
    for legacy_key, rule in limits.items():
        canonical = PROFILE_KEY_ALIASES.get(legacy_key, legacy_key)
        if canonical in profile and not count_match(profile[canonical], rule):
            return False, f"{canonical.split('.')[-1]}_out_of_range"
    if item.get("status") in {"rejected", "deprecated"} or card.get("status") in {"rejected", "deprecated"}:
        return False, f"status_{item.get('status', card.get('status'))}"
    if renderer:
        if norm(renderer) not in renderer_map(registry):
            return False, "renderer_unknown"
        if norm(renderer) not in {norm(x) for x in card.get("renderer_options", [])}:
            return False, "renderer_mismatch"
    forbidden = {norm(x) for x in card.get("not_recommended_when", [])}
    hit = sorted(flag for flag in constraint_flags(args) if norm(flag) in forbidden)
    if hit:
        return False, "not_recommended:" + ",".join(hit)
    return True, "eligible"


def fit_score(item: dict, card: dict, args: argparse.Namespace, renderer: str | None) -> tuple[int, list[str], dict]:
    score = 0
    reasons: list[str] = []
    components: dict[str, int] = {}
    query_words = words(" ".join([args.task or "", args.message or "", args.density or "", args.annotation_burden or ""]))
    overlap = len(query_words & card_blob(card, item))
    components["semantic_overlap"] = min(overlap, 4)
    score += components["semantic_overlap"]
    if overlap:
        reasons.append(f"semantic_overlap={overlap}")
    if renderer:
        score += 3
        components["renderer"] = 3
        reasons.append("renderer_capability_match")
    if args.density and args.density in {"sparse", "moderate", "dense"}:
        declared = str(card.get("layout", {}).get("density_strategy", ""))
        if args.density in declared or (args.density == "dense" and "compact" in declared):
            score += 2
            components["density"] = 2
            reasons.append("density_fit")
    if args.message and args.message.lower() == str(card.get("message_type", "")).lower():
        score += 2
        components["message"] = 2
        reasons.append("message_type_match")
    if args.annotation_burden == "low" and len(card.get("annotation_strategy", [])) <= 3:
        score += 1
        components["annotation_burden"] = 1
        reasons.append("annotation_burden_fit")
    if args.publication_width == "single" and str(card.get("layout", {}).get("aspect_ratio", "")) not in {"2", "journal_target"}:
        score += 1
        components["single_width"] = 1
        reasons.append("single_panel_width_fit")
    if args.split == "condition" and any("condition" in str(v) for v in card.get("encoding", {}).values()):
        score += 1
        components["condition_split"] = 1
        reasons.append("condition_split_fit")
    if card.get("confidence") == "high":
        score += 1
        components["confidence"] = 1
        reasons.append("higher_confidence")
    return score, reasons or ["eligible_default"], components


def query(*, task: str = "", domain: str | None = None, message: str = "", density: str | None = None,
          renderer: str | None = None, data_structure: list[str] | None = None, paired: str | None = None,
          coordinates: str | None = None, publication_width: str | None = None, split: str | None = None,
          cluster: str | None = None, annotation_burden: str | None = None, avoid: list[str] | None = None,
          rows: int | None = None, columns: int | None = None, data_profile: dict | None = None) -> dict:
    profile = dict(data_profile or {})
    if rows is not None:
        profile.setdefault("matrix", {})["n_rows"] = rows
    if columns is not None:
        profile.setdefault("matrix", {})["n_columns"] = columns
    args = argparse.Namespace(task=task, domain=domain, message=message, density=density, renderer=renderer,
                              data_structure=data_structure or [], paired=paired, coordinates=coordinates,
                              publication_width=publication_width, split=split, cluster=cluster,
                              annotation_burden=annotation_burden, avoid=avoid or [], rows=rows, columns=columns,
                              data_profile=profile)
    index = load(ROOT / "patterns/index.yaml")
    registry = load(ROOT / "renderer-registry.yaml")["renderers"]
    renderer_canonical = renderer_map(registry).get(norm(renderer)) if renderer else None
    candidates, filtered = [], []
    for item in index["patterns"]:
        card = load(ROOT / "patterns" / item["path"])
        ok, reason = eligible(item, card, args, renderer, registry)
        if not ok:
            filtered.append({"pattern_id": item["pattern_id"], "reason": reason})
            continue
        design_fit, reasons, components = fit_score(item, card, args, renderer_canonical)
        candidates.append({"pattern_id": item["pattern_id"], "path": item["path"], "eligibility": 1,
                           "design_fit": design_fit, "design_fit_components": components,
                           "total": 10 + design_fit, "selection_reasons": reasons})
    candidates.sort(key=lambda x: (-x["total"], x["pattern_id"]))
    capability = "not_requested" if not renderer else ("known" if renderer_canonical else "unknown")
    return {"query": vars(args), "renderer_capability": capability,
            "eligibility_filter": {"eligible_count": len(candidates), "constraints": sorted(constraint_flags(args)), "excluded": filtered},
            "candidates": candidates}


def retrieve(args: argparse.Namespace) -> dict:
    return query(task=args.task or "", domain=args.domain, message=args.message or "", density=args.density,
                 renderer=args.renderer, data_structure=args.data_structure, paired=args.paired,
                 coordinates=args.coordinates, publication_width=args.publication_width, split=args.split,
                 cluster=args.cluster, annotation_burden=args.annotation_burden, avoid=args.avoid,
                 rows=args.rows, columns=args.columns,
                 data_profile=json.loads(args.data_profile_json) if args.data_profile_json else None)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--task")
    parser.add_argument("--domain")
    parser.add_argument("--message")
    parser.add_argument("--density", choices=["sparse", "moderate", "dense"])
    parser.add_argument("--renderer")
    parser.add_argument("--data-structure", action="append", default=[])
    parser.add_argument("--paired", choices=["true", "false", "unknown"])
    parser.add_argument("--coordinates", choices=["present", "absent", "unknown"])
    parser.add_argument("--publication-width", choices=["single", "wide"])
    parser.add_argument("--split", choices=["none", "condition", "modality"])
    parser.add_argument("--cluster", choices=["none", "rows", "columns", "both"])
    parser.add_argument("--annotation-burden", choices=["low", "moderate", "high"])
    parser.add_argument("--rows", type=int)
    parser.add_argument("--columns", type=int)
    parser.add_argument("--data-profile-json", help="canonical Data Profile as a JSON object")
    parser.add_argument("--avoid", action="append", default=[])
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    result = retrieve(args)
    if args.json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
    else:
        for candidate in result["candidates"]:
            print(f"{candidate['pattern_id']} total={candidate['total']} fit={candidate['design_fit']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
