# 六个项目的源码学习与 Benchmark 进度

更新：2026-09-26。只把核验过的项目内容归入 BioFigure；源码静读、作者执行输出、独立编程复现、原数据复算分开记。当前有 3 个 source-exposed 独立编程案例、2 个 source-output 对齐案例及 1 个设计方法原图审计；不代表模型权重更新。

## 六项目核对

| 项目 | 已读内容与结论 | 状态/阻断 |
|---|---|---|
| `genecell/single-cell-papers-with-code` | 从索引锁定 Luecken & Theis 2019 Figure 2、作者 `QC_plots.ipynb`、正式原图与固定提交。看图和源码后用 R/ggplot2+patchwork 独立实现 A–D：全分布与 inset、基因分布、log barcode-rank、counts–genes+线粒体比例色条。 | 结构/视觉复现完成并在最终尺寸核对；不要求像素或逐值恒等。 |
| `caleblareau/pearson_syndrome` | 固定提交内的 Fig. 6b–e 作者 PNG、`03_visualize.R` 和正式 Fig. 6 已锁定；在此基础上独立用 R 重建共享 UMAP 合同、异质性连续色、细胞类群分类色、6 个 ADT 小面板和 del7q 二分类。图示细胞来自单一患者 PT3，不能把细胞数当患者 n。 | source-exposed 独立结构复现完成；使用固定种子结构数据，不作数值或生物效应复现声明，完整 V2 门禁待跑。 |
| `jingwanglab/Populus_3D_genome_evolution` | Nature Ecology & Evolution Fig. 2b；源码 `Figure2bcd.R` 第 1–16 行给出十物种顺序、四类 A/B 状态及 `position="fill"`；正式图与脚本有外观差异。按官方 Sup Tab5 独立提取并绘制 40 个比例值，10 组各 4 类，最大闭合误差约 `1.11e-15`。使用 `geom_col(position_stack)` 保留已闭合比例，图中不写显著性；Ks 带只表示源支持的顺序。 | Fig. 2b source-exposed 独立复现完成；作者脚本未执行，非盲测。Bundle、CP0–CP4、六项科学检查均通过。 |
| `the-blundell-lab/mCA-mutation-rates-fitness-consequences` | Fig. 2a 的公开派生参数表、完整 notebook cell 12 和作者执行输出均已锁定。BioFigure 用 R 从 105 个 mCA 的 `s`、`mu` 与 95% 区间独立重跑双栏 league table；行序、三类颜色、线性/对数轴、区间与数值列逐项核对。Fig. 1 仍依赖受控 UK Biobank 参与者数据。 | Fig. 2a source-exposed 独立重跑完成；非原始参与者数据复算，尚未走完整 CP0–CP4。 |
| `immunogenomics/RA_ATAC_multiome` | 锁定 Fig. 2、`Tcell_figures.ipynb` 及执行输出后，独立用 R 重建五类 UMAP、7×ATAC/RNA 双排 21-bin hex summary、TBX21 chromVAR、motif 热图、KLRG1 UMAP 与对齐的位点轨迹。收到视觉反馈后增大散点、增加细胞密度并为共享 UMAP 加连通桥接，降低原模拟团块间空隙。 | source-exposed 独立结构复现完成；固定种子结构数据不作数值声明。作者 UMAP 坐标不可用；2d 右轨迹仅据正式原图学习，因 notebook 无其生成源码。 |
| `wp-a/nature-figure` | 设计 Skill 与工作流，不是单篇论文。用官方 Nature 原图 s41586-026-10408-8 Fig. 1 与 s41586-026-10426-6 Fig. 2 检查“主导示意图+安静证据行”和“暗底影像板+固定通道语义”。 | 两条规律获原图支持；固定提交文档声称内置 `assets/`，但仓库无该目录，记为证据缺口。 |

逐仓库固定提交、文件哈希、panel/cell 映射及阻断项见任务留档 `work/2026-09-26-six-repositories/pending_source_audit/figure_code_map.md` 和 `source_manifest.json`。这些摘要不替代引用的原文、补充数据与作者仓库。

