# 渲染与交付凭据

每图保存Spec、代码、渲染凭据、inspection、ledger和门禁输出。清单先定。

## ggplot入口

复制 `scripts/figure_style.R` 到项目，调用：

```r
source("figure_style.R")
font <- bf_font("Arial")
# boxes含data/labels/legend实测槽位。
bf_render_png(plot, "figure.png", font, allowed_text,
  width_mm=90, height_mm=110, target_width_mm=90,
  source_files=c("plot.R", "figure_style.R", "design-spec.yaml"),
  boxes=boxes)
```

尺寸按数据与当前设计计算；来源模式还须对照参考。`target_width_mm`是论文/展示实际宽度；不能为通过字号检查写原始大画布宽度。默认≥6pt；5pt须填写`text_size_authorization`依据。标题授权用`heading_authorization`，仍须在清单内。

入口预检同一对象并导出，检查字体、清单、双离散GeomTile方格、槽位及最终字号。成功才写JSON；失败删除旧凭据。凭据绑定PNG、字体、脚本、样式助手与Spec哈希。boxes是测量输入，不代表脚本已识别全部真实对象碰撞，仍须看图。

## 图内文字

**硬门：导出画布严禁caption、footer、footnote和底部说明段。科学内容同样适用。** 样本设计、处理日期、方法、筛选阈值串、数据来源说明和完整figure legend放在图外图注/正文/元数据，不占PNG/PDF/SVG画布。正常底部轴与图例允许保留。

画布仅放有依据的轴/单位/刻度、图例、对象ID、必要面板标签、效应/P/q、比例尺；必要样本数用面板内紧凑`n = 8`。`-log10(FDR)`、`Up/Down/Other`等正常标签保留。标题授权只作用于title/subtitle/tag，不授权caption或脚注。

本次反例永久列入失败测试：`n = 8 fish per group; infection day 12`与`FDR <= 0.05; VIP >= 1; FC >= 1.2 or <= 1/1.2`。这两行应移图外；缩小、换语言、拆行或改成图层注释均不能改变规则。

禁止AI署名/备注、自动生成说明、预检/复现过程、PASS/NOT_VERIFIED状态、检查建议、演示/推断免责声明及内部案例编号等进入科研画布。将其加入`allowed_text`、缩小字号、改成注释图层或填写`heading_authorization`均不能豁免。读取参考或旧模板时删除这类输出文字，保留相关审计信息于图外；旧图及旧资格只作历史证据，不批量覆盖。

CP2：`text_contract.footer_policy`固定`outside-only`（省略时也执行）；`allowed_text`和`allow_headings`不构成豁免。校验计划文字与禁止字段，失败不得编码。

渲染：`bf_prepare`独立拒绝caption；检查gtable的caption槽和命名footer/footnote，递归查手写grob与`annotation_custom`文字，导出前再次查。patchwork须审完整组合grob；未适配的ggplot入口直接拒绝，禁止漏掉组合图后声称通过。

CP3：所有renderer都提交实际`rendered_text`、文字policy、`footer_policy_id=no-canvas-footer-v1`及真实执行的`footer_free`检查；缺失或与Spec不符即失败，换ComplexHeatmap/grid/Python不能跳过。禁止手填true代替执行。

CP4：打开当前PNG及实际PDF/SVG，从数据区看到最底边。`footer_absent`须有当前图的实际观察；发现任意底部说明记`footer_text=true`和`unrequested_text=true`，退回重画。缺观察、只读代码或沿用旧PASS均不得交付。短语和结构检查覆盖常见形式，任意改写仍靠最终逐字审查；含AI的真实ID和模拟量纲不因裸关键词误删。

## 热图格形硬门

少量矩阵逐格物理正方；特别密集才可显式`dense-overview`，不能自动压扁。CP2须锁展示行列与格形；CP3无当前设备逐panel/slice实际量测即失败，全部分片须覆盖所声明矩阵；CP4无当前PNG/PDF格形观察不得PASS。树、文字、图例及gap不参与格比计算，手写窄注释条有独立约束。完整字段、少量/密集默认边界及R入口见[heatmaps.md](heatmaps.md)。历史模板PASS不豁免新输入、新尺寸或最终导出。

## 其他后端

ComplexHeatmap/grid/Python保持原后端，使用真实字体/文本/布局测量及同次导出生成相同JSON字段；字段定义见`validate_render_receipt`。不得手写`checks=true`充数。缺适配器只交未验证预览。

## 最后一道门

CP2 evidence增加`design_spec`绝对路径；CP3增加`render_receipt`；CP4增加`inspection_evidence`，指向实际观察文件。凭据source_files必须包含Spec；所有凭据文件路径为绝对路径。

```sh
python3 scripts/validate_checkpoints.py checkpoint-ledger.yaml --json
```

检查器实际重跑Spec与publication完整Critic，不接受只写PASS；即使只要PNG也不能降级为仅scientific检查。专项Critic由Spec领域确定。每PNG验收；全PASS且退出码0才交付。

改图后重渲染、重开图、更新inspection再验收。来源模式缺参考或任何模式缺专项证据记录NOT_ASSESSED；原创以完整design-quality六维代替reference-quality，不降低终尺寸标准。哈希只证明文件一致性，技术凭据不是审美认证。
