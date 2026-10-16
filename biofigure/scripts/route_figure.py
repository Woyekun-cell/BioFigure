#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, sys
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from reference_modes import resolve_request_mode, code_gate

def load_manifest():
    return yaml.safe_load((ROOT / "manifest.yaml").read_text(encoding="utf-8"))

def route(request: dict, previous_lock: dict | None = None) -> dict:
    reference_mode = resolve_request_mode(request)
    manifest = load_manifest(); axes = manifest["routing_axes"]
    for key in ("primary_domain", "primary_role", "backend", "deliverable"):
        if key not in request: raise ValueError(f"missing {key}")
    backend = request["backend"]
    if not isinstance(backend, str) or backend not in axes["backend"]["values"]:
        raise ValueError("backend must be exactly one of R or Python")
    domain = request["primary_domain"]; role = request["primary_role"]; delivery = request["deliverable"]
    if domain not in axes["domain"]["values"]: raise ValueError(f"unknown domain: {domain}")
    if role not in axes["role"]["values"]: raise ValueError(f"unknown role: {role}")
    if delivery not in axes["deliverable"]["values"]: raise ValueError(f"unknown deliverable: {delivery}")
    secondary_domains = request.get("secondary_domains", [])
    if not isinstance(secondary_domains, list) or any(not isinstance(x, str) for x in secondary_domains):
        raise ValueError("secondary_domains must be a list of domain values")
    domains = [domain] + sorted(set(secondary_domains) - {domain})
    secondary_roles = request.get("secondary_roles", [])
    if not isinstance(secondary_roles, list) or any(x not in axes["role"]["values"] for x in secondary_roles):
        raise ValueError("secondary_roles must use the role vocabulary")
    secondary_roles = sorted(set(secondary_roles))
    bad = [x for x in domains if x not in axes["domain"]["values"]]
    if bad: raise ValueError(f"unknown secondary domains: {bad}")
    required_reference_sources = set() if reference_mode == 'original' else {"reproduction", "top_journal", "scidraw"}
    reference_sources = request.get("reference_sources", sorted(required_reference_sources))
    if not isinstance(reference_sources, list) or (not reference_sources and required_reference_sources) or not all(isinstance(x, str) for x in reference_sources):
        raise ValueError("reference_sources must be a non-empty list")
    unknown_sources = sorted(set(reference_sources) - set(manifest.get("reference_evidence_layers", {})))
    if unknown_sources:
        raise ValueError(f"unknown reference source(s): {unknown_sources}")
    missing_sources = required_reference_sources - set(reference_sources)
    if missing_sources:
        raise ValueError(f"required reference sources cannot be skipped: {sorted(missing_sources)}")
    reference_sources = sorted(set(reference_sources))
    # The manifest is a routing map, not a host-level loading guarantee.
    modules = list(manifest.get("common_dynamic_load", []))
    operation = request.get("operation", "draw")
    phase_routes = manifest.get("phase_dynamic_load", {})
    if operation not in {"select", "draw", "reproduce", "review", "revise"}:
        raise ValueError("operation must be select, draw, reproduce, review, or revise")
    phases = []
    if operation in {"draw", "revise"}:
        phases.append("render")
    if operation == "reproduce":
        phases.extend(["render", "reproduction"])
    if operation == "review":
        phases.append("reference-review")
    if "statistics_required" in request and type(request["statistics_required"]) is not bool:
        raise ValueError("statistics_required must be boolean")
    if request.get("statistics_required") is True:
        phases.append("statistics")
    if request.get("use_personal_style") is True:
        phases.append("user-requested-style")
    for phase in phases:
        modules += phase_routes.get(phase, [])
    modules += [axes["domain"]["values"][x] for x in domains]
    from plan_pangenome_figure import applies as pangenome_applies
    if pangenome_applies(str(request.get('figure_task','')),request.get('pangenome_context')):
        modules += ['references/pangenome-learning.md','references/pangenome-statistics.md','static/core/pangenome-paradigms.json']
    critics = [manifest["specialty_critics"][x] for x in domains if x in manifest["specialty_critics"]]
    selected_reference_layers = {}
    for source in reference_sources:
        layer = manifest["reference_evidence_layers"][source]
        modules += layer.get("load", [])
        if layer.get("critic"):
            critics.append(layer["critic"])
        selected_reference_layers[source] = {key: value for key, value in layer.items() if key in {
            "corpus", "methods", "grammar", "source_compared_methods", "review_evidence",
            "batch2_methods", "batch2_review_evidence", "learning_ten_20260925",
            "learning_ten_methods", "learning_ten_batch2", "learning_ten_batch2_methods",
            "visual_study", "layout_recipes", "retriever", "load", "policy", "precedence"}}
    changed = bool(previous_lock and previous_lock.get("backend") != backend)
    lock_seed = json.dumps({"backend": backend, "domains": domains, "role": role}, sort_keys=True).encode()
    return {"primary_domain": domain, "domains": domains, "primary_role": role, "secondary_roles": secondary_roles,
            "backend_lock": {"backend": backend, "exclusive": True, "lock_id": hashlib.sha256(lock_seed).hexdigest()[:16],
                             "prior_evidence_invalidated": changed, "rerender_required": changed,
                             "preview_export_qa_same_backend": True},
            "deliverable": delivery, "required_formats": axes["deliverable"]["values"][delivery],
            "modules": list(dict.fromkeys(modules)), "critics": list(dict.fromkeys(critics)),
            "reference_evidence_layers": selected_reference_layers, "reference_mode": reference_mode,
            "pre_code_gate": {
                "mandatory": True,
                "status": code_gate(reference_mode),
                "preparation_command": "python3 scripts/prepare_figure.py request.yaml --output preparation-receipt.json",
                "required_sources": sorted(required_reference_sources),
                "must_complete_before_renderer_code": [
                    "analyze current data, scientific question, local Pattern and all design dimensions",
                    "decompose panels, layers, spatial relationships, typography and package responsibilities in reference_analysis",
                    "validate the Design Spec and attach this preparation receipt to CP2",
                ] if reference_mode == 'original' else [
                    "inspect retrieved original-size references and relevant method/package notes",
                    "decompose panels, layers, spatial relationships, typography and package responsibilities in reference_analysis",
                    "validate the Design Spec and attach this preparation receipt to CP2",
                ],
            "reasoning_mode_independent": True,
            "operation": operation,
            }}

def main():
    p=argparse.ArgumentParser(); p.add_argument("request", type=Path); p.add_argument("--previous-lock", type=Path)
    a=p.parse_args(); req=yaml.safe_load(a.request.read_text(encoding='utf-8')); old=yaml.safe_load(a.previous_lock.read_text(encoding='utf-8')) if a.previous_lock else None
    print(json.dumps(route(req, old), ensure_ascii=False, indent=2)); return 0
if __name__ == "__main__": raise SystemExit(main())
