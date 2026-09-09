# Gallery examples / 画廊示例

The examples use simulated data and fixed seeds. They are visual and execution demonstrations, not biological results. / 示例使用模拟数据和固定随机种子，只展示绘图与执行效果，不代表生物学结果。

## Core / 核心图型

```bash
Rscript --vanilla biofigure/examples/gallery/generate_core_gallery.R docs/assets/gallery
```

Produces / 生成：square expression heatmap、volcano plot、single-cell marker dot plot。The script requires a real Arial file and treats warnings as errors. / 脚本要求真实 Arial 字体，并把 warning 视为错误。

## Advanced / 复杂图型

```bash
Rscript --vanilla biofigure/examples/gallery/generate_advanced_gallery.R /tmp/biofigure-gallery
```

Produces / 生成：fan phylogeny with aligned tracks、raincloud plot with adjusted tests、five-axis radar profile。It also saves the simulated inputs and statistical tables. / 同时保存模拟输入和统计表。

Package requirements / 包依赖：`ape`, `ggplot2`, `ggrepel`, `ComplexHeatmap`, `circlize`, `grid`, `ragg`, `svglite`, `systemfonts`。

