#!/usr/bin/env python3
"""Build a provenance-preserving, code-free derived atlas from SciDraw assets."""
from __future__ import annotations
import argparse, csv, hashlib, io, json, re, zipfile
from concurrent.futures import ThreadPoolExecutor
from html import unescape
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin
from urllib.request import Request, urlopen
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
UA = {"User-Agent": "Mozilla/5.0 BioFigure/3.0 reference-indexer"}

FEATURES = {
    "plot_primitives": ["geom_point", "geom_line", "geom_bar", "geom_col", "geom_tile", "geom_violin", "geom_boxplot", "geom_ribbon", "geom_segment", "geom_text", "geom_label", "Heatmap", "pheatmap", "corrplot", "circos", "ggtree", "plot_roc", "roc_curve", "confusion_matrix"],
    "layout_controls": ["patchwork", "cowplot", "gridExtra", "facet_wrap", "facet_grid", "inset_element", "plot_layout", "GridSpec", "subplots", "tight_layout", "constrained_layout"],
    "statistics": ["t.test", "wilcox.test", "aov", "anova", "TukeyHSD", "dunnett", "lm(", "lmer", "cor.test", "p.adjust", "multipletests", "pearsonr", "spearmanr", "roc_auc", "calibration_curve"],
    "export_controls": ["ggsave", "pdf(", "svg(", "tiff(", "png(", "agg_png", "svglite", "savefig"],
    "typography": ["family", "fontfamily", "base_family", "Arial", "Helvetica", "fontsize", "element_text", "font.size"],
    "legend_controls": ["legend.position", "guide_legend", "Legend", "bbox_to_anchor", "get_legend", "show_legend"],
}
RISKS = {
    "installs_packages": ["install.packages", "BiocManager::install", "pip install"],
    "network_io": ["download.file", "requests.get", "urlopen(", "curl::", "httr::"],
    "shell_execution": ["system(", "system2(", "shell(", "subprocess", "os.system"],
    "file_delete": ["unlink(", "file.remove", "os.remove", "shutil.rmtree"],
    "working_directory_change": ["setwd(", "os.chdir"],
}

def clean_html(value: str) -> str:
    return re.sub(r"\s+", " ", unescape(re.sub(r"<[^>]+>", "", value))).strip()

def norm(value: str) -> str:
    return re.sub(r"[^0-9a-z\u4e00-\u9fff]+", "", value.lower())

def decode(raw: bytes) -> str:
    for enc in ("utf-8-sig", "utf-8", "gb18030"):
        try: return raw.decode(enc)
        except UnicodeDecodeError: pass
    return raw.decode("utf-8", "replace")

def analyze_code(parts: list[tuple[str, str]]) -> dict:
    joined = "\n".join(text for _, text in parts)
    packages = set()
    for name, text in parts:
        if name.lower().endswith(".r"):
            packages.update(re.findall(r"(?:library|require)\s*\(\s*['\"]?([A-Za-z0-9_.]+)", text))
            packages.update(re.findall(r"([A-Za-z][A-Za-z0-9_.]+)::[A-Za-z0-9_.]+", text))
        if name.lower().endswith(".py"):
            packages.update(x.split(".")[0] for x in re.findall(r"^\s*(?:from|import)\s+([A-Za-z0-9_.]+)", text, re.M))
    found = {key: [x for x in values if x.lower() in joined.lower()] for key, values in FEATURES.items()}
    risks = [key for key, values in RISKS.items() if any(x.lower() in joined.lower() for x in values)]
    colors = list(dict.fromkeys(re.findall(r"#[0-9A-Fa-f]{6}\b", joined)))[:24]
    digest = hashlib.sha256("\n".join(f"{n}\0{t}" for n, t in parts).encode()).hexdigest()
    return {"file_count": len(parts), "languages": sorted({Path(n).suffix.lower().lstrip(".") for n, _ in parts}),
            "combined_sha256": digest, "packages": sorted(packages), **found,
            "hex_colors": colors, "risk_flags": risks}

def parse_inventory(page: str, url: str) -> list[dict]:
    """Bind image, title and article within a project-card, regardless of order."""
    class Cards(HTMLParser):
        def __init__(self):
            super().__init__(); self.items=[]; self.card=None; self.depth=0
            self.section=""; self.capture=None; self.buffer=[]
        def handle_starttag(self, tag, attrs):
            attrs=dict(attrs)
            if tag=="div":
                if self.card is not None: self.depth+=1
                elif "project-card" in attrs.get("class", "").split():
                    self.card={"heading":"", "section":self.section, "images":[], "source_url":""}; self.depth=1
            if tag=="h2" or (tag=="h3" and self.card is not None):
                self.capture=tag; self.buffer=[]
            if self.card is not None:
                if tag=="img" and attrs.get("src"):
                    self.card["images"].append((urljoin(url,attrs["src"]),attrs.get("alt","")))
                if tag=="a" and attrs.get("href","").startswith("https://mp.weixin.qq.com/"):
                    self.card["source_url"]=attrs["href"]
        def handle_data(self, data):
            if self.capture: self.buffer.append(data)
        def handle_endtag(self, tag):
            if tag==self.capture:
                value=" ".join("".join(self.buffer).split())
                if tag=="h2": self.section=value
                elif self.card is not None: self.card["heading"]=value
                self.capture=None
            if tag=="div" and self.card is not None:
                self.depth-=1
                if self.depth==0:
                    for src,alt in self.card["images"]:
                        self.items.append({"visual_id":f"SCIVIS-{len(self.items)+1:03d}",
                            "section":self.card["section"],"heading":self.card["heading"],
                            "heading_status":"page-card-matched", "source_url":self.card["source_url"],
                            "src":src,"alt":alt})
                    self.card=None
    parser=Cards(); parser.feed(page); parser.close()
    return parser.items

