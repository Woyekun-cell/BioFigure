import hashlib
from io import BytesIO
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.parse import unquote, urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import gallery_cache


class Response(BytesIO):
    def __init__(self, payload, url, *, content_length=True):
        super().__init__(payload)
        self.url = url
        self.headers = {"Content-Length": str(len(payload))} if content_length else {}

    def geturl(self):
        return self.url


class OnlineGalleryTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.gallery = gallery_cache.OnlineGallery(self.root / "cache")
        code = b"print('public code')\n"
        self.catalog = {"figures": [{
            "id": "a", "image": "assets/a.webp", "thumbnail": "assets/a-preview.webp",
            "pdf": "assets/a.pdf", "resources": {
                "code": [{"url": "resources/a/code/draw.py", "sha256": hashlib.sha256(code).hexdigest()}],
                "data": [{"url": "resources/a/data/table.csv"}, {"url": "https://paper.test/original.csv"}],
            },
        }]}
        self.payloads = {name: ("/* " + name + " */").encode() for name in gallery_cache.UI_FILES}
        self.payloads.update({
            "assets/a.webp": b"original", "assets/a-preview.webp": b"thumbnail",
            "assets/a.pdf": b"pdf", "resources/a/code/draw.py": code,
            "resources/a/data/table.csv": b"x,y\n1,2\n",
        })
        self.calls = []
        self.without_length = set()
        self.redirects = {}
        self.update_metadata()
        mocked = patch.object(gallery_cache, "urlopen", side_effect=self.open)
        mocked.start()
        self.addCleanup(mocked.stop)

    def update_metadata(self):
        encoded = json.dumps(self.catalog)
        self.payloads["gallery.json"] = encoded.encode()
        self.payloads["index.html"] = (
            '<link rel="stylesheet" href="./atlas.css"><script src="./atlas.js"></script>'
            '<script id="atlas-data" type="application/json">' + encoded + "</script>"
        ).encode()

    def open(self, request, timeout):
        self.assertEqual(timeout, 30)
        url = request.full_url
        self.assertTrue(url.startswith(gallery_cache.DEFAULT_BASE))
        relative = unquote(urlsplit(url).path.removeprefix("/BioFigure/"))
        self.calls.append(relative)
        if relative not in self.payloads:
            raise HTTPError(url, 404, "Not Found", {}, None)
        return Response(self.payloads[relative], self.redirects.get(relative, url),
                        content_length=relative not in self.without_length)

    def test_prepare_only_fetches_ui_then_selected_files_are_lazy_and_reused(self):
        self.assertEqual(self.gallery.prepare(), (self.root / "cache").resolve())
        self.assertEqual(set(self.calls), {"gallery.json", "index.html", *gallery_cache.UI_FILES})
        self.assertFalse((self.gallery.cache / "assets").exists())
        self.gallery.ensure_figures(["a", "a"])
        selected = {"assets/a.webp", "assets/a-preview.webp", "assets/a.pdf",
                    "resources/a/code/draw.py", "resources/a/data/table.csv"}
        self.assertTrue(selected <= set(self.calls))
        self.assertEqual(len(self.calls), 8 + len(selected))
        self.gallery.ensure_figures(["a"])
        self.assertEqual(len(self.calls), 8 + len(selected))
        self.assertFalse((self.root / "personal.sqlite").exists())

    def test_every_selected_id_is_downloaded_even_when_there_are_more_than_twelve(self):
        for number in range(13):
            ident = f"figure-{number}"
            row = {"id": ident, "image": f"assets/{ident}.webp", "thumbnail": f"assets/{ident}-preview.webp"}
            self.catalog["figures"].append(row)
            self.payloads[row["image"]] = b"full"
            self.payloads[row["thumbnail"]] = b"preview"
        self.update_metadata()
        self.gallery.prepare()
        ids = [row["id"] for row in self.catalog["figures"]]
        self.gallery.ensure_figures(ids)
        self.assertEqual(len(self.gallery.rows), 14)
        for row in self.catalog["figures"]:
            self.assertTrue((self.gallery.cache / row["image"]).is_file())
            self.assertTrue((self.gallery.cache / row["thumbnail"]).is_file())

    def test_invalid_paths_unknown_paths_and_symlink_escape_never_download(self):
        self.gallery.prepare()
        before = len(self.calls)
        for path in ("../outside", "/assets/a.webp", "assets/.secret", "assets/../a.webp",
                     "https://evil.test/a.webp", "//evil.test/a.webp", "assets/%2e%2e/a.webp",
                     "assets/%252e%252e/a.webp", "assets\\a.webp", "assets/a.webp?token=1",
                     "assets/a.webp#fragment", "assets/%00a.webp"):
            with self.subTest(path=path), self.assertRaises(ValueError):
                self.gallery.ensure(path)
        with self.assertRaises(FileNotFoundError):
            self.gallery.ensure("assets/unlisted.webp")
        (self.gallery.cache / "assets").symlink_to(self.root)
        with self.assertRaises(ValueError):
            self.gallery.ensure("assets/a.webp")
        with self.assertRaises(ValueError):
            self.gallery.ensure_figures(["a", "unknown"])
        self.assertEqual(len(self.calls), before)

    def test_inconsistent_embedded_catalog_keeps_the_previously_usable_ui(self):
        self.gallery.prepare()
        previous = {name: (self.gallery.cache / name).read_bytes()
                    for name in ("gallery.json", "index.html", "atlas.js")}
        self.payloads["gallery.json"] = b'{"figures": []}'
        with self.assertRaisesRegex(ValueError, "index and gallery.json differ"):
            self.gallery.prepare()
        for name, content in previous.items():
            self.assertEqual((self.gallery.cache / name).read_bytes(), content)
        self.assertEqual(list(self.gallery.cache.glob(".refresh-*")), [])

    def test_optional_ui_404_is_reported_but_referenced_ui_is_required(self):
        del self.payloads["sky.js"]
        self.gallery.prepare()
        self.assertEqual(len(self.gallery.warnings), 1)
        self.assertIn("HTTP 404", self.gallery.warnings[0])
        self.assertIn("sky.js", self.gallery.warnings[0])
        with self.assertRaises(FileNotFoundError):
            self.gallery.ensure("sky.js")
        del self.payloads["atlas.js"]
        with self.assertRaises(HTTPError):
            self.gallery.prepare()

    def test_over_limit_files_are_rejected_with_or_without_content_length(self):
        self.gallery.prepare()
        for header in (True, False):
            if not header:
                self.without_length.add("assets/a.webp")
            with self.subTest(content_length=header), patch.object(gallery_cache, "MAX_FILE_BYTES", 4):
                with self.assertRaisesRegex(ValueError, "at most 64 MiB"):
                    self.gallery.ensure("assets/a.webp")
            self.assertFalse((self.gallery.cache / "assets/a.webp").exists())
            self.assertEqual(list((self.gallery.cache / "assets").glob(".download-*")), [])

    def test_wrong_resource_hash_does_not_replace_an_existing_file(self):
        self.gallery.prepare()
        target = self.gallery.cache / "resources/a/code/draw.py"
        target.parent.mkdir(parents=True)
        target.write_bytes(b"previous")
        self.payloads["resources/a/code/draw.py"] = b"wrong content"
        with self.assertRaisesRegex(ValueError, "SHA-256"):
            self.gallery.ensure("resources/a/code/draw.py")
        self.assertEqual(target.read_bytes(), b"previous")
        self.assertEqual(list(target.parent.glob(".download-*")), [])
        self.payloads["resources/a/code/draw.py"] = b"print('public code')\n"
        self.gallery.ensure("resources/a/code/draw.py")
        self.assertEqual(target.read_bytes(), self.payloads["resources/a/code/draw.py"])

    def test_redirect_to_another_site_is_rejected(self):
        self.gallery.prepare()
        for destination in ("https://evil.test/copied.webp", gallery_cache.DEFAULT_BASE + "../secret"):
            self.redirects["assets/a.webp"] = destination
            with self.subTest(redirect=destination), self.assertRaises(ValueError):
                self.gallery.ensure("assets/a.webp")
        self.assertFalse((self.gallery.cache / "assets/a.webp").exists())

    def test_external_original_pdf_is_skipped_and_foreign_previews_are_rejected(self):
        self.catalog["figures"][0]["pdf"] = "https://paper.test/original.pdf"
        self.update_metadata()
        self.gallery.prepare()
        self.gallery.ensure_figures(["a"])
        self.assertNotIn("assets/a.pdf", self.calls)
        self.catalog["figures"][0]["image"] = "https://paper.test/preview.png"
        self.update_metadata()
        with self.assertRaisesRegex(ValueError, "previews must use relative"):
            self.gallery.prepare()

    def test_second_start_loads_local_catalog_without_downloads_or_overwrites(self):
        self.gallery.prepare()
        self.gallery.ensure("resources/a/code/draw.py")
        before = {path.relative_to(self.gallery.cache): (path.read_bytes(), path.stat().st_mtime_ns)
                  for path in self.gallery.cache.rglob("*") if path.is_file()}
        requests_before = len(self.calls)
        self.catalog["figures"].append({"id": "new-public-card", "image": "assets/new.webp",
                                        "thumbnail": "assets/new-preview.webp"})
        self.update_metadata()
        self.payloads["atlas.js"] = b"new public UI"
        self.payloads["resources/a/code/draw.py"] = b"changed remote source"
        restarted = gallery_cache.OnlineGallery(self.gallery.cache)
        with patch.object(gallery_cache, "urlopen", side_effect=AssertionError("Load must not use the network")):
            self.assertEqual(restarted.load(), self.gallery.cache)
            self.assertEqual(set(restarted.rows), {"a"})
            self.assertEqual(restarted.allowed, self.gallery.allowed)
            self.assertEqual(restarted._hashes, self.gallery._hashes)
            self.assertEqual(restarted.ensure("resources/a/code/draw.py").read_bytes(), b"print('public code')\n")
        self.assertEqual(len(self.calls), requests_before)
        after = {path.relative_to(self.gallery.cache): (path.read_bytes(), path.stat().st_mtime_ns)
                 for path in self.gallery.cache.rglob("*") if path.is_file()}
        self.assertEqual(after, before)

    def test_load_requires_matching_local_metadata_and_cached_referenced_ui(self):
        self.gallery.prepare()
        requests_before = len(self.calls)
        (self.gallery.cache / "atlas.js").unlink()
        with self.assertRaisesRegex(FileNotFoundError, "required UI file: atlas.js"):
            gallery_cache.OnlineGallery(self.gallery.cache).load()
        (self.gallery.cache / "atlas.js").write_bytes(self.payloads["atlas.js"])
        (self.gallery.cache / "gallery.json").write_text('{"figures": []}')
        with self.assertRaisesRegex(ValueError, "index and gallery.json differ"):
            gallery_cache.OnlineGallery(self.gallery.cache).load()
        self.assertEqual((self.gallery.cache / "gallery.json").read_text(), '{"figures": []}')
        self.assertEqual(len(self.calls), requests_before)

    def test_load_validates_resource_paths_and_hashes_without_downloading(self):
        self.gallery.prepare()
        requests_before = len(self.calls)
        for value in ("../private.csv", "assets/.hidden"):
            self.catalog["figures"][0]["resources"]["data"][0]["url"] = value
            self.update_metadata()
            for name in ("index.html", "gallery.json"):
                (self.gallery.cache / name).write_bytes(self.payloads[name])
            with self.subTest(path=value), self.assertRaises(ValueError):
                gallery_cache.OnlineGallery(self.gallery.cache).load()
        self.catalog["figures"][0]["resources"]["data"][0]["url"] = "resources/a/data/table.csv"
        self.catalog["figures"][0]["resources"]["code"][0]["sha256"] = "not-a-sha256"
        self.update_metadata()
        for name in ("index.html", "gallery.json"):
            (self.gallery.cache / name).write_bytes(self.payloads[name])
        with self.assertRaisesRegex(ValueError, "Invalid published SHA-256"):
            gallery_cache.OnlineGallery(self.gallery.cache).load()
        self.assertEqual(len(self.calls), requests_before)

    def test_load_of_missing_cache_does_not_create_it(self):
        missing = self.root / "not-created"
        with self.assertRaises(FileNotFoundError):
            gallery_cache.OnlineGallery(missing).load()
        self.assertFalse(missing.exists())
        self.assertEqual(self.calls, [])


if __name__ == "__main__":
    unittest.main()
