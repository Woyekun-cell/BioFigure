# 学习与 Benchmark 总入口

索引覆盖全部已学记录；发现阶段按图型、数据含义与科研问题检索，避免先读全部主题与完整JSON。同主题继续追加。原图、源码、运行、原图对照、新输入迁移和用户验收分别记录。

```bash
python3 scripts/find_figure_reference.py --query "相关气泡图 分组 correlation"
python3 scripts/find_figure_reference.py --case-id SCICASE-024
python3 scripts/find_figure_reference.py --list-types
python3 scripts/find_figure_reference.py --type "森林图" --query "置信区间"
python3 scripts/retrieve_learned_methods.py --case-id SCICASE-024
```

第一步默认前三条定位卡，不调用R、PDF或复用认证；按原始ID绑定路径。来源页资产可能含教程拼图/复现图，不能自动当论文原图；代码预览仅前两个片段，选ID后读全合同。材料缺失/配对冲突必须重审。第二步看卡；第三步只读选定合同、必读材料与原图。将`learned_method_id`写入request重新prepare，CP2说明采用/拒绝、数据适配及缺陷处理。正式门禁完整，不用轻检索替代。

轻索引`atlas/figure-reference-catalog.json`自动按完整索引及生成器内容哈希失效；`--refresh`重建。新增学习仍先运行`build_learned_method_index.py`，同步生成轻索引。历史登记不代表当前资格；原图质量需人工看图，排名只反映元数据匹配。

分类入口：`library/按图型检索/类别/来源图、对应代码/图型_用途_原ID/`，保留原始文件，用中文相对软链接集中浏览。`00_分类总索引.tsv`保留原名、路径、哈希、图/码定位和风险；`01_链接清单.json`用于核验、重建与限定清理。复合图有交叉入口；论文总览、无明确图型及已知配对冲突分列。分类依据标题/图合同，不从绘图包或错误旧标签推断。来源页候选不等于论文原图，代码回原路径执行以保留依赖；40条旧分段待核提示保留。更新学习后运行`python3 scripts/organize_figure_library.py --refresh`；先验哈希/冲突，同名普通文件或错误软链接拒绝覆盖，未列文件不清理。
## 全部主题

- [点线透明与描边](mark-opacity.md)：[十篇顶刊源图学习](mark-opacity-sources.md)，重叠点/背景边/分布填充/主要证据分层；参数为BioFigure建议起点，原图观察与源码证实分开。`atlas/mark-opacity-study-20261013.json`保留图/码来源和当前查看hash，三张R helper验证图只认证层级实现。

- SciDraw：157项，[案例入口](scidraw-benchmark-index.md)、[学习](scidraw-learning.md)。代码/源图配对与历史错误须重审；内部模拟不等于新输入迁移。
- 顶刊：83篇、365代码块、99期合集；[1–80](topjournal-001-080-learning.md)、[86/89/97/98](topjournal-081-100-learning.md)。训练序号不等于期号；源图与源码在`library/topjournal-corpus/`，复现材料在`benchmark/library/topjournal/`。缺原数据及未通过项保留。
- 单细胞七案： [Han](han-foregut-single-cell-learning.md)、[Wahle](wahle-retinal-single-cell-learning.md)、[Hochgerner](hochgerner-dentate-single-cell-learning.md)、[Trevino](trevino-cortex-single-cell-learning.md)、[Yu](yu-interneuron-single-cell-learning.md)、[Ma](ma-primate-pfc-single-cell-learning.md)、[Fleck五类方法](../library/single-cell/fleck-organoid/data/metadata/source-manifest.json)。源图/源码/输入缺口在`library/single-cell/*/data/metadata/source-manifest.json`；未证明整套原图复现。
- 基因组六案：`library/genomics/`中的ape-t2t、arabidopsis-27、barley-pantranscriptome、rpe1-reference、[大麻泛基因组](../library/genomics/cannabis-pangenome/data/metadata/source-manifest.json)、[DPM多组学](../library/genomics/dpm-multiomics/data/metadata/source-manifest.json)。29配方定位输入、源码与原图。新两案学习共线性双编码轨道、散点边际分布、方向热图、气泡阵列、证据网络；作者表与原码缺口分别记录，未运行原图渲染。旧案选定结构模拟/表重绘不等于原文数值、全图或全流程复现。
- [Nature基因组/多组学六案](nature-genomics-multiomics-learning.md)：六篇、11选定图；限定作者表复算另记，仍为候选。
- [MBE冻融](msad040-visualization-learning.md)：23主面板、22补图及补表；S5/S9/S13限定重绘，无作者绘图源码。
- [番茄泛基因组](pangenome-learning.md)：15选图合同及统计/源码差异；Fig2a–c源表重绘，不等于全流程。
- [awesome视觉布局](awesome-scientific-figure-learning.md)：29图位、12布局合同；视觉语法不认证原科学方法或数据。
- [六项目](six-project-benchmark-learning.md)、`benchmark/cases/`、`benchmark/evidence/`：mCA、Pearson、RA、QC、Populus、TooManyCells及已验收合同；固定结构成功不继承为新数据PASS。
- `benchmark/library/core-examples/`：线性、桑基、ANOVA和三角相似度等基础样例，方法及数据边界分别保留。

