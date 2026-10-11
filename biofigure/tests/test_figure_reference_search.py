import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from figure_reference_search import build_catalog, rank_catalog


def entry(method_id, title, category='', **detail):
    return {'method_id': method_id, 'title': title, 'collection': 'test',
            'source_record': 'atlas/test.json', 'source_sha256': 'a' * 64,
            'learned_contract': dict(detail, category=category),
            'material_binding': {'bound': [], 'unresolved': [], 'hash_mismatches': []}}


class FigureReferenceSearchTests(unittest.TestCase):
    def test_full_tokens_do_not_confuse_plot_with_corrplot_or_bar_with_barley(self):
        catalog = build_catalog({'entries': [
            entry('CORR', 'corrplot', '相关性图'),
            entry('BARLEY', 'barley pangenome'),
            entry('PCA', 'PCA principal component'),
            entry('BAR', 'bar plot', '分布图')]})
        self.assertEqual(rank_catalog(catalog, 'PCA plot samples matrix')[0]['method_id'], 'PCA')
        self.assertEqual(rank_catalog(catalog, 'bar plot')[0]['method_id'], 'BAR')
        self.assertEqual(rank_catalog(catalog, 'plot'), [])

    def test_question_stopwords_and_paths_do_not_create_unknown_hits(self):
        item = entry('PAN', 'family prevalence', question='家族在多少个基因组存在？',
                     source_code_files=[{'path': '/secret/no_matching_9471.R', 'sha256': 'b' * 64}])
        item['search_text'] = 'no_matching_9471 arbitrary old search text'
        catalog = build_catalog({'entries': [item]})
        self.assertEqual(rank_catalog(catalog, '不存在的图 no_matching_9471'), [])
        self.assertNotIn('/secret/', catalog['cards'][0]['semantic_text'])
        self.assertNotIn('no_matching_9471', catalog['cards'][0]['semantic_text'])

    def test_chinese_raincloud_aliases_return_identical_candidates(self):
        catalog = build_catalog({'entries': [entry('RAIN', '小提琴+箱式+散点', '云雨图'),
                                              entry('BOX', '箱线图', '分布图')]})
        self.assertEqual([x['method_id'] for x in rank_catalog(catalog, '雨云图')],
                         [x['method_id'] for x in rank_catalog(catalog, '云雨图')])
        self.assertEqual(rank_catalog(catalog, '雨云图')[0]['method_id'], 'RAIN')

    def test_correlation_expression_enrichment_bubbles_remain_distinct(self):
        catalog = build_catalog({'entries': [
            entry('CORR', 'correlation bubble matrix', '相关性图',
                  code_analysis={'plot_primitives': ['geom_point']}),
            entry('EXPR', 'expression DotPlot', '基因/蛋白表达图'),
            entry('ENRICH', 'enrichment bubble', '富集图')]})
        for query, expected in [('相关性气泡图', 'CORR'), ('expression DotPlot', 'EXPR'),
                                ('富集气泡图', 'ENRICH')]:
            self.assertEqual(rank_catalog(catalog, query)[0]['method_id'], expected)

    def test_bound_source_images_exclude_generated_and_comparison_images(self):
        item = entry('CORR', 'correlation heatmap', '相关性图',
                     all_method_records=[{'family': 'correlation', 'validated_pngs': [
                         {'path': 'rendered.png', 'sha256': 'r',
                          'source_image_sha256': 's', 'comparison_sha256': 'c'}]}],
                     source_compared_materials=[{'path': 'original.png', 'sha256': 's'},
                                               {'path': 'comparison.png', 'sha256': 'c'}])
        item['material_binding']['bound'] = [
            {'recorded_path': 'original.png', 'path': 'exact/original.png', 'sha256': 's'},
            {'recorded_path': 'comparison.png', 'path': 'exact/comparison.png', 'sha256': 'c'},
            {'recorded_path': 'rendered.png', 'path': 'exact/rendered.png', 'sha256': 'r'}]
        card = build_catalog({'entries': [item]})['cards'][0]
        self.assertEqual([x['path'] for x in card['source_images']], ['exact/original.png'])
        self.assertEqual(card['validation_status'], 'NOT_VERIFIED')

    def test_recorded_path_maps_assets_without_basename_guess(self):
        item = entry('PAPER', 'GLUE Figure 3', local_asset='source/fig3.png',
                     asset_sha256='s', publisher_page='https://example.test/figures/3',
                     code_bindings=[{'local_source': 'source/figure.py', 'sha256': 'c'}],
                     parent_source_assets=[{'path': 'whole-paper.png', 'sha256': 'p'}])
        item['material_binding']['bound'] = [
            {'recorded_path': 'source/fig3.png', 'path': 'library/exact/fig3.png', 'sha256': 's'},
            {'recorded_path': 'source/figure.py', 'path': 'library/exact/figure.py', 'sha256': 'c'},
            {'recorded_path': 'whole-paper.png', 'path': 'library/whole-paper.png', 'sha256': 'p'}]
        card = build_catalog({'entries': [item]})['cards'][0]
        self.assertEqual(card['source_images'][0]['path'], 'library/exact/fig3.png')
        self.assertEqual(card['code_files'][0]['path'], 'library/exact/figure.py')
        self.assertEqual(len(card['source_images']), 1)

    def test_article_order_images_keep_pairing_uncertainty(self):
        item = entry('REPRO', 'correlation heatmap',
                     source_image_files=[{'path': 'figure.png', 'sha256': 's',
                                          'mapping_status': 'article-order-candidate-unverified'}])
        item['material_binding']['bound'] = [
            {'recorded_path': 'figure.png', 'path': 'library/figure.png', 'sha256': 's'}]
        card = build_catalog({'entries': [item]})['cards'][0]
        self.assertEqual(card['source_images'][0]['mapping_status'], 'article-order-candidate-unverified')
        self.assertTrue(any('article-order' in x for x in card['warnings']))
        item['learned_contract']['source_image_files'][0].pop('mapping_status')
        self.assertEqual(build_catalog({'entries': [item]})['cards'][0]['source_images'][0]['mapping_status'],
                         'article-order-candidate-unverified')

    def test_explicit_id_is_exact_and_unknown_id_raises(self):
        catalog = build_catalog({'entries': [entry('CASE-001', 'PCA')]})
        self.assertEqual(rank_catalog(catalog, 'irrelevant query', case_id='CASE-001')[0]['method_id'], 'CASE-001')
        with self.assertRaisesRegex(ValueError, 'unknown learned method ID'):
            rank_catalog(catalog, '', case_id='CASE-00')

    def test_live_catalog_preserves_all_ids_and_specific_literature_searches(self):
        full = json.loads((ROOT / 'atlas/learned-method-index.json').read_text())
        catalog = build_catalog(full)
        self.assertEqual(len(catalog['cards']), len(full['entries']))
        self.assertEqual({x['method_id'] for x in catalog['cards']}, {x['method_id'] for x in full['entries']})
        for query, prefix in [('T2T-Y HiFi CENP-A', 'NATURE-OMICS-001'),
                              ('GLUE FOSCTTM', 'NATURE-OMICS-004'),
                              ('Numbat CNV posterior', 'NATURE-OMICS-005'),
                              ('tomato pangenome', 'PAN-'),
                              ('mCA league table', 'SIX-PROJECT-biofigure-case-mca'),
                              ('Pearson heteroplasmy UMAP', 'SIX-PROJECT-biofigure-case-pearson')]:
            with self.subTest(query=query):
                self.assertTrue(rank_catalog(catalog, query, 1)[0]['method_id'].startswith(prefix))
        self.assertEqual(rank_catalog(catalog, '不存在的图 no_matching_9471'), [])
        self.assertEqual(rank_catalog(catalog, 'PCA plot samples matrix')[0]['type_tags'].count('pca'), 1)
        upper = rank_catalog(catalog, '上三角相关性热图')[0]
        self.assertEqual(upper['method_id'], 'SCICASE-019')
        self.assertIn('upper-triangle', upper['type_tags'])
        lower = rank_catalog(catalog, '下三角相关性热图')
        self.assertNotIn('SCICASE-019', [x['method_id'] for x in lower])
        disputed = next(x for x in catalog['cards'] if x['method_id'] == 'SCICASE-055')
        self.assertTrue(any('conflict' in x for x in disputed['warnings']))

    def test_real_natural_requests_keep_primary_structure_and_domains(self):
        full = json.loads((ROOT / 'atlas/learned-method-index.json').read_text())
        catalog = build_catalog(full)
        for query in ('相关气泡图', '不同组相关系数矩阵做气泡参考'):
            results = rank_catalog(catalog, query)
            self.assertTrue(results)
            self.assertTrue(all('correlation' in x['domain'] and 'bubble' in x['type_tags'] for x in results))
            self.assertFalse(any('conflict' in x for x in results[0]['warnings']))
        dot = rank_catalog(catalog, '用基因表达汇总矩阵画DotPlot参考')
        self.assertTrue(dot)
        self.assertTrue(all('dotplot' in x['type_tags'] and 'expression' in x['domain'] for x in dot))
        self.assertNotIn('REPRO-089', [x['method_id'] for x in dot])
        self.assertNotIn('GEN-BARLEY-TFBS-COHERENCE-001', [x['method_id'] for x in dot])
        self.assertEqual(rank_catalog(catalog, '三角相关热图')[0]['method_id'], 'SCICASE-019')
        combined = rank_catalog(catalog, '桑基气泡图')
        self.assertTrue(combined)
        self.assertTrue(all({'sankey', 'bubble'} <= set(x['type_tags']) for x in combined))
        pca = rank_catalog(catalog, '样本PCA图参考')
        self.assertTrue(pca)
        self.assertTrue(all('pca' in x['type_tags'] for x in pca))

    def test_geom_point_alone_does_not_prove_a_correlation_bubble_structure(self):
        catalog = build_catalog({'entries': [entry('SCATTER', 'correlation fitted scatter', '相关性图',
                                                    code_analysis={'plot_primitives': ['geom_point']})]})
        self.assertNotIn('bubble', catalog['cards'][0]['type_tags'])
        self.assertEqual(rank_catalog(catalog, 'correlation bubble'), [])

    def test_catalog_build_and_rank_never_read_files_or_probe_runtime(self):
        full = {'entries': [entry('PCA', 'PCA chart', source_code_files=[
            {'path': '/does/not/exist/script.R', 'sha256': 'c'}])]}
        with patch('builtins.open', side_effect=AssertionError('unexpected file read')), \
             patch.object(Path, 'read_text', side_effect=AssertionError('unexpected index read')), \
             patch.object(Path, 'read_bytes', side_effect=AssertionError('unexpected asset hash')), \
             patch('subprocess.run', side_effect=AssertionError('unexpected R/PDF probe')):
            catalog = build_catalog(full)
            result = rank_catalog(catalog, '样本PCA图参考')
        self.assertEqual(result[0]['method_id'], 'PCA')
        self.assertEqual(rank_catalog(catalog, 'PCAish', 3), [])

    def test_recipe_name_and_chart_selection_recall_pca_with_bound_code(self):
        full = json.loads((ROOT / 'atlas/learned-method-index.json').read_text())
        catalog = build_catalog(full)
        result = rank_catalog(catalog, '样本PCA图参考')
        self.assertIn('GEN-BARLEY-ORDINATION-LAYOUT-001', [x['method_id'] for x in result])
        recipe = next(x for x in result if x['method_id'] == 'GEN-BARLEY-ORDINATION-LAYOUT-001')
        self.assertTrue(recipe['code_files'])
        self.assertTrue(any('02_PCA_UMAP_peraccession.R' in x['path'] for x in recipe['code_files']))
        self.assertTrue(any(x.get('start') == 33 and x.get('end') == 94 for x in recipe['code_files']))

    def test_chinese_species_constraints_do_not_select_other_pangenomes(self):
        full = json.loads((ROOT / 'atlas/learned-method-index.json').read_text())
        catalog = build_catalog(full)
        for query, species in [('番茄泛基因组', 'tomato'), ('大麦PCA', 'barley')]:
            result = rank_catalog(catalog, query)
            self.assertTrue(result)
            self.assertTrue(all(species in x['semantic_text'].casefold() for x in result))


if __name__ == '__main__':
    unittest.main()
