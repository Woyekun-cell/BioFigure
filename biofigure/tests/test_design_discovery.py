"""Reference-first design is independent of paper provenance requirements."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from test_reference_modes import load_module, original_request, original_spec

ROOT = Path(__file__).resolve().parents[1]


class DesignDiscoveryTests(unittest.TestCase):
    def setUp(self):
        self.prepare = load_module('prepare_figure')
        self.cp = load_module('validate_checkpoints')
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name)

    def binding_errors(self, receipt, doc):
        path = self.directory / 'preparation.json'
        path.write_text(json.dumps(receipt), encoding='utf-8')
        return self.cp.validate_preparation_receipt(str(path), doc)

    def reviewed(self, receipt):
        candidate = receipt['design_discovery']['candidates'][0]
        return {'policy_id': 'reference-first-v1', 'strategy': 'reviewed-reference',
                'candidate_id': candidate['candidate_id'], 'files': candidate['files'],
                'inspection': {'figure_opened': True, 'code_read': True},
                'review': {key: 'Protocol fixture only: inspect and adapt the declared ' + key
                           for key in ('structure', 'code', 'data_mapping', 'typography', 'legend_and_layout', 'adaptation')}}

    def test_ordinary_draw_discovers_paired_public_figure_code_before_cp2(self):
        receipt = self.prepare.prepare(original_request())
        discovery = receipt.get('design_discovery', {})
        self.assertEqual(discovery.get('policy_id'), 'reference-first-v1')
        candidates = discovery['candidates']
        self.assertEqual(candidates[0]['candidate_id'], 'PUBLIC-boxplot')
        self.assertEqual({row['role'] for row in candidates[0]['files']},
                         {'figure', 'code', 'provenance', 'metadata'})
        self.assertTrue(all(row['path'] in receipt['source_hashes'] for row in candidates[0]['files']))
        self.assertIn('optional_archive_search', discovery)
        self.assertNotEqual(receipt['retrievals'], {})

    def test_missing_review_cannot_pass_cp2_even_in_original_mode(self):
        receipt = self.prepare.prepare(original_request())
        doc = original_spec(self.directory, receipt)
        doc['reference_evidence'].pop('design_precedent', None)
        errors = self.binding_errors(receipt, doc)
        self.assertTrue(any('design_precedent' in error for error in errors), errors)

    def test_matched_public_recipe_needs_no_doi_or_private_source(self):
        receipt = self.prepare.prepare(original_request())
        doc = original_spec(self.directory, receipt)
        doc['reference_evidence']['design_precedent'] = self.reviewed(receipt)
        self.assertEqual(self.binding_errors(receipt, doc), [])

    def test_unread_code_or_unopened_figure_is_not_a_reference_review(self):
        receipt = self.prepare.prepare(original_request())
        for key in ('figure_opened', 'code_read'):
            doc = original_spec(self.directory, receipt)
            review = self.reviewed(receipt)
            review['inspection'][key] = False
            doc['reference_evidence']['design_precedent'] = review
            self.assertTrue(any(key in error for error in self.binding_errors(receipt, doc)))

    def test_fabricated_candidate_and_edited_code_hash_are_rejected(self):
        receipt = self.prepare.prepare(original_request())
        for mutation in ('id', 'hash'):
            doc = original_spec(self.directory, receipt)
            review = self.reviewed(receipt)
            if mutation == 'id':
                review['candidate_id'] = 'invented-candidate'
            else:
                review['files'] = copy.deepcopy(review['files'])
                next(row for row in review['files'] if row['role'] == 'code')['sha256'] = '0' * 64
            doc['reference_evidence']['design_precedent'] = review
            self.assertTrue(any('design_precedent' in error for error in self.binding_errors(receipt, doc)))

    def test_fallback_cannot_silently_ignore_matching_public_reference(self):
        receipt = self.prepare.prepare(original_request())
        doc = original_spec(self.directory, receipt)
        review = self.reviewed(receipt)
        review['strategy'] = 'pattern-fallback'
        review.pop('candidate_id')
        review.pop('files')
        doc['reference_evidence']['design_precedent'] = review
        self.assertTrue(any('rejected_candidates' in error for error in self.binding_errors(receipt, doc)))

    def test_zero_match_remains_original_but_records_explicit_fallback(self):
        module = load_module('design_discovery')
        with patch.object(module, 'ROOT', self.directory):
            result = module.discover(original_request(), 'boxplot independent observations')
        self.assertEqual(result['candidates'], [])
        self.assertEqual(result['optional_archive_search']['status'], 'UNAVAILABLE')
        self.assertEqual(result['required_action'], 'document-pattern-fallback')

    def test_missing_private_fixed_fixture_does_not_deadlock_ordinary_draw(self):
        request = dict(original_request(), data_shape=original_request()['data_shape'] + '; tree track')
        receipt = self.prepare.prepare(request)
        self.assertEqual(receipt['status'], 'PREFLIGHT_COMPLETE')
        templates = receipt['design_discovery']['locked_template_search']
        self.assertEqual(templates['status'], 'UNAVAILABLE')
        self.assertIn('reason', templates)

    def test_fallback_must_reject_locked_template_candidates_as_well(self):
        module = load_module('design_discovery')
        discovery = {'policy_id': 'reference-first-v1', 'candidates': [],
                     'optional_archive_search': {'results': []},
                     'locked_template_search': {'candidates': [{'case_id': 'LOCKED-1'}]}}
        doc = {'reference_evidence': {'design_precedent': {
            'policy_id': 'reference-first-v1', 'strategy': 'pattern-fallback',
            'fallback_reason': 'No usable scientific reference is available.', 'rejected_candidates': [],
            'review': {key: 'Current-input design decision: ' + key for key in module.REVIEW_KEYS}}}}
        self.assertTrue(any('rejected_candidates' in error for error in module.validate_review(discovery, doc)))

    def test_packaged_replay_cannot_authorize_unrelated_renderer(self):
        module = load_module('design_discovery')
        receipt = self.prepare.prepare(original_request())
        doc = original_spec(self.directory, receipt)
        review = self.reviewed(receipt)
        review.update(strategy='packaged-replay')
        review.pop('inspection')
        doc['reference_evidence']['design_precedent'] = review
        unrelated = self.directory / 'not-the-recipe.R'
        unrelated.write_text('print(1)\n', encoding='utf-8')
        self.assertTrue(module.validate_renderer_sources(receipt, doc, [unrelated]))
        self.assertEqual(module.validate_renderer_sources(receipt, doc, [ROOT / 'examples/portable/render.R']), [])
        for name in ('new-renderer.R', 'new-renderer.Rscript', 'new-renderer.txt', 'new-renderer'):
            path = self.directory / name
            path.write_text('print(1)\n', encoding='utf-8')
            self.assertTrue(module.validate_renderer_sources(receipt, doc, [ROOT / 'examples/portable/render.R', path]), name)

    def test_unique_automatic_pattern_selection_still_finds_its_paired_recipe(self):
        request = dict(original_request(), figure_task='marker-expression-across-cell-types', figure_family='single-cell',
                       primary_domain='single-cell-spatial', primary_role='discovery')
        request.pop('pattern_id')
        receipt = self.prepare.prepare(request)
        self.assertEqual(receipt['status'], 'PREFLIGHT_COMPLETE')
        self.assertEqual(receipt['design_discovery']['candidates'][0]['candidate_id'], 'PUBLIC-bubble')

    def test_new_renderer_cannot_skip_six_design_adaptation_decisions(self):
        receipt = self.prepare.prepare(original_request())
        doc = original_spec(self.directory, receipt)
        review = self.reviewed(receipt)
        review['review'].pop('legend_and_layout')
        doc['reference_evidence']['design_precedent'] = review
        self.assertTrue(any('legend_and_layout' in error for error in self.binding_errors(receipt, doc)))

    def test_status_words_are_not_code_or_design_review(self):
        receipt = self.prepare.prepare(original_request())
        doc = original_spec(self.directory, receipt)
        review = self.reviewed(receipt)
        review['review'] = {key: 'PASS' for key in review['review']}
        doc['reference_evidence']['design_precedent'] = review
        self.assertTrue(any('concrete' in error for error in self.binding_errors(receipt, doc)))


if __name__ == '__main__':
    unittest.main()
