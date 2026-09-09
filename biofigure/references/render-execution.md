# 从规范到首次可运行代码

默认顺序：输入与统计契约、参数、文字清单、字体解析、布局测量、图形对象、导出、验图。随机数据声明模拟并固定种子；真实数据不补造。参数集中包含尺寸mm、字号pt、色板、描边、类别顺序、图例槽位。保存sessionInfo和统计来源，不用全局theme_set或options改变用户会话。

## ggplot2

复用 `scripts/figure_style.R`：`font <- bf_font('Arial')`；加 `bf_theme(font)`；每个geom_text/repel/annotate文字层显式 `family=font$family`。`bf_prepare(plot,font,allowed_text,width_mm=...,height_mm=...)`在ragg设备构建并审查文字；`bf_export_png`使用相同尺寸。allowed_text来自批准的变量名、数据标签和明确的刻度，禁止从成图抽取全部文本再整体批准。多余标题先报错，不静默抹掉科学文字。

该工具检查字体族/缺字/文字清单和最小可用面板，不自动证明所有标签没有碰撞；手工或渲染器测量的槽位用bf_check_boxes。数据标签可有意位于panel内，但文字不能遮住证据；allowed_pairs须具体到对象对并记录原因。

## ComplexHeatmap / circlize / grid

先用bf_complexheatmap_font检查临时PDF测量所需的同名字体指标；部分版本anno_text内部会另开PDF，外部ragg不覆盖该设备。Arial只可登记真实ArialMT指标，不可别名到Helvetica。每个文字gp明确fontfamily、fontsize：row_names_gp、column_names_gp、row/column_title_gp、annotation_name_gp、legend labels_gp/title_gp；anno_text、anno_mark另设。split默认标题显式控制；有意义组名保留。白底ragg设备上先grid测文字，再算主体mm；`bf_square_body`计算格子与实际gap总量。`rect_gp`设细白/黑边；图例在独立槽位。列标签用bf_label_angle按实测宽度与单格间距选择0/90度，必要时增加格宽。draw()的合并/位置参数显式指定。不能把ggplot主题误用到grid图上。

## Python

同样建立文字清单与槽位；findfont禁fallback，逐个Text对象核对字体文件/字号，canvas.draw后实测extent。Scanpy关闭自动标题或替换为批准的变量标签；rcParams不能代替逐对象检查。

## 设备与证据

warning不吞掉；区分科学/字体/裁切错误与记录后确认无影响的提示。预检和导出尺寸、设备或字体变更都重测。实际打开最终图，检查文字、图例、留白、格子、颜色与误差线。审计脚本与图像查看器可以跨语言，渲染布局保持选定后端。

来源：[ggplot2 theme](https://ggplot2.tidyverse.org/reference/theme.html)、[systemfonts](https://systemfonts.r-lib.org/reference/match_fonts.html)。