## Populus Fig. 2b 学到的可迁移规则

1. **分别锁两种真值**：官方补充表决定数值，正式发表图决定最终配色、标签、面板框和装饰。作者脚本是实现线索，不自动等于期刊最终版。
2. **先判值是否已闭合**：计数且分母正确时才组内归一化；源表已给闭合比例时用 `geom_col(position_stack)`，避免 `position_fill()` 二次归一化。
3. **保留实体键与顺序**：严格验证 10 个物种、每组 4 个状态及其顺序；40 kb 同源 bins 是比例分母，不是独立重复。
4. **装饰编码也需证据**：源图 Ks 色带可作排序提示；因输入没有具体 Ks 值，不得把带宽或梯度解释成定量 Ks。
5. **按子图物理尺度核对**：本例 90×54 mm 是从子图占全图约半宽推得的尺寸估计；需记录为推断，不得把它当期刊公布尺寸。保持边框、图例、轴、柱、色带和标签的相对位置后，再看实际目标尺寸 PNG。
6. **逐项量图例几何**：初版 4 mm 色块和不透明图例底色让顶边线被遮、图例整体偏窄；原尺寸对照发现了自动验收未发现的问题。按 930×560 参考裁片归一后调到 2.2 mm 键高、4.7 mm 横向间距、0.48 横锚点，并让图例背景透明；复查确认键尺寸、总宽和边框均与原图对齐。Design Spec 的 `inside_top` 位置只在独立图例框与数据框经渲染预检确认不重叠时通过。
7. **单一坐标系减少拼版误差**：BioFigure `bf_render_png` 当前按单个 ggplot 做对象预检；本例将顺序带作为 `annotation_raster` 放进同一绘图区，避免 patchwork 对象不能通过入口预检。

## 新增案例学到的规则

1. **mCA 双栏 league table**：同一实体的两种参数必须共享行顺序；左栏线性轴、右栏对数轴不可为排版方便统一尺度。置信区间超出视窗时保留裁切语义，数值列放在绘图区外并按最终尺寸检查。
2. **共享嵌入是跨面板合同**：Pearson 独立复现进一步验证分类、连续信号、六特征小面板和二分类状态必须复用同一坐标和点集；禁止逐面板重算 UMAP 或缩放坐标。嵌套小面板必须显式分配主面板字母，不能让组图工具自动漂移编号。
3. **颜色跟随变量类型**：类别用固定离散色；表达量用顺序色；正负 chromVAR 用以 0 为中心的发散色；del7q/WT 用二分类色。图例标题、位置和色标范围属于验收对象。
4. **作者执行输出是强实现证据，不是原数据复现**：它可证明代码实际产出与论文面板对应；缺少主对象或受控矩阵时，不能把重新拼版称为数据重算。
5. **缺失源码单独降级**：RA Fig. 2d 右侧没有锁定生成源码；允许据正式原图学习其轨道拓扑，但必须标明该面板的证据只到原图结构，不能称作者源码复现。
6. **细胞嵌入与特征汇总分开**：RA Fig. 2a、c、d 左均是 cell-level `geom_point`；只有 b 的 feature grid 调用作者 `plot_markerPeaks_norm_hex_v2`，内部 `stat_summary_hex(bins=21)` 汇总六边形内信号。不要把全部 UMAP 改成热图。
6. **复现目标先分层**：图表 benchmark 优先复现 panel topology、视觉编码、层级、图例和最终尺寸；数值一致与像素一致单列，不作为默认完成条件。
7. **inset 不参与自动编号**：patchwork 自动 tag 会把 inset 计作子图，造成 A/B/C/D 错位；复现时给四个主面板显式 tag，inset 保持无 tag。
8. **连续质量色条归属散点图**：线粒体比例用连续顺序色，色条固定在 D 面板右侧；不得挤入数据区或让整组图重复图例。
9. **设计 Skill 也需原图审计**：抽取其声称的版式规律后回到官方论文图逐条查证；仓库文档与实际文件树不一致时标 `CONTRADICTED`，不补造缺失示例。

