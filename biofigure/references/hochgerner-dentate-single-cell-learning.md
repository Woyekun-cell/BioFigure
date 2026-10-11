# Hochgerner 齿状回单细胞：绘图代码技法

来源：[Nature Neuroscience 论文](https://doi.org/10.1038/s41593-017-0056-2)、[作者固定版 MATLAB 源码](https://github.com/linnarsson-lab/DG_paper_public/tree/b0f7b531ec6d3a8fad3c705fa65ba9d6c8075887)。本案核对 Fig.1–6 与绘图脚本；只作静态学习，未运行数据、未复现发表图。文件和哈希见 `../library/single-cell/hochgerner-dentate/data/metadata/source-manifest.json`。

## 可迁移画法

- 【原图观察】Fig.1 把大热图、聚类色条、树状相关矩阵和类群 t-SNE 拼成不等宽面板；Fig.2/4 用“大网络主图＋热图/表达条＋同坐标基因小多图”；Fig.3 以年龄为列、探针为行，固定显微图裁切与标尺；Fig.6 是紧凑散点矩阵。发表版总组图代码未见，不把单图脚本说成完整复现。
- 【源码证实】`early_neurogenesis_KNN_genes_C1_data_v3.m:181-224,328-347` 先从相关矩阵取互为近邻的 KNN 边，算 Jaccard 距离；MATLAB `graph`/`plot(...,'layout','force')` 建一次坐标，再传固定 `xdata/ydata` 给每个基因图。基底是细灰边，节点以灰→红插值显示表达；固定坐标才能比较空间分布。该脚本的 `imagesc(...,[0,10])`＋`colormap('summer')` 生成绿→黄连接热图。
- 【源码证实】`late_neurogenesis_peak_genes_10xdata_v2.m:233-273` 先算簇内 `mean(log2(count+1))`、阳性比例及簇均值比值，再按每基因峰值簇、峰值强度排序；`imagesc`、`summer`、8 pt 标签、显式画布位置与 `export_fig` 输出窄高 PDF。迁移应保存排序索引与色阶范围，避免跨图误比。
- 【源码证实】`plot_C1_dendrogram_tsne_knnMCL_cluster_v4_correction.m:405-451` 用 `distinguishable_colors` 区分类群；年龄小多图用 `subplot(3,6,i)`，所有细胞灰底、当前年龄彩色点、关闭坐标轴；嵌入坐标保持一致。类别色需按标签锁定，不能依赖动态数组顺序。
- 【源码证实】`early_group_comparison_neurogenesis_merge_V1_V2_KNN_v2.m:716-752` 用 `tight_subplot(2,4,...)` 固定面板间距，`log2(count+1)` 对比和 Wilcoxon 秩和检验经 `qval_from_pval` 校正，底层灰/默认点、显著点绿、重点标签红，叠加实线对角及虚线偏移线。该脚本的红/绿与发表 Fig.6 的洋红/青绿外观不同，不能当最终色值。
- 【包与边界】主要是 MATLAB 图形、图论及统计函数；`distinguishable_colors`、`export_fig`、`freezeColors`、`tight_subplot`、`save2pdf` 等辅助函数被调用但未随仓提供。`early_neurogenesis_SCbarplots_10xdata_v4.m:265-290` 的 NavyBlue 柱用同色边；BioFigure 成图仍按本 Skill 的深色细描边默认规则。仓库缺原始输入及环境锁，本机无 MATLAB/Octave，不能宣称可运行或视觉 PASS。
