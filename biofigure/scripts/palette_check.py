#!/usr/bin/env python3
"""Advisory sRGB palette diagnostics. Dependencies: numpy, colorspacious.

Machado et al. CVD emulation via colorspacious; CAM02-UCS distances use
the library's default viewing conditions. This does not certify a figure.
Sources: https://colorspacious.readthedocs.io/en/latest/tutorial.html
https://colorspace.r-forge.r-project.org/articles/color_vision_deficiency.html
"""
import argparse
import json
import re
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--colors", nargs="+", required=True, help="Opaque #RRGGBB colors in display order")
    parser.add_argument("--kind", choices=["categorical", "sequential", "diverging"], default="categorical")
    parser.add_argument("--background", default="#FFFFFF")
    parser.add_argument("--warning-distance", type=float, default=10,
                        help="Heuristic CAM02-UCS warning distance, NOT an accessibility standard")
    args = parser.parse_args()
    if not 2 <= len(args.colors) <= 256:
        parser.error("provide between 2 and 256 colors")
    if args.kind == "diverging" and len(args.colors) < 3:
        parser.error("diverging palettes require at least 3 colors including the intended center")
    if not 0 < args.warning_distance < 1000:
        parser.error("warning-distance must be finite and positive, below 1000")
    for c in [*args.colors, args.background]:
        if not re.fullmatch(r"#[0-9a-fA-F]{6}", c):
            parser.error(f"expected opaque #RRGGBB, got {c!r}")
    try:
        import numpy as np
        from colorspacious import cspace_convert
    except ImportError as exc:
        parser.error(f"missing optional diagnostic dependency: {exc}; use an existing environment with numpy/colorspacious, or R colorspace")

    def rgb(c):
        return np.array([int(c[i:i+2], 16) / 255 for i in (1, 3, 5)])

    def linear(x):
        return np.where(x <= .04045, x / 12.92, ((x + .055) / 1.055) ** 2.4)

    def luminance(x):
        return linear(x) @ np.array([.2126, .7152, .0722])

    colors = np.array([rgb(c) for c in args.colors])
    y = luminance(colors)
    bg = float(luminance(rgb(args.background)))
    contrast = (np.maximum(y, bg) + .05) / (np.minimum(y, bg) + .05)
    report = {
        "kind": args.kind, "input_colors": args.colors, "background": args.background,
        "certifies_accessibility": False,
        "distance_metric": "CAM02-UCS Euclidean; default colorspacious viewing conditions",
        "warning_distance_heuristic": args.warning_distance,
        "contrast_to_background": contrast.tolist(), "views": {}, "warnings": [],
        "limits": ["Opaque palette only; inspect actual marks, text, alpha, labels and background separately.",
                   "CVD simulation is approximate; clipping can affect simulated colors and distances.",
                   "Distance threshold is a screening heuristic, not a publication or WCAG requirement.",
                   "Gradients need manual review of ordered progression, data limits and neutral value."]
    }
    gray = np.where(y <= .0031308, 12.92 * y, 1.055 * y ** (1 / 2.4) - .055)
    view_inputs = {"normal": colors, "grayscale": np.repeat(gray[:, None], 3, axis=1)}
    for name, cvd, severity in [("deutan_50", "deuteranomaly", 50),
                                ("deutan_100", "deuteranomaly", 100),
                                ("protan_50", "protanomaly", 50),
                                ("protan_100", "protanomaly", 100),
                                ("tritan_100", "tritanomaly", 100)]:
        view_inputs[name] = cspace_convert(colors,
            {"name": "sRGB1+CVD", "cvd_type": cvd, "severity": severity}, "sRGB1")
    for name, raw in view_inputs.items():
        clipped = np.clip(raw, 0, 1)
        near = None
        if args.kind == "categorical":
            ucs = cspace_convert(clipped, "sRGB1", "CAM02-UCS")
            distances = np.linalg.norm(ucs[:, None, :] - ucs[None, :, :], axis=2)
            np.fill_diagonal(distances, np.inf)
            i, j = np.unravel_index(np.argmin(distances), distances.shape)
            near = {"indices_zero_based": [int(i), int(j)], "distance": float(distances[i, j])}
            if near["distance"] < args.warning_distance:
                report["warnings"].append(f"{name}: colors {i+1}/{j+1} may be hard to distinguish; inspect and add non-color cues")
        report["views"][name] = {
            "colors": ["#" + "".join(f"{int(v):02X}" for v in np.rint(c * 255)) for c in clipped],
            "clipped_colors": int(np.count_nonzero(np.any((raw < -1e-7) | (raw > 1+1e-7), axis=1))),
            "relative_luminance": luminance(clipped).tolist(), "closest_pair": near
        }
    print(json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False))


if __name__ == "__main__":
    main()
