# 统计规则来源

核对日期：2026-09-28；在线R-devel与包文档可能更新，具体分析记录本机版本。

- [R t.test](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/t.test.html)：Welch/配对、方向、区间。
- [R oneway.test](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/oneway.test.html)、[aov](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/aov.html)：单因素Welch、ANOVA及不平衡限制。
- [R wilcox.test](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/wilcox.test.html)：符号秩假设、估计量和精确/近似行为；不误称通用中位数检验。
- [emmeans交互分析](https://rvlenth.github.io/emmeans/articles/interactions.html)、[对比](https://rvlenth.github.io/emmeans/articles/comparisons.html)：条件估计、简单效应、交互对比与校正。
- [R p.adjust](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/p.adjust.html)：Holm、BH等校正与方法边界。
- [lme4奇异拟合](https://lme4.github.io/lme4/reference/isSingular.html)：随机效应与奇异模型风险。
- [R Kruskal–Wallis](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/kruskal.test.html)、[Friedman](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/friedman.test.html)、[TukeyHSD](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/TukeyHSD.html)：秩方法、完整区组和两两比较适用性。
- 本地nature-statistics：重复、交互误读和图注审查；academic-research-suite的设计/统计核验原则用于交叉检查，不复制其外部工作流或新增默认报告。

本模块为可审查的统计工作规则，不是期刊官方固定菜单。验证器只检查已声明计划和一致性；不能证明研究意向、原始数据真实性、残差假设或所有分析分支已实测。
