# 首次代码与渲染

交付入口见`enforced-execution.md`。默认顺序：科学契约、参数、文字清单、字体、布局测量、绘图、导出、验图。模拟须声明并固定种子，真实数据不补造。参数集中：mm尺寸、pt字号、色板、描边、顺序、图例槽位；保存sessionInfo与统计来源。不用全局theme_set/options改变用户会话。

## ggplot2

复制`scripts/figure_style.R`到项目。`bf_font('Arial')`解析真实字体；`bf_theme(font)`设置主题。所有geom_text/repel/annotate显式`family=font$family`。

`bf_render_png`内部调用prepare/export，预检与导出同一对象、尺寸和设备。allowed_text来自预先批准的变量、标签、刻度；不得从成图全量反向批准。多余标题报错，不静默删除科学文字。

助手检查字体、缺字、清单和最小面板；不证明所有真实对象无碰撞。boxes由渲染器实测，bf_check_boxes检查槽位；allowed_pairs具体到对象对并记录原因。

## ComplexHeatmap / circlize / grid

先用bf_complexheatmap_font检查内部临时PDF的同名字体指标；外部ragg不覆盖anno_text内部设备。Arial只能登记真实ArialMT，不能别名Helvetica。

每层gp显式fontfamily/fontsize，包括行列名、标题、注释、图例、anno_text/mark；split默认标题显式控制，必要组名保留。

白底ragg上grid测文字，再算主体mm；bf_square_body计算格子与全部gap，rect_gp细白/黑边。图例独立槽位；bf_label_angle按实测宽度与间距选0/90度，必要时扩格。draw合并/位置参数显式；ggplot主题不约束grid。

## Python

建立文字清单与槽位，findfont禁fallback，逐Text核对真实字体/字号；canvas.draw后测extent。Scanpy关闭未批准标题，rcParams不能代替逐对象检查。

## 证据

不吞warning；设备、尺寸、字体变化均重测。打开最终图核对文字、图例、留白、方格、颜色与误差线。审计工具可跨语言，布局渲染保持选定后端。

来源：[ggplot2](https://ggplot2.tidyverse.org/reference/theme.html)、[systemfonts](https://systemfonts.r-lib.org/reference/match_fonts.html)。
