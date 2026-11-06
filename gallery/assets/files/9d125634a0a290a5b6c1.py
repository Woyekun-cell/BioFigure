#!/usr/bin/env python3
"""Build three body-width-matched source/model comparison pages.

Only crop and place supplied figure pixels. Never change scientific marks or
invent values. Run after the main renderer, using its prefix and audit receipt.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path

from PIL import Image
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
from reportlab.platypus import Paragraph


CASE = Path(__file__).resolve().parent.parent
PROJECT = CASE.parents[4]
WORK = PROJECT / "work/2026-10-15-mefisto-reproduction"
PAPER_URL = "https://www.nature.com/articles/s41592-021-01343-9"
MODEL_URL = "https://doi.org/10.6084/m9.figshare.13233860.v1"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prefix_file(prefix: Path, suffix: str) -> Path:
    return Path(str(prefix) + suffix)


def paragraph(c, text, x, y_top, width, size=9.2, color="#30343B"):
    style = ParagraphStyle(
        "comparison", fontName="ComparisonCJK", fontSize=size,
        leading=size * 1.45, alignment=TA_LEFT, wordWrap="CJK",
        textColor=colors.HexColor(color), spaceAfter=0,
    )
    p = Paragraph(text, style)
    _, height = p.wrap(width * mm, 100 * mm)
    p.drawOn(c, x * mm, y_top * mm - height)
    return height / mm


def crop_mm(image, bounds, canvas_mm):
    """Bounds are x0,y0,x1,y1, in the main figure's bottom-left mm frame."""
    x0, y0, x1, y1 = bounds
    width, height = canvas_mm
    box = (
        round(x0 / width * image.width),
        round((height - y1) / height * image.height),
        round(x1 / width * image.width),
        round((height - y0) / height * image.height),
    )
    return image.crop(box), box


