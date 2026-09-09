# 示例图库 / Example gallery

全部示例使用模拟数据与固定随机种子，用于检查代码执行、字体、排版和视觉语法，不代表生物学结果。<br>
All examples use simulated data and fixed seeds to test execution, typography, layout, and visual grammar. They do not represent biological results.

## 核心图型 / Core figures

```bash
Rscript --vanilla biofigure/examples/gallery/generate_core_gallery.R docs/assets/gallery
```

生成方格表达热图、火山图和单细胞气泡图。脚本要求真实 Arial 字体，并把 warning 视为错误。<br>
Produces a square expression heatmap, volcano plot, and single-cell dot plot. The script requires a real Arial font and treats warnings as errors.

## 复杂统计图 / Advanced statistical figures

```bash
Rscript --vanilla biofigure/examples/gallery/generate_advanced_gallery.R /tmp/biofigure-advanced
```

生成系统树与对齐轨道、云雨图和雷达图，同时导出模拟输入与统计表。<br>
Produces a phylogeny with aligned tracks, raincloud plot, and radar profile, together with simulated inputs and statistical tables.

## 领域覆盖 / Domain coverage

```bash
Rscript --vanilla biofigure/examples/gallery/generate_domain_gallery.R /tmp/biofigure-domains
```

生成 12 张图：代谢组 PCA、跨组学关联、单细胞 UMAP、空间表达、染色质信号曲线与热图、结构变异 Circos、共线性、图像实验板、ROC/校准、机制图和多面板主图。<br>
Produces 12 figures: metabolomics PCA, cross-omics association, single-cell UMAP, spatial expression, chromatin profile and heatmap, structural-variation Circos, synteny, imaging assay plate, ROC/calibration, mechanism diagram, and a multi-panel main figure.

依赖包括 `ape`、`ggplot2`、`ggrepel`、`patchwork`、`ComplexHeatmap`、`circlize`、`grid`、`ragg`、`svglite`、`systemfonts` 和 `scales`。<br>
Dependencies include `ape`, `ggplot2`, `ggrepel`, `patchwork`, `ComplexHeatmap`, `circlize`, `grid`, `ragg`, `svglite`, `systemfonts`, and `scales`.
