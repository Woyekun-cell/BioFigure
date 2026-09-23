# Awesome Scientific Figure 学习实施计划

> **For agentic workers:** 后续按任务逐项实施、核验；当前任务不要求并行代理。

**Goal:** 把外部图目录转为 BioFigure 可检索、可验证的绘图方法，而非仅收集图片。

**Architecture:** 独立候选层只收录目录元数据；通过原论文、图注、数据与代码核查后，才可进入已验证方法层。与现有顶刊案例、CP0–CP4 和参考忠实度验收保持分离。

**Tech Stack:** JSON、Python 标准库、BioFigure manifest/Atlas、R 优先的独立重绘。

**Spec:** 用户要求学习该项目库并提升 BioFigure；来源为 [awesome-scientific-figure](https://github.com/nehSgnaiL/awesome-scientific-figure/tree/8632aa34fcc1b0b2c3f66a7b1ddd4c0e587a25a8)。

## 约束与验收

- 不复制第三方图片、调色板或论文数据；原库未提供可确认的整体复用许可，逐项核权。
- 目录标签只作候选线索；不得由标签推断统计方法、数据处理或图的实际结构。
- 每类型先选一个科学相关、视觉语法不同的案例，避免同类重复堆积；新案例须证明新增能力。
- 每次记录来源版本、图号、科学任务、实验单位、输入字段、代码/数据/许可、最终图证据；未知项明确标注。

## Task 1：候选索引接入（本轮）

- [x] 核查目录版本、条目、许可与可用代码；记录来源。
- [x] 建 `biofigure/atlas/awesome-scientific-figure-candidates.json`：按时序组合、组间比较、拟合关系选三个不重复候选。
- [x] 建 `biofigure/scripts/retrieve_awesome_figures.py` 和可选 manifest 路由；查询结果始终声明“验证证据不足”。
- [x] 建 `biofigure/references/awesome-scientific-figure-learning.md`，补 BioFigure 入口与针对性单测。

## Task 2：逐图核对（待做）

- [ ] 从原论文核对标题、图号、图注、面板、坐标、统计量和实验单位；记录原始 Source Data/代码及许可。
- [ ] 对每类型提炼布局、编码、图例和失败边界；做一张含来源与禁止迁移项的方法卡。

## Task 3：独立复现与迁移（待做）

- [ ] 按 BioFigure 数据契约写脚本和绘图数据；原数据不可用时标明固定种子模拟，仅评估结构。
- [ ] 在目标尺寸检查实际 PNG/PDF，分别跑参考复现、换数据迁移、压力案例及 CP0–CP4；记录失败并修正。
- [ ] 仅在来源、许可、科学语义、最终图及基准均通过后，将方法提升到已验证 Atlas；否则保留候选状态。
