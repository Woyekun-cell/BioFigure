#!/usr/bin/env python3
"""Fresh gated native replay of packaged plot tables into a new directory.

Run from a complete public BioFigure clone. Author raw processing and complete
paper-figure fidelity are not executed or inherited from historical evidence.
"""
import argparse, datetime, hashlib, json, os, pathlib, shutil, subprocess, sys, yaml
os.environ["PYTHONDONTWRITEBYTECODE"] = "1"
ROOT = pathlib.Path(__file__).resolve().parents[1]
TABLES = ("busco-coordinates.csv", "busco-palette.csv", "sample-order.csv", "synthase-markers.csv")

def sha(p):
    return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()

def skill_root():
    return next(p for p in ROOT.parents if (p / "scripts/prepare_figure.py").is_file() and (p / "SKILL.md").is_file())

def call(log, *args):
    r = subprocess.run(list(map(str, args)), capture_output=True, text=True, encoding="utf-8", env=dict(os.environ, PYTHON=sys.executable, PYTHONUTF8="1"), errors="replace")
    pathlib.Path(log).write_text(r.stdout + r.stderr, encoding="utf-8")
    if r.returncode:
        raise RuntimeError("Command failed (" + str(r.returncode) + "); see " + str(log))
    return r

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--output-dir", type=pathlib.Path, help="Required fresh, previously nonexistent directory for a render")
    p.add_argument("--source-view-confirmed", action="store_true", help="Confirm that sources/own-reference.png was actually viewed for this invocation")
    p.add_argument("--native-source-dir", type=pathlib.Path, help="Optional previously acquired, SHA-verified original GPL BUSCOplot source cache")
    p.add_argument("--check-only", action="store_true", help="Verify packaged input hashes only; this is not a rendering PASS")
    p.add_argument("--rscript", default="Rscript")
    p.add_argument("--pdftoppm", default="pdftoppm", help="Poppler executable used only to inspect actual PDF")
    a = p.parse_args()
    lock = json.loads((ROOT / "data/metadata/source-lock.json").read_text(encoding="utf-8"))
    for item in lock["assets"]:
        q = ROOT / item["path"]
        if not q.is_file() or sha(q) != item["sha256"]:
            raise ValueError("Public input hash mismatch: " + item["path"])
    if a.check_only:
        print(json.dumps({"status": "PUBLIC_INPUT_HASH_CHECK_PASS", "assets": len(lock["assets"]), "rendered": False})); return
    if not a.output_dir:
        p.error("--output-dir is required for a fresh replay; reviewed packaged outputs are never overwritten")
    if not a.source_view_confirmed:
        p.error("View sources/own-reference.png, then pass --source-view-confirmed; no source view is inferred")
    bf = skill_root(); out = a.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    meta = out / "data/metadata"; meta.mkdir(parents=True)
    qa = out / "work"; qa.mkdir()
    name = "fig4d-author-recolored" if lock["case_kind"] == "cannabis-cassette" else "author-public-chr7-recolored"
    sealed_pdf = ROOT / "results/figures" / (name + ".pdf")
    sealed_sha = sha(sealed_pdf)
    native = a.native_source_dir.resolve() if a.native_source_dir else out / "native-source/BUSCOplot"
    acmd = [sys.executable, ROOT / "scripts/acquire_sources.py", "--output-dir", native]
    if a.native_source_dir: acmd += ["--check-only"]
    call(out / "native-acquisition.log", *acmd)
    lib = out / "R-library"
    call(out / "native-install.log", a.rscript, ROOT / "scripts/install_native.R", native, lib)
    call(out / "current-table-audit.log", a.rscript, ROOT / "scripts/audit_inputs.R", ROOT, out / "current-table-audit.json")
    call(out / "prepare-cp2.log", sys.executable, ROOT / "scripts/prepare_spec.py", "--output-dir", meta, "--rscript", a.rscript, "--source-view-confirmed")
    spec = yaml.safe_load((meta / "design-spec.yaml").read_text(encoding="utf-8"))
    acquisition = json.loads((ROOT / "data/metadata/native-acquisition.json").read_text(encoding="utf-8"))
    sources = [ROOT / "scripts/render.R", bf / "scripts/figure_style.R", ROOT / "data/metadata/source-lock.json"]
    sources += [ROOT / x["path"] for x in lock["assets"] if pathlib.Path(x["path"]).suffix.lower() not in {".yaml", ".yml"}]
    sources += [native / x["path"] for x in acquisition["assets"]]
    cmd = [sys.executable, bf / "scripts/authorize_render.py", "--receipt", meta / "preparation-receipt.json", "--design-spec", meta / "design-spec.yaml", "--output", qa / "authorization.json"]
    for q in dict.fromkeys(sources): cmd += ["--source", q]
    call(out / "authorize.log", *cmd)
    call(out / "render.log", a.rscript, ROOT / "scripts/render.R", ROOT, qa, qa / "authorization.json", lib, out, meta / "design-spec.yaml", native)
    pdf = out / "results/figures" / (name + ".pdf")
    preview_code = r'''
    a<-commandArgs(TRUE);suppressPackageStartupMessages(library(magick))
    p<-image_read(file.path(a[1],paste0(a[2],".png")))
    image_write(image_resize(p,sprintf("%dx%d!",round(180/25.4*96),round(as.numeric(a[3])/25.4*96))),file.path(a[1],"target-size-96dpi.png"),format="png")
    '''
    call(qa / "preview-generation.log", a.rscript, "-e", preview_code, qa, name, spec["output_size"]["height_mm"])
    poppler = shutil.which(a.pdftoppm)
    if not poppler:
        raise RuntimeError("Poppler pdftoppm required for actual PDF preview; use --pdftoppm <executable>")
    call(qa / "pdf-preview-generation.log", poppler, "-r", "120", "-png", "-singlefile", pdf, qa / "pdf-preview-120dpi")
    comparisons = [{"file": n, "sha256": sha(out / "results/plot_data" / n), "packaged_input_sha256": sha(ROOT / "results/plot_data" / n), "byte_equal": sha(out / "results/plot_data" / n) == sha(ROOT / "results/plot_data" / n)} for n in TABLES]
    if not all(x["byte_equal"] for x in comparisons) or sha(sealed_pdf) != sealed_sha:
        raise ValueError("Packaged table replay or sealed-output preservation failed")
    report = {"schema_version": 1, "status": "FRESH_PUBLIC_TABLE_NATIVE_REPLAY_EXECUTED", "scope": "Public fixed packaged tables and current own gallery layout only", "method_id": lock["method_id"], "output_directory": str(out), "packaged_outputs_preserved": True, "packaged_pdf_sha256": sealed_sha, "native_package_commit": lock["native_package_commit"], "native_package_source_sha_verified": True, "isolated_native_library_installed": str(lib), "plot_data_comparison": comparisons, "rendered_pdf": {"path": str(pdf), "sha256": sha(pdf)}, "current_table_audit": json.loads((out / "current-table-audit.json").read_text(encoding="utf-8")), "fresh_prepare_CP2_authorization": True, "PNG_PDF_visual_review": "PENDING", "author_raw_processing": False, "original_whole_figure_fidelity": "NOT_VERIFIED", "new_input_transfer": False, "stable_template": False}
    (out / "replay-evidence.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"output_directory": str(out), "plot_data_all_byte_equal": True, "status": report["status"]}, ensure_ascii=False))

if __name__ == "__main__": main()
