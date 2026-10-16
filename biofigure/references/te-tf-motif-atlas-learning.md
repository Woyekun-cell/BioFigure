# 转座子–TF motif 表观组学：Karttunen & Patel 2023

本案例学习原作者代码、原图版式及处理后的绘图表，限定正式 Fig.3a 两个散点面板和 Fig.3b 完整聚类热图。Fig.3c/d 的基因组轨道及信号热图需要其他输入与脚本，不在本次范围。

## 论文、代码与数据

- Karttunen, Patel 等，*Transposable elements as tissue-specific enhancers in cancers of endodermal lineage*，Nature Communications 14,5313 (2023)，[DOI10.1038/s41467-023-41081-4](https://www.nature.com/articles/s41467-023-41081-4)。论文 Code availability 明确链接作者仓库。
- 固定代码：[scripts/fig_3.Rmd](https://github.com/Karttune/Karttunen_Patel_et_al/blob/2220b9cf7304db38553fc0d36bb1bd97630543c3/scripts/fig_3.Rmd)，commit `2220b9cf7304db38553fc0d36bb1bd97630543c3`，配套 `scripts/utils/utils.R`。仓库没有 LICENSE；仅在本项目 work/source-reading 保存私用学习副本，不进入公开发布包。适配器独立编写。
- [正式 Fig.3](https://www.nature.com/articles/s41467-023-41081-4/figures/3) 已打开原尺寸图：顶端左右两个同尺度 log–log scatter；b 为14个motif簇×35个TE亚家族，Common/GP5d/HepG2三片，有行树及三列树，右侧TF缩写、底部垂直TE标签及水平连续色标。NFYA/NFYB与LTR12用蓝色相连，TFAP2与MER11用红色相连。
- [Source Data ZIP](https://media.springernature.com/original/springer-static/esm/art%3A10.1038%2Fs41467-023-41081-4/MediaObjects/41467_2023_41081_MOESM6_ESM.zip) 全包266,564,020bytes；本次仅HTTP Range提取 `Source Data/source_data.xlsx`（5,421,353bytes），保留ZIP成员索引、Range区间、ETag及提取后SHA256。
- [Supplementary Data1–9](https://media.springernature.com/original/springer-static/esm/art%3A10.1038%2Fs41467-023-41081-4/MediaObjects/41467_2023_41081_MOESM4_ESM.xlsx)，7,593,600bytes；AME完整8188条，含motif_ID/subf/Vierstra cluster/class/adj_pval/eval。无需FASTQ/BAM或重跑AME。
- 论文图及附属材料为CC BY4.0；源码无许可证，权限分别记录。

## 原始处理方法及复现决策

1. Fig3a源码从已有TE enrichment构造细胞系比较，Fisher双侧检验加BH校正。本次直接复用正式Source Data中的 `padj_fisher/fisher_sig/lab`，不重检验；558条=左279+右279，同一TE在两面板出现是设计用途，不跨面板去重。横纵坐标是observed/expected ratio。
2. Fig3b从指定亚家族AME结果中按 `adj_pval<1e-5` 选择，以Vierstra相似motif簇归并。选择每TE的top1 motif簇时使用 `min(eval)`。
3. **正式caption写最小E-value，但源码最终显示矩阵用 `mean(-log10(eval))`，随后按列 `scale.default(center=FALSE)`。** 后者除以 `sqrt(sum(x²)/(n-1))`，不减均值，不是中心化Z-score。明确区分选择阶段与显示阶段；本次保留作者最终Source Data矩阵，图例写 `Scaled -log10(E-value)`，不擅自换为最小E值或中心化Z-score。
4. 最终矩阵有18个负值（E-value>1产生），必须保留。零填充表示未进入该motif显示组合，不直接解释为生物零活性。8188条AME原结果与14×35最终矩阵均保存，便于复核链条。
5. 32条散点面板记录含零比值；log(0)无定义。保留源零值，并独立生成display_x/y：低于0.1绘在原图对数轴下界，以三角标记及图例说明；不把0.1替换成原测值或伪计数。全558条保留。
6. 列分组Common10/GP5d12/HepG213；保留全部原ID与完整motif组合。图内沿原图用14个TF家族缩写。它们是亚家族分类，不是生物重复、基因组坐标或因果网络。

## 包与绘图范式

| 包 | 函数和职责 | 可复用方法 |
|---|---|---|
| ComplexHeatmap | `Heatmap/HeatmapAnnotation/draw/row_order/column_order` | 真正切片热图与Ward.D2行/片内列树；关闭slice聚类，不用普通tile假画树 |
| circlize | `colorRamp2` | 连续标量色标保留负值；替换OrRd而不换数值 |
| ggplot2 | `geom_point/geom_abline/scale_x_log10/scale_y_log10` | 双面板同尺度，显著类别用大描边点，非显著点小；对角线是等值线，不是拟合线 |
| ggrepel | `geom_text_repel` | 可按源TE家族将标签合并，并连到所有所属点；不删点或原ID |
| readxl/base R | `read_xlsx/hclust/dist` | 复用已处理表与固定ID；无需bedtools、重新取序列或新增统计 |
| grid/ragg/svglite | `grid.grabExpr/gpar`及导出 | 将原生ComplexHeatmap捕获为可编辑grid，与ggplot按毫米组装；PDF不扁平化 |

新色义：Common青绿、GP5d赭橙、HepG2兰紫；TFAP2/MER11共赭橙，NFYA/LTR12共兰紫。标量热图浅米色至青蓝，负值另留浅褐；白底、细格边，图例预留位置。双栏180×160mm，Arial≥7.5pt，完整14×35矩阵、两幅散点及双向树；不拿柱状图替代复杂结构。

## 本地入口与验证范围

`benchmark/library/epigenomics/te-tf-motif-atlas/scripts/prepare_data.R` 从两份固定XLSX生成5个CSV与QC，保留490格、558散点及8188AME记录。绘图入口在本次fresh prepare/CP2后独立编写 `scripts/render.R`。单一R后端导出PNG/PDF/SVG，检查实际源图、最终PDF与独立复跑。后续新输入仍需核验单位、缩放、排序、字号及实际成图；固定表复现不等于任意输入、c/d整图或模型等效性通过。
