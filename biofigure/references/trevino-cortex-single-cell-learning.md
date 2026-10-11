# Trevino 皮层单细胞多组学：绘图技法

来源：[Cell 正式论文](https://doi.org/10.1016/j.cell.2021.07.039)、[作者提供的正式版 PDF](https://static1.squarespace.com/static/61e14b3ce0a8b6050be3b8fb/t/61e8204a6d642d234730d5a0/1642602603623/Trevino%2Bet%2Bal%2B2021_main%2Bsmall.pdf)、[作者固定版 R 源码](https://github.com/GreenleafLab/brainchromatin/tree/f8f509b5d811c9f0577f6c7c2ddbcb5ca8d68d14)。来源哈希见 `../library/single-cell/trevino-cortex/data/metadata/source-manifest.json`。只学画法；未下载大数据、未复现发表图。

## 版式与配色

- 【原图观察】Fig.1 把组织定位图、RNA/ATAC 成对嵌入、同一组基因的表达/基因活性/motif 活性和并排 DotPlot 按阅读顺序排开；Fig.2 将双 UMAP 与宽幅 CRE–基因热图并列，热图顶部有 RNA、ATAC、样本、拟时序色条。Fig.3/4 各自按拟时序排列热图列，同一图内的模态对齐；Fig.4–6 重复“灰底嵌入＋彩色模块/基因”小多图。颜色值不能仅凭 PDF 目测当作源码参数。
- 【源码证实】`R/Load_Environment.R:82-140` 从 `misc/colorpals.ai.csv` 读九套植物命名色板，RNA/ATAC 类别色从外部 `data_files/tsv/*_Colors.txt` 读取；时间色明确为 PCW16 `#D7496E`、PCW20 `#FAAD6C`、PCW21 `#D84C27`、PCW24 `#7E2B18`。类别色文件不在源码快照中，不能推定发表图的精确 HEX。

## 图前处理→函数→输出

- `R/Single_Cell_Functions.R:102-250` 的 `geneSetAveragePlot` 对基因名映射，逐基因、均值或加权均值显示，按需逐行缩放、分位截断，`facet_wrap` 做小多图；`ggplot2::scale_color_gradientn` 分配连续色，`ggrastr::geom_point_rast` 处理密集点。输入矩阵与嵌入坐标须另按 cell ID 核对。`plotAccessibility:294-332` 汇总 peak 可及性，可选背景峰归一化；`plotChromVAR:349-380` 单独显示 motif deviation Z 分数并用 `geom_blank` 扩展双侧色阶。三模态应保留各自单位和色标。
- `R/FCM_Workflows.R:128-237` 先用 `cleanMatrix` 做截尾/缩放，再按类别及拟时序排列 pseudobulk 列；`ComplexHeatmap::Heatmap` 与 `HeatmapAnnotation` 对齐类别、年龄、拟时序，`circlize::colorRamp2` 配注释色，`use_raster=TRUE` 降低大热图体积，固定 PDF 宽高。`R/Single_Cell_Functions.R:465-530` 还对 linked peaks 用 `lowess` 平滑、峰值位置排序、逐行缩放，并加 genomic class 注释；这些是可迁移的热图前处理，未证实直接生成 Fig.2/3 的发表版组图。
- 【关键包】绘图：`ggplot2`、`ComplexHeatmap`、`circlize`、`ggrastr`、`ggrepel`；配色：`viridis`、`RColorBrewer`、`wesanderson`、自带 CSV；`patchwork` 已载入但本仓未见最终组图语句。数据对象：`SingleCellExperiment`、`Seurat`、`URD`。`R/FCM_Functions.R:137-174` 给连续 membership 与二值阈值热图共用列序的示例。
- 【Fig.7 边界】原图把序列贡献 logo、预测信号与多类细胞 ATAC 轨道纵向对齐。作者另有 [Brain_ASD 固定版](https://github.com/GreenleafLab/Brain_ASD/tree/83664b38b528e10e91ebcdd4551ab329cc8b90c7)；其中 `PyFiles/plot_interpretation.py:27-46` 用 `pyBigWig` 读贡献分数、`pysam` 取序列、`concise.utils.plot.seqlogo_fig` 绘序列 logo，再由 Matplotlib 输出。未见完整 Fig.7 轨道组图脚本；该脚本 `maxthresh` 分支用 `max()`，迁移前须核查上限截断意图。

## 迁移门槛

五个 R 脚本均可解析，但依赖未下载的 `data_files`，仓库 README 称数据合计超过 10 GB。当前 R 4.6.1 将色板 CSV 的 `palette.name` 读成字符，`Load_Environment.R:83-105` 却用 `levels()`，会得到空色板；迁移时改为显式 `factor()` 或 `unique()` 并锁标签顺序。`FCM_Workflows.R:214` 的 `genes.order` 与上文 `gene.order` 不一致。无环境锁及发表版面板组图文件；不标视觉 PASS。
