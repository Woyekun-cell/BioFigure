#!/usr/bin/env python3
"""Checked descriptive preview for two-condition repeated or independent observations."""
import argparse
import csv
from collections import defaultdict
import hashlib
import json
import math
from pathlib import Path
import statistics
import subprocess
import tempfile

import personal_style as taste

FAMILY = "time-series"
LIB = taste.TIME_EXAMPLE
FIELDS = ["observation_id", "subject_id", "group", "time", "value"]


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path, obj):
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_rows(path):
    with path.open(newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def prepare(rows, design):
    require(rows and set(FIELDS) <= set(rows[0]), "Missing required input columns or observations")
    require(design.get("sampling") in {"repeated", "independent"}, "Declare repeated or independent sampling")
    groups, traces, by_id = defaultdict(list), defaultdict(list), {}
    for row in rows:
        obs, subject, group = (row[k] for k in ("observation_id", "subject_id", "group"))
        t, v = float(row["time"]), float(row["value"])
        require(obs and subject and group and obs not in by_id and math.isfinite(v) and math.isfinite(t),
                "Blank/duplicate observation identity or nonfinite value")
        groups[group,t].append(v)
        traces[subject].append((t,group,obs))
        by_id[obs] = (subject,group,t)
    require(set(g for g,_ in groups) == set(design["group_colors"]), "Group-to-color mapping mismatch")
    times = {float(row["time"]) for row in rows}
    visits = sorted(map(float,design.get("planned_times", times)))
    require(times <= set(visits) and len(visits) == len(set(visits)), "Invalid visit schedule")
    visit_index = {value:i for i,value in enumerate(visits)}
    adjacent = set()
    for events in traces.values():
        require(len({g for _,g,_ in events})==1 and len({t for t,_,_ in events})==len(events),
                "Subject crosses conditions or has ambiguous duplicate times")
        if design["sampling"] == "independent":
            require(len(events)==1, "Independent sampling conflicts with repeated subject IDs")
        ordered = sorted(events)
        adjacent.update((a[2],b[2]) for a,b in zip(ordered,ordered[1:]) if visit_index[b[0]] == visit_index[a[0]]+1)
    if design["sampling"] == "repeated":
        require(any(len(events)>1 for events in traces.values()), "Repeated sampling requires at least one verified repeated individual")
    return groups, adjacent


def render(input_dir, output_dir, style=None, requested=None, task_id=None):
    data, spec = input_dir/"plot_data.csv", input_dir/"design.json"
    design = read_json(spec)
    rows = read_rows(data)
    groups, adjacent = prepare(rows, design)
    recipe = read_json(LIB/"method.json")
    output_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="trial-", dir=output_dir) as scratch:
        tmp = Path(scratch)
        effective = dict(design)
        defaults = {"point_emphasis":"balanced", "grid":"light", "legend_position":"top"}
        chosen = {"point_emphasis":style} if isinstance(style,str) else (style or {})
        requested = requested or {}
        origins = {}
        for feature, fallback in defaults.items():
            if feature in requested:
                effective[feature] = requested[feature]
                origins[feature] = "request"
            elif feature in design:
                origins[feature] = design.get("style_origins",{}).get(feature,"output")
            elif feature in chosen:
                effective[feature] = chosen[feature]
                origins[feature] = "learned"
            else:
                effective[feature] = fallback
                origins[feature] = "template"
            taste.validate(feature,effective[feature])
        write_json(tmp/"effective.json", effective)
        subprocess.run(["Rscript","--vanilla",str(LIB/"render.R"),str(data),str(tmp/"effective.json"),str(tmp)], cwd=tmp,check=True)
        summary = read_rows(tmp/"summary.csv")
        checked = set()
        for row in summary:
            key = (row["group"],float(row["time"]))
            require(key in groups and key not in checked, "Duplicate or unknown summary key")
            values = groups[key]
            require(int(row["n"]) == len(values) and math.isclose(float(row["mean"]),statistics.mean(values),abs_tol=1e-8),
                    f"Summary mismatch at {key}")
            quartiles = statistics.quantiles(values,method="inclusive") if len(values)>1 else values*3
            for col,expected in (("low",quartiles[0]),("high",quartiles[2])):
                require(math.isclose(float(row[col]),expected,abs_tol=1e-8),f"Quartile mismatch at {key}")
            checked.add(key)
        require(checked == set(groups), "Missing summary cells")
        links = read_rows(tmp/"links.csv")
        edges = {(v["from_id"],v["to_id"]) for v in links}
        require(len(links)==len(edges) and edges == adjacent, "Invalid individual connection")
        if design["sampling"]=="independent":
            require(not edges, "Independent individuals must have zero individual connections")
        for file, magic in [("preview.pdf",b"%PDF-"),("preview.png",b"\x89PNG")]:
            require((tmp/file).read_bytes().startswith(magic), f"Missing or invalid {file}")
        record = dict(sampling=design["sampling"], point_emphasis=effective.get("point_emphasis","balanced"), observations=len(rows), subjects=len({r["subject_id"] for r in rows}),
                      summary_cells=len(checked), individual_edges=len(edges), expected_adjacent_edges=len(adjacent),
                      input_sha256=digest(data), design_sha256=digest(spec), method_sha256=digest(LIB/"method.json"),
                      renderer_sha256=digest(LIB/"render.R"), source_method=recipe.get("id",recipe.get("method_id")),
                      files={name:digest(tmp/name) for name in ["preview.pdf","preview.png","summary.csv","links.csv"]})
        task = task_id or design.get("task_id")
        if not task:
            # Distinct copies and row-order changes are still one drawing task.
            identity = hashlib.sha256()
            for row in sorted(rows,key=lambda row:row["observation_id"]):
                identity.update(json.dumps([row[key] for key in FIELDS]).encode())
            task = "data-" + identity.hexdigest()
        record["task_id"] = task
        record["visual_style"] = {feature:effective[feature] for feature in defaults}
        record["style_origins"] = origins
        write_json(tmp/"checks.json", record)
        for name in ["preview.pdf","preview.png","summary.csv","links.csv","checks.json"]:
            (tmp/name).replace(output_dir/name)
        return record


