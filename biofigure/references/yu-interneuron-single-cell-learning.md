# Yu 胎脑中间神经元：绘图技法

来源：[Nature Neuroscience 论文](https://doi.org/10.1038/s41593-021-00940-3)、[作者源码固定版](https://github.com/yuanbell/Single-cell-sequencing-of-subpallium/tree/5562c65831bb155ca3b49b7cc8ffa4abbbe72a3b)。Fig.1–7 原图、10 个 R 脚本、逐文件哈希见 `../library/single-cell/yu-interneuron/`。状态：`code-learned-static-audit`；未重跑数据，未复现发表组图。

## 原图版式与色彩

- 【原图观察】Fig.1 用大 t-SNE 和轨迹图作主轴，旁列基因小多图与连接热图；Fig.2 把胎龄分栏，下方按基因行排列小提琴图；Fig.3–6 穿插灰底组织切片和彩色原位点位、相同区域的放大视图及尺度尺；Fig.7 并列两个年龄的流向图，旁置细胞组成饼图。类别色跨嵌入、轨迹、流向维持一致，连续表达另用渐变。图面观察不等于代码逐面板复现。

## 图前处理、函数与可迁移范式

- 【源码证实】`R/progenitor_analysis.r:68-86` 从 Seurat 归一化表达矩阵按基因取值，转置后与细胞类别合并，再 `melt` 为长表；`ggplot2::geom_violin(scale='width')` 与 `facet_wrap(~variable, ncol=1, scales='free_y')` 形成基因行，`scale_fill_manual` 给类别色。对多年龄图，应锁定类别与色值，并明确每行独立纵轴。
- `R/MGE_GW09_GW11.r:164-227` 以 `Seurat::DimPlot` 显示 t-SNE，`pheatmap` 对平均表达逐行标准化，用蓝绿 `#3da4ab`、米白 `#fcf9ea`、珊瑚 `#fe8a71` 热图；`destiny` 扩散坐标加 `slingshot` 谱系曲线，逐基因用 `geom_smooth(method='loess', span=0.75)` 画两条拟时序。热图、轨迹和曲线是不同量纲，不共用色标。
- `R/Mapped_analysis.r:257-281` 先对细胞类别与映射类别做交叉表，按映射类别算比例，再用 `ggalluvial::geom_alluvium`、`geom_stratum`、`geom_text` 画 Fig.7 流向；流带透明度 0.7、节点黑描边。流带高度映射 `Count`，所算 `Fraction` 未映射到高度；迁移时须标清“数量”或“比例”。

## 边界

10 个 R 文件语法解析均通过。仓库还含 ISS 数据，但未见把原位测序点位、组织图像和全篇面板装配成发表 Fig.3–7 的完整脚本；不把该部分记为源码复现。脚本使用未随快照保存的 RDS/CSV，`Mapped_analysis.r:281` 输出目录拼为 `~/resulst/`；直接运行前须修正路径、补数据、核对包版本。
