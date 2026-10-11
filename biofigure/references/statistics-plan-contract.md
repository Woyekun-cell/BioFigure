# 可校验的统计计划

计划可直接作为YAML文件，或嵌入Design Spec顶层 `statistics_plan`。新推断任务另设 `statistics_required: true`。旧benchmark不自动补造/提升统计证据；新请求必须按统计流程建立计划。

```yaml
mode: compute
status: ready
question: 处理相对对照的均值差
intent_source: user
intent_evidence: 用户指定比较处理与对照
estimand: mean_difference
alternative: two.sided
goal: planned_contrasts
method: welch_t
formula: response ~ group
rationale: 两独立组；比较均值，不合并估计方差
design:
  outcome_type: continuous
  response: response
  factors: [group]
  factor_levels: {group: [control, treatment]}
  covariates: []
  independent_unit: animal_id
  dependence: independent
  evidence: 已核对样本字典和独立个体ID
  technical_replicates: 已按测量流程聚合；保留QC
  missing_policy: 不自动删行，先核对缺失
  outlier_policy: 无事后剔除
  scale: 原始测量单位
contrasts: [treatment minus control]
diagnostics: [独立性按设计核对, 组内分布及影响点, 有效样本量]
multiplicity: {method: none, family: 单一预设对比, n_tests: 1}
results:
  table: results/tables/comparisons.csv
  effect: lhs_minus_rhs
  interval_scope: pointwise_95_percent
  annotation_source: same_results_table
```

多因素填实际因素、协变量及公式；交互目标填 `interaction_terms`；依赖设计填 `dependence_id`；对照目标填 `control_level`。常规等方差方法需要 `equal_variance_basis`。单侧需 `one_sided_basis`。Friedman需 `complete_blocks: true`。

不确定填 `needs_user_intent` 或 `needs_design`，不写ready；如实记录问题。校验器阻止推断，不代答用户。描述/不适用模式填 `reason` 和 `significance_annotations: false`。

`existing`模式填 `source: {path, sha256, p_semantics, comparison_mapping, provenance}` 与 `recompute: false`；路径相对计划文件，文件必须存在且哈希一致。原始/校正P区分为raw/adjusted/mixed_declared；不复算不等于无需审查设计及结果含义。

校验器核对声明、方法大类与结果绑定，不读取所有原始数据或代做假设检验。现有Design Spec门禁在出现该合同/必需标志时调用它；未使用新字段的历史Spec维持原验证范围。
