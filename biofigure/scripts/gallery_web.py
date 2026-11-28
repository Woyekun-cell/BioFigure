"""Serve a personal local gallery with a loopback-only Codex CLI bridge."""
import argparse
from contextlib import closing
import functools
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import mimetypes
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import tempfile
import threading
from urllib.parse import unquote, urlsplit

from personal_style import default_path
from gallery_render import RenderJobs, codex_environment

CLI = Path(__file__).resolve().parents[1] / "bin/biofigure"
PREFIX = "/BioFigure/"
WEB = CLI.parents[1] / "web"
API = PREFIX + "api/"
MAX_ATTACHED_PREVIEWS = 12
ACTION_KINDS = ["add_reference", "remove_reference", "star", "unstar", "revision"]
ACTION_SCHEMA = {
    "type": "object",
    "properties": {
        "answer": {"type": "string"},
        "actions": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "kind": {"type": "string", "enum": ACTION_KINDS},
                    "id": {"type": "string"},
                    "instruction": {"type": "string"},
                },
                "required": ["kind", "id", "instruction"],
                "additionalProperties": False,
            },
        },
    },
    "required": ["answer", "actions"],
    "additionalProperties": False,
}


def gallery(server, *args):
    env = dict(os.environ, BIOFIGURE_GALLERY_DIR=str(server.site))
    result = subprocess.run([str(CLI), "gallery", *args], env=env, text=True,
                            capture_output=True, timeout=30, stdin=subprocess.DEVNULL)
    if result.returncode:
        raise ValueError(result.stderr.strip() or "BioFigure gallery command failed")
    return json.loads(result.stdout) if result.stdout.strip() else None


def public_ids(server, ids):
    if not isinstance(ids, list) or any(not isinstance(key, str) or key not in server.rows for key in ids):
        raise ValueError("Choose references from the current atlas")
    return list(dict.fromkeys(ids))


def curation_state(db):
    rows = db.execute("SELECT id, hidden, edits FROM cards")
    hidden, edits = [], {}
    for key, removed, record in rows:
        if removed:
            hidden.append(key)
        if record:
            edits[key] = json.loads(record)
    return {"hidden": hidden, "edits": edits}


def read_curation(path):
    if not path.is_file():
        return {"hidden": [], "edits": {}}
    with closing(sqlite3.connect(path.resolve().as_uri() + "?mode=ro", uri=True)) as db:
        if db.execute("SELECT 1 FROM sqlite_master WHERE name='cards'").fetchone():
            return curation_state(db)
    return {"hidden": [], "edits": {}}


def update_curation(server, body):
    action = body.get("action")
    ids = public_ids(server, body.get("ids", []))
    if action not in ("hide", "restore", "edit", "reset") or not ids:
        raise ValueError("Choose gallery cards and an action")
    if action in ("edit", "reset") and len(ids) != 1:
        raise ValueError("Edit one gallery card at a time")
    record = None
    if action == "edit":
        record = {}
        fields = body.get("fields")
        if not isinstance(fields, dict) or set(fields) != {"chart", "intro"}:
            raise ValueError("Supply a title and description")
        for field, maximum in (("chart", 140), ("intro", 1500)):
            translations = fields[field]
            if not isinstance(translations, dict) or set(translations) != {"en", "zh"}:
                raise ValueError("Supply both language versions")
            for value in translations.values():
                if not isinstance(value, str) or len(value.strip()) > maximum or (field == "chart" and not value.strip()):
                    raise ValueError("Check the title and description lengths")
            record[field] = {lang: value.strip() for lang, value in translations.items()}
    server.curation.parent.mkdir(parents=True, exist_ok=True)
    with closing(sqlite3.connect(server.curation, timeout=15)) as db, db:
        db.execute("CREATE TABLE IF NOT EXISTS cards (id TEXT PRIMARY KEY, hidden INTEGER NOT NULL DEFAULT 0, edits TEXT)")
        if action in ("hide", "restore"):
            db.executemany("INSERT INTO cards(id,hidden) VALUES (?,?) ON CONFLICT(id) DO UPDATE SET hidden=excluded.hidden",
                           [(key, int(action == "hide")) for key in ids])
        else:
            db.execute("INSERT INTO cards(id,edits) VALUES (?,?) ON CONFLICT(id) DO UPDATE SET edits=excluded.edits",
                       (ids[0], json.dumps(record, ensure_ascii=False) if record is not None else None))
        db.execute("DELETE FROM cards WHERE hidden=0 AND edits IS NULL")
        return curation_state(db)


