# ggsashimi：BAM 剪接覆盖、叠加与内含子压缩

来源：Garrido-Martín et al., PLoS Computational Biology 2018, DOI [10.1371/journal.pcbi.1006360](https://doi.org/10.1371/journal.pcbi.1006360)。作者[仓库](https://github.com/guigolab/ggsashimi)固定 commit `a6d3c81a96831489fddc7de00aece92d301d0164`，MIT。学习范围是官方 examples；不是重新分析原论文全部数据。

## 已核源码与原图

论文 Results 明示 12 个真实 ENCODE RNA-seq 样本，分为 Endothelial、Epithelial、Mesenchymal 三组；官方 TSV 每组四个 ENCLB 库，对应原始 ENCFF 文件。不是模拟数据；分组仅沿用作者分类，不额外认定四个库为四个独立生物重复。区域 `chr10:27040584-27048100`，7,517 个数组位置；BAM 为作者提取的小区域文件，GTF 注释轨道保留原始 ENST 版本 ID。

作者 Python/pysam 从 BAM 的 CIGAR 提取实际匹配覆盖与 N 剪接跳跃，生成 R/ggplot2/grid 的覆盖柱和 xspline 弧线。`GGSASHIMI_DEBUG=yes` 是作者提供的数据计算与 R 代码生成入口，无图像输出。最终图片须在 R 中走 BioFigure 一次授权 `bf_render_png`，不声称 Python 原生 CP3。

覆盖仅计 M，I/S 不推进参考位置，D 推进但不计覆盖；含 H/P/X/= 的整个 read 被排除。原程序不额外过滤低 MAPQ、duplicate 或 secondary alignment，计数单位为 alignment，不是独立样本数。输入坐标先转 `(start-1,end)`，而源码 `read.reference_start+1` 后计数，保留此混合边界行为以复现作者；不能将结果宣称为通用标准 pileup。N 的 donor/acceptor 以作者内部坐标输出；只保留严格落在内部的 junction，并在每个库执行 `-M 10` 门槛。稀有 junction 先被库内过滤，后聚合不能补作零值推断。

`--shrink` 从观察到的 intron 区间交集压缩长度到原长的 0.7 次幂，覆盖、弧线和 GTF 同步变换；x 刻度映回原始基因组值，但显示距离已非均匀基因组尺度。Overlay 的计数字符串按输入库次序列出。Mean 是位置覆盖的算术均值；junction 聚合使用通过阈值的记录，四舍五入显示，不能当作差异剪接统计或 PSI。

原图：三条组轨道垂直对齐，每轨叠加四个半透明覆盖；长跳跃位于下方，两个短弧上方，弧线粗细映射组内 junction count 相对量；下方共享坐标及14条转录本。官方 `examples/sashimi.pdf` 配橙/蓝/绿，仓库根 `sashimi.png` 配红/绿/蓝，两者不可混称完全同一版本。互补视图为官方第二例的 mean+fixed-y、无 GTF、无 shrink。

## 本次适配与边界

本次已完成两次独立 fresh prepare/CP2 与固定输入复跑。原始 Python 数据算法保持不改；R 适配包含下述已证实的 overlay 聚合修复、ggplot2 4.x 的 gtable/label 兼容、最终尺寸、Arial 字体与授权导出。若出现实际差异须记录，不继承历史 PASS。独立复跑只验证固定样例；新输入迁移和结构压力测试均为 NOT_VERIFIED。图内仅科研文字，来源/证据边界放图外。

## 本次固定样例的具体发现（2026-10-13）

12 BAM 的头注释保留 hg19/GencodeV19 来源；本区域基因为 ABI1（ENSG00000136754.12），负链。共读取32,725 alignments，含843条 secondary 和1,600条 MAPQ<20，均由作者算法保留；未见 duplicate、supplementary 或 H/P/X/= read。独立 CIGAR tuple 实现与作者函数的90,204覆盖值、37条junction逐值一致，其中36条达到每库M10。上游相对于0-based参考起点整体偏移1bp，固定区间覆盖总和比常规0-based计数少2,246；此差异保留且显式披露，不把作者重放等同通用pileup正确。

当前上游 master 的 overlay 无aggregate代码生成 `round((count))`，data.table 每junction输出4行，使每组出现12条重复弧。实际首版失败图与原始 generated R 已留存。适配只在 R 组弧步骤替换为 `sum(count)`，每junction一条弧、宽度使用合并支持量；原四库计数字符串按TSV顺序保留。Mean 模式仍是 `round(mean(count))`，不受此替换影响。作者独立图层、xspline与随机种子原样使用。另修旧 gtable 整数位置索引，按真实panel列总左宽对齐，避免裁切和错位。

正式命名为“原生BAM计数 + 显式R兼容修复”；不说原脚本逐字直接产图。两次独立 fresh prepare/CP2、原Python运行与一次授权R渲染得到一致PNG/SVG哈希、逐字相同CSV；每图9弧。Overlay保留14条ENST、33个GTF exon segment；Mean无GTF，固定纵轴。实际PDF为180×150或180×100mm，7–10pt Arial，全矢量；PNG与PDF均已实际查看。Mean配色统一为官方overlay的橙/蓝/绿，和原TIFF的红/绿/蓝有所不同。固定样例通过不代表全新BAM迁移或结构压力资格；两项继续NOT_VERIFIED。

复用入口：`benchmark/library/transcriptomics/ggsashimi-splicing/scripts/fresh_replay.py`。必须重新读当前学习索引、prepare/CP2与最终图。科学审计入口：同包 `data/metadata/coordinate-filter-audit.json`、`assembly-provenance.json`、`source-difference-review.json`；实际双跑/PDF核验见 `evidence/independent-replay-and-PDF-QC.json`。

## 隔离环境与复跑

BAM计算已验证 Python3.14.7、pysam0.24.1（含htslib1.24）。不依赖现有临时venv；在任意可写的新work目录建立环境并使用永久源包：

```sh
python3 -m venv /absolute/work/ggsashimi-env
/absolute/work/ggsashimi-env/bin/python -m pip install -r /absolute/biofigure/benchmark/library/transcriptomics/ggsashimi-splicing/scripts/requirements-bam.txt
python3 /absolute/biofigure/benchmark/library/transcriptomics/ggsashimi-splicing/scripts/fresh_replay.py --run-dir /absolute/work/new-run --bam-python /absolute/work/ggsashimi-env/bin/python
```

上面需替换绝对路径；`python3`控制器使用BioFigure现有PyYAML/Pillow环境，BAM Python只需固定pysam。R沿用已有ggplot2/grid/data.table/gridExtra/gtable/ragg/svglite环境；详见每次生成的render-metrics.json。新版本或新平台必须重跑；这些命令不表示所有环境都已测。PDF审计脚本使用带pypdf/pypdfium2的文档运行时。
