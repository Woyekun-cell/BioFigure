---
name: biofigure
description: 设计、绘制、精修或审查生物科研图；R优先，兼容Python，检查科学语义、字体、排版与实际成图。
---

# BioFigure 3.1

每次调用先读 `references/personal-style.md`、`references/render-execution.md`、`static/core/contract.md`；随后读 `manifest.yaml`，运行 `scripts/route_figure.py` 并读取返回的模块。不得把路由JSON当成已经读过模块。

质量目标是当前任务匹配的用户参考图。必读 `references/reference-quality.md`：先开参考图、写可实现的设计参数，成图后逐项对照；规范通过而视觉未达目标仍为REVISE。

## 首次代码必须实现

- 默认R、纯白画布、Arial或Helvetica真实文件、单图。字体必须覆盖坐标轴、geom_text/repel、图例、热图注释、树与统计文字；不能只设theme或用sans代替。
- 先列图中允许出现的文本：轴/单位、刻度、基因/样本/组别、色标变量、预设统计标签。默认不写总标题、副标题、编号、脚注、口号、装饰解释。必要分组名与色标标题保留。
- 先定mm尺寸，实测文字，分配数据/注释/图例槽位，再写绘图层。图例外置；气泡细黑边；可读离散热图单格正方，分类条≤3mm。颜色按语义选，不锁死某一套。
- ggplot任务复用 `scripts/figure_style.R` 的字体、文字清单和导出检查；复杂图按 `references/render-execution.md` 显式设置每层。交付脚本附上所用函数，不能依赖用户机器上的Skill绝对路径。

## 执行与交付

科学契约、Pattern/参考检索、Design Spec、锁定后端渲染、实际看图、Critics依次执行。CP0–CP4见 `references/checkpoints.md`。R/Python不混用绘制后端；读取产物和独立QA可用其他工具。

先验证Spec；运行并开图后才提供可复现代码。首轮预检减少布局错误，真实设备仍须验图；发现缺陷修正布局规则后重绘。无执行能力只能标“未验证代码”。

Critic按 `critics/inspection-evidence.schema.yaml` 记录；缺专项证据为NOT_ASSESSED，不能代填PASS。只要PNG不生成多余交付格式。代码运行、检查点通过、视觉通过分别陈述，禁止据此保证“顶刊级”。严禁补造数据、统计或机制；未受托不重跑NGS分析。