def question(server, body):
    prompt = body.get("question")
    if not isinstance(prompt, str) or not prompt.strip() or len(prompt) > 4000:
        raise ValueError("Enter a question of up to 4,000 characters")
    ids = public_ids(server, body.get("ids", []))
    if server.online:
        server.online.ensure_figures(ids)
    curated = read_curation(server.curation)
    if set(ids).intersection(curated["hidden"]):
        raise ValueError("Some selected figures were removed. Choose references again.")
    if not server.host_cli:
        raise RuntimeError("Codex CLI is unavailable. Install it and sign in to connect.")
    if not server.ask_lock.acquire(blocking=False):
        raise RuntimeError("Codex is answering another request. Try again when it finishes.")
    try:
        families = {server.rows[key]["category"] for key in ids}
        family = next(iter(families)) if len(families) == 1 else "gallery"
        context = gallery(server, "brief", "--family", family, "--", prompt, *ids)
        context["starred"] = []  # The browser supplies only the reference IDs the visitor chooses.
        previews = []
        for key in ids[:MAX_ATTACHED_PREVIEWS]:
            relative = Path(server.rows[key]["thumbnail"])
            if relative.is_absolute() or ".." in relative.parts:
                continue
            image = (server.site / relative).resolve()
            anchor = (server.site / relative.parts[0]).resolve()
            if image.is_relative_to(anchor) and image.is_file():
                previews.append((key, image))
        attached_ids = {key for key, _ in previews}
        context["selected"] = [
            {**card, "chart": server.rows[card["id"]]["chart"], "intro": server.rows[card["id"]]["intro"],
             **curated["edits"].get(card["id"], {}),
             "simulated": server.rows[card["id"]].get("simulated", False),
             "preview_attached": card["id"] in attached_ids}
            for card in context["selected"]
        ]
        instructions = (
            "Answer questions about BioFigure scientific figure design using the following BioFigure CLI context. "
            "Image attachments are in the same order as selected entries with preview_attached set. "
            "Reason from metadata for entries without a preview. "
            "Preserve BioFigure's scientific checks: clarify experimental unit, pairing, variables and intended comparison "
            "whenever those determine the recommendation. Discuss layout only if study details are missing. "
            "Keep the answer in the visitor's language. Do not run commands, change files, or claim any changes. "
            "Only propose actions explicitly requested, for UI confirmation. A session reference uses add_reference or "
            "remove_reference; permanent favorites require an explicit star or unstar request. For these actions use the "
            "exact ID among selected figures and an empty instruction. For revision use an empty ID and put the visitor's "
            "requested design change in instruction. A revision is a proposed plan. The visitor must click Execute to "
            "run a separate drawing job and see its actual output. Do not claim a revision has already been rendered. "
            "For ordinary questions return actions [].\n"
        )
        with tempfile.TemporaryDirectory(prefix="biofigure-question-") as tmp:
            folder = Path(tmp)
            schema = folder / "response.json"
            schema.write_text(json.dumps(ACTION_SCHEMA))
            answer_file = folder / "answer.json"
            command = [
                server.host_cli, "-a", "never", "exec", "--sandbox", "read-only", "--ephemeral",
                "--ignore-user-config", "--skip-git-repo-check", "--color", "never",
                "-m", server.model, "-C", tmp, "--output-schema", str(schema),
                "--output-last-message", str(answer_file),
                *[arg for _, image in previews for arg in ("--image", str(image))], "-",
            ]
            response = subprocess.run(command, text=True, input=instructions + json.dumps(context, ensure_ascii=False),
                                      capture_output=True, timeout=160, env=codex_environment())
            if response.returncode or not answer_file.is_file():
                raise RuntimeError("Codex did not return a reply. Check the configured model and your Codex sign-in.")
            result = json.loads(answer_file.read_text())
        actions = [action for action in result["actions"]
                   if action["kind"] == "revision" or action["id"] in ids]
        return {"answer": result["answer"], "actions": actions, "host": "Codex", "ids": ids, "previews": len(previews)}
    finally:
        server.ask_lock.release()


