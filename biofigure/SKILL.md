---
name: biofigure
description: Use when choosing a suitable chart from biological data, designing, drawing, reproducing, reviewing, or revising research figures; 根据生物数据判断适合的图型、按数据选图、设计、绘制、复现、审查或修订科研图。
---

# BioFigure 3.7.1

根据数据、实验设计和科学问题选择图型、实现并核验科研图。用户只问选图时给首选、备选和理由，不渲染。

## 启动门

先定位Skill根，运行轻检索，不预读整套总览或遍历图库：

```bash
python3 <Skill根>/scripts/find_figure_reference.py --query "图型 + 数据含义 + 科研问题"
```

默认前三条给图/码路径、命中理由及配对风险。`--list-types`列类别，`--type "森林图"`筛选；中文同名入口在`library/按图型检索/类别/{来源图,对应代码}`，代码回原路径运行。来源页候选需辨论文/教程/复现并核数据图层；选ID用`retrieve_learned_methods.py --case-id <ID>`读合同/核心代码/缺陷，request绑定`learned_method_id`再fresh prepare/CP2。选图咨询到此结束。零命中或不适配先改关键词，再查[总入口](references/benchmark-learning-index.md)。无文字图先描述结构；词法排名不当视觉相似度。

正式绘图读`static/core/execution-contract.yaml`与[绘图门禁](references/figure-execution-gates.md)；已验适配器才读[复用规则](references/stable-template-reuse.md)。CP2仍绑定采用/拒绝、适配及renderer哈希。原图密度需对照；候选/needs-revision不继承PASS。

领域页按需读：
- 基因组/多组学：[Nature](references/nature-genomics-multiomics-learning.md)，核坐标、量纲、证据与源码版本。
- 冻融：[MBE](references/msad040-visualization-learning.md)，缺重复仅源表汇总。
- 泛基因组：[流程](references/pangenome-learning.md)，request声明pangenome_context。
- 单细胞：[Han轨迹/投票树](references/han-foregut-single-cell-learning.md)、[Wahle空间](references/wahle-retinal-single-cell-learning.md)、[Hochgerner网络](references/hochgerner-dentate-single-cell-learning.md)、[Trevino多组学](references/trevino-cortex-single-cell-learning.md)。各自核类别/模态色、预处理、排序与辅助函数缺口。
学习逐项记录预处理、函数/包、色义、布局和导出；区分源码证实、原图观察与脚本缺失。源码学习不等于原图复现；缺终稿组装仅迁移技法。

请求与回执存现有项目 `work/<任务>/`；同一学习主题不按对话新建Project：

```bash
python3 <Skill根>/scripts/prepare_figure.py <项目>/work/<任务>/request.yaml --output <项目>/work/<任务>/preparation-receipt.json
```

关键科研字段缺失时返回 `NEEDS_SPEC`；未指定图型则按数据与问题选型。预检或CP2失败不得写图代码。`manifest.yaml`仅路由材料。

## 统计决策

统计/重分析读[流程](references/statistics-workflow.md)，按结局、因素、配对/重复及比较目标选方法；关键意向/设计缺失先问，答复后做依赖检验。咨询只给条件式建议。

推断图声明 `statistics_required: true`、`statistics_plan`，运行 `validate_statistics_plan.py`并过CP2。诊断/统计表完成才映射效应、区间和显著性；已有P/q保留来源/校正，不为画图重算；描述图声明边界。

首次成图即用有科学语义的彩色，禁止先黑白后补色；黑白数据图不能视觉PASS，见[配色规则](references/palette-system.md)。批量任务逐图验色并完整展示，不用单张代表整批。

柱状图默认加可辨认的深色细描边（ggplot2 `colour="#30343B"`, `linewidth=0.35` mm），适用于普通、分组和堆积柱；最终尺寸检查边界，禁止粗边抢占数据。用户明确另指定时按新要求执行。

## 统一执行

1. 按路由读所需材料并执行 [绘图门禁](references/figure-execution-gates.md)。核对实验单位、重复、尺度、缺失、比较方向；候选不替代科学判断。
2. 打开原尺寸来源图与方法/包材料，拆解面板、图层、映射、位置、层级和包职责。项目首图建立 `project-style.yaml`；后续图必须绑定其哈希、palette ID、语义色、字体角色及尺寸等级，偏离须写依据并重审。Design Spec同时锁定最终画布与字号：单栏89–90 mm、1.5栏120–136 mm或双栏180–183 mm，常规高度≤170 mm。
3. 按[字号参考](references/layout.md)起步，依实际图文比例修正并更新Spec。编码前运行 `validate_design_spec.py <Spec> --preparation-receipt <回执>`；成功才可开始编码。编码后、渲染前签发一次性授权；R用 `bf_render_png()`消费。Python无官方授权入口，不得CP3 PASS。
4. CP3打开最终PNG并绑定首版/终版、哈希和目标尺寸。CP4逐项检查字号、文字位置、标签/图例重叠、裁切、面板对齐及图文比例；大画布小字必须 `REVISE`。每次重绘使旧检查失效。

验收后将来源、脚本、plot data、终图、环境、QC及失败规则追加主题包，更新索引/分类入口。锁基线并独立复跑才登记稳定模板；清理仅可重建临时项。写入Skill/参考文档不覆盖旧证据。

分别报告科学、技术、来源与用户验收。脚本PASS不等于视觉或复现PASS；未盲测的模型与环境不得声称等效。
