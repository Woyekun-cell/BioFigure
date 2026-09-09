# Visual Ontology 与 Renderer 路由

机器字段：问题/scientific question、输入、实验单位、尺度/变换、统计、视觉通道、失败条件、QA、导出。

- 先由领域和问题确定图型，再选 Pattern 与 renderer。

先定科学问题、数据结构、尺度、密度和 message，再选 primitive、Pattern、Renderer；不能从文件扩展名或熟悉的包反推图型。

默认优先级：

1. 常规统计图、转录组、代谢组、多组学：R + ggplot2；矩阵：R + ComplexHeatmap；树/结构/比较基因组：ggtree、gggenomes、circlize。
2. 单细胞若对象是 Seurat，优先 R 后自定义 ggplot；对象是 AnnData/Scanpy 且需沿用 embedding/layer 时可 Python。Scanpy 默认图必须重设字体、白底、图例和输出尺寸。
3. deepTools、pyGenomeTracks 等 Python/CLI 专用信号轨道可原生生成；若版式不足，再在不改数据映射的前提下重排。
4. 用户指定语言时服从；“兼容 Python”不等于每张图双实现。

两阶段 Retrieval：eligibility 先按 domain/task/message/行列规模/连续或离散/配对/坐标排除冲突卡；design-fit 再按信息密度、最长标签、分片、聚类、目标宽度、注释负担和 Renderer 能力排序。

R 优先是 renderer 实现默认，不是科学规则。任何后端都必须执行[首轮布局合同](first-render-contract.md)。输出候选、排除理由和选择理由；不让审美分覆盖样本错配、尺度未知、方向错误等 hard failure。
