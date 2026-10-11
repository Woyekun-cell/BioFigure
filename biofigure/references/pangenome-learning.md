# 番茄超泛基因组：逻辑与选图

来源：[Li等，Nature Genetics 2023](https://www.nature.com/articles/s41588-023-01340-y)；[作者仓库](https://github.com/HongboDoll/TomatoSuperPanGenome)，固定f31cab43。来源、15个数据合同及审计见[主题包](../library/pangenome/tomato-superpangenome/data/metadata/paradigms.json)。代码学习不等于测序流程复现。

## 证据顺序

组装与重复注释先做QC。RNA比对/StringTie/TransDecoder及Trinity/PASA提供转录证据和训练集，Genscan/Augustus/GlimmerHMM提供从头预测，GeMoMa提供同源证据，EVM按来源权重整合。01依赖03的BAM，编号不是执行依赖顺序；硬编码路径、缺失输入和GFF来源名需重建，不能直接执行。

每基因选代表转录本；原文另用GMAP回查注释遗漏。OrthoFinder聚类后转换器输出的是基因ID列表/“-”，须显式变成0/1/未知；拷贝数另存。单独检查未分组基因，不能默认全部包含。相同注释策略与可比完整度是“缺失”的前提。

基因家族泛基因组、SV目录和vg图基因组是三层对象。SyRI/SVMU比较组装，统一参考、liftover及合并后，才构建图并进行群体分型；该图仅纳入INS/DEL及小于1Mb的INV。GWAS另需个体表型、PC和亲缘矩阵。共享/关联不等于因果；候选位点再接PCR、表达及功能实验。

## 数据决定范式

- 注释QC表：指标点图/完整度堆积图；基因结构GFF：共享坐标轨道。
- 家族PAV矩阵：组成柱图、占有频率、累积曲线或有序热图，按研究目标选。
- 子集计数表：泛/核心双曲线；子集范围不是生物学置信区间。
- SV类型计数：材料×类型堆积柱；窗口密度：轨道/热图，必要时Circos。
- 比对区块：正反向共线性点线图；Hi-C矩阵：共享色标的接触图。
- Newick与元数据：树与注释列；全量GWAS：Manhattan＋QQ；原始个体表型：基因型箱线＋点；GO：背景明确的富集点图。

自动入口：request加pangenome_context，含data_type、intent、columns、unit；PAV另含missing_policy: unknown_not_absent。主规划器接15条合同；同数据多目标而未声明意图时NEEDS_SPEC，询问用户。字段映射须显式，元数据校验不替代实际数据QC。统计见[审计](pangenome-statistics.md)。

已运行：作者Fig2a全部8,178子集的均值/范围、Fig2b的60条SV计数、Fig2c的9,637窗口；三张彩色PDF独立重绘，不是原始图像逐像素复现。[离线重绘入口](../benchmark/library/pangenome/tomato-superpangenome/scripts/reproduce_figures.py)以--work-dir指定临时目录；自动选图走prepare_figure.py的request入口。