class GalleryHandler(SimpleHTTPRequestHandler):
    def host_ok(self):
        return self.headers.get("Host") in self.server.allowed_hosts

    def log_message(self, *_args):
        # Questions and personal figure IDs do not enter server access logs.
        return

    def end_headers(self):
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        super().end_headers()

    def send_json(self, result, status=HTTPStatus.OK):
        data = json.dumps(result, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def starred(self):
        return [entry["id"] for entry in gallery(self.server, "list")
                if entry["starred"] and entry["id"] in self.server.rows]

    def reject_hidden_or_foreign(self):
        if not self.host_ok():
            self.send_error(HTTPStatus.FORBIDDEN)
            return True
        if any(part.startswith(".") for part in unquote(urlsplit(self.path).path).split("/") if part):
            self.send_error(HTTPStatus.NOT_FOUND)
            return True
        return False

    def send_local_ui(self, path, *, head=False):
        relative = path.removeprefix(PREFIX) if path.startswith(PREFIX) else path.lstrip("/")
        name = relative or "index.html"
        if name not in ("index.html","atlas.js","atlas.css") or not (WEB/name).is_file():
            return False
        data = (WEB/name).read_bytes()
        if name == "index.html":
            catalog = json.loads((self.server.site/"gallery.json").read_text())
            token = b"__BIOFIGURE_CATALOG__"
            if data.count(token) != 1:
                raise RuntimeError("The local gallery template is invalid")
            data = data.replace(token,json.dumps(catalog,ensure_ascii=False).replace("<","\\u003c").encode())
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type",mimetypes.guess_type(name)[0] or "application/octet-stream")
        self.send_header("Content-Length",str(len(data)))
        self.send_header("Cache-Control","no-store")
        self.end_headers()
        if not head:
            self.wfile.write(data)
        return True

    def do_HEAD(self):
        if not self.reject_hidden_or_foreign() and not self.send_local_ui(urlsplit(self.path).path,head=True):
            super().do_HEAD()

    def do_GET(self):
        if self.reject_hidden_or_foreign():
            return
        path = urlsplit(self.path).path
        if path == "/":
            self.send_response(HTTPStatus.FOUND)
            self.send_header("Location", PREFIX)
            self.end_headers()
        elif path == API + "curation":
            try:
                self.send_json(read_curation(self.server.curation))
            except (OSError, sqlite3.Error) as error:
                self.send_json({"error": str(error)}, HTTPStatus.SERVICE_UNAVAILABLE)
        elif path == API + "status":
            try:
                self.send_json({"host": "Codex" if self.server.host_cli else None, "stars": self.starred()})
            except (ValueError, OSError, subprocess.TimeoutExpired) as error:
                self.send_json({"error": str(error)}, HTTPStatus.SERVICE_UNAVAILABLE)
        elif path.startswith(API + "render/"):
            tail = path.removeprefix(API + "render/").split("/",2)
            try:
                if len(tail) == 1:
                    self.send_json(self.server.renderer.get(tail[0]))
                elif len(tail) == 3 and tail[1] == "files":
                    file = self.server.renderer.file(tail[0], unquote(tail[2]))
                    self.send_response(HTTPStatus.OK)
                    self.send_header("Content-Type",mimetypes.guess_type(file.name)[0] or "application/octet-stream")
                    self.send_header("Content-Length",str(file.stat().st_size))
                    self.send_header("Cache-Control","no-store")
                    self.end_headers()
                    with file.open("rb") as source:
                        shutil.copyfileobj(source,self.wfile)
                else:
                    self.send_error(HTTPStatus.NOT_FOUND)
            except (ValueError,KeyError,FileNotFoundError):
                self.send_json({"error":"Drawing task or file not found"},HTTPStatus.NOT_FOUND)
        else:
            if self.send_local_ui(path):
                return
            if self.server.online:
                try:
                    relative = path.removeprefix(PREFIX) if path.startswith(PREFIX) else path.lstrip("/")
                    self.server.online.ensure(relative or "index.html")
                except (ValueError, FileNotFoundError):
                    self.send_error(HTTPStatus.NOT_FOUND)
                    return
                except (OSError, RuntimeError) as error:
                    self.send_json({"error":str(error)},HTTPStatus.BAD_GATEWAY)
                    return
            super().do_GET()

    def do_POST(self):
        if self.reject_hidden_or_foreign():
            return
        origin = self.headers.get("Origin")
        if origin != "http://" + self.headers["Host"]:
            self.send_json({"error": "Open the local atlas to use the bridge"}, HTTPStatus.FORBIDDEN)
            return
        path = urlsplit(self.path).path
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if not 0 < length <= 64_000 or self.headers.get_content_type() != "application/json":
                raise ValueError("Expected a JSON request")
            body = json.loads(self.rfile.read(length))
            if not isinstance(body, dict):
                raise ValueError("Expected a JSON object")
            if path == API + "render":
                ids = public_ids(self.server,body.get("ids",[]))
                if not ids:
                    raise ValueError("Select a figure to redraw")
                if set(ids).intersection(read_curation(self.server.curation)["hidden"]):
                    raise ValueError("A selected figure has been removed")
                if self.server.online:
                    self.server.online.ensure_figures(ids)
                result = self.server.renderer.start({**body,"ids":ids},self.server.rows)
            elif path == API + "curation":
                result = update_curation(self.server, body)
            elif path == API + "ask":
                result = question(self.server, body)
            elif path == API + "star":
                key = public_ids(self.server, [body.get("id")])[0]
                enabled = body.get("starred")
                if type(enabled) is not bool:
                    raise ValueError("Expected a star state")
                if self.server.online:
                    self.server.online.ensure(self.server.rows[key]["image"])
                gallery(self.server, "star" if enabled else "unstar", key)
                result = {"stars": self.starred()}
            elif path == API + "revision":
                ids = public_ids(self.server, body.get("ids", []))
                instruction = body.get("instruction")
                if not isinstance(instruction, str):
                    raise ValueError("A design instruction is required")
                result = gallery(self.server, "revise", "--", instruction, *ids)
            else:
                self.send_json({"error": "Unknown gallery action"}, HTTPStatus.NOT_FOUND)
                return
            self.send_json(result)
        except (ValueError, KeyError) as error:
            self.send_json({"error": str(error)}, HTTPStatus.BAD_REQUEST)
        except (RuntimeError, OSError, sqlite3.Error, subprocess.TimeoutExpired) as error:
            message = "The request timed out. Try a narrower question." if isinstance(error, subprocess.TimeoutExpired) else str(error)
            self.send_json({"error": message}, HTTPStatus.SERVICE_UNAVAILABLE)

    def translate_path(self, path):
        parts = urlsplit(path)
        return super().translate_path(parts.path.removeprefix(PREFIX) if parts.path.startswith(PREFIX) else parts.path)

    def list_directory(self, _path):
        self.send_error(HTTPStatus.NOT_FOUND)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--site", type=Path, help="Serve an existing gallery directory")
    parser.add_argument("--online", action="store_true",help="Refresh shared examples before starting the local-only website")
    parser.add_argument("--offline",action="store_true",help="Use an existing example cache without downloading")
    parser.add_argument("--cache",type=Path,default=Path.home()/".cache/biofigure/gallery")
    parser.add_argument("--outputs",type=Path,help="Directory for this personal profile's rendered figures")
    parser.add_argument("--port", type=int, default=18807)
    parser.add_argument("--model", default=os.environ.get("BIOFIGURE_CODEX_MODEL", "gpt-6.2-sol"))
    args = parser.parse_args()
    if args.online and (args.site or args.offline):
        parser.error("Use --online separately from --site and --offline")
    online = None
    if args.offline:
        site = (args.site or args.cache).expanduser().resolve()
        if not (site/"gallery.json").is_file():
            parser.error("The local example cache is empty. Start once without --offline or supply --site.")
    elif args.online or args.site is None:
        from gallery_cache import OnlineGallery
        online = OnlineGallery(args.cache)
        site = online.prepare().resolve()
    else:
        site = args.site.resolve()
    rows = json.loads((site / "gallery.json").read_text())["figures"]
    with ThreadingHTTPServer(("127.0.0.1", args.port), functools.partial(GalleryHandler, directory=site)) as server:
        server.site = site
        server.online = online
        profile = default_path()
        server.curation = profile.with_name(profile.stem + "-gallery.sqlite")
        server.rows = {row["id"]: row for row in rows}
        server.host_cli = shutil.which("codex")
        server.model = args.model
        outputs = args.outputs or profile.parent/"drawings"/profile.stem
        server.renderer = RenderJobs(site,outputs.expanduser().resolve(),server.host_cli,args.model)
        server.ask_lock = threading.Lock()
        server.allowed_hosts = {f"127.0.0.1:{server.server_port}", f"localhost:{server.server_port}"}
        print(f"BioFigure Gallery http://127.0.0.1:{server.server_port}{PREFIX}", flush=True)
        server.serve_forever()


if __name__ == "__main__":
    main()