## 状态与复用

读[全量迁移](all-learning-transfer.md)、[缺陷](all-learning-audit-defects.md)及[固定样例重复](stable-template-reuse.md)。源码与历史PASS只是证据；每条方法通过新输入、压力、独立复跑和终尺寸验收后，登记持久验证表。每次调用重新验哈希，不靠对话记忆。

问题/单位 → 检索/选定方法 → CP2 → 编码 → 终尺寸成图审查 → 归档原主题。保留原始输入、脚本、终图、环境及QC；唯一work证据迁移并验哈希前禁止清理。

复杂基因组作者数据图与图库修订：见[八例来源与方法索引](genomics-source-gallery-learning-20261011.md)。

新增作者源码基因组案例：[鳞翅目 Merian 染色体涂色 Fig.4b](lepidoptera-merian-paints-learning.md)。Nature Ecology & Evolution 2024；5物种真实枝长系统树＋120条染色体、20,316 BUSCO位点。固定源码、S4/S10、原图、native R处理/绘图与独立复跑在 `benchmark/library/genomics/lepidoptera-chromosome-evolution/`；检索 `BENCH-genomics-lepidoptera-merian-paints-2024`。

新增单细胞环形源码案例：[环形UMAP／t-SNE外圈注释 plot1cell](circular-embedding-plot1cell-learning.md)。MIT原生circlize代码＋Cell Metabolism2024正式Fig1F/G作者代码对照；Nature Communications2022完整102710保存坐标作为方法迁移演示。包括共尺度坐标、log10计数扇区、MASS全局KDE、分类颜色对齐和三层轨道；没有percent.mt。自包含资料在 `benchmark/library/single-cell/circular-embedding-plot1cell/`，检索 `BENCH-singlecell-circular-embedding-plot1cell`；完成范围以绑定bundle为准。

## 2026-10-12 组学源码与原图学习

- [TE–TF motif Atlas](te-tf-motif-atlas-learning.md)：Nature Communications 2023，原生ComplexHeatmap重绘限定Fig3a/b；14×35、三组切片/四树及558散点，保留负值、原ID和作者既有统计。实际PDF与独立原始附表复跑通过；源caption/执行代码的mean与min、非中心化缩放差异已记录。检索 `BENCH-epigenomics-te-tf-motif-atlas`。
- [HMO转录组–糖组学](hmo-gene-reaction-learning.md)：Nature Communications 2022，真实源码、处理表与预印本/正式数据差异已学习。文字网络＋矩阵版被用户拒绝，当前只计源码学习，不计原图复现或视觉PASS；原版式SNFG修订另存variants，不借独立复跑相同宣称源图一致。检索 `BENCH-multiomics-hmo-gene-reaction`。

- [HMO正式Fig4 SNFG修订](hmo-snfg-fig4-learning.md)：31节点/40反应＋3异构体、196糖符/163糖苷键；原图结构版式审查与独立复跑分别通过，正式权重线宽/字体/灰扇形差异保留。代码、源数据、原图对照及限定资格在`benchmark/library/multiomics/hmo-gene-reaction/variants/fig4-snfg/`；检索`BENCH-multiomics-hmo-snfg-fig4`。用户验收/新输入迁移未验证，旧文字网络仍为拒绝。

## 2026-10-13 复杂组学源码与布局规则

以下三案已核原图、固定作者源码、处理后数据与代码行号；均为**源码学习和非绘图验证**，本轮未渲染新图、未授予原图复现资格。每案的输入合同、关键包、排序与坐标、颜色含义、导出和缺口保存在案例包，按需检索，不扩张核心技能规则。

