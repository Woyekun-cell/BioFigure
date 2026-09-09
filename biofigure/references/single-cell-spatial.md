# scRNA、scATAC、multiome 与空间数据

对象输入先检查使用的assay/layer、归一化、细胞元数据、样本ID、已有embedding与注释。沿用已认可坐标，不为图更分离重跑UMAP。降维距离不自动等于发育距离或时间；同一坐标多面板使用相同范围和细胞集合，抽样须说明。

DotPlot明确颜色均值来自所有细胞还是表达细胞、点面积代表比例还是数量、表达阈值和按基因缩放。FeaturePlot比较相同量时保持色阶；不同基因独立缩放须提示不可直接比较绝对表达。

细胞比例按生物学样本统计，保留分母；细胞不冒充独立生物学重复。条件差异与细胞类型marker不是同一问题；未授权不自动做pseudobulk或细胞级检验。

scATAC聚合轨道注明分组、细胞数、信号归一化；peak-to-gene和motif为对应分析证据，不能等同因果调控。RNA+ATAC确认同细胞测量还是跨样本整合。

空间图确认像素/物理坐标、原点、轴方向、缩放和组织图匹配；不拉伸组织以适应版面。不外传原始临床图像或元数据。

依据：[Signac作者教程](https://stuartlab.org/signac/)、[Scanpy高级绘图](https://scanpy.readthedocs.io/en/latest/tutorials/plotting/advanced.html)。具体API使用时核对对象版本。
