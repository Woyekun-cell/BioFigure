# R 发表级实现

常规图优先 ggplot2，复杂矩阵优先 ComplexHeatmap，组装用 patchwork/grid；不要为了统一接口改用较弱 Renderer。

字体使用 Arial / Helvetica 中经 systemfonts 与当前图形设备实测可用且试写零警告的一种；不得固定假设某一种存在，任何 silent fallback 均失败。画布、panel 和导出背景均为 #FFFFFF，暖白只能作为数据中点候选。

ComplexHeatmap 分两路：

- 可读离散矩阵：按单格毫米数计算 body width/height，rect_gp 使用细白/黑边，最终 viewport 实测宽高误差。
- 密集矩阵：use_raster=TRUE，仅栅格化 body；树、标签、注释、图例保持矢量。最终尺寸不可辨时不画逐格边框，改用分片、稀疏行名或总览+细节。

先建立 Heatmap/annotation，再在 draw() 中固定 legend side、padding 和背景。图例在矩阵外；分片 gap、树高、最长标签和图例宽度进入画布计算。row/column title 默认为空。

设备先实写探针：PNG 优先 ragg::agg_png，SVG 用 svglite，PDF 用明确 family 的 pdf。capabilities("cairo") 不代表动态库可加载；设备或字体有任一 warning 即失败。ComplexHeatmap 内部栅格设备优先 agg_png，避免不可用 Cairo。

首轮必须零警告、打开 PNG、检查裁切/重叠/白底/字体，再导出正式格式。依据：[ComplexHeatmap](https://jokergoo.github.io/ComplexHeatmap-reference/book/)、[patchwork](https://patchwork.data-imaginist.com/articles/guides/layout.html)。
