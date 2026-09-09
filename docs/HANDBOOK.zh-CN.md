# BioFigure 3.1 中文完整手册

## 1. 定位

BioFigure 是统一的生物科研图生产 Skill。目标是从研究问题生成科学可信、视觉克制、代码可复现、可实际审查的单图或组图。它不负责原始 NGS 流程，也不以“Nature 风格”替代具体数据语义和期刊要求。

## 2. 启动与动态加载

`biofigure/SKILL.md` 是短入口。每次调用先加载个人风格、渲染执行、参考质量、科学契约、立场和检查点，再由 `manifest.yaml` 按四维路由加载领域资料：主/次生物领域、主/次科学角色、唯一后端、交付目标。`scripts/route_figure.py` 返回模块清单和后端锁；返回清单不等于已经阅读模块。

领域包括转录/代谢/多组学、单细胞/空间、染色质、基因组与变异、系统树/共线性/基因家族、图像实验、机器学习、机制图和多面板。角色包括 QC、发现、比较、结构、机制、验证、预测及稳健性/模型评估。

## 3. 科学契约

`static/core/contract.md` 约束所有下游。渲染前必须记录核心结论和边界、生物实体与关系、实验/统计/重复单位、坐标、单位、变换、过滤、缺失值和不确定性。统计不适用也要说明理由。用户未提供数值时只能画明确标记的结构示意或模拟图。

图像实验需保留比例尺、曝光和代表图选择边界；机器学习需检查训练/验证/测试隔离、泄漏、校准和外部验证；基因组图需检查组装版本、坐标系、链方向、ID 映射和同源关系；机制图的每条边要有证据等级，不能把相关性画成已证实机制。

## 4. Pattern Retrieval 与 Atlas

`patterns/` 保存19种可复用设计模式，例如火山图、原始点＋箱体、方格热图、PCA、单细胞气泡、染色质信号、富集、多组学因子、系统树＋基因结构、染色体密度、共线性和多面板证据链。Pattern 写适用场景、视觉层级、编码、布局、可选组件、风险和 Renderer，不保存一次任务的具体数值。

`atlas/` 保存 Pattern 的证据。Top-journal corpus 是人工整理的主要证据；SciDraw 是补充设计线索。网页图、标题和代码入口必须来自同一卡片；关联成功不代表科学或视觉通过。参考优先级为作者代码/官方 vignette、有 Source Data 的论文图、仅图片的视觉参考。已检索、已读代码、已运行、已看图和人工认可必须分开记录。

## 5. Figure Design Spec

`schemas/figure-design-spec.schema.yaml` 要求在编码前锁定：任务与信息、数据和生物契约、后端与交付、候选及选中 Pattern、参考观察和拒绝项、视觉层级、编码、注释、图例、配色语义、Renderer、物理尺寸、各版面槽位、字体文件、允许文本、白底和检查计划。Spec 验证失败时不能进入绘图。

## 6. Renderer 与 Components

`renderer-registry.yaml` 登记18个后端。R 默认用 ggplot2；矩阵用 ComplexHeatmap；树用 ggtree；基因组与共线性用 gggenomes/circlize；单细胞可用 Seurat＋自定义 ggplot。Python 提供 matplotlib、seaborn、Scanpy、pyGenomeTracks 和 pyGenomeViz。专用工具可提供输入，但不能绕过最终 QA。

`components/` 定义 marks、labels、legends、annotation、statistical layers 和 genomic tracks。组件是可组合对象，不是成图模板。数据区、标签区、注释区和图例区必须先按毫米分配。

## 7. 首次成图标准

默认 Arial 或 Helvetica 真实字体、纯白画布、单图、无无意义标题。热图方格与细边按最终物理尺寸计算；分类条通常不宽于3 mm。气泡图使用细黑描边，面积与颜色分别编码不同变量。图例外置。配色依据变量类型、中心值、类别数、色觉安全和灰度辨识选择，不固定某套颜色。

有生物学重复的比较图需同步输出统计表：分析尺度、总体检验、预设比较、多重校正、效应量、置信区间及精确 P/q。配对或重复测量未知时不能擅自检验。Illustrator 只做末端对象级调整；可复现的修改回写代码。

## 8. 实际检查、Critics 与 Benchmark

CP0 确认科学意图；CP1 固定科学契约；CP2 锁定设计；CP3 打开最终 PNG 并记录哈希、尺寸、查看方式和缺陷；CP4 在 Critics 与 QA 通过后交付。前门失败时后门不能 PASS。

Scientific Critic 检查语义和统计；Visual 检查层级、密度、构图、留白；Publication 检查字体、线宽、裁切和导出；Anti-AI 检查装饰化标题、卡片和模板腔；ML、图像、基因组和机制图有专项 Critic。Benchmark 以统一权重测试整个 Skill，不代替单图审查。`CODE EXECUTES`、`FIGURE PASSES`、用户认可和期刊接收是四件不同的事。

## 9. 目录导航

| 路径 | 职责 |
|---|---|
| `SKILL.md` / `manifest.yaml` | 入口与路由 |
| `static/core/` | 不可破坏的科学与视觉立场 |
| `references/` | 领域、图型、布局、统计、导出和来源规则 |
| `patterns/` / `atlas/` | 设计语法与证据 |
| `components/` | 可组合视觉组件 |
| `schemas/` | 结构契约 |
| `scripts/` | 路由、检索、验证和 R 样式工具 |
| `critics/` / `checkpoints/` | 成图门禁 |
| `benchmark/` / `test-prompts.json` | 多任务回归评价 |
| `examples/gallery/` | 可运行模拟模板 |

返回：[README](../README.md) · [English handbook](HANDBOOK.en.md)

