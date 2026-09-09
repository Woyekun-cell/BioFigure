# 基因组与比较基因组

先核对组装与注释配对、物种/个体/版本、染色体命名和坐标。BED通常0-based半开区间；GFF3使用1-based闭区间。转换只做一次并记录，检测越界/负长/未知contig。
圆形跨原点与零长度位点按格式特例处理，不机械当坏区间。

共线性图区分核酸比对、蛋白同源、orthogroup和真实共线区。布局翻转须同时转换feature及连接坐标，记录原始方向；不把布局连接简化当重排证据。基因家族图不能把转录本、碎片注释直接计作独立基因拷贝。

系统树明确有根/无根、branch length意义、支持值类型、标签映射。按拓扑排序注释，不能按名称排序错配。无依据不增加分化时间轴。

变异图：OncoPrint缺失/未测与未检出不同；同一样本多个事件保留编码；右侧频率分母说明。CNV、SV、GWAS分别保留单位、位置、阈值来源和缺失区域。Hi-C注明分辨率、归一化、矩阵范围；三角显示不能任意拉伸或冒充距离尺度。

常用组合：树+基因结构/结构域；共线性+基因轨道；染色体概览+局部区域。选择依赖科学问题，不强制圆形。

依据：[gggenomes方向](https://thackl.github.io/gggenomes/reference/flip.html)、[GFF3规范](https://github.com/The-Sequence-Ontology/Specifications/blob/master/gff3.md)、[UCSC BED](https://genome.ucsc.edu/FAQ/FAQformat.html#format1)。
