# 点线与填充的视觉层级

首版采用柔和填充、清晰边缘和明确主次。下列alpha是BioFigure起始建议，按终尺寸、重叠和来源调整；不是期刊统一参数。证据见[十篇记录](../atlas/mark-opacity-study-20261013.json)。淡色不能证明透明度。

| 图层角色 | 起始alpha | 处理 |
|---|---:|---|
| replicate-point | fill .70，edge 1 | 少量样本shape21，stroke .25；每点可数 |
| hollow-point | fill 0，edge 1 | 来源/语义适合时保留清晰外圈 |
| dense-point | .30 | 重叠点起步 .12–.55，缩小点径；密集UMAP不全加黑环 |
| individual-line | .25 | 个体轨迹用细线，避免色墙 |
| summary-line | 1 | 清晰汇总线、拟合线或主要轨道 |
| uncertainty-band | .18 | 区间带 .10–.25，先画底层，定义区间类型 |
| distribution-fill | fill .32，edge 1 | 箱/小提琴/密度填充 .20–.50，轮廓清晰 |
| bar-fill | fill .82，edge 1 | 柱体 .65–.90，保留深细边 |
| continuous-bubble | fill 1，edge 1 | 连续色含数值时保色标；面积映射数量 |

小样本、稀有群体和关键标签保持可辨；高密度叠加不当经校准的密度估计。热图/连续量色标、文字、轴、误差线与比例尺默认不透明。连续色例外须统一alpha、同步图例并说明原因。禁止装饰光晕。

## 编码与合同

`bf_mark_style(role)`读取起点；`bf_fill_alpha()`只改填色。`alpha=NA_real_`保留颜色内alpha，避免`geom_point(alpha=.7)`同时冲淡外圈。

```r
geom_point(aes(fill=stage(group, after_scale=bf_fill_alpha(fill,.70))),
           shape=21, colour="#30343B", stroke=.25, alpha=NA_real_)
```

新点/线/面积图编码前在Spec填写`mark_style_contract`，按实际图层编号列出role与采用alpha；偏离写`override_reason`，`design_target.marks`解释来源观察与调整。数据图层全部纳入；轴/文字/误差条独立核验。

```yaml
mark_style_contract:
  policy_id: layer-role-opacity-v1
  layers:
    - {layer: 1, role: replicate-point, fill_alpha: 0.70, edge_alpha: 1}
```

Spec校验器核合同；`bf_render_png()`导出前核实际built图层。支持point/line/path/segment/curve/ribbon/violin/box/density/bar；Smooth等复合几何须拆成线+区间，专用结构走对应renderer审查。连续色气泡校验保持fill=1；例外需专项核实际色条，布尔声明不能代替测量。归档Spec保留原验证范围。Python用独立RGBA facecolors/edgecolors。

终尺寸核点数、最小点、细环、主线/个体线、区间遮挡和图例。白底/灰度/色觉模拟及最终PDF重新审阅，不靠删点或加无意义标题改善图面。

技术依据：[ggplot2 alpha](https://ggplot2.tidyverse.org/reference/aes_colour_fill_alpha.html)、[stage/after_scale](https://ggplot2.tidyverse.org/reference/aes_eval.html)、[Matplotlib RGBA](https://matplotlib.org/stable/gallery/color/set_alpha.html)。
