#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
from collections import Counter
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
PUBLIC_TEXT_SUFFIXES = {".md", ".json", ".yaml", ".yml", ".toml", ".csv", ".tsv", ".py", ".r"}
SCIDRAW_NODE_MAP = {
    "SCIDRAW-RCS-001": "scidraw-a2dd8d3b52",
    "SCIDRAW-RIDGE-BIPOLAR-001": "scidraw-709e0a8c86",
    "SCIDRAW-PCOA-MARGINAL-001": "scidraw-62b8290bc1",
    "SCIDRAW-TERNARY-001": "scidraw-6be07d3441",
    "SCIDRAW-CORRPLOT-001": "scidraw-9a92615206",
    "SCIDRAW-SWIMMER-001": "scidraw-1a060be0fe",
    "SCIDRAW-CHORD-TRACK-001": "scidraw-fdf13d26d3",
    "SCIDRAW-VOLCANO-GSEA-001": "scidraw-f749086eb5",
}


def zh_count(text: str) -> int:
    return len(re.findall(r"[\u4e00-\u9fff]", text))


def version_snapshot() -> dict[str, str]:
    manifest = yaml.safe_load((ROOT / "manifest.yaml").read_text())
    skill = re.search(r"BioFigure (\d+\.\d+\.\d+)", (ROOT / "SKILL.md").read_text()).group(1)
    readme = re.search(r"BioFigure-(\d+\.\d+\.\d+)", (REPO / "README.md").read_text()).group(1)
    zh = re.search(r"BioFigure (\d+\.\d+\.\d+)", (REPO / "docs/HANDBOOK.zh-CN.md").read_text()).group(1)
    en = re.search(r"BioFigure (\d+\.\d+\.\d+)", (REPO / "docs/HANDBOOK.en.md").read_text()).group(1)
    return {"manifest": manifest["version"], "skill": skill, "readme": readme, "handbook_zh": zh, "handbook_en": en}


def atlas_snapshot(path: Path) -> dict:
    cases = json.loads(path.read_text())["cases"]
    eligible = [x for x in cases if x.get("runtime_status") == "source-compared-png" and x.get("review_status") == "pass"]
    incomplete = [x for x in cases if x.get("runtime_status") == "source-compared-needs-revision"]
    return {
        "total": len(cases),
        "runtime_status": dict(Counter(x.get("runtime_status", "missing") for x in cases)),
        "review_status": dict(Counter(x.get("review_status", "missing") for x in cases)),
        "high_fidelity_eligible": len(eligible),
        "source_compared_excluded": len(incomplete),
        "eligible_missing_png": [x.get("issue", x.get("id")) for x in eligible if not x.get("validated_pngs")],
    }


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def png_pixels(path: Path) -> list[int]:
    payload = path.read_bytes()[:24]
    if payload[:8] != b"\x89PNG\r\n\x1a\n" or payload[12:16] != b"IHDR":
        raise ValueError(f"not a PNG: {path}")
    return list(struct.unpack(">II", payload[16:24]))


def verified_png_errors(cases: list[dict]) -> list[str]:
    errors = []
    for case in cases:
        if case.get("review_status") != "pass":
            continue
        for item in case.get("validated_pngs", []):
            if isinstance(item, str):
                # Legacy benchmark records predate portable path/hash evidence.
                # Their selected public subset is checked separately below.
                continue
            path = REPO / item["path"]
            if not path.is_file():
                errors.append(f"missing:{item['path']}")
            elif item.get("sha256") != sha256(path):
                errors.append(f"hash:{item['path']}")
            elif item.get("pixels") and item["pixels"] != png_pixels(path):
                errors.append(f"pixels:{item['path']}")
    return errors


def scidraw_review_errors(methods: list[dict], evidence: dict) -> list[str]:
    errors = []
    by_id = {case["case_id"]: case for case in evidence["cases"]}
    if {case["id"] for case in methods} != set(by_id):
        return ["case-id-set"]
    for method in methods:
        reviewed = by_id[method["id"]]
        artifact = reviewed["implementation"]
        artifact_path = artifact.get("artifact_path") or artifact.get("artifact")
        path = REPO / artifact_path
        if reviewed.get("review_status") != method.get("review_status"):
            errors.append(f"review-sync:{method['id']}")
        elif not path.is_file():
            errors.append(f"missing:{artifact_path}")
        elif sha256(path) != artifact.get("artifact_sha256"):
            errors.append(f"hash:{artifact_path}")
        elif png_pixels(path) != artifact.get("artifact_pixels"):
            errors.append(f"pixels:{artifact_path}")
    return errors


