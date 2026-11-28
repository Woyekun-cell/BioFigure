#!/usr/bin/env python3
"""Local, figure-family-scoped taste memory and explicitly collected references."""
import argparse
import hashlib
from io import BytesIO
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
from contextlib import closing

TIME_EXAMPLE = Path(__file__).resolve().parents[1] / "examples" / "personal-time-response"
WINDOW, REQUESTS, OBSERVATIONS = 5, 3, 4
FEATURES = {
    "point_emphasis": ("points", "balanced"),
    "grid": ("light", "none"),
    "legend_position": ("top", "right", "bottom", "left"),
}


def default_path():
    return Path(os.getenv("BIOFIGURE_PERSONAL_DB") or
                Path.home() / ".local/share/biofigure/personal.sqlite").expanduser()


def connect(path):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(path, timeout=15)
    db.row_factory = sqlite3.Row
    db.executescript("""
      CREATE TABLE IF NOT EXISTS figures (
        id TEXT PRIMARY KEY,title TEXT NOT NULL,image TEXT NOT NULL,family TEXT,
        starred INTEGER NOT NULL DEFAULT 0,hint TEXT);
      CREATE TABLE IF NOT EXISTS taste_events (
        seq INTEGER PRIMARY KEY,family TEXT NOT NULL,feature TEXT NOT NULL,
        task TEXT NOT NULL,value TEXT NOT NULL,source TEXT NOT NULL,
        UNIQUE(family,feature,task));
      CREATE INDEX IF NOT EXISTS recent_taste ON taste_events(family,feature,seq DESC);
      CREATE TABLE IF NOT EXISTS taste_defaults (
        family TEXT,feature TEXT,value TEXT NOT NULL,PRIMARY KEY(family,feature));
      CREATE TABLE IF NOT EXISTS reference_notes (
        id TEXT PRIMARY KEY,origin TEXT NOT NULL,tags TEXT NOT NULL DEFAULT '[]');
      CREATE TABLE IF NOT EXISTS gallery_identity (
        singleton INTEGER PRIMARY KEY CHECK(singleton=1), id TEXT NOT NULL);
      INSERT OR IGNORE INTO gallery_identity VALUES (1, lower(hex(randomblob(16))));
      CREATE TABLE IF NOT EXISTS gallery_events (
        seq INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL,
        refs TEXT NOT NULL, instruction TEXT NOT NULL,
        recorded_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')));
    """)
    return db


def validate(feature, value):
    if value not in FEATURES.get(feature, ()):
        raise ValueError(f"Unsupported visual setting: {feature}={value}")


def observe(db, family, task, feature, value, source):
    validate(feature, value)
    if not family.strip() or not task.strip() or source not in ("request", "output"):
        raise ValueError("Need a figure family, stable task ID and request/output origin")
    with db:
        # A retry/revision has one vote. A user's instruction outranks the renderer.
        db.execute("""INSERT INTO taste_events(family,feature,task,value,source) VALUES(?,?,?,?,?)
            ON CONFLICT(family,feature,task) DO UPDATE SET value=excluded.value,source=excluded.source
            WHERE excluded.source='request' OR taste_events.source!='request'""",
                   (family, feature, task, value, source))
        rows = db.execute("""SELECT value,source FROM taste_events WHERE family=? AND feature=?
                             ORDER BY seq DESC LIMIT ?""", (family,feature,WINDOW)).fetchall()
        for candidate in {r["value"] for r in rows}:
            matching = [r for r in rows if r["value"] == candidate]
            if sum(r["source"] == "request" for r in matching) >= REQUESTS or len(matching) >= OBSERVATIONS:
                db.execute("""INSERT INTO taste_defaults VALUES(?,?,?)
                    ON CONFLICT(family,feature) DO UPDATE SET value=excluded.value""",
                           (family,feature,candidate))
                break