def website_inventory(url: str) -> tuple[list[dict], dict]:
    raw = urlopen(Request(url, headers=UA), timeout=30).read()
    page = decode(raw)
    return parse_inventory(page,url), {"page_sha256": hashlib.sha256(raw).hexdigest(),
        "h2_sections": len(re.findall(r"<h2\b", page, re.I)),
        "h3_examples": len(re.findall(r"<h3\b", page, re.I))}

def image_profile(item: dict) -> dict:
    error = None
    for _ in range(3):
      try:
        raw=urlopen(Request(item["src"],headers=UA),timeout=20).read()
        with Image.open(io.BytesIO(raw)) as im:
            rgb=im.convert("RGB"); thumb=rgb.copy(); thumb.thumbnail((320,320))
            pixels=list(thumb.get_flattened_data()); white=sum(min(p)>=245 for p in pixels)/max(1,len(pixels))
            colored=[p for p in pixels if min(p)<238]
            palette=[]
            if colored:
                sample=Image.new("RGB",(len(colored),1)); sample.putdata(colored)
                q=sample.quantize(colors=6,method=Image.Quantize.MEDIANCUT).convert("RGB")
                for c in q.getcolors(maxcolors=256) or []:
                    hx="#%02X%02X%02X"%c[1]
                    if hx not in palette: palette.append(hx)
            return {**item,"sha256":hashlib.sha256(raw).hexdigest(),"width_px":rgb.width,"height_px":rgb.height,
                    "aspect_ratio":round(rgb.width/rgb.height,4),"near_white_fraction":round(white,4),"dominant_nonwhite":palette[:6],"status":"profiled"}
      except Exception as exc:
        error = type(exc).__name__
    return {**item,"status":"failed","error":error}

def build(zip_path: Path, website: str) -> dict:
    visuals, page_meta = website_inventory(website)
    with ThreadPoolExecutor(max_workers=20) as pool:
        visuals=list(pool.map(image_profile,visuals))
    with zipfile.ZipFile(zip_path) as z:
        prefix="SciDraw代码分类包/"
        rows=list(csv.DictReader(io.StringIO(decode(z.read(prefix+"00_总索引.csv")))))
        report=json.loads(decode(z.read(prefix+"00_抓取报告.json")))
        names=set(z.namelist()); cases=[]
        for i,row in enumerate(rows,1):
            rels=[x for x in row["代码文件"].split(";") if x]
            parts=[]
            for rel in rels:
                full=prefix+rel
                if full in names: parts.append((rel,decode(z.read(full))))
            title=row["图表命名"]; nt=norm(title)
            match=[x["visual_id"] for x in visuals if norm(x["heading"])==nt and x.get("source_url")==row["原文URL"]]
            cases.append({"case_id":f"SCICASE-{i:03d}","category":row["图表类型"],"title":title,
                          "source_url":row["原文URL"],"status":row["抓取状态"],"note":row["备注"],
                          "code_analysis":analyze_code(parts),"visual_match":{"visual_ids":match,"status":"page-card-matched" if match else "unmatched"}})
        all_code=[n for n in names if "/code_" in n and Path(n).suffix.lower() in {".r",".py",".txt"}]
        ext={e:sum(Path(n).suffix.lower()==e for n in all_code) for e in (".r",".py",".txt")}
    return {"schema_version":"1.0","source":{"website":website,"zip_name":zip_path.name,
            "zip_sha256":hashlib.sha256(zip_path.read_bytes()).hexdigest(),**page_meta},
            "coverage":{"index_entries":len(rows),"metadata_entries":len([n for n in names if n.endswith('/metadata.json')]),
                        "visual_assets":len(visuals),"profiled_visuals":sum(x["status"]=="profiled" for x in visuals),
                        "code_files":len(all_code),"r_files":ext[".r"],"python_files":ext[".py"],"text_files":ext[".txt"],
                        "archived_entries":report["archived_entries"],"needs_review_entries":report["needs_review_entries"],
                        "failed_entries":report["failed_entries"],"no_public_url_entries":report["no_public_url_entries"]},
            "policy":{"raw_code_embedded":False,"execution_performed":False,"needs_review_is_not_validated":True},
            "cases":cases,"visuals":visuals}

def main():
    p=argparse.ArgumentParser(); p.add_argument("--zip",type=Path,required=True); p.add_argument("--website",default="https://scidraw.msttnote.cn/"); p.add_argument("--output",type=Path,default=ROOT/"atlas/scidraw-derived-corpus.json")
    a=p.parse_args(); result=build(a.zip,a.website); a.output.parent.mkdir(parents=True,exist_ok=True); a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps(result["coverage"],ensure_ascii=False)); return 0
if __name__=="__main__": raise SystemExit(main())
