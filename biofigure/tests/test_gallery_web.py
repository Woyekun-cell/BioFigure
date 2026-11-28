import io
import json
from email.message import Message
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"scripts"))
import gallery_web


class LocalGalleryWebTests(unittest.TestCase):
    def handler(self,origin="http://127.0.0.1:18807"):
        handler=object.__new__(gallery_web.GalleryHandler)
        handler.path="/BioFigure/api/star"
        handler.headers=Message()
        payload=json.dumps({"id":"chosen","starred":True}).encode()
        for key,value in {"Host":"127.0.0.1:18807","Origin":origin,
                          "Content-Type":"application/json","Content-Length":str(len(payload))}.items():
            handler.headers[key]=value
        handler.rfile=io.BytesIO(payload)
        handler.server=SimpleNamespace(allowed_hosts={"127.0.0.1:18807"},
            rows={"chosen":{"image":"assets/chosen.webp"}})
        handler.responses=[]
        handler.send_json=lambda data,status=200:handler.responses.append((status,data))
        handler.send_error=lambda status:handler.responses.append((status,{}))
        return handler

    def test_first_star_materializes_image_before_cli(self):
        handler=self.handler()
        calls=[]
        handler.server.online=SimpleNamespace(ensure=lambda path:calls.append(("cache",path)))
        def cli(server,*args):
            calls.append(("cli",args[0]))
            return [{"id":"chosen","starred":True}] if args[0]=="list" else None
        with patch.object(gallery_web,"gallery",cli):
            handler.do_POST()
        self.assertEqual(calls,[("cache","assets/chosen.webp"),("cli","star"),("cli","list")])
        self.assertEqual(handler.responses,[(200,{"stars":["chosen"]})])

    def test_foreign_origin_cannot_write_personal_profile(self):
        handler=self.handler("https://woyekun-cell.github.io")
        with patch.object(gallery_web,"gallery") as cli:
            handler.do_POST()
        self.assertEqual(handler.responses[0][0],403)
        cli.assert_not_called()

    def test_local_template_uses_current_catalog_and_escapes_html(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            web=root/"web"
            site=root/"site"
            web.mkdir()
            site.mkdir()
            (web/"index.html").write_text('<script id="atlas-data" type="application/json">__BIOFIGURE_CATALOG__</script>')
            data={"figures":[{"id":"private","title":"</script><script>bad()</script>"}]}
            (site/"gallery.json").write_text(json.dumps(data))
            handler=object.__new__(gallery_web.GalleryHandler)
            handler.server=SimpleNamespace(site=site)
            handler.wfile=io.BytesIO()
            handler.send_response=lambda status:None
            handler.send_header=lambda *args:None
            handler.end_headers=lambda:None
            with patch.object(gallery_web,"WEB",web):
                self.assertTrue(handler.send_local_ui("/BioFigure/"))
            html=handler.wfile.getvalue().decode()
            self.assertEqual(html.count("</script>"),1)
            self.assertNotIn("__BIOFIGURE_CATALOG__",html)
            self.assertEqual(json.loads(html.split(">",1)[1].rsplit("</script>",1)[0]),data)


if __name__=="__main__":
    unittest.main()
