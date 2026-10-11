# Awesome Scientific Figure 候选学习层

来源：[项目目录固定版本](https://github.com/nehSgnaiL/awesome-scientific-figure/tree/8632aa34fcc1b0b2c3f66a7b1ddd4c0e587a25a8)。`atlas/awesome-scientific-figure-visual-study.json` 记录 29 个图位的来源哈希、尺寸、面板结构、配色作用和实现假设；8 张原尺寸联系表均已复看，12 种版式各选 1 张单独查看。`atlas/awesome-scientific-figure-layout-recipes.json` 将它们归并为 12 种布局合同，避免同类重复堆积。原论文图注、Source Data、作者代码和素材许可仍未逐项核验；布局学习不等于原数据复现。

学习到的可复用规律：地图与统计面板先定主次和空间比例；小多图锁定坐标范围、分类顺序和色标；跨面板重复的类别保持同色；连续量用顺序色阶、有正负方向的量以零为中心用发散色阶；点大小按面积编码并单独给图例；复合图先分配行列和图例空间，再画细节。合集多数来自地图、人口流动与交通研究，所以这里只迁移版式与视觉编码，生物学解释、统计方法和实验单位必须由当前数据与原始论文独立确认。具体 12 类规则及输入要求见 layout recipe JSON。

用 `python3 scripts/retrieve_awesome_figures.py --pattern two-panel-bubble-fit` 查布局合同，或用 `--domain imaging-assay --task 'antibody comparison'` 查科学任务候选。返回的 `verified_reference_evidence_gap` 恒为 `true`。编码先用合同确定面板数、输入单位、颜色语义和首图检查，再写绘图层；原图的色值列表和图像均不收入 BioFigure。

`examples/awesome-layout-prototypes/render.R` 有三个固定种子模拟的可运行结构样例：时序曲线＋气泡轨、纵向组间比较、双面板气泡拟合。已渲染并目检预览，但它们不是论文数据复现，也未通过参考忠实度/迁移/压力测试。

后续仍须逐图核原论文与实验单位、数据/代码/许可，再分别做原图复现、换数据迁移和压力测试；通过前留在视觉方法候选层。详见 `docs/superpowers/plans/2026-09-23-awesome-scientific-figure-learning.md`。
