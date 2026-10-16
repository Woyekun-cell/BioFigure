# ggtranscript：转录本结构、间隔压缩与异构体差异

方法ID：`BENCH-ggtranscript-sod1-2026`。来源为作者的官方包教程，原始注释是真实参考基因组注释，并非实验测量或模拟覆盖信号。

## 来源与版本

- [官方教程](https://dzhang32.github.io/ggtranscript/articles/ggtranscript.html)、[源码](https://github.com/dzhang32/ggtranscript/tree/682a0df688ad242fa262d0b0557bf973dc202787)。
- ggtranscript 1.0.0；固定 commit `682a0df688ad242fa262d0b0557bf973dc202787`，MIT。官方网页图片下载于2026-10-13；网页未声明构建所用 commit，不能声称网页与锁定源码逐像素同版本。
- 方法论文：Gustavsson et al., Bioinformatics (2022)，[DOI:10.1093/bioinformatics/btac409](https://doi.org/10.1093/bioinformatics/btac409)。本次复现对象为教程图，不是论文整图。
- 包内 `sod1_annotation.rda` 与 `pknox1_annotation.rda` 来自 Ensembl105、GRCh38/hg38，提取过程保存在 `sources/data-raw/sod1_pknox1_annotation.R`。作者保留 `transcript_name`，未保留 ENST ID；不得补造。
- 本次未采用 junction/GTEx counts、coverage 或模拟突变。作者教程这些材料不能混写为本次输入。

全部原始RDA、固定源码压缩包、源码/许可证、官网原图均在 `benchmark/library/transcriptomics/ggtranscript-sod1/` 保留；`case-candidate.json` 是初始来源登记，不是最终验收记录。

## 输入与科学合同

输入需有 `seqnames, start, end, strand, type, gene_name, transcript_name, transcript_biotype`。GTF注释是1-based closed；当前两基因均为chr21正链。

| 固定样例 | 转录本 | 外显子 | 内含子连接 |
|---|---:|---:|---:|
| SOD1 | 4 | 20 | 16 |
| PKNOX1 | 11 | 59 | 48 |

每个转录本的相邻外显子由 `to_intron()` 连接。其绘图区间使用相邻外显子的边界，即前一exon的end到后一exon的start；不能直接当作真实GTF内含子坐标。不得把这些结构行视为生物重复或表达量；本图无统计推断。

`shorten_gaps()` 先计算不与任何输入exon重叠的共同间隔，再把超过目标宽度的间隔缩短。本例 `target_gap_width=100L`。不能逐转录本独立缩短，否则共享exon会错位。输出仅为显示坐标，exon长度保留；必须标为“Shortened coordinate (bp)”，不能套用染色体基因组坐标。当前包的相对坐标起始为2，该原生行为原样保留。

`to_diff()` 对每个转录本与参考转录本的exon集合进行区间拆分和重叠判断。`in_ref` 是仅参考具有的区间，`not_in_ref` 是当前转录本具有而参考没有的区间。它不推断差异表达、剪接比例或功能后果。PKNOX1以201为参考；84个差异片段保留。

## 原生函数职责与实际执行

| 函数 | 本次职责与边界 |
|---|---|
| `geom_range()` | 直接绘制exon或差异区间；映射 `xstart/xend/y`，并用fill编码biotype或difference。 |
| `geom_intron()` | 原生绘制连接和中央链方向箭头；`strand`明确为正链。 |
| `to_intron()` | 从完整exon记录生成连接；按transcript_name分组，保留所有连接。 |
| `shorten_gaps()` | 按共同非exon间隔压缩到100bp，保留exon长度和跨转录本对齐。 |
| `to_diff()` | 计算PKNOX1相对于201的集合差异；准备阶段也核验SOD1差异。 |
| `geom_half_range()` | PKNOX1-201画下半、203画上半，21个exon、19个intron；保留共享中心线。 |

以上全部实际执行，几何来自安装后的原生ggtranscript包，未用基础矩形/线段仿造包功能。ggplot2负责刻度、主题与面板组合；图例小色块不替代数据几何。GenomicRanges承担原生区间处理，GenomeInfoDb承担序列层级修剪。

UTR/CDS重叠绘制、junction曲线和计数标签仅源码学习；未进入交付图，不能登记为本次实际绘图能力。

## 两张图与原图对应

1. `sod1-structure.pdf`，136×100mm：a完整对应官方 `geom-range-intron` 四行图；b把官方 `shorten_gaps()` 移植到同一SOD1输入。这是明确的包内数据适配，不是假称原官网已有此SOD1压缩图。
2. `pknox1-comparison.pdf`，180×119mm：a对应官方 `shorten-gaps`；b对应官方 `to-diff`；c对应官方 `geom-half-range`。三幅完整教程图组合成新布局，11行没有删减。

显式改动：官方默认灰背景变白底；生物类型改为具名青绿/铜橙/金/紫；差异遮罩保留分类并改为铜橙/青绿；half-range为201深蓝灰、203紫。数据描边0.18–0.28mm；箭头0.9mm。图例由右侧移到专门的外部空带。常规文字7.5pt、轴标题8pt、面板字母9pt，Arial/Arial Bold。不是原图像素复刻。

`arrow.min.intron.length` 原始SOD1用500bp、压缩坐标用300bp，以避免短内含子箭头盖住相邻exon。抑制短区间箭头不删除内含子线；仍保留真实strand元数据。

## 已验证与未验证

已完成：fresh prepare/CP2、一次性授权的 `bf_render_png()`、两次独立R进程，PNG像素和PDF150dpi栅格完全一致；完整PNG与96dpi终尺寸PDF视图已打开。

独立Python实现逐碱基集合核验：79个exon映射端点、全部转录本相对201的差异集合、共同gap压缩坐标与原生输出一致。原生QC也核对了所有exon长度、相邻exon连接以及压缩前后每转录本差异bp总数。

实际PDF审计：136×100mm和180×119mm单页；ArialMT/Arial-BoldMT；有效字号7.500001/8/9pt；无替换字、越界字符。词框检测为0重叠，实际全图审查未见压字、裁切或行错位。PNG/PDF复跑一致不代表原图像素相同。

失败输入实测：缺strand、混染色体、混strand的shorten_gaps输入正确报错。其他未知物种、长ID、大量转录本、负链、单exon等尚未完成转移/压力验证；不得宣称任意输入通用PASS。原论文整图、用户验收未验证。

## 复跑与封存

工作目录任取新的可写路径；共享R库不修改。

```bash
python3 scripts/install_dependencies.py <新工作目录>
Rscript scripts/prepare_data.R <本案例绝对路径> <新工作目录>/R-lib
python3 scripts/validate_intervals.py
python3 scripts/fresh_call.py <新工作目录>/R-lib <新输出目录>
```

命令在案例根目录使用，或将scripts替换为绝对路径。依赖来自已存档源码：ggtranscript1.0.0 MIT；GenomeInfoDb1.48.0和UCSC.utils1.8.0 Artistic-2.0。余下依赖版本随session记录。隔离安装过程不升级共享库。

`fresh_call.py` 为每幅重新检索来源、prepare、绑定当前read hashes、核验CP2，再签发一次性授权并原生渲染；输出目录不得复用已消费授权。它不自动声明视觉PASS。每次变更数据、环境或布局后仍必须打开新PNG/PDF、重新做源图比对与终尺寸审查。原图哈希变化会中止，需先重新学习。

稳定复用范围仅上述固定官方注释样例。数据、变换CSV在 `results/plot_data/`；原始输入 `data/raw/`；最终PDF在 `results/figures/`；技术/视觉证据在 `results/qa/`。来源差异记录在 `data/metadata/source-difference-review.json`。封存时索引更新后的最终fresh-call另有证据，不能沿用更新前的门禁回执。