## 本例证据

- Case：`POPULUS-FIG2B-SOURCE-001`；Pattern `COMP-STACK-001` 保持 `candidate`，一个复现例不足以证明整个图型覆盖。
- 最终运行：`run_v2_19`，BioFigure V2 runner，`source-exposed-independent`；比例 CSV、官方工作簿、完整 Figure 2、裁剪参考、来源锁、方法计划、Design Spec、R 脚本、样式助手、环境与渲染回执哈希均入包。v2.19 已替换掉图例尺寸/位置不符的初版，并用新的 PNG 哈希复验 Critic、CP0–CP4 与 bundle。
- 视觉比较：`benchmark/evidence/populus-fig2b-source-001/review/comparison.png`；正式图原件和证据 bundle 仅保存在本机，不随仓库发布。
- Bundle audit、Design Spec、Pattern、CP0–CP4 与 Critics 是不同验证层；当前仅 Populus 面板通过完整门禁。mCA 是公开派生表的独立重跑；Pearson、RA 与单细胞 QC 已完成独立结构复现。transfer/stress 均未测，不能称 BioFigure 已整体受训或模型权重已更新。

## 本地案例路径

- 总览：`work/2026-09-26-six-repositories/benchmark_gallery_current.png`。
- mCA：`biofigure-case-mca-fig2a/`，含数据、来源锁、R 脚本、作者输出、重跑图和并排对照。
- Pearson：`biofigure-case-pearson-fig6/`，含 Fig. 6b–e 作者输出锁、固定种子结构数据、独立 R 脚本、PNG/PDF、正式图对照与检查回执。
- RA：`biofigure-case-ra-fig2/`，含 notebook cell 输出、独立 R 脚本、结构数据、PNG/PDF、正式图对照、Design Spec 与检查回执。
- 单细胞 QC：`biofigure-case-singlecell-qc/`，含论文原图、作者 notebook 锁定信息、独立 R 脚本、最终 PNG/PDF 与对照板。
- nature-figure 审计：`biofigure-case-nature-figure-audit/`，含两张官方 Nature 原图、逐条结论表和证据板。

## 原始来源

- Populus 论文与 Fig. 2：[Nature Fig. 2](https://www.nature.com/articles/s41559-026-03069-3/figures/2)；作者代码固定提交：[Figure2bcd.R](https://github.com/jingwanglab/Populus_3D_genome_evolution/tree/70d98b88fbcbf7ec0dcf8e2c0c56d69dfea27969/7-Figure%20plot/Figure2/Figure2bcd.R)；Table 5 下载地址、文件 SHA-256 和本地保存规则见 `work/2026-09-26-six-repositories/original_figures/source_receipt.json`。
- Pearson：[论文 Fig. 6](https://pmc.ncbi.nlm.nih.gov/articles/PMC10548551/)；[作者仓库固定提交](https://github.com/caleblareau/pearson_syndrome/tree/e5adb96770f286b60d880378a7c823163229a3f9)。
- mCA：[论文](https://pmc.ncbi.nlm.nih.gov/articles/PMC10562253/)；[作者仓库固定提交](https://github.com/the-blundell-lab/mCA-mutation-rates-fitness-consequences/tree/4f70f4db0702a35556b5fe8cd7b85e6acfe7bd39)。
- RA ATAC：[论文 Fig. 2](https://pmc.ncbi.nlm.nih.gov/articles/PMC11143375/)；[作者仓库固定提交](https://github.com/immunogenomics/RA_ATAC_multiome/tree/88f1d3f34fb911649ebce17722ef3bd17356060)。
- 发现索引与设计方法：[single-cell-papers-with-code 固定提交](https://github.com/genecell/single-cell-papers-with-code/tree/7f163c878faf6d8d2e7ef23ff5e04b0edd3057a8)；[nature-figure 固定提交](https://github.com/wp-a/nature-figure/tree/57d7a8557467edeceff54e03b76814def4724f1b)。
