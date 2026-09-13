# method family 044 053

## 非单细胞源码驱动方法

- 星云密度图：核心层是`stat_density_2d(geom="raster", contour=FALSE)`，不是等高线多边形。黑底、`viridis`的`magma`连续色标、细白点、白色虚线边界和共享坐标双分面必须同时保留。点层只提示观测密度，不能遮住密度峰。
- 临床蜘蛛图：每条线绑定患者ID；不同分子亚组拆成等高面板并共享横纵范围、时间刻度与响应阈值。`patchwork`只负责拼接，不能改变患者轨迹或把纵轴范围分别缩放。
- 带注释泳道：`swimplot::swimmer_plot`生成随访长度，`swimmer_points`编码响应事件，`swimmer_arrows`编码持续随访；左侧临床注释条与泳道必须共享患者因子顺序。若来源同案还含瀑布图，只有泳道部分完成时必须标记`needs-revision`。
- 多变量相关矩阵：用`GGally::ggpairs`承担矩阵单元布局；对角线显示分组密度，下三角显示散点与拟合，上三角显示总体及分组相关。不得用单张相关热图替代这三种统计层。
- 断轴堆积柱：先按堆积顺序计算`cumsum(Mean)`，误差棒中心绑定累计高度；再用`ggbreak::scale_y_break`实现真实断轴。直接在各段均值上放误差棒或手工删除纵轴区间均失败。科学计数版本属于独立输出要求，未实现时不得把整案标为通过。
- Voronoi树图：用`WeightedTreemaps::voronoiTreemap`计算层级多边形、`drawTreemap`绘制；上层分组因子必须显式定序，否则调色板会错配语义。面积编码数值，颜色编码上层分组；矩形treemap不能代替圆形Voronoi布局。
- 决策曲线：用`dcurves::dca`从二分类或生存结局计算净获益。预计算概率列必须通过`as_probability`声明；输出须同时出现各模型、Treat All、Treat None，并共享阈值轴。只有默认策略线说明模型没有正确进入DCA，判失败。
- 复杂注释系统树：`ggtree`负责树与扇形布局；每类外环均由`ggtreeExtra::geom_fruit`生成，连续热图、分类条与堆积组成之间用`ggnewscale::new_scale_fill`隔离色标。树、所有轨道和元数据必须以tip label连接；只画彩色树尖不能代表复杂注释树。
- 聚类网络：先用`igraph`建图、去重、取主连通分量并计算群落，再用`graphlayouts`布局和`ggraph`绘制；群落间稀疏连接与群落内高密度必须在拓扑中真实存在。`ggforce::geom_mark_hull`只标示群落边界，不能用包络形状伪造聚类。来源群落数或边密度依赖缺失原始网络时，只能标记`needs-revision`。
