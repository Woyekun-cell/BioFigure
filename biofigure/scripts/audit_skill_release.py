#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def zh_count(text: str) -> int:
    return len(re.findall(r"[\u4e00-\u9fff]", text))


def version_snapshot() -> dict[str, str]:
    manifest = yaml.safe_load((ROOT / "manifest.yaml").read_text())
    skill = re.search(r"BioFigure (\d+\.\d+\.\d+)", (ROOT / "SKILL.md").read_text()).group(1)
    readme = re.search(r"BioFigure-(\d+\.\d+)", (REPO / "README.md").read_text()).group(1)
    zh = re.search(r"BioFigure (\d+\.\d+)", (REPO / "docs/HANDBOOK.zh-CN.md").read_text()).group(1)
    en = re.search(r"BioFigure (\d+\.\d+)", (REPO / "docs/HANDBOOK.en.md").read_text()).group(1)
    return {"manifest": manifest["version"], "skill": skill, "readme": readme, "handbook_zh": zh, "handbook_en": en}


def atlas_snapshot(path: Path) -> dict:
    cases = json.loads(path.read_text())["cases"]
    eligible = [x for x in cases if x.get("runtime_status") == "source-compared-png" and x.get("review_status") == "pass"]
    incomplete = [x for x in cases if x.get("runtime_status") == "source-compared-png" and x.get("review_status") != "pass"]
    return {
        "total": len(cases),
        "runtime_status": dict(Counter(x.get("runtime_status", "missing") for x in cases)),
        "review_status": dict(Counter(x.get("review_status", "missing") for x in cases)),
        "high_fidelity_eligible": len(eligible),
        "source_compared_excluded": len(incomplete),
        "eligible_missing_png": [x.get("issue", x.get("id")) for x in eligible if not x.get("validated_pngs")],
    }


def audit() -> dict:
    manifest = yaml.safe_load((ROOT / "manifest.yaml").read_text())
    hot = []
    for rel in manifest["always_load"]:
        text = (ROOT / rel).read_text()
        hot.append({"path": rel, "zh_chars": zh_count(text)})
    versions = version_snapshot()
    version_ok = versions["manifest"] == versions["skill"] and all(
        x == ".".join(versions["manifest"].split(".")[:2])
        for x in (versions["readme"], versions["handbook_zh"], versions["handbook_en"])
    )
    reproduction = atlas_snapshot(ROOT / "atlas/reproduction-methods.json")
    scidraw = atlas_snapshot(ROOT / "atlas/scidraw-source-compared-methods.json")
    assets = sorted((REPO / "docs/assets/reproduction-gallery").glob("*.png"))
    errors = []
    if not version_ok:
        errors.append("version mismatch")
    if sum(x["zh_chars"] for x in hot) > 8000 or any(x["zh_chars"] > 1200 for x in hot):
        errors.append("hot-load document budget exceeded")
    if reproduction["eligible_missing_png"] or scidraw["eligible_missing_png"]:
        errors.append("eligible precedent lacks validated PNG")
    if len(assets) != 8:
        errors.append("public selected gallery must contain 8 PNG files")
    return {
        "schema_version": 1,
        "release": versions["manifest"],
        "status": "PASS" if not errors else "FAIL",
        "errors": errors,
        "versions": versions,
        "hot_load": {"files": hot, "total_zh_chars": sum(x["zh_chars"] for x in hot)},
        "reproduction_atlas": reproduction,
        "scidraw_atlas": scidraw,
        "selected_public_gallery_pngs": [x.name for x in assets],
        "claim_boundary": "Only high_fidelity_eligible records may be cited as source-compared precedents; excluded records remain diagnostic evidence.",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = audit()
    payload = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload)
    print(payload, end="")
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
