# 作者案例卡：设计证据，不是风格图库

以下是可追溯入口；作者数据尚未在本环境完整运行。`Pattern ID` 是抽象范式，`Atlas ID` 是来源实例；许可和版本须再次核对。

|案例|Pattern ID|Atlas ID|提炼重点|边界|
|---|---|---|---|---|
|[ComplexHeatmap Heatmap](https://jokergoo.github.io/ComplexHeatmap-reference/book/a-single-heatmap.html)|MAT-EXPR-001|ATLAS-CHM-001|矩阵、树、注释与图例分区|少量可读行；密集矩阵另走 DENSE|
|[ComplexHeatmap 多热图](https://jokergoo.github.io/ComplexHeatmap-reference/book/more-examples.html)|MAT-EXPR-DENSE-001|—|热图列表、统一行序、独立注释槽|最终尺寸仍须检查密度|
|[ComplexHeatmap OncoPrint](https://jokergoo.github.io/ComplexHeatmap-reference/book/oncoprint.html)|MAT-EXPR-001|—|离散事件与临床注释|不能迁移为连续表达色阶|
|[MOFA2 教程](https://biofam.github.io/MOFA2/tutorials.html)|MO-FACTOR-001|ATLAS-MO-001|因子、方差、载荷|因子不等于机制，方向可翻转|
|[deepTools plotHeatmap](https://deeptools.readthedocs.io/en/develop/content/tools/plotHeatmap.html)|CHR-HEAT-001|—|基因组信号分箱、排序与尺度|需声明参考区域与归一化|
|[Scanpy advanced plotting](https://scanpy.readthedocs.io/en/latest/tutorials/plotting/advanced.html)|SC-DOT-001|—|单细胞表达编码|细胞不是独立生物重复|

比较基因组、组成流与环图见[扩展案例](case-cards-genomics.md)。复用前提取 bbox、留白、字体、图例、排序和密度；来源不自动证明本地输出合格。公众号只作线索，须回溯论文、作者代码或官方文档。
