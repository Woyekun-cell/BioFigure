# SciDraw方法族

分面热图、双曲线火山、RNA/翻译象限、细胞蜂群、三层OTU气泡图，以及散点饼图、参数恢复矩阵、对称双标尺热图、配对箱线图等拆图范式见 `references/scidraw-layout-recipes.md`；模拟验证不得继承原研究结果。

## 来源与通过门

- 来源代码只用于识别包、统计模型、几何层和布局；按当前数据另写脚本。缺原始数据时用固定种子模拟，只验证结构，不继承数值或结论。
- 装包和脚本成功不等于复现。来源图与最终PNG并排核对方向、主体比例、字号、轴范围、对齐、留白及遮挡后，才记`source-compared-png`。
- 离散调色板渲染前须断言长度覆盖全部水平且无`NA`；否则整组图元可能静默丢失。

## 专用方法

- RCS：生存结局用`rms::cph`、`rms::rcs`、`rms::Predict`；禁止`geom_smooth`冒充。
- 山脊：`ggridges::geom_density_ridges_gradient`；与双向柱共享因子顺序。
- PCoA：`vegan::vegdist`明确距离；散点与边缘箱图共享坐标。
- 三元：`ggtern`且三分量闭合；多时间点等宽分面并共享轴、颜色、形状。背景修改后复查三轴、刻度、网格；组别同时用颜色和形状。
- 相关：`corrplot`或`linkET`；矩阵、聚类和类别注释共用变量键。
- 泳道：`ggnewscale`分离治疗、响应和元数据标度；事件共用患者顺序与时间原点。
- 和弦：`circlize`；连接、扇区和外围轨共享边界，复现后`circos.clear()`。
- 火山：`ggrepel`，图例外置；最终尺寸检查标签、连线、阈值及点簇遮挡。模拟富集轨只称编码演示。

## 环图与开放扇形

- 环形热图用`circlize::circos.heatmap(split=...)`；矩阵、基因标签、q值轨和分区带共享顺序。中心UpSet用`ComplexHeatmap::UpSet`，Venn用`eulerr`真实集合；装饰圆不算复现。
- 半圆小提琴/扇形箱图用`coord_radial(start,end,inner.radius)`锁定开角；琴体/箱体、原始点、均值及外标共享分组顺序。闭合花环判为识别失败。
- 环状分组折线按`interaction(系列,领域)`分组，禁止跨空白扇区；外圈变量/显著性、断裂网格、内圈领域名共用特征顺序。

## 网络、关联环与系统树

- 网络加环柱/气泡：`tidygraph`建根—类别—末端三层键，`ggraph`按树布局；外围定量层须使用同一末端顺序。边色用`scale_edge_colour_manual`，节点色用`scale_colour_manual`，两者不能互代。柱长或气泡大小须映射数值，不得只画一圈装饰点。
- 关联环图：`circlize`按疾病等语义组建扇区，组内基因用共享局部坐标；棒棒糖、`circos.genomicLabels`和`circos.link`共用该坐标。不得按每个基因另起扇区后声称疾病分组复现；每次绘图前后清空circos状态。
- 系统树加轨道：用`ggtree`保存拓扑和分支组，用`ggtreeExtra::geom_fruit`按tip ID叠加独立轨；每条不同含义的填充尺度间用`ggnewscale::new_scale_fill()`。二元出现轨不得与分类色带混淆；外圈柱须映射真实系数及`orientation='y'`。缺原树和注释表时只能验证固定种子模拟结构，不报告来源物种或结果。
