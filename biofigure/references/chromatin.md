# ATAC、ChIP、CUT&Tag 与信号轨道

输入可能是peak集合、bigWig、区域×bin矩阵、差异区域或motif结果。区分峰计数、峰评分、read覆盖、归一化信号，纵轴不能统一写“expression”。记录参考组装、注释、坐标制及信号归一化。

热图明确TSS中心/峰中心/缩放gene body；上下游长度、bin大小或数量、链方向、缺失处理、过滤规则。缩放gene body不是等长真实基因；平均曲线区分区域间变异与生物学重复不确定性。

跨条件对同一批区域比较时共享行集合和排序，不让每组独立排序制造共同模式。shared scale取决于信号可比性；不同归一化结果不得仅因统一颜色就并排定量。

轨道共用基因组坐标，断轴、翻转或不同y范围明确标识。最近基因注释不等于已证实靶基因。Motif富集、footprint、可及性与TF真实结合分开表述。

密集信号是个人方格规则的需确认例外，先说明密度与建议布局；没有已有授权时不自行去边或压扁。不能为图小就隐藏区域或改变bins。

依据：[deepTools热图](https://deeptools.readthedocs.io/en/develop/content/tools/plotHeatmap.html)、[ChIPseeker](https://bioconductor.org/packages/release/bioc/vignettes/ChIPseeker/inst/doc/ChIPseeker.html)、[pyGenomeTracks](https://github.com/deeptools/pyGenomeTracks)。
