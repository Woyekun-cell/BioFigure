# 鳞翅目 Merian 染色体涂色：作者代码 benchmark

检索 ID：`BENCH-genomics-lepidoptera-merian-paints-2024`。正式来源为 Wright 等，Nature Ecology & Evolution 2024，DOI [10.1038/s41559-024-02329-4](https://www.nature.com/articles/s41559-024-02329-4)。本例学习、换色复现正式 Fig.4b 的 Pierini 系统树与五列染色体涂色；原始测序、组装和同源位点识别不在执行范围。

## 源码和输入定位

作者仓库 `charlottewright/Chromosome_evolution_Lepidoptera_MS` 固定到 `9e2742ba8270aa88e9ce14b08e2c4fd7c1c56cc2`，辅助 `lep_busco_painter` 固定到 `cf2081c28f39111599d709883c279375dfd84697`。MIT 许可文件保留。

原文件、来源 URL、字节数、SHA256 在 `benchmark/library/genomics/lepidoptera-chromosome-evolution/sources/source-manifest.json`。正式原 PNG 和作者整张 Fig4.pdf 均已实际查看。案例卡为 `benchmark/cases/genomics-lepidoptera-merian-paints-2024.json`；详细合同在该案例 `data/metadata/source-learning.json`。

- `sources/4_highly_rearranged_genomes/merian_paints/Fig4.R`：五物种树、branch event 注释、五列绘图顺序、上下层组合；正式 b 对应 `Pierini_panel`。
- `sources/2_merian_elements/merian_paints/functions_busco_painter.R`：`prepare_data()` 筛选；`get_busco_paint()` 将 fusion→split→ancestral 排序；`busco_paint_coloured_chr()` 绘制染色体与位点。
- `sources/lep_busco_painter/buscopainter.py`：`print_summary_table()` 按最大计数确定 dominant Merian；`print_location_table()` 计算中点和 self 类别。
- `data/raw/fig4b_selected_species_busco.tsv`：从作者处理后217物种表无损选出5物种、20,345行，保留原 BUSCO/染色体 ID 和坐标。原 ZIP 永久保留，整表解压放 work。
- S4 定义 Merian 元件；S10 提供真实染色体长度与 rearrangement status；保存的 Newick 树仅做5物种裁剪。

## 数据对应图表

输入需同时具有 orthologue 位点、染色体长度、祖先元件类别及保存的树。用系统树与各物种染色体涂色列组合，展示位置结构及来源元件；类别合计柱状图不能保留这套坐标关系。各物种独立 Mb 刻度；共用 Merian 类别和描边图例。图内枝上事件数直接保留作者已发表结果，不根据图中染色体 status 重新推导。

处理流程为：选物种→核对 S4→中点 `(start+end)/2`→按染色体求 Merian 最大计数→该类别记 self，其他保留 Merian ID→排除含冒号 contig、每染色体保留 BUSCO 数 `>3`→按 S10 命名列连接长度和 status→fusion、split、ancestral 类内按原染色体词法顺序→裁剪保存的树，保留真实枝长→绘图。

本固定输入保留20,316位点、120染色体，物种左到右为 Anthocharis cardamines、Aporia crataegi、Pieris rapae、Pieris brassicae、Pieris napi，染色体数30/25/25/15/25。10,964位点为 dominant self，9,352为其他元件；32个 Merian 类别均保留。

## 包与版式范式

| 包/函数 | 作者用途 | 可复用处理或版式 |
| --- | --- | --- |
| ggplot2 `geom_rect` | 染色体外框和 BUSCO 细矩形 | 外框为0..真实长度；位点为中点±20kb；填色与描边使用独立语义 |
| dplyr、tidyr | 筛选、连接、类别因子 | 先验唯一键、命名列、明确排除数；不让合并改变物种/染色体 ID |
| scales | 原 `hue_pal()`、Mb 显示 | 新配色明确绑定 MZ、M1..M31、self；每物种原比例保留 |
| ggtree | tree coordinate、`layout_dendrogram()` | 默认 ladderize TRUE/right FALSE；revts、反向和旋转；真实 branch length 不变 |
| ape、phytools | Newick 与树裁剪 | 读取处理后树，删除非目标叶；不重做系统发育分析 |
| cowplot、patchwork、ggpubr | 五列/上下层/共用轴图例 | 作者上树下涂色的1:4分区；各列高度共享，行间距随染色体数变化 |
| ragg、svglite、systemfonts | 新 adapter 导出与字体核验 | 同一 native R 对象输出 PNG/PDF/SVG，最终物理尺寸和 Arial 实际字面核对 |

新 adapter 为180×170mm，完整五列，不抽样；海蓝、草绿、紫色及暖色辅助组成32类固定色表。self 使用中性蓝灰，祖先描边蓝灰、重排描边酒红。正式图的 Mb 刻度90°，共享图例在底部重排为适合单独 b 面板的紧凑结构。科研图上没有流程状态、训练备注或诊断标题。

## 源码陷阱和迁移限制

1. Fig4.R 写 `Fig4A.pdf=Pierini`、`Fig4B.pdf=Lysandra`，正式图注却是 a=Lysandra、b=Pierini。图号依正式 caption，源码输出名另记。
2. 原绝对目录与 S10 数字列号已失效，需用 species、chr、status、length 命名列；原未用的 `Length=length*1e6` 不应复用。实际绘制长度是 bp。
3. self 是本染色体最多的 Merian，不能解释为缺失、未分配或 ancestral。HG993173.1 的 M1/M9 各74，按作者词法排序、严格大于更新规则选 M1。
4. 原位点区间不按染色体边界截断；13个中点±20kb区间会超出对应外框，但中点均在范围内。保留并记录，不能宣称已 clip。
5. `layout_dendrogram()` 保留真实枝长，不能替换成等枝长 cladogram。作者 PDF 的 tick 水平，正式 publisher PNG 的 tick 垂直；以正式 PNG 核对本次版式。
6. 本例仅固定 Fig.4b。Lysandra 的缺失长度、整张 Fig.4、陌生输入和压力案例未获得资格。复用时重新检查输入与 source、完成 CP2 并实际看新图，不复制旧 PASS。

## 运行与验收入口

`scripts/prepare_data.R` 做原生 R 数据准备；`scripts/verify_source.py` 独立比对 ZIP、选中行、位点、染色体及真实树；`scripts/prepare_spec.py` 绑定新 CP2；`scripts/render.R` 通过 BioFigure 单次授权绘制；`scripts/verify_render_mapping.py` 独立核对20,316个位点、120个外框、树坐标、配色和字体字框到枝线的留白；`scripts/reproduce.py` 在新空目录重新执行。入口需要 `--source-view-confirmed`，只有实际查看了绑定原图才能声明。

当前验证环境为 macOS、R4.6.1、ggtree4.2.0、ape5.8.1；导出调用 Quartz PDF，准备脚本调用 `/usr/bin/shasum`，不声称已验证跨平台。还需 `Rscript` 在 PATH、Arial、原生 `pdftoppm`，R 包 ggplot2、yaml、jsonlite、digest、ragg、svglite、systemfonts 和 Python PyYAML。实际版本在 data-qc.json 与 render-metrics.json；不由入口自动安装包或下载数据。

在 `Project_001_生物科研绘图Skill` 下运行，先实际查看本例原 PNG/PDF，再选择不存在的输出目录：

```bash
python3 biofigure/benchmark/library/genomics/lepidoptera-chromosome-evolution/scripts/reproduce.py \
  --output-dir work/lepidoptera-fresh-replay \
  --skill-root biofigure \
  --source-view-confirmed
```

默认 skill-root 先取 `BIOFIGURE_SKILL_ROOT`，否则按本案例目录解析回 biofigure；显式参数最明确。默认 workdir 为新输出的 `work/visual-qa`；显式 `--workdir` 需新空目录，若在输出内必须位于 `work/` 下，且不得与源案例或其祖先重合。源包内输出和复用既有 QA 目录会在复制前拒绝，避免递归复制或覆盖收据。命令完成只表示新渲染成功；仍须实际打开新 PNG 和本次 PDF 的预览，不能复制本次 PASS。

最终图在该案例 `results/figures/fig4b_merian_recolored.pdf`；彩色 PNG、SVG 和实际 PDF 预览属于 work 核验文件。`evidence/` 记录本次完成的范围、独立检查和文件哈希；执行成功与实际成图验收分开记录。
