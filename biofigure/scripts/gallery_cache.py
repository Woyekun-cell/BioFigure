"""Cache the published gallery UI and fetch only requested public figure files."""
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import tempfile
from urllib.error import HTTPError
from urllib.parse import quote, unquote, urlsplit
from urllib.request import Request, urlopen


DEFAULT_BASE = "https://woyekun-cell.github.io/BioFigure/"
MAX_FILE_BYTES = 64 * 1024 * 1024
UI_FILES = (
    "atlas.js", "atlas.css", "showcase.js", "sky.js", "sky.css",
    "vendor/anime.umd.min.js",
)


class _Index(HTMLParser):
    def __init__(self):
        super().__init__()
        self.embedded = []
        self.references = set()
        self.capture = False
        self.seen_catalog = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "script" and attrs.get("id") == "atlas-data":
            if self.seen_catalog:
                raise ValueError("The published index contains duplicate gallery data")
            self.seen_catalog = True
            self.capture = True
        value = None
        if tag == "script":
            value = attrs.get("src")
        elif tag == "link":
            value = attrs.get("href")
        if value:
            self.references.add(urlsplit(value).path.removeprefix("./"))

    def handle_endtag(self, tag):
        if tag == "script":
            self.capture = False

    def handle_data(self, data):
        if self.capture:
            self.embedded.append(data)


def _relative(value):
    if not isinstance(value, str) or not value or value != value.strip():
        raise ValueError("Expected a relative public gallery path")
    parsed = urlsplit(value)
    if parsed.scheme or parsed.netloc or parsed.query or parsed.fragment:
        raise ValueError("Expected a relative public gallery path")
    decoded = unquote(parsed.path, errors="strict")
    if (decoded.startswith("/") or "\\" in decoded or unquote(decoded) != decoded
            or any(ord(c) < 32 or ord(c) == 127 for c in decoded)
            or any(not part or part.startswith(".") for part in decoded.split("/"))):
        raise ValueError("The gallery path is outside the public file list")
    return decoded


