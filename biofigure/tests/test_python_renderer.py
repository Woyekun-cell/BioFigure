"""Real Matplotlib rendering through the single-use CP2 authorization boundary."""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from authorize_render import issue
from prepare_figure import prepare
from validate_checkpoints import validate_render_receipt

try:
    import matplotlib
    matplotlib.use('Agg')
    from matplotlib.figure import Figure
    from matplotlib import font_manager
    from PIL import Image
except ImportError:
    matplotlib = None


@unittest.skipIf(matplotlib is None, 'Matplotlib rendering extra is not installed')
class PythonRendererTests(unittest.TestCase):
    def setUp(self):
        helper = ROOT / 'scripts/figure_style.py'
        if not helper.is_file():
            self.fail('official Python renderer is not implemented')
        spec = importlib.util.spec_from_file_location('biofigure_test_python_style', helper)
        self.renderer = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.renderer)
        try:
            self.font = self.renderer.bf_font('Arial')
        except ValueError as exc:
            self.skipTest(str(exc))
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name)
        self.design = self.directory / 'design.yaml'
        self.preparation = self.directory / 'preparation.json'
        self.authorization = self.directory / 'authorization.json'
        self.authorization_count = 0
        self.plot_source = self.directory / 'plot.py'
        self.plot_source.write_text('from matplotlib.figure import Figure\n', encoding='utf-8')
        self.sources = [self.plot_source, helper.resolve()]
        self.png = self.directory / 'figure.png'
        self.receipt = Path(str(self.png) + '.render.json')
        request = {'reference_mode': 'reference-guided', 'primary_domain': 'single-cell-spatial',
                   'primary_role': 'discovery', 'backend': 'Python', 'deliverable': 'editable-vector',
                   'figure_task': 'cell-embedding-structure',
                   'data_shape': 'fixed UMAP embedding coordinates and group labels', 'figure_family': 'single-cell'}
        preparation = prepare(request)
        self.preparation.write_text(json.dumps(preparation), encoding='utf-8')
        self.doc = yaml.safe_load((ROOT / 'schemas/examples/marker-dotplot.yaml').read_text())
        registry = yaml.safe_load((ROOT / 'schemas/examples/project-style.yaml').read_text())
        registry['typography']['family'] = 'Arial'
        registry['size_system']['allowed_classes'] = ['single-column']
        registry_path = self.directory / 'project-style.yaml'
        registry_path.write_text(yaml.safe_dump(registry), encoding='utf-8')
        self.doc['project_style_contract'].update(registry_path=str(registry_path),
            registry_sha256=hashlib.sha256(registry_path.read_bytes()).hexdigest())
        self.doc['reference_mode'] = 'reference-guided'
        self.doc['figure_task'] = 'cell-embedding-structure'
        self.doc['candidate_patterns'] = ['SC-UMAP-001']
        self.doc['selected_pattern'] = 'SC-UMAP-001'
        self.doc['reference_evidence']['retrieval_query'].update(task='cell-embedding-structure', pattern='SC-UMAP-001')
        self.doc['backend_lock'].update(backend='Python', lock_id='test-matplotlib-v1')
        self.doc['renderer'] = {'language': 'Python', 'backend': 'matplotlib', 'packages': ['matplotlib']}
        self.doc['font_contract']['family'] = 'Arial'
        self.doc['font_contract']['minimum_final_text_pt'] = 6
        self.doc['output_size'].update(width_mm=90, height_mm=75, size_class='single-column')
        self.doc['output_size']['size_rationale'].update(density='low', longest_label_chars=8,
            recommended_class='single-column', selection_reason='one compact test panel')
        evidence = self.doc['reference_evidence']
        evidence.update(preparation_id=preparation['preparation_id'], preparation_request=preparation['request'],
            selected_method_case_id=preparation['selected_reference_candidates']['planner_selected'],
            learned_method_reuse={'adopted': [], 'rejected': [
                {'method_id': row['method_id'], 'reason': 'test isolates renderer authorization and measured text'}
                for row in preparation['learned_methods']['results']]})
        self.doc['reference_analysis'] = {
            'figure_family': 'single-cell', 'semantic_purpose': 'display marker specificity',
            'panels': [{'id': 'main', 'role': 'primary evidence', 'position': 'full canvas'}],
            'elements': [{'id': 'bubbles', 'role': 'marker expression', 'geometry': 'points',
                          'position': 'matrix cells', 'data_mapping': 'gene by cell type', 'required': True},
                         {'id': 'labels', 'role': 'gene labels', 'geometry': 'text',
                          'position': 'left', 'data_mapping': 'gene labels', 'required': True}],
            'relationships': [{'from': 'bubbles', 'to': 'labels', 'type': 'aligns-with', 'shared_key': 'gene'}],
            'spatial_topology': {'coordinate_system': 'cartesian', 'reading_order': ['main'],
                                'alignment_keys': ['gene', 'cell_type'], 'layer_order': ['bubbles', 'labels']},
            'required_structures': ['gene by cell type matrix'], 'forbidden_substitutions': ['bar chart']}
        self.doc['design_target'] = {'reference': 'ATLAS-TJ-HCL-F2', 'reference_opened': True}
        for key in ('hierarchy', 'geometry', 'palette', 'typography', 'marks', 'annotation'):
            self.doc['design_target'][key] = {'observation': 'visible', 'implementation': 'task-specific',
                                           'difference_reason': 'adapted to an isolated rendering test'}
        self.doc['text_contract'] = {'allowed_text': ['Dose', 'Response', '1', '2', '3', '4'],
                                     'allow_headings': False, 'footer_policy': 'outside-only'}
        self.write_design()

    def write_design(self):
        self.design.write_text(yaml.safe_dump(self.doc), encoding='utf-8')

    def authorize(self):
        self.authorization_count += 1
        self.authorization = self.directory / f'authorization-{self.authorization_count}.json'
        return issue(self.preparation, self.design, self.sources, self.authorization)

    def figure(self):
        with self.renderer.bf_style(self.font):
            fig = Figure(figsize=(90 / 25.4, 75 / 25.4))
            ax = fig.add_axes((.20, .20, .70, .70))
            ax.scatter([1, 2, 3], [2, 3, 4], s=12)
            ax.set(xlim=(.5, 3.5), ylim=(1.5, 4.5), xticks=[1, 2, 3], yticks=[2, 3, 4],
                   xlabel='Dose', ylabel='Response')
        return fig

    def render(self, fig=None, **kwargs):
        return self.renderer.bf_render(fig or self.figure(), self.png, design_spec=self.design,
            authorization=self.authorization, source_files=self.sources, **kwargs)

    def test_actual_png_pdf_svg_pass_public_receipt_validation(self):
        self.authorize()
        receipt = self.render()
        self.assertEqual(validate_render_receipt(str(self.receipt), self.png, self.design, self.preparation), [])
        self.assertEqual(receipt['renderer_entrypoint'], 'biofigure-matplotlib-v1')
        self.assertEqual(receipt['runtime']['matplotlib'], matplotlib.__version__)
        self.assertEqual(receipt['runtime']['python'], sys.version.split()[0])
        self.assertEqual(set(receipt['rendered_text']), {'Dose', 'Response', '1', '2', '3', '4'})
        self.assertGreaterEqual(receipt['target_min_text_pt'], 6)
        with Image.open(self.png) as image:
            self.assertEqual(image.getpixel((0, 0))[:3], (255, 255, 255))
            self.assertLessEqual(abs(image.width - 1063), 1)
            self.assertLessEqual(abs(image.height - 886), 1)
        self.assertTrue(self.png.with_suffix('.pdf').read_bytes().startswith(b'%PDF'))
        svg = self.png.with_suffix('.svg').read_text()
        self.assertIn('<text', svg)
        self.assertIn('Response', svg)

    def test_missing_and_reused_authorization_are_rejected(self):
        with self.assertRaisesRegex((ValueError, FileNotFoundError), 'authorization'):
            self.render()
        self.authorize()
        self.render()
        valid_receipt = self.receipt.read_bytes()
        with self.assertRaisesRegex(ValueError, 'consumed'):
            self.render()
        self.assertEqual(self.receipt.read_bytes(), valid_receipt)
        self.authorization = self.directory / 'missing-authorization.json'
        with self.assertRaisesRegex(ValueError, 'authorization'):
            self.render()
        self.assertEqual(self.receipt.read_bytes(), valid_receipt)

    def test_consumed_new_authorization_then_failure_removes_old_pass_receipt(self):
        self.authorize()
        self.render()
        self.authorize()
        fig = self.figure()
        fig.axes[0].xaxis.label.set_fontsize(4)
        with self.assertRaisesRegex(ValueError, 'small'):
            self.render(fig)
        self.assertFalse(self.receipt.exists())

    def test_changed_spec_and_plot_source_reject_authorization(self):
        for change in ('spec', 'source'):
            with self.subTest(change=change):
                self.authorize()
                path = self.design if change == 'spec' else self.plot_source
                original = path.read_bytes()
                path.write_bytes(original + b'\n# changed after authorization\n')
                with self.assertRaisesRegex(ValueError, 'changed'):
                    self.render()
                self.assertFalse(self.receipt.exists())
                path.write_bytes(original)

    def test_helper_must_be_bound_to_authorization(self):
        self.sources = [self.plot_source]
        self.authorize()
        with self.assertRaisesRegex(ValueError, 'figure_style.py|helper'):
            self.render()
        self.assertFalse(self.receipt.exists())

    def test_unapproved_or_prohibited_actual_text_rejected(self):
        for label in ('Unapproved', 'AI note'):
            with self.subTest(label=label):
                self.authorize()
                fig = self.figure()
                fig.text(.5, .95, label, family='Arial', size=7)
                with self.assertRaisesRegex(ValueError, 'unapproved|prohibited'):
                    self.render(fig)
                self.assertFalse(self.receipt.exists())

    def test_nonpublication_or_fallback_font_rejected(self):
        with self.assertRaisesRegex(ValueError, 'font'):
            self.renderer.bf_font('DefinitelyMissingFont')
        self.authorize()
        fig = self.figure()
        fig.axes[0].xaxis.label.set_fontfamily('DejaVu Sans')
        with self.assertRaisesRegex(ValueError, 'font'):
            self.render(fig)
        self.assertFalse(self.receipt.exists())

    def test_text_path_effects_and_tex_cannot_bypass_the_text_audit(self):
        from matplotlib import patheffects
        from matplotlib.text import Text
        for kind in ('path-effects', 'draw-created-path-effects', 'tex'):
            with self.subTest(kind=kind):
                self.authorize()
                fig = self.figure()
                def add_unsupported_text(event=None):
                    text = fig.text(.5, .95, 'Unapproved', family='DejaVu Sans', size=4)
                    text.set_path_effects([patheffects.withStroke(linewidth=.5, foreground='white')])
                if kind == 'draw-created-path-effects':
                    callback = None
                    def add_once(event):
                        fig.canvas.mpl_disconnect(callback)
                        add_unsupported_text()
                    callback = fig.canvas.mpl_connect('draw_event', add_once)
                elif kind == 'path-effects':
                    add_unsupported_text()
                else:
                    fig.text(.5, .95, 'Unapproved', usetex=True)
                with self.assertRaisesRegex(ValueError, 'path effects|math/TeX'):
                    if kind == 'tex':
                        with patch.object(Text, '_get_layout', side_effect=AssertionError('TeX must be rejected before layout')):
                            self.render(fig)
                    else:
                        self.render(fig)
                self.assertFalse(self.receipt.exists())

    def test_small_and_outside_canvas_text_rejected(self):
        for problem in ('small', 'outside'):
            with self.subTest(problem=problem):
                self.authorize()
                fig = self.figure()
                if problem == 'small':
                    fig.axes[0].xaxis.label.set_fontsize(4)
                else:
                    fig.text(1.05, .5, 'Dose', family='Arial', size=7)
                with self.assertRaisesRegex(ValueError, 'small|outside canvas'):
                    self.render(fig)
                self.assertFalse(self.receipt.exists())

    def test_canvas_size_and_layout_boxes_rejected(self):
        self.authorize()
        fig = self.figure()
        fig.set_size_inches(4, 4)
        with self.assertRaisesRegex(ValueError, 'canvas|size'):
            self.render(fig)
        self.authorize()
        with self.assertRaisesRegex(ValueError, 'outside canvas'):
            self.render(boxes=[{'id': 'data', 'x': 89, 'y': 0, 'w': 5, 'h': 5}])
        self.assertFalse(self.receipt.exists())

    def test_draw_callback_cannot_change_text_between_preflight_and_export(self):
        self.authorize()
        fig = self.figure()
        draws = []
        def change_after_preflight(event):
            draws.append(event)
            if len(draws) == 2:
                fig.axes[0].set_xlabel('Unapproved')
        fig.canvas.mpl_connect('draw_event', change_after_preflight)
        with self.assertRaisesRegex(ValueError, 'changed|unapproved'):
            self.render(fig)
        self.assertFalse(self.receipt.exists())


if __name__ == '__main__':
    unittest.main()
