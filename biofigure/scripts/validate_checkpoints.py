#!/usr/bin/env python3
"""Validate ordered, evidence-bound BioFigure checkpoints."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys
import math
import subprocess

import yaml


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from reference_modes import (design_reference_mode, receipt_reference_mode,
                             mode_binding_errors, code_gate, ORIGINAL_MATERIAL)
from reference_paths import resolve_reference_path, resolve_project_root
_text_spec = importlib.util.spec_from_file_location("biofigure_cp_text_policy", ROOT / "scripts/figure_text_policy.py")
_text_module = importlib.util.module_from_spec(_text_spec)
assert _text_spec and _text_spec.loader
_text_spec.loader.exec_module(_text_module)
_cell_spec = importlib.util.spec_from_file_location('biofigure_cp_cell_geometry', ROOT / 'scripts/heatmap_geometry.py')
_cell_module = importlib.util.module_from_spec(_cell_spec)
_cell_spec.loader.exec_module(_cell_module)
DEFINITION = ROOT / "checkpoints/checkpoints.yaml"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
DETECTED_KEYS = {"overlap", "clipping", "missing_glyph", "font_fallback", "legend_overlap",
                 "non_white_background", "unrequested_text", "small_text", "text_position",
                 "label_overlap", "panel_misalignment", "figure_text_proportion", "footer_text"}
REPRO_CORPUS = ROOT / "atlas/reproduction-derived-corpus.json"


def load(path: Path):
    with path.open(encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_inspection_evidence(document: dict, heatmap_design: dict | None = None) -> list[str]:
    """Validate artifact-bound CP3/CP4 inspection evidence fields."""
    errors = []
    required = ('artifact_sha256', 'first_render_sha256', 'target_size', 'reviewer_type',
                'reviewer_id', 'judgment', 'artifact_path', 'first_render_path',
                'defect_coordinates', 'viewer_method', 'revision_count', 'final_size_checks')
    for key in required:
        if key not in document:
            errors.append(f'{key} required')
    for key in ('artifact_sha256', 'first_render_sha256'):
        if key in document and not SHA256.fullmatch(str(document[key])):
            errors.append(f'{key} must be a SHA-256 hash')
    size = document.get('target_size')
    if 'target_size' in document and (not isinstance(size, dict) or not all(isinstance(size.get(k), (int, float)) and size[k] > 0 for k in ('width_mm', 'height_mm'))):
        errors.append('target_size must include positive width_mm and height_mm')
    if document.get('reviewer_type') not in {'human', 'model', 'automated'}:
        errors.append('reviewer_type must be human, model, or automated')
    if not isinstance(document.get('reviewer_id'), str) or not document['reviewer_id'].strip():
        errors.append('reviewer_id must identify the reviewer without exposing a model label')
    if document.get('judgment') not in {'PASS', 'REVISE', 'FAIL'}:
        errors.append('judgment must be PASS, REVISE, or FAIL')
    if document.get('judgment') == 'PASS' and document.get('reviewer_type') == 'automated':
        errors.append('visual PASS requires a human or model reviewer, not automated review alone')
    for key in ('artifact_path', 'first_render_path'):
        if not isinstance(document.get(key), str) or not document[key].strip():
            errors.append(f'{key} must be recorded')
    if not isinstance(document.get('defect_coordinates'), list):
        errors.append('defect_coordinates must be a list')
    # bool subclasses int in Python, but is not a valid revision count.
    if type(document.get('revision_count')) is not int or document.get('revision_count', -1) < 0:
        errors.append('revision_count must be a non-negative integer')
    elif document.get('revision_count', 0) > 0 and (
            document.get('artifact_path') == document.get('first_render_path')
            or document.get('artifact_sha256') == document.get('first_render_sha256')):
        errors.append('revised final and first render must have different paths and hashes')
    coords = document.get('defect_coordinates')
    if isinstance(coords, list):
        for index, coord in enumerate(coords):
            if (not isinstance(coord, dict) or not isinstance(coord.get('issue'), str) or not coord['issue'].strip()
                    or not isinstance(coord.get('x'), (int, float)) or isinstance(coord.get('x'), bool)
                    or not isinstance(coord.get('y'), (int, float)) or isinstance(coord.get('y'), bool)
                    or coord.get('unit') != 'normalized'):
                errors.append(f'defect_coordinates[{index}] requires issue, finite normalized x/y in 0..1')
                continue
            if not math.isfinite(coord['x']) or not math.isfinite(coord['y']):
                errors.append(f'defect_coordinates[{index}] coordinates must be finite')
            elif not (0 <= coord['x'] <= 1 and 0 <= coord['y'] <= 1):
                errors.append(f'defect_coordinates[{index}] normalized coordinates must be within 0..1')
    if document.get('viewer_method') not in {'direct-open', 'contact-sheet-open'}:
        errors.append('viewer_method must record an opened viewer')
    final_checks = document.get('final_size_checks')
    required_checks = ('typography_size', 'typography_position', 'label_overlap',
                       'legend_overlap', 'clipping', 'panel_alignment',
                       'figure_text_proportion', 'semantic_color', 'footer_absent')
    if not isinstance(final_checks, dict):
        errors.append('final_size_checks must be a mapping')
    else:
        if final_checks.get('target_size_opened') is not True:
            errors.append('final_size_checks.target_size_opened must be true')
        checks = final_checks.get('checks')
        if not isinstance(checks, dict):
            errors.append('final_size_checks.checks must be a mapping')
        else:
            for key in required_checks:
                record = checks.get(key)
                if (not isinstance(record, dict) or record.get('status') not in {'PASS', 'FAIL'}
                        or not isinstance(record.get('evidence'), str) or not record['evidence'].strip()):
                    errors.append(f'final_size_checks.{key} requires PASS/FAIL status and evidence')
                elif document.get('judgment') == 'PASS' and record['status'] != 'PASS':
                    errors.append(f'final_size_checks.{key} must PASS before visual PASS')
    if document.get('judgment') == 'PASS' and isinstance(final_checks, dict):
        color = (final_checks.get('checks') or {}).get('semantic_color', {})
        if not isinstance(color, dict) or color.get('colored_data_marks') is not True:
            errors.append('semantic_color.colored_data_marks must be true: monochrome or decorative-only color cannot receive visual PASS')
    if _cell_module.requires_cell_geometry(heatmap_design or {}):
        errors.extend(_cell_module.validate_cell_metrics(document.get('heatmap_cells'), heatmap_design))
        cell_check = ((final_checks or {}).get('checks') or {}).get('cell_geometry', {})
        if (not isinstance(cell_check, dict) or cell_check.get('status') != 'PASS'
                or not str(cell_check.get('evidence', '')).strip()):
            errors.append('final_size_checks.cell_geometry requires actual final-size cell observation before PASS')
    return errors


def validate_reproduction_receipt(receipt_path: str, corpus: Path = REPRO_CORPUS, root: Path | None = None,
                                  document_path: Path | None = None,
                                  reference_mode: str | None = None) -> list[str]:
    errors = []
    try:
        resolved_receipt = resolve_reference_path(receipt_path, document_path=document_path, project_root=root)
        receipt = json.loads(resolved_receipt.read_text())
        if receipt.get('schema_version') != 1 or not str(receipt.get('query','')).strip():
            errors.append('reproduction receipt version/query invalid')
        if receipt.get('kind') == 'primary-source-lock':
            locked_mode = receipt.get('reference_mode')
            if locked_mode is not None and locked_mode not in {'reference-guided', 'reproduction'}:
                errors.append('primary-source lock reference_mode must be reference-guided or reproduction')
            if reference_mode is not None and locked_mode is not None and reference_mode != locked_mode:
                errors.append('reference_mode differs between source lock and Design Spec')
            if reference_mode == 'original':
                errors.append('reference_mode original cannot bind a source lock')
            # Legacy unversioned locks retain their original three-role contract.
            guided = locked_mode == 'reference-guided' and reference_mode in {None, 'reference-guided'}
            source_root = resolve_project_root(receipt.get('project_root'), document_path=resolved_receipt)
            if root is not None and Path(root).expanduser().resolve() != source_root:
                errors.append('primary-source lock project root invalid')
            paper = receipt.get('primary_source', {})
            kind = paper.get('kind', 'paper')
            if kind not in {'paper', 'package-docs', 'tutorial', 'user-reference'}:
                errors.append('primary-source lock primary_source.kind is unsupported')
            metadata_keys = ('title', 'url') if guided else ('title', 'url', 'figure', 'panel')
            if not guided and kind == 'paper':
                metadata_keys += ('doi',)
            if kind in {'package-docs', 'tutorial'}:
                metadata_keys += ('version',)
            if guided and kind == 'user-reference':
                metadata_keys = ('title', 'attachment_name')
            for key in metadata_keys:
                if not isinstance(paper.get(key),str) or not paper[key].strip():
                    errors.append(f'primary-source lock missing primary_source.{key}')
            files = receipt.get('source_files')
            roles = set()
            if not isinstance(files,list) or len(files) < (1 if guided else 3):
                errors.append('primary-source lock requires at least one hashed source file' if guided else 'primary-source lock requires at least three hashed source files')
                files = []
            for item in files:
                if not isinstance(item,dict):
                    errors.append('primary-source lock source file entry invalid')
                    continue
                role, rel, claimed = item.get('role'), item.get('path'), item.get('sha256')
                if not isinstance(role,str) or not role.strip() or role in roles:
                    errors.append('primary-source lock source roles missing or duplicated')
                    continue
                roles.add(role)
                path = (source_root / str(rel or '')).resolve()
                if path != source_root and source_root not in path.parents:
                    errors.append(f'primary-source lock path escapes project root: {rel}')
                elif not path.is_file() or not SHA256.fullmatch(str(claimed or '')) or digest(path)!=claimed:
                    errors.append(f'primary-source lock file missing or hash changed: {rel}')
            adopted = receipt.get('adopted_roles')
            if guided:
                if (not isinstance(adopted, list) or not adopted or not all(isinstance(role, str) for role in adopted)
                        or len(set(adopted)) != len(adopted) or 'figure_asset' not in adopted or not set(adopted).issubset(roles)):
                    errors.append('reference-guided source lock must hash every declared adopted_role including figure_asset')
            elif not {'figure_asset','author_code','source_data'}.issubset(roles):
                errors.append('primary-source lock must bind figure_asset, author_code and source_data')
            mappings = receipt.get('source_mapping')
            mapping_required = not guided or (isinstance(adopted, list) and 'source_data' in adopted)
            if mapping_required and (not isinstance(mappings,list) or not mappings):
                errors.append('primary-source lock source_mapping required')
            elif mappings:
                for mapping in mappings:
                    if not isinstance(mapping,dict) or not mapping.get('panel') or mapping.get('author_code') not in roles or mapping.get('source_data') not in roles:
                        errors.append('primary-source lock mapping must bind a panel to author code and source data')
                        break
            if receipt.get('inspection',{}).get('original_figure_opened') is not True:
                errors.append('primary-source lock requires opened original figure evidence')
            contract = receipt.get('generation_contract',{})
            if contract.get('author_material_access')!='authorized-inspection-no-copy' or contract.get('implementation')!='new-script-from-user-data-and-derived-patterns' or contract.get('blind_generation') is not False:
                errors.append('primary-source lock source-exposure contract invalid')
            return errors
        bound = receipt.get('corpus', {})
        if Path(str(bound.get('path',''))).resolve() != corpus.resolve() or not corpus.is_file() or bound.get('sha256') != digest(corpus):
            errors.append('reproduction receipt corpus missing or changed')
        results = receipt.get('results')
        if not isinstance(results,list) or not 1 <= len(results) <= 5 or any(not isinstance(x,dict) or not x.get('case_id') for x in results):
            errors.append('reproduction receipt requires 1-5 cases')
        contract = receipt.get('generation_contract', {})
        if contract.get('author_material_access') not in {'forbidden','authorized-inspection-no-copy'} or contract.get('implementation') != 'new-script-from-user-data-and-derived-patterns':
            errors.append('reproduction access/implementation contract invalid')
        if contract.get('author_material_access') == 'authorized-inspection-no-copy' and contract.get('blind_generation') is True:
            errors.append('source-exposed reproduction cannot claim blind generation')
        if 'source_code' in json.dumps(receipt,ensure_ascii=False):
            errors.append('reproduction receipt exposes source code')
    except Exception as exc:
        errors.append(f'reproduction receipt unreadable: {exc}')
    return errors


def validate_preparation_receipt(receipt_path: str, design_spec: dict) -> list[str]:
    """Bind CP2 to the deterministic retrieval receipt used before design/code."""
    errors = []
    try:
        receipt = json.loads(Path(receipt_path).expanduser().read_text(encoding='utf-8'))
        reference_mode = receipt_reference_mode(receipt)
        errors.extend(mode_binding_errors(receipt, design_spec))
        if reference_mode != 'original':
            from reuse_templates import validate_binding
            errors.extend(validate_binding(receipt, design_spec))
            from retrieve_learned_methods import validate_binding as validate_learning
            errors.extend(validate_learning(receipt, design_spec))
        claimed_id = receipt.get('preparation_id')
        unsigned = dict(receipt)
        unsigned.pop('preparation_id', None)
        actual_id = hashlib.sha256(json.dumps(unsigned, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
        if not re.fullmatch(r'[0-9a-f]{32}', str(receipt.get('invocation_id', ''))):
            errors.append('preparation receipt missing unique invocation ID')
        if receipt.get('schema_version') != 1 or not isinstance(claimed_id, str) or claimed_id != actual_id:
            errors.append('preparation receipt version or integrity hash invalid')
        if receipt.get('status') != 'PREFLIGHT_COMPLETE':
            errors.append('preparation receipt is not PREFLIGHT_COMPLETE')
        if receipt.get('code_gate') != code_gate(reference_mode):
            errors.append('preparation receipt code gate invalid')
        material = receipt.get('source_hashes', {})
        required_material = {
            'SKILL.md', 'manifest.yaml', 'static/core/execution-contract.yaml', 'schemas/figure-request.schema.yaml',
            'schemas/figure-design-spec.schema.yaml', 'checkpoints/checkpoints.yaml',
            'scripts/prepare_figure.py', 'scripts/route_figure.py', 'scripts/plan_figure_method.py',
            'scripts/retrieve_reproduction.py', 'scripts/retrieve_scidraw.py', 'scripts/retrieve_capabilities.py',
            'scripts/retrieve_references.py', 'scripts/benchmark_core.py', 'scripts/validate_design_spec.py',
            'scripts/validate_checkpoints.py', 'atlas/reproduction-derived-corpus.json',
            'atlas/reproduction-methods.json', 'atlas/scidraw-derived-corpus.json',
            'atlas/scidraw-visual-grammar.yaml', 'atlas/scidraw-source-compared-methods.json',
            'atlas/scidraw-review-evidence.json', 'atlas/scidraw-batch2-methods.json',
            'atlas/scidraw-batch2-review-evidence.json', 'atlas/scidraw-learning-ten-20260925.json',
            'atlas/scidraw-learning-ten-20260925-02.json', 'atlas/top-journal-corpus.yaml',
            'atlas/unified-capability-graph.json', 'atlas/family-execution-contracts.yaml',
            'atlas/index.yaml', 'patterns/index.yaml', 'renderer-registry.yaml', 'benchmark/registry.json',
            'atlas/reusable-template-index.json', 'scripts/reuse_templates.py',
            'scripts/run_template_replay.py', 'references/stable-template-reuse.md',
            'atlas/learned-method-index.json', 'scripts/retrieve_learned_methods.py',
            'scripts/build_learned_method_index.py', 'scripts/learning_materials.py',
            'references/all-learning-transfer.md', 'references/all-learning-audit-defects.md',
            'atlas/learned-method-validations.json', 'scripts/validate_learned_reuse.py',
            'atlas/source-syntax-audit.json',
        }
        if reference_mode == 'original':
            required_material = ORIGINAL_MATERIAL
        elif 'reference_mode' in receipt:
            required_material.update({'scripts/reference_modes.py', 'scripts/reference_paths.py'})
        if not isinstance(material, dict) or receipt.get('missing_material') or not required_material.issubset(material):
            errors.append('preparation receipt has missing or malformed bound material')
        else:
            for name, expected_hash in material.items():
                path = (ROOT / str(name)).resolve()
                if path != ROOT.resolve() and ROOT.resolve() not in path.parents:
                    errors.append(f'preparation receipt source path escapes Skill root: {name}')
                elif not path.is_file() or not SHA256.fullmatch(str(expected_hash)) or digest(path) != expected_hash:
                    errors.append(f'preparation receipt source changed or missing: {name}')
            if not set(receipt.get('route', {}).get('modules', [])) <= set(material):
                errors.append('preparation receipt does not hash every routed module')
        expected_sources = set() if reference_mode == 'original' else {'reproduction', 'top_journal', 'scidraw'}
        loaded_sources = set(receipt.get('route', {}).get('reference_evidence_layers', {}))
        if not expected_sources.issubset(loaded_sources):
            errors.append('preparation receipt omits mandatory reference sources')
        request = receipt.get('request', {})
        spec_reference = design_spec.get('reference_evidence', {})
        if spec_reference.get('preparation_id') != claimed_id:
            errors.append('Design Spec preparation_id does not match CP2 preparation receipt')
        if spec_reference.get('preparation_request') != request:
            errors.append('Design Spec preparation_request differs from complete CP2 request binding')
        if spec_reference.get('selected_method_case_id') != receipt.get('selected_reference_candidates', {}).get('planner_selected'):
            errors.append('Design Spec selected_method_case_id differs from deterministic planner candidate')
        if reference_mode == 'original':
            selected_pattern = design_spec.get('selected_pattern')
            if receipt.get('selected_reference_candidates', {}).get('planner_selected') != 'PATTERN-' + str(selected_pattern):
                errors.append('original Design Spec Pattern differs from the preflight-selected Pattern')
            if request.get('pattern_id') and request['pattern_id'] != selected_pattern:
                errors.append('original Design Spec selected_pattern differs from requested pattern_id')
        if re.sub(r'\s+', ' ', str(request.get('figure_task', '')).strip()).casefold() != re.sub(r'\s+', ' ', str(design_spec.get('figure_task', '')).strip()).casefold():
            errors.append('preparation receipt figure_task differs from Design Spec')
        biology = design_spec.get('biology_contract', {})
        backend = design_spec.get('backend_lock', {})
        if request.get('primary_domain') != biology.get('primary_domain'):
            errors.append('preparation receipt primary_domain differs from Design Spec')
        if request.get('backend') != backend.get('backend'):
            errors.append('preparation receipt backend differs from Design Spec')
        if request.get('primary_role') != design_spec.get('role_contract', {}).get('primary_role'):
            errors.append('preparation receipt primary_role differs from Design Spec')
        if request.get('figure_family') and request.get('figure_family') != design_spec.get('reference_analysis', {}).get('figure_family'):
            errors.append('preparation receipt figure_family differs from Design Spec reference analysis')
        targets = {'quick-png': ['png'], 'paper-pdf': ['pdf', 'png'], 'paper-composite': ['pdf', 'svg', 'png'],
                   'editable-vector': ['svg', 'pdf', 'png'], 'tiff-submission': ['tiff', 'png']}
        requested_target = request.get('deliverable')
        contract = design_spec.get('deliverable_contract', {})
        expected_formats = targets.get(requested_target)
        spec_formats = contract.get('required_formats') if isinstance(contract, dict) else None
        output_formats = design_spec.get('output_size', {}).get('formats', [])
        if (not expected_formats or contract.get('target') != requested_target
                or spec_formats != expected_formats or set(output_formats) != set(expected_formats)):
            errors.append('preparation receipt deliverable does not match Design Spec output contract/formats')
        if not isinstance(receipt.get('method_plan', {}).get('selected_case'), dict):
            errors.append('preparation receipt has no selected method candidate')
        elif receipt.get('selected_reference_candidates', {}).get('planner_selected') != receipt['method_plan']['selected_case'].get('case_id'):
            errors.append('preparation receipt planner candidate binding is inconsistent')
    except Exception as exc:
        errors.append(f'preparation receipt unreadable: {exc}')
    return errors


def validate_render_receipt(receipt_path: str, artifact: Path, design_spec: Path | None = None,
                            preparation_receipt: Path | None = None) -> list[str]:
    """Check workflow bindings; this detects mistakes, not deliberate forgery."""
    errors = []
    try:
        receipt = json.loads(Path(receipt_path).read_text())
        if receipt.get('schema_version') != 1 or receipt.get('status') != 'PASS':
            errors.append('render receipt version/status invalid')
        if receipt.get('backend') not in {'R', 'Python'}:
            errors.append('render receipt backend invalid')
        if receipt.get('backend') == 'Python':
            errors.append('Python CP3 PASS blocked: official authorized Python renderer is not implemented')
        authorization = receipt.get('authorization_consumption', {})
        authorization = authorization if isinstance(authorization, dict) else {}
        authorized_design_path = None
        marker = authorization.get('marker', {})
        marker_path = Path(str(marker.get('path', ''))).expanduser()
        if (authorization.get('consumed') is not True or not SHA256.fullmatch(str(authorization.get('authorization_id', '')))
                or not marker_path.is_file() or digest(marker_path) != marker.get('sha256')
                or marker_path.read_text(encoding='utf-8').strip() != authorization.get('authorization_id')):
            errors.append('render authorization consumption evidence missing or invalid')
        marker_record = authorization.get('marker', {}) if isinstance(authorization, dict) else {}
        authorization_record = authorization.get('authorization_file', {}) if isinstance(authorization, dict) else {}
        if authorization_record.get('path') and marker_record.get('path'):
            expected_marker = str(Path(str(authorization_record['path'])).expanduser().resolve()) + '.consumed'
            if str(Path(str(marker_record['path'])).expanduser().resolve()) != expected_marker:
                errors.append('render authorization consumption marker path does not match authorization file')
        path_base = receipt.get('path_base')
        repository_root = ROOT.parent.resolve()
        def bound_path(item):
            if not isinstance(item, dict):
                return None
            p = Path(str(item.get('path', '')))
            if not p.is_absolute():
                if path_base != 'repository-root':
                    return None
                p = (repository_root / p).resolve()
                if p != repository_root and repository_root not in p.parents:
                    return None
            else:
                p = p.resolve()
            return p if p.is_file() and digest(p) == item.get('sha256') else None
        def bound(item):
            return bound_path(item) is not None
        authorization_file = authorization.get('authorization_file', {})
        if not bound(authorization_file):
            errors.append('render authorization file missing or changed')
        else:
            try:
                auth_path = bound_path(authorization_file)
                auth_doc = json.loads(auth_path.read_text(encoding='utf-8'))
                auth_id = auth_doc.pop('authorization_id', None)
                was_consumed = auth_doc.pop('consumed', False)
                calculated_id = hashlib.sha256(json.dumps(auth_doc, sort_keys=True).encode()).hexdigest()
                if (auth_doc.get('schema_version') != 1 or auth_doc.get('status') != 'AUTHORIZED'
                        or auth_doc.get('single_use') is not True
                        or auth_id != calculated_id or auth_id != authorization.get('authorization_id')):
                    errors.append('render authorization id does not match bound authorization file')
                if was_consumed is not True:
                    errors.append('render authorization file is not sealed as consumed')
                bound_inputs = auth_doc.get('bound', {})
                consumed_prep = authorization.get('preparation_receipt', {})
                auth_prep = bound_inputs.get('receipt', {})
                if (not isinstance(consumed_prep, dict) or not isinstance(auth_prep, dict)
                        or Path(str(consumed_prep.get('path', ''))).resolve() != Path(str(auth_prep.get('path', ''))).resolve()
                        or consumed_prep.get('sha256') != auth_prep.get('sha256') or not bound(consumed_prep)):
                    errors.append('render authorization preparation receipt binding invalid')
                if preparation_receipt is not None and (
                        Path(str(consumed_prep.get('path', ''))).resolve() != preparation_receipt.resolve()):
                    errors.append('render authorization preparation receipt differs from CP2 ledger')
                auth_design = bound_inputs.get('design_spec', {})
                authorized_design_path = bound_path(auth_design)
                if authorized_design_path is not None and bound(consumed_prep):
                    current_preparation = json.loads(bound_path(consumed_prep).read_text(encoding='utf-8'))
                    current_design = load(authorized_design_path)
                    errors.extend(mode_binding_errors(current_preparation, current_design))
                    if auth_doc.get('reference_mode', 'reference-guided') != receipt_reference_mode(current_preparation):
                        errors.append('reference_mode differs between render authorization and bound inputs')
                if design_spec is not None and Path(str(auth_design.get('path', ''))).resolve() != design_spec.resolve():
                    errors.append('render authorization Design Spec differs from CP2 ledger')
                render_sources = receipt.get('sources', [])
                if not any(bound_path(x) == Path(str(auth_design.get('path', ''))).resolve()
                           and x.get('sha256') == auth_design.get('sha256') for x in render_sources if isinstance(x, dict)):
                    errors.append('render authorization Design Spec binding differs from render receipt')
                expected_sources = bound_inputs.get('sources', [])
                actual_sources = [x for x in render_sources if isinstance(x, dict)
                                  and Path(str(x.get('path', ''))).resolve() != Path(str(auth_design.get('path', ''))).resolve()]
                expected_set = {(str(Path(x.get('path', '')).resolve()), x.get('sha256')) for x in expected_sources if isinstance(x, dict)}
                actual_set = {(str(Path(x.get('path', '')).resolve()), x.get('sha256')) for x in actual_sources}
                if expected_set != actual_set:
                    errors.append('render authorization source bindings differ from render receipt')
            except Exception as exc:
                errors.append(f'render authorization file invalid: {exc}')
        image = receipt.get('artifact', {})
        if not bound(image) or bound_path(image) != artifact.resolve():
            errors.append('render receipt artifact mismatch')
        sources = receipt.get('sources')
        if not isinstance(sources, list) or not sources or not all(bound(x) for x in sources):
            errors.append('render receipt source missing or changed')
        if not isinstance(sources, list) or not any(isinstance(x, dict) and Path(str(x.get('path', ''))).suffix.lower() in {'.r', '.py'} for x in sources):
            errors.append('render receipt must bind renderer source code')
        if receipt.get('renderer') == 'ggplot2':
            names = [Path(str(x.get('path', ''))).name for x in sources if isinstance(x, dict)] if isinstance(sources, list) else []
            if 'figure_style.R' not in names or not any(n.lower().endswith('.r') and n != 'figure_style.R' for n in names):
                errors.append('ggplot2 receipt must bind plot source and figure_style.R')
            current_style = ROOT / 'scripts/figure_style.R'
            style_sources = [bound_path(x) for x in sources if isinstance(x, dict)
                             and Path(str(x.get('path', ''))).name == 'figure_style.R'] if isinstance(sources, list) else []
            if not any(path is not None and digest(path) == digest(current_style) for path in style_sources):
                errors.append('ggplot2 receipt must bind the current canonical figure_style.R or an identical copy')
        if design_spec is not None and (not isinstance(sources, list) or not any(
                bound_path(x) == design_spec.resolve() for x in sources if isinstance(x, dict))):
            errors.append('render receipt must bind current design spec')
        if design_spec is not None:
            declared_size = load(design_spec).get('output_size', {})
            receipt_size = receipt.get('target_size', {})
            for key in ('width_mm', 'height_mm', 'size_class', 'size_basis'):
                if key in declared_size and receipt_size.get(key) != declared_size.get(key):
                    errors.append(f'render receipt target_size.{key} differs from Design Spec')
        font = receipt.get('font', {})
        if not bound(font) or font.get('family') not in {'Arial', 'Helvetica'}:
            errors.append('render receipt font invalid')
        checks = receipt.get('checks', {})
        if not isinstance(checks, dict) or any(checks.get(k) is not True for k in ('font', 'text_allowlist', 'layout', 'target_size')):
            errors.append('render receipt checks incomplete')
        strict_text = True  # All renderers must submit actual canvas text.
        rendered_text = receipt.get('rendered_text')
        if strict_text:
            if not isinstance(checks, dict) or checks.get('scientific_text_only') is not True:
                errors.append('render receipt scientific_text_only check missing or false')
            if receipt.get('text_policy_id') != _text_module.TEXT_POLICY_ID:
                errors.append('render receipt current text_policy_id missing or invalid')
            if (receipt.get('footer_policy_id') != _text_module.FOOTER_POLICY_ID
                    or not isinstance(checks, dict) or checks.get('footer_free') is not True):
                errors.append('render receipt current no-canvas-footer policy and footer_free check required')
        if strict_text or 'rendered_text' in receipt:
            if not isinstance(rendered_text, list) or not all(isinstance(label, str) for label in rendered_text):
                errors.append('render receipt rendered_text must be an array of actual rendered strings')
            else:
                errors.extend(_text_module.validate_figure_text(rendered_text, field='render receipt rendered_text'))
                text_design_path = design_spec if design_spec is not None else authorized_design_path
                if text_design_path is None:
                    errors.append('rendered text evidence requires the current bound Design Spec')
                else:
                    text_design = load(text_design_path)
                    contract = text_design.get('text_contract', {}) if isinstance(text_design, dict) else {}
                    errors.extend(_text_module.validate_footer_contract(contract))
                    allowed = contract.get('allowed_text') if isinstance(contract, dict) else None
                    if not isinstance(allowed, list) or not all(isinstance(label, str) for label in allowed):
                        errors.append('rendered text evidence requires Design Spec text_contract.allowed_text strings')
                    else:
                        errors.extend(_text_module.validate_figure_text(allowed))
                        # Empty grob labels are invisible; every visible string must be declared.
                        unexpected = sorted(set(label for label in rendered_text if label.strip()) - set(allowed))
                        if unexpected:
                            errors.append('render receipt actual rendered_text contains unapproved labels: ' + ' | '.join(unexpected))
        cell_design_path = design_spec if design_spec is not None else authorized_design_path
        cell_design = load(cell_design_path) if cell_design_path is not None else {}
        if _cell_module.requires_cell_geometry(cell_design) or receipt.get('heatmap_cells'):
            errors.extend(_cell_module.validate_cell_metrics(receipt.get('heatmap_cells'), cell_design))
            if receipt.get('heatmap_cell_policy_id') != _cell_module.POLICY_ID or checks.get('cell_geometry') is not True:
                errors.append('heatmap_cells requires current policy and executed cell_geometry check')
        size = receipt.get('target_min_text_pt')
        if type(size) not in (int, float) or not math.isfinite(size) or size < 5:
            errors.append('render receipt target text below 5 pt or invalid')
        elif size < 6 and not str(receipt.get('text_size_authorization') or '').strip():
            errors.append('render receipt text below 6 pt requires documented basis')
        target = receipt.get('target_size')
        classes = {'single-column': (89, 90, 170),
                   'one-and-half-column': (120, 136, 170),
                   'double-column': (180, 183, 170),
                   'custom': (50, 210, 247)}
        if not isinstance(target, dict) or target.get('size_class') not in classes:
            errors.append('render receipt target_size publication class missing or invalid')
        else:
            width, height = target.get('width_mm'), target.get('height_mm')
            lo, hi, max_height = classes[target['size_class']]
            if (type(width) not in (int, float) or not math.isfinite(width)
                    or not lo <= width <= hi):
                errors.append(f"render receipt {target['size_class']} width must be {lo}..{hi} mm")
            if (type(height) not in (int, float) or not math.isfinite(height)
                    or height <= 0 or height > max_height):
                errors.append(f"render receipt {target['size_class']} height must be positive and at most {max_height} mm")
            if target.get('size_basis') != 'final_physical_output':
                errors.append('render receipt target_size basis must be final_physical_output')
            if target['size_class'] == 'custom' and not str(target.get('override_basis') or '').strip():
                errors.append('render receipt custom target size requires documented basis')
    except Exception as exc:
        errors.append(f'render receipt unreadable: {exc}')
    return errors


def validate(ledger: dict, definition: dict) -> list[str]:
    errors: list[str] = []
    if not isinstance(ledger, dict):
        return ["ledger must be a mapping"]
    for key in ("schema_version", "artifact_id", "mode", "checkpoints"):
        if key not in ledger:
            errors.append(f"ledger missing: {key}")
    gates = definition.get("checkpoints", []) if isinstance(definition, dict) else []
    expected = [gate.get("id") for gate in gates]
    entries = ledger.get("checkpoints")
    if not isinstance(entries, list):
        return errors + ["checkpoints must be a list"]
    received = [entry.get("id") if isinstance(entry, dict) else None for entry in entries]
    if received != expected:
        errors.append(f"checkpoint order must be {expected}; got {received}")
        return errors

    allowed = set(definition.get("status_enum", []))
    blocker: tuple[str, str] | None = None
    cp3_digest: str | None = None
    for gate, entry in zip(gates, entries):
        checkpoint_id = gate["id"]
        status = entry.get("status")
        evidence = entry.get("evidence")
        failures = entry.get("failures")
        next_action = entry.get("next_action")
        if status not in allowed:
            errors.append(f"{checkpoint_id} invalid status: {status}")
            continue
        if not isinstance(evidence, dict):
            errors.append(f"{checkpoint_id} evidence must be a mapping")
            evidence = {}
        if not isinstance(failures, list):
            errors.append(f"{checkpoint_id} failures must be a list")
            failures = []
        if not isinstance(next_action, str) or not next_action.strip():
            errors.append(f"{checkpoint_id} next_action must be non-empty")
        if blocker and status == "PASS":
            errors.append(f"{checkpoint_id} cannot PASS after {blocker[0]}={blocker[1]}")
        if status in {"REVISE", "STOP"}:
            if not failures:
                errors.append(f"{checkpoint_id} {status} requires failures")
            if not blocker:
                blocker = (checkpoint_id, status)
        elif status == "NOT_RUN" and not blocker:
            errors.append(f"{checkpoint_id} cannot be NOT_RUN without an earlier blocker")
            blocker = (checkpoint_id, status)
        elif status == "PASS":
            missing = [key for key in gate.get("required_evidence", []) if key not in evidence]
            if missing:
                errors.append(f"{checkpoint_id} evidence missing: {', '.join(missing)}")

        if status != "PASS":
            continue
        if checkpoint_id == "CP0":
            for key in ("scientific_question", "figure_task", "claim_boundary"):
                if not isinstance(evidence.get(key), str) or not evidence[key].strip():
                    errors.append(f"CP0 {key} must be non-empty")
            if evidence.get("unresolved_critical_fields") != []:
                errors.append("CP0 cannot PASS with unresolved_critical_fields")
        if checkpoint_id == "CP1":
            if evidence.get("sample_mapping_checked") is not True:
                errors.append("CP1 sample_mapping_checked must be true")
            for key in ("replicate_unit", "scale_and_transform", "statistics_contract", "coordinate_contract"):
                if not isinstance(evidence.get(key), str) or not evidence[key].strip():
                    errors.append(f"CP1 {key} must be non-empty")
        if checkpoint_id == "CP2":
            spec_doc = {}
            spec_path = Path(str(evidence.get('design_spec', ''))).expanduser()
            if not spec_path.is_file():
                errors.append('CP2 design_spec file required')
            else:
                result = subprocess.run([sys.executable, str(ROOT/'scripts/validate_design_spec.py'), str(spec_path)], capture_output=True, text=True)
                if result.returncode:
                    errors.append('CP2 actual design validation failed: ' + result.stdout.strip())
            if not isinstance(evidence.get("selected_pattern"), str) or not evidence["selected_pattern"].strip():
                errors.append("CP2 selected_pattern must be non-empty")
            if spec_path.is_file():
                try:
                    spec_doc = load(spec_path)
                    prep_path = str(evidence.get('preparation_receipt', ''))
                    if not prep_path:
                        errors.append('CP2 preparation_receipt is required')
                    else:
                        errors.extend(validate_preparation_receipt(prep_path, spec_doc))
                except Exception as exc:
                    errors.append(f'CP2 preparation receipt binding failed: {exc}')
            try:
                cp2_mode = design_reference_mode(spec_doc) if spec_path.is_file() else 'reference-guided'
                if cp2_mode != 'original':
                    receipt_path = evidence.get('reference_method_receipt', evidence.get('reproduction_retrieval_receipt',''))
                    errors.extend(validate_reproduction_receipt(str(receipt_path), document_path=spec_path, reference_mode=cp2_mode))
            except ValueError as exc:
                errors.append(str(exc))
            for key, wanted in (("design_spec_validation", "PASS"), ("renderer_available", True), ("layout_slots_reserved", True)):
                if evidence.get(key) != wanted:
                    errors.append(f"CP2 {key} must be {wanted}")
        if checkpoint_id == "CP3":
            path = Path(str(evidence.get("artifact", ""))).expanduser()
            cp2 = entries[2].get('evidence', {})
            errors.extend(validate_render_receipt(str(evidence.get('render_receipt', '')), path,
                          Path(str(cp2.get('design_spec', ''))),Path(str(cp2.get('preparation_receipt', '')))))
            claimed = str(evidence.get("artifact_sha256", ""))
            if not path.is_file():
                errors.append("CP3 artifact missing")
            elif not SHA256.fullmatch(claimed) or digest(path) != claimed:
                errors.append("CP3 artifact_sha256 mismatch")
            else:
                cp3_digest = claimed
            first = evidence.get('first_render', {})
            first_path = Path(str(first.get('path', ''))).expanduser() if isinstance(first, dict) else Path('')
            first_hash = str(evidence.get('first_render_sha256', ''))
            if not first_path.is_file() or not SHA256.fullmatch(first_hash) or digest(first_path) != first_hash or first.get('sha256') != first_hash:
                errors.append('CP3 first render missing or hash mismatch')
            size = evidence.get('target_size')
            if not isinstance(size, dict) or any(not isinstance(size.get(k), (int, float)) or size[k] <= 0 for k in ('width_mm', 'height_mm')):
                errors.append('CP3 target_size must record positive width_mm and height_mm')
            if evidence.get("artifact_opened") is not True or evidence.get("viewer_method") not in {"direct-open", "contact-sheet-open"}:
                errors.append("CP3 requires an actual viewer-open record")
            if evidence.get("target_size_checked") is not True:
                errors.append("CP3 target_size_checked must be true")
            detected = evidence.get("detected")
            if not isinstance(detected, dict) or not DETECTED_KEYS <= set(detected):
                errors.append("CP3 detected fields incomplete")
            elif any(detected[key] is not False for key in DETECTED_KEYS):
                errors.append("CP3 cannot PASS with a detected hard failure")
        if checkpoint_id == "CP4":
            spec_doc = {}
            cp2 = entries[2].get('evidence', {})
            cp3 = entries[3].get('evidence', {})
            command = [sys.executable, str(ROOT/'scripts/run_critics.py'), '--artifact', str(cp3.get('artifact', '')),
                       '--pattern', str(cp2.get('selected_pattern', '')), '--mode', 'publication',
                       '--inspection-evidence', str(evidence.get('inspection_evidence', '')),
                       '--design-spec', str(cp2.get('design_spec', '')), '--json']
            inspection_path = Path(str(evidence.get('inspection_evidence', ''))).expanduser()
            if not inspection_path.is_file():
                errors.append('CP4 inspection evidence file required')
            else:
                try:
                    inspection_doc = load(inspection_path)
                    current_spec = load(Path(str(cp2.get('design_spec', ''))))
                    errors.extend([f'inspection evidence: {item}' for item in validate_inspection_evidence(inspection_doc, current_spec)])
                    if inspection_doc.get('artifact_sha256') != cp3.get('artifact_sha256'):
                        errors.append('inspection evidence artifact hash differs from CP3')
                    if inspection_doc.get('first_render_sha256') != cp3.get('first_render_sha256'):
                        errors.append('inspection evidence first render hash differs from CP3')
                    if inspection_doc.get('target_size') != cp3.get('target_size'):
                        errors.append('inspection evidence target size differs from CP3')
                    if inspection_doc.get('reviewer_type') != evidence.get('reviewer_type'):
                        errors.append('CP4 reviewer_type differs from inspection evidence')
                    if inspection_doc.get('reviewer_type') not in {'human', 'model'}:
                        errors.append('CP4 visual PASS requires a human or model reviewer; automated review alone is insufficient')
                    if inspection_doc.get('reviewer_id') != evidence.get('reviewer_id'):
                        errors.append('CP4 reviewer_id differs from inspection evidence')
                    if inspection_doc.get('judgment') != 'PASS':
                        errors.append('CP4 visual PASS requires explicit reviewer judgment PASS')
                    cp3_artifact = Path(str(cp3.get('artifact', ''))).resolve()
                    cp3_first = cp3.get('first_render', {})
                    if inspection_doc.get('artifact_path') != str(cp3_artifact):
                        errors.append('CP4 inspection artifact_path differs from CP3 final artifact')
                    if inspection_doc.get('first_render_path') != str(Path(str(cp3_first.get('path', ''))).resolve()):
                        errors.append('CP4 inspection first_render_path differs from CP3 first render')
                except Exception as exc:
                    errors.append(f'inspection evidence unreadable: {exc}')
            spec_path = Path(str(cp2.get('design_spec', '')))
            try:
                spec_doc = load(spec_path)
                current_mode = design_reference_mode(spec_doc)
                if ledger.get('reference_mode') is not None and ledger['reference_mode'] != current_mode:
                    errors.append('reference_mode differs between ledger and Design Spec')
                biology = spec_doc.get('biology_contract', {})
                for key in ('primary_domain', 'secondary_domain'):
                    if biology.get(key): command.extend(['--domain', str(biology[key])])
                result = subprocess.run(command, capture_output=True, text=True)
                if result.returncode:
                    errors.append('CP4 actual critic validation failed: ' + result.stdout.strip() + result.stderr.strip())
            except Exception as exc:
                errors.append(f'CP4 critic execution failed: {exc}')
            if evidence.get("critic_status") != "PASS" or evidence.get("qa_status") != "PASS":
                errors.append("CP4 critic_status and qa_status must be PASS")
            if not isinstance(evidence.get("simulation_disclosed"), bool):
                errors.append("CP4 simulation_disclosed must be boolean")
            deliverables = evidence.get("deliverables")
            if not isinstance(deliverables, list) or not deliverables:
                errors.append("CP4 deliverables must be non-empty")
            else:
                observed = set()
                observed_formats = set()
                for item in deliverables:
                    if not isinstance(item, dict):
                        errors.append("CP4 deliverable must be a mapping")
                        continue
                    path = Path(str(item.get("path", ""))).expanduser()
                    if path.suffix.lower() == '.png' and path.resolve() != Path(str(cp3.get('artifact', ''))).resolve():
                        errors.append('CP4 each PNG requires its own inspected ledger')
                    claimed = str(item.get("sha256", ""))
                    if not path.is_file() or not SHA256.fullmatch(claimed) or digest(path) != claimed:
                        errors.append(f"CP4 deliverable hash mismatch: {path}")
                    else:
                        observed.add(claimed)
                        observed_formats.add(path.suffix.lower().lstrip('.'))
                if cp3_digest and cp3_digest not in observed:
                    errors.append("CP4 deliverables do not include the inspected artifact")
                required_formats = set(spec_doc.get('deliverable_contract', {}).get('required_formats', []))
                missing_formats = required_formats - observed_formats
                if missing_formats:
                    errors.append('CP4 actual deliverables missing required format(s): ' + ', '.join(sorted(missing_formats)))
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("ledger", type=Path)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    try:
        ledger = load(args.ledger)
        errors = validate(ledger, load(DEFINITION))
        if not errors and not all(entry.get('status') == 'PASS' for entry in ledger['checkpoints']):
            errors.append('ledger is structurally valid but release is blocked; all checkpoints must PASS')
    except Exception as exc:
        errors = [str(exc)]
    payload = {"status": "PASS" if not errors else "FAIL", "errors": errors}
    print(json.dumps(payload, ensure_ascii=False, indent=2) if args.json else ("CHECKPOINTS_OK" if not errors else "CHECKPOINTS_FAIL\n" + "\n".join(errors)))
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