class OnlineGallery:
    def __init__(self, cache: Path, base=DEFAULT_BASE):
        self.cache = Path(cache).expanduser().resolve()
        self.base = base.rstrip("/") + "/"
        origin = urlsplit(self.base)
        if origin.scheme not in ("https", "http") or not origin.netloc or origin.query or origin.fragment or origin.username:
            raise ValueError("Expected an HTTP(S) gallery base URL")
        self.allowed = set()
        self.rows = {}
        self.warnings = []
        self._hashes = {}

    def _local(self, relative):
        target = (self.cache / relative).resolve()
        if not target.is_relative_to(self.cache):
            raise ValueError("The gallery path escapes its cache")
        return target

    def _download(self, relative, destination, expected=None):
        url = self.base + quote(relative, safe="/")
        destination.parent.mkdir(parents=True, exist_ok=True)
        temporary = None
        try:
            request = Request(url, headers={"User-Agent": "BioFigure gallery cache", "Cache-Control": "no-cache"})
            with urlopen(request, timeout=30) as response:
                final, base = urlsplit(response.geturl()), urlsplit(self.base)
                if ((final.scheme, final.netloc) != (base.scheme, base.netloc)
                        or not unquote(final.path).startswith(unquote(base.path))):
                    raise ValueError("The gallery download redirected outside its public site")
                _relative(unquote(final.path)[len(unquote(base.path)):])
                length = response.headers.get("Content-Length")
                expected_length = int(length) if length and length.isdigit() else None
                if expected_length is not None and expected_length > MAX_FILE_BYTES:
                    raise ValueError("Public gallery files must be at most 64 MiB")
                with tempfile.NamedTemporaryFile(prefix=".download-", dir=destination.parent, delete=False) as output:
                    temporary = Path(output.name)
                    total = 0
                    digest = hashlib.sha256()
                    while chunk := response.read(1024 * 1024):
                        total += len(chunk)
                        if total > MAX_FILE_BYTES:
                            raise ValueError("Public gallery files must be at most 64 MiB")
                        output.write(chunk)
                        digest.update(chunk)
                if expected_length is not None and total != expected_length:
                    raise ValueError("The public gallery download is incomplete")
                if expected and digest.hexdigest() != expected:
                    raise ValueError("The public gallery file does not match its published SHA-256")
            temporary.replace(destination)
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)

    def _resource(self, value, allowed, hashes, expected=None):
        parsed = urlsplit(value) if isinstance(value, str) else None
        if parsed and parsed.scheme in ("https", "http") and parsed.netloc:
            return None
        relative = _relative(value)
        if expected is not None:
            if not isinstance(expected, str) or not re.fullmatch(r"[a-fA-F0-9]{64}", expected):
                raise ValueError("Invalid published SHA-256 for a gallery resource")
            expected = expected.lower()
            if relative in hashes and hashes[relative] != expected:
                raise ValueError("Conflicting hashes for a gallery resource")
            hashes[relative] = expected
        allowed.add(relative)
        return relative

    def prepare(self) -> Path:
        self.cache.mkdir(parents=True, exist_ok=True)
        warnings = []
        with tempfile.TemporaryDirectory(prefix=".refresh-", dir=self.cache) as staging:
            stage = Path(staging)
            for name in ("gallery.json", "index.html"):
                self._download(name, stage / name)
            catalog = json.loads((stage / "gallery.json").read_text(encoding="utf-8"))
            index = _Index()
            index.feed((stage / "index.html").read_text(encoding="utf-8"))
            if not index.embedded or json.loads("".join(index.embedded)) != catalog:
                raise ValueError("The published gallery index and gallery.json differ. Retry after deployment completes.")
            rows = catalog.get("figures")
            if not isinstance(rows, list) or any(not isinstance(row, dict) or not isinstance(row.get("id"), str) for row in rows):
                raise ValueError("The published gallery contains invalid figure records")
            by_id = {row["id"]: row for row in rows}
            if len(by_id) != len(rows):
                raise ValueError("The published gallery contains duplicate figure IDs")
            allowed, hashes = {"gallery.json", "index.html"}, {}
            for row in rows:
                for field in ("image", "thumbnail"):
                    relative = self._resource(row.get(field), allowed, hashes, row.get(field + "_sha256"))
                    if relative is None:
                        raise ValueError("Figure previews must use relative public gallery paths")
                if value := row.get("pdf"):
                    self._resource(value, allowed, hashes, row.get("pdf_sha256"))
                for resources in row.get("resources", {}).values():
                    for resource in resources:
                        self._resource(resource["url"], allowed, hashes, resource.get("sha256"))
            for name in UI_FILES:
                try:
                    self._download(name, stage / name)
                except HTTPError as error:
                    error.close()
                    if error.code != 404 or name in index.references:
                        raise
                    warnings.append(f"Published gallery file returned HTTP 404 and is not referenced by index.html: {name}")
                    continue
                allowed.add(name)
            for relative in allowed.intersection({"gallery.json", "index.html", *UI_FILES}):
                target = self._local(relative)
                target.parent.mkdir(parents=True, exist_ok=True)
                (stage / relative).replace(target)
            self.rows, self.allowed, self._hashes = by_id, allowed, hashes
            self.warnings = warnings
        return self.cache

    def ensure(self, path) -> Path:
        relative = _relative(path)
        if relative not in self.allowed:
            raise FileNotFoundError("The file is not in the current public gallery")
        target = self._local(relative)
        expected = self._hashes.get(relative)
        if target.is_file():
            if not expected:
                return target
            with target.open("rb") as source:
                if hashlib.file_digest(source, "sha256").hexdigest() == expected:
                    return target
        self._download(relative, target, expected)
        return target

    def ensure_figures(self, ids):
        if not isinstance(ids, list) or any(not isinstance(key, str) or key not in self.rows for key in ids):
            raise ValueError("Choose references from the current atlas")
        for key in dict.fromkeys(ids):
            row = self.rows[key]
            for field in ("image", "thumbnail", "pdf"):
                if value := row.get(field):
                    if urlsplit(value).scheme not in ("https", "http"):
                        self.ensure(value)
            for resources in row.get("resources", {}).values():
                for resource in resources:
                    parsed = urlsplit(resource["url"])
                    if parsed.scheme not in ("https", "http"):
                        self.ensure(resource["url"])
