# Ma 灵长类前额叶：绘图技法

来源：[Science 论文](https://doi.org/10.1126/science.abo7257)、[PMC 全文及 Fig.1–6](https://pmc.ncbi.nlm.nih.gov/articles/PMC9614553/)、[作者源码固定版](https://github.com/sestanlab/Cross-species-PFC-snRNA-seq/tree/faf3ab5ce62822895263f54969e84cecff57053f)。来源与哈希见 `../library/single-cell/ma-primate-pfc/`。状态：`code-learned-static-audit`，未重跑数据或复现发表组图。

## 原图版式与色彩

- 【原图观察】Fig.1 用大型环形亚型图谱作视觉中心，叠分类、物种比例、标记基因点阵与树；Fig.2–5 把 UMAP、点阵/热图、流向与组织切片按问题组合；Fig.6 成对比较跨物种小提琴和组织切片。大片白底留给复杂多面板，主色用于类别，物种色跨面板固定。
- 【源码证实】`Overview/mf1.plot.v8.R:187-191` 与 `SourceFunctions/pfc.fun.R:826` 固定人 `#FF420E`、黑猩猩 `#4CB5F5`、恒河猴 `#89DA59`、狨猴 `#FFBB00`；图上其他亚型色需另从代码或输入注释核对。

## 图前处理、函数与可迁移范式

- `Overview/mf1.plot.v8.R:35-103,175-340` 从平均表达/表达率、细胞元数据和树对象确定同一亚型顺序；`circlize` 分轨绘制标签、类群、物种堆叠比例、基因点阵、亚型比例与树。点大小表示表达细胞比例，灰至红表示逐基因缩放的平均表达；两种量不能混写。环内图例在相应轨道内完成。代码只生成环形主体 PDF，不证明整张 Fig.1 拼版可一键复现。
- `SourceFunctions/exp.fun.R:125-214` 对表达矩阵逐行缩放、截断并与阳性比例合成长表；`ggplot2` 用 `shape=21` 的填色、描边与大小同时编码，按物种分面。`SourceFunctions/exp.fun.R:395-409` 另用 `ComplexHeatmap`、`circlize::colorRamp2` 和 `viridis` 处理连续热图；跨物种格子须锁同一行列顺序、色域与大小标尺。
- `InN/inn.fun.R:43-75` 先按指定类别顺序编码节点，再由 `ggsankey::make_long`、`geom_sankey` 绘层位到细胞亚型流向；`EvolutionPatterns/plot.sccoda.summary.R:76-97` 把比较结果制成多物种扇形点阵；密集 UMAP 脚本用 `ggrastr::rasterise(..., dpi=300)` 保留文字矢量。`ExN/plot.de.heat.ExN.R:154-180` 对物种×亚型矩阵按基因行缩放、截断后绘图。

## 边界

121 个 R 文件语法解析均通过；多数脚本仍依赖仓库外的 RDS、相对路径和自定义函数。`InN/plot.SST.cls.layer.sankey.R:48-55` 的 `cls_cols` 当前设为 `NA`，不能直接当成已完成的类别配色。静态代码审阅不验证统计结论、整版布局或最终印刷尺寸。