def preferences(db, family):
    return dict(db.execute("SELECT feature,value FROM taste_defaults WHERE family=?", (family,)))


def favorites(db, family):
    rows = db.execute("""SELECT f.id,f.title,f.image,n.tags FROM figures f LEFT JOIN reference_notes n USING(id)
        WHERE f.starred=1 AND (f.family=? OR f.family IS NULL) ORDER BY f.rowid DESC LIMIT 3""", (family,))
    return [dict(id=r["id"],title=r["title"],image=r["image"],tags=json.loads(r["tags"] or "[]")) for r in rows]


def snapshot(family, path=None):
    path = path or default_path()
    if not family or not path.is_file():
        return {"defaults": {}, "starred": []}
    # Reading a plan must not create a database or perform schema upgrades.
    db = sqlite3.connect(path.resolve().as_uri()+"?mode=ro",uri=True,timeout=2)
    db.row_factory = sqlite3.Row
    try:
        tables = {row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        return {"defaults": preferences(db,family) if "taste_defaults" in tables else {},
                "starred": favorites(db,family) if {"figures","reference_notes"} <= tables else []}
    finally:
        db.close()


def list_references(path):
    if not path.is_file():
        return []
    db = sqlite3.connect(path.resolve().as_uri()+"?mode=ro", uri=True)
    db.row_factory = sqlite3.Row
    try:
        tables = {r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        if "figures" not in tables:
            return []
        notes = ("n.tags FROM figures f LEFT JOIN reference_notes n USING(id)"
                 if "reference_notes" in tables else "NULL AS tags FROM figures f")
        rows = db.execute("SELECT f.id,f.title,f.image,f.family,f.starred,"+notes+" ORDER BY f.rowid DESC")
        return [dict(dict(r),tags=json.loads(r["tags"] or "[]")) for r in rows]
    finally:
        db.close()


def collect(db, image, *, title=None, family=None, tags=(), starred=False, origin="import"):
    # Keep the exact imported bytes so moving or deleting the source does not break the gallery.
    from PIL import Image
    data = image.read_bytes()
    with Image.open(BytesIO(data)) as im:
        ext = {"PNG":"png","JPEG":"jpg","WEBP":"webp","TIFF":"tiff"}.get(im.format)
        if not ext:
            raise ValueError("Supported reference formats: PNG, JPEG, WebP, TIFF")
        im.verify()
    with Image.open(BytesIO(data)) as decoded:
        decoded.load()
    sha = hashlib.sha256(data).hexdigest()
    key = "image-" + sha
    db_path = Path(db.execute("PRAGMA database_list").fetchone()[2])
    assets = db_path.parent / (db_path.name + ".images")
    assets.mkdir(exist_ok=True)
    dest = assets / (sha + "." + ext)
    with tempfile.NamedTemporaryFile(dir=assets,delete=False) as handle:
        tmp = Path(handle.name)
        try:
            handle.write(data)
            handle.flush()
            try:
                os.link(tmp, dest)
            except FileExistsError:
                if hashlib.sha256(dest.read_bytes()).hexdigest() != sha:
                    raise ValueError("Stored reference hash mismatch")
        finally:
            tmp.unlink(missing_ok=True)
    with db:
        db.execute("BEGIN IMMEDIATE")
        prior = db.execute("SELECT starred FROM figures WHERE id=?", (key,)).fetchone()
        db.execute("""INSERT INTO figures(id,title,image,family,starred) VALUES(?,?,?,?,?)
                      ON CONFLICT(id) DO UPDATE SET starred=max(starred,excluded.starred),
                      family=coalesce(excluded.family,family)""",
                   (key,title or image.stem,str(dest.resolve()),family,int(starred)))
        db.execute("""INSERT INTO reference_notes(id,origin) VALUES(?,?)
                      ON CONFLICT(id) DO UPDATE SET origin=excluded.origin
                      WHERE excluded.origin='preview-time' OR (excluded.origin='saved' AND reference_notes.origin='import')""",(key,origin))
        add_tags(db,key,tags)
        if starred and not (prior and prior["starred"]):
            record_gallery_event(db, "star", [{"id": key, "title": title or image.stem,
                                               "family": family, "source": origin}])
    return key


def add_tags(db, key, tags):
    if tags:
        db.execute("INSERT OR IGNORE INTO reference_notes(id,origin) VALUES(?, 'gallery')",(key,))
        old = db.execute("SELECT tags FROM reference_notes WHERE id=?", (key,)).fetchone()[0]
        labels = list(dict.fromkeys(json.loads(old) + [s.strip() for s in tags if s.strip()]))
        db.execute("UPDATE reference_notes SET tags=? WHERE id=?", (json.dumps(labels,ensure_ascii=False),key))


def gallery_reference(key, public, stored):
    return {
        "id": key,
        "title": public["title"] if public else stored["title"],
        "family": public["family"] if public else stored["family"],
        "source": public["source"] if public else "personal-gallery",
    }


def record_gallery_event(db, kind, references, instruction=""):
    cursor = db.execute("INSERT INTO gallery_events(kind,refs,instruction) VALUES(?,?,?)",
                        (kind, json.dumps(references, ensure_ascii=False), instruction))
    return cursor.lastrowid


def gallery_changes(path, after):
    if after < 0:
        raise ValueError("The event cursor must be nonnegative")
    if not path.is_file():
        return {"profile": None, "events": [], "next": after, "more": False}
    with closing(sqlite3.connect(path.resolve().as_uri() + "?mode=ro", uri=True)) as db:
        db.row_factory = sqlite3.Row
        if not db.execute("SELECT 1 FROM sqlite_master WHERE name='gallery_events'").fetchone():
            return {"profile": None, "events": [], "next": after, "more": False}
        profile = db.execute("SELECT id FROM gallery_identity WHERE singleton=1").fetchone()["id"]
        rows = db.execute("SELECT * FROM gallery_events WHERE seq>? ORDER BY seq LIMIT 201", (after,)).fetchall()
        events = [dict(seq=row["seq"], kind=row["kind"], references=json.loads(row["refs"]),
                       instruction=row["instruction"], recorded_at=row["recorded_at"]) for row in rows[:200]]
        return {"profile": profile, "events": events, "next": events[-1]["seq"] if events else after,
                "more": len(rows) > 200}


def revise(db, instruction, keys):
    from personal_references import public_reference
    if not instruction.strip() or len(instruction) > 4000:
        raise ValueError("Supply a design revision of up to 4,000 characters")
    references = []
    for key in dict.fromkeys(keys):
        public = public_reference(key)
        stored = db.execute("SELECT title,family FROM figures WHERE id=?", (key,)).fetchone()
        if not public and not stored:
            raise ValueError("Unknown reference ID")
        references.append(gallery_reference(key, public, stored))
    with db:
        return record_gallery_event(db, "revision", references, instruction)


def mark(db, key, enabled, tags=()):
    from personal_references import public_reference
    public = public_reference(key) if not key.startswith("image-") else None
    with db:
        db.execute("BEGIN IMMEDIATE")
        stored = db.execute("SELECT title,family,starred FROM figures WHERE id=?", (key,)).fetchone()
        if not stored:
            if not public:
                raise ValueError("Unknown reference ID")
            if not enabled:
                return
            db.execute("INSERT INTO figures(id,title,image,family,starred) VALUES(?,?,?,?,1)",
                       (key, public["title"], public["image"], public["family"]))
        elif stored["starred"] != int(enabled):
            db.execute("UPDATE figures SET starred=? WHERE id=?", (int(enabled), key))
        add_tags(db,key,tags)
        if bool(stored and stored["starred"]) != enabled:
            record_gallery_event(db, "star" if enabled else "unstar", [gallery_reference(key, public, stored)])


def pick(db):
    if sys.platform != "darwin":
        raise ValueError("Use the import command with an image path on this system")
    proc = subprocess.run(["/usr/bin/osascript",str(Path(__file__).with_name("pick_style_reference.applescript"))],
                          check=True,capture_output=True)
    response = proc.stdout.removesuffix(b"\n").decode()
    if not response:
        return []
    action, label, *paths = response.split("\0")
    return [collect(db,Path(path),starred=action=="★ 喜欢并导入",tags=[label]) for path in paths]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--gallery",type=Path,default=default_path())
    sub = p.add_subparsers(dest="cmd",required=True)
    sub.add_parser("list")
    changes = sub.add_parser("changes", help="read personal-gallery changes after an event cursor")
    changes.add_argument("--after", type=int, default=0)
    revision = sub.add_parser("revise", help="record an explicit design revision for review")
    revision.add_argument("instruction")
    revision.add_argument("references", nargs="*")
    design = sub.add_parser("brief",help="select references for one task without collecting them")
    design.add_argument("--family",required=True)
    design.add_argument("description")
    design.add_argument("references",nargs="*")
    sub.add_parser("pick", help="open the macOS import and star dialog")
    get = sub.add_parser("get")
    get.add_argument("--family",required=True)
    event = sub.add_parser("observe")
    for name in ("family","task","feature","value"):
        event.add_argument("--"+name,required=True)
    event.add_argument("--source",choices=["request","output"],required=True)
    save = sub.add_parser("save", help="explicitly collect a finished figure or a checked preview directory")
    save.add_argument("file", type=Path)
    save.add_argument("--family")
    imp = sub.add_parser("import")
    imp.add_argument("file",type=Path)
    imp.add_argument("--family")
    imp.add_argument("--tag",action="append",default=[])
    imp.add_argument("--star",action="store_true")
    for cmd in ("star","unstar"):
        m = sub.add_parser(cmd)
        m.add_argument("id")
        m.add_argument("--tag",action="append",default=[])
    args = p.parse_args()
    if args.cmd == "list":
        print(json.dumps(list_references(args.gallery),ensure_ascii=False))
        return
    if args.cmd == "changes":
        print(json.dumps(gallery_changes(args.gallery, args.after), ensure_ascii=False))
        return
    if args.cmd == "brief":
        from personal_references import brief
        print(json.dumps(brief(args.gallery,args.family,args.description,args.references),ensure_ascii=False))
        return
    if args.cmd == "get":
        print(json.dumps(snapshot(args.family,args.gallery),ensure_ascii=False))
        return
    with connect(args.gallery) as db:
        if args.cmd == "revise":
            print(json.dumps({"seq": revise(db, args.instruction, args.references)}))
        elif args.cmd == "pick":
            print(json.dumps(pick(db),ensure_ascii=False))
        elif args.cmd == "observe":
            observe(db,args.family,args.task,args.feature,args.value,args.source)
        elif args.cmd == "save":
            image = args.file.expanduser()
            family = args.family
            origin = "saved"
            if image.is_dir():
                receipt = json.loads((image/"checks.json").read_text())
                image = image/"preview.png"
                if hashlib.sha256(image.read_bytes()).hexdigest() != receipt["files"]["preview.png"]:
                    raise ValueError("Preview no longer matches its receipt")
                if (receipt.get("source_method")==json.loads((TIME_EXAMPLE/"method.json").read_text())["id"]
                    and receipt.get("renderer_sha256")==hashlib.sha256((TIME_EXAMPLE/"render.R").read_bytes()).hexdigest()):
                    family = family or "time-series"
                    origin = "preview-time"
            print(collect(db,image,title=args.file.name,family=family,origin=origin))
        elif args.cmd == "import":
            print(collect(db,args.file,family=args.family,tags=args.tag,starred=args.star))
        else:
            mark(db,args.id,args.cmd=="star",args.tag)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, sqlite3.Error) as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(2)
