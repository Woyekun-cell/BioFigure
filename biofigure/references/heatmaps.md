# 热图：离散与密集

先声明值：counts、TPM、VST、log强度、行Z-score、log2FC和相关系数不可混用。已处理值不默认再缩放；常量行、NA、截断和色阶中心必须记录。样本ID与metadata严格一一对应。

## 可读离散热图

通常5–200行。R/ComplexHeatmap优先。单格边长由最终尺寸决定；body宽高=格数×边长+gap。细白/黑边从0.2–0.4pt试画，最终 viewport 实测宽高误差≤1%。标签、树、注释和图例不计入格子尺寸，均有独立空间。

## 密集表达热图

超过200行或逐格在最终尺寸不可辨时使用 MAT-EXPR-DENSE-001。5000行保留全部数据，body栅格化，文字/树/注释矢量；按预先定义模块/聚类分片，隐藏大多数行名，只按规则标少量行。逐格描边会产生摩尔纹时禁用。若用户坚持每格正方形，只能超长图、按模块分块或“全量总览+局部细节”，必须说明物理冲突。

检索矩阵 Pattern 必传 `--rows` 与 `--columns`；规模超出卡片范围即从 eligibility 排除，不能只降排序。

共同规则：同一行集合联排只计算一次顺序；记录distance/linkage/seed/order。分类色带默认≤3 mm，名称用矩阵外图例；图例置于矩阵外；颜色参数化，同一颜色不兼任group与module。无总标题、panel letter或画布说明。依据：[ComplexHeatmap](https://jokergoo.github.io/ComplexHeatmap-reference/book/a-single-heatmap.html)。
