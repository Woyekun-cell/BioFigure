<div align="center">

**中文 · [English](README.en.md)**

# BioFigure

**参考引导的生物科研图设计与质控 Skill**

[![BioFigure](https://img.shields.io/badge/BioFigure-3.7.1-28527A)](biofigure/SKILL.md)
[![R first](https://img.shields.io/badge/backend-R%20first-4F8F8A)](biofigure/renderer-registry.yaml)
[![Python compatible](https://img.shields.io/badge/Python-compatible-7D719B)](biofigure/renderer-registry.yaml)
[![License: MIT](https://img.shields.io/badge/license-MIT-C97864)](LICENSE)

[中文手册](docs/HANDBOOK.zh-CN.md) · [设计来源](docs/DESIGN-SOURCES.md) · [精选图廊](docs/GALLERY.md) · [版本下载](https://github.com/Woyekun-cell/BioFigure/releases) · [社区](https://github.com/Woyekun-cell/BioFigure/discussions)

</div>

BioFigure 面向多组学及生物医学研究中的图形表达，提供从数据结构检查、图型选择到 R/Python 编码、排版和成图审查的工作流程。它以 Skill 的形式供编码助手使用：结合研究问题和输入数据选择绘图方法，并保留可修改的代码与绘图数据。

R 是默认后端。矩阵注释、环形轨道、系统树、基因组坐标和多面板组合分别使用适合的专用包；AnnData、Scanpy 等原生数据对象也可沿用 Python 工作流。重点是保留图的科学含义，同时处理好文字、配色、图例和面板之间的关系。

## 适用领域与图型

| 研究领域 | 绘图任务 |
|---|---|
| 转录组、蛋白组 | 表达与差异热图、火山图、分组表达、富集结果、相关矩阵 |
| 代谢组与多组学整合 | PCA、丰度分布、跨组学关联、注释热图、关联网络 |
| 单细胞与空间组学 | 降维嵌入、标记基因气泡图、细胞组成、空间表达及分面比较 |
| 表观组与染色质 | ATAC/ChIP 信号曲线、信号热图、区域与基因组轨道 |
| 基因组与比较基因组 | 染色体与区间分布、共线性、环形连线、系统树及对齐注释 |
| 微生物与生态研究 | 群落组成、排序分析、系统树、丰度与环境关联 |
| 临床与实验生物学 | 生存曲线、森林图、患者泳道、时序响应、分组比较与模型评估 |
| 综合展示 | 多面板组合、图像实验板和证据注释 |

以上是方法与路由覆盖范围；具体任务取决于输入数据、包依赖和相应方法的验证状态。已有分析结果可直接用于绘图，缺少上游数据时不会声称完成了相应分析。

## 分类图廊

现有成图中精选 **14 类、79 张**。同一细分图型只展示一张代表图，去除重复配色、数据集及历史版本；点击分类查看。

数据来源包括模拟数据、公开数据和软件包示例，逐图标注。收录不等于原论文数据复现或完整验收。

| 图型分类 | 图数 |
|---|---:|
| [热图与矩阵注释](docs/gallery/heatmaps.md) | 7 |
| [分布、箱线与小提琴](docs/gallery/distributions.md) | 5 |
| [相关、散点与气泡矩阵](docs/gallery/correlations.md) | 6 |
| [组成、桑基与三元图](docs/gallery/composition.md) | 7 |
| [柱形、棒棒糖与花瓣图](docs/gallery/bars.md) | 6 |
| [雷达与多指标比较](docs/gallery/radar.md) | 2 |
| [差异表达、富集与曼哈顿图](docs/gallery/differential.md) | 6 |
| [降维、单细胞与空间](docs/gallery/embeddings.md) | 6 |
| [生存、森林与患者轨迹](docs/gallery/clinical.md) | 7 |
| [基因组、染色体与系统树](docs/gallery/genomes.md) | 11 |
| [网络与地图](docs/gallery/networks.md) | 6 |
| [时序、曲线与信号](docs/gallery/profiles.md) | 5 |
| [集合交叠与 UpSet](docs/gallery/intersections.md) | 2 |
| [机制、图像与多面板](docs/gallery/multipanel.md) | 3 |

[完整分类目录](docs/GALLERY.md) · [逐图清单与文件哈希](docs/gallery/catalog.csv)。复合图只归入一个主要类别，同类变体不重复展示。

## 绘图方法与质量检查

**按图型选择包。** 通用统计图采用 ggplot2，复杂矩阵注释采用 ComplexHeatmap，环形坐标采用 circlize，系统树采用 ggtree，基因组轨道与共线性采用 gggenomes，多面板采用 patchwork 或 cowplot。具体包和关键函数在编码前确定，避免用不合适的基础图层替代专用布局。

**先核对科学含义。** 检查实验单位、分组、配对关系、比较方向、数据变换及坐标。请求含糊时补齐关键信息，不能凭图名猜测统计方法，也不能补造测量值。

**按实际成图检查。** 统一字体和最终尺寸，为标签和图例留出空间，核对文字遮挡、裁切、颜色语义和必要注释。修图后重新检查当前输出；代码运行成功不等于版式通过。

**保留可复现材料。** 交付绘图代码、所用数据及必要环境信息。案例记录保存包用法、布局方法和已知问题，便于更换数据后重新编码和调整。

## 安装与使用

将完整的 `biofigure` 文件夹放入项目的 `.agents/skills/`，或个人 `~/.agents/skills/`。保留脚本、配置和参考文件，不能只复制入口文档。在支持 Skills 的 Codex 中调用；[VS Code 使用说明](biofigure/references/vscode-execution.md)包含扩展和路径说明。

```bash
python3 -m pip install -r biofigure/requirements.txt
```

R 包按图型安装，无需一次安装所有依赖。提供数据、研究目的和期望图型，例如：

```text
$biofigure 读取 expression.csv 和 metadata.csv，画分组表达热图。
样本顺序按元数据，标注处理与时间，先检查数据，再绘图并检查文字与图例。

$biofigure 用 differential.csv 画火山图，横轴 log2FC，纵轴 -log10(padj)。
比较方向为处理组相对对照组，标注指定基因，输出 PNG 和 PDF。
```

更完整的设计与导出说明见[中文手册](docs/HANDBOOK.zh-CN.md)。

## 验证与适用边界

方法覆盖不等于每个案例都已通过验收。仓库分别记录来源复现、独立迁移和压力测试；当前全量 V2 benchmark 尚未完成。自动检查主要验证规则、文件和运行证据，最终图仍须审阅。[查看验收规则](biofigure/references/benchmark-protocol.md)与[审计记录](docs/release-audit-3.5.1.json)。

3.7.1 新增 6 个作者处理数据的复杂图重绘案例，并替换 2 个模拟示例：BUSCO 锚定区域、跨基因组路径、通路双矩阵、证据网络、Micro-C 接触矩阵与环标记、单倍型比对、桑基图和多事件 OncoPrint。当前输入已逐图核对代码、数据、配色、版式和实际 PDF；学习要点见[基因组案例索引](biofigure/references/genomics-source-gallery-learning-20261011.md)。

公开包包含自有适配脚本、绘图表、PDF、可执行配置和逐案例来源记录；[公开重绘入口](biofigure/examples/genomics-gallery-20261011/README.md)每次使用新目录与新的准备、CP2 和授权，OHCA 按固定 URL 和校验值另取处理 RDS。原作者代码、原图、原始 R 对象及本地完整验收档案未随仓库发布。此次通过的是当前输入的限定范围验收；原论文整幅图的高保真资格、新数据迁移及全量 V2 验证仍分别记录。

公开文件检查：`python3 tools/audit_public_release.py`；图库文档检查：`python3 tools/build_gallery.py --check`。[本次文件与替换清单](docs/gallery/refresh-20261011.json)保留 SHA256。两项检查验证公开包的一致性，不代替科学复现与视觉审阅。

8 个公开入口已在新目录完成原生 R 复跑，重新验证 CP2 与一次性授权，并实际检查新 PNG 和 96/120 dpi PDF 预览。绘图表与封存版本哈希一致，新 PNG 与图库字节一致；[本次运行记录](docs/gallery/runtime-validation-20261011.json)记录环境、文件绑定与限定范围结果。127 项相关功能检查和 21 项公开包测试通过；完整历史测试因未随公开包发布的来源与全量证据仍未全通过，不升级全量 V2 资格。

Skill 不改变模型参数，也不能保证不同模型与推理档位得到相同结果。其作用是提供明确的方法、约束和检查流程。

## 版本与历史

- [Releases：下载已命名版本](https://github.com/Woyekun-cell/BioFigure/releases)
- [v3.7.1：本次更新](https://github.com/Woyekun-cell/BioFigure/tree/v3.7.1) · [更新前快照](https://github.com/Woyekun-cell/BioFigure/tree/snapshot-20261011-pre-gallery-refresh)
- [v3.5.1 更新记录](docs/RELEASE-NOTES-3.5.1.md) · [v3.5.0 更新记录](docs/RELEASE-NOTES-3.5.0.md)
- [完整提交历史](https://github.com/Woyekun-cell/BioFigure/commits/main/)：查看每次修改和当时的文件。

`main` 是当前代码；版本标签固定在对应提交上，便于下载和对照旧版本。

## 来源与反馈

方法来源见[设计来源](docs/DESIGN-SOURCES.md)和[来源声明](NOTICE.md)。本图廊展示自行生成的图件，模拟数据、公开数据与软件包示例逐图标注；不上传第三方参考原图、网页或抓取代码。

绘图需求、参考案例和审美建议欢迎发到 [Discussions](https://github.com/Woyekun-cell/BioFigure/discussions)。可复现的问题请提交 [Issue](https://github.com/Woyekun-cell/BioFigure/issues/new/choose)，附数据结构、代码、包版本和成图；贡献方式见[贡献指南](CONTRIBUTING.md)。
