import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import personal_style as taste


class PersonalStyleTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name) / "profile.sqlite"
        self.db = taste.connect(self.path)
        self.addCleanup(self.db.close)

    def signal(self, task, value="points", source="request", family="time-series"):
        taste.observe(self.db, family, task, "point_emphasis", value, source)

    def test_requests_revisions_and_changed_taste(self):
        for _ in range(5):
            self.signal("one")
        self.signal("one","balanced","output")
        self.signal("two")
        self.assertEqual(taste.preferences(self.db,"time-series"), {})
        self.signal("three")
        self.assertEqual(taste.preferences(self.db,"time-series")["point_emphasis"], "points")
        for task in ("four","five","six"):
            self.signal(task,"balanced")
        self.assertEqual(taste.preferences(self.db,"time-series")["point_emphasis"], "balanced")
        self.assertFalse(taste.snapshot("matrix",self.path)["defaults"])
        self.assertEqual(self.db.execute("SELECT count(*) FROM figures").fetchone()[0], 0)

    def test_observation_threshold_and_scope(self):
        for i in range(3):
            self.signal(str(i), source="output")
        for i in range(3):
            self.signal(str(i), source="output", family="matrix")
        self.assertFalse(taste.preferences(self.db,"time-series"))
        self.signal("other","balanced","output")
        self.signal("last", source="output")
        self.assertEqual(taste.snapshot("time-series",self.path)["defaults"], {"point_emphasis":"points"})
        self.assertFalse(taste.snapshot("matrix",self.path)["defaults"])
        with self.assertRaises(ValueError):
            taste.observe(self.db,"time-series","task","sampling","repeated","output")

    def test_import_copy_dedup_like_and_unlike(self):
        from PIL import Image
        img = self.path.parent/"my reference.png"
        Image.new("RGB",(5,5),"white").save(img)
        key = taste.collect(self.db,img)
        self.assertFalse(taste.favorites(self.db,"matrix"))
        self.assertEqual(key,taste.collect(self.db,img,starred=True,tags=["留白"]))
        img.unlink()
        ref, = taste.favorites(self.db,"matrix")
        self.assertTrue(Path(ref["image"]).is_file())
        self.assertEqual(ref["tags"],["留白"])
        self.assertFalse(taste.preferences(self.db,"matrix"))
        taste.mark(self.db,key,False)
        self.assertFalse(taste.favorites(self.db,"matrix"))
        self.assertEqual(self.db.execute("SELECT count(*) FROM figures").fetchone()[0], 1)

    def test_native_picker_actions_without_opening_windows(self):
        from PIL import Image
        img = self.path.parent/"留白 example.png"
        Image.new("RGB",(5,5),"white").save(img)
        for action,enabled in (("导入",False),("★ 喜欢并导入",True)):
            payload = ("\0".join([action,"留白",str(img)])+"\n").encode()
            with patch.object(taste.sys,"platform","darwin"), patch.object(taste.subprocess,"run",
                       return_value=subprocess.CompletedProcess([],0,payload)) as command:
                key, = taste.pick(self.db)
                self.assertEqual(bool(taste.favorites(self.db,"matrix")),enabled)
                self.assertTrue(command.called)
        with patch.object(taste.sys,"platform","darwin"), patch.object(taste.subprocess,"run",
                   return_value=subprocess.CompletedProcess([],0,b"\n")):
            self.assertEqual(taste.pick(self.db),[])

    def test_prepare_reads_same_profile_without_writing_to_other_profiles(self):
        from prepare_figure import finalize_receipt
        for task in ("a","b","c"):
            self.signal(task)
        receipt = {"request":{"figure_family":"time-series"},"code_gate":"BLOCKED"}
        with patch.dict(os.environ,BIOFIGURE_PERSONAL_DB=str(self.path)):
            actual = finalize_receipt(dict(receipt))
            self.assertEqual(actual["personal_style"]["defaults"]["point_emphasis"],"points")
            self.assertEqual(actual["code_gate"],"BLOCKED")
        blank = self.path.with_name("missing.sqlite")
        with patch.dict(os.environ,BIOFIGURE_PERSONAL_DB=str(blank)):
            self.assertNotIn("personal_style",finalize_receipt(dict(actual)))
            self.assertFalse(blank.exists())


if __name__ == "__main__":
    unittest.main()
