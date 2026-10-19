#!/usr/bin/env python3
"""Validate a pre-render Figure Design Spec and its cross-references."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import re
import sys
import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from reference_modes import design_reference_mode
from reference_paths import resolve_reference_path
SCHEMA = ROOT / "schemas/figure-design-spec.schema.yaml"

_text_spec = importlib.util.spec_from_file_location("biofigure_text_policy", ROOT / "scripts/figure_text_policy.py")
_text_module = importlib.util.module_from_spec(_text_spec)
assert _text_spec and _text_spec.loader
_text_spec.loader.exec_module(_text_module)

_cell_spec = importlib.util.spec_from_file_location('biofigure_design_cell_geometry', ROOT / 'scripts/heatmap_geometry.py')
_cell_module = importlib.util.module_from_spec(_cell_spec)
_cell_spec.loader.exec_module(_cell_module)

_ref_spec = importlib.util.spec_from_file_location("biofigure_retrieve_references", ROOT / "scripts/retrieve_references.py")
_ref_module = importlib.util.module_from_spec(_ref_spec)
assert _ref_spec and _ref_spec.loader
_ref_spec.loader.exec_module(_ref_module)
retrieve_references = _ref_module.retrieve

_cp_spec = importlib.util.spec_from_file_location("biofigure_checkpoint_validator", ROOT / "scripts/validate_checkpoints.py")
_cp_module = importlib.util.module_from_spec(_cp_spec)
assert _cp_spec and _cp_spec.loader
_cp_spec.loader.exec_module(_cp_module)
validate_reproduction_receipt = _cp_module.validate_reproduction_receipt
_auth_spec = importlib.util.spec_from_file_location("biofigure_authorize_render", ROOT / "scripts/authorize_render.py")
_auth_module = importlib.util.module_from_spec(_auth_spec)
assert _auth_spec and _auth_spec.loader
_auth_spec.loader.exec_module(_auth_module)


_stats_spec = importlib.util.spec_from_file_location("biofigure_statistics_plan", ROOT / "scripts/validate_statistics_plan.py")
_stats_module = importlib.util.module_from_spec(_stats_spec)
assert _stats_spec and _stats_spec.loader
_stats_spec.loader.exec_module(_stats_module)


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


def validate_primary_source_reference(reference: dict, project_root: Path | None = None,
                                      spec_path: Path | None = None,
                                      reference_mode: str | None = None) -> tuple[list[str], bool]:
    """Validate a task-locked source figure without requiring an unrelated atlas precedent."""
    lock_path = reference.get("primary_source_lock")
    if not lock_path:
        return [], False
    try:
        path = resolve_reference_path(lock_path, document_path=spec_path, project_root=project_root)
    except ValueError as exc:
        return [f'reference_evidence.primary_source_lock invalid: {exc}'], False
    if not path.is_file():
        return ["reference_evidence.primary_source_lock file missing"], False
    try:
        locked = load(path)
        errors = validate_reproduction_receipt(str(path), root=project_root, reference_mode=reference_mode)
        source = reference.get("primary_source")
        if not isinstance(source, dict) or source != locked.get("primary_source"):
            errors.append("reference_evidence primary source metadata differs from primary source lock")
        return [f"primary source lock: {error}" for error in errors], not errors
    except Exception as exc:
        return [f"reference_evidence.primary_source_lock unreadable: {exc}"], False


def validate_project_style_contract(doc: dict, spec_path: Path | None = None) -> list[str]:
    contract = doc.get("project_style_contract")
    if not isinstance(contract, dict):
        return ["project_style_contract must be a mapping"]
    required = ("registry_path", "registry_sha256", "project_id", "palette_id",
                "semantic_colors", "reuse_policy", "exception_basis")
    errors = [f"project_style_contract.{key} is required" for key in required if key not in contract]
    if errors:
        return errors
    raw_path = Path(str(contract["registry_path"])).expanduser()
    if not raw_path.is_absolute() and spec_path is not None:
        raw_path = spec_path.parent / raw_path
    if not raw_path.is_file():
        return ["project_style_contract.registry_path file missing"]
    digest = hashlib.sha256(raw_path.read_bytes()).hexdigest()
    if contract.get("registry_sha256") != digest:
        errors.append("project_style_contract.registry_sha256 differs from project style registry")
    try:
        registry = load(raw_path)
    except Exception as exc:
        return errors + [f"project_style_contract.registry_path unreadable: {exc}"]
    if not isinstance(registry, dict):
        return errors + ["project_style_contract registry must be a mapping"]
    if contract.get("project_id") != registry.get("project_id"):
        errors.append("project_style_contract.project_id differs from project style registry")
    palette = registry.get("palette", {})
    if contract.get("palette_id") != palette.get("palette_id"):
        errors.append("project_style_contract.palette_id differs from project style registry")
    if contract.get("semantic_colors") != palette.get("semantic_colors"):
        errors.append("project_style_contract.semantic_colors differs from project style registry")
    if contract.get("reuse_policy") != "exact_semantic_mapping":
        errors.append("project_style_contract.reuse_policy must be exact_semantic_mapping")
    font = doc.get("font_contract", {})
    typography = registry.get("typography", {})
    if isinstance(font, dict) and font:
        if font.get("family") != typography.get("family"):
            errors.append("project_style_contract typography family differs from project style registry")
        if font.get("size_roles_pt") != typography.get("size_roles_pt"):
            errors.append("project_style_contract typography roles differ from project style registry")
    size = doc.get("output_size", {})
    allowed = registry.get("size_system", {}).get("allowed_classes", [])
    if isinstance(size, dict) and size and size.get("size_class") not in allowed:
        errors.append("project_style_contract output size class is not allowed by project style registry")
    exception = contract.get("exception_basis")
    if not isinstance(exception, str):
        errors.append("project_style_contract.exception_basis must be a string")
    return errors


def validate_learned_source_reference(reference: dict, pattern: str) -> tuple[list[str], bool]:
    """Allow an exact learned source to define a pattern absent from the old catalog.

    This binds current materials and a declared direct source view. It does not
    certify the view's aesthetic judgment or promote the method's reuse status.
    """
    if not str(pattern).startswith('LEARNED-'):
        return [], False
    errors = []
    binding = reference.get('learned_source_reference', {})
    method_id = binding.get('method_id')
    if not method_id or pattern != 'LEARNED-' + str(method_id) or reference.get('selected_method_case_id') != method_id:
        return ['learned native pattern must bind the exact selected learned method'], False
    try:
        from retrieve_learned_methods import retrieve
        entry = retrieve('', case_id=method_id)['results'][0]
    except (ValueError, OSError, KeyError) as exc:
        return ['learned native source unavailable: ' + str(exc)], False
    if (entry['missing_material'] or entry['source_record_changed'] or entry['changed_bound_material']
            or binding.get('source_record_sha256') != entry['source_sha256']
            or binding.get('read_hashes') != entry['current_read_hashes']):
        errors.append('learned native source/read set missing, stale or incomplete')
    asset = binding.get('opened_source_asset', {})
    path = str(asset.get('path', ''))
    if (Path(path).suffix.lower() not in {'.png', '.jpg', '.jpeg', '.webp', '.avif', '.svg', '.pdf'}
            or path not in entry['current_read_hashes'] or asset.get('sha256') != entry['current_read_hashes'].get(path)
            or asset.get('original_size_viewed') is not True):
        errors.append('learned native reference requires an opened, hash-bound source image from its read set')
    # Adoption/data-unit/defect handling is independently checked against the
    # invocation receipt by validate_preparation_receipt; no fixed replay waiver.
    return errors, not errors


def validate_source_panel_background(doc: dict) -> list[str]:
    """Permit only the hash-bound SCICASE-071 source's neutral gray triangle.

    Canvas and export white checks remain separate. This narrow source-derived
    exception does not permit arbitrary colored panels or claim visual fidelity.
    """
    background = doc.get("background_contract", {})
    if not isinstance(background, dict) or str(background.get("panel", "")).upper() == "#FFFFFF":
        return []
    prefix = "source_panel_background_contract"
    contract = doc.get(prefix)
    if not isinstance(contract, dict):
        return ["background_contract.panel must be #FFFFFF unless a source-derived gray panel contract validates"]
    errors = []
    panel = str(background.get("panel", "")).upper()
    if panel != "#EBEBEB" or str(contract.get("color", "")).upper() != panel:
        errors.append(f"{prefix}.color must match panel and be the source neutral gray #EBEBEB")
    if not isinstance(contract.get("reason"), str) or not contract["reason"].strip():
        errors.append(f"{prefix}.reason must be a non-empty source-derived explanation")
    reference = doc.get("reference_evidence", {})
    if not isinstance(reference, dict):
        reference = {}
    binding = reference.get("learned_source_reference", {})
    if not isinstance(binding, dict):
        binding = {}
    if (binding.get("method_id") != "SCICASE-071"
            or reference.get("selected_method_case_id") != "SCICASE-071"
            or doc.get("selected_pattern") != "LEARNED-SCICASE-071"):
        errors.append(f"{prefix} is limited to the original SCICASE-071 ternary panel")
    asset = contract.get("source_asset")
    original = binding.get("original_source_asset")
    if not isinstance(asset, dict) or not isinstance(original, dict):
        return errors + [f"{prefix}.source_asset and original_source_asset hash binding are required"]
    expected_path = "benchmark/library/scidraw/sources/ternary_03.png"
    if (asset.get("path") != expected_path or original.get("path") != expected_path
            or asset.get("sha256") != original.get("sha256")
            or original.get("original_size_viewed") is not True):
        errors.append(f"{prefix}.source_asset must match the viewed original SCICASE-071 image binding")
    raw_path = asset.get("path")
    if not isinstance(raw_path, str) or not raw_path.strip():
        return errors + [f"{prefix}.source_asset.path is required"]
    path = (ROOT / raw_path).resolve()
    if not path.is_relative_to(ROOT.resolve()) or not path.is_file():
        errors.append(f"{prefix}.source_asset must be an existing file within ROOT")
    else:
        actual_sha256 = hashlib.sha256(path.read_bytes()).hexdigest()
        if asset.get("sha256") != actual_sha256:
            errors.append(f"{prefix}.source_asset.sha256 differs from current source image")
    return errors


def validate_source_typography(doc: dict, schema: dict) -> list[str]:
    """Validate an explicit, viewed-source hierarchy for reproduction only.

    This preserves semantic roles; it does not waive minimum text size,
    embedded-face checks, collision checks, or actual final-PDF review.
    """
    prefix = "source_typography_contract"
    contract = doc.get(prefix)
    if not isinstance(contract, dict):
        return [f"{prefix} must be a mapping"]
    errors = []
    reference = doc.get("reference_evidence", {})
    reference = reference if isinstance(reference, dict) else {}
    request = reference.get("preparation_request", {})
    binding = reference.get("learned_source_reference", {})
    request = request if isinstance(request, dict) else {}
    binding = binding if isinstance(binding, dict) else {}
    method = binding.get("method_id")
    if (request.get("operation") != "reproduce" or not method
            or reference.get("selected_method_case_id") != method
            or doc.get("selected_pattern") != f"LEARNED-{method}"):
        errors.append(f"{prefix} requires reproduction of the selected learned source")
    if not isinstance(contract.get("reason"), str) or not contract["reason"].strip():
        errors.append(f"{prefix}.reason must explain the source semantic hierarchy")
    basis = contract.get("role_basis", {})
    font = doc.get("font_contract", {})
    font = font if isinstance(font, dict) else {}
    role_sizes = font.get("size_roles_pt", {})
    role_sizes = role_sizes if isinstance(role_sizes, dict) else {}
    text_roles = set(schema.get("font_size_roles_required", [])) | set(role_sizes)
    if (not isinstance(basis, dict) or any(not isinstance(basis.get(role), str)
            or not basis[role].strip() for role in text_roles)):
        errors.append(f"{prefix}.role_basis must explain every declared text role")
    ratio = contract.get("maximum_role_ratio")
    if (not isinstance(ratio, (int, float)) or isinstance(ratio, bool)
            or not math.isfinite(ratio) or not 1 < ratio <= schema.get("font_source_max_role_ratio", 4)):
        errors.append(f"{prefix}.maximum_role_ratio must be finite and within the source-reproduction limit")
    if contract.get("final_pdf_role_sizes_required") is not True:
        errors.append(f"{prefix}.final_pdf_role_sizes_required must be true")
    asset = contract.get("source_asset", {})
    opened = binding.get("opened_source_asset", {})
    asset = asset if isinstance(asset, dict) else {}
    opened = opened if isinstance(opened, dict) else {}
    raw_path = asset.get("path")
    reads = binding.get("read_hashes", {})
    reads = reads if isinstance(reads, dict) else {}
    if (not isinstance(raw_path, str) or not raw_path.strip()
            or Path(raw_path).suffix.lower() not in {".png", ".jpg", ".jpeg", ".webp", ".avif", ".svg", ".pdf"}
            or opened.get("path") != raw_path or opened.get("sha256") != asset.get("sha256")
            or reads.get(raw_path) != asset.get("sha256") or opened.get("original_size_viewed") is not True):
        errors.append(f"{prefix}.source_asset must match a viewed image in the learned-source read set")
    if isinstance(raw_path, str) and raw_path.strip():
        path = (ROOT / raw_path).resolve()
        if not path.is_relative_to(ROOT.resolve()) or not path.is_file():
            errors.append(f"{prefix}.source_asset must be an existing image within ROOT")
        elif hashlib.sha256(path.read_bytes()).hexdigest() != asset.get("sha256"):
            errors.append(f"{prefix}.source_asset.sha256 differs from current source image")
    return errors


def validate_mark_style_contract(doc: dict) -> list[str]:
    """Optional for archived specs; new point/line designs declare actual layer roles."""
    if "mark_style_contract" not in doc:
        return []
    contract = doc["mark_style_contract"]
    if not isinstance(contract, dict) or contract.get("policy_id") != "layer-role-opacity-v1":
        return ["mark_style_contract requires policy_id: layer-role-opacity-v1"]
    layers = contract.get("layers")
    if not isinstance(layers, list) or not layers:
        return ["mark_style_contract.layers must be a non-empty list"]
    roles = {"replicate-point", "hollow-point", "dense-point", "individual-line",
             "summary-line", "uncertainty-band", "distribution-fill", "continuous-bubble", "bar-fill"}
    errors, indexes = [], set()
    for entry in layers:
        if not isinstance(entry, dict):
            errors.append("mark_style_contract layer must be a mapping")
            continue
        allowed = {"layer", "role", "fill_alpha", "edge_alpha", "alpha", "override_reason"}
        if set(entry) - allowed:
            errors.append("mark_style_contract unknown mark field")
        index = entry.get("layer")
        if not isinstance(index, int) or isinstance(index, bool) or index < 1:
            errors.append("mark_style_contract layer index must be a positive integer")
        elif index in indexes:
            errors.append("mark_style_contract duplicate layer index")
        else:
            indexes.add(index)
        if entry.get("role") not in roles:
            errors.append("mark_style_contract unknown mark role")
        for key in ("fill_alpha", "edge_alpha", "alpha"):
            if key in entry:
                value = entry[key]
                if not isinstance(value, (int, float)) or isinstance(value, bool) or not math.isfinite(value) or not 0 <= value <= 1:
                    errors.append(f"mark_style_contract.{key} must be finite and in [0,1]")
        if "override_reason" in entry and (not isinstance(entry["override_reason"], str) or not entry["override_reason"].strip()):
            errors.append("mark_style_contract.override_reason must explain the exception")
    return errors


def validate(doc: dict, schema: dict, spec_path: Path | None = None) -> list[str]:
    errors = [f"missing required key: {key}" for key in schema["required"] if key not in doc]
    try:
        reference_mode = design_reference_mode(doc)
    except ValueError as exc:
        errors.append(str(exc))
        reference_mode = 'reference-guided'
    errors.extend(_cell_module.validate_cell_contract(doc))
    errors.extend(validate_project_style_contract(doc, spec_path))
    errors.extend(validate_mark_style_contract(doc))
    errors.extend(_stats_module.validate_document(doc, spec_path.parent if spec_path else None))
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
        # `inside_top` supports framed source figures; its non-overlap is checked
        # later by the BioFigure layout-box preflight.
        elif legend["place"] not in set(schema.get("legend_place_options", [])):
            errors.append("legend.place must use a supported reserved or direct-label location")
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
    reference = doc.get('reference_evidence', {})
    native_errors, native_source = validate_learned_source_reference(reference if isinstance(reference, dict) else {}, selected)
    errors.extend(native_errors)
    index = load(ROOT / "patterns/index.yaml")
    known_patterns = {x["pattern_id"] for x in index["patterns"]}
    for pattern in candidates or []:
        if pattern not in known_patterns and not (native_source and pattern == selected):
            errors.append(f"unknown pattern: {pattern}")
    registry = load(ROOT / "renderer-registry.yaml")["renderers"]
    renderer = doc.get("renderer")
    selected_card = None
    if selected in known_patterns:
        selected_item = next(x for x in index["patterns"] if x["pattern_id"] == selected)
        selected_card = load(ROOT / "patterns" / selected_item["path"])
    elif native_source:
        query = reference.get('retrieval_query', {})
        selected_card = {'domain': [query.get('domain', '')], 'scientific_task': [doc.get('figure_task', '')],
                         'renderer_options': list(registry)}
    reference = doc.get("reference_evidence")
    if not isinstance(reference, dict):
        errors.append("reference_evidence must be a mapping")
    else:
        required_reference = (schema.get('original_evidence_required', ['preparation_id', 'preparation_request', 'selected_method_case_id', 'retrieval_query'])
                              if reference_mode == 'original' else schema.get("reference_evidence_required", []))
        for key in required_reference:
            if key not in reference:
                errors.append(f"reference_evidence.{key} is required")
        if reference_mode == 'original':
            from design_discovery import discover, validate_review
            request = reference.get('preparation_request', {})
            if isinstance(request, dict):
                errors.extend(validate_review(discover(request, ' '.join(str(request.get(key, '')) for key in ('figure_task', 'figure_family', 'data_shape', 'pattern_id'))), doc))
        preparation_id = reference.get("preparation_id")
        if not isinstance(preparation_id, str) or not re.fullmatch(r"[0-9a-f]{64}", preparation_id):
            errors.append("reference_evidence.preparation_id must be a 64-character preflight receipt hash")
        selected_method = reference.get("selected_method_case_id")
        if not isinstance(selected_method, str) or not selected_method.strip():
            errors.append("reference_evidence.selected_method_case_id must name a preflight candidate")
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
        if reference_mode != 'original':
            atlas_ids = reference.get("selected_atlas_ids")
            source_lock_errors, source_locked = validate_primary_source_reference(reference, spec_path=spec_path, reference_mode=reference_mode)
            errors.extend(source_lock_errors)
            entries_by_id = {}
            if not isinstance(atlas_ids, list) or not all(isinstance(x, str) and x for x in atlas_ids):
                errors.append("reference_evidence.selected_atlas_ids must be a list of non-empty IDs")
            elif not atlas_ids and not (source_locked or native_source):
                errors.append("reference_evidence.selected_atlas_ids must be a non-empty list")
            elif atlas_ids:
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
    analysis = doc.get("reference_analysis")
    if not isinstance(analysis, dict):
        errors.append("reference_analysis must be a mapping completed before rendering")
    else:
        for key in schema.get("reference_analysis_required", []):
            if key not in analysis:
                errors.append(f"reference_analysis.{key} is required")
        for key in ("figure_family", "semantic_purpose"):
            if not isinstance(analysis.get(key), str) or not analysis[key].strip():
                errors.append(f"reference_analysis.{key} must be a non-empty string")
        panels = analysis.get("panels")
        if not isinstance(panels, list) or not panels:
            errors.append("reference_analysis.panels must be a non-empty list")
        else:
            for index, panel in enumerate(panels):
                if not isinstance(panel, dict):
                    errors.append(f"reference_analysis.panels[{index}] must be a mapping")
                    continue
                for key in schema.get("reference_panel_required", []):
                    if not isinstance(panel.get(key), str) or not panel[key].strip():
                        errors.append(f"reference_analysis.panels[{index}].{key} must be a non-empty string")
        elements = analysis.get("elements")
        element_ids = set()
        if not isinstance(elements, list) or not elements:
            errors.append("reference_analysis.elements must be a non-empty list")
        else:
            for index, element in enumerate(elements):
                if not isinstance(element, dict):
                    errors.append(f"reference_analysis.elements[{index}] must be a mapping")
                    continue
                for key in schema.get("reference_element_required", []):
                    if key not in element:
                        errors.append(f"reference_analysis.elements[{index}].{key} is required")
                for key in ("id", "role", "geometry", "position", "data_mapping"):
                    if not isinstance(element.get(key), str) or not element[key].strip():
                        errors.append(f"reference_analysis.elements[{index}].{key} must be a non-empty string")
                if not isinstance(element.get("required"), bool):
                    errors.append(f"reference_analysis.elements[{index}].required must be a boolean")
                element_id = element.get("id")
                if isinstance(element_id, str) and element_id:
                    if element_id in element_ids:
                        errors.append(f"duplicate reference_analysis element id: {element_id}")
                    element_ids.add(element_id)
        relationships = analysis.get("relationships")
        allowed_relationships = set(schema.get("reference_relationship_types", []))
        if not isinstance(relationships, list) or not relationships:
            errors.append("reference_analysis.relationships must be a non-empty list")
        else:
            for index, relationship in enumerate(relationships):
                if not isinstance(relationship, dict):
                    errors.append(f"reference_analysis.relationships[{index}] must be a mapping")
                    continue
                for key in schema.get("reference_relationship_required", []):
                    if not isinstance(relationship.get(key), str) or not relationship[key].strip():
                        errors.append(f"reference_analysis.relationships[{index}].{key} must be a non-empty string")
                if relationship.get("type") not in allowed_relationships:
                    errors.append(f"reference_analysis.relationships[{index}].type is invalid")
                for endpoint in ("from", "to"):
                    value = relationship.get(endpoint)
                    if isinstance(value, str) and value and element_ids and value not in element_ids:
                        errors.append(f"reference_analysis.relationships[{index}].{endpoint} references unknown element: {value}")
        topology = analysis.get("spatial_topology")
        if not isinstance(topology, dict):
            errors.append("reference_analysis.spatial_topology must be a mapping")
        else:
            for key in schema.get("reference_spatial_topology_required", []):
                value = topology.get(key)
                if not isinstance(value, (str, list)) or not value or (isinstance(value, list) and not all(isinstance(x, str) and x for x in value)):
                    errors.append(f"reference_analysis.spatial_topology.{key} must be a non-empty string or list of strings")
        for key in ("required_structures", "forbidden_substitutions"):
            value = analysis.get(key)
            if not isinstance(value, list) or not value or not all(isinstance(x, str) and x.strip() for x in value):
                errors.append(f"reference_analysis.{key} must be a non-empty list of strings")
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
        for key in schema.get("output_size_required", []):
            if key not in size:
                errors.append(f"output_size.{key} is required")
        for key in ("width_mm", "height_mm"):
            value = size.get(key)
            if not isinstance(value, (int, float)) or isinstance(value, bool) or value <= 0:
                errors.append(f"output_size.{key} must be positive")
        if not isinstance(size.get("formats"), list) or not size["formats"]:
            errors.append("output_size.formats must be non-empty")
        elif any(str(x).lower() not in {"pdf", "svg", "png", "tiff"} for x in size["formats"]):
            errors.append("output_size.formats contains unsupported format")
        size_class = size.get("size_class")
        classes = schema.get("publication_size_classes", {})
        if size_class not in classes:
            errors.append("output_size.size_class must use a supported publication column class")
        elif all(isinstance(size.get(k), (int, float)) and not isinstance(size.get(k), bool)
                 for k in ("width_mm", "height_mm")):
            rule = classes[size_class]
            if not rule["min_width_mm"] <= size["width_mm"] <= rule["max_width_mm"]:
                errors.append(
                    f"output_size.{size_class} width must be {rule['min_width_mm']}..{rule['max_width_mm']} mm")
            if size["height_mm"] > rule["max_height_mm"]:
                errors.append(
                    f"output_size.{size_class} height exceeds {rule['max_height_mm']} mm")
        if size.get("size_basis") != schema.get("output_size_basis", "final_physical_output"):
            errors.append("output_size.size_basis must be final_physical_output")
        rationale = size.get("size_rationale")
        if not isinstance(rationale, dict):
            errors.append("output_size.size_rationale must be a mapping")
        else:
            for key in schema.get("size_rationale_required", []):
                if key not in rationale:
                    errors.append(f"output_size.size_rationale.{key} is required")
            panel_count = rationale.get("panel_count")
            longest = rationale.get("longest_label_chars")
            density = rationale.get("density")
            if type(panel_count) is not int or panel_count < 1:
                errors.append("output_size.size_rationale.panel_count must be a positive integer")
            if type(longest) is not int or longest < 0:
                errors.append("output_size.size_rationale.longest_label_chars must be a non-negative integer")
            if density not in schema.get("size_density_options", []):
                errors.append("output_size.size_rationale.density must be low, medium, or high")
            panels = doc.get("reference_analysis", {}).get("panels", [])
            if isinstance(panels, list) and panels and type(panel_count) is int and panel_count != len(panels):
                errors.append("output_size.size_rationale.panel_count must equal reference_analysis panel count")
            allowed_text = doc.get("text_contract", {}).get("allowed_text", [])
            if isinstance(allowed_text, list) and allowed_text and type(longest) is int:
                actual_longest = max(len(str(label)) for label in allowed_text)
                if longest != actual_longest:
                    errors.append("output_size.size_rationale.longest_label_chars must equal the text allowlist maximum")
            if type(panel_count) is int and type(longest) is int and density in {"low", "medium", "high"}:
                recommended = ("double-column" if density == "high" or panel_count >= 4
                               else "one-and-half-column" if density == "medium" or panel_count >= 3 or longest > 24
                               else "single-column")
                if rationale.get("recommended_class") != recommended:
                    errors.append(f"output_size.size_rationale.recommended_class must be {recommended}")
                override = rationale.get("override_basis")
                if not isinstance(override, str):
                    errors.append("output_size.size_rationale.override_basis must be a string")
                    override = ""
                if size_class != recommended and not override.strip():
                    errors.append("output_size.size_class must equal recommended_class unless override_basis cites a journal or user constraint")
            if not isinstance(rationale.get("selection_reason"), str) or not rationale["selection_reason"].strip():
                errors.append("output_size.size_rationale.selection_reason must be non-empty")
            if size_class == "custom" and not str(rationale.get("override_basis") or "").strip():
                errors.append("output_size custom size requires a journal or user override_basis")
    delivery = doc.get("deliverable_contract")
    if isinstance(delivery, dict):
        targets = {"quick-png": ["png"], "paper-pdf": ["pdf", "png"], "paper-composite": ["pdf", "svg", "png"], "editable-vector": ["svg", "pdf", "png"], "tiff-submission": ["tiff", "png"]}
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
        if contract in {"layout_contract", "background_contract"} and any(not isinstance(v, str) or not v.strip() for v in value.values()):
            errors.append(f"{contract} values must be non-empty strings")
    background = doc.get("background_contract")
    if isinstance(background, dict):
        for key in ("canvas", "export"):
            if str(background.get(key, "")).upper() != "#FFFFFF":
                errors.append(f"background_contract.{key} must be #FFFFFF")
        errors.extend(validate_source_panel_background(doc))
    font = doc.get("font_contract")
    if isinstance(font, dict) and font.get("family") not in {"Helvetica", "Arial"}:
        errors.append("font_contract.family must be Helvetica or Arial")
    if isinstance(font, dict):
        for key in ("family", "resolved_font_file", "fallback_policy", "warning_policy",
                    "all_layers_inherit_policy", "rendered_face_check", "size_basis"):
            if not isinstance(font.get(key), str) or not font[key].strip():
                errors.append(f"font_contract.{key} must be a non-empty string")
        if font.get("resolved_font_file") in {"", "unknown", "unresolved", None}:
            errors.append("font_contract.resolved_font_file must record a resolved file or runtime resolution method")
        if font.get("all_layers_inherit_policy") != "fail_if_any_layer_unverified":
            errors.append("font_contract.all_layers_inherit_policy must fail if any layer is unverified")
        minimum = font.get("minimum_final_text_pt")
        if (not isinstance(minimum, (int, float)) or isinstance(minimum, bool)
                or minimum < schema.get("font_minimum_final_text_pt", 5)):
            errors.append("font_contract.minimum_final_text_pt must be at least 5 pt at final output size")
        if font.get("size_basis") != schema.get("font_size_basis", "final_output_size"):
            errors.append("font_contract.size_basis must be final_output_size")
        roles = font.get("size_roles_pt")
        required_roles = schema.get("font_size_roles_required", [])
        if not isinstance(roles, dict):
            errors.append("font_contract.size_roles_pt must be a mapping")
        else:
            for role in required_roles:
                if role not in roles:
                    errors.append(f"font_contract.size_roles_pt.{role} is required")
            for role, size in roles.items():
                if (not isinstance(size, (int, float)) or isinstance(size, bool)
                      or not math.isfinite(size) or not isinstance(minimum, (int, float)) or size < minimum):
                    errors.append(f"font_contract.size_roles_pt.{role} is below minimum_final_text_pt")
            numeric = [size for size in roles.values()
                       if isinstance(size, (int, float)) and not isinstance(size, bool) and math.isfinite(size)]
            maximum_ratio = schema.get("font_max_role_ratio", 1.6)
            if "source_typography_contract" in doc:
                source_errors = validate_source_typography(doc, schema)
                errors.extend(source_errors)
                if not source_errors:
                    maximum_ratio = doc["source_typography_contract"]["maximum_role_ratio"]
            if numeric and isinstance(minimum, (int, float)) and max(numeric) > minimum * maximum_ratio:
                errors.append("font_contract size hierarchy exceeds allowed final-size ratio")
            if all(isinstance(roles.get(role), (int, float)) and not isinstance(roles.get(role), bool)
                   for role in ("axis_text", "axis_title")) and roles["axis_title"] < roles["axis_text"]:
                errors.append("font_contract axis_title must be at least axis_text")
            if all(isinstance(roles.get(role), (int, float)) and not isinstance(roles.get(role), bool)
                   for role in ("axis_title", "panel_label")) and roles["panel_label"] < roles["axis_title"]:
                errors.append("font_contract panel_label must be at least axis_title")
    target = doc.get("design_target")
    if not isinstance(target, dict):
        errors.append("design_target must bind a viewed reference to executable design choices")
    else:
        if reference_mode != "original" and (not isinstance(target.get("reference"), str) or not target["reference"].strip()):
            errors.append("design_target.reference must identify a source figure or user attachment")
        if reference_mode != "original" and target.get("reference_opened") is not True:
            errors.append("design_target.reference_opened must be true; inaccessible reference is not verified")
        for key in ("hierarchy", "geometry", "palette", "typography", "marks", "annotation"):
            choice = target.get(key)
            if not isinstance(choice, dict) or any(not isinstance(choice.get(k), str) or not choice[k].strip()
                    for k in ("observation", "implementation", "difference_reason")):
                errors.append(f"design_target.{key} needs observation, implementation and difference_reason")
    text_contract = doc.get("text_contract")
    errors.extend(_text_module.validate_footer_contract(text_contract))
    if not isinstance(text_contract, dict):
        errors.append("text_contract must declare allowed_text and allow_headings before rendering")
    else:
        labels = text_contract.get("allowed_text")
        if not isinstance(labels, list) or not labels or not all(isinstance(x, str) and x.strip() for x in labels):
            errors.append("text_contract.allowed_text must contain approved labels, units and tick text")
        if isinstance(labels, list):
            errors.extend(_text_module.validate_figure_text(labels))
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
    parser.add_argument("--preparation-receipt", type=Path)
    parser.add_argument("--issue-render-authorization", type=Path)
    parser.add_argument("--source", type=Path, action="append", default=[])
    args = parser.parse_args(argv)
    try:
        doc = load(args.path)
        schema = load(SCHEMA)
    except Exception as exc:
        print("DESIGN_SPEC_VALIDATION_FAIL")
        print(str(exc))
        return 1
    errors = validate(doc if isinstance(doc, dict) else {}, schema, spec_path=args.path)
    if args.preparation_receipt and not errors:
        errors.extend(_cp_module.validate_preparation_receipt(str(args.preparation_receipt), doc))
    if args.issue_render_authorization and (not args.preparation_receipt or not args.source):
        errors.append("authorization requires --preparation-receipt and at least one --source")
    if errors:
        print("DESIGN_SPEC_VALIDATION_FAIL")
        print("\n".join(errors))
        return 1
    print("DESIGN_SPEC_VALIDATION_OK")
    if args.issue_render_authorization:
        try:
            issued = _auth_module.issue(args.preparation_receipt, args.path, args.source,
                                        args.issue_render_authorization)
            print("RENDER_AUTHORIZATION_ISSUED " + issued["authorization_id"])
        except Exception as exc:
            print("RENDER_AUTHORIZATION_FAIL")
            print(str(exc))
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
