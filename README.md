<div align="center">

# BioFigure

**参考引导的生物科研图设计与质控 Skill**<br>
**A reference-guided design and quality-control skill for biological figures**

[![BioFigure](https://img.shields.io/badge/BioFigure-3.5.1-28527A)](biofigure/SKILL.md)
[![R first](https://img.shields.io/badge/backend-R%20first-4F8F8A)](biofigure/renderer-registry.yaml)
[![Python compatible](https://img.shields.io/badge/Python-compatible-7D719B)](biofigure/renderer-registry.yaml)
[![License: MIT](https://img.shields.io/badge/license-MIT-C97864)](LICENSE)

[中文手册](docs/HANDBOOK.zh-CN.md) · [English handbook](docs/HANDBOOK.en.md) · [设计来源 / Sources](docs/DESIGN-SOURCES.md) · [精选图廊 / Gallery](docs/GALLERY.md) · [版本下载 / Releases](https://github.com/Woyekun-cell/BioFigure/releases) · [Community](https://github.com/Woyekun-cell/BioFigure/discussions)

</div>

BioFigure 面向多组学及生物医学研究中的图形表达，提供从数据结构检查、图型选择到 R/Python 编码、排版和成图审查的工作流程。它以 Skill 的形式供编码助手使用：结合研究问题和输入数据选择绘图方法，并保留可修改的代码与绘图数据。<br>
BioFigure supports figure design across multi-omics and biomedical research, from checking data structures and selecting plot types to writing R/Python code, arranging panels, and reviewing the output. As a Skill for coding assistants, it connects the research question to suitable plotting methods and retains editable code and plotting data.

R 是默认后端。矩阵注释、环形轨道、系统树、基因组坐标和多面板组合分别使用适合的专用包；AnnData、Scanpy 等原生数据对象也可沿用 Python 工作流。重点是保留图的科学含义，同时处理好文字、配色、图例和面板之间的关系。<br>
R is the default backend. Dedicated packages handle annotated matrices, circular tracks, phylogenies, genomic coordinates, and panel assembly. Native AnnData and Scanpy workflows can remain in Python. The aim is to preserve scientific meaning while giving labels, colors, legends, and panels a clear layout.

## 适用领域与图型 / Research areas and plot types

| 研究领域<br>Research area | 绘图任务<br>Plotting tasks |
|---|---|
| 转录组、蛋白组<br>Transcriptomics and proteomics | 表达与差异热图、火山图、分组表达、富集结果、相关矩阵<br>Expression and differential heatmaps, volcano plots, grouped expression, enrichment, correlation matrices |
| 代谢组与多组学整合<br>Metabolomics and multi-omics | PCA、丰度分布、跨组学关联、注释热图、关联网络<br>PCA, abundance distributions, cross-omics associations, annotated heatmaps, networks |
| 单细胞与空间组学<br>Single-cell and spatial omics | 降维嵌入、标记基因气泡图、细胞组成、空间表达及分面比较<br>Embeddings, marker dot plots, cell composition, spatial expression, faceted comparisons |
| 表观组与染色质<br>Epigenomics and chromatin | ATAC/ChIP 信号曲线、信号热图、区域与基因组轨道<br>ATAC/ChIP profiles, signal heatmaps, regions and genomic tracks |
| 基因组与比较基因组<br>Genomics and comparative genomics | 染色体与区间分布、共线性、环形连线、系统树及对齐注释<br>Chromosome and interval distributions, synteny, circular links, phylogenies with aligned annotations |
| 微生物与生态研究<br>Microbiology and ecology | 群落组成、排序分析、系统树、丰度与环境关联<br>Community composition, ordination, phylogenies, abundance and environmental associations |
| 临床与实验生物学<br>Clinical and experimental biology | 生存曲线、森林图、患者泳道、时序响应、分组比较与模型评估<br>Survival curves, forest plots, patient swimmers, time courses, group comparisons, model evaluation |
| 综合展示<br>Integrated figures | 多面板组合、图像实验板和证据注释<br>Multi-panel figures, imaging plates, evidence annotations |

以上是方法与路由覆盖范围；具体任务取决于输入数据、包依赖和相应方法的验证状态。已有分析结果可直接用于绘图，缺少上游数据时不会声称完成了相应分析。<br>
These are areas covered by the method library and routing rules. Individual tasks depend on the available data, dependencies, and validation status. Existing analysis results can be plotted directly; unavailable upstream analyses are not treated as completed.

## 分类图廊 / Gallery by plot type

完整收录本地已有科研成图 **14 类、216 张**。点击分类查看对应图片，较大类别分页；历史修订版折叠保留。<br>All 216 inventoried scientific figures are organized into 14 categories. Click a category to browse; historical versions remain available in folded sections.

数据来源包括模拟数据、公开数据和软件包示例，逐图标注。收录不等于原论文数据复现或完整验收。<br>Each figure states whether it uses simulated, public or package-example data. Inclusion does not certify reproduction of original research findings.

| 图型分类 / Category | 图数 / Figures |
|---|---:|
| [热图与矩阵注释 / Heatmaps](docs/gallery/heatmaps.md) | 25 |
| [分布、箱线与小提琴 / Distributions](docs/gallery/distributions.md) | 27 |
| [相关、散点与气泡矩阵 / Correlations and scatter plots](docs/gallery/correlations.md) | 20 |
| [组成、桑基与三元图 / Composition and flows](docs/gallery/composition.md) | 19 |
| [柱形、棒棒糖与花瓣图 / Bars and lollipops](docs/gallery/bars.md) | 14 |
| [雷达与多指标比较 / Radar plots](docs/gallery/radar.md) | 7 |
| [差异表达、富集与曼哈顿图 / Differential expression](docs/gallery/differential.md) | 19 |
| [降维、单细胞与空间 / Embeddings and spatial plots](docs/gallery/embeddings.md) | 12 |
| [生存、森林与患者轨迹 / Clinical plots](docs/gallery/clinical.md) | 18 |
| [基因组、染色体与系统树 / Genomes and phylogeny](docs/gallery/genomes.md) | 25 |
| [网络与地图 / Networks and maps](docs/gallery/networks.md) | 10 |
| [时序、曲线与信号 / Time courses and profiles](docs/gallery/profiles.md) | 14 |
| [集合交叠与 UpSet / Set intersections](docs/gallery/intersections.md) | 2 |
| [机制、图像与多面板 / Mechanisms and panels](docs/gallery/multipanel.md) | 4 |

[完整分类目录](docs/GALLERY.md) · [逐图清单与文件哈希](docs/gallery/catalog.csv)。复合图只归入一个主要类别，变体分别计数。

## 绘图方法与质量检查 / Methods and quality checks

**按图型选择包。** 通用统计图采用 ggplot2，复杂矩阵注释采用 ComplexHeatmap，环形坐标采用 circlize，系统树采用 ggtree，基因组轨道与共线性采用 gggenomes，多面板采用 patchwork 或 cowplot。具体包和关键函数在编码前确定，避免用不合适的基础图层替代专用布局。<br>
**Choose packages by task.** Use ggplot2 for general statistics, ComplexHeatmap for annotated matrices, circlize for circular coordinates, ggtree for phylogenies, gggenomes for genomic tracks and synteny, and patchwork or cowplot for panel assembly. Select the package and key functions before coding.

**先核对科学含义。** 检查实验单位、分组、配对关系、比较方向、数据变换及坐标。请求含糊时补齐关键信息，不能凭图名猜测统计方法，也不能补造测量值。<br>
**Check the scientific meaning first.** Confirm experimental units, groups, pairing, comparison direction, transformations, and coordinates. Resolve important ambiguities rather than guessing statistical tests or inventing measurements.

**按实际成图检查。** 统一字体和最终尺寸，为标签和图例留出空间，核对文字遮挡、裁切、颜色语义和必要注释。修图后重新检查当前输出；代码运行成功不等于版式通过。<br>
**Review the rendered figure.** Check fonts and final dimensions, reserve space for labels and legends, and inspect overlap, clipping, color semantics, and annotations. Recheck revised outputs; successful execution alone does not establish visual quality.

**保留可复现材料。** 交付绘图代码、所用数据及必要环境信息。案例记录保存包用法、布局方法和已知问题，便于更换数据后重新编码和调整。<br>
**Keep the work reproducible.** Deliver plotting code, data, and essential environment information. Method records retain package usage, layout decisions, and known problems to support new datasets.

## 安装与使用 / Installation and use

将完整的 `biofigure` 文件夹放入项目的 `.agents/skills/`，或个人 `~/.agents/skills/`。保留脚本、配置和参考文件，不能只复制入口文档。在支持 Skills 的 Codex 中调用；[VS Code 使用说明](biofigure/references/vscode-execution.md)包含扩展和路径说明。<br>
Place the complete `biofigure` folder in the project’s `.agents/skills/` directory or your personal `~/.agents/skills/` directory. Keep its scripts, configuration, and references. Invoke it in a Codex environment that supports Skills; see the [VS Code instructions](biofigure/references/vscode-execution.md) for paths and extension details.

```bash
python3 -m pip install -r biofigure/requirements.txt
```

R 包按图型安装，无需一次安装所有依赖。提供数据、研究目的和期望的图型，例如：<br>
Install R packages as needed for the selected plot. Provide the data, research question, and intended figure, for example:

```text
$biofigure 读取 expression.csv 和 metadata.csv，画分组表达热图。
样本顺序按元数据，标注处理与时间，先检查数据，再绘图并检查文字与图例。

$biofigure 用 differential.csv 画火山图，横轴 log2FC，纵轴 -log10(padj)。
比较方向为处理组相对对照组，标注指定基因，输出 PNG 和 PDF。

$biofigure Read expression.csv and metadata.csv and draw a grouped expression heatmap.
Preserve metadata sample order, annotate treatment and time, and review labels and legends.

$biofigure Draw a volcano plot from differential.csv using log2FC and -log10(padj).
The comparison is treatment versus control. Label the specified genes; export PNG and PDF.
```

更完整的设计与导出说明见[中文手册](docs/HANDBOOK.zh-CN.md)和[英文手册](docs/HANDBOOK.en.md)。<br>
See the [Chinese handbook](docs/HANDBOOK.zh-CN.md) and [English handbook](docs/HANDBOOK.en.md) for design and export details.

## 验证与适用边界 / Validation and scope

方法覆盖不等于每个案例都已通过验收。仓库分别记录来源复现、独立迁移和压力测试；当前全量 V2 benchmark 尚未完成。自动检查主要验证规则、文件和运行证据，最终图仍须审阅。[查看验收规则](biofigure/references/benchmark-protocol.md)与[审计记录](docs/release-audit-3.5.1.json)。<br>
Method coverage does not mean every case has passed validation. Source reproduction, independent transfer, and stress tests are tracked separately; the full V2 benchmark remains incomplete. Automated checks assess rules, files, and execution evidence, while figures still require visual review. See the [protocol](biofigure/references/benchmark-protocol.md) and [audit](docs/release-audit-3.5.1.json).

Skill 不改变模型参数，也不能保证不同模型与推理档位得到相同结果。其作用是提供明确的方法、约束和检查流程。<br>
The Skill does not change model weights or guarantee identical results across models and reasoning settings. It provides methods, constraints, and checks for the actual workflow.

## 版本与历史 / Versions and history

- [Releases：下载已命名版本 / Download versions](https://github.com/Woyekun-cell/BioFigure/releases)
- [v3.5.1 更新记录 / Release notes](docs/RELEASE-NOTES-3.5.1.md) · [v3.5.0 更新记录 / Release notes](docs/RELEASE-NOTES-3.5.0.md)
- [完整提交历史 / Commit history](https://github.com/Woyekun-cell/BioFigure/commits/main/)：查看每次修改和当时的文件。 / Browse changes and earlier files.

`main` 是当前代码；版本标签固定在对应提交上，便于下载和对照旧版本。<br>
`main` contains the current code. Version tags remain attached to their release commits so older versions can be downloaded and compared.

## 来源与反馈 / Sources and feedback

方法来源见[设计来源](docs/DESIGN-SOURCES.md)和[来源声明](NOTICE.md)。本图廊展示自行生成的图件，模拟数据、公开数据与软件包示例逐图标注；不上传第三方参考原图、网页或抓取代码。<br>
See [design sources](docs/DESIGN-SOURCES.md) and [NOTICE](NOTICE.md) for provenance. The gallery contains independently generated figures with per-figure data-origin labels; third-party reference images, webpages and scraped code are not included.

绘图需求、参考案例和审美建议欢迎发到 [Discussions](https://github.com/Woyekun-cell/BioFigure/discussions)。可复现的问题请提交 [Issue](https://github.com/Woyekun-cell/BioFigure/issues/new/choose)，附数据结构、代码、包版本和成图；贡献方式见[贡献指南](CONTRIBUTING.md)。
<br>
Use [Discussions](https://github.com/Woyekun-cell/BioFigure/discussions) for figure ideas, references, and design feedback. Report reproducible issues through [Issues](https://github.com/Woyekun-cell/BioFigure/issues/new/choose), including data structure, code, package versions, and the output. See the [contribution guide](CONTRIBUTING.md).