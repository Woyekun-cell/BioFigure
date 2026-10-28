# BioFigure 3.8.0 中文完整手册

## 3.8.0 公开发行范围

[公开案例清单](../biofigure/public-cases.json)区分 13 个可执行入口与 2 个 DPM 仅参考档案。可执行入口包括 7 个一方模拟例、Cannabis 两案、Planarian、OHCA、桑基图和 OncoPrint。OncoPrint 保留12×144全部单元，以3个12×48原生方格矩阵排布；当前固定输入、macOS执行与PNG/PDF另行核验，历史记录不迁移为当前通过。454 条学习档案按方法组织，便于查找图型、设计思路和对应来源；可分发材料与执行入口见各项记录。

依赖检查分为 `portable` 和 `all-public`：前者覆盖新增 7 例与 OncoPrint，后者补齐保留案例的专用 R 包。Cannabis 需固定 BUSCOplot 来源；OHCA 需既有 HiContacts/HiCExperiment 等 R 依赖及固定哈希 RDS，锁定提交和来源见 [README 安装说明](../README.md#安装与使用)及案例执行配置。macOS 已实跑；Linux、Windows 未验证。Python 新环境仍使用既有 R 包及 Arial，不等于全新操作系统安装验收。代码执行、材料审计、来源保真、当前 PNG/PDF 审阅和用户认可分别记录。


`portable` 与 `all-public` 依赖检查遵守 R 4.6.1／Bioconductor 3.23 和固定顶层包版本；`all-public` 另安装并核验两项作者包源码及专用依赖。安装只写显式 R library；执行时设同一 `R_LIBS_USER`。公共 PDF 使用共享精确字体／Ghostscript 接口，Windows 与 macOS 的实际测试和终图审阅结果见[双系统验证说明](PLATFORM-VALIDATION.md)。不分发字体，也不因配置完成宣称两系统已经通过。

## 1. 定位

BioFigure 把研究问题、已有分析结果和图形设计接在一起，做成代码可复现、便于继续修改的单图或组图。原始 NGS 分析在上游完成；选图、编码与排版围绕具体的数据语义和期刊要求展开。

## 2. 启动与动态加载

`biofigure/SKILL.md` 是短入口。每次新图、复现或修图先运行 `scripts/prepare_figure.py`，统一检索复现库、顶刊图谱、SciDraw、能力图谱与方法包，并生成哈希回执；Design Spec/CP2 必须绑定该回执和选中方法ID。随后 `manifest.yaml` 按四维路由加载领域资料：主/次生物领域、主/次科学角色、唯一后端、交付目标。候选命中不等于已读图或验证通过。

领域包括转录/代谢/多组学、单细胞/空间、染色质、基因组与变异、系统树/共线性/基因家族、图像实验、机器学习、机制图和多面板。角色包括 QC、发现、比较、结构、机制、验证、预测及稳健性/模型评估。

## 3. 科学契约

`static/core/contract.md` 约束所有下游。渲染前必须记录核心结论和边界、生物实体与关系、实验/统计/重复单位、坐标、单位、变换、过滤、缺失值和不确定性。统计不适用也要说明理由。用户未提供数值时只能画明确标记的结构示意或模拟图。

图像实验需保留比例尺、曝光和代表图选择边界；机器学习需检查训练/验证/测试隔离、泄漏、校准和外部验证；基因组图需检查组装版本、坐标系、链方向、ID 映射和同源关系；机制图的每条边要有证据等级，不能把相关性画成已证实机制。

## 4. Pattern Retrieval 与 Atlas

`patterns/` 保存19种可复用设计模式，例如火山图、原始点＋箱体、方格热图、PCA、单细胞气泡、染色质信号、富集、多组学因子、系统树＋基因结构、染色体密度、共线性和多面板证据链。Pattern 写适用场景、视觉层级、编码、布局、可选组件、风险和 Renderer，不保存一次任务的具体数值。

`atlas/` 保存 Pattern 的证据。Top-journal corpus 是人工整理的主要证据；SciDraw 是补充设计线索。网页图、标题和代码入口必须来自同一卡片；关联成功不代表科学或视觉通过。参考优先级为作者代码/官方 vignette、有 Source Data 的论文图、仅图片的视觉参考。已检索、已读代码、已运行、已看图和人工认可必须分开记录。

## 5. Figure Design Spec

`schemas/figure-design-spec.schema.yaml` 要求在编码前锁定：任务与信息、数据和生物契约、后端与交付、预检回执ID、选中方法案例及 Pattern、参考观察和拒绝项、视觉层级、编码、注释、图例、配色语义、Renderer、物理尺寸、各版面槽位、字体文件、允许文本、白底和检查计划。Spec 或 CP2 校验失败时不能进入绘图。

## 6. Renderer 与 Components

`renderer-registry.yaml` 登记18个后端。R 默认用 ggplot2；矩阵用 ComplexHeatmap；树用 ggtree；基因组与共线性用 gggenomes/circlize；单细胞可用 Seurat＋自定义 ggplot。Python 提供 matplotlib、seaborn、Scanpy、pyGenomeTracks 和 pyGenomeViz。专用工具可提供输入，但不能绕过最终 QA。

R 提供准备、CP2、一次性授权及成图审查执行链。Python 当前支持代码工作流，但没有官方绘图授权入口，不能声明 CP3 PASS。公开依赖脚本 `install_public_dependencies.R` 的 `portable` / `all-public` 配置精确锁定 R 4.6.1 与所列包版本；这不是所有 R 入口的统一版本硬锁。冷安装与已配好环境的入口见 [README](../README.md#快速开始)，实际跨平台证据见[平台记录](PLATFORM-VALIDATION.md)。

`components/` 定义 marks、labels、legends、annotation、statistical layers 和 genomic tracks。组件是可组合对象，不是成图模板。数据区、标签区、注释区和图例区必须先按毫米分配。

## 7. 首次成图标准

默认 Arial 或 Helvetica 真实字体、纯白画布、单图、无无意义标题。热图方格与细边按最终物理尺寸计算；分类条通常不宽于3 mm。气泡图使用细黑描边，面积与颜色分别编码不同变量。图例外置。配色依据变量类型、中心值、类别数、色觉安全和灰度辨识选择，不固定某套颜色。

有生物学重复的比较图需同步输出统计表：分析尺度、总体检验、预设比较、多重校正、效应量、置信区间及精确 P/q。配对或重复测量未知时不能擅自检验。Illustrator 只做末端对象级调整；可复现的修改回写代码。

## 8. 实际检查、Critics 与 Benchmark

CP0 确认科学意图；CP1 固定科学契约；CP2 锁定设计；CP3 打开最终 PNG 并记录哈希、尺寸、查看方式和缺陷；CP4 在 Critics 与 QA 通过后交付。前门失败时后门不能 PASS。

Scientific Critic 检查语义和统计；Visual 检查层级、密度、构图、留白；Publication 检查字体、线宽、裁切和导出；Anti-AI 检查装饰化标题、卡片和模板腔；ML、图像、基因组和机制图有专项 Critic。Benchmark 以统一权重测试整个 Skill，不代替单图审查。`CODE EXECUTES`、`FIGURE PASSES`、用户认可和期刊接收是四件不同的事。

固定案例的通过只绑定当时输入、代码、环境和实际输出。新数据需重新确认科学与统计契约并重跑门禁；其他平台需重新核验依赖、字体、设备和成图。全量 V2 benchmark 尚未完成，图库收录、安装检查和局部测试均不替代全量验证，也不产生通用审美评分。

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
