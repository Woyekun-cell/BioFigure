# Wahle 视网膜类器官：多模态绘图技法

来源：[Nature Biotechnology 论文](https://doi.org/10.1038/s41587-023-01747-2)与[作者固定版代码](https://github.com/quadbio/spatial_multimodal_retinal_organoid/tree/da0989865ad2c3aef0c8a9d40f226f4327ea0b73)。清单中的此条代码链接误指向上一篇；以论文 Code availability 的仓库为准。详细映射见 `../benchmark/library/single-cell/wahle-retinal/data/metadata/figure-code-map.json`。本案仅源码学习，未重跑原始数据或复现图。

## 版式、配色与代码

- 【原图观察】Fig.2 从定位示意、彩色窗口网络、拟时序密度到同轴堆叠的内外层强度热图，按流程纵排；Fig.3/4 各自固定嵌入坐标，再换类别、时间和特征着色；Fig.4/6 的二维密度图沿统一“内—外×拟时序”坐标做小多图。Fig.5 按 13/32 周行对齐空间点图，再接测量—转移比较图。多图只共享同一变量的尺度，不混用表达、开放性和细胞比例色标。
- 【原图观察】时间点从紫、青、黄绿、黄、橙到深红渐进；细胞类别在 Fig.3/4/6 中稳定映射；表达嵌入图为青蓝、开放性为粉紫，空间强度图以深紫—橙—黄增强。准确 HEX 与最终组图程序未在仓库找到；这些是视觉语法，不作为作者代码参数。
- 【源码证实】`image_processing_pipeline/modules.py:793-884` 用 `numpy` 种子 5 生成 MTU 类别色，`seaborn.clustermap` 以逐标记 z-score、0 为中心的反转 `RdBu` 绘 QC 热图；调低列树高度、缩窄行树、色条贴齐热图，簇标签框与组织图复用同一类别色；`matplotlib` 按图像像素比例输出透明 PDF。这套色带**不是**论文 Fig.2e 的紫黄轨迹热图，不能直接照搬。
- 【源码证实】`laminator_analysis/utils.R:29-68` 按样本/年龄校正后逐标记缩放至 0–1；`retina_dev_laminar_windows/04_distances_by_feature.R:11-37` 用 `FBN` 平滑、下采样，`TSdist` 求 Fourier 距离；`06_pseudo_time_analysis.R:1-62` 用 `destiny` 扩散图/DPT 和 `umap`，固定随机种子 42。`integration_4i_sc_rna_atac/utils.R:11-84` 用 Seurat/Signac/Harmony 的 CCA、UMAP 和 `TransferData` 给空间核赋类；`ext/matching.py` 用 SciPy/NetworkX 求配对。4i 图像上色前处理还用 scikit-image、SimpleITK、Cellpose；它们是数据处理包，不是发表图排版器。

| 数据输入 | 源码、原图 | 图形表达与处理边界 |
|---|---|---|
| 4i 分割图、53路蛋白信号、定向组织窗口 | `image_processing_pipeline/`、`laminator_analysis/`；Fig.2 | 先轮廓及内外轴，再窗口特征、距离、扩散轨迹；图上连接的是**组织窗口簇**，不是单细胞谱系。网络点大小为该时间点内窗口比例；热图纵轴为内外位置、横轴为拟时序。必须保存窗口筛选和根/方向。 |
| 不同细胞的 scRNA、scATAC，同细胞 multiome | `sc_rna_atac_analysis/`；Fig.3 | CCA 后于相容簇内用最小费用最大流匹配 RNA 与 ATAC，得到计算配对的 metacell；同细胞 multiome 单列标识。共用 UMAP 坐标可换标签，表达量与开放性各自标尺度。Pando 调控网络是推断，需区分 TF 表达、motif、靶基因和实测扰动。 |
| 4i 核坐标与测序 metacell | `integration_4i_sc_rna_atac/`；Fig.4 | 先按相近周龄整合，再向空间核转移标签。蛋白和位置是测量；RNA、ATAC 面板为映射或预测，图例和说明不得写成核内直接测得。内外轴与拟时序二维密度图保持统一方向。 |
| smFISH spot、Baysor 细胞、4i 核 | `smFISH/`；Fig.5 | spot图、分割、转移及跨模态一致性按层呈现；“n=窗口/细胞”不能替代类器官数。4i 与 smFISH 数据各自只有一次实验批次，比较按原文组织层级报告。 |
| OTX2 regulon 与 CROP-seq | Fig.6；仓库无完整 Pando/CROP-seq 入口 | 调控边、正负靶基因、差异模块、空间活性分别编码；不能把共表达网络直接称因果调控。未找到该图的端到端作者脚本，不标复现通过。 |

源码静态审计：48文件，26个R文件中3个有语法错误；其余语法通过也不证明可执行，原仓库缺原始输入、部分中间对象与环境锁。`params.yml` 列出的对齐参考周期17不在`cycles: 0–12`内，需按真实图像元数据核对。Fig.2窗口大小图注与Methods单位冲突，见审计；不自行选一个当真值。任何迁移先核对受试者/类器官/切片/窗口/细胞层级。
