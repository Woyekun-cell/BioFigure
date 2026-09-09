#!/usr/bin/env python3
"""Emit a structured, evidence-scoped Critic Loop result for one artifact."""
from __future__ import annotations

import argparse
import hashlib
import json
from datetime import date
from collections import Counter
from pathlib import Path
import re
import sys
import yaml
from PIL import Image, ImageStat

ROOT = Path(__file__).resolve().parents[1]
MODE_CRITICS = {
    "standard": ["scientific"],
    "publication": ["scientific", "visual", "publication", "anti-ai", "reference-quality"],
    "reference-guided": ["scientific", "visual", "anti-ai", "reference-quality"],
    "reproduce": ["scientific", "visual", "anti-ai", "reference-quality"],
}
DOMAIN_CRITICS = {
    "machine-learning": "ml",
    "imaging-assay": "imaging",
    "genome-sequence-variation": "genome",
    "phylogeny-synteny-gene-family": "genome",
    "schematic-mechanism": "mechanism",
}

def specialty_critics(domains: list[str]) -> list[str]:
    return list(dict.fromkeys(DOMAIN_CRITICS[x] for x in domains if x in DOMAIN_CRITICS))


def load(path: Path):
    with path.open(encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def issue(name, evidence, proposed_fix):
    return {"issue": name, "evidence": evidence, "proposed_fix": proposed_fix}


def raster_metrics(path: Path) -> dict | None:
    if path.suffix.lower() != ".png":
        return None
    with Image.open(path) as image:
        rgb = image.convert("RGB")
        stat = ImageStat.Stat(rgb)
        pixels = list(rgb.get_flattened_data())
        nonwhite = sum(1 for r, g, b in pixels if min(r, g, b) < 250) / max(1, len(pixels))
        common_color, common_count = Counter(pixels).most_common(1)[0]
        patch = max(2, min(rgb.width, rgb.height) // 100)
        corners = [rgb.crop(box) for box in ((0, 0, patch, patch), (rgb.width-patch, 0, rgb.width, patch),
                                              (0, rgb.height-patch, patch, rgb.height),
                                              (rgb.width-patch, rgb.height-patch, rgb.width, rgb.height))]
        corner_min = min(min(ImageStat.Stat(c).mean) for c in corners)
        return {"width_px": rgb.width, "height_px": rgb.height,
                "nonwhite_fraction": round(nonwhite, 6),
                "channel_std_max": round(max(stat.stddev), 4),
                "corner_channel_mean_min": round(corner_min, 4),
                "dominant_rgb": list(common_color), "dominant_fraction": round(common_count / len(pixels), 6)}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_evidence(path: Path | None, artifact: Path, metrics: dict | None) -> tuple[dict | None, list[dict], list[dict], list[dict]]:
    hard, major, minor = [], [], []
    if path is None:
        hard.append(issue("inspection_evidence_missing", "--inspection-evidence is required",
                          "open the rendered artifact and record hash-bound structured evidence"))
        return None, hard, major, minor
    try:
        evidence = load(path)
    except Exception as exc:
        hard.append(issue("inspection_evidence_invalid", str(exc), "write valid YAML evidence"))
        return None, hard, major, minor
    if not isinstance(evidence, dict):
        return None, [issue("inspection_evidence_invalid", "not a mapping", "write a YAML mapping")], [], []
    required = ["artifact", "artifact_sha256", "artifact_opened", "inspected_at", "inspector", "viewer_record", "visual_evidence", "detected", "issues"]
    missing = [key for key in required if key not in evidence]
    if missing:
        hard.append(issue("inspection_evidence_incomplete", missing, "complete all required evidence fields"))
        return evidence, hard, major, minor
    declared = Path(str(evidence.get("artifact", "")))
    declared_paths = [declared.resolve()] if declared.is_absolute() else [(Path.cwd() / declared).resolve(), (ROOT.parent / declared).resolve()]
    if artifact.resolve() not in declared_paths:
        hard.append(issue("artifact_path_mismatch", evidence.get("artifact"), "bind evidence to the exact inspected artifact path"))
    if evidence.get("artifact_sha256") != sha256(artifact):
        hard.append(issue("artifact_sha256_mismatch", evidence.get("artifact_sha256"), "inspect this exact artifact and update its hash"))
    if evidence.get("artifact_opened") is not True:
        hard.append(issue("artifact_not_opened", evidence.get("artifact_opened"), "open the final-size artifact before assessment"))
    if not isinstance(evidence.get("inspector"), str) or len(evidence["inspector"].strip()) < 3:
        hard.append(issue("inspector_invalid", evidence.get("inspector"), "record a named human or agent inspector"))
    inspected_at = str(evidence.get("inspected_at", ""))
    try:
        date.fromisoformat(inspected_at)
    except ValueError:
        hard.append(issue("inspection_date_invalid", inspected_at, "use an ISO 8601 calendar date"))
    viewer = evidence.get("viewer_record")
    if not isinstance(viewer, dict) or viewer.get("method") not in {"direct-open", "contact-sheet-open"} or viewer.get("opened_artifact_sha256") != sha256(artifact):
        hard.append(issue("viewer_record_invalid", viewer, "record the viewer method and opened artifact SHA-256"))
    visual = evidence.get("visual_evidence")
    if not isinstance(visual, dict):
        hard.append(issue("visual_evidence_invalid", visual, "record hierarchy, whitespace, and legend observations"))
    else:
        normalized_observations = []
        for key in ("hierarchy", "whitespace", "legend", "title_discipline"):
            value = visual.get(key)
            observation = value.get("observation") if isinstance(value, dict) else None
            compact = re.sub(r"\s+", "", observation or "") if isinstance(observation, str) else ""
            if len(compact) < 24 or len(set(compact.lower())) < 8:
                hard.append(issue("visual_observation_missing", key, f"record a concrete {key} observation"))
            else:
                normalized_observations.append(compact.lower())
        if len(normalized_observations) != len(set(normalized_observations)):
            hard.append(issue("duplicated_visual_observations", normalized_observations, "record distinct object-specific evidence for each visual dimension"))
    detected = evidence.get("detected")
    if not isinstance(detected, dict):
        hard.append(issue("detected_checks_invalid", detected, "record all defect checks as booleans"))
    else:
        severe = {"clipping", "overlap", "missing_glyph", "legend_overlap", "non_white_background", "font_fallback", "unrequested_text"}
        for key in severe:
            if not isinstance(detected.get(key), bool):
                hard.append(issue("inspection_check_missing", key, "record an explicit boolean after inspection"))
            elif detected[key]:
                hard.append(issue(key, "reported by actual inspection", f"correct {key.replace('_', ' ')} and rerender"))
    if metrics and isinstance(evidence.get("image_metrics"), dict):
        if evidence["image_metrics"].get("width_px") != metrics["width_px"] or evidence["image_metrics"].get("height_px") != metrics["height_px"]:
            hard.append(issue("artifact_dimensions_mismatch", evidence.get("image_metrics"), "regenerate evidence for this artifact"))
    evidence_issues = evidence.get("issues")
    if not isinstance(evidence_issues, list):
        hard.append(issue("inspection_issues_invalid", evidence_issues, "issues must be a list"))
    else:
        for item in evidence_issues:
            if not isinstance(item, dict) or item.get("severity") not in {"hard", "major", "minor"} or not item.get("issue"):
                hard.append(issue("inspection_issue_malformed", item, "record issue, severity, evidence, and proposed_fix"))
                continue
            normalized = issue(item["issue"], item.get("evidence", "reported by inspector"), item.get("proposed_fix", "revise and rerender"))
            {"hard": hard, "major": major, "minor": minor}[item["severity"]].append(normalized)
    return evidence, hard, major, minor


def run(args: argparse.Namespace) -> dict:
    artifact = Path(args.artifact)
    index = load(ROOT / "patterns/index.yaml")
    known = {x["pattern_id"] for x in index["patterns"]}
    hard, major, minor = [], [], []
    supplemental_reference_used = False
    if getattr(args, "design_spec", None):
        try:
            design_spec = load(Path(args.design_spec))
            if design_spec.get("selected_pattern") != args.pattern:
                hard.append(issue("design_spec_pattern_mismatch", design_spec.get("selected_pattern"), "run the artifact against its selected Pattern"))
            supplemental_reference_used = bool(design_spec.get("reference_evidence", {}).get("supplemental_case_ids"))
        except Exception as exc:
            hard.append(issue("design_spec_invalid", str(exc), "provide a readable validated Figure Design Spec"))
    if args.pattern not in known:
        hard.append({"issue": "unknown_pattern", "evidence": args.pattern, "proposed_fix": "select a Pattern ID from patterns/index.yaml"})
    atlas = load(ROOT / "atlas/index.yaml")
    reviewed_patterns = {
        entry.get("pattern_id")
        for entry in atlas.get("entries", [])
        if entry.get("review_status") in {"source-reviewed", "human-approved"}
    }
    top_journal = load(ROOT / "atlas/top-journal-corpus.yaml")
    for entry in top_journal.get("entries", []):
        if entry.get("actual_figure_reviewed") is True and entry.get("review_status") == "source-and-visual-reviewed":
            reviewed_patterns.update(entry.get("patterns", []))
    if args.mode == "reference-guided" and args.pattern not in reviewed_patterns:
        major.append({"issue": "reviewed_atlas_entry_missing", "evidence": args.pattern, "proposed_fix": "use a source-reviewed or human-approved Atlas entry, or switch mode"})
    if not artifact.exists():
        hard.append({"issue": "artifact_missing", "evidence": str(artifact), "proposed_fix": "render the artifact before running critics"})
    vector_text = raster_nodes = None
    if artifact.exists() and artifact.suffix.lower() == ".svg":
        raw = artifact.read_text(encoding="utf-8", errors="replace")
        vector_text = len(re.findall(r"<text(?:\s|>)", raw))
        raster_nodes = len(re.findall(r"<(?:image|image-rendering)(?:\s|>)", raw))
        if raster_nodes == 1:
            minor.append({"issue": "single_raster_layer", "evidence": raster_nodes, "proposed_fix": "verify it is only a continuous colorbar; otherwise export vector geometry"})
        elif raster_nodes:
            major.append({"issue": "embedded_raster", "evidence": raster_nodes, "proposed_fix": "prefer vector text and geometry or document the raster source"})
    metrics = raster_metrics(artifact) if artifact.exists() else None
    if metrics and (metrics["nonwhite_fraction"] < 0.005 or metrics["channel_std_max"] < 2):
        hard.append(issue("blank_or_near_blank_artifact", metrics, "render visible data marks before inspection"))
    if metrics and metrics["corner_channel_mean_min"] < 250:
        hard.append(issue("non_white_background_machine", metrics["corner_channel_mean_min"], "export canvas and panel with #FFFFFF"))
    # A dominant data color is not evidence of a colored panel background.
    evidence, evidence_hard, evidence_major, evidence_minor = (None, [], [], [])
    if artifact.exists():
        evidence, evidence_hard, evidence_major, evidence_minor = validate_evidence(
            Path(args.inspection_evidence) if args.inspection_evidence else None, artifact, metrics)
        hard.extend(evidence_hard)
        major.extend(evidence_major)
        minor.extend(evidence_minor)
    inspection_status = "evidence_valid" if evidence is not None and not evidence_hard else "failed"
    critics_run = list(dict.fromkeys(MODE_CRITICS[args.mode] + specialty_critics(getattr(args, "domain", []) or [])))
    if supplemental_reference_used:
        critics_run = list(dict.fromkeys(critics_run + ["reference-transfer"]))
    reviews = evidence.get("critic_reviews", {}) if isinstance(evidence, dict) else {}
    if not isinstance(reviews, dict):
        reviews = {}
    scores = {}
    for name in critics_run:
        review = reviews.get(name)
        valid = (isinstance(review, dict) and review.get("status") in {"PASS", "REVISE", "FAIL"}
                 and isinstance(review.get("evidence"), str) and len(review["evidence"].strip()) >= 20)
        if valid and name == "reference-quality":
            dimensions = review.get("dimensions", {})
            valid = isinstance(dimensions, dict) and all(
                isinstance(dimensions.get(k), dict)
                and dimensions[k].get("status") in {"PASS", "REVISE", "FAIL"}
                and isinstance(dimensions[k].get("evidence"), str)
                and len(dimensions[k]["evidence"].strip()) >= 20
                for k in ("hierarchy", "geometry", "palette", "typography", "marks", "annotation"))
            if valid and review["status"] == "PASS" and any(v.get("status") != "PASS" for v in dimensions.values()):
                valid = False
        if not valid:
            scores[name] = {"result": "NOT_ASSESSED", "basis": "missing critic-specific observations"}
            major.append(issue("critic_review_missing", name, "perform and record this critic with concrete evidence"))
        else:
            scores[name] = {"result": review["status"], "basis": review["evidence"]}
            if review["status"] != "PASS":
                (hard if review["status"] == "FAIL" else major).append(issue(
                    "critic_review_not_passed", {name: review}, "resolve the recorded findings and repeat this critic"))
    status = "FAIL" if hard else ("REVISE" if major else "PASS")
    critic_basis = {
        "scientific": "explicit data, units, mapping and statistical review; never inferred from pixels",
        "visual": "hierarchy, whitespace, legend observations plus defect checks",
        "publication": "machine background gate plus final-size inspection and format audit handoff",
        "anti-ai": "title-discipline and hierarchy observations",
        "ml": "ML split, leakage, discrimination, calibration and interpretation contract",
        "imaging": "image integrity, processing, scale-bar and sampling-unit contract",
        "genome": "assembly, coordinate, mapping and alignment contract",
        "mechanism": "edge evidence level, direction and no-fabrication contract",
        "reference-quality": "actual reference-to-render comparison of hierarchy, geometry, palette, typography, marks and annotation",
        "reference-transfer": "supplemental case provenance, transfer decisions, rejected elements and final-size inspection",
    }
    return {
        "schema_version": "1.1", "artifact": str(artifact), "pattern_id": args.pattern, "mode": args.mode,
        "critics_run": critics_run, "status": status, "hard_failures": hard,
        "major_issues": major, "minor_issues": minor,
        "scores": scores, "critic_requirements": {name: critic_basis[name] for name in critics_run},
        "inspection": {"status": inspection_status, "artifact_exists": artifact.exists(), "artifact_sha256": sha256(artifact) if artifact.exists() else None,
                       "image_metrics": metrics, "vector_text_nodes": vector_text, "raster_nodes": raster_nodes,
                       "evidence_scope": "hash_bound_machine_checks_plus_actual_visual_observations"},
        "revision_history": [], "next_action": "PASS" if status == "PASS" else "revise_and_rerun",
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifact", required=True)
    parser.add_argument("--pattern", required=True)
    parser.add_argument("--mode", choices=sorted(MODE_CRITICS), default="standard")
    parser.add_argument("--actual-inspection", action="store_true")
    parser.add_argument("--inspection-evidence", type=Path)
    parser.add_argument("--design-spec", type=Path)
    parser.add_argument("--domain", action="append", default=[])
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    payload = run(args)
    print(json.dumps(payload, ensure_ascii=False, sort_keys=True, indent=2) if args.json else payload["status"])
    return 0 if payload["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
