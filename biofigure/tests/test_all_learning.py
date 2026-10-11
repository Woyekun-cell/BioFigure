import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from retrieve_learned_methods import retrieve, validate_binding
from build_learned_method_index import build
from retrieve_scidraw import learned_records
from prepare_figure import prepare


class AllLearningTests(unittest.TestCase):
    def test_every_persisted_learning_record_can_be_retrieved_by_its_id(self):
        index = json.loads((ROOT / 'atlas/learned-method-index.json').read_text())
        self.assertEqual(build(), index)
        self.assertEqual(index['coverage']['scidraw'], 157)
        self.assertEqual(index['coverage']['topjournal'], 83)
        self.assertEqual(index['coverage']['awesome-visual'], 29)
        self.assertEqual(index['coverage']['awesome-layout'], 12)
        self.assertEqual(index['coverage']['six-project'], 6)
        for entry in index['entries']:
            with self.subTest(method_id=entry['method_id']):
                result = retrieve('', case_id=entry['method_id'])['results']
                self.assertEqual(len(result), 1)
                self.assertEqual(result[0]['method_id'], entry['method_id'])
                self.assertFalse(result[0]['source_record_changed'])
                self.assertFalse(result[0]['missing_material'])

    def test_previous_unreachable_papers_are_top_candidates(self):
        for query, prefix in [('T2T-Y HiFi CENP-A', 'NATURE-OMICS-001'), ('GLUE FOSCTTМ', 'NATURE-OMICS-004'),
                              ('Numbat CNV posterior', 'NATURE-OMICS-005'), ('msad040 冻融', 'MBE-'),
                              ('tomato pangenome', 'PAN-'), ('two-panel-bubble-fit', 'ASF-RECIPE-two-panel'),
                              ('mCA league table', 'SIX-PROJECT-biofigure-case-mca'),
                              ('Pearson heteroplasmy UMAP', 'SIX-PROJECT-biofigure-case-pearson')]:
            with self.subTest(query=query):
                self.assertTrue(retrieve(query, 1)['results'][0]['method_id'].startswith(prefix))

    def test_natural_chinese_requests_retrieve_learned_methods(self):
        for query in ('我要画一个桑基气泡图', '请用当前数据画分组环状热图', '做一个小提琴图',
                      '我想画番茄泛基因组的核心基因累积图'):
            with self.subTest(query=query):
                self.assertTrue(retrieve(query)['results'])

    def test_explicit_method_cannot_be_discarded_without_scientific_difference(self):
        learning = retrieve('GLUE', case_id='NATURE-OMICS-004')
        receipt = {'query': 'GLUE', 'request': {'figure_task': 'GLUE', 'learned_method_id': 'NATURE-OMICS-004'},
                   'learned_methods': learning}
        spec = {'reference_evidence': {'learned_method_reuse': {'adopted': [],
                'rejected': [{'method_id': 'NATURE-OMICS-004', 'reason': 'none'}]}}}
        self.assertTrue(validate_binding(receipt, spec))

    def test_explicit_fleck_contract_controls_plan_not_unrelated_cluster_heatmap(self):
        receipt = prepare({'figure_task': 'multiomic heatmap', 'figure_family': 'matrix',
                           'data_shape': 'RNA and chromVAR cluster means with shared pseudotime order',
                           'primary_domain': 'single-cell-spatial', 'primary_role': 'comparison', 'backend': 'R',
                           'deliverable': 'quick-png', 'learned_method_id': 'FLECK-MULTIOMIC-HEATMAP'})
        self.assertEqual(receipt['method_plan']['selected_case']['case_id'], 'FLECK-MULTIOMIC-HEATMAP')
        self.assertEqual(receipt['selected_reference_candidates']['planner_selected'], 'FLECK-MULTIOMIC-HEATMAP')
        self.assertNotIn('clusterData', receipt['method_plan']['function_contract'])
        self.assertIn('RNA', str(receipt['method_plan']['data_contract']))

    def test_scidraw_methods_bind_actual_source_case_ids(self):
        corpus = json.loads((ROOT / 'atlas/scidraw-derived-corpus.json').read_text())
        rows = learned_records(corpus)
        self.assertTrue(any(m.get('id') == 'SCIDRAW-RCS-001' for m in rows['SCICASE-038']))
        self.assertTrue(any(m.get('id') == 'SCIDRAW-PCOA-MARGINAL-001' for m in rows['SCICASE-062']))
        self.assertTrue(any(m.get('id') == 'SCIDRAW-HALF-VIOLIN-001' for m in rows['SCICASE-007']))
        self.assertIn('SCICASE-096', rows)

    def test_core_source_files_are_bound_not_only_metadata(self):
        expected = {
            'REPRO-023': 'library/topjournal-corpus/results/code/issue_023/block_001.R',
            'FLECK-MULTIOMIC-HEATMAP': 'library/single-cell/fleck-organoid/sources/author-code/figures/FIGURE_1.R',
            'NATURE-OMICS-004': 'library/nature-genomics-multiomics/sources/gao-lab--GLUE/experiments/TripleOmics/s03_markers.py',
            'ASF-RECIPE-two-panel-bubble-fit': 'examples/awesome-layout-prototypes/render.R',
        }
        for method_id, path in expected.items():
            with self.subTest(method_id=method_id):
                entry = retrieve('', case_id=method_id)['results'][0]
                self.assertIn(path, entry['mandatory_read_set'])
                self.assertIn(path, entry['current_read_hashes'])

    def test_cp2_cannot_delete_learning_candidates_or_forget_prior_defects(self):
        learning = retrieve('GLUE FOSCTTM')
        receipt = {'query': 'GLUE FOSCTTM', 'request': {'figure_task': 'GLUE FOSCTTM'}, 'learned_methods': learning}
        self.assertTrue(validate_binding(receipt, {}))
        changed = dict(receipt, learned_methods=dict(learning, results=[]))
        self.assertTrue(validate_binding(changed, {}))
        ids = [r['method_id'] for r in learning['results']]
        spec = {'reference_evidence': {'learned_method_reuse': {'adopted': ids, 'rejected': [],
                'data_adaptation': 'bind method and seed; summarize input values',
                'known_failures_addressed': 'n=1 is not assigned fabricated SD',
                'source_issue_resolutions': [{'source_path': issue['path'], 'resolution': 'Independent new renderer; do not execute incomplete author fragment; audit current input mapping.'}
                    for entry in learning['results'] for issue in entry['known_source_syntax_issues']]}}}
        self.assertEqual(validate_binding(receipt, spec), [])


if __name__ == '__main__':
    unittest.main()
