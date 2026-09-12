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

尺寸按数据与参考计算。`target_width_mm`是论文/展示实际宽度；不能为通过字号检查写原始大画布宽度。默认≥6pt；5pt须填写`text_size_authorization`依据。标题授权用`heading_authorization`，仍须在清单内。

入口预检同一对象并导出，检查字体、清单、双离散GeomTile方格、槽位及最终字号。成功才写JSON；失败删除旧凭据。凭据绑定PNG、字体、脚本、样式助手与Spec哈希。boxes是测量输入，不代表脚本已识别全部真实对象碰撞，仍须看图。

## 其他后端

ComplexHeatmap/grid/Python保持原后端，使用真实字体/文本/布局测量及同次导出生成相同JSON字段；字段定义见`validate_render_receipt`。不得手写`checks=true`充数。缺适配器只交未验证预览。

## 最后一道门

CP2 evidence增加`design_spec`绝对路径；CP3增加`render_receipt`；CP4增加`inspection_evidence`，指向实际观察文件。凭据source_files必须包含Spec；所有凭据文件路径为绝对路径。

```sh
python3 scripts/validate_checkpoints.py checkpoint-ledger.yaml --json
```

检查器实际重跑Spec与publication完整Critic，不接受只写PASS；即使只要PNG也不能降级为仅scientific检查。专项Critic由Spec领域确定。每PNG验收；全PASS且退出码0才交付。

改图后重渲染、重开图、更新inspection再验收。缺参考/专项证据记录NOT_ASSESSED。哈希只证明文件一致性，技术凭据不是审美认证。
