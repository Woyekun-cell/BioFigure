#!/usr/bin/env python3
"""Fresh BioFigure preparation and authorized same-input MEFISTO visual replay."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import time
import yaml

CASE = Path(__file__).resolve().parents[1]
SKILL = CASE.parents[3]
PROJECT = SKILL.parent
META = CASE / "data/metadata/reproduction"

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def run(argv):
    subprocess.run([str(x) for x in argv], check=True, cwd=PROJECT)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Output prefix; baseline remains unchanged by default.")
    args = parser.parse_args()
    started = time.time()
    contract = json.loads((META / "fixed-input-contract.json").read_text())
    for entry in contract["frozen_files"]:
        path = CASE / entry["path"]
        if not path.is_file() or sha(path) != entry["sha256"]:
            raise SystemExit("Frozen-input contract changed; revalidate this input before replay: " + str(path))
    work = Path(tempfile.mkdtemp(prefix="mefisto-replay-", dir=PROJECT / "work"))
    output = args.output.expanduser().resolve() if args.output else work / "mefisto-fig2bde"
    receipt_path = work / "preparation-receipt.json"
    request = META / "request.yaml"
    run(["python3", SKILL / "scripts/prepare_figure.py", request, "--output", receipt_path])
    receipt = json.loads(receipt_path.read_text())
    method_id = "BENCH-subjournal-mefisto-2022"
    method = next(item for item in receipt["learned_methods"]["results"] if item["method_id"] == method_id)
    if method["material_binding"]["hash_mismatches"] or method["material_binding"]["unresolved"]:
        raise SystemExit("Current learned materials have drifted or are missing; review before drawing.")
    spec = yaml.safe_load((META / "design-spec-template.yaml").read_text())
    evidence = spec["reference_evidence"]
    evidence["preparation_id"] = receipt["preparation_id"]
    evidence["preparation_request"] = receipt["request"]
    evidence["learned_source_reference"]["source_record_sha256"] = method["source_sha256"]
    evidence["learned_source_reference"]["read_hashes"] = {
        name: sha(SKILL / name) for name in method["mandatory_read_set"]}
    style = META / "project-style.yaml"
    spec["project_style_contract"]["registry_path"] = str(style)
    spec["project_style_contract"]["registry_sha256"] = sha(style)
    spec_path = work / "design-spec.yaml"
    spec_path.write_text(yaml.safe_dump(spec, allow_unicode=True, sort_keys=False))
    authorization = work / "render-authorization.json"
    # Ordered exactly as render.R; authorization intentionally binds order as well as bytes.
    sources = [CASE / "scripts/render.R", SKILL / "scripts/figure_style.R",
               META / "variance-color-anchors.csv"] + [
        CASE / "results/plot_data" / (name + ".csv") for name in
        ["r2_per_factor", "r2_total", "observed_factors", "interpolated_factors",
         "group_kernels", "factor_scores"]]
    validate = ["python3", SKILL / "scripts/validate_design_spec.py", spec_path,
                "--preparation-receipt", receipt_path,
                "--issue-render-authorization", authorization]
    for source in sources:
        validate += ["--source", source]
    run(validate)
    run(["Rscript", CASE / "scripts/render.R", CASE, output, spec_path, authorization])
    observed = sha(output.with_suffix(".png"))
    matched = observed == contract["baseline_png_sha256"]
    report = {"status": "FIXED_INPUT_DRAW_MATCHES_BASELINE" if matched else "REQUIRES_NEW_VISUAL_REVIEW",
              "scope": "Only the frozen author-model inputs in this contract; no new-input or environment-transfer certification.",
              "png_bytes_exact": matched, "baseline_png_sha256": contract["baseline_png_sha256"],
              "current_png_sha256": observed, "preparation_id": receipt["preparation_id"],
              "output_prefix": str(output), "work": str(work),
              "seconds_including_preparation_and_R": time.time() - started}
    (work / "replay-verification.json").write_text(json.dumps(report, indent=2))
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if not matched:
        raise SystemExit(2)

if __name__ == "__main__":
    main()
