# 十篇Nature大子刊科研图：来源学习与benchmark入口

2026-10-15完成十篇DOI独立的来源学习，来自Nature Methods（5）、Nature Biotechnology（3）、Nature Genetics（1）、Nature Cell Biology（1）。保存18张完整正式原图，学习38组数据面板。三子agent并行，根agent独立开图、核对绑定并统一入库。

这是原图观察、作者代码/方法、输入与排版合同学习。8篇定位到原作者分析代码；Augur与Tangram仍缺所选正式面板作图脚本，保留计算包/同期方法层证据，未以教程冒充。十篇的原图重算复现、CP2–CP4、新输入迁移、压力验证和用户验收全部未认证。

## 十篇入口

| 项目与论文原始来源 | 期刊 / 卷期年 | 学习图型 | 本地合同与固定代码 | 检索ID |
|---|---|---|---|---|
| [CellRank](https://www.nature.com/articles/s41592-021-01346-6) · 10.1038/s41592-021-01346-6 | Nature Methods 2022 | 环形命运投影 · 拟时序概率 · 标记基因点图 | [学习卡](../benchmark/library/single-cell/cellrank-2022/learning.md) · [图码映射](../benchmark/library/single-cell/cellrank-2022/data/metadata/code-figure-mapping.json) | `BENCH-subjournal-cellrank-2022` |
| [MEFISTO](https://www.nature.com/articles/s41592-021-01343-9) · 10.1038/s41592-021-01343-9 | Nature Methods 2022 | 方差解释热图 · 因子曲线与区间 · 分组核相关 | [学习卡](../benchmark/library/multiomics/mefisto-2022/learning.md) · [图码映射](../benchmark/library/multiomics/mefisto-2022/data/metadata/code-figure-mapping.json) | `BENCH-subjournal-mefisto-2022` |
| [Augur](https://www.nature.com/articles/s41587-020-0605-1) · 10.1038/s41587-020-0605-1 | Nature Biotechnology 2021 | 样本量稳健性曲线 · 效应量响应热图 | [学习卡](../benchmark/library/single-cell/augur-2021/learning.md) · [图码映射](../benchmark/library/single-cell/augur-2021/data/metadata/code-figure-mapping.json) | `BENCH-subjournal-augur-2021` |
| [LIANA+](https://www.nature.com/articles/s41556-024-01469-w) · 10.1038/s41556-024-01469-w | Nature Cell Biology 2024 | 因子富集热图 · 空间因子 · 配体受体变化 | [学习卡](../benchmark/library/spatial/liana-plus-2024/learning.md) · [图码映射](../benchmark/library/spatial/liana-plus-2024/data/metadata/code-figure-mapping.json) | `BENCH-subjournal-liana-plus-2024` |
| [NicheNet](https://www.nature.com/articles/s41592-019-0667-5) · 10.1038/s41592-019-0667-5 | Nature Methods 2020 | 配体活性条 · 配体靶基因热图 · 肿瘤表达联图 | [学习卡](../benchmark/library/single-cell/nichenet-2020/learning.md) · [图码映射](../benchmark/library/single-cell/nichenet-2020/data/metadata/code-figure-mapping.json) | `BENCH-subjournal-nichenet-2020` |
| [Tangram](https://www.nature.com/articles/s41592-021-01264-7) · 10.1038/s41592-021-01264-7 | Nature Methods 2021 | 空间概率小多图 · 预测与实测基因对照 · 经验CDF | [学习卡](../benchmark/library/spatial/tangram-2021/learning.md) · [图码映射](../benchmark/library/spatial/tangram-2021/data/metadata/code-figure-mapping.json) | `BENCH-subjournal-tangram-2021` |
| [ArchR](https://www.nature.com/articles/s41588-021-00790-6) · 10.1038/s41588-021-00790-6 | Nature Genetics 2021 | 成对轨迹热图 · 多模态TF热图 · 轨道与足迹 | [学习卡](../benchmark/library/epigenomics/archr-2021/learning.md) · [图码映射](../benchmark/library/epigenomics/archr-2021/data/metadata/code-figure-mapping.json) | `BENCH-subjournal-archr-2021` |
| [Signac](https://www.nature.com/articles/s41592-021-01282-5) · 10.1038/s41592-021-01282-5 | Nature Methods 2021 | 注释一致性热图 · motif足迹 · coverage与链接弧 | [学习卡](../benchmark/library/epigenomics/signac-2021/learning.md) · [图码映射](../benchmark/library/epigenomics/signac-2021/data/metadata/code-figure-mapping.json) | `BENCH-subjournal-signac-2021` |
| [SEACells](https://www.nature.com/articles/s41587-023-01716-9) · 10.1038/s41587-023-01716-9 | Nature Biotechnology 2023 | 表达可及性相关散点 · 轨道弧 · TF活性热图 | [学习卡](../benchmark/library/single-cell/seacells-2023/learning.md) · [图码映射](../benchmark/library/single-cell/seacells-2023/data/metadata/code-figure-mapping.json) | `BENCH-subjournal-seacells-2023` |
| [Milo](https://www.nature.com/articles/s41587-021-01033-z) · 10.1038/s41587-021-01033-z | Nature Biotechnology 2022 | 固定邻域网络 · 分面蜂群 · logFC排序密集热图 | [学习卡](../benchmark/library/single-cell/milo-2022/learning.md) · [图码映射](../benchmark/library/single-cell/milo-2022/data/metadata/code-figure-mapping.json) | `BENCH-subjournal-milo-2022` |

## 逐篇可复用与限制

### CellRank

Fig6c：九终末状态的环形命运投影；Fig6e：Palantir拟时序×Basal概率散点，以及Stage1–3的Bpifb1、Krt5、Trp63点图。

原作者notebook第76、129、131、134单元（从0计）：CellRank circular_projection、scVelo scatter、Scanpy dotplot。当前包源码另固定。

normalize_by_mean=True；当前实现先除各命运列均值、再逐行归一后投影，不能当作原始概率几何。终末状态顺序须锁定；点图面积为表达细胞比例，颜色为均值。

已看Fig6；两张作者稳健性表各24个p值的范围已核，另查阶段边界合同；这些表不是Fig6输入，未重算命运矩阵。

缺Fig6完整肺细胞对象及正式组装。第125单元random.seed=0未调用种子函数；阶段2/3在2/3边界重叠，后赋值归阶段3。当前包与旧接口另有差异。

固定代码来源：[https://github.com/theislab/cellrank_reproducibility](https://github.com/theislab/cellrank_reproducibility)；提交/版本：`c1b9232caacd15fdd16914007fab4890b136109f`。许可与原论文代码/当前包分层详见本案source-manifest和paper-source。

### MEFISTO

Fig2b：五物种解释方差柱形图与5×5因子热图；Fig2d：共同发育时间上的因子轨迹及区间；Fig2e：逐因子的物种相关核热图。

原作者evodevo_all.Rmd：198–201、352–384、410–485行。MOFA2取方差/插值因子；ggplot2画线、点和区间，pheatmap与cowplot组装。

保留group、view、factor与时间键。源码区间为mean±1.96√variance；核热图每因子独立聚类，不强行统一顺序。推断共同时间不等于物理时间。

已看Fig2；当前包299573字节合成HDF5的两组×50点×3因子，已核均值有限、方差非负、相关核对称及半正定；不是论文五物种模型。

缺原始evo-devo预训练模型、标准化输入与旧环境；作者分析库未发现LICENSE。源码与正式组合图的条带位置有差异；未重绘或核原图数值。

固定代码来源：[https://github.com/bioFAM/MEFISTO_analyses](https://github.com/bioFAM/MEFISTO_analyses)；提交/版本：`3310b5f285e49672d07438ca4878aa5eef77816c`。许可与原论文代码/当前包分层详见本案source-manifest和paper-source。

### Augur

Fig1b：Augur与朴素随机森林的细胞数—AUC稳健性曲线；Fig1d：模拟DE比例×效应量的AUC热图，均不能当作实测生物效应。

论文补充ZIP含原始calculate_auc计算代码；当前plot_lollipop文档指向ED7b。Fig1b/d的模拟表及正式绘图脚本未取得，不能用当前绘图函数替代。

固定抽样数、种子与标签；论文代码按细胞分层交叉验证，并非跨动物留出。AUC表征可分性，不是细胞比例、动物效应量或因果。

已看Fig1/2；补充包与当前包分别固定提交。原始demo为15697×600，各类型102对照/98处理；元数据只有位置行名，ID匹配未证实。

正式Fig1b/d图码配对缺失；demo不能替代模拟网格，旧Seurat有槽位兼容问题。2020-07-23更正记录原PDF扩展图页替换问题，ED编号需另核。

固定代码来源：[https://github.com/neurorestore/Augur](https://github.com/neurorestore/Augur)；提交/版本：`b252b84e4af687d9817813b1db409267eb44ec3f`。许可与原论文代码/当前包分层详见本案source-manifest和paper-source。

### LIANA+

Fig5c/d：组别关联与通路富集矩阵；Fig5e–g：同一空间切片的NMF载荷和相互作用余弦相似度；Fig5l：配体/受体分组logFC。

LIANA+、Scanpy、decoupler及原始liana-plus-manuscript中的kuppe分析笔记本；精确面板映射在code-figure-mapping.json。

空间面板共用坐标、朝向与掩膜；载荷、相似度、logFC采用各自单位与色标。热图星号绑定原始校正p值，不能由颜色阈值反推。

已看正式原图；SourceData中Fig5c/d的BH多重校正可独立核验，检查已执行。

潜因子与先验网络不直接证明通讯机制或因果；全量空间模型未重算，正式最终图未重绘。

固定代码来源：[https://github.com/saezlab/lianaplus_manuscript](https://github.com/saezlab/lianaplus_manuscript)；提交/版本：`37c712d280ed4f6ef55cd17490366c2f062ee513`。许可与原论文代码/当前包分层详见本案source-manifest和paper-source。

### NicheNet

Fig2a/b：20个配体活性与31个靶基因调控潜力；Fig2c/d：10个肿瘤的31基因表达及p-EMT评分，共享肿瘤/基因排序。

原作者hnscc_pemt_analysis.R：291–411预处理、420–456绘图、519–569组装；NicheNet提供配体靶基因矩阵与活性计算。

配体行、靶基因列及肿瘤行按键联动；源表达表0–9.41，原图经scale_quantile变成0–1。调控潜力与表达不能共用数值色标。

原图已看；用206 Range仅提取154156字节作者归档文件，CRC32通过；官方SourceData矩阵维度与值域已核。

先验预测不能当作已确认作用；原始大型单细胞对象未重算，正式完整图未重绘。

固定代码来源：[https://github.com/saeyslab/nichenetr](https://github.com/saeyslab/nichenetr)；提交/版本：`66f90d5eeafef280b2b2f339b3fd70ffec1781dd`。许可与原论文代码/当前包分层详见本案source-manifest和paper-source。

### Tangram

Fig2a：同一切片的细胞类型概率小多图；Fig2c：MERFISH实测与Tangram预测逐基因成对；Fig2d：留出基因空间相关的经验分布。

Tangram map_cells_to_space、project_genes与plot_utils；论文时期包和当前包分别固定，教程只提供调用合同，未取得正式最终组装脚本。

保留AnnData基因与观测键、空间坐标及训练/测试基因划分；逐基因图共用掩膜与方向。概率阵列不是细胞已确认的精确位置。

已看正式Fig1/2/4；小型教程score表的结构、排序、值域和训练标志共7项检查已执行。CDF仅作原图观察，未复算正式数据。

教程score表不是正式图的概率阵列；源码score为cosine similarity，不自行称Pearson。缺最终概率矩阵、正式组装和原始输入；模型未重算。

固定代码来源：[https://github.com/broadinstitute/Tangram](https://github.com/broadinstitute/Tangram)；提交/版本：`2ce1df5e481c925bbde74311ad6af29a4a61dc30`。许可与原论文代码/当前包分层详见本案source-manifest和paper-source。

### ArchR

Fig4e：11,999个峰—基因链接的可及性/RNA双轨迹热图；Fig4h正式图从左到右为motif deviation、gene score、RNA；Fig4f/g为hg19物理坐标轨道。

原作者ArchR_2020分析R自述ArchR0.2.1；getTrajectory、correlateTrajectories、trajectoryHeatmap、plotFootprints。正式browser最终组装调用未定位。

双热图共享链接键、行序与伪时间；各模态分别保留Z分数和色标。密集11,999行不授权稀疏输入压扁格子。伪时间不是实测时间，链接和足迹不单独证明因果或结合。

官方Fig3/4已打开；原补表核得70,239个唯一链接、9,389个基因坐标ID，均同染色体。HMGA1/BLK保留38条原字段，142个文本FDR及692个零值未改写。

分析库无LICENSE；Fig4h源码拼接motif/RNA/GS，与正式图次序不同。缺11,999条轨迹矩阵、旧版完整环境及browser组装；未重绘或检验新输入。

固定代码来源：[https://github.com/GreenleafLab/ArchR_2020](https://github.com/GreenleafLab/ArchR_2020)；提交/版本：`fe290efeecfa346552853c4ba24fe353b866a995`。许可与原论文代码/当前包分层详见本案source-manifest和paper-source。

### Signac

Fig2d：20×20比例热图，x为RNA真实注释、y为ATAC预测；Fig2h：校正后footprint与期望Tn5轨；Fig2l：MS4A1/LYZ的hg38 coverage、基因、峰、链接及RNA小提琴。

论文分析来自signac-paper；另固定Signac1.2.0实现。CoveragePlot、Footprint、PlotFootprint、LinkPeaks负责数据层，Seurat处理RNA与转移，patchwork组装组件。

Fig2d按真实RNA类别归一化，显示每列合计1。coverage按组深度归一化后作100bp中心滚动和。LinkPeaks的pnorm(-abs(z))是名义模型P，不能改成双尾P或FDR。

官方Fig2/3已打开；独立合成小核验确认深度成比例时coverage相等、z约1.96对应原算法P=0.025，并核混淆矩阵方向；未冒充原PBMC复算。

Fig3更正删错误n=6，保留20个cell types，并非20个供体。分析库无LICENSE，包MIT许可另计。缺PBMC对象与links；最终全图组装、原数据重算和重绘均未执行。

固定代码来源：[https://github.com/timoast/signac-paper](https://github.com/timoast/signac-paper)；提交/版本：`1cdbb6dd6a5ad817bd23bb7d65319d5bf802455f`。许可与原论文代码/当前包分层详见本案source-manifest和paper-source。

### SEACells

Fig3a：metacell/单细胞表达—峰可及性散点；Fig3b：NFR配metacell关联、全片段配单细胞关联的coverage与弧；Fig3e：两种TF-target方案的预测误差活动热图。

SEACellsReproducibility原始Fig3AB_Fig4B、Fig3CD及Fig1笔记本。compute_coverage/plot_coverage画轨道；spearmanr、np.cov和clustermap分别负责相关、协方差和热图。

同一ATAC metacell归属配对聚合RNA/ATAC；散点报告Spearman、峰关联模型用Pearson。Fig3e共享伪时间列序，颜色为带符号预测误差变化；metacell不是独立供体n。

官方Fig1/3/5已打开；原输出提取6,881个细胞计数。TAL1输出0.8274、正式图0.82。合成秩分箱核出最大边界风险，未推定实际细胞丢失或论文结论改变。

原模型/矩阵未重算。源码LassoCV为5折、论文写10折；coverage NFR≤145与峰调用<147属于不同阶段。Fig1协方差两色尺相差10倍；TF活动是模型推断。

固定代码来源：[https://github.com/dpeerlab/SEACellsReproducibility](https://github.com/dpeerlab/SEACellsReproducibility)；提交/版本：`85787bd2f254d6f09b663dade835798778c367ea`。许可与原论文代码/当前包分层详见本案source-manifest和paper-source。

### Milo

Fig4c：固定UMAP邻域图；Fig4d：TEC分面蜂群与独立研究方向箭头；Fig4f：DA秩曲线及同序邻域表达热图。另学Fig5的跨数据沿用及配色问题。

miloR plotNhoodGraphDA、plotNhoodExpressionDA；ggbeeswarm与patchwork。原始mouse_thymus-figures_revision.Rmd:326–438,508–537。

节点为重叠邻域，样本单位为小鼠/供体。热图列按logFC秩，行逐基因min-max到0–1，不是z-score。左侧箭头与分面按同一细胞类型键对齐。

7个作者文件与固定提交Git blob一致；CSV行宽和min-max算术已核；FDR文字1%与代码10%的冲突已记录。

FDR及marker阈值文字/代码冲突、Fig5配色翻转、Tcells (1)重复join风险均已记。4f调用logcounts、5f调用counts，缓存assay未核。处理对象未取得，CP2–CP4与正式重绘未运行。

固定代码来源：[https://github.com/MarioniLab/milo_analysis_2020](https://github.com/MarioniLab/milo_analysis_2020)；提交/版本：`99c1c1ce858fc39fd6c4033d4a17348f610d18d1`。许可与原论文代码/当前包分层详见本案source-manifest和paper-source。

## 快速定位与实际新图使用

先用`find_figure_reference.py --query "CellRank 环形命运投影"`找紧凑卡，或用包名加图型词；十篇均核验进入前三。再用`retrieve_learned_methods.py --case-id BENCH-subjournal-cellrank-2022`取完整原图、代码、合同、失败修法及哈希。脚本均位于本skill的`scripts/`。分类浏览入口为`library/按图型检索/`，保留相同ID。

开始新图时先确认问题、单位、数据字段和比较方向；读取选定学习卡及code-figure-mapping，采用或明确拒绝来源决定。锁定排序主键、归一化、统计阈值、类别颜色、空间/基因组坐标、显示行列及最终物理尺寸；再fresh prepare/CP2和原生绘图，打开最终PNG/PDF逐项与原图对照。旧来源学习或历史固定输入PASS不转授。

此前三角图的密集度与重叠问题仍适用：不得靠缩字或删数据掩盖差异；稀疏热图核物理方格，密集例外须由实际显示维度与最终毫米几何支持。NicheNet/ArchR等正式图的长方形格子只记录其来源版式，不自动成为新输入的许可。

## 证据与交付

- [十页原图学习册](../../results/figures/nature-subjournal-ten-source-learning-2026-10-15.pdf)：一篇一页，完整原图配图外学习注释；PDF嵌入像素与原PNG逐像素一致。
- [批次核验](../../results/tables/subjournal-ten-source-learning-validation-2026-10-15.json)：文件身份、原图审阅、十条检索、旧记录保留及独立小检查的范围。
- [学习册输入规范](../../results/tables/subjournal-ten-atlas-spec-2026-10-15.json)与[页级来源清单](../../results/tables/subjournal-ten-atlas-manifest-2026-10-15.json)。生成脚本为`../../scripts/create_subjournal_learning_atlas.py`，检查脚本为`../../scripts/validate_subjournal_source_learning.py`。
- 每包保留paper-source、source-manifest、code-figure-mapping、nonrender-checks、learning.md及本地来源原字节；大模型/原始矩阵未下载或未运行的部分逐案列明。源码无LICENSE与出版图权利分别记录，本轮仅本地研究学习，未公开发布。

当前总学习索引454条，benchmark registry281条。本轮新增10条，其余444个索引ID、271条registry记录和25份旧案例文件均按启动快照核验保留。检索/注册通过不等于成图、原图复现或任意数据稳定复现通过。
