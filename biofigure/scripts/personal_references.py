"""Resolve only the references selected for one drawing brief."""
from contextlib import closing
from functools import lru_cache
import hashlib
import json
import os
from pathlib import Path
import sqlite3

from personal_style import TIME_EXAMPLE, snapshot

SKILL_ROOT = Path(__file__).resolve().parents[1]
GALLERY_FAMILY = {
    "heatmap": "matrix", "time": "time-series", "maps": "map",
    "multi": "multipanel", "mechanism": "schematic-mechanism",
}



@lru_cache(maxsize=1)
def public_catalog(directory):
    index = directory / "gallery.json"
    if not index.is_file():
        return {}, {}
    entries = json.loads(index.read_text())["figures"]
    binding = directory.parent / "resource-bindings.json"
    bindings = json.loads(binding.read_text())["figures"] if binding.is_file() else {}
    return {item["id"]: item for item in entries}, bindings


def public_reference(key):
    directory = Path(os.environ.get("BIOFIGURE_GALLERY_DIR") or SKILL_ROOT.parent / "public-gallery/dist")
    entries, bindings = public_catalog(directory)
    item = entries.get(key)
    if item is None:
        return None
    image = directory / item["image"]
    if not image.is_file():
        raise FileNotFoundError(image)
    code = []
    urls = []
    for asset in bindings.get(key, {}).get("code", []):
        path = directory.parent.parent / asset["path"]
        if path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == asset["sha256"]:
            code.append(str(path.resolve()))
    for asset in item.get("resources", {}).get("code", []):
        url = asset["url"]
        if url.startswith("https://"):
            urls.append(url)
        elif (directory / url).is_file():
            code.append(str((directory / url).resolve()))
    return dict(id=key, title=item["title"]["zh"], image=str(image.resolve()), family=GALLERY_FAMILY.get(item.get("category"), item.get("category")),
                source="https://woyekun-cell.github.io/BioFigure/?figure=" + key,
                code=list(dict.fromkeys(code)), code_urls=urls)


def selected_references(keys, profile):
    stored = {}
    if keys and profile.is_file():
        with closing(sqlite3.connect(profile.resolve().as_uri()+"?mode=ro", uri=True)) as db:
            db.row_factory = sqlite3.Row
            tables = {r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
            if "figures" in tables:
                notes = ("n.tags,n.origin FROM figures f LEFT JOIN reference_notes n USING(id)"
                         if "reference_notes" in tables else "NULL AS tags,NULL AS origin FROM figures f")
                for key in dict.fromkeys(keys):
                    row = db.execute("SELECT f.id,f.title,f.image,"+notes+" WHERE f.id=?", (key,)).fetchone()
                    if row:
                        stored[key] = dict(id=key,title=row["title"],image=row["image"],tags=json.loads(row["tags"] or "[]"))
                        if row["origin"] == "preview-time":
                            stored[key].update(code=[str(TIME_EXAMPLE/"render.R")], method=str(TIME_EXAMPLE/"method.json"))
    result = []
    methods = None
    for key in dict.fromkeys(keys):
        file = Path(key).expanduser()
        if key in stored:
            entry = public_reference(key) if not key.startswith("image-") else None
            card = stored[key]
            if entry:
                card.update(code=entry["code"], code_urls=entry["code_urls"], family=entry["family"], source=entry["source"])
            result.append(card)
        elif file.is_file():
            result.append(dict(id=key,title=file.name,image=str(file.resolve())))
        elif entry := public_reference(key):
            result.append(entry)
        else:
            from find_figure_reference import load_catalog, _locations
            if methods is None:
                methods = {card["method_id"]: card for card in load_catalog()["cards"]}
            if key not in methods:
                raise ValueError(f"Unknown reference {key!r}. Use an imported ID, a file path or a figure reference ID.")
            card = methods[key]
            result.append(dict(id=key,title=card["title"],source_images=_locations(card.get("source_images",[]),2),
                               code_files=_locations(card.get("code_files",[]),2)))
    return result


def brief(profile, family, description, keys):
    if not description.strip():
        raise ValueError("Supply the design description")
    state = snapshot(family,profile)
    candidates = []
    if not keys:
        from find_figure_reference import find
        candidates = [dict(id=r["method_id"], title=r["title"]) for r in find(description)["results"]]
    return dict(description=description,family=family,selected=selected_references(keys,profile),
                candidates=candidates,defaults=state["defaults"],starred=[] if keys else state["starred"])
