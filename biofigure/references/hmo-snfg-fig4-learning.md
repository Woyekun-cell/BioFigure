# HMO正式Fig.4：SNFG图符与原版式复现

本例纠正此前文字网络＋热图与正式Fig.4差异过大的问题。旧图保持USER_REJECTED_SOURCE_LAYOUT；不能用固定数据复跑一致替代原图相似性。

原图：Nature Communications 2022，DOI10.1038/s41467-022-29867-4，Fig.4A/B，1999×1186像素。A为DFLNT1/2/3三异构体，B为含糖图符的代谢反应网络，TypeI/II分区、图符碳位示意、放大框与底部SNFG图例。已按原尺寸实际看图并逐节点/边/符号拆解。

## 真实数据与显示子集

正式Dataset3(MOESM7)全101代谢物/204反应。本例显示原图B实际31label及其40反应；不是旧95%路径标志的43节点/58边，原图31中10个flag为FALSE。A三异构体IDs28/29/39（DFLNT3不是ID30）。B的Lactose源图仅label，禁止新增糖图符；B可见178单糖符＋A18＝196，33独特糖链包含被隐藏的根乳糖及A独有结构。

保留原始ID/糖字符串/parent及键位；手工图像坐标只为显示，原生像素测量约±3–6px，不冒充作者矢量坐标。31标签、7个星标、40边均逐项追踪；反应边40/40在正式表及源图检视匹配。

## 学过哪些真实代码

作者HMO仓库固定`bab5107ec0cb6df41f0b6c33c47915d60a58bfe6`，原始R包含igraph结构、重要性及子图绘法；只有文字网络导出，未找到正式SNFG终稿装配代码。正文CC-BY4.0与仓库Apache2.0分开记录，见原学习卡。

补图符用BojarLab/glycowork v1.10.1 fixedcommit`8e178129e99477dfdc38a055a34886bbbe0e02ea`，MIT：`linearcode_to_iupac`、`GlycoDraw`、`draw_shape`、`get_coordinates_and_labels`及`plot_network(draw_glycans=True)`。糖形状、颜色、分支、Fuc/Neu5Ac位置、节点内嵌SVG应独立处理，普通文字节点无法替代。glypy fixedcommit`8d129a8c950e8635165cda9b4b1af392d4e7289e`，Apache2.0，`linear_code.py`从右向左解析，branch_stack把括号分支接回父糖，不能只数糖字母。

本地strict HMO子集parser不新增依赖。原样执行固定glycowork转换函数AST（没有运行整个包），96明确糖字符串转换一致；8已知键位夹具通过、3无效夹具拒绝。NN供体为C2，其余糖C1；5个聚合sink不伪造为具体糖链。

## 字形与化学合同

官方[SNFG规范](https://www.ncbi.nlm.nih.gov/glycans/snfg.html)：Glc蓝圆#0072BC、Gal黄圆#FFD400、GlcNAc蓝方#0072BC、Fuc红三角#ED1C24、Neu5Ac紫菱#A54399。符号颜色与形状编码糖身份，不任意换色；三角尖端向上、菱形保持方向。原论文主体cyan与底部blue不一致，本例统一官方蓝色；普通网络边和文字换配色。

本次R grid逐糖`circleGrob/rectGrob/polygonGrob`和每条parent键`segmentsGrob`，放在原图追踪节点锚点，不截图、不栅格化。严格parser坐标遇到分支碰撞整体移动子树，parent/键位不变；A大糖符用源实际像素中心，B用实际source31锚点、固定等比例拓扑glyph。8夹具及33目标结构的预处理无符号碰撞/无无关键穿符号，最终毫米字形仍需重新核验。

## 版式与定量边界

双栏180×112mm，保留A左3大糖链与连接DFLNT2箭头、B源位点/TypeI-II竖线、上方非定量zoom草图、右上碳位示意、右侧9项键连图例、底部5糖身份图例。所有科研标注按源比例并调至可读物理字号。图内不放AI/训练/验收状态。

原图线宽与正式表存在冲突：乳糖4出边正式权重相同但像素粗细不同；2→8源细而正式权重大；25→53源较粗而正式权重极小。本例线宽严格用已给`weight.enrichment_scaled_proportion`，source solid/dash/dot样式保留，渐细几何只是视觉模板。不得按原像素线宽逆推出未提供权重。上述差异写图外及证据，不掩盖。

检索ID`BENCH-multiomics-hmo-snfg-fig4`。原图结构/布局核验、真实CSV、源码版本/许可、renderer、物理PDF字形/QC及独立复跑封存本variant；旧文字网络不重新升格。