def place_image(c, image, x, y_top, width, height):
    # No crop-fit or panel-wide resizing is performed here. The caller supplies
    # a scale derived exclusively from the width of one data body.
    buf = io.BytesIO()
    image.save(buf, format="PNG")
    c.drawImage(
        ImageReader(buf), x * mm, (y_top - height) * mm,
        width=width * mm, height=height * mm, mask="auto",
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--render", type=Path, default=WORK / "preview-v2/mefisto-fig2bde", help="Main render prefix, without extension")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--contract", type=Path, default=WORK / "source-visual-contract.json")
    parser.add_argument("--source", type=Path, default=None)
    parser.add_argument("--trajectory-body-mm", type=float, default=32.1)
    parser.add_argument("--font", type=Path, default=Path("/System/Library/Fonts/STHeiti Light.ttc"), help="Embedded TrueType CJK font, TTC subfont 0")
    args = parser.parse_args()
    prefix, output = args.render.resolve(), args.output.resolve()
    contract_path = args.contract.resolve()
    contract = json.loads(contract_path.read_text())
    source_path = args.source.resolve() if args.source else PROJECT / contract["source"]["image"]
    render_png = prefix_file(prefix, ".png")
    render_pdf = prefix_file(prefix, ".pdf")
    render_audit = prefix_file(prefix, ".audit.json")
    frozen_inputs = {path: sha256(path) for path in [source_path, render_png, render_pdf, render_audit, contract_path]}
    audit = json.loads(render_audit.read_text())
    if sha256(source_path) != contract["source"]["sha256"]:
        raise ValueError("Source image differs from the visually inspected contract")
    source = Image.open(source_path).convert("RGB")
    rendered = Image.open(render_png).convert("RGB")
    if list(source.size) != contract["source"]["dimensions_px"]:
        raise ValueError("Source image dimensions do not match contract")
    canvas_mm = audit["canvas_mm"]
    if canvas_mm != [183, 170]:
        raise ValueError("Expected the reviewed 183 x 170 mm render")
    cells = audit.get("heatmap_cells_pdf") or audit["heatmap_cells_png"]
    if len(cells) != 10 or any(x["rows"] != 5 or x["columns"] != 5 for x in cells):
        raise ValueError("Expected ten 5 x 5 matrix body receipts")
    b_body_mm = sum(x["body_width_mm"] for x in cells[:5]) / 5
    e_body_mm = sum(x["body_width_mm"] for x in cells[5:]) / 5
    if any(abs(x["body_width_mm"] - b_body_mm) > .05 for x in cells[:5]):
        raise ValueError("Panel b body widths differ")
    if any(abs(x["body_width_mm"] - e_body_mm) > .05 for x in cells[5:]):
        raise ValueError("Panel e body widths differ")
    if not audit.get("source_model_no_retraining", False):
        raise ValueError("Main audit must affirm the un-retrained source model")

    # Source crop coordinates were independently matched, pixel for pixel, to
    # the supplied source-b/d/e crops. Body geometry comes from the contract.
    # The final b matrix/organ labels moved up by 1.8 mm. A 106 mm crop
    # preserves the organ labels and excludes the adjacent Factor header.
    specs = [
        dict(panel="b", title="总解释方差与因子解释方差热图", source_box=[50, 710, 2085, 1425],
             source_body_px=contract["panel_b_total_bars_and_variance_heatmaps"]["per_heatmap_size_px_approx"][0],
             source_body_origin_px=[174, 900], new_crop_mm=[0, 106, 183, 170],
             new_body_mm=b_body_mm, new_body_origin_mm=[15, 147.8], target_body_mm=20, body_top_mm=137,
             notes=[
                 "真实 evo-devo 预训练模型；未重新训练。总 R2 直接读取作者模型，不由单因子 R2 相加。",
                 "5 个物种、5 个器官、5 个因子；25 根总量柱。物种与器官排序沿发表图。",
                 "复绘采用物理正方格；发表图 b 的格子略长。负 R2 仅显示时映射为 0.001，原始数值保留。",
             ]),
        dict(panel="d", title="潜在因子轨迹、模型区间与平滑度／共享度", source_box=[0, 1470, 2119, 2100],
             source_body_px=contract["panel_d_factor_trajectories"]["facet_outer_x_ranges_px"][0][1] - contract["panel_d_factor_trajectories"]["facet_outer_x_ranges_px"][0][0],
             source_body_origin_px=[122, 1541], new_crop_mm=[0, 48, 183, 105],
             new_body_mm=args.trajectory_body_mm, new_body_origin_mm=[11.8, 99], target_body_mm=22, body_top_mm=142,
             notes=[
                 "真实 evo-devo 预训练模型；未重新训练。415 个观测因子点和 350 条预测记录均来自作者存档。",
                 "点为观测因子值，线为潜在过程均值；区间按作者代码为均值 ± 1.96 × √方差，不是动物重复之间的 SD。",
                 "物种颜色与 b 保持一致；平滑度和共享度条采用发表稿的上方位置。",
             ]),
        dict(panel="e", title="逐因子物种相关核与层次聚类", source_box=[0, 2150, 2119, 2693],
             source_body_px=contract["panel_e_species_kernel_heatmaps"]["per_heatmap_size_px_approx"][0],
             source_body_origin_px=[129, 2204], new_crop_mm=[0, 0, 183, 48],
             new_body_mm=e_body_mm, new_body_origin_mm=[13.85 if e_body_mm > 27 else 14.5, 45 if e_body_mm > 27 else 43],
             target_body_mm=20, body_top_mm=143,
             notes=[
                 "真实 evo-devo 预训练模型；未重新训练。相关范围固定为 −1 到 1，零值居中；聚类由作者核矩阵重新计算。",
                 "存档 Factor 4／5 的核与发表图不同；保留真实矩阵及 get_group_kernel 原生物种赋名，不交换标签或改数值。",
                 "复绘采用正方格。强负相关也贡献共享度，不能把共享度解释为所有物种同向变化的比例。",
             ]),
    ]
    pdfmetrics.registerFont(TTFont("ComparisonCJK", str(args.font), subfontIndex=0))
    output.parent.mkdir(parents=True, exist_ok=True)
    c = canvas.Canvas(str(output), pagesize=(297 * mm, 190 * mm), pageCompression=1, invariant=1)
    c.setTitle("MEFISTO Fig. 2b/d/e - body-width-matched source comparison")
    c.setAuthor("Local scientific figure review")
    pages = []
    # 141.5 mm columns keep all original text while retaining an exact 20 mm body.
    # A whole 183 mm crop at 20/26 scale is 140.77 mm wide.
    column_origins = [5.0, 150.5]
    column_width = 141.5
    body_left_in_column = 11.6
    for page_number, spec in enumerate(specs, 1):
        p = spec["panel"]
        paragraph(c, f"MEFISTO Fig. 2{p}　来源对照", 8, 182, 281, 15)
        paragraph(c, spec["title"], 8, 173, 281, 10.2, "#505761")
        paragraph(c, "发表原图", column_origins[0], 162, column_width, 11)
        paragraph(c, "作者预训练模型复绘", column_origins[1], 162, column_width, 11)
        matched = f"单个数据主体宽度：两侧均为 {spec['target_body_mm']:g} mm"
        paragraph(c, matched, 8, 154.5, 281, 8.6, "#606973")
        source_crop = source.crop(tuple(spec["source_box"]))
        new_crop, new_pixel_box = crop_mm(rendered, spec["new_crop_mm"], canvas_mm)
        target = spec["target_body_mm"]
        source_scale_mm_px = target / spec["source_body_px"]
        new_scale = target / spec["new_body_mm"]
        new_scale_mm_px = new_scale * canvas_mm[0] / rendered.width
        sw, sh = source_crop.width * source_scale_mm_px, source_crop.height * source_scale_mm_px
        nw, nh = new_crop.width * new_scale_mm_px, new_crop.height * new_scale_mm_px
        sx_offset = (spec["source_body_origin_px"][0] - spec["source_box"][0]) * source_scale_mm_px
        sy_offset = (spec["source_body_origin_px"][1] - spec["source_box"][1]) * source_scale_mm_px
        nx_offset = spec["new_body_origin_mm"][0] * new_scale
        ny_offset = (spec["new_crop_mm"][3] - spec["new_body_origin_mm"][1]) * new_scale
        sx = column_origins[0] + body_left_in_column - sx_offset
        nx = column_origins[1] + body_left_in_column - nx_offset
        stop = spec["body_top_mm"] + sy_offset
        ntop = spec["body_top_mm"] + ny_offset
        for x, w, col in [(sx, sw, column_origins[0]), (nx, nw, column_origins[1])]:
            if x < col - .05 or x + w > col + column_width + .05:
                raise ValueError(f"Panel {p} complete crop exceeds column; do not fit-shrink its data body")
        place_image(c, source_crop, sx, stop, sw, sh)
        place_image(c, new_crop, nx, ntop, nw, nh)
        bottom = min(stop - sh, ntop - nh)
        rule_y = bottom - 6
        c.setStrokeColor(colors.HexColor("#D5D9DE"))
        c.setLineWidth(.45)
        c.line(8 * mm, rule_y * mm, 289 * mm, rule_y * mm)
        notes_y = rule_y - 4
        for note in spec["notes"]:
            consumed = paragraph(c, note, 8, notes_y, 281, 9.4)
            notes_y -= consumed + 2
        c.setFont("Helvetica", 7.2)
        c.setFillColor(colors.HexColor("#5A6570"))
        c.drawString(8 * mm, 13 * mm, "Nature Methods 19, 179-186 (2022) | DOI: 10.1038/s41592-021-01343-9")
        c.drawString(8 * mm, 8 * mm, "Author model: Figshare 10.6084/m9.figshare.13233860.v1 | CC BY 4.0")
        c.linkURL(PAPER_URL, (8 * mm, 12 * mm, 160 * mm, 17 * mm), relative=0)
        c.linkURL(MODEL_URL, (8 * mm, 7 * mm, 170 * mm, 12 * mm), relative=0)
        c.drawRightString(289 * mm, 8 * mm, f"{page_number} / 3")
        pages.append({
            "panel": p, "source_crop_box_px": spec["source_box"],
            "render_crop_box_mm": spec["new_crop_mm"], "render_crop_box_px": new_pixel_box,
            "source_body_width_px": spec["source_body_px"], "render_body_width_mm": spec["new_body_mm"],
            "comparison_body_width_mm": target,
            "source_mm_per_px": source_scale_mm_px, "render_mm_per_px": new_scale_mm_px,
            "source_placed_rect_mm": [sx, stop - sh, sw, sh], "render_placed_rect_mm": [nx, ntop - nh, nw, nh],
            "data_body_top_mm": spec["body_top_mm"], "no_crop_fit": True,
            "notes_outside_figure": spec["notes"],
        })
        c.showPage()
    c.save()
    if any(sha256(path) != value for path, value in frozen_inputs.items()):
        raise RuntimeError("Comparison inputs changed during creation; rerun with completed main outputs")
    receipt = {
        "status": "BODY_MATCHED_COMPARISON_PDF_CREATED_REQUIRES_VISUAL_REVIEW",
        "page_count": 3, "page_size_mm": [297, 190], "column_width_mm": column_width,
        "source_model_no_retraining": True, "data_values_modified": False,
        "source": {"path": str(source_path), "sha256": sha256(source_path), "url": PAPER_URL},
        "render_png": {"path": str(render_png), "sha256": sha256(render_png)},
        "render_pdf": {"path": str(render_pdf), "sha256": sha256(render_pdf)},
        "render_audit": {"path": str(render_audit), "sha256": sha256(render_audit)},
        "source_contract": {"path": str(contract_path), "sha256": sha256(contract_path)},
        "script": {"path": str(Path(__file__).resolve()), "sha256": sha256(Path(__file__).resolve())},
        "embedded_report_font": {"path": str(args.font.resolve()), "sha256": sha256(args.font.resolve()), "subfont_index": 0},
        "output_pdf": {"path": str(output), "sha256": sha256(output)},
        "pages": pages,
    }
    receipt_path = output.with_suffix(".audit.json")
    receipt_path.write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"pdf": str(output), "audit": str(receipt_path), "pages": 3, "body_widths_mm": [20, 22, 20]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
