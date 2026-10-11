# 绘图前的统计决策

用于新统计分析、重分析或统计图注审查。先区分 `compute`、`existing`、`descriptive`、`not_applicable`；已有结果不为画星号重算。新增计算由原始数据和明确分析需求授权，单纯复现版式不扩大统计范围。

## 提取设计与意向

读实际数据、字典和用户说明，确认：研究问题、结局类型、独立实验单位、因素及水平、协变量、技术重复、配对/重复/嵌套结构、比较方向、缺失和尺度。因素数量是设计因素数，不是分组组合数；多因素不是多结局。

意向优先使用当前或既有明确说明。关键缺口集中问一轮，不要求用户先知道检验名称：

- 三组以上：“主要比较所有组两两差异，还是各处理与某个对照？”
- 处理×时间：“关注处理总体效应、随时间变化的交互作用，还是预设时间点内的处理差异？”
- 重复结构不明：“各时间点是否来自同一个个体？哪个字段能连接个体？”
- 要求‘无差异/等效’：“希望证明差异小于哪个有意义的界值？”

未知目标记 `needs_user_intent`，未知设计记 `needs_design`。可继续QC和描述图；等待回复期间不运行依赖该缺口的检验或添加显著性。不根据P值最小来选方法、单双侧、终点或校正范围。

## 锁定并执行

按 [方法选择](statistics-method-selection.md)、[多因素与重复](statistics-factorial-repeated.md)、[诊断](statistics-diagnostics.md)在当次request标记 `statistics_required: true`，形成Design Spec顶层 `statistics_required: true` 和 `statistics_plan`；字段见 [统计计划](statistics-plan-contract.md)。描述性任务设false并声明边界。

运行 `scripts/validate_statistics_plan.py <Spec或计划.yaml>`；通过后生成当前项目R分析脚本，可用 `scripts/statistics_helpers.R` 的有限辅助函数。执行示例见 [R配方](statistics-r-recipes.md)；复杂模型按专项实现，不降级成独立t检验。保存结果、诊断、软件版本与代码；按 [统计与成图](statistics-results-plotting.md)映射标记，再走原CP和视觉门禁。

计划校验不证明数据或模型成立；具体任务仍需实际诊断和数值核验。[来源](statistics-sources.md)。

多组学关联、交集富集、配对方法评价或等位读数，另读 [顶刊案例统计边界](statistics-multiomics-learning.md)；原文检验不自动迁移到新实验设计。
