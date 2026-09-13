# BioFigure 3.5.0

本版把复现经验从长篇规则拆成按案例区间加载的方法文件，降低短请求和低推理模式漏读关键约束的概率。所有模式使用同一门禁：专用包实测、独立重写、最终PNG检查、原图对照和CP0–CP4均不可省略。

复现检索新增证据过滤。只有`runtime_status=source-compared-png`且`review_status=pass`的记录可作为高保真先例；旧记录缺少对象级审查时继续保留，但不会被当作通过案例。来源代码仅在用户授权时用于检查包、函数、变换、排序键和布局，公开代码仍须独立重写。

公开图库增加8张使用模拟数据生成的专用R包方法图，覆盖`ggtern`、`circlize`、`ComplexHeatmap`、`ggnewscale`、`ggraph`、`ggridges`、`scatterpie`与`sf`等方法族。图库不包含公众号原图、来源数据或来源代码。

本版没有完成全部79个公众号案例和SciDraw案例的高保真验证。发布审计中的`high_fidelity_eligible`是当前可用于高保真检索的数量，其余记录按待复核或待修订处理。
