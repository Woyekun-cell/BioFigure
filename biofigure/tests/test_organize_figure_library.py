import hashlib
import importlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))


class OrganizeFigureLibraryTests(unittest.TestCase):
    def setUp(self):
        self.m = importlib.import_module('organize_figure_library')
        self.temp = tempfile.TemporaryDirectory(dir=ROOT.parent / 'work')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.view = self.root / 'library' / '按图型检索'
        self.image = self.root / 'source.png'
        self.code = self.root / 'source.R'
        self.record = self.root / 'record.json'
        self.image.write_bytes(b'image-original')
        self.code.write_text('source-original')
        self.record.write_text('{}')
        self.card = {
            'method_id': 'CASE-001', 'title': '原标题', 'display_name': '森林图_比较_CASE-001',
            'primary_category': '01_森林图', 'categories': ['01_森林图', '02_散点图'],
            'classification_status': 'METADATA_CLASSIFIED', 'classification_basis': 'explicit title',
            'source_record': 'record.json', 'warnings': ['source pairing unverified'],
            'source_images': [self.asset(self.image, 'article-order-candidate-unverified')],
            'code_files': [dict(self.asset(self.code, 'recorded-code-binding'), start=12, end=35)],
            'archive_status': 'needs_review', 'archive_note': 'ambiguous_sections',
        }

    def asset(self, path, status):
        return {'path': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                'mapping_status': status}

    def run_view(self, cards=None):
        return self.m.organize({'cards': cards or [self.card]}, self.view, skill_root=self.root)

    def test_links_preserve_bytes_identity_locators_and_pairing_warnings(self):
        before = {p: p.read_bytes() for p in (self.image, self.code, self.record)}
        result = self.run_view()
        self.assertEqual(result['case_count'], 1)
        self.assertEqual(result['link_count'], 4)
        manifest = json.loads((self.view / '01_链接清单.json').read_text())
        links = manifest['links']
        self.assertEqual(len(links), 4)
        self.assertTrue(all((self.view / x['alias']).is_symlink() for x in links))
        self.assertTrue(all((self.view / x['alias']).resolve() == (self.root / x['original_path']).resolve()
                            for x in links))
        self.assertTrue(all('CASE-001' in x['alias'] for x in links))
        self.assertTrue(all(x['start'] == 12 and x['end'] == 35 for x in links if x['role'] == 'code'))
        rows = manifest['cases']
        self.assertEqual(rows[0]['archive_note'], 'ambiguous_sections')
        self.assertIn('source pairing unverified', rows[0]['warnings'])
        self.assertEqual(rows[0]['validation_status'], 'NOT_VERIFIED')
        self.assertIn('article-order-candidate-unverified', (self.view / '00_分类总索引.tsv').read_text())
        for path, data in before.items():
            self.assertEqual(path.read_bytes(), data)

    def test_idempotent_and_retains_unrelated_files(self):
        first = self.run_view()
        manifest_before = (self.view / '01_链接清单.json').read_bytes()
        extra = self.view / '用户补充.txt'
        extra.write_text('保留')
        second = self.run_view()
        self.assertEqual(first['link_count'], second['link_count'])
        self.assertEqual(manifest_before, (self.view / '01_链接清单.json').read_bytes())
        self.assertEqual(extra.read_text(), '保留')
        self.assertEqual(second['created_links'], 0)

    def test_conflicting_file_refused_before_any_link_is_created(self):
        planned = self.m.plan_library({'cards': [self.card]}, self.view, skill_root=self.root)
        conflict = self.view / planned['links'][-1]['alias']
        conflict.parent.mkdir(parents=True)
        conflict.write_text('用户原文件')
        with self.assertRaisesRegex(ValueError, 'conflict'):
            self.run_view()
        self.assertEqual(conflict.read_text(), '用户原文件')
        self.assertFalse((self.view / '01_链接清单.json').exists())
        self.assertFalse(any(p.is_symlink() for p in self.view.rglob('*')))

    def test_wrong_link_and_symlink_parent_refused(self):
        planned = self.m.plan_library({'cards': [self.card]}, self.view, skill_root=self.root)
        conflict = self.view / planned['links'][0]['alias']
        conflict.parent.mkdir(parents=True)
        conflict.symlink_to(self.code)
        with self.assertRaisesRegex(ValueError, 'conflict'):
            self.run_view()
        self.assertEqual(conflict.resolve(), self.code)
        conflict.unlink()
        other = self.root / 'foreign'
        other.mkdir()
        parent = self.view / '02_散点图'
        parent.symlink_to(other, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'symlink directory'):
            self.run_view()
        self.assertEqual(list(other.iterdir()), [])

    def test_changed_source_hash_refused(self):
        self.image.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'hash mismatch'):
            self.run_view()
        self.assertFalse(self.view.exists())

    def test_stale_links_only_removed_when_still_owned(self):
        self.run_view()
        old_manifest = json.loads((self.view / '01_链接清单.json').read_text())
        old = self.view / old_manifest['links'][0]['alias']
        old.unlink()
        old.write_text('用户替换')
        self.card['display_name'] = '森林图_新名字_CASE-001'
        result = self.run_view()
        self.assertEqual(old.read_text(), '用户替换')
        self.assertEqual(len(result['retained_stale_paths']), 1)
        self.assertEqual(len([p for p in self.view.rglob('*') if p.is_symlink()]), 4)

    def test_unsafe_names_and_duplicate_ids_rejected(self):
        self.card['display_name'] = '../escape'
        with self.assertRaisesRegex(ValueError, 'unsafe'):
            self.run_view()
        self.card['display_name'] = 'safe_CASE-001'
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            self.run_view([self.card, self.card])

    def test_user_modified_generated_index_is_not_overwritten(self):
        self.run_view()
        table = self.view / '00_分类总索引.tsv'
        table.write_text('用户修改的索引')
        with self.assertRaisesRegex(ValueError, 'index conflict'):
            self.run_view()
        self.assertEqual(table.read_text(), '用户修改的索引')

    def test_unsafe_previous_alias_refused_before_new_links(self):
        self.run_view()
        manifest_path = self.view / '01_链接清单.json'
        previous = json.loads(manifest_path.read_text())
        previous['links'][0]['alias'] = '../foreign.txt'
        manifest_path.write_text(json.dumps(previous))
        self.card['display_name'] = '改名_CASE-001'
        with self.assertRaisesRegex(ValueError, 'unsafe alias'):
            self.run_view()
        self.assertFalse(any('改名' in str(p) for p in self.view.rglob('*')))

    def test_existing_same_target_user_link_is_not_adopted(self):
        planned = self.m.plan_library({'cards': [self.card]}, self.view, skill_root=self.root)
        item = planned['links'][0]
        path = self.view / item['alias']
        path.parent.mkdir(parents=True)
        path.symlink_to(item['target'])
        with self.assertRaisesRegex(ValueError, 'unowned link conflict'):
            self.run_view()
        self.assertTrue(path.is_symlink())
        self.assertFalse((self.view / '01_链接清单.json').exists())

    def test_stale_empty_owned_case_directories_are_removed(self):
        user_dir = self.view / '01_森林图/来源图/用户空文件夹'
        user_dir.mkdir(parents=True)
        self.run_view()
        old_case = self.view / '01_森林图/来源图' / self.card['display_name']
        self.card['display_name'] = '森林图_改名_CASE-001'
        self.run_view()
        self.assertFalse(old_case.exists())
        self.assertTrue(user_dir.is_dir())


if __name__ == '__main__':
    unittest.main()
