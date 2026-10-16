"""Public examples execute real preparation and authorization around the R boundary."""
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
RUNNER = ROOT / 'scripts/run_public_example.py'
CASES = ('boxplot', 'heatmap', 'dense-heatmap', 'bubble', 'volcano', 'synteny', 'phylogeny')


class PublicExampleTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='biofigure-public-example-')
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name).resolve()

    def module(self):
        self.assertTrue(RUNNER.is_file(), 'Public example runner is not implemented')
        spec = importlib.util.spec_from_file_location('biofigure_public_example_test', RUNNER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def input_csv(self, value='1.2'):
        path = self.directory / 'user.csv'
        lines = ['Sample,Group,Expression'] + [f'C{i},Control,{float(value) + i / 10}' for i in range(12)] + [f'T{i},Treatment,{float(value) + 1 + i / 10}' for i in range(12)]
        path.write_text('\n'.join(lines) + '\n')
        return path

    def r_stub(self, stage, case, output_dir, skill_root, input_path, formats):
        """Only replace the external R process; all Python gates run for real."""
        audit = Path(output_dir) / '_audit'
        config = json.loads((audit / 'render-config.json').read_text())
        if stage == 'analyze':
            stats = audit / 'statistics.csv'
            stats.write_text('comparison,estimate,p_value\nTreatment - Control,1.0,0.001\n')
            analysis = {'allowed_text': ['Control', 'Treatment', 'Expression (a.u.)', 'p = 0.001'],
                        'width_mm': 90, 'height_mm': 85, 'font_family': 'Arial',
                        'renderer': {'language': 'R', 'backend': 'ggplot2', 'packages': ['ggplot2']},
                        'statistics': {'path': str(stats), 'sha256': hashlib.sha256(stats.read_bytes()).hexdigest(),
                            'method': 'Welch two-sample t-test', 'comparison': 'Treatment - Control', 'p_semantics': 'raw'},
                        'heatmap_cells': None, 'semantic_colors': {'Control': '#38658B', 'Treatment': '#B66E83'}}
            (audit / 'analysis.json').write_text(json.dumps(analysis))
        else:
            self.assertTrue((audit / 'preparation.json').is_file())
            self.assertTrue(Path(config['design_spec_path']).is_file())
            auth = json.loads(Path(config['authorization_path']).read_text())
            self.assertEqual(auth['status'], 'AUTHORIZED')
            self.assertFalse(auth.get('consumed', False))
            sys.path.insert(0, str(Path(skill_root) / 'scripts'))
            try:
                from authorize_render import consume
                sources = [Path(p) for p in config['source_files'] if Path(p) != Path(config['design_spec_path'])]
                consume(Path(config['authorization_path']), Path(config['design_spec_path']), sources)
            finally:
                sys.path.remove(str(Path(skill_root) / 'scripts'))
            for extension in formats:
                (Path(output_dir) / f'{case}.{extension}').write_bytes(b'protocol fixture only')
            (Path(output_dir) / f'{case}.png.render.json').write_text(json.dumps({'status': 'PASS', 'protocol_fixture': True}))
        return {'returncode': 0}

    def test_external_input_requires_explicit_experimental_unit_and_independence(self):
        module = self.module()
        for declarations in ({}, {'experimental_unit': 'biological-sample'}, {'independence': 'independent'}):
            with self.subTest(declarations=declarations), patch.object(module, 'run_r') as r_process:
                with self.assertRaisesRegex(ValueError, 'experimental.unit|independence'):
                    module.run_example('boxplot', self.directory / 'out', input_path=self.input_csv(), formats=['png'], **declarations)
                r_process.assert_not_called()

    def test_external_boxplot_preserves_user_rows_and_png_only_formats(self):
        module = self.module()
        source = self.input_csv()
        original_hash = hashlib.sha256(source.read_bytes()).hexdigest()
        output = self.directory / 'out'
        with patch.object(module, 'run_r', side_effect=self.r_stub):
            result = module.run_example('boxplot', output, input_path=source, experimental_unit='biological-sample', independence='independent', formats=['png'])
        self.assertEqual(result['status'], 'RENDERED_PENDING_VISUAL_REVIEW')
        self.assertEqual(result['visual_review'], 'NOT_RUN')
        self.assertTrue((output / 'boxplot.png').is_file())
        self.assertFalse((output / 'boxplot.pdf').exists())
        self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), original_hash)
        spec = yaml.safe_load((output / '_audit/design-spec.yaml').read_text())
        self.assertEqual(spec['reference_mode'], 'original')
        self.assertEqual(spec['biology_contract']['experimental_unit'], 'biological-sample')
        self.assertEqual(spec['statistics_plan']['source']['comparison_mapping'], 'Treatment - Control')
        self.assertEqual(spec['statistics_plan']['source']['p_semantics'], 'raw')
        self.assertTrue((output / '_audit/cp2-validation.json').is_file())
        style = yaml.safe_load(Path(spec['project_style_contract']['registry_path']).read_text())
        self.assertEqual(style['project_id'], 'biofigure-portable-boxplot-standalone')
        self.assertEqual(style['experiment_scope'], 'Standalone example; cases are not one biological experiment.')
        self.assertEqual(style['palette']['semantic_colors']['Control'], '#38658B')

    def test_failed_analysis_never_issues_authorization(self):
        module = self.module()
        output = self.directory / 'failed'
        with patch.object(module, 'run_r', side_effect=RuntimeError('analysis failed')):
            with self.assertRaisesRegex(RuntimeError, 'analysis failed'):
                module.run_example('boxplot', output, formats=['png'])
        self.assertFalse(list(output.glob('_audit/authorization*.json')))
        self.assertFalse((output / '_audit/preparation.json').exists())
        self.assertTrue((output / '_audit/run.json').is_file(), 'Failed runs must retain an explicit audit status')
        self.assertEqual(json.loads((output / '_audit/run.json').read_text())['status'], 'FAILED')

    def test_each_call_gets_a_fresh_preparation_and_single_use_authorization(self):
        module = self.module()
        identifiers = []
        for index in range(2):
            output = self.directory / str(index)
            with patch.object(module, 'run_r', side_effect=self.r_stub):
                result = module.run_example('boxplot', output, formats=['png'])
            prep = json.loads((output / '_audit/preparation.json').read_text())
            config = json.loads((output / '_audit/render-config.json').read_text())
            auth = json.loads(Path(config['authorization_path']).read_text())
            self.assertTrue(auth['consumed'])
            identifiers.append((prep['preparation_id'], auth['authorization_id']))
        self.assertNotEqual(identifiers[0][0], identifiers[1][0])
        self.assertNotEqual(identifiers[0][1], identifiers[1][1])

    def test_analysis_colours_and_project_identity_are_case_specific(self):
        module = self.module()
        ids = []
        for case in ('boxplot', 'bubble'):
            audit = self.directory / case
            audit.mkdir()
            metadata = json.loads((ROOT / 'examples/portable' / case / 'metadata.json').read_text())
            analysis = {'allowed_text': ['A', 'B'], 'width_mm': 90, 'height_mm': 75,
                        'renderer': 'ggplot2', 'statistics': None, 'heatmap_cells': None,
                        'semantic_colors': {'actual_mark': '#123456'}}
            receipt = {'preparation_id': 'fixture', 'request': {},
                       'selected_reference_candidates': {'planner_selected': 'fixture'}}
            spec = module.make_spec(case, metadata, analysis, receipt, audit, ['png'])
            style = yaml.safe_load(Path(spec['project_style_contract']['registry_path']).read_text())
            self.assertEqual(style['palette']['semantic_colors'].get('actual_mark'), '#123456')
            self.assertEqual(spec['project_style_contract']['semantic_colors'], style['palette']['semantic_colors'])
            ids.append(style['project_id'])
        self.assertNotEqual(ids[0], ids[1])

    def test_all_seven_inputs_have_first_party_provenance_and_units(self):
        self.module()
        for case in CASES:
            with self.subTest(case=case):
                folder = ROOT / 'examples/portable' / case
                self.assertTrue((folder / 'data.csv').is_file())
                provenance = json.loads((folder / 'provenance.json').read_text())
                metadata = json.loads((folder / 'metadata.json').read_text())
                self.assertEqual(provenance['license'], 'MIT')
                self.assertTrue(provenance['synthetic'])
                self.assertTrue(metadata['experimental_unit'])
                self.assertTrue(metadata['limitations'])
                self.assertEqual(provenance['input_sha256'], hashlib.sha256((folder / 'data.csv').read_bytes()).hexdigest())


if __name__ == '__main__':
    unittest.main()
