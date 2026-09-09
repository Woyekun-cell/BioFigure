#!/usr/bin/env python3
"""Validate a pre-render Figure Design Spec and its cross-references."""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import re
import sys
import yaml

ROOT = Path(__file__).resolve().parents[1]
SCHEMA = ROOT / "schemas/figure-design-spec.schema.yaml"

_ref_spec = importlib.util.spec_from_file_location("biofigure_retrieve_references", ROOT / "scripts/retrieve_references.py")
_ref_module = importlib.util.module_from_spec(_ref_spec)
assert _ref_spec and _ref_spec.loader
_ref_spec.loader.exec_module(_ref_module)
retrieve_references = _ref_module.retrieve


def load(path: Path):
    with path.open(encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def norm(value: str) -> str:
    """Normalize controlled vocabulary labels without weakening exact semantics."""
    return re.sub(r"[^a-z0-9]+", "", str(value).lower())


def annotation_value_valid(value) -> bool:
    if isinstance(value, bool):
        return True
    if isinstance(value, str):
        return bool(value.strip())
    if isinstance(value, dict):
        return bool(value) and all(isinstance(key, str) and key and annotation_value_valid(item) for key, item in value.items())
    return False


def validate(doc: dict, schema: dict) -> list[str]:
    errors = [f"missing required key: {key}" for key in schema["required"] if key not in doc]
    contract_requirements_3 = {
        "biology_contract": schema.get("biology_contract_required", []),
        "role_contract": schema.get("role_contract_required", []),
        "backend_lock": schema.get("backend_lock_required", []),
        "deliverable_contract": schema.get("deliverable_contract_required", []),
        "integrity_contract": schema.get("integrity_contract_required", []),
    }
    for contract, keys in contract_requirements_3.items():
        value = doc.get(contract)
        if not isinstance(value, dict):
            errors.append(f"{contract} must be a mapping")
            continue
        for key in keys:
            if key not in value:
                errors.append(f"{contract}.{key} is required")
    biology = doc.get("biology_contract", {})
    if isinstance(biology, dict):
        for key in ("entities", "relationships"):
            if not isinstance(biology.get(key), list) or not biology.get(key):
                errors.append(f"biology_contract.{key} must be a non-empty list")
    role_contract = doc.get("role_contract", {})
    roles = {"QC", "discovery", "comparison", "structure", "mechanism", "validation", "prediction", "robustness-model-evaluation"}
    if isinstance(role_contract, dict) and role_contract.get("primary_role") not in roles:
        errors.append("role_contract.primary_role is invalid")
    for key in ("figure_task", "scientific_message", "selection_reason"):
        if not isinstance(doc.get(key), str) or not doc.get(key, "").strip():
            errors.append(f"{key} must be a non-empty string")
    for key in ("data_contract_summary", "visual_hierarchy", "encoding", "annotation", "legend", "palette_semantics"):
        if not isinstance(doc.get(key), dict):
            errors.append(f"{key} must be a mapping")
        elif not doc[key]:
            errors.append(f"{key} must be non-empty")
    hierarchy = doc.get("visual_hierarchy")
    if isinstance(hierarchy, dict):
        if any(not isinstance(value, str) or not value.strip() for value in hierarchy.values()):
            errors.append("visual_hierarchy values must be non-empty strings")
        for key in ("primary", "secondary"):
            if not isinstance(hierarchy.get(key), str) or not hierarchy[key].strip():
                errors.append(f"visual_hierarchy.{key} must be a non-empty string")
    encoding = doc.get("encoding")
    if isinstance(encoding, dict) and any(not isinstance(key, str) or not isinstance(value, str) or not value.strip() for key, value in encoding.items()):
        errors.append("encoding keys and values must be non-empty strings")
    annotation = doc.get("annotation")
    if isinstance(annotation, dict) and any(not annotation_value_valid(value) for value in annotation.values()):
        errors.append("annotation values must be strings, booleans, or mappings")
    legend = doc.get("legend")
    if isinstance(legend, dict):
        if not isinstance(legend.get("place"), str) or not legend["place"].strip():
            errors.append("legend.place must be a non-empty string")
        elif legend["place"] not in {"outside_plot", "outside_right", "outside_left", "outside_top", "outside_bottom", "outside_or_direct", "shared_outside", "direct", "none"}:
            errors.append("legend.place must reserve space outside dense data or use direct labels")
        if "shared" in legend and not isinstance(legend["shared"], bool):
            errors.append("legend.shared must be a boolean")
    palette = doc.get("palette_semantics")
    if isinstance(palette, dict) and any(not isinstance(value, str) or not value.strip() for value in palette.values()):
        errors.append("palette_semantics values must be non-empty strings")
    summary = doc.get("data_contract_summary")
    if isinstance(summary, dict) and any(isinstance(value, (list, dict, bool)) or value is None for value in summary.values()):
        errors.append("data_contract_summary values must be scalar")
    candidates = doc.get("candidate_patterns")
    if not isinstance(candidates, list) or not candidates or not all(isinstance(x, str) for x in candidates):
        errors.append("candidate_patterns must be a non-empty list of strings")
    selected = doc.get("selected_pattern")
    if not isinstance(selected, str) or not selected:
        errors.append("selected_pattern must be set")
    elif isinstance(candidates, list) and selected not in candidates:
        errors.append("selected_pattern must be one of candidate_patterns")
    index = load(ROOT / "patterns/index.yaml")
    known_patterns = {x["pattern_id"] for x in index["patterns"]}
    for pattern in candidates or []:
        if pattern not in known_patterns:
            errors.append(f"unknown pattern: {pattern}")
    registry = load(ROOT / "renderer-registry.yaml")["renderers"]
    renderer = doc.get("renderer")
    selected_card = None
    if selected in known_patterns:
        selected_item = next(x for x in index["patterns"] if x["pattern_id"] == selected)
        selected_card = load(ROOT / "patterns" / selected_item["path"])
    reference = doc.get("reference_evidence")
    if not isinstance(reference, dict):
        errors.append("reference_evidence must be a mapping")
    else:
        for key in schema.get("reference_evidence_required", []):
            if key not in reference:
                errors.append(f"reference_evidence.{key} is required")
        query = reference.get("retrieval_query")
        if not isinstance(query, dict) or not query:
            errors.append("reference_evidence.retrieval_query must be a non-empty mapping")
        elif set(query) != {"domain", "task", "pattern"} or not all(isinstance(query.get(k), str) and query[k].strip() for k in ("domain", "task", "pattern")):
            errors.append("reference_evidence.retrieval_query requires exactly non-empty domain, task, and pattern strings")
        elif query["pattern"] != selected:
            errors.append("reference_evidence.retrieval_query.pattern must equal selected_pattern")
        elif selected_card is not None:
            if norm(query["task"]) != norm(doc.get("figure_task", "")):
                errors.append("reference_evidence.retrieval_query.task must equal figure_task")
            card_domains = {norm(value) for value in selected_card.get("domain", [])}
            if norm(query["domain"]) not in card_domains:
                errors.append("reference_evidence.retrieval_query.domain must be supported by selected_pattern")
            card_tasks = {norm(value) for value in selected_card.get("scientific_task", [])}
            if norm(query["task"]) not in card_tasks:
                errors.append("reference_evidence.retrieval_query.task must be supported by selected_pattern")
        atlas_ids = reference.get("selected_atlas_ids")
        entries_by_id = {}
        if not isinstance(atlas_ids, list) or not atlas_ids or not all(isinstance(x, str) and x for x in atlas_ids):
            errors.append("reference_evidence.selected_atlas_ids must be a non-empty list")
        else:
            corpus = load(ROOT / "atlas/top-journal-corpus.yaml")
            entries_by_id = {entry["atlas_id"]: entry for entry in corpus.get("entries", [])}
            known_atlas = set(entries_by_id)
            for atlas_id in atlas_ids:
                if atlas_id not in known_atlas:
                    errors.append(f"unknown top-journal atlas reference: {atlas_id}")
            if isinstance(query, dict) and set(query) == {"domain", "task", "pattern"} and all(isinstance(query.get(k), str) for k in query):
                retrieved = retrieve_references(query["domain"], query["task"], query["pattern"], 5)
                eligible_ids = {entry["atlas_id"] for entry in retrieved["references"]}
                for atlas_id in atlas_ids:
                    if atlas_id in known_atlas and atlas_id not in eligible_ids:
                        errors.append(f"reference {atlas_id} is incompatible with retrieval_query")
        for key in ("observed_principles", "transfer_decisions", "rejected_elements"):
            value = reference.get(key)
            if not isinstance(value, list) or not value or not all(isinstance(x, str) and x.strip() for x in value):
                errors.append(f"reference_evidence.{key} must be a non-empty list of strings")
        if isinstance(atlas_ids, list) and atlas_ids and all(x in entries_by_id for x in atlas_ids):
            field_map = {"observed_principles": "visual_observations", "transfer_decisions": "transferable_decisions", "rejected_elements": "do_not_transfer"}
            for spec_field, corpus_field in field_map.items():
                allowed = {item for atlas_id in atlas_ids for item in entries_by_id[atlas_id][corpus_field]}
                supplied = reference.get(spec_field)
                if isinstance(supplied, list) and any(item not in allowed for item in supplied):
                    errors.append(f"reference_evidence.{spec_field} contains unsupported statements")
        if reference.get("evidence_status") != "source-and-visual-reviewed":
            errors.append("reference_evidence.evidence_status must be source-and-visual-reviewed; human approval needs a separate signed artifact")
        supplemental_ids = reference.get("supplemental_case_ids", [])
        if supplemental_ids:
            if not isinstance(supplemental_ids, list) or not all(isinstance(x, str) and x for x in supplemental_ids):
                errors.append("reference_evidence.supplemental_case_ids must be a list of non-empty strings")
            else:
                scidraw = json.loads((ROOT / "atlas/scidraw-derived-corpus.json").read_text(encoding="utf-8"))
                cases_by_id = {item["case_id"]: item for item in scidraw["cases"]}
                for case_id in supplemental_ids:
                    if case_id not in cases_by_id:
                        errors.append(f"unknown supplemental SciDraw case: {case_id}")
                visual_ids = reference.get("supplemental_visual_ids")
                if not isinstance(visual_ids, list) or not all(isinstance(x, str) and x for x in visual_ids):
                    errors.append("reference_evidence.supplemental_visual_ids must be a list of non-empty strings")
                else:
                    known_visuals = {item["visual_id"] for item in scidraw["visuals"]}
                    allowed_visuals = {visual for case_id in supplemental_ids if case_id in cases_by_id for visual in cases_by_id[case_id]["visual_match"]["visual_ids"]}
                    for visual_id in visual_ids:
                        if visual_id not in known_visuals:
                            errors.append(f"unknown supplemental SciDraw visual: {visual_id}")
                        elif visual_id not in allowed_visuals:
                            errors.append(f"supplemental visual {visual_id} is not matched to selected cases")
            for key in ("supplemental_transfer_decisions", "supplemental_rejected_elements"):
                value = reference.get(key)
                if not isinstance(value, list) or not value or not all(isinstance(x, str) and x.strip() for x in value):
                    errors.append(f"reference_evidence.{key} must be a non-empty list of strings")
            if reference.get("supplemental_evidence_status") != "optional-not-ground-truth":
                errors.append("reference_evidence.supplemental_evidence_status must be optional-not-ground-truth")
            if reference.get("source_precedence") != "scientific-contract-over-supplemental":
                errors.append("reference_evidence.source_precedence must be scientific-contract-over-supplemental")
    if not isinstance(renderer, dict):
        errors.append("renderer must be a mapping")
    else:
        backend = renderer.get("backend")
        if not isinstance(backend, str) or backend not in registry:
            errors.append(f"unknown renderer backend: {backend}")
        elif selected_card is not None and backend not in selected_card.get("renderer_options", []):
            errors.append(f"renderer backend {backend} is not supported by selected pattern {selected}")
        if not renderer.get("language"):
            errors.append("renderer.language is required")
        if "packages" in renderer and (not isinstance(renderer["packages"], list) or not all(isinstance(x, str) and x for x in renderer["packages"])):
            errors.append("renderer.packages must be a list of non-empty strings")
        lock = doc.get("backend_lock")
        if isinstance(lock, dict):
            if lock.get("backend") != renderer.get("language"):
                errors.append("backend_lock.backend must equal renderer.language")
            if lock.get("locked") is not True or lock.get("preview_export_qa_same_backend") is not True:
                errors.append("backend_lock must be locked and keep preview/export/QA on one backend")
    size = doc.get("output_size")
    if not isinstance(size, dict):
        errors.append("output_size must be a mapping")
    else:
        for key in ("width_mm", "height_mm"):
            value = size.get(key)
            if not isinstance(value, (int, float)) or isinstance(value, bool) or value <= 0:
                errors.append(f"output_size.{key} must be positive")
        if not isinstance(size.get("formats"), list) or not size["formats"]:
            errors.append("output_size.formats must be non-empty")
        elif any(str(x).lower() not in {"pdf", "svg", "png", "tiff"} for x in size["formats"]):
            errors.append("output_size.formats contains unsupported format")
    delivery = doc.get("deliverable_contract")
    if isinstance(delivery, dict):
        targets = {"quick-png": ["png"], "paper-composite": ["pdf", "svg", "png"], "editable-vector": ["svg", "pdf", "png"], "tiff-submission": ["tiff", "png"]}
        target = delivery.get("target")
        if target not in targets:
            errors.append("deliverable_contract.target is invalid")
        elif [str(x).lower() for x in delivery.get("required_formats", [])] != targets[target]:
            errors.append("deliverable_contract.required_formats does not match target")
        elif isinstance(size, dict) and set(str(x).lower() for x in size.get("formats", [])) != set(targets[target]):
            errors.append("output_size.formats must match deliverable_contract")
    targets = doc.get("critic_targets")
    if not isinstance(targets, dict) or not targets.get("scientific"):
        errors.append("critic_targets.scientific is required")
    elif any(value not in {"required", "optional", "skip"} for value in targets.values()):
        errors.append("critic_targets values must be required, optional, or skip")
    contract_requirements = {
        "layout_contract": schema.get("layout_contract_required", []),
        "font_contract": schema.get("font_contract_required", []),
        "background_contract": schema.get("background_contract_required", []),
        "inspection_plan": schema.get("inspection_plan_required", []),
    }
    for contract, keys in contract_requirements.items():
        value = doc.get(contract)
        if not isinstance(value, dict):
            errors.append(f"{contract} must be a mapping")
            continue
        for key in keys:
            if key not in value:
                errors.append(f"{contract}.{key} is required")
        if contract in {"layout_contract", "font_contract", "background_contract"} and any(not isinstance(v, str) or not v.strip() for v in value.values()):
            errors.append(f"{contract} values must be non-empty strings")
    background = doc.get("background_contract")
    if isinstance(background, dict):
        for key in ("canvas", "panel", "export"):
            if str(background.get(key, "")).upper() != "#FFFFFF":
                errors.append(f"background_contract.{key} must be #FFFFFF")
    font = doc.get("font_contract")
    if isinstance(font, dict) and font.get("family") not in {"Helvetica", "Arial"}:
        errors.append("font_contract.family must be Helvetica or Arial")
    if isinstance(font, dict):
        if font.get("resolved_font_file") in {"", "unknown", "unresolved", None}:
            errors.append("font_contract.resolved_font_file must record a resolved file or runtime resolution method")
        if font.get("all_layers_inherit_policy") != "fail_if_any_layer_unverified":
            errors.append("font_contract.all_layers_inherit_policy must fail if any layer is unverified")
    target = doc.get("design_target")
    if not isinstance(target, dict):
        errors.append("design_target must bind a viewed reference to executable design choices")
    else:
        if not isinstance(target.get("reference"), str) or not target["reference"].strip():
            errors.append("design_target.reference must identify a source figure or user attachment")
        if target.get("reference_opened") is not True:
            errors.append("design_target.reference_opened must be true; inaccessible reference is not verified")
        for key in ("hierarchy", "geometry", "palette", "typography", "marks", "annotation"):
            choice = target.get(key)
            if not isinstance(choice, dict) or any(not isinstance(choice.get(k), str) or not choice[k].strip()
                    for k in ("observation", "implementation", "difference_reason")):
                errors.append(f"design_target.{key} needs observation, implementation and difference_reason")
    text_contract = doc.get("text_contract")
    if not isinstance(text_contract, dict):
        errors.append("text_contract must declare allowed_text and allow_headings before rendering")
    else:
        labels = text_contract.get("allowed_text")
        if not isinstance(labels, list) or not labels or not all(isinstance(x, str) and x.strip() for x in labels):
            errors.append("text_contract.allowed_text must contain approved labels, units and tick text")
        if not isinstance(text_contract.get("allow_headings"), bool):
            errors.append("text_contract.allow_headings must be boolean; default false")
    inspection = doc.get("inspection_plan")
    if isinstance(inspection, dict):
        for key in schema.get("inspection_plan_required", []):
            if inspection.get(key) is not True:
                errors.append(f"inspection_plan.{key} must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    args = parser.parse_args(argv)
    try:
        doc = load(args.path)
        schema = load(SCHEMA)
    except Exception as exc:
        print("DESIGN_SPEC_VALIDATION_FAIL")
        print(str(exc))
        return 1
    errors = validate(doc if isinstance(doc, dict) else {}, schema)
    if errors:
        print("DESIGN_SPEC_VALIDATION_FAIL")
        print("\n".join(errors))
        return 1
    print("DESIGN_SPEC_VALIDATION_OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
