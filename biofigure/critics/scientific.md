# Scientific Critic（永远运行）

核对数据与样本 ID、实验单位和 biological n；assay/layer、尺度/变换、缺失/零值；轴、单位、分母、色阶中点、效应方向、P/q 和多重校正；细胞与样本边界；热图缩放；基因组 assembly/坐标/strand/ID；树拓扑和支持度；SV/CNV/网络边含义；富集背景与映射。

固定输出：

```yaml
status: PASS | REVISE | FAIL
hard_failures: []
major_issues: [{issue: "", evidence: "", proposed_fix: ""}]
minor_issues: []
evidence: "实际核对的数据、实验单位、尺度、统计表与结论边界"
next_action: ""
```

错误尺度、样本错配、伪重复、坐标越界、未声明分母或把相关写成因果属于 hard failure，直接 FAIL。

无数值的结构/机制图明确统计不适用及原因。没有执行此审查时记录NOT_ASSESSED，不能由图像白底或Pattern存在推断科学正确。

统计推断追加核对 [统计计划与流程](../references/statistics-workflow.md)：目标与检验假设匹配、单/多因素、个体相关、交互解释、诊断/可估性、家族校正、结果表与图中标记一一对应。未解决的分析意向、伪重复、忽略依赖、以差异显著性推断交互、NA当ns、标记脱离结果表均阻止统计通过；缺少实际诊断不得由计划ready推为分析通过。
