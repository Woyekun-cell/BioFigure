#!/usr/bin/env python3
"""Validate BioFigure palette-library structure and opaque sRGB values."""
from pathlib import Path
import re
import sys
import yaml

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / "palettes/palette-library.yaml"
doc = yaml.safe_load(path.read_text(encoding="utf-8"))
errors = []
palettes = doc.get("palettes", [])
ids = [p.get("id") for p in palettes]
if len(palettes) < 18:
    errors.append("at least 18 palettes required")
if len(ids) != len(set(ids)):
    errors.append("palette ids must be unique")
if {p.get("kind") for p in palettes} != {"categorical", "sequential", "diverging"}:
    errors.append("categorical, sequential and diverging palettes are all required")
for p in palettes:
    colors = p.get("colors")
    for key in ("id", "label", "kind", "cvd_status", "source", "recommended_for"):
        if not p.get(key):
            errors.append(f"{p.get('id')}: missing {key}")
    if not isinstance(colors, list) or len(colors) < 3:
        errors.append(f"{p.get('id')}: at least three colors required")
        continue
    if any(not re.fullmatch(r"#[0-9A-F]{6}", str(c)) for c in colors):
        errors.append(f"{p.get('id')}: colors must be uppercase opaque #RRGGBB")
    if len(colors) != len(set(colors)):
        errors.append(f"{p.get('id')}: duplicate colors")
    if p.get("kind") == "categorical" and p.get("max_categories") != len(colors):
        errors.append(f"{p.get('id')}: max_categories must equal available colors")
    if p.get("kind") == "diverging" and not p.get("center_semantics"):
        errors.append(f"{p.get('id')}: diverging palette requires center_semantics")
if errors:
    print("PALETTE_LIBRARY_FAIL")
    print("\n".join(errors))
    sys.exit(1)
print(f"PALETTE_LIBRARY_OK:{len(palettes)}")

