#!/usr/bin/env python3
"""Validate one BioFigure Pattern Card or all cards in patterns/index.yaml."""
from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys
import yaml

ROOT = Path(__file__).resolve().parents[1]
SCHEMA = ROOT / "schemas/pattern-card.schema.yaml"
INDEX = ROOT / "patterns/index.yaml"
SOURCE_INDEX = ROOT / "references/source-index.json"
TOP_JOURNAL_CORPUS = ROOT / "atlas/top-journal-corpus.yaml"
REGISTRY = ROOT / "renderer-registry.yaml"
PROFILE_KEYS = {"n_observations", "n_features", "n_groups", "n_samples", "n_conditions", "n_modalities", "n_panels", "n_regions", "n_chromosomes", "n_labels", "matrix.n_rows", "matrix.n_columns", "single_cell.n_cells", "single_cell.n_cell_types", "genomic.n_regions", "genomic.n_tracks", "genomic.n_chromosomes", "labels.n_labels", "labels.max_label_length"}


def load(path: Path):
    with path.open(encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def validate(path: Path, required: list[str], statuses: set[str], confidences: set[str], source_ids: set[str], atlas_ids: set[str], renderers: set[str], components: set[str]) -> list[str]:
    errors: list[str] = []
    try:
        doc = load(path)
    except Exception as exc:  # pragma: no cover - surfaced as a CLI diagnostic
        return [f"{path}: YAML error: {exc}"]
    if not isinstance(doc, dict):
        return [f"{path}: card must be a mapping"]
    for key in required:
        if key not in doc:
            errors.append(f"{path}: missing required key {key}")
    if not isinstance(doc.get("version"), str):
        errors.append(f"{path}: version must be a string")
    if doc.get("status") not in statuses:
        errors.append(f"{path}: invalid status {doc.get('status')!r}")
    if doc.get("confidence") not in confidences:
        errors.append(f"{path}: invalid confidence {doc.get('confidence')!r}")
    provenance = doc.get("provenance")
    if not isinstance(provenance, dict) or "created_from" not in provenance:
        errors.append(f"{path}: provenance.created_from is required")
    for ref in list(doc.get("references", [])) + list(provenance.get("created_from", []) if isinstance(provenance, dict) else []):
        if str(ref).startswith("source-index://") and str(ref).split("//", 1)[1] not in source_ids:
            errors.append(f"{path}: unknown source reference {ref}")
        if str(ref).startswith("atlas://") and str(ref).split("//", 1)[1] not in atlas_ids:
            errors.append(f"{path}: unknown atlas reference {ref}")
    for renderer in doc.get("renderer_options", []):
        if renderer not in renderers:
            errors.append(f"{path}: unknown renderer {renderer}")
    for component in doc.get("optional_components", []):
        if not isinstance(component, str) or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", component):
            errors.append(f"{path}: component ID must be kebab-case: {component}")
        elif component not in components:
            errors.append(f"{path}: unknown component {component}")
    applicable = doc.get("applicable_when")
    if not isinstance(applicable, dict):
        errors.append(f"{path}: applicable_when must be a mapping")
    elif "data_profile" in applicable and not isinstance(applicable["data_profile"], dict):
        errors.append(f"{path}: applicable_when.data_profile must be a mapping")
    elif isinstance(applicable.get("data_profile"), dict):
        for key in applicable["data_profile"]:
            if key not in PROFILE_KEYS:
                errors.append(f"{path}: unknown Data Profile key {key}")
    return errors


def card_paths(path: Path | None) -> list[Path]:
    if path:
        return [path]
    index = load(INDEX)
    return [ROOT / "patterns" / item["path"] for item in index["patterns"]]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", nargs="?", type=Path)
    args = parser.parse_args(argv)
    schema = load(SCHEMA)
    required = schema["required"]
    statuses = set(schema["status_enum"])
    confidences = set(schema["confidence_enum"])
    source_ids = {entry["id"] for entry in load(SOURCE_INDEX)["entries"]}
    atlas_ids = {entry["atlas_id"] for entry in load(TOP_JOURNAL_CORPUS)["entries"]}
    known_pattern_ids = {item["pattern_id"] for item in load(INDEX)["patterns"]}
    renderers = set(load(REGISTRY)["renderers"])
    components: set[str] = set()
    for component_file in (ROOT / "components").glob("*.yaml"):
        components.update((load(component_file) or {}).get("components", {}))
    paths = card_paths(args.path)
    errors = [err for path in paths for err in validate(path, required, statuses, confidences, source_ids, atlas_ids, renderers, components)]
    for entry in load(TOP_JOURNAL_CORPUS)["entries"]:
        for pattern_id in entry.get("patterns", []):
            if pattern_id not in known_pattern_ids:
                errors.append(f"{TOP_JOURNAL_CORPUS}: unknown corpus pattern {pattern_id}")
    if errors:
        print("PATTERN_VALIDATION_FAIL")
        print("\n".join(errors))
        return 1
    print(f"PATTERN_VALIDATION_OK:{len(paths)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
