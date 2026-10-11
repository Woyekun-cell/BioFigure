import importlib
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))


class ReferenceSearchCliTests(unittest.TestCase):
    def setUp(self):
        self.m = importlib.import_module('find_figure_reference')

    def test_cached_discovery_does_not_parse_full_index_or_probe_runtime(self):
        self.m.load_catalog(refresh=True)
        with patch.object(self.m, 'build_catalog', side_effect=AssertionError('cache rebuilt')), \
             patch('subprocess.run', side_effect=AssertionError('runtime probe')):
            result = self.m.find('雨云图')
        self.assertTrue(result['results'])
        self.assertLess(len(json.dumps(result, ensure_ascii=False)), 12000)
        self.assertTrue(all(x['validation_status'] == 'NOT_VERIFIED' for x in result['results']))

    def test_changed_index_invalidates_catalog(self):
        with tempfile.TemporaryDirectory(dir=ROOT.parent / 'work') as temp:
            index, catalog = Path(temp) / 'index.json', Path(temp) / 'catalog.json'
            index.write_text(json.dumps({'entries': [], 'coverage': {}}))
            first = self.m.load_catalog(index_path=index, catalog_path=catalog)
            index.write_text(json.dumps({'entries': [], 'coverage': {'new': 1}}))
            second = self.m.load_catalog(index_path=index, catalog_path=catalog)
            self.assertNotEqual(first['source_index_sha256'], second['source_index_sha256'])
            self.assertEqual(second['coverage'], {'new': 1})

    def test_unknown_id_and_invalid_limit_do_not_fall_back(self):
        with self.assertRaises(ValueError):
            self.m.find('', case_id='SCICASE-does-not-exist')
        with self.assertRaises(ValueError):
            self.m.find('雨云图', limit=0)

    def test_discovery_exposes_absolute_paths_and_read_command(self):
        result = self.m.find('', case_id='SCICASE-024')['results'][0]
        self.assertIn('SCICASE-024', result['read_command'])
        for key in ('source_images', 'code_files'):
            self.assertTrue(result[key])
            self.assertTrue(all(Path(x['path']).is_absolute() for x in result[key] if 'path' in x))

    def test_type_directory_counts_cover_all_original_ids(self):
        result = self.m.list_types(refresh=True)
        self.assertEqual(result['indexed_records'], 425)
        self.assertEqual(sum(x['primary_count'] for x in result['types']), 425)
        self.assertIn('classifier_sha256', self.m.load_catalog())

    def test_type_filter_excludes_old_wrong_ternary_tags(self):
        forest = self.m.find('', category='森林图', case_id='SCICASE-078')['results'][0]
        self.assertEqual(forest['primary_category'], '21_森林图')
        self.assertIn('SCICASE-078', forest['display_name'])
        with self.assertRaisesRegex(ValueError, 'does not belong'):
            self.m.find('', category='三元图', case_id='SCICASE-078')
        browse = self.m.find('', category='森林图')
        self.assertTrue(browse['results'])
        self.assertLess(browse['searched_records'], 425)
        self.assertTrue(all('21_森林图' in c['categories'] for c in browse['results']))
        with self.assertRaisesRegex(ValueError, 'unknown or ambiguous'):
            self.m.find('', category='不存在图型')

    def test_all_ambiguous_code_ownership_is_visible_in_compact_catalog(self):
        catalog = self.m.load_catalog()
        full = json.loads(self.m.INDEX.read_text())
        ids = {e['method_id'] for e in full['entries']
               if e.get('learned_contract', {}).get('status') == 'needs_review'}
        self.assertEqual(len(ids), 40)
        cards = {c['method_id']: c for c in catalog['cards']}
        for method_id in ids:
            self.assertEqual(cards[method_id]['archive_status'], 'needs_review')
            self.assertTrue(any('ownership needs review' in w for w in cards[method_id]['warnings']))
        result = self.m.find('', case_id=sorted(ids)[0])['results'][0]
        self.assertTrue(any('ownership needs review' in w for w in result['warnings']))

    def test_chart_metadata_conflict_is_visible_before_deep_read(self):
        card = self.m.find('', case_id='ASF-V24')['results'][0]
        self.assertEqual(card['classification_status'], 'NEEDS_REVIEW')
        self.assertIn('图型待核', card['display_name'])
        self.assertTrue(any('conflict' in x for x in card['warnings']))


if __name__ == '__main__':
    unittest.main()
