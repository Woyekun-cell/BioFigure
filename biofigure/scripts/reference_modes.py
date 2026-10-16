"""One evidence-mode contract shared by preparation, design, authorization and QA.

Legacy Specs/receipts without a versioned mode keep the former source-guided
contract. New ordinary requests default to original design; explicit source use
and reproduction cannot be relabelled original to escape their evidence gates.
"""
from __future__ import annotations

MODES = ('original', 'reference-guided', 'reproduction')
DIMENSIONS = ('hierarchy', 'geometry', 'palette', 'typography', 'marks', 'annotation')
SOURCE_REQUEST_FIELDS = ('primary_source', 'learned_method_id', 'reusable_case_id')
ORIGINAL_MATERIAL = frozenset({
    'SKILL.md', 'manifest.yaml', 'static/core/execution-contract.yaml',
    'schemas/figure-request.schema.yaml', 'schemas/figure-design-spec.schema.yaml',
    'checkpoints/checkpoints.yaml', 'patterns/index.yaml', 'renderer-registry.yaml',
    'scripts/reference_modes.py', 'scripts/reference_paths.py', 'scripts/prepare_figure.py', 'scripts/route_figure.py',
    'scripts/validate_design_spec.py', 'scripts/validate_checkpoints.py',
    'scripts/authorize_render.py', 'scripts/run_critics.py',
    'scripts/figure_text_policy.py', 'scripts/heatmap_geometry.py',
    'scripts/validate_statistics_plan.py', 'scripts/plan_pangenome_figure.py', 'critics/design-quality.md',
})


def resolve_request_mode(request: dict) -> str:
    explicit = request.get('reference_mode')
    if explicit is not None and explicit not in MODES:
        raise ValueError('reference_mode must be original, reference-guided, or reproduction')
    source_fields = [key for key in SOURCE_REQUEST_FIELDS if request.get(key)]
    reproduction = request.get('operation') == 'reproduce'
    mode = explicit or ('reproduction' if reproduction else 'reference-guided' if source_fields else 'original')
    if reproduction and mode != 'reproduction':
        raise ValueError('reference_mode conflicts with operation reproduce; reproduction evidence is required')
    if mode == 'original' and source_fields:
        raise ValueError('reference_mode original cannot declare source/reuse fields: ' + ', '.join(source_fields))
    return mode


def design_reference_mode(doc: dict) -> str:
    reference = doc.get('reference_evidence', {})
    reference = reference if isinstance(reference, dict) else {}
    request = reference.get('preparation_request', {})
    request = request if isinstance(request, dict) else {}
    mode = doc.get('reference_mode', request.get('reference_mode', 'reference-guided'))
    resolved = resolve_request_mode(dict(request, reference_mode=mode))
    if resolved == 'original':
        source_fields = [key for key in ('primary_source_lock', 'primary_source', 'learned_source_reference',
                                         'template_reuse', 'selected_atlas_ids', 'supplemental_case_ids') if reference.get(key)]
        learning = reference.get('learned_method_reuse', {})
        if isinstance(learning, dict) and learning.get('adopted'):
            source_fields.append('learned_method_reuse.adopted')
        if str(doc.get('selected_pattern', '')).startswith('LEARNED-'):
            source_fields.append('learned native pattern')
        target = doc.get('design_target', {})
        if isinstance(target, dict) and (target.get('reference') or target.get('reference_opened')):
            source_fields.append('design_target.reference')
        if source_fields:
            raise ValueError('reference_mode original cannot adopt source evidence: ' + ', '.join(source_fields))
    return resolved


def receipt_reference_mode(receipt: dict) -> str:
    if 'reference_mode' not in receipt:
        return 'reference-guided'  # explicit compatibility rule for historical receipts
    request = receipt.get('request', {})
    mode = resolve_request_mode(request)
    if receipt['reference_mode'] != mode or request.get('reference_mode') != mode:
        raise ValueError('reference_mode differs between preparation receipt and request')
    return mode


def code_gate(mode: str) -> str:
    return 'BLOCKED_UNTIL_DESIGN_ANALYSIS_AND_CP2' if mode == 'original' else 'BLOCKED_UNTIL_REFERENCE_ANALYSIS_AND_CP2'


def mode_binding_errors(receipt: dict, doc: dict) -> list[str]:
    try:
        if receipt_reference_mode(receipt) != design_reference_mode(doc):
            return ['reference_mode differs between preparation receipt and Design Spec']
    except ValueError as exc:
        return [str(exc)]
    return []
