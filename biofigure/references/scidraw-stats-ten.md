# SciDraw 统计/分布图：第1批十例

逐图账本：`atlas/scidraw-learning-ten-20260925.json`；新代码：`scripts/learn_scidraw_ten.R`；模拟数据：`results/learning_validation/plot_data/`。除 095 使用R内置iris，其余模拟；均非原文数值复现。

|例|源码方法与结构|包职责/必须保留|
|---|---|---|
|095|3组原始点、均值柱、SE、Tukey三对比|`TukeyHSD`全组校正；括号逐对。|
|097|2条件×3基因型、断轴、四括号|`DescTools::PostHocTest(method="lsd")`；`ggbreak`断轴；ANOVA门控，按对照名称提取比较。|
|098|7变体×4处理，DMSO对照和竖排P|`DescTools::DunnettTest(control="DMSO")`，不能误作所有两两检验。|
|099|6时间块×3条件共18个堆积柱|逐重复归一；累计边界误差逐样本算；右图例留足槽位。|
|100|低/高B6双分面，每面7柱、三同位素|逐重复合计100%；预设M+1比较、分面内BH；分面标题需醒目。|
|115|4并排箱线图、独立渐变底和色条标题|`patchwork`拼版；图片为4箱线面板，归档代码呈3小提琴，错配不可抹去。|
|120|11组箱线+准随机点、长标签、四比较|`ggbeeswarm`避免规则蜂拥；检验与多重校正对应预设。|
|123|4配对箱线及个体虚线|连接与点共享ID偏移；按ID合并，不能依赖行顺序。|
|132|2×2气泡图、面积深度、站点色、下排零截距拟合|`ggpmisc::stat_poly_eq`公式仅放下排；图例收集后外置。|
|133|相关点、拟合带、标签及方向辅助轴|Pearson r保留符号、P由`cor.test`给出；`ggrepel`后仍需最终尺寸查碰撞。|

## 判定

本批逐图看源码/图像，重写并渲染PNG，属于 source-exposed 新实现，不是盲迁移。对照页：`results/learning_validation/figures/review-a.png`、`review-b.png`。审图发现097图例/断轴上下文、099图例拥挤、100分面标题、133标签密度等差异；当前状态 `needs-revision`、用户审图待定、高保真PASS=0。先修公共图例槽位、分面标题与标注避让，再逐图原尺寸复看。规则和方法笔记不是模型权重训练。