def apply(input_dir, output_dir, gallery_path, *, requested=None, task_id=None, save=False):
    requested = requested or {}
    for feature, value in requested.items():
        taste.validate(feature, value)
    output_dir = output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    lock = output_dir / ".biofigure-drawing"
    with lock.open("x"):
        try:
            require(all(entry == lock for entry in output_dir.iterdir()), "Choose an empty output folder")
            style = taste.snapshot(FAMILY, gallery_path)["defaults"]
            result = render(input_dir.resolve(), output_dir, style, requested, task_id)
            signals = {feature: source for feature,source in result["style_origins"].items()
                       if source in ("request", "output")}
            key = None
            if signals or save:
                with taste.connect(gallery_path) as db:
                    for feature,source in signals.items():
                        taste.observe(db, FAMILY, result["task_id"], feature, result["visual_style"][feature], source)
                    if save:
                        key = taste.collect(db, output_dir/"preview.png", title=output_dir.name, family=FAMILY, origin="preview-time")
            return dict(gallery_id=key, **result)
        finally:
            lock.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output_dir", type=Path, help="new or empty output directory")
    parser.add_argument("--input", type=Path, default=LIB,
                        help="folder containing plot_data.csv and design.json; default: bundled synthetic example")
    parser.add_argument("--gallery", type=Path, default=taste.default_path())
    parser.add_argument("--task-id", help="reuse the same ID for revisions of one drawing")
    parser.add_argument("--request", nargs=2, action="append", default=[], metavar=("FEATURE","VALUE"))
    parser.add_argument("--save", action="store_true", help="explicitly collect the verified PNG in the personal gallery")
    args = parser.parse_args()
    result = apply(args.input, args.output_dir, args.gallery, requested=dict(args.request),
                   task_id=args.task_id, save=args.save)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
