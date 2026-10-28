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

Matplotlib Figure 使用官方 `scripts/figure_style.py` 的 `bf_font`、`bf_style` 与 `bf_render`；seaborn/Scanpy 须取得其实际 Figure 后走同一入口。先完成准备与 CP2，编码后以实际脚本、输入和 helper 自身签发一次性授权，Spec 通过独立参数绑定，再由 `bf_render` 消费。具体参数与命令见 [Python 授权渲染](python-rendering.md)。

文字清单从设计和输入语义预先确定，不从成图反向批准；真实字体禁 fallback，逐 Text 核对字体/字号，canvas.draw 后测 extent。Scanpy 关闭未批准标题，rcParams 不能代替逐对象检查。普通 `savefig` 或其他 CLI 只证明导出文件；正式回执也不替代当前 PNG/PDF/SVG 的实际检查与 CP3/CP4 校验。

## 证据

不吞warning；设备、尺寸、字体变化均重测。打开最终图核对文字、图例、留白、方格、颜色与误差线。审计工具可跨语言，布局渲染保持选定后端。

来源：[ggplot2](https://ggplot2.tidyverse.org/reference/theme.html)、[systemfonts](https://systemfonts.r-lib.org/reference/match_fonts.html)。
