<div align="center">

# BioFigure

**参考引导的生物科研图设计与质控 Skill**<br>
**A reference-guided design and quality-control skill for biological figures**

[![BioFigure](https://img.shields.io/badge/BioFigure-3.1-28527A)](biofigure/SKILL.md)
[![R first](https://img.shields.io/badge/backend-R%20first-4F8F8A)](biofigure/renderer-registry.yaml)
[![Python compatible](https://img.shields.io/badge/Python-compatible-7D719B)](biofigure/renderer-registry.yaml)
[![License: MIT](https://img.shields.io/badge/license-MIT-C97864)](LICENSE)

[中文手册](docs/HANDBOOK.zh-CN.md) · [English handbook](docs/HANDBOOK.en.md) · [设计来源](docs/DESIGN-SOURCES.md) · [示例代码](biofigure/examples/gallery) · [Community](https://github.com/Woyekun-cell/BioFigure/discussions)

</div>

BioFigure 在生物学问题与绘图代码之间建立可审查的设计链：先确认实体、样本、重复、尺度、统计和坐标，再检索视觉 Pattern，写入 Figure Design Spec，锁定 R 或 Python 后端，检查实际成图后交付。<br>
BioFigure builds an auditable design chain between a biological question and plotting code: it checks entities, samples, replicates, scales, statistics, and coordinates; retrieves a visual pattern; writes a Figure Design Spec; locks the R or Python backend; and inspects the rendered artifact before delivery.

R 是默认后端；AnnData、Scanpy 等原生工作流可使用 Python。同一张图的预览、导出和布局质控保持同一后端。单图优先生成，复合图在各面板通过检查后再装配。<br>
R is the default backend, while native workflows such as AnnData and Scanpy may use Python. Preview, export, and layout QA stay on one backend. Individual panels are prepared first and assembled only after each panel passes inspection.

## 示例图 / Gallery

下列 18 张图均由仓库中的 R 代码和固定随机种子生成，只展示图形语法、排版和质控边界，不承载生物学结论。<br>
The 18 figures below are generated from repository R code with fixed seeds. They demonstrate visual grammar, layout, and QA boundaries and carry no biological conclusions.

### 常规组学与多组学 / Bulk omics and multi-omics

| 方格表达热图 / Square expression heatmap | 火山图 / Volcano plot |
|---|---|
| ![Square expression heatmap](docs/assets/gallery/template-heatmap.png) | ![Volcano plot](docs/assets/gallery/template-volcano.png) |
| 代谢组 PCA / Metabolomics PCA | 跨组学关联 / Cross-omics association |
| ![Metabolomics PCA](docs/assets/gallery/domain-metabolomics-pca.png) | ![Cross-omics association](docs/assets/gallery/domain-multiomics-association.png) |
| 云雨图 / Raincloud plot | 雷达图 / Radar profile |
| ![Raincloud plot](docs/assets/gallery/template-raincloud.png) | ![Radar profile](docs/assets/gallery/template-radar.png) |

### 单细胞、空间与染色质 / Single-cell, spatial, and chromatin

| 单细胞气泡图 / Single-cell dot plot | 单细胞嵌入 / Single-cell embedding |
|---|---|
| ![Single-cell dot plot](docs/assets/gallery/template-single-cell-dotplot.png) | ![Single-cell embedding](docs/assets/gallery/domain-single-cell-umap.png) |
| 空间表达 / Spatial expression | 染色质信号曲线 / Chromatin profile |
| ![Spatial expression](docs/assets/gallery/domain-spatial-expression.png) | ![Chromatin profile](docs/assets/gallery/domain-chromatin-profile.png) |
| 染色质信号热图 / Chromatin heatmap |  |
| ![Chromatin heatmap](docs/assets/gallery/domain-chromatin-heatmap.png) |  |

### 基因组与比较基因组 / Genome and comparative genomics

| 系统树与对齐轨道 / Phylogeny with aligned tracks | 结构变异 Circos / Structural-variation Circos |
|---|---|
| ![Phylogeny with tracks](docs/assets/gallery/template-phylogeny-tracks.png) | ![Structural-variation Circos](docs/assets/gallery/domain-structural-variation.png) |
| 共线性 / Synteny |  |
| ![Synteny](docs/assets/gallery/domain-synteny.png) |  |

### 图像、模型与综合叙事 / Imaging, models, and integrated evidence

| 图像实验板 / Imaging assay plate | ROC 与校准 / ROC and calibration |
|---|---|
| ![Imaging assay plate](docs/assets/gallery/domain-imaging-assay.png) | ![ROC and calibration](docs/assets/gallery/domain-ml-evaluation.png) |
| 证据分级机制图 / Evidence-aware mechanism | 多面板证据链 / Multi-panel evidence chain |
| ![Evidence-aware mechanism](docs/assets/gallery/domain-mechanism.png) | ![Multi-panel evidence chain](docs/assets/gallery/domain-multipanel-evidence.png) |

## 使用 / Use

调用时可以只给出研究问题、数据路径和交付格式；BioFigure 会按生物领域、图的科学角色、数据结构与后端完成路由。比较方向、实验单位或配对关系无法可靠判断时才会询问。缺少真实测量值时，仅允许生成明确标记的模拟图或示意图。<br>
Provide a research question, data path, and delivery format. BioFigure routes by biological domain, scientific role, data topology, and backend. It asks when comparison direction, experimental unit, or pairing cannot be determined safely. Without measured values, it may create only clearly labelled simulations or schematics.

```text
$biofigure 用 R 读取 expression.tsv 和 metadata.tsv，绘制四组表达热图；
样本顺序按元数据，格子保持正方形，输出 PNG 和可编辑 SVG。

$biofigure Use R to read expression.tsv and metadata.tsv and draw a four-group
expression heatmap. Preserve metadata order, keep square cells, and export PNG and SVG.
```

```mermaid
flowchart LR
    A[科学问题<br/>Scientific question] --> B[数据与生物契约<br/>Data and biology contract]
    B --> C[领域与角色路由<br/>Domain and role routing]
    C --> D[Pattern 与证据检索<br/>Pattern and evidence retrieval]
    D --> E[Figure Design Spec]
    E --> F[锁定后端并渲染<br/>Locked renderer]
    F --> G[实际图件<br/>Rendered artifact]
    G --> H[看图与专项审查<br/>Visual and specialist review]
    H -->|REVISE| E
    H -->|PASS| I[可复现交付<br/>Reproducible delivery]
```

Pattern 保存可复用的视觉结构；Atlas 记录来源、适用边界与反例；Renderer 把 Design Spec 转成代码；Critics 检查科学语义、统计、排版和导出；Benchmark 用统一任务集衡量 Skill 的稳定性。<br>
Patterns store reusable visual structures; the Atlas records provenance, scope, and counterexamples; renderers turn the Design Spec into code; critics inspect scientific meaning, statistics, layout, and export; benchmarks measure stability across a common task set.

## 复现与验证 / Reproduction and validation

```bash
Rscript --vanilla biofigure/examples/gallery/generate_core_gallery.R docs/assets/gallery
Rscript --vanilla biofigure/examples/gallery/generate_advanced_gallery.R /tmp/biofigure-advanced
Rscript --vanilla biofigure/examples/gallery/generate_domain_gallery.R /tmp/biofigure-domains

python3 -m unittest discover -s biofigure/tests -p 'test_*.py'
Rscript --vanilla biofigure/tests/test_style.R
python3 biofigure/scripts/validate_pattern.py
python3 biofigure/scripts/validate_palette_library.py
```

测试通过代表结构、代码和已定义规则通过检查。投稿前仍需按目标尺寸查看实际图，并核对生物学解释、统计设计、图注与期刊要求。<br>
Passing tests confirms the defined structural, code, and rule checks. Before submission, inspect the actual figure at target size and verify biological interpretation, statistical design, legend text, and journal requirements.

## 开源与来源 / Open source and provenance

BioFigure 自有代码、文档与模拟图库采用 [MIT License](LICENSE)。外部软件包、论文、网页和链接资源遵循各自许可证；来源与设计依据见 [DESIGN-SOURCES.md](docs/DESIGN-SOURCES.md) 和 [NOTICE.md](NOTICE.md)。期刊名称仅用于描述设计目标，不表示期刊认可。<br>
BioFigure-owned code, documentation, and simulated gallery assets are released under the [MIT License](LICENSE). External packages, papers, websites, and linked resources retain their own licenses; provenance and design references are recorded in [DESIGN-SOURCES.md](docs/DESIGN-SOURCES.md) and [NOTICE.md](NOTICE.md). Journal names describe design targets and do not imply endorsement.

## 社区 / Community

欢迎在 [Discussions](https://github.com/Woyekun-cell/BioFigure/discussions) 分享绘图需求、参考案例、审美建议和使用经验。可复现的成图问题、功能需求与代码缺陷请使用 [Issues](https://github.com/Woyekun-cell/BioFigure/issues/new/choose)。提交前请阅读 [贡献指南](CONTRIBUTING.md)；请勿上传未公开数据、患者信息或受限材料。<br>
Use [Discussions](https://github.com/Woyekun-cell/BioFigure/discussions) for figure ideas, references, design feedback, and experience reports. Submit reproducible rendering problems, feature requests, and code defects through [Issues](https://github.com/Woyekun-cell/BioFigure/issues/new/choose). Read the [contribution guide](CONTRIBUTING.md) first, and never upload unpublished data, patient information, or restricted material.
