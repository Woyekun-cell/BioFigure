# 数据语义与研究情景

适用于原始观测、矩阵、汇总表、分析结果和未指定图型的请求。列名、数值类型及文件后缀只是线索；不能据此认定生物学含义。

## 先获取事实

读实际文件、数据字典、样本表与用户上下文。CSV/TSV可运行：

```bash
python3 scripts/profile_figure_data.py data.csv --group condition --unit subject
```

参数仅使用已确认的列，可重复 `--group`。不确定实验单位时省略 `--unit`，不要猜。JSON默认到标准输出；需留存时写项目 `work/本次任务/`。XLSX、R对象、AnnData使用其读取工具，记录同等事实，不能只改后缀。

核对行列、ID、缺失、重复、范围、分组行数、独立单位数、测量层级、配对完整性、时间/剂量间隔、单位/变换、误差定义、批次及混杂。大对象可分块；若抽样，明确范围，不把抽样统计写成全量。

## 再解释情景

`semantic_context`包含：`question`、`data_level`、`entities`、`column_roles`、`experimental_unit`、`design`、`comparison_direction`、`units_transforms`、`evidence`、`assumptions`、`unknowns`。

每项判断记录依据（文件/字段/用户陈述），标为已知、推断或未知；不输出虚构概率。优先级：明确实验说明、数据字典和实际数据；冲突时先解决冲突。数值ID不是连续测量；行数不等于生物学n。探索任务先用中性问题，不预设“上调/显著/有效”。

目标不明时，给探索性建议和假设；实验单位、配对、分母、效应方向等会改变结论的缺口，集中问最小必要问题。可继续无依赖的QC，不反复问已知事实。

## 决策与衔接

先按科学有效性筛选，再按问题、分布、密度和最终尺寸排序，见 [情景映射](semantic-scenarios.md)。首选1种，必要时备选1–2种，不为凑数推荐。

`chart_decision`记录 `status`（ready/conditional/needs_context）、`recommended`、`alternatives`、`rejected`、`rationale`、`required_fields`、`missing_fields`、`mappings`、`claim_limits`。备选和排除项各说明原因。ready仅代表选图信息足够，不代表统计/渲染已通过。

确认后将科学角色、领域、图型和字段传入既有route、Pattern检索与方法合同；科学前提不得被审美或案例匹配分数覆盖。数据、目的、配对或变换改变时重做受影响决策。

来源与边界见 [参考依据](semantic-sources.md)。
