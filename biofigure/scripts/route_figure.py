#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parents[1]

def load_manifest():
    return yaml.safe_load((ROOT / "manifest.yaml").read_text(encoding="utf-8"))

def route(request: dict, previous_lock: dict | None = None) -> dict:
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
    domains = [domain] + request.get("secondary_domains", [])
    secondary_roles = request.get("secondary_roles", [])
    if not isinstance(secondary_roles, list) or any(x not in axes["role"]["values"] for x in secondary_roles):
        raise ValueError("secondary_roles must use the role vocabulary")
    bad = [x for x in domains if x not in axes["domain"]["values"]]
    if bad: raise ValueError(f"unknown secondary domains: {bad}")
    reference_sources = request.get("reference_sources", ["top_journal", "scidraw"])
    if not isinstance(reference_sources, list) or not reference_sources or not all(isinstance(x, str) for x in reference_sources):
        raise ValueError("reference_sources must be a non-empty list")
    unknown_sources = sorted(set(reference_sources) - set(manifest.get("reference_evidence_layers", {})))
    if unknown_sources:
        raise ValueError(f"unknown reference source(s): {unknown_sources}")
    modules = list(manifest.get("always_load", [])) + list(manifest.get("common_dynamic_load", []))
    modules += [axes["domain"]["values"][x] for x in domains]
    critics = [manifest["specialty_critics"][x] for x in domains if x in manifest["specialty_critics"]]
    selected_reference_layers = {}
    for source in reference_sources:
        layer = manifest["reference_evidence_layers"][source]
        modules += layer.get("load", [])
        if layer.get("critic"):
            critics.append(layer["critic"])
        selected_reference_layers[source] = {key: value for key, value in layer.items() if key in {"corpus", "grammar", "retriever", "policy", "precedence"}}
    changed = bool(previous_lock and previous_lock.get("backend") != backend)
    lock_seed = json.dumps({"backend": backend, "domains": domains, "role": role}, sort_keys=True).encode()
    return {"primary_domain": domain, "domains": domains, "primary_role": role, "secondary_roles": secondary_roles,
            "backend_lock": {"backend": backend, "exclusive": True, "lock_id": hashlib.sha256(lock_seed).hexdigest()[:16],
                             "prior_evidence_invalidated": changed, "rerender_required": changed,
                             "preview_export_qa_same_backend": True},
            "deliverable": delivery, "required_formats": axes["deliverable"]["values"][delivery],
            "modules": list(dict.fromkeys(modules)), "critics": list(dict.fromkeys(critics)),
            "reference_evidence_layers": selected_reference_layers}

def main():
    p=argparse.ArgumentParser(); p.add_argument("request", type=Path); p.add_argument("--previous-lock", type=Path)
    a=p.parse_args(); req=yaml.safe_load(a.request.read_text()); old=yaml.safe_load(a.previous_lock.read_text()) if a.previous_lock else None
    print(json.dumps(route(req, old), ensure_ascii=False, indent=2)); return 0
if __name__ == "__main__": raise SystemExit(main())
