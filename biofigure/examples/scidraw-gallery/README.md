# SciDraw 方法迁移图库

28 个案例均按本地持有的来源代码与公开文章图形结构独立重写。仓库只包含固定种子模拟数据生成代码和自生成 PNG，不包含公众号原始图片、原始研究数据或整段来源代码。

从本目录运行：

```bash
Rscript --vanilla scripts/scidraw_rcs_reproduction.R
Rscript --vanilla scripts/scidraw_ridge_bipolar_reproduction.R
Rscript --vanilla scripts/generate_six_scidraw.R
Rscript --vanilla scripts/generate_batch20.R
```

需要的核心包：`rms`、`survival`、`ggplot2`、`ggridges`、`patchwork`、`vegan`、`ggtern`、`corrplot`、`ggnewscale`、`circlize`、`ggrepel`、`fmsb`、`ggradar`、`gghalves`、`ggbeeswarm`、`ggdist`、`ggside`、`factoextra`、`pheatmap`、`GGally`、`linkET`、`ragg`、`systemfonts`、`jsonlite`。

输出位于 `results/figures/` 与 `results/plot_data/`。所有数值仅用于方法和视觉结构验证，不能解释为来源研究结果。
