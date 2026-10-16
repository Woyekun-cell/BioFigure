#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Run a self-contained synthetic example through analysis, fresh CP2 and rendering."""
from __future__ import annotations
import argparse
import csv
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import uuid
import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
CASES = {
    'boxplot': ('DIST-BOX-001', 'distribution', 'group-distribution', 'distribution', 'imaging-assay', 'comparison'),
    'heatmap': ('MAT-EXPR-001', 'matrix', 'expression-pattern', 'matrix', 'transcriptomics-metabolomics-multiomics', 'comparison'),
    'dense-heatmap': ('MAT-EXPR-DENSE-001', 'matrix', 'expression-pattern', 'matrix', 'transcriptomics-metabolomics-multiomics', 'comparison'),
    'bubble': ('SC-DOT-001', 'single-cell', 'marker-expression-across-cell-types', 'single-cell', 'single-cell-spatial', 'discovery'),
    'volcano': ('DIFF-VOLCANO-001', 'other', 'differential-biology', 'differential', 'transcriptomics-metabolomics-multiomics', 'comparison'),
    'synteny': ('GEN-SYNTENY-001', 'genome', 'synteny-and-genome-track', 'comparative-genomics', 'phylogeny-synteny-gene-family', 'structure'),
    'phylogeny': ('PHYLO-TREE-001', 'tree', 'phylogenetic-relationships', 'comparative-genomics', 'phylogeny-synteny-gene-family', 'structure'),
}


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write_json(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def run_r(stage, case, output_dir, skill_root, input_path, formats):
    command = ['Rscript', '--vanilla', str(Path(skill_root) / 'examples/portable/render.R'), stage, case,
               str(output_dir), str(skill_root), str(input_path), ','.join(formats)]
    environment = dict(os.environ, PYTHON=sys.executable)
    result = subprocess.run(command, text=True, capture_output=True, env=environment)
    if result.returncode:
        raise RuntimeError(f'R {stage} failed ({result.returncode}): {result.stderr.strip()}\n{result.stdout.strip()}')
    return {'command': command, 'returncode': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr}


def external_metadata(path, experimental_unit, independence, *, value_unit=None):
    if not experimental_unit or not independence:
        raise ValueError('External input requires explicit --experimental-unit and --independence independent; rows are not automatically independent biological samples')
    if independence != 'independent':
        raise ValueError('This two-group example requires confirmed independent samples; paired/repeated data need a different analysis')
    if not isinstance(value_unit, str) or not value_unit.strip():
        raise ValueError('External input requires explicit --value-unit; the measurement unit is separate from the experimental unit')
    value_unit = value_unit.strip()
    with path.open(newline='', encoding='utf-8-sig') as handle:
        reader = csv.DictReader(handle)
        if not {'Sample', 'Group', 'Expression'}.issubset(reader.fieldnames or []):
            raise ValueError('External boxplot requires CSV columns Sample,Group,Expression')
        rows = list(reader)
    if not rows or len({row['Sample'] for row in rows}) != len(rows) or any(not row['Sample'].strip() or not row['Group'].strip() for row in rows):
        raise ValueError('Each row needs a nonempty unique Sample and nonempty Group; technical repeats must not be counted as independent samples')
    try:
        if not all(math.isfinite(float(row['Expression'])) for row in rows):
            raise ValueError('Nonfinite Expression')
    except (ValueError, TypeError) as exc:
        raise ValueError('Expression must contain finite numbers without missing values') from exc
    groups = list(dict.fromkeys(row['Group'] for row in rows))
    counts = {group: sum(row['Group'] == group for row in rows) for group in groups}
    if len(groups) != 2 or min(counts.values()) < 2:
        raise ValueError('External boxplot requires exactly two groups with at least two confirmed independent samples each')
    return {'schema_version': 1, 'case_id': 'boxplot', 'synthetic': False, 'input_path': str(path), 'input_sha256': digest(path),
            'experimental_unit': experimental_unit, 'independence': independence, 'groups': groups, 'sample_counts': counts,
            'comparison': f'{groups[1]} - {groups[0]}', 'comparison_order': groups,
            'reference_group': groups[0], 'comparison_group': groups[1],
            'group_order_basis': 'First appearance in the supplied CSV; the second group minus the first is explicitly recorded.',
            'units': value_unit, 'value_unit': value_unit,
            'technical_replicates': 'User declaration: each Sample is an independent experimental unit.',
            'limitations': ['Independence is explicitly declared by the user, not established from row count.',
                            'The example computes a two-sided Welch comparison with no covariates; suitability still requires scientific review.']}


def validate_input_binding(input_path, expected_hash, analysis=None):
    """Prevent new raw values from being paired with statistics from an older read."""
    if digest(input_path) != expected_hash:
        raise ValueError('input changed since the declared analysis input was bound; analyze the current data again')
    if analysis is not None:
        binding = analysis.get('input_binding')
        if (not isinstance(binding, dict) or binding.get('sha256') != expected_hash
                or Path(str(binding.get('path', ''))).expanduser().resolve() != Path(input_path).resolve()):
            raise ValueError('analysis input binding is missing or differs from the current declared input')


def make_spec(case, metadata, analysis, receipt, audit, formats):
    pattern, family, task, pattern_domain, domain, role = CASES[case]
    doc = yaml.safe_load((ROOT / 'schemas/examples/marker-dotplot.yaml').read_text())
    style = yaml.safe_load((ROOT / 'examples/portable/metadata/project-style.yaml').read_text())
    style['project_id'] = f'biofigure-portable-{case}-standalone'
    style['experiment_scope'] = 'Standalone example; cases are not one biological experiment.'
    if analysis.get('semantic_colors'):
        if not isinstance(analysis['semantic_colors'], dict):
            raise ValueError('analysis.semantic_colors must be a mapping of actual rendered semantic keys')
        style['palette']['semantic_colors'].update(analysis['semantic_colors'])
    if analysis.get('group_colours'):
        colours = analysis['group_colours']
        style['palette']['semantic_colors'].update(colours if isinstance(colours, dict) else dict(zip(analysis['groups'], colours)))
    style_path = audit / 'project-style.yaml'
    style_path.write_text(yaml.safe_dump(style, sort_keys=False))
    renderer = analysis['renderer']
    if isinstance(renderer, str):
        packages = {'ComplexHeatmap': ['ComplexHeatmap', 'circlize'], 'circlize': ['circlize'], 'ggplot2': ['ggplot2']}
        renderer = {'language': 'R', 'backend': renderer, 'packages': packages[renderer] + (['ggrepel'] if case == 'volcano' else ['ape'] if case == 'phylogeny' else [])}
    stats = analysis.get('statistics')
    unit = metadata['experimental_unit']
    value_unit = metadata.get('value_unit', metadata.get('units', 'not declared'))
    if isinstance(value_unit, dict):
        value_unit = json.dumps(value_unit, sort_keys=True)
    biology = {
        'boxplot': (['sample', 'group', 'expression_measurement'], ['sample belongs to a declared group', 'one expression measurement per independent sample']),
        'heatmap': (['gene', 'sample', 'group', 'expression_measurement'], ['gene-by-sample expression matrix', 'sample has declared group membership', 'row-standardization within gene']),
        'dense-heatmap': (['gene', 'sample', 'group', 'expression_measurement'], ['gene-by-sample expression matrix', 'sample has declared group membership', 'row-standardization within gene']),
        'bubble': (['gene', 'group', 'mean_expression', 'expressing_percentage'], ['gene-by-group supplied mean expression', 'gene-by-group supplied expressing percentage']),
        'volcano': (['gene', 'effect_estimate', 'standard_error', 'adjusted_p_value'], ['gene-indexed model effect estimate and standard error', 'normal Wald p value and BH adjustment across all supplied genes']),
        'synteny': (['genome', 'chromosome', 'genomic_interval', 'paired_coordinate_block'], ['interval coordinates within a declared genome assembly', 'explicit coordinate-block pairing across two synthetic genomes']),
        'phylogeny': (['taxon', 'tree_node', 'tree_branch', 'tip_group'], ['supplied Newick parent-child topology', 'input branch length attached to each edge', 'tip markers encode the declared clade split']),
    }[case]
    doc.update(schema_version='3.4', reference_mode='original', figure_task=task,
               scientific_message={'boxplot': 'Compare the declared two independent groups using all observations and one Welch contrast.',
                   'heatmap': 'Show descriptive row-standardized expression patterns across the displayed samples.',
                   'dense-heatmap': 'Show the full dense expression matrix as a descriptive overview.',
                   'bubble': 'Show supplied mean expression and expressing percentages for each gene and group.',
                   'volcano': 'Show synthetic estimated effects with BH-adjusted model-based significance.',
                   'synteny': 'Show explicitly paired coordinate blocks between the supplied synthetic genomes.',
                   'phylogeny': 'Show the supplied synthetic topology and branch lengths.'}[case],
               data_contract_summary={'unit': value_unit, 'experimental_unit': unit, 'input_kind': 'synthetic fixture' if metadata['synthetic'] else 'user-supplied CSV',
                                      'comparison': metadata.get('comparison') or 'descriptive, no group inference'},
               biology_contract={'primary_domain': domain, 'entities': biology[0],
                    'relationships': biology[1], 'experimental_unit': unit, 'statistical_unit': unit,
                    'replicate_unit': unit, 'evidence_level': 'synthetic_demonstration' if metadata['synthetic'] else 'user_declared_design',
                    'claim_boundary': '; '.join(metadata['limitations'])},
               role_contract={'primary_role': role, 'secondary_roles': []},
               backend_lock={'backend': 'R', 'lock_id': 'portable-original-r-v1', 'locked': True, 'preview_export_qa_same_backend': True},
               deliverable_contract={'target': 'quick-png' if formats == ['png'] else 'paper-pdf', 'required_formats': formats},
               candidate_patterns=[pattern], selected_pattern=pattern, selection_reason='Pattern follows the input structure and declared scientific purpose.',
               statistics_required=bool(stats), renderer=renderer)
    doc['reference_evidence'] = {'preparation_id': receipt['preparation_id'], 'preparation_request': receipt['request'],
        'selected_method_case_id': receipt['selected_reference_candidates']['planner_selected'],
        'retrieval_query': {'domain': pattern_domain, 'task': task, 'pattern': pattern}}
    if stats:
        path = Path(stats['path'])
        if not path.is_absolute():
            path = audit / path
        if not path.is_file() or digest(path) != stats['sha256']:
            raise ValueError('Analysis statistics file is missing or its SHA-256 changed')
        doc['statistics_plan'] = {'mode': 'existing', 'status': 'ready', 'recompute': False,
            'source': {'path': str(path.resolve()), 'sha256': stats['sha256'], 'p_semantics': stats['p_semantics'],
                       'comparison_mapping': stats['comparison'], 'provenance': 'R analysis in the same invocation, before CP2; ' + stats['method']}}
    else:
        doc['statistics_plan'] = {'mode': 'descriptive', 'status': 'ready', 'reason': metadata.get('statistics', 'Descriptive mapping of supplied values; no inferential statistics.'), 'significance_annotations': False}
    values = list(dict.fromkeys(str(x) for x in analysis['allowed_text']))
    width, height = analysis['width_mm'], analysis['height_mm']
    doc['project_style_contract'] = {'registry_path': str(style_path), 'registry_sha256': digest(style_path), 'project_id': style['project_id'],
        'palette_id': style['palette']['palette_id'], 'semantic_colors': style['palette']['semantic_colors'], 'reuse_policy': 'exact_semantic_mapping', 'exception_basis': ''}
    doc['font_contract'].update(family=analysis.get('font_family', 'Arial'), size_roles_pt=style['typography']['size_roles_pt'], minimum_final_text_pt=6)
    doc['output_size'] = {'width_mm': width, 'height_mm': height, 'formats': formats, 'size_class': 'single-column', 'size_basis': 'final_physical_output',
        'size_rationale': {'panel_count': 1, 'density': 'high' if case == 'dense-heatmap' else 'low' if case in ('boxplot', 'phylogeny') else 'medium', 'longest_label_chars': max(map(len, values)),
            'recommended_class': 'double-column' if case == 'dense-heatmap' else 'single-column' if case in ('boxplot', 'phylogeny') and max(map(len, values)) <= 24 else 'one-and-half-column', 'selection_reason': 'Final size uses the measured analysis layout and retains the full displayed data.', 'override_basis': 'This public demonstration explicitly targets a 90 mm single-column canvas; actual final-size layout and cell metrics require review.'}}
    doc['visual_hierarchy'] = {'primary': 'data geometry', 'secondary': 'scientific labels', 'tertiary': 'guides and legends'}
    mappings = {'boxplot': ('Group', 'Expression'), 'heatmap': ('sample', 'gene'), 'dense-heatmap': ('sample', 'gene'), 'bubble': ('Group', 'Gene'),
                'volcano': ('log2FC', '-log10 FDR'), 'synteny': ('physical coordinates', 'paired blocks'), 'phylogeny': ('branch length', 'taxon')}
    x, y = mappings[case]
    doc['encoding'] = {'x': x, 'y': y, 'color': 'declared semantic dictionary'}
    doc['annotation'] = {'labels': 'Only analysis-derived scientific labels and ticks; no canvas footer.'}
    doc['legend'] = {'place': 'outside_plot', 'shared': False}
    doc['palette_semantics'] = {'categorical': 'exact group or chromosome mapping', 'continuous': 'declared centered or sequential scale'}
    doc['reference_analysis'] = {'figure_family': family, 'semantic_purpose': doc['scientific_message'],
        'panels': [{'id': 'main', 'role': 'primary data', 'position': 'single panel'}],
        'elements': [{'id': 'data', 'role': 'scientific data', 'geometry': case, 'position': 'reserved data body', 'data_mapping': f'{y} by {x}', 'required': True},
                     {'id': 'labels', 'role': 'identity and scale', 'geometry': 'text', 'position': 'reserved margins', 'data_mapping': 'exact input identifiers and axis ticks', 'required': True}],
        'relationships': [{'from': 'data', 'to': 'labels', 'type': 'aligns-with', 'shared_key': x}],
        'spatial_topology': {'coordinate_system': 'circular' if case == 'synteny' else 'cartesian', 'reading_order': ['main'], 'alignment_keys': [x, y], 'layer_order': ['data', 'labels']},
        'required_structures': ['All displayed input entities and exact scale mappings'], 'forbidden_substitutions': ['Unreported input filtering or invented biological claims']}
    doc['design_target'] = {key: {'observation': doc['scientific_message'], 'implementation': f'{renderer["backend"]} at {width} by {height} mm with measured text and reserved margins.',
                                  'difference_reason': 'Original design is bound to the current input and analysis.'} for key in ('hierarchy', 'geometry', 'palette', 'typography', 'marks', 'annotation')}
    doc['text_contract'] = {'allowed_text': values, 'allow_headings': False}
    contracts = {'boxplot': [{'layer': 1, 'role': 'distribution-fill', 'fill_alpha': .32, 'edge_alpha': 1},
                            {'layer': 2, 'role': 'replicate-point', 'fill_alpha': .70, 'edge_alpha': 1},
                            {'layer': 3, 'role': 'summary-line', 'alpha': 1}, {'layer': 4, 'role': 'summary-line', 'alpha': 1}],
        'bubble': [{'layer': 1, 'role': 'continuous-bubble', 'fill_alpha': 1, 'edge_alpha': 1}],
        'volcano': [{'layer': 1, 'role': 'dense-point', 'alpha': .22}, {'layer': 2, 'role': 'dense-point', 'alpha': .45}],
        'phylogeny': [{'layer': 1, 'role': 'summary-line', 'alpha': 1}, {'layer': 2, 'role': 'replicate-point', 'fill_alpha': 1, 'edge_alpha': 1,
                       'override_reason': 'Categorical tree tip markers encode membership, not overlapping replicate density.'}]}
    if case in contracts:
        doc['mark_style_contract'] = {'policy_id': 'layer-role-opacity-v1', 'layers': contracts[case]}
    cells = analysis.get('heatmap_cells')
    if cells:
        doc['heatmap_cell_contract'] = {'policy_id': 'heatmap-cells-v1', 'shape': cells['mode'], 'rows': int(cells['rows']), 'columns': int(cells['columns']),
            'measurement_basis': 'final_body_viewports_mm', 'max_relative_error': .01}
        if cells['mode'] == 'dense-overview':
            doc['heatmap_cell_contract']['density_reason'] = 'The full displayed matrix has thousands of rows; aggregate pattern, not individual cells, is the reading target.'
    return doc


def _run_example(case, output_dir, *, input_path=None, experimental_unit=None, independence=None, value_unit=None, formats=None):
    if case not in CASES:
        raise ValueError('Unknown public example: ' + str(case))
    formats = formats or ['pdf', 'png']
    formats = ['png'] if set(formats) == {'png'} else ['pdf', 'png'] if set(formats) == {'pdf', 'png'} else None
    if formats is None:
        raise ValueError('Supported formats are png or pdf png; PNG is required for native render evidence')
    external = input_path is not None
    input_path = Path(input_path).expanduser().resolve() if external else ROOT / 'examples/portable' / case / 'data.csv'
    if not input_path.is_file():
        raise ValueError('Input file missing: ' + str(input_path))
    if external and case != 'boxplot':
        raise ValueError('External --input is currently supported for boxplot only; other cases use their declared synthetic fixtures')
    metadata = external_metadata(input_path, experimental_unit, independence, value_unit=value_unit) if external else json.loads((input_path.parent / 'metadata.json').read_text())
    input_hash = metadata.get('input_sha256') or digest(input_path)
    validate_input_binding(input_path, input_hash)
    output = Path(output_dir).expanduser().resolve()
    output.mkdir(parents=True, exist_ok=True)
    audit = output / '_audit'
    audit.mkdir(exist_ok=True)
    invocation = uuid.uuid4().hex
    metadata_path = audit / 'input-metadata.json' if external else input_path.parent / 'metadata.json'
    if external:
        write_json(metadata_path, metadata)
    config = {'case': case, 'input_path': str(input_path), 'input_binding': {'path': str(input_path), 'sha256': input_hash},
              'metadata_path': str(metadata_path), 'experimental_unit': metadata['experimental_unit'],
              'independence': metadata['independence'], 'formats': formats, 'design_spec_path': str(audit / 'design-spec.yaml'),
              'authorization_path': str(audit / f'authorization-{invocation}.json'), 'source_files': []}
    config_path = audit / 'render-config.json'
    write_json(config_path, config)
    analysis_run = run_r('analyze', case, output, ROOT, input_path, formats)
    analysis_path = audit / 'analysis.json'
    analysis = json.loads(analysis_path.read_text())
    validate_input_binding(input_path, input_hash, analysis)
    pattern, family, task, _, domain, role = CASES[case]
    from prepare_figure import prepare
    request = {'reference_mode': 'original', 'operation': 'draw', 'figure_task': task, 'figure_family': family, 'pattern_id': pattern,
               'data_shape': f'{case}: {metadata.get("generation", "user-supplied declared independent sample table")}',
               'primary_domain': domain, 'primary_role': role, 'backend': 'R', 'deliverable': 'quick-png' if formats == ['png'] else 'paper-pdf',
               'statistics_required': bool(analysis.get('statistics'))}
    receipt = prepare(request)
    if receipt['status'] != 'PREFLIGHT_COMPLETE':
        raise ValueError('Preparation blocked: ' + json.dumps(receipt.get('missing_material', [])))
    prep_path = audit / 'preparation.json'
    write_json(prep_path, receipt)
    write_json(audit / 'figure-request.json', request)
    spec = make_spec(case, metadata, analysis, receipt, audit, formats)
    design_path = Path(config['design_spec_path'])
    design_path.write_text(yaml.safe_dump(spec, sort_keys=False))
    from validate_design_spec import validate, load, SCHEMA
    from validate_checkpoints import validate_preparation_receipt
    errors = validate(spec, load(SCHEMA), spec_path=design_path)
    errors.extend(validate_preparation_receipt(str(prep_path), spec))
    write_json(audit / 'cp2-validation.json', {'status': 'PASS' if not errors else 'FAIL', 'errors': errors,
               'preparation_id': receipt['preparation_id'], 'design_spec_sha256': digest(design_path), 'scope': 'Pre-render design and current-input binding only; no visual acceptance.'})
    if errors:
        raise ValueError('CP2 validation failed: ' + '; '.join(errors))
    sources = [ROOT / 'examples/portable/render.R', ROOT / 'scripts/figure_style.R', Path(__file__).resolve(), input_path,
               metadata_path, analysis_path]
    if analysis.get('statistics'):
        stat_path = Path(analysis['statistics']['path'])
        sources.append(stat_path if stat_path.is_absolute() else audit / stat_path)
    heatmap_values = audit / 'heatmap-values.csv'
    if heatmap_values.is_file():
        sources.append(heatmap_values)
    sources.extend([config_path, design_path])
    config['source_files'] = [str(path.resolve()) for path in sources]
    write_json(config_path, config)
    validate_input_binding(input_path, input_hash, analysis)
    from authorize_render import issue
    authorization = issue(prep_path, design_path, [path for path in sources if path != design_path], Path(config['authorization_path']))
    render_run = run_r('render', case, output, ROOT, input_path, formats)
    artifacts = [output / f'{case}.{extension}' for extension in formats]
    render_receipt = output / f'{case}.png.render.json'
    if not all(path.is_file() for path in artifacts) or not render_receipt.is_file():
        raise ValueError('Renderer did not produce every requested artifact and native receipt')
    result = {'schema_version': 1, 'case': case, 'status': 'RENDERED_PENDING_VISUAL_REVIEW', 'visual_review': 'NOT_RUN',
              'reference_mode': 'original', 'input': {'path': str(input_path), 'sha256': digest(input_path), 'synthetic': bool(metadata['synthetic'])},
              'formats': formats, 'artifacts': [{'path': str(path), 'sha256': digest(path)} for path in artifacts],
              'analysis': str(analysis_path), 'preparation': str(prep_path), 'design_spec': str(design_path),
              'authorization': config['authorization_path'], 'authorization_id': authorization['authorization_id'],
              'render_receipt': str(render_receipt), 'cp2_validation': str(audit / 'cp2-validation.json'),
              'executions': [analysis_run, render_run], 'boundary': 'Final-size visual review and scientific suitability review remain required; CP4 is not inferred.'}
    write_json(audit / 'run.json', result)
    return result


def run_example(case, output_dir, *, input_path=None, experimental_unit=None, independence=None, value_unit=None, formats=None):
    try:
        return _run_example(case, output_dir, input_path=input_path, experimental_unit=experimental_unit,
                            independence=independence, value_unit=value_unit, formats=formats)
    except Exception as exc:
        audit = Path(output_dir).expanduser().resolve() / '_audit'
        if audit.is_dir():
            write_json(audit / 'run.json', {'schema_version': 1, 'case': case, 'status': 'FAILED',
                       'visual_review': 'NOT_RUN', 'error': str(exc),
                       'boundary': 'Partial artifacts do not establish successful rendering or visual acceptance.'})
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('case', choices=CASES)
    parser.add_argument('--output-dir', required=True, type=Path)
    parser.add_argument('--input', dest='input_path', type=Path)
    parser.add_argument('--experimental-unit')
    parser.add_argument('--independence', choices=['independent'])
    parser.add_argument('--value-unit', help='Required for external CSV input; preserve the actual measurement unit, e.g. a.u. or mg/L')
    parser.add_argument('--formats', nargs='+', choices=['png', 'pdf'], default=['pdf', 'png'])
    args = parser.parse_args()
    try:
        result = run_example(**vars(args))
    except Exception as exc:
        print(json.dumps({'status': 'FAILED', 'error': str(exc)}), file=sys.stderr)
        return 1
    print(json.dumps({'status': result['status'], 'case': result['case'], 'artifacts': result['artifacts'], 'audit': str(Path(args.output_dir).resolve() / '_audit/run.json')}))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
