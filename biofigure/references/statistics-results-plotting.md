# 统计结果与绘图绑定

永久保留实际分析脚本、独立单位/绘图数据、必要统计表、模型诊断与软件版本；模拟验证标simulation。诊断图片与试图放work，必要结论并入现有合同，不默认新增报告。

每个效应/对比一行：`comparison_id, outcome, lhs, rhs, direction, n_lhs, n_rhs, method, formula, estimand, estimate, ci_low, ci_high, ci_scope, statistic, df, p_raw, p_adj, adjustment, family_id, status`。无适用字段写NA和原因，不能补造。已有结果保留原始字段语义和来源哈希，不把上游已校正P再次校正。

总体检验、主效应、交互检验、简单效应分别输出/标明。预先界定家族：同一科学问题的组间、时间点、特征或终点集合。少量确认性多对比可Holm控制FWER；大批探索特征可BH控制FDR，方法依据与依赖条件须声明。Tukey/Dunnett/Games–Howell等有其既定家族，不叠加另一校正却不说明。

绘图直接读取同表：

- 组间比较显示独立单位点和已定义中心/离散；配对按ID连接。
- 多因素显示交互/分面和适合的估计边际均值区间；模型区间与原始SD不能混称。
- 误差定义为SD/SEM/点态CI/同时CI；校正P不使普通95%CI自动变为同时CI。
- 星号/括号或字母来自 `comparison_id` 对应的实际校正P，阈值、家族和方向在图注。共享字母表示未拒绝差异，不表示相等；避免全两两括号遮挡数据。
- 仅均值、SD和n时不能反造分布/配对；确能由汇总数据计算的检验需独立公式、假设和来源审查。

未算、失败、不可估与不显著分别显示；禁止把NA变成ns或P=1。统计与标注变化使原检查失效，重新检查数值、误差、文字和最终尺寸。[有限R助手](../scripts/statistics_helpers.R)不代替诊断和方法选择。
