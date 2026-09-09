# 单细胞与空间图

机器字段：问题、输入、实验单位、尺度/变换、统计、视觉通道、失败条件、QA、导出。

- 硬边界：生物样本是推断单位；细胞不是独立重复。

保留assay/layer、归一化、embedding名称、细胞集合、样本映射和版本。生物样本是推断单位，细胞数仅是描述性分辨率；不得把细胞当生物学重复。

10x 矩阵首轮必须记录 chemistry、feature/barcode/matrix 规模、过滤阈值、保留/删除数量、线粒体规则、归一化、变量基因数、PCA/UMAP 参数、聚类参数和随机种子。没有样本标签时不得伪造 condition；没有参考映射时 cluster 只能叫 cluster，marker 只能作候选证据。

Renderer：Seurat对象优先R后自定义ggplot；AnnData/Scanpy对象可Python，沿用已认可embedding，不为美观重算。Scanpy默认主题不得直接交付：显式设置Helvetica/Arial、#FFFFFF、figure size、legend_loc、frameon、palette、alpha、点径和坐标范围。

UMAP/FeaturePlot/空间图先固定data bbox与legend bbox。稀有群体通过绘制顺序、形状或直接标签保护；标签使用避让并在渲染后测bbox。不同gene独立缩放时不得比较绝对颜色。

DotPlot定义点面积、填色、阳性阈值、每组细胞数和样本数；缺失组合与零分开。气泡使用填充圆和固定近黑细描边，R 优先 `shape=21`、`fill` 映射连续值、`colour="#1A1A1A"`、`stroke=0.2–0.35`，按最终尺寸检查，不能让边框吞没小点。violin/比例图保留每样本摘要和分母。空间图记录坐标、原点、scale factor与切片，不拉伸组织适应版面。

QC 图用过滤前的完整细胞集合直接画出阈值线，并用保留/删除编码让读者看见过滤影响；若另画过滤后摘要，必须分成独立图。UMAP 保持坐标比例。每张单图独立导出，先检查白底、图例 bbox、标签和默认主题是否被覆盖；Seurat 优先 R，缺包时可用 Matrix+uwot，但必须写明未创建 Seurat 对象及统计边界。

单图无总标题/panel letter/重复图例；首轮实际PNG必须无重叠、裁切、乱码和默认字体回退。
