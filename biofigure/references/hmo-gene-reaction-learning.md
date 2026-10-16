# HMO 基因–反应网络：原始代码与复杂图学习

论文：Kellman et al., Nature Communications 13,2455 (2022), DOI [10.1038/s41467-022-29867-4](https://www.nature.com/articles/s41467-022-29867-4)。原图已实际查看 Fig.4 糖结构网络、Fig.5 双指标板以及补充 Fig.15 共现网络。当前训练对象为正式 Dataset3 的原生 R 方法迁移；不是整张 Fig.4 高保真重建。

## 可检索来源与版本

作者仓库 [LewisLabUCSD/HMO_GeneReaction_pred](https://github.com/LewisLabUCSD/HMO_GeneReaction_pred)，固定 commit `bab5107ec0cb6df41f0b6c33c47915d60a58bfe6`（2020-10-21，早于正式论文）。`B_largeModel_code_par.r` 是134153字节的真实作者分析/绘图文件，不能整体执行；其开头与部分分支涉及月级计算及作者绝对路径。`functions.R` 为数据连接及统计辅助函数；`C_GCagg.ipynb` 内为 R 代码。

版本许可分开保留：正式文章写代码/数据 CC-BY-4.0；固定仓库 LICENSE 为 Apache-2.0。保存全文与许可证，按对应版本引用；本轮不公开发布。

正式轻量输入 [Supplementary Dataset3](https://media.springernature.com/original/springer-static/esm/art%3A10.1038%2Fs41467-022-29867-4/MediaObjects/41467_2022_29867_MOESM7_ESM.xlsx)（82,534字节）为 baseline；101代谢物、204反应、377路径、27结构共现矩阵。`data/raw`保留原表，`data/plot_data`保留全量与选后表。171MB的 SourceData/MOESM8未取得，不需要它。Zenodo中原始模型矩阵为GB级；不用从头计算。

## 源码学习与包职责

| 源码位置 | 函数/包 | 学到的实际处理 |
|---|---|---|
| B_largeModel L1984–2008 | igraph::graph_from_edgelist、strength、degree、shortest_paths | 用代谢物ID连有向边；edge权重、颜色、线型分开；节点深度从乳糖根开始 |
| L2011–2027 | all_simple_paths、ecdf | 按每个终点独立选择 percentile_term>0.95；≤2路径终点全选；节点取这些路径并集 |
| L2032–2068 | layout_as_tree、induced_subgraph、plot.igraph | 全图与入选节点子图；入选节点间所有内连边保留，不只最强路径边 |
| L1339–1392 | coocur_par、jaccard、gplots::heatmap.2 | 结构共现模型矩阵，固定顺序或另一版本聚类；两侧结构家族色条；不是样本表达相关矩阵 |
| 本次适配 | igraph、ComplexHeatmap、circlize、grid/ggplotify、ggplot2、ragg/svglite | 保留原生有向分层图、真正注释热图，物理mm组装及矢量PDF；用新配色 |

源R边权为 `proportion_inter * (1+enrichment_inter)`，再除全图最大权重；源码此处 enrichment 已在上游由1-p定义。正式 Dataset3 列名/README叙述与源码有歧义，本次直接保留 `weight.enrichment_scaled_proportion`，不从P值重算。节点原始importance/degree/depth与子图selected_degree/selected_strength/shortest_from_lactose同时保存，禁止混用。

## 图型与版式迁移

Fig.4B：乳糖在上，反应向下，Type I/II布局、节点SNFG糖结构，颜色代表新增单糖，线型代表键连位点，粗细代表重要性。作者R源PDF只有网络/文字；正式SNFG图符、放大框与手工装配代码未找到。

本次绘两板：A保留43入选ID及58反应，以igraph从乳糖根分层，全边色按新增单糖类别，实/虚/点线按键位，线宽按正式已给重要性，灰线为isomer sink。B显示全部27×27=729共现值，固定源顺序、五个结构家族注释；ComplexHeatmap替代源heatmap.2以实现清晰字体、间距和共享图例。与补充Fig.15的12节点/高共现边网络相比，B是完整矩阵展开，未复制其阈值筛选。

画布180×170mm，Arial7.5pt以上；首次即语义彩色，正式PDF与目标尺寸预览重新检查。布局、色值、包版本、节点/边/矩阵数量与数据哈希写入本例合同和证据。

## 必须保留的科学边界与缺口

- 第95百分位路径为重要性排名，不是95%置信区间；43节点/58边为作者表标志诱导子图。
- Jaccard衡量高评分模型中结构共同出现，不能写为Pearson/Spearman或基因表达相关。
- `functions.R::jaccard(x,y=NULL)`首分支缺return；源27×27对角为0。原表及值完整保留，不能擅改成1，也不能将对角0解释为结构不存在。外部图注说明其源实现边界。
- GitHub预印本 `Gene_Choice_aggstats.rda` 的候选基因/数值与正式 Fig.5A 不同，仅为版本证据，不进入本次图。Fig5A的GLS是Spearman、MSC是Pearson，分别min–max为0–1，cohort用线型；不能因量纲统一而混淆统计定义。
- 源文件有绝对路径、旧API及重计算分支；只学习选定方法，重新写轻量适配器。读过源码的迁移为source-exposed-transfer，不是盲测或通用能力认证。

检索ID：`BENCH-multiomics-hmo-gene-reaction`。关键词：糖组学 转录组 网络 反应 结构共现 Jaccard glycomics HMO directed network。原生数据准备入口：`benchmark/library/multiomics/hmo-gene-reaction/scripts/prepare_data.R`；参数为本例绝对根目录。