- [水稻着丝粒多轨共线性](../benchmark/library/genomics/rice-centromere-multitrack-2025/learning.md)，Nature Genetics 2025：Fig5a相邻材料共线性带、Fig6d十材料信号与五级注释轨，另学Fig4重复层级处理。重点为基因组原点平移、原始行序/ID、配对去重、ED多边形、共有物理比例和显式样本顺序。真实例表保留5,900条Chr01注释、1,799配对；只有8对具仓库示例ED，25条全表反向区间保留异常记录。`ggplot2`、`Cairo`、`cowplot`和Python处理职责分列；示例不是正式图同批输入。检索 `BENCH-genomics-rice-centromere-multitrack-2025`。
- [ChromaFold多分辨率接触图与基因组轨道](../benchmark/library/epigenomics/chromafold-multiresolution-contact-atlas/learning.md)，Nature Communications 2024：Fig2a/c、4a/b，解析V-stripe重组、45°格点、大上下文/小显示窗、50/500/10,000 bp对齐、Jaccard聚合、跨轨高亮与分层高度。`NumPy/pandas`处理矩阵，`Matplotlib`绘非正交格点，`CoolBox`组织基因和弧轨。13项模拟几何和8项真实IMR-90 chr19矩阵检查通过；真实矩阵5862×5862，非Figure4小鼠原数据。最终组版和部分参数块缺失。检索 `BENCH-epigenomics-chromafold-multiresolution-contact-atlas`。
- [mofaCLL连续因子排序热图与通路归属网络](../benchmark/library/multiomics/mofacll-proliferative-drive/learning.md)，Nature Cancer 2021：Fig4d及ED6a–c，学习基因按回归系数、患者按CLL-PD排序且不聚类，逐行标准化/截断、三热图并排和共享基因节点。`ComplexHeatmap/circlize`组织矩阵与注释，`igraph/ggraph/tidygraph`布局通路归属图。正式源表和作者建图代码得到228节点/245边；已处理模型5000×217 RNA中15例整模态缺失，202例用于排序/缩放核验。76个MitoCarta注释基因不等同mtDNA编码基因；训练矩阵不冒充ED6完整矩阵。检索 `BENCH-multiomics-mofacll-proliferative-drive`。

复用时先读这些已查明的风险：默认发散色带未必以0为白色；随机种子不保证跨包版本坐标相同；缺ED/缺失矩阵值不可补成观测0；信号平滑需按染色体和样本分组；三角接触图不可按值重排行列或只裁200×200矩阵替代700×700上下文。正式绘图另行绑定输入和环境、核对原图面板边界与终尺寸输出。

## 2026-10-13 作者原生代码复现：三项目六图

本轮同时完成三个作者项目的源码学习、完整固定输入成图、独立复跑和逐图原图对照。先检索下列 ID，再读各自学习卡、原图差异、输入合同与 fresh 调用入口。当前结果只限定这些固定作者样例，不能自动继承为任意新输入或整篇论文复现。

- [gggenomes EMales](gggenomes-emales-learning.md)：`BENCH-gggenomes-emales-2026`。六病毒多轨主图与同数据方向同步测试；143基因、12TIR、3NGARO、2856GC窗口、222相邻蛋白连带。主图减少10个重复名称文字，不删除基因对象；图例显式固定Genes在上、GC在下，防止跨进程交换。固定gggenomes1.2.0；核酸/GFF/BED与蛋白aa2nuc坐标分开核验。
- [ggtranscript SOD1/PKNOX1](ggtranscript-sod1-learning.md)：`BENCH-ggtranscript-sod1-2026`。完整4/11条转录本，79外显子、共同间隔压缩、84个PKNOX1差异片段及201/203 half-range。压缩坐标仅供显示；原外显子长度和跨转录本对齐保持。两图白底换色和重新组合，非原图像素复刻。
- [ggsashimi剪接轨道](ggsashimi-splicing-learning.md)：`BENCH-ggsashimi-splicing-2026`。12个作者BAM库，overlay+shrink和mean+固定纵轴两图；90,204覆盖值、37原始junction逐值核验。保留源码1bp显示偏移及secondary/低MAPQ计数约定；显式R兼容补丁修复重复弧和面板错位。不能当作通用pileup默认算法。

[六页原图—复现对照](../../results/figures/deep-learning-source-comparison-2026-10-13.pdf)逐张列明映射与差异；[父级验收](../../results/tables/deep-learning-root-review-2026-10-13.json)绑定三包证据、六张最终图、数值与实际PDF测量。原始数据、图、源码、绘图CSV、环境、失败样例及复用入口均保留于`benchmark/library/`相应案例。源码冻结后先登记稳定路径，再统一fresh prepare/CP2；每次调用独立Spec副本，避免模板变动或registry/索引变动使回执失效。

## 2026-10-15：十篇Nature大子刊原图与代码学习

[十篇学习入口](nature-subjournal-ten-learning-20261015.md)：CellRank、MEFISTO、Augur、LIANA+、NicheNet、Tangram、ArchR、Signac、SEACells、Milo。18张原图、38组面板；合同/源码/来源/异常已保存，检索`BENCH-subjournal-<项目-年份>`。学习索引454、registry281；Augur/Tangram正式面板脚本有缺口。原图复现、新输入迁移、CP2–CP4及用户验收仍未认证。
