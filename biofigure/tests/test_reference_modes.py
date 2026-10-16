"""Portable original design must retain scientific and six-dimensional QA gates."""
import copy
import importlib.util
import json
from argparse import Namespace
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import yaml
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))


def load_module(name):
    spec = importlib.util.spec_from_file_location('modes_test_' + name, ROOT / 'scripts' / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def original_request():
    return {'operation': 'draw', 'figure_task': 'group-distribution', 'figure_family': 'distribution',
            'pattern_id': 'DIST-BOX-001', 'data_shape': '24 independent samples; sample_id, group, value (a.u.); 12 per group',
            'primary_domain': 'imaging-assay', 'primary_role': 'comparison', 'backend': 'R',
            'deliverable': 'quick-png', 'statistics_required': False}


def original_spec(directory, receipt):
    """Scientific/render protocol fixture, never evidence of an inspected figure."""
    directory = Path(directory)
    doc = yaml.safe_load((ROOT / 'schemas/examples/marker-dotplot.yaml').read_text())
    style = directory / 'project-style.yaml'
    style.write_bytes((ROOT / 'schemas/examples/project-style.yaml').read_bytes())
    doc['project_style_contract']['registry_path'] = str(style)
    doc.update(reference_mode='original', figure_task='group-distribution', candidate_patterns=['DIST-BOX-001'],
               selected_pattern='DIST-BOX-001', statistics_required=False,
               role_contract={'primary_role': 'comparison', 'secondary_roles': []},
               deliverable_contract={'target': 'quick-png', 'required_formats': ['png']})
    doc['biology_contract']['primary_domain'] = 'imaging-assay'
    doc['output_size']['formats'] = ['png']
    doc['output_size']['size_rationale']['override_basis'] = 'Unit-test fixture retains example canvas; not a figure-quality judgment.'
    doc['output_size']['size_rationale']['density'] = 'high'
    doc['reference_evidence'] = {
        'preparation_id': receipt['preparation_id'], 'preparation_request': receipt['request'],
        'selected_method_case_id': receipt['selected_reference_candidates']['planner_selected'],
        'retrieval_query': {'domain': 'distribution', 'task': 'group-distribution', 'pattern': 'DIST-BOX-001'}}
    doc['reference_analysis'] = {
        'figure_family': 'distribution', 'semantic_purpose': 'Display all independent observations and quartiles.',
        'panels': [{'id': 'main', 'role': 'group distribution', 'position': 'full canvas'}],
        'elements': [{'id': 'points', 'role': 'observations', 'geometry': 'points', 'position': 'within group', 'data_mapping': 'value by group', 'required': True},
                     {'id': 'boxes', 'role': 'summary', 'geometry': 'boxplot', 'position': 'within group', 'data_mapping': 'quartiles by group', 'required': True}],
        'relationships': [{'from': 'points', 'to': 'boxes', 'type': 'shares-coordinate', 'shared_key': 'group'}],
        'spatial_topology': {'coordinate_system': 'cartesian', 'reading_order': ['Control', 'Treatment'], 'alignment_keys': ['group'], 'layer_order': ['boxes', 'points']},
        'required_structures': ['all 24 observations'], 'forbidden_substitutions': ['mean-only bars']}
    doc['design_target'] = {key: {'observation': 'Two independent groups and a small sample count.',
                                  'implementation': 'Raw observations over quartiles at the final declared size.',
                                  'difference_reason': 'Original design follows the current data and question.'}
                            for key in ('hierarchy', 'geometry', 'palette', 'typography', 'marks', 'annotation')}
    doc['text_contract'] = {'allowed_text': ['Control', 'Treatment', 'Value (a.u.)'], 'allow_headings': False}
    doc['output_size']['size_rationale']['longest_label_chars'] = max(map(len, doc['text_contract']['allowed_text']))
    return doc


class ReferenceModeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name)
        self.prepare = load_module('prepare_figure')
        self.design = load_module('validate_design_spec')

    def test_ordinary_draw_defaults_original_and_uses_local_pattern(self):
        receipt = self.prepare.prepare(original_request())
        self.assertEqual(receipt.get('reference_mode'), 'original')
        self.assertEqual(receipt['status'], 'PREFLIGHT_COMPLETE')
        self.assertEqual(receipt['selected_reference_candidates']['planner_selected'], 'PATTERN-DIST-BOX-001')
        self.assertEqual(receipt['route']['reference_evidence_layers'], {})

    def test_missing_private_archives_do_not_block_original_preflight(self):
        isolated = self.directory / 'biofigure'
        shutil.copytree(ROOT, isolated, ignore=shutil.ignore_patterns('atlas', 'library', 'benchmark', 'examples', '__pycache__'))
        request = self.directory / 'request.yaml'
        request.write_text(yaml.safe_dump(original_request()))
        output = self.directory / 'receipt.json'
        result = subprocess.run([sys.executable, str(isolated / 'scripts/prepare_figure.py'), str(request), '--output', str(output)], capture_output=True, text=True, cwd=self.directory)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        receipt = json.loads(output.read_text())
        self.assertEqual(receipt['reference_mode'], 'original')
        self.assertFalse(any(name.startswith(('atlas/', 'library/', 'benchmark/')) for name in receipt['source_hashes']))

    def test_original_spec_needs_no_source_figure_or_doi_but_keeps_design_analysis(self):
        receipt = self.prepare.prepare(original_request())
        doc = original_spec(self.directory, receipt)
        schema = self.design.load(self.design.SCHEMA)
        self.assertEqual(self.design.validate(doc, schema, self.directory / 'spec.yaml'), [])
        del doc['reference_analysis']['spatial_topology']
        self.assertTrue(any('spatial_topology' in error for error in self.design.validate(doc, schema)))

    def test_paper_pdf_deliverable_requires_both_final_pdf_and_png_preview(self):
        request = dict(original_request(), deliverable='paper-pdf')
        receipt = self.prepare.prepare(request)
        self.assertEqual(receipt['status'], 'PREFLIGHT_COMPLETE')
        self.assertEqual(receipt['route']['required_formats'], ['pdf', 'png'])
        doc = original_spec(self.directory, receipt)
        doc['deliverable_contract'] = {'target': 'paper-pdf', 'required_formats': ['pdf', 'png']}
        doc['output_size']['formats'] = ['pdf', 'png']
        self.assertEqual(self.design.validate(doc, self.design.load(self.design.SCHEMA)), [])
        receipt_path = self.directory / 'preparation.json'
        receipt_path.write_text(json.dumps(receipt))
        cp = load_module('validate_checkpoints')
        self.assertEqual(cp.validate_preparation_receipt(str(receipt_path), doc), [])
        for formats in (['pdf'], ['png'], ['pdf', 'svg', 'png']):
            with self.subTest(formats=formats):
                changed = copy.deepcopy(doc)
                changed['deliverable_contract']['required_formats'] = formats
                changed['output_size']['formats'] = formats
                self.assertTrue(any('formats' in error for error in self.design.validate(changed, self.design.load(self.design.SCHEMA))))
                self.assertTrue(any('deliverable' in error for error in cp.validate_preparation_receipt(str(receipt_path), changed)))

    def test_original_cp2_cannot_switch_the_bound_pattern_after_preflight(self):
        cp = load_module('validate_checkpoints')
        receipt = self.prepare.prepare(original_request())
        doc = original_spec(self.directory, receipt)
        doc['selected_pattern'] = 'DIST-BAR-RAW-001'
        doc['candidate_patterns'] = ['DIST-BAR-RAW-001']
        doc['reference_evidence']['retrieval_query']['pattern'] = 'DIST-BAR-RAW-001'
        path = self.directory / 'preparation.json'
        path.write_text(json.dumps(receipt))
        self.assertTrue(any('Pattern' in error or 'pattern' in error for error in cp.validate_preparation_receipt(str(path), doc)))

    def test_cp4_requires_every_declared_format_in_actual_deliverables(self):
        import hashlib
        cp = load_module('validate_checkpoints')
        receipt = self.prepare.prepare(dict(original_request(), deliverable='paper-pdf'))
        doc = original_spec(self.directory, receipt)
        doc['deliverable_contract'] = {'target': 'paper-pdf', 'required_formats': ['pdf', 'png']}
        doc['output_size']['formats'] = ['pdf', 'png']
        spec_path = self.directory / 'design.yaml'
        spec_path.write_text(yaml.safe_dump(doc))
        prep_path = self.directory / 'preparation.json'
        prep_path.write_text(json.dumps(receipt))
        png = self.directory / 'fixture.png'
        Image.new('RGB', (100, 100), 'navy').save(png)
        definition = cp.load(cp.DEFINITION)
        entries = [{'id': gate['id'], 'status': 'PASS', 'evidence': {}, 'failures': [], 'next_action': 'Protocol negative test only.'} for gate in definition['checkpoints']]
        entries[2]['evidence'] = {'design_spec': str(spec_path), 'preparation_receipt': str(prep_path), 'selected_pattern': 'DIST-BOX-001'}
        entries[3]['evidence'] = {'artifact': str(png), 'artifact_sha256': hashlib.sha256(png.read_bytes()).hexdigest()}
        entries[4]['evidence'] = {'deliverables': [{'path': str(png), 'sha256': hashlib.sha256(png.read_bytes()).hexdigest()}]}
        errors = cp.validate({'schema_version': 1, 'artifact_id': 'negative-protocol-fixture', 'mode': 'standard', 'checkpoints': entries}, definition)
        self.assertTrue(any('CP4' in error and 'format' in error and 'pdf' in error for error in errors), errors)

    def test_explicit_source_reuse_or_reproduction_cannot_downgrade_to_original(self):
        for fields in ({'operation': 'reproduce'}, {'primary_source': 'https://example.org/figure'},
                       {'learned_method_id': 'SCICASE-007'}, {'reusable_case_id': 'test-case'}):
            with self.subTest(fields=fields), self.assertRaisesRegex(ValueError, 'reference_mode|original'):
                self.prepare.prepare(dict(original_request(), reference_mode='original', **fields))

    def test_unselected_source_suggestions_do_not_require_private_archives(self):
        # Optional discovery can report a missing archive. Explicit adoption must
        # still fail its existing learned-source binding validation.
        retrieve = self.prepare.retrieve_learned
        def unavailable_suggestion(*args, **kwargs):
            result = retrieve(*args, **kwargs)
            for entry in result['results']:
                entry['mandatory_read_set'].append('benchmark/library/MISSING-OPTIONAL-ARCHIVE.txt')
            return result
        with patch.object(self.prepare, 'retrieve_learned', side_effect=unavailable_suggestion):
            receipt = self.prepare.prepare(dict(original_request(), reference_mode='reference-guided', data_shape=original_request()['data_shape'] + '; boxplot with raw points'))
        self.assertEqual(receipt['status'], 'PREFLIGHT_COMPLETE', receipt['missing_material'])
        self.assertFalse(any('MISSING-OPTIONAL' in name for name in receipt['source_hashes']))

    def test_request_spec_mode_mismatch_is_rejected(self):
        receipt = self.prepare.prepare(original_request())
        doc = original_spec(self.directory, receipt)
        doc['reference_mode'] = 'reference-guided'
        path = self.directory / 'receipt.json'
        path.write_text(json.dumps(receipt))
        cp = load_module('validate_checkpoints')
        self.assertTrue(any('reference_mode' in error for error in cp.validate_preparation_receipt(str(path), doc)))

    def test_guided_tutorial_locks_actual_adopted_roles_without_paper_doi(self):
        import hashlib
        cp = load_module('validate_checkpoints')
        asset = self.directory / 'fixture.txt'
        asset.write_text('Protocol fixture; this is not a source figure or review evidence.\n')
        lock = {'schema_version': 1, 'kind': 'primary-source-lock', 'reference_mode': 'reference-guided',
                'query': 'tutorial protocol test', 'project_root': str(self.directory),
                'primary_source': {'kind': 'package-docs', 'title': 'Tutorial fixture', 'url': 'https://example.org/test-only', 'version': 'fixture'},
                'source_files': [{'role': 'figure_asset', 'path': asset.name, 'sha256': hashlib.sha256(asset.read_bytes()).hexdigest()}],
                'adopted_roles': ['figure_asset'], 'inspection': {'original_figure_opened': True},
                'generation_contract': {'author_material_access': 'authorized-inspection-no-copy', 'implementation': 'new-script-from-user-data-and-derived-patterns', 'blind_generation': False}}
        path = self.directory / 'lock.json'
        path.write_text(json.dumps(lock))
        self.assertEqual(cp.validate_reproduction_receipt(str(path)), [])
        self.assertTrue(any('reference_mode' in error for error in cp.validate_reproduction_receipt(str(path), reference_mode='reproduction')))
        lock['adopted_roles'].append('author_code')
        path.write_text(json.dumps(lock))
        self.assertTrue(any('adopted_role' in error for error in cp.validate_reproduction_receipt(str(path))))
        lock['adopted_roles'] = ['figure_asset']
        lock['reference_mode'] = 'reproduction'
        path.write_text(json.dumps(lock))
        errors = cp.validate_reproduction_receipt(str(path))
        self.assertTrue(any('author_code' in error and 'source_data' in error for error in errors))

    def test_source_cp2_still_requires_the_template_binding_contract(self):
        import hashlib
        cp = load_module('validate_checkpoints')
        request = dict(original_request(), reference_mode='reference-guided', data_shape=original_request()['data_shape'] + '; boxplot with raw points')
        receipt = self.prepare.prepare(request)
        receipt.pop('reusable_templates')
        receipt.pop('preparation_id')
        receipt['preparation_id'] = hashlib.sha256(json.dumps(receipt, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
        path = self.directory / 'preparation.json'
        path.write_text(json.dumps(receipt))
        self.assertTrue(any('reusable template contract missing' in error for error in cp.validate_preparation_receipt(str(path), {})))

    def test_original_cannot_use_learned_native_pattern_or_source_lock(self):
        receipt = self.prepare.prepare(original_request())
        doc = original_spec(self.directory, receipt)
        doc['reference_evidence']['primary_source_lock'] = 'source-lock.json'
        errors = self.design.validate(doc, self.design.load(self.design.SCHEMA))
        self.assertTrue(any('original' in error and 'source' in error for error in errors))

    def test_original_keeps_font_and_text_hard_gates(self):
        doc = original_spec(self.directory, self.prepare.prepare(original_request()))
        doc['font_contract']['size_roles_pt']['axis_text'] = 3
        doc['text_contract']['allowed_text'].append('Generated by ChatGPT')
        errors = self.design.validate(doc, self.design.load(self.design.SCHEMA))
        self.assertTrue(any('below minimum' in error for error in errors))
        self.assertTrue(any('production/audit/disclaimer' in error for error in errors))

    def test_original_authorization_binds_mode_and_is_consumed_only_once(self):
        authorization = load_module('authorize_render')
        receipt = self.prepare.prepare(original_request())
        doc = original_spec(self.directory, receipt)
        receipt_path, spec_path = self.directory / 'preparation.json', self.directory / 'spec.yaml'
        receipt_path.write_text(json.dumps(receipt))
        spec_path.write_text(yaml.safe_dump(doc))
        source = self.directory / 'plot.R'
        source.write_text('# Protocol fixture only; no plot rendered.\n')
        output = self.directory / 'authorization.json'
        issued = authorization.issue(receipt_path, spec_path, [source], output)
        self.assertEqual(issued['reference_mode'], 'original')
        self.assertTrue(authorization.consume(output, spec_path, [source]))
        with self.assertRaisesRegex(ValueError, 'already consumed'):
            authorization.consume(output, spec_path, [source])

    def test_authorization_mode_cannot_drift_from_bound_spec_and_receipt(self):
        import hashlib
        authorization = load_module('authorize_render')
        receipt = self.prepare.prepare(original_request())
        doc = original_spec(self.directory, receipt)
        receipt_path, spec_path = self.directory / 'preparation.json', self.directory / 'spec.yaml'
        receipt_path.write_text(json.dumps(receipt))
        spec_path.write_text(yaml.safe_dump(doc))
        source = self.directory / 'plot.R'
        source.write_text('# Protocol fixture only.\n')
        output = self.directory / 'authorization.json'
        issued = authorization.issue(receipt_path, spec_path, [source], output)
        issued['reference_mode'] = 'reference-guided'
        issued.pop('authorization_id')
        issued['authorization_id'] = hashlib.sha256(json.dumps(issued, sort_keys=True).encode()).hexdigest()
        output.write_text(json.dumps(issued))
        with self.assertRaisesRegex(ValueError, 'reference_mode'):
            authorization.consume(output, spec_path, [source])

    def test_original_publication_critic_requires_same_six_design_dimensions(self):
        critics = load_module('run_critics')
        art = self.directory / 'test.png'
        image = Image.new('RGB', (300, 300), 'white')
        ImageDraw.Draw(image).rectangle((40, 40, 100, 260), fill='navy')
        image.save(art)
        doc = {'reference_mode': 'original', 'selected_pattern': 'DIST-BOX-001'}
        design_path = self.directory / 'design.yaml'
        design_path.write_text(yaml.safe_dump(doc))
        evidence = {'artifact': str(art), 'artifact_sha256': critics.sha256(art), 'artifact_opened': True,
                    'inspected_at': '2026-10-16', 'inspector': 'protocol-fixture-only',
                    'viewer_record': {'method': 'direct-open', 'opened_artifact_sha256': critics.sha256(art)},
                    'visual_evidence': {key: {'observation': key + ' test fixture checks required review fields, not actual visual acceptance.'} for key in ('hierarchy', 'whitespace', 'legend', 'title_discipline')},
                    'detected': {key: False for key in ('clipping', 'overlap', 'missing_glyph', 'legend_overlap', 'non_white_background', 'font_fallback', 'unrequested_text', 'small_text', 'text_position', 'label_overlap', 'panel_misalignment', 'footer_text')},
                    'issues': [], 'rendered_text': [], 'critic_reviews': {}}
        for name in ('scientific', 'visual', 'publication', 'anti-ai', 'design-quality'):
            evidence['critic_reviews'][name] = {'status': 'PASS', 'evidence': 'Protocol test fixture only, no scientific or visual acceptance claimed.'}
        evidence['critic_reviews']['design-quality']['dimensions'] = {key: {'status': 'PASS', 'evidence': 'Protocol test fixture verifies the review dimension has concrete evidence.'} for key in ('hierarchy', 'geometry', 'palette', 'typography', 'marks', 'annotation')}
        path = self.directory / 'inspection.yaml'
        path.write_text(yaml.safe_dump(evidence))
        args = Namespace(artifact=str(art), pattern='DIST-BOX-001', mode='publication', inspection_evidence=str(path), design_spec=str(design_path), domain=[])
        result = critics.run(args)
        self.assertEqual(result['status'], 'PASS', result)
        self.assertIn('design-quality', result['critics_run'])
        self.assertNotIn('reference-quality', result['critics_run'])
        for reference_mode, review_name in (('original', 'design-quality'), ('reference-guided', 'reference-quality')):
            with self.subTest(reference_mode=reference_mode):
                doc['reference_mode'] = reference_mode
                design_path.write_text(yaml.safe_dump(doc))
                evidence['critic_reviews'][review_name] = copy.deepcopy(evidence['critic_reviews']['design-quality'])
                dimensions = evidence['critic_reviews'][review_name]['dimensions']
                for dimension in ('hierarchy', 'geometry', 'palette', 'typography', 'marks', 'annotation'):
                    valid_dimension = dimensions.pop(dimension)
                    path.write_text(yaml.safe_dump(evidence))
                    self.assertNotEqual(critics.run(args)['status'], 'PASS', dimension)
                    dimensions[dimension] = valid_dimension
                    for status in ('REVISE', 'FAIL'):
                        dimensions[dimension]['status'] = status
                        path.write_text(yaml.safe_dump(evidence))
                        self.assertNotEqual(critics.run(args)['status'], 'PASS', dimension + status)
                    dimensions[dimension]['status'] = 'PASS'
                path.write_text(yaml.safe_dump(evidence))
                final_review = critics.run(args)
                self.assertEqual(final_review['status'], 'PASS', final_review)
                self.assertIn(review_name, final_review['critics_run'])


if __name__ == '__main__':
    unittest.main()