def machine_specific_references() -> list[str]:
    """Return public text files that expose a user or temporary home path."""
    forbidden = ("/" + "Users/", "/" + "home/", "/var/" + "folders/")
    hits = []
    for path in REPO.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in PUBLIC_TEXT_SUFFIXES:
            continue
        relative = path.relative_to(REPO)
        if any(part in {".git", "work", "__pycache__"} for part in relative.parts):
            continue
        if relative.as_posix().startswith(("biofigure/benchmark/evidence/", "biofigure/library/",
                                          "biofigure/benchmark/library/", "results/full_library_audit/")):
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        if any(token in text for token in forbidden):
            hits.append(relative.as_posix())
    return sorted(hits)


def audit_legacy_source_archive() -> dict:
    import sys
    sys.path.insert(0, str(ROOT / "scripts"))
    from benchmark_core import inventory
    benchmark = inventory(ROOT)
    manifest = yaml.safe_load((ROOT / "manifest.yaml").read_text())
    hot = []
    for rel in ["SKILL.md", *manifest["common_dynamic_load"]]:
        text = (ROOT / rel).read_text()
        hot.append({"path": rel, "zh_chars": zh_count(text)})
    versions = version_snapshot()
    version_ok = versions["manifest"] == versions["skill"] and all(
        x == versions["manifest"]
        for x in (versions["readme"], versions["handbook_zh"], versions["handbook_en"])
    )
    reproduction_data = json.loads((ROOT / "atlas/reproduction-methods.json").read_text())
    scidraw_data = json.loads((ROOT / "atlas/scidraw-source-compared-methods.json").read_text())
    scidraw_evidence = json.loads((ROOT / "atlas/scidraw-review-evidence.json").read_text())
    scidraw_batch2_data = json.loads((ROOT / "atlas/scidraw-batch2-methods.json").read_text())
    scidraw_batch2_evidence = json.loads((ROOT / "atlas/scidraw-batch2-review-evidence.json").read_text())
    reproduction = atlas_snapshot(ROOT / "atlas/reproduction-methods.json")
    scidraw = atlas_snapshot(ROOT / "atlas/scidraw-source-compared-methods.json")
    scidraw_batch2 = atlas_snapshot(ROOT / "atlas/scidraw-batch2-methods.json")
    assets = sorted((REPO / "docs/assets/reproduction-gallery").glob("*.png"))
    scidraw_assets = sorted((REPO / "docs/assets/scidraw-gallery").glob("*.png"))
    scidraw_batch2_assets = sorted((REPO / "docs/assets/scidraw-gallery-batch2").glob("*.png"))
    method_contracts = yaml.safe_load((ROOT / "atlas/family-execution-contracts.yaml").read_text())
    capability_graph = json.loads((ROOT / "atlas/unified-capability-graph.json").read_text())
    methods_by_issue = {
        x["issue"]: x for x in json.loads((ROOT / "atlas/reproduction-methods.json").read_text())["cases"]
    }
    graph_status_mismatches = []
    from sync_capability_status import expected_topjournal_state
    for node in capability_graph["nodes"]:
        match = re.fullmatch(r"topfigure-(\d+)-[0-9a-f]+", node.get("id", ""))
        if not match:
            continue
        visual, reviewed, expected = expected_topjournal_state(node, methods_by_issue)
        if (
            node.get("visual_status") != visual
            or node.get("review_status") != reviewed
            or bool(node.get("high_fidelity_eligible")) != expected
        ):
            graph_status_mismatches.append(node["id"])
    nodes_by_id = {node["id"]: node for node in capability_graph["nodes"]}
    scidraw_by_id = {case["id"]: case for case in scidraw_data["cases"]}
    for case_id, node_id in SCIDRAW_NODE_MAP.items():
        method = scidraw_by_id[case_id]
        node = nodes_by_id[node_id]
        expected = method.get("runtime_status") == "source-compared-png" and method.get("review_status") == "pass"
        if (
            node.get("visual_status") != method.get("runtime_status", "not-run")
            or node.get("review_status") != method.get("review_status", "missing")
            or bool(node.get("high_fidelity_eligible")) != expected
        ):
            graph_status_mismatches.append(node_id)
    for method in scidraw_batch2_data["cases"]:
        node_id = method["graph_node_id"]
        node = nodes_by_id[node_id]
        expected = method.get("runtime_status") == "source-compared-png" and method.get("review_status") == "pass"
        if (
            node.get("visual_status") != method.get("runtime_status", "not-run")
            or node.get("review_status") != method.get("review_status", "missing")
            or bool(node.get("high_fidelity_eligible")) != expected
        ):
            graph_status_mismatches.append(node_id)
    artifact_errors = verified_png_errors(
        reproduction_data["cases"] + scidraw_data["cases"] + scidraw_batch2_data["cases"]
    )
    scidraw_evidence_errors = scidraw_review_errors(scidraw_data["cases"], scidraw_evidence)
    scidraw_batch2_evidence_errors = scidraw_review_errors(
        scidraw_batch2_data["cases"], scidraw_batch2_evidence
    )
    local_path_leaks = machine_specific_references()
    errors = list(benchmark["errors"])
    if not version_ok:
        errors.append("version mismatch")
    if sum(x["zh_chars"] for x in hot) > 8000 or any(x["zh_chars"] > 1200 for x in hot):
        errors.append("hot-load document budget exceeded")
    if reproduction["eligible_missing_png"] or scidraw["eligible_missing_png"] or scidraw_batch2["eligible_missing_png"]:
        errors.append("eligible precedent lacks validated PNG")
    if len(assets) != 8:
        errors.append("public selected gallery must contain 8 PNG files")
    if len(scidraw_assets) != 8:
        errors.append("public SciDraw gallery must contain 8 PNG files")
    if len(scidraw_batch2_assets) != 20:
        errors.append("public SciDraw batch-2 gallery must contain 20 PNG files")
    if artifact_errors:
        errors.append("validated PNG evidence does not match current artifacts")
    if scidraw_evidence_errors:
        errors.append("SciDraw source-comparison evidence is incomplete or stale")
    if scidraw_batch2_evidence_errors:
        errors.append("SciDraw batch-2 source-comparison evidence is incomplete or stale")
    if len(method_contracts.get("families", {})) != 15 or len(method_contracts.get("subtypes", {})) < 8:
        errors.append("low-reasoning method contracts are incomplete")
    expected_pass = (
        reproduction["high_fidelity_eligible"]
        + scidraw["high_fidelity_eligible"]
        + scidraw_batch2["high_fidelity_eligible"]
        + benchmark["track_pass"]["reproduction"]
    )
    if capability_graph["summary"].get("source_compared_pass") != expected_pass:
        errors.append("unified capability graph evidence status is stale")
    if graph_status_mismatches:
        errors.append("unified capability graph contains case-level status mismatches")
    if local_path_leaks:
        errors.append("public files contain machine-specific absolute paths")
    return {
        "schema_version": 1,
        "release": versions["manifest"],
        "check_scope": "package integrity; not visual benchmark acceptance",
        "benchmark": benchmark,
        "release_readiness": "BLOCKED_PENDING_BENCHMARK",
        "status": "PASS" if not errors else "FAIL",
        "errors": errors,
        "versions": versions,
        "hot_load": {"files": hot, "total_zh_chars": sum(x["zh_chars"] for x in hot)},
        "reproduction_atlas": reproduction,
        "scidraw_atlas": scidraw,
        "scidraw_batch2_atlas": scidraw_batch2,
        "selected_public_gallery_pngs": [x.name for x in assets],
        "scidraw_public_gallery_pngs": [x.name for x in scidraw_assets],
        "scidraw_batch2_public_gallery_pngs": [x.name for x in scidraw_batch2_assets],
        "validated_png_errors": artifact_errors,
        "scidraw_review_evidence_errors": scidraw_evidence_errors,
        "scidraw_batch2_review_evidence_errors": scidraw_batch2_evidence_errors,
        "low_reasoning_contracts": {"families": len(method_contracts["families"]), "subtypes": len(method_contracts["subtypes"])},
        "capability_graph_source_compared_pass": capability_graph["summary"].get("source_compared_pass"),
        "capability_graph_status_mismatches": graph_status_mismatches,
        "machine_specific_path_files": local_path_leaks,
        "claim_boundary": "Only high_fidelity_eligible records may be cited as source-compared precedents; excluded records remain diagnostic evidence.",
    }


