# Han 前肠单细胞：可迁移绘图技法

来源：[论文](https://doi.org/10.1038/s41467-020-17968-x)、[作者固定版源码](https://github.com/ZornLab/Single-cell-transcriptomics-reveals-a-signaling-roadmap-coordinating-endoderm-and-mesoderm-lineage/tree/49fdb8f126a53e7514068838c52b684436a82884)。本案只学习代码与数据合同，未复现原图；详见 `../benchmark/library/single-cell/han-foregut/data/metadata/code-audit.json`。

## 版式、配色与代码

- 【原图观察】Fig.3 用“上间充质、下内胚层”的平行两行，每行固定“轨迹网络→窄投票热图→三时点状态树”；Fig.5 的六通路横排、共用点大小/颜色图例，实线与灰虚线分连接等级；Fig.6 热图与组织切片、GSEA 小图相邻，标题色条标层级。仓库未见这些发表版总组图脚本，版式须另行实现并按原图核对。
- 【源码证实】`Seurat_Analysis_Scripts/Seuratv2.3.4_RunMultiCCA.r:231-253` 用 Seurat `DimPlot`/`VlnPlot`、`plot_grid` 并排诊断，`DimHeatmap`，再以 CCA 对齐后的 tSNE 成图；脚本未显式载入提供 `plot_grid` 的 cowplot，迁移时用 `cowplot::plot_grid`。`SPRING_Analysis_Scripts/SPRINGv1.0_Process_and_setup_SPRING_DIR.py:38-67` 借助 scikit-learn 在复杂阶段训练 40 PCs、投影全数据，再输出分组/自定义颜色数据，需固定细胞顺序与布局。
- 【源码证实】`MetaGene_Profile_Calculation/Seuratv3.0_MetaProfile_Dotplot.r:44-53` 先固定簇因子顺序，后 `Seurat::DotPlot(cols=c("green","red"), dot.scale=5) + RotatedAxis()`；点面积与颜色分别承载阳性比例、标准化强度。`PseudoSpaceOrdering_Analysis/PseudoSpaceDistribution_Using_URD.r:40-55` 用 URD/destiny 建拟时序并 `plotDists` 输出簇密度。`RShiny/app.R:319` 用 `ggcorrplot` 的蓝—白—橙发散色显示相关系数；ggplot2/plotly 用于绘制和交互导出。
- 【包边界】另有 `Monocle3_Pseudotime_Analysis/Monoclev3_TrajectoryAnalysis.r:59-86` 的 Monocle 轨迹绘图入口；不能据此断言论文 Fig.3 的最终网络由 Monocle 生成。上列代码给分析图与素材，未给发表版的热图、状态树和总排版生成器。
- 【颜色核对】`RunMultiCCA.r:226-227` 与 `RShiny/app.R:132` 的阶段颜色末两项顺序不同；原图 Fig.3 的阶段点色和投票热图是观察所得，仓库无最终热图/状态树调色与组图代码。复用时按标签显式定义颜色、锁同一比较组尺度，不能把任一数组当论文最终色值。`RShiny/app.R:154` 提供九类谱系色，仅用于该应用配置。

| 数据输入 | 作者代码与对应图 | 图形表达与处理边界 |
|---|---|---|
| 逐细胞计数、阶段及谱系标签 | Seurat 2.3.4 分时点聚类、MultiCCA；Fig.1c/e/f | UMAP/tSNE 需固定对象、坐标与细胞 ID；嵌入距离不等于空间距离。九个分时点脚本有语法错误，不能声称原仓库直接可运行。 |
| 各阶段前肠 DE/SM、已定前端簇 | URD 扩散图和 `plotDists`；Fig.1g/h | 画簇的拟空间密度，根簇和时点分别记录。作者示例 E8.5 DE 根为 a5；拟空间不是时间或直接测量的位置。Source Data 的该页仅嵌图，无逐细胞表。 |
| 后期细胞对前期簇的 KNN 投票 | `KNN_Classification.r`、汇总 Perl；Fig.3c–f | 先展示后期行、前期列的投票矩阵，再由最大票连实线、次高票大于首位 60% 连虚线。Perl 量是均值除前期簇大小乘 1000，行和不必为 100；与论文“% votes”文字不能混写。示例仅 E8.75 对 E8.5，不能冒充全图。 |
| 14545 个 DE/SM 细胞的配体、受体、响应基因集 | metagene Perl、Seurat DotPlot；Fig.5c/d/h/i、补图 | 基因先除以该基因在所有细胞中的最大值，再逐细胞求和、除以合计最大值；颜色为簇均值标准化，点面积为表达细胞比例。响应、配体、受体分别编码。Fig.5c 箭头另需邻近、阈值和方向证据；共表达只生成候选。随仓示例只有 18 个配体/受体 profile，缺响应 profile。 |
| HH/Gli 突变体 3 胚胎/基因型及单细胞簇 | 补表3、Fig.6e–g | 效应和 FDR 来自原表；Fig.6f 按行 min–max 缩放，不能误写 Z 分数。图注 FDR<0.05 与补表筛选 FDR<0.1 不一致，复用前逐项核对。 |

信号候选门槛：配体、受体、响应各需簇标准化值≥−1及≥25%阳性；Notch配体特例≥−1.5；配体加响应≥1记强信号。`SPRING` 在 E9.5 较复杂数据上拟合 40 PCs，再投射其他阶段；固定同一布局后才比较阶段或通路。TF 脚本 `FindAllMarkers` 给簇特异候选，不证明调控活性。单细胞是测量单位，不等于生物学重复；检验须返回胚胎/独立实验层级。例程验证与审计状态见案例 JSON，不得称整篇图已复现。
