"""Classification tests use literal expectations and the current metadata library."""
import copy
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
try:
    from figure_library_categories import CATEGORY_LABELS, classify_card
except ModuleNotFoundError:
    CATEGORY_LABELS, classify_card = {}, None


class FigureLibraryCategoryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cards = {c['method_id']: c for c in json.loads(
            (ROOT / 'atlas/figure-reference-catalog.json').read_text())['cards']}
        cls.entries = {e['method_id']: e for e in json.loads(
            (ROOT / 'atlas/learned-method-index.json').read_text())['entries']}

    def setUp(self):
        self.assertTrue(callable(classify_card), 'classification function is missing')

    def actual(self, method_id):
        return classify_card(self.cards[method_id], self.entries[method_id])

    def test_library_titles_override_polluted_tags_and_old_categories(self):
        expected = {
            'SCICASE-004': '18_雷达图',
            'SCICASE-032': '17_UpSet图与Venn图',
            'SCICASE-034': '17_UpSet图与Venn图',
            'SCICASE-062': '13_降维图',
            'SCICASE-063': '13_降维图',
            'SCICASE-075': '20_泳道图',
            'SCICASE-078': '21_森林图',
            'REPRO-007': '23_饼图与层级占比图',
        }
        for method_id, category in expected.items():
            with self.subTest(method_id=method_id):
                result = self.actual(method_id)
                self.assertEqual(result['primary_category'], category)
        self.assertNotIn('05_柱状图与条形图', self.actual('SCICASE-004')['categories'])
        self.assertNotIn('02_表达与常规热图', self.actual('REPRO-007')['categories'])
        self.assertNotIn('19_三元图', self.actual('SCICASE-075')['categories'])

    def test_package_names_and_code_primitives_never_classify_unknown_chart(self):
        card = {'method_id': 'BARLEY-X', 'title': 'barley pangenome',
                'type_tags': ['bar', 'heatmap'], 'semantic_text': 'barley ComplexHeatmap Heatmap geom_bar'}
        entry = {'learned_contract': {'packages': ['ComplexHeatmap'],
                 'code_analysis': {'plot_primitives': ['Heatmap', 'geom_bar']}}}
        result = classify_card(card, entry)
        self.assertEqual(result['primary_category'], '99_待分类')
        self.assertEqual(result['classification_status'], 'NEEDS_REVIEW')

    def test_explicit_contract_recovers_locator_only_titles(self):
        expected = {'GEN-ATH27-SYNTENY-001': '25_共线性与序列比对图',
                    'MBE-MAIN-Figure 1C': '14_系统树与层级树',
                    'ASF-V01': '28_地理地图'}
        for method_id, category in expected.items():
            with self.subTest(method_id=method_id):
                result = self.actual(method_id)
                self.assertEqual(result['primary_category'], category)
                self.assertIn(method_id.replace(' ', '_'), result['display_name'])

    def test_composite_keeps_explicit_components_only(self):
        result = self.actual('SCICASE-068')
        self.assertEqual(result['primary_category'], '14_系统树与层级树')
        self.assertIn('02_表达与常规热图', result['categories'])
        self.assertIn('05_柱状图与条形图', result['categories'])

    def test_nested_contract_and_source_shape_fields_are_not_lost(self):
        expected = {'APE-SYNTENY-STACK': '25_共线性与序列比对图',
                    'APE-REGISTERED-GENOME-TRACKS': '26_基因组轨道图',
                    'FLECK-MULTIOMIC-HEATMAP': '02_表达与常规热图',
                    'FLECK-FIXED-GRN': '15_网络图',
                    'EVIDENCE-populus-fig2b-source-001': '05_柱状图与条形图',
                    'CORE-anova-tukey-eight-replicates-data-metadata': '05_柱状图与条形图',
                    'CORE-evidence-sankey': '16_桑基图与冲击图',
                    'CORE-source_data-metadata': '27_曼哈顿图与QQ图',
                    'SIX-PROJECT-biofigure-case-mca-fig2a': '05_柱状图与条形图'}
        for method_id, category in expected.items():
            with self.subTest(method_id=method_id):
                self.assertEqual(self.actual(method_id)['primary_category'], category)

    def test_id_only_title_names_use_documented_purpose(self):
        name = self.actual('GEN-ATH27-SYNTENY-001')['display_name']
        self.assertIn('多基因组带状共线性', name)

    def test_ambiguous_image_code_pairing_has_own_primary_category(self):
        result = self.actual('SCICASE-055')
        self.assertEqual(result['primary_category'], '97_图码配对待核')
        self.assertIn('03_气泡图与DotPlot', result['categories'])
        self.assertEqual(result['classification_status'], 'NEEDS_REVIEW')

    def test_paper_overview_keeps_context_without_becoming_heatmap(self):
        result = self.actual('PAPER-barley-pantranscriptome')
        self.assertEqual(result['primary_category'], '98_论文与项目总览')

    def test_friendly_name_replaces_vague_dimension_titles(self):
        result = self.actual('SCICASE-014')
        self.assertTrue(result['display_name'].startswith('相关性图_'))
        self.assertNotIn('一维变量', result['display_name'])
        self.assertIn('corrplot', result['display_name'])
        self.assertIn('SCICASE-014', result['display_name'])

    def test_genomic_and_embedding_maps_do_not_become_geographic_maps(self):
        for method_id in ('PAN-HIC', 'SIX-PROJECT-biofigure-case-pearson-fig6',
                          'SIX-PROJECT-biofigure-case-ra-fig2'):
            with self.subTest(method_id=method_id):
                self.assertNotIn('28_地理地图', self.actual(method_id)['categories'])
        self.assertEqual(self.actual('PAN-HIC')['primary_category'], '02_表达与常规热图')

    def test_reference_coordinates_do_not_mean_principal_coordinate_analysis(self):
        result = self.actual('GEN-ATH27-COORDINATE-DILUTION-001')
        self.assertNotIn('13_降维图', result['categories'])
        self.assertEqual(result['primary_category'], '06_折线图与时序图')
        explicit = classify_card({'method_id': 'PCOA-CN', 'title': '主坐标分析图'})
        self.assertEqual(explicit['primary_category'], '13_降维图')

    def test_synteny_dotplot_is_sequence_alignment_not_expression_bubbles(self):
        result = self.actual('PAN-ALIGN')
        self.assertEqual(result['primary_category'], '25_共线性与序列比对图')
        self.assertNotIn('03_气泡图与DotPlot', result['categories'])

    def test_map_scale_bar_is_not_a_bar_chart(self):
        result = self.actual('ASF-V02')
        self.assertEqual(result['primary_category'], '28_地理地图')
        self.assertNotIn('05_柱状图与条形图', result['categories'])
        self.assertIn('33_版式与组合图', result['categories'])
        result = classify_card({'method_id': 'COLOR-KEY', 'title': 'heatmap with color bar'})
        self.assertNotIn('05_柱状图与条形图', result['categories'])

    def test_broad_scatter_bubble_family_does_not_claim_bubble_size_encoding(self):
        for method_id in ('GEN-BARLEY-TFBS-COHERENCE-001', 'REPRO-089'):
            with self.subTest(method_id=method_id):
                result = self.actual(method_id)
                self.assertNotIn('03_气泡图与DotPlot', result['categories'])
                self.assertIn('07_散点图与回归图', result['categories'])
        self.assertIn('03_气泡图与DotPlot', self.actual('SCICASE-132')['categories'])

    def test_page_or_network_layout_words_do_not_create_composite_class(self):
        for method_id in ('APE-BINNED-DIVERGENCE', 'GEN-DPM-EVIDENCE-PIE-NETWORK-003'):
            with self.subTest(method_id=method_id):
                self.assertNotIn('33_版式与组合图', self.actual(method_id)['categories'])
        result = self.actual('GEN-DPM-EVIDENCE-PIE-NETWORK-003')
        self.assertIn('15_网络图', result['categories'])
        self.assertIn('23_饼图与层级占比图', result['categories'])
        self.assertEqual(self.actual('SIX-PROJECT-biofigure-case-singlecell-qc')['primary_category'],
                         '33_版式与组合图')

    def test_title_and_recorded_visual_structure_conflict_remains_reviewable(self):
        result = self.actual('ASF-V24')
        self.assertEqual(result['classification_status'], 'NEEDS_REVIEW')
        self.assertIn('28_地理地图', result['categories'])
        self.assertIn('03_气泡图与DotPlot', result['categories'])
        self.assertIn('06_折线图与时序图', result['categories'])
        self.assertIn('conflict', result['classification_basis'])
        self.assertTrue(result['classification_warnings'])
        self.assertIn('ASF-V24', result['display_name'])
        self.assertIn('图型待核', result['display_name'])

    def test_names_are_portable_bounded_and_collision_resistant(self):
        first = classify_card({'method_id': 'odd/id', 'title': '热图/' + '很长的用途' * 90})
        second = classify_card({'method_id': 'odd:id', 'title': '热图/' + '很长的用途' * 90})
        self.assertNotEqual(first['display_name'], second['display_name'])
        for result in (first, second):
            name = result['display_name']
            self.assertLessEqual(len(name.encode('utf-8')), 160)
            self.assertNotRegex(name, r'[/\\<>:"|?*\x00-\x1f]')

    def test_full_library_is_nonmutating_deterministic_and_name_unique(self):
        before = copy.deepcopy(self.cards)
        names = set()
        for method_id, card in self.cards.items():
            with self.subTest(method_id=method_id):
                result = classify_card(card, self.entries[method_id])
                self.assertEqual(result, classify_card(card, self.entries[method_id]))
                self.assertIn(result['primary_category'], CATEGORY_LABELS)
                self.assertIn(result['primary_category'], result['categories'])
                self.assertEqual(len(result['categories']), len(set(result['categories'])))
                self.assertLessEqual(len(result['display_name'].encode('utf-8')), 160)
                self.assertNotIn(result['display_name'], names)
                names.add(result['display_name'])
        self.assertEqual(before, self.cards)


if __name__ == '__main__':
    unittest.main()
