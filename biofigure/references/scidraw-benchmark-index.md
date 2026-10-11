# SciDraw Benchmark 索引

稳定包：`benchmark/library/scidraw/`。`sources/` 存已选原图，`scripts/` 存独立实现，`plot_data/` 存绘图输入，`figures/` 存终图，`evidence/` 与 `metadata/` 存来源和审查证据。

## 已学习案例

- 首组 2 图：径向堆积/连接结构与统计组合；来源图缺口保留在 metadata，不提升为完整复现。
- 六图：PCoA+边际分布、三元细胞状态、相关热图、泳道图、弦图外轨、火山+GSEA。六张选定来源图已从候选缓存晋升到 `sources/`。
- 第二批 20 图：5 类雷达、5 类雨云/小提琴、残差与相关矩阵、聚类热图、气泡、多元回归、Mantel 网络、两类密度图；逐案状态见 [第二批学习](scidraw-batch20-learning.md)。
- 另有两批统计/结构十例：见 `scidraw-stats-ten.md`、`scidraw-batch2-structures.md` 与对应 atlas JSON；尚未完成用户终审时保持 `source-exposed`。

## 迁移规则

先匹配数据合同、专用包和 panel topology，再迁移布局。雷达、弦图、圆热图、树外轨、Mantel 网络、双轴、边际分布不得用外观相似的通用几何替代。图例、显著性、数值列、标签和注释带均是结构对象，位置错误即 `REVISE`。
