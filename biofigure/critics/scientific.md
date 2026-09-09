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
