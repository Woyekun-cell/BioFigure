---
name: biofigure
description: Use when choosing a suitable chart from biological data, designing, drawing, reproducing, reviewing, or revising research figures; 根据生物数据判断适合的图型、按数据选图、设计、绘制、复现、审查或修订科研图。
---

# BioFigure 3.8.0

按数据、实验设计与问题选图、绘制、核验；选图咨询给首选、备选与理由。

## 启动与模式

先定位Skill根，读`static/core/execution-contract.yaml`与[绘图门禁](references/figure-execution-gates.md)。[证据模式](references/reference-modes.md)贯穿request、Spec、授权与CP4：
- `original`：普通新画默认；须先检索、审阅匹配模板与参考代码，再按当前数据设计。不以DOI、作者数据或私人档案作前置。
- `reference-guided`：采用来源/learned/reuse；绑定真实来源、采用/拒绝、适配与renderer哈希。
- `reproduction`：`operation: reproduce`；保留原图、作者码、源数据与panel映射。模式冲突拒绝，缺材料不偷换原创。

**所有绘图写代码前必须轻检索匹配模板与参考代码，读图读码并适配；原创不豁免。** 检索与采用分开，不预读图库：

```bash
python3 <Skill根>/scripts/find_figure_reference.py --query "图型 + 数据含义 + 科研问题"
```

前三卡只定位；`--list-types`/`--type`筛型。选ID后读原尺寸图、代码/合同/缺陷；learned用`retrieve_learned_methods.py --case-id <ID>`。原创用回执`design_discovery`和Spec的`reference_evidence.design_precedent`按[模式合同](references/reference-modes.md)绑定候选、哈希、六项review及适配；无可用候选逐项说明拒绝后走`pattern-fallback`，缺私人档案不锁死。来源/复现保留原source/template/learned证据合同，不强加这两个新字段。排名不是视觉证据，锁定模板按[复用规则](references/stable-template-reuse.md)执行。

## 统一执行

请求、回执存现有项目`work/<任务>/`；同主题不另建Project。

**R为主，Python仅候补**：常规统计、矩阵、树、基因组与组图优先R；仅用户指定、保留既有Python原生流程或R无合适实现时选Python，并记录原因。Spec前锁定；R失败不静默切换。切换须更新Spec、准备、授权与审阅；候补不降低质控。

```bash
python3 <Skill根>/scripts/prepare_figure.py request.yaml --output preparation-receipt.json
```

1. 核问题、实验单位、分组/方向、配对、尺度与缺失；技术重复非独立n。关键语义缺失返`NEEDS_SPEC`；未指定图型先选型，不猜显著性。
2. 完成参考审阅及适配，写完整`reference_analysis`：面板、元素、映射、拓扑、层级、包职责；`design_target`保留六维。原创不虚填来源；来源/复现继续绑定原图、代码和输入。首图建`project-style.yaml`，后续绑定其哈希、语义色、字体角色与尺寸。
3. 按[布局](references/layout.md)锁最终画布/字号。运行`validate_design_spec.py <Spec> --preparation-receipt <回执>`，成功才可开始编码；预检或CP2失败禁写图代码。编码后、渲染前签发一次性授权；默认R用`bf_render_png()`，Python Matplotlib Figure用[官方`bf_render()`](references/python-rendering.md)消费。授权须绑定实际脚本、输入、Spec及所用helper；其他CLI导出不自动取得正式凭据。
4. CP3打开当前PNG/PDF，核真实字体、终尺寸与哈希；CP4检查字号/位置、碰撞、裁切、对齐、配色与图文比例。原创`design-quality`、来源`reference-quality`均须hierarchy/geometry/palette/typography/marks/annotation六维实际观察。重绘使旧检查失效；自动检查不能替代human/model审图。

按[变更范围复核与收口](references/workflow.md)：日常单次出图，将输入/统计核验与最终PNG/PDF审图合并一轮；必要检查通过即交付。无硬缺陷不继续润色，登记文字、路径整理和基准归档不触发重画；新输入、绑定变更或实际重渲染仍执行相应门禁，不沿用旧审阅。

## 专项硬门

- 推断读[统计流程](references/statistics-workflow.md)，声明`statistics_required`与plan，先诊断/统计后标注；已有P/q保留来源，不为画图重算。
- 首版即[语义彩色](references/palette-system.md)；柱图默认深细边`#30343B`、0.35mm。点/线/带按[图层透明度](references/mark-opacity.md)分控fill/edge。
- [热图](references/heatmaps.md)：少量物理方格，密集例外须声明；CP3逐slice实测，CP4看当前图。
- [文字](references/enforced-execution.md)：caption/footer/脚注、方法/阈值段落、AI备注移图外；标题授权/白名单不豁免。核到底边，缺`footer_absent`实际观察不交付。

交付保留输入、plot data、脚本/配置、PDF、环境/QC；分别报告科学、执行、视觉、来源与用户验收。旧PASS不迁移；源码学习、固定复跑、原图复现和新输入迁移分别记录，不升级档案资格。
