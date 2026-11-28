import io
import json
import os
from email.message import Message
from pathlib import Path
import sys
import tempfile
import threading
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

    def settings_server(self,path):
        return SimpleNamespace(host_file=path,host_lock=threading.RLock(),ask_lock=threading.Lock(),
                               renderer=SimpleNamespace(lock=threading.Lock(),host_name="codex",host_cli="codex",model=None),
                               host_name="codex",host_cli="codex",model=None)

    def test_host_model_settings_are_private_and_model_is_optional(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            a=self.settings_server(root/"a-host.json")
            b=self.settings_server(root/"b-host.json")
            with patch("agent_host.shutil.which",side_effect=lambda value:"/bin/"+value):
                saved=gallery_web.change_host(a,{"host":"opencode","model":""})
                self.assertEqual(saved["selected_host"],"opencode")
                self.assertIsNone(saved["model"])
                self.assertEqual(json.loads(a.host_file.read_text()),{"host":"opencode","model":None})
                self.assertFalse(b.host_file.exists())
                self.assertEqual(b.host_name,"codex")
                self.assertEqual(a.renderer.host_name,"opencode")

    def test_busy_host_change_keeps_previous_runtime_and_settings(self):
        with tempfile.TemporaryDirectory() as tmp:
            server=self.settings_server(Path(tmp)/"host.json")
            server.host_file.write_text('{"host":"codex","model":null}')
            previous=server.host_file.read_bytes()
            server.ask_lock.acquire()
            try:
                with self.assertRaises(gallery_web.HostBusy):
                    gallery_web.change_host(server,{"host":"claude","model":None})
            finally:
                server.ask_lock.release()
            self.assertEqual(server.host_name,"codex")
            self.assertEqual(server.host_file.read_bytes(),previous)
            with self.assertRaises(ValueError):
                gallery_web.change_host(server,{"host":"unlisted","model":None})

    def test_api_key_is_private_retained_only_for_same_endpoint_and_can_be_cleared(self):
        with tempfile.TemporaryDirectory() as tmp:
            server=self.settings_server(Path(tmp)/"host.json")
            body={"host":"api","model":"chosen-model","protocol":"openai",
                  "base_url":"https://models.example/v1/","api_key":"test-private-key"}
            with patch("agent_api.ApiAgent"):
                status=gallery_web.change_host(server,body)
                self.assertTrue(status["available"])
                self.assertTrue(status["api"]["key_set"])
                self.assertNotIn("test-private-key",json.dumps(status))
                self.assertEqual(os.stat(server.host_file).st_mode & 0o777,0o600)
                record=json.loads(server.host_file.read_text())
                self.assertEqual(record["api"]["api_key"],"test-private-key")
                self.assertEqual(record["api"]["base_url"],"https://models.example/v1")
                gallery_web.change_host(server,{**body,"api_key":""})
                self.assertEqual(server.api_settings["api_key"],"test-private-key")
                status=gallery_web.change_host(server,{**body,"api_key":"","base_url":"https://other.example/v1"})
                self.assertFalse(status["available"])
                self.assertFalse(status["api"]["key_set"])
                self.assertIsNone(server.renderer.agent)
                gallery_web.change_host(server,body)
                status=gallery_web.change_host(server,{**body,"clear_key":True})
                self.assertFalse(status["api"]["key_set"])

    def test_cli_switch_retains_saved_api_without_exposing_key(self):
        with tempfile.TemporaryDirectory() as tmp:
            server=self.settings_server(Path(tmp)/"host.json")
            body={"host":"api","model":"chosen-model","protocol":"anthropic",
                  "base_url":"https://api.anthropic.com/v1","api_key":"private"}
            with patch("agent_api.ApiAgent"),patch("agent_host.shutil.which",return_value="/bin/claude"):
                gallery_web.change_host(server,body)
                status=gallery_web.change_host(server,{"host":"claude","model":None})
                self.assertEqual(server.api_settings["api_key"],"private")
                self.assertIsNone(server.renderer.agent)
                self.assertNotIn('"api_key"',json.dumps(status))
                self.assertEqual(status["selected_host"],"claude")

    def test_invalid_or_unconstructable_api_does_not_overwrite_settings(self):
        with tempfile.TemporaryDirectory() as tmp:
            server=self.settings_server(Path(tmp)/"host.json")
            server.host_file.write_text('{"host":"codex","model":null}')
            before=server.host_file.read_bytes()
            body={"host":"api","model":"model","protocol":"openai","api_key":"secret"}
            for endpoint in ("http://remote.example/v1","https://user:password@example.com","https://api.example/v1?key=secret"):
                with self.assertRaises(ValueError):
                    gallery_web.change_host(server,{**body,"base_url":endpoint})
            with patch("agent_api.ApiAgent",side_effect=ValueError("Invalid endpoint")):
                with self.assertRaises(ValueError):
                    gallery_web.change_host(server,body)
            self.assertEqual(server.host_file.read_bytes(),before)
            self.assertEqual(server.host_name,"codex")

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
