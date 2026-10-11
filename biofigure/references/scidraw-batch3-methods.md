# SciDraw 014/017/027/031/082/085/089/096/135/149 代码学习笔记

本批从全库覆盖表中选取无绑定复现证据的 10 个 ID。图形与代码来自本机 SciDraw 分类库；输出使用固定随机种子模拟数据，数值不能与原图数据等同。方法只记录能从源码核验的部分。

| ID | 源码方法合同 | 本次实现与差异 |
|---|---|---|
| 014 | `corrplot(method='square', type='upper', order='original')`；显著性 `insig='blank'`；变量颜色标签和侧边分组条另由 grid/ggplot 组合。 | `ggplot2` 上三角模拟相关矩阵；缺显著性检验、侧边分类条与完整变量布局，未达复现。 |
| 017 | `ComplexHeatmap` 自定义三角分组矩阵；上/下三角代表两组、共享颜色映射；行列分组注释、边界和标签按组排列。 | `ComplexHeatmap` 共享色标与分组切片；当前切片/注释和图中实际关系未充分复原，未达复现。 |
| 027 | Python `plot_corr_matrix`：N×N 矩阵；下三角二维核密度；对角分布；上三角相关数值色块；共享色条。 | 用 `GGally::ggpairs` 自写 panel functions 复刻三角职责；源图有更细标签、变量描述和更多颜色刻度，结构相似但未达高保真。 |
| 031 | `linkET::qcorrplot` + `geom_square`；Mantel 分组连接以 `geom_couple` 绘制，显著性映射颜色，r 分档映射线宽，节点填色/尺寸独立。 | `linkET`、`geom_couple` 与相关矩阵；需再调源图的边缘节点和连线起终点，当前交叉遮挡明显，未达复现。 |
| 082 | `patchwork` 镜像两侧水平堆积条；左侧负向、右侧正向；中心共享类别轴；外加虚线框突出子区域。 | `ggplot2` facet 镜像条形近似，仍缺源图明确中心标签轴及虚线框位置，未达复现。 |
| 085 | 四个独立时间序列 `ggplot` 水平拼接；每面板均值线宽约 0.7、同色半透明 SD ribbon、面板各自 y 范围；拼接时统一轴文字尺度。 | `patchwork` 四面板和 ribbon 已实现；模拟信号、标签及原图线形数据不同，属于结构复现。 |
| 089 | `sf`/`rnaturalearth` 底图、`scatterpie` 地点组成饼；半径按 `5*log10(N)`；海色、地点分类色、单独半径图例。 | 世界轮廓和 scatterpie 已出；投影、真实地点、海域边界/图例精细布局与源图不同，未达复现。 |
| 096 | 源 Python 使用 statsmodels 单因素 ANOVA + Tukey；分组柱宽 0.4、重复观测 jitter 点、SEM、黑色描边/间隔、显著性星号。 | 为本机 Python 缺少 pandas/matplotlib/scipy/statsmodels，采用 R `aov`/`TukeyHSD` 做同类分析与绘图；本次未映射显著性星号，非语言级复刻。 |
| 135 | `ggplot2` 五组点径 4/alpha .8；全局二次虚线拟合宽 1；均值点形 18、双向 SD 误差线宽 .8；`ggh4x` 次刻度及内嵌图例。 | ggplot2 + ggh4x；输出设备比例下按比例缩小点线，均值误差线和图例可读，但模拟数据分布与位置仍有差异。 |
| 149 | `ggridges::geom_density_ridges_gradient` 蓝-白-绿密度；与负/正计数水平条按同一属名顺序对齐；`patchwork` 宽度比 3:2；中线 0.6。 | ggridges + patchwork 已实现大体左右对齐；源码中的属名顺序、数据量、计数分布和字体仍未完全恢复。 |

## 审核记录

- `results/full_library_audit/coverage.csv` 对这 10 个 ID 的先前状态均为 `no-bound-render-evidence`；选择时另剔除了曾经画过或属于已画图重复家族的备选。
- 首轮发现 135 SD 列取错并修复；149 分类计数未转数值而失败并修复；089 地图饼半径太小而调大；149 柱超出范围而减少模拟样本量；014 补为上三角。
- 仍有较大结构差距：014/017 的分组侧条与注释；031 的连线端点/分层和节点；082 中轴类别与框选区域；089 原始坐标/投影和尺寸图例；096 显著性比较展示。覆盖表状态必须保持 `needs_revision`，不可标 `mastered` 或高保真 PASS。
- 源码的 `geom_errorbarh()` 在当前 ggplot2 4.0+ 已弃用，后续应用 `geom_errorbar(orientation='y')`；149 仍报告少数计数条超出原图 x 限制而删除的 ggplot 行，应先确认数据合理后扩展范围或重设模拟数据，不能静默忽略。
- 暂未完成完整 PNG 最终尺寸人工检查和迁移测试；需要先处理上述差距再评估结构验收。