def audit() -> dict:
    """Audit current public bytes, retaining the separate historical archive audit.

    The 3.5-era exact 8/8/20 source-gallery checks are not the distribution
    inventory of 3.8. Public completeness now binds every declared executable
    case and the full Skill/runtime, plus the current curated gallery.
    """
    import importlib.util
    import sys
    sys.path.insert(0, str(ROOT / 'scripts'))
    from audit_portable_install import audit as portable_audit
    from benchmark_core import inventory
    portable = portable_audit(ROOT, distribution_root=REPO)
    public_path = REPO / 'tools/audit_public_release.py'
    spec = importlib.util.spec_from_file_location('current_public_release', public_path)
    public_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(public_module)
    public = public_module.audit_public_release(REPO)
    manifest = yaml.safe_load((ROOT / 'manifest.yaml').read_text())
    hot = [{'path': rel, 'zh_chars': zh_count((ROOT / rel).read_text())}
           for rel in ['SKILL.md', *manifest['common_dynamic_load']]]
    errors = list(portable['errors']) + list(public['errors'])
    if sum(x['zh_chars'] for x in hot) > 8000 or any(x['zh_chars'] > 1200 for x in hot):
        errors.append('hot-load document budget exceeded')
    benchmark = inventory(ROOT)
    errors.extend(benchmark['errors'])
    catalog = json.loads((REPO / 'docs/gallery/catalog.json').read_text())
    graph = json.loads((ROOT / 'atlas/unified-capability-graph.json').read_text())
    return {'schema_version': 2, 'release': manifest['version'],
            'check_scope': 'public-package-portability-and-gallery',
            'status': 'FAIL' if errors else 'PASS', 'errors': errors,
            'release_readiness': 'PUBLIC_PACKAGE_READY_FULL_BENCHMARK_INCOMPLETE' if not errors else 'BLOCKED',
            'scientific_or_visual_pass_inferred': False,
            'versions': version_snapshot(),
            'hot_load': {'files': hot, 'total_zh_chars': sum(x['zh_chars'] for x in hot)},
            'benchmark': benchmark,
            'public_cases': {'case_counts': portable['case_counts'], 'cases': portable['cases']},
            'learning_catalog': portable.get('learning_catalog'),
            'distribution': {'file_count': portable['distribution']['file_count'],
                             'text_files_scanned': portable['distribution']['text_files_scanned'],
                             'privacy_and_containment_errors': [e for e in portable['errors'] if e.startswith('distribution:')]},
            'current_gallery': public['gallery'],
            'selected_public_gallery_pngs': [row['image'] for row in catalog['figures']],
            'capability_graph': {'case_count': graph['summary']['case_count'],
                                 'source_compared_pass': graph['summary']['source_compared_pass'],
                                 'historical_source_review_summary': graph['summary'].get('historical_source_review_summary')},
            'legacy_source_archive_audit': {'status': 'NOT_RUN',
                'entrypoint': 'audit_legacy_source_archive()',
                'scope': 'Full private/source archive and historical 8/8/20 audit; retained separately, not silently promoted by a public install.'},
            'claim_boundary': 'Public package integrity only. Actual analysis, runtime execution, source fidelity, final-size visual review, new-input transfer and user acceptance remain separate.'}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    parser.add_argument('--legacy-source-archive', action='store_true', help='Run the retained historical full-source archive audit explicitly.')
    args = parser.parse_args()
    result = audit_legacy_source_archive() if args.legacy_source_archive else audit()
    payload = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload)
    print(payload, end="")
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
