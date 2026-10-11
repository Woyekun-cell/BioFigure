#!/usr/bin/env python3
"""Check declared statistical intent and design; never infer them from p-values."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import yaml

METHODS = {
    'one_sample_t', 'welch_t', 'student_t', 'paired_t', 'wilcoxon_rank_sum',
    'wilcoxon_signed_rank', 'anova_oneway', 'welch_anova', 'kruskal_wallis',
    'factorial_lm', 'linear_model', 'rm_anova', 'friedman', 'mixed_model',
    'glm', 'glmm', 'survival_model', 'multivariate_model', 'custom',
}
GOALS = {'baseline', 'all_pairs', 'control', 'planned_contrasts', 'main_effects',
         'interaction', 'simple_effects', 'trend', 'association', 'equivalence'}

def valid_enum(value, choices):
    return isinstance(value,str) and value in choices

def nonempty(value):
    return isinstance(value, str) and bool(value.strip())

def validate_plan(plan, base_path=None):
    if not isinstance(plan, dict):
        return ['statistics_plan must be a mapping']
    errors = []
    mode = plan.get('mode') if isinstance(plan.get('mode'),str) else None
    if mode not in {'compute', 'existing', 'descriptive', 'not_applicable'}:
        return ['statistics_plan.mode is invalid']
    if plan.get('status') != 'ready':
        errors.append('statistics_plan is not ready; resolve design or analysis intent before inference')
    if mode in {'descriptive', 'not_applicable'}:
        if not nonempty(plan.get('reason')):
            errors.append('statistics_plan.reason is required')
        if plan.get('significance_annotations') is not False:
            errors.append('descriptive/not_applicable plans must disable significance_annotations')
        return errors
    if mode == 'existing':
        source = plan.get('source', {})
        if not isinstance(source, dict):
            return errors + ['statistics_plan.source must be a mapping']
        for key in ('path', 'sha256', 'p_semantics', 'comparison_mapping', 'provenance'):
            if not nonempty(source.get(key)):
                errors.append(f'statistics_plan.source.{key} is required')
        if not valid_enum(source.get('p_semantics'), {'raw', 'adjusted', 'mixed_declared'}):
            errors.append('statistics_plan.source.p_semantics is invalid')
        if nonempty(source.get('path')):
            path = Path(source['path']).expanduser()
            if not path.is_absolute() and base_path:
                path = Path(base_path) / path
            if not path.is_file():
                errors.append('statistics_plan.source file missing')
            elif source.get('sha256') != hashlib.sha256(path.read_bytes()).hexdigest():
                errors.append('statistics_plan.source hash differs')
        if plan.get('recompute') is not False:
            errors.append('existing statistics must declare recompute: false')
        return errors
    design = plan.get('design', {})
    if not isinstance(design, dict):
        return errors + ['statistics_plan.design must be a mapping']
    for key in ('question', 'estimand', 'intent_evidence', 'formula', 'rationale'):
        if not nonempty(plan.get(key)):
            errors.append(f'statistics_plan.{key} is required')
    if not valid_enum(plan.get('intent_source'), {'user', 'prespecified', 'explicit_design', 'default_disclosed'}):
        errors.append('statistics_plan.intent_source is required')
    if not valid_enum(plan.get('goal'), GOALS):
        errors.append('statistics_plan.goal is unresolved or invalid; ask analysis intent')
    if not valid_enum(plan.get('alternative'), {'two.sided', 'greater', 'less', 'not_applicable'}):
        errors.append('statistics_plan.alternative must be declared')
    if valid_enum(plan.get('alternative'), {'greater', 'less'}) and not nonempty(plan.get('one_sided_basis')):
        errors.append('one-sided inference needs a prespecified scientific basis')
    for key in ('response', 'independent_unit', 'evidence', 'technical_replicates', 'missing_policy', 'outlier_policy', 'scale'):
        if not nonempty(design.get(key)):
            errors.append(f'statistics_plan.design.{key} is required')
    if not valid_enum(design.get('outcome_type'), {'continuous', 'binary', 'count', 'proportion', 'ordinal', 'survival', 'multivariate'}):
        errors.append('statistics_plan.design.outcome_type is unresolved')
    dependence = design.get('dependence') if isinstance(design.get('dependence'),str) else None
    if dependence not in {'independent', 'paired', 'repeated', 'nested', 'clustered'}:
        errors.append('statistics_plan.design.dependence is unresolved; ask the experimental-unit relationship')
    factors = design.get('factors')
    if not isinstance(factors, list) or any(not nonempty(x) for x in factors) or (all(isinstance(x,str) for x in factors) and len(set(factors)) != len(factors)):
        errors.append('statistics_plan.design.factors must be unique column names')
        factors = []
    levels = design.get('factor_levels', {})
    if not isinstance(levels,dict):
        errors.append('statistics_plan.design.factor_levels must be a mapping')
        levels = {}
    for factor in factors:
        values = levels.get(factor)
        if not isinstance(values,list) or len(values)<2 or any(not nonempty(x) for x in values) or (all(isinstance(x,str) for x in values) and len(set(values))!=len(values)):
            errors.append(f'statistics_plan.design.factor_levels.{factor} must declare observed unique levels')
    covariates = design.get('covariates')
    if not isinstance(covariates, list) or any(not nonempty(x) for x in covariates):
        errors.append('statistics_plan.design.covariates must be a list')
    if dependence in {'paired', 'repeated', 'nested', 'clustered'} and not nonempty(design.get('dependence_id')):
        errors.append('dependent observations require a real dependence_id')
    method = plan.get('method') if isinstance(plan.get('method'),str) else None
    if method not in METHODS:
        errors.append('statistics_plan.method is unresolved or invalid')
    independent_only = {'one_sample_t', 'welch_t', 'student_t', 'wilcoxon_rank_sum', 'anova_oneway', 'welch_anova', 'kruskal_wallis', 'factorial_lm', 'linear_model', 'glm'}
    if dependence != 'independent' and method in independent_only:
        errors.append('selected method ignores the declared dependence structure')
    if method in {'paired_t', 'wilcoxon_signed_rank'} and dependence != 'paired':
        errors.append('paired method requires a confirmed paired design')
    if method in {'rm_anova', 'friedman'} and dependence not in {'paired', 'repeated'}:
        errors.append('repeated-measures method requires a within-unit design')
    if method == 'friedman' and design.get('complete_blocks') is not True:
        errors.append('Friedman requires confirmed complete blocks')
    one_factor = {'welch_t', 'student_t', 'paired_t', 'wilcoxon_rank_sum', 'wilcoxon_signed_rank', 'anova_oneway', 'welch_anova', 'kruskal_wallis', 'friedman'}
    if method in one_factor and len(factors) != 1:
        errors.append('one-factor method cannot answer a multi-factor design without an explicit valid subset')
    if method in {'welch_t','student_t','paired_t','wilcoxon_rank_sum','wilcoxon_signed_rank'} and len(factors)==1 and isinstance(levels.get(factors[0]),list) and len(levels[factors[0]])!=2:
        errors.append('two-group method requires exactly two declared observed levels')
    if method == 'factorial_lm' and len(factors) < 2:
        errors.append('factorial model requires at least two design factors')
    if method in {'one_sample_t', 'welch_t', 'student_t', 'paired_t', 'anova_oneway', 'welch_anova', 'factorial_lm', 'linear_model', 'rm_anova'} and design.get('outcome_type') != 'continuous':
        errors.append('continuous-response method mismatches the declared outcome')
    if plan.get('goal') == 'interaction' and not plan.get('interaction_terms'):
        errors.append('interaction intent requires declared interaction terms/contrasts')
    if plan.get('goal') == 'interaction' and method == 'factorial_lm' and nonempty(plan.get('formula')) and not any(x in plan['formula'] for x in ('*',':')):
        errors.append('factorial interaction intent requires an interaction in the model formula')
    if plan.get('goal') == 'control' and not nonempty(plan.get('control_level')):
        errors.append('control comparisons require control_level')
    if plan.get('goal') == 'equivalence':
        if not nonempty(plan.get('equivalence_margin_basis')) or method != 'custom':
            errors.append('equivalence requires a justified margin and dedicated custom method; ordinary difference tests are insufficient')
    if method in {'student_t', 'anova_oneway'} and not nonempty(plan.get('equal_variance_basis')):
        errors.append('pooled-variance method requires equal_variance_basis')
    if valid_enum(plan.get('goal'), {'all_pairs', 'control', 'planned_contrasts', 'simple_effects'}):
        contrasts = plan.get('contrasts')
        if not isinstance(contrasts, list) or not contrasts or any(not nonempty(x) for x in contrasts):
            errors.append('planned comparisons require explicit contrasts and direction')
    diagnostics = plan.get('diagnostics')
    if not isinstance(diagnostics, list) or not diagnostics or any(not nonempty(x) for x in diagnostics):
        errors.append('statistics_plan.diagnostics must declare actual model checks to perform')
    multiplicity = plan.get('multiplicity', {})
    if not isinstance(multiplicity, dict):
        return errors + ['statistics_plan.multiplicity must be a mapping']
    adjust = multiplicity.get('method') if isinstance(multiplicity.get('method'),str) else None
    if adjust not in {'none', 'holm', 'BH', 'BY', 'bonferroni', 'tukey', 'dunnett', 'games_howell', 'custom'}:
        errors.append('multiplicity method is unresolved')
    n_tests = multiplicity.get('n_tests')
    if type(n_tests) is not int or n_tests < 1:
        errors.append('multiplicity.n_tests must be a positive integer')
    elif n_tests > 1 and adjust == 'none' and not nonempty(multiplicity.get('no_adjustment_basis')):
        errors.append('multiple tests without adjustment need an explicit scientific strategy')
    if method == 'welch_anova' and adjust == 'tukey':
        errors.append('ordinary Tukey HSD is not the Welch unequal-variance post-hoc procedure')
    if not nonempty(multiplicity.get('family')):
        errors.append('multiplicity.family must define the comparisons/endpoints covered')
    result = plan.get('results', {})
    if not isinstance(result, dict):
        return errors + ['statistics_plan.results must be a mapping']
    for key in ('table', 'effect', 'interval_scope'):
        if not nonempty(result.get(key)):
            errors.append(f'statistics_plan.results.{key} is required')
    if result.get('annotation_source') != 'same_results_table':
        errors.append('plot annotations must read the same statistical results table')
    return errors


def validate_document(doc, base_path=None):
    if not isinstance(doc, dict):
        return ['statistics document must be a mapping']
    evidence = doc.get('reference_evidence', {})
    bound_request = evidence.get('preparation_request', {}) if isinstance(evidence,dict) else {}
    if isinstance(bound_request,dict) and bound_request.get('statistics_required') is True and doc.get('statistics_required') is not True:
        return ['preparation request requires statistical inference; statistics_required cannot be omitted or disabled']
    if 'statistics_required' in doc and type(doc['statistics_required']) is not bool:
        return ['statistics_required must be boolean']
    if 'statistics_plan' in doc:
        errors = validate_plan(doc['statistics_plan'], base_path)
        if doc.get('statistics_required') is True and isinstance(doc['statistics_plan'],dict) and doc['statistics_plan'].get('mode') not in {'compute','existing'}:
            errors.append('statistics_required cannot be satisfied by a descriptive/not_applicable plan')
        return errors
    if doc.get('statistics_required') is True:
        return ['statistics_required needs statistics_plan before inference or plotting']
    return []  # Legacy benchmark specs are not silently rewritten or re-certified.


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path)
    args = parser.parse_args()
    doc = yaml.safe_load(args.input.read_text(encoding='utf-8'))
    plan = doc.get('statistics_plan', doc) if isinstance(doc, dict) else doc
    errors = validate_document(doc, args.input.parent) if isinstance(doc, dict) and ('statistics_required' in doc or 'statistics_plan' in doc) else validate_plan(plan, args.input.parent)
    status = 'READY' if not errors else 'BLOCKED'
    if isinstance(plan, dict) and valid_enum(plan.get('status'), {'needs_user_intent', 'needs_design'}):
        status = plan['status'].upper()
    questions = []
    if isinstance(plan,dict) and plan.get('mode')=='compute':
        if plan.get('status')=='needs_user_intent' or not valid_enum(plan.get('goal'), GOALS):
            questions.append('主要关注所有组两两比较、各处理与对照、交互/简单效应，还是随时间或剂量的趋势？')
        design = plan.get('design', {})
        if not isinstance(design,dict) or not valid_enum(design.get('dependence'), {'independent','paired','repeated','nested','clustered'}):
            questions.append('这些观测来自独立个体还是同一个体的配对/重复测量？哪个字段标识个体？')
    print(json.dumps({'status': status, 'errors': errors, 'questions': questions,
                      'boundary': 'declared plan consistency only; actual data/model diagnostics and results still required'}, ensure_ascii=False, indent=2))
    return 0 if not errors else 1


if __name__ == '__main__':
    raise SystemExit(main())
