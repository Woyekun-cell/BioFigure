# gggenomes EMales：六病毒基因组多轨道图

检索 ID：`BENCH-gggenomes-emales-2026`。关键词：六病毒基因组、EMale、gggenomes、基因箭头、蛋白共线带、TIR、NGARO、GC wiggle、方向同步、aa2nuc。

适用问题：已有序列长度、基因注释、蛋白/核酸比对结果和区间注释时，比较多个基因组的局部结构、同源联系与插入区。它是处理结果的可视化方法，不验证组装、同源身份或生物学因果；不是从测序原始数据开始的全流程复现。

## 固定来源与入口

- 官方原图与完整示例：[gggenomes 主页](https://thackl.github.io/gggenomes/)；[直接 PNG](https://thackl.github.io/gggenomes/reference/figures/emales.png)。原图 2400 × 1200 px，SHA-256 `ab288fb4976693f1de2bdb801d326f5cd30bfcb5de87266a28af4e57a4210542`。
- 源码固定于 [thackl/gggenomes@752e0e19da04b6813f0524d784843901ac64dcb2](https://github.com/thackl/gggenomes/tree/752e0e19da04b6813f0524d784843901ac64dcb2)，版本 1.2.0，MIT。包内保存完整源档案、许可、README 和核心函数原文。
- 包目录：`benchmark/library/comparative-genomics/gggenomes-emales/`。主图 `results/figures/gggenomes-emales-main.pdf`；方向测试 `results/figures/gggenomes-emales-direction.pdf`；CSV 在 `results/plot_data/`；检查结果在 `evidence/` 和 `results/tables/`。
- 可重入调用器 `scripts/fresh_call.py`；原生绘图 `scripts/render.R`；源数据导出 `scripts/prepare_data.R`；严格比对脚本 `scripts/verify.py`。当次状态以 `evidence/verification.json` 与 `evidence/source-difference-review.json` 为准，卡片不继承历史 PASS。

## 原图结构与数据合同

从上到下固定为 RCC970_016B、E4-10_086、Cflag_017B、BVI_069、BVI_008A、E4-10_112。六基因组长度分别为 20152、20642、21311、26808、26820、26856 bp。完整输入含 143 个基因、12 个 TIR、3 个 NGARO 插入区、2856 个 GC 窗口、125 条核酸比对和 827 条蛋白比对。原始 `seq_id`、`feat_id`、所有坐标、分数及其他列均保存；列表列在 RDS 中无损保存，在 CSV 中以 JSON 字符串表达。

主图由共享水平基因组坐标和六个行中心组成；连续箭头构成主体，浅灰绿色同源带连接相邻行，GC 小轨道位于基因线下，TIR 标记两端，NGARO 以半透明区间加文字说明。图例在右侧、基因组 ID 在左侧、基因名倾斜 45 度置于箭头上方。信息密度来自完整对象，不靠省略低关注基因或放大空白。

基因/TIR/NGARO 的源 GFF 坐标以 1 为起点；GC 表保留源 BED 的 0 起点。蛋白比对的 start/end 是氨基酸位置，不可直接当 bp 连线。`add_sublinks()` 根据 feat_id 匹配源基因，原生执行 aa2nuc 和链方向转换。`geom_link(data=links(2))` 显示第二条蛋白连带轨道；默认相邻基因组布局保留 222 条可见蛋白连带，核酸轨道有 38 条相邻记录。其他比对保存在输入，不冒称 827 条全部绘于主图。

## 原生函数职责

`gggenomes()` 建立序列、基因、特征、链接的轨道布局；`geom_gene()` 构造具有链方向的箭头；`geom_feat()` 表示 TIR 和 NGARO 区间；`geom_gene_tag()` 与 `geom_feat_note()` 提供基于特征坐标的标签；`geom_wiggle()` 将 GC 分数变成相对中位数的上下偏移。`sync()` 依据相邻链接长度支持度启发式翻转序列，不代表重新推断生物学方向，也不改变原始表中的 start/end。

本例 GC 的公共中位数为 0.38，2.5% 和 97.5% 分位数为 0.20 与 0.76；高度 0.20 行距。该 wiggle 是相对偏离显示，不是有明确纵轴刻度的绝对 GC 测量图。主图按作者示例用第一条核酸轨道同步，再绘第二条蛋白轨道；方向测试明确用第二条蛋白轨道同步。

## 版本与版式的必要适配

系统共享包 1.1.3 与固定上游 1.2.0 的核酸起点有 1 bp 差异，因此在任务专用 R 库安装固定源 1.2.0，不升级共享包。1.2.0 默认横轴变为比例尺；本例显式恢复官方 PNG 的 0、10k、20k 基因组坐标轴。区间线宽用 `linewidth`，避免 ggplot2 4.0.3 对旧 `size` 线宽参数发出弃用警告。

采用 `marginal="keep"` 保留 6 个 start=0 的边界 GC 窗口；官方 1.2.0 默认 `drop` 会显示 2850 个窗口。主图画布 183 × 94 mm，方向测试 183 × 154 mm；Arial 的基因名 6.5 pt、坐标 7 pt、基因组 ID 与图例 7.5 pt、图例标题 8 pt。保留 Dark2 的六种基因色；NA 基因图例显示为 `Unnamed`，只表明 name 缺失。

首版顶行重复 ATPase 文字过近，作为负例保存在任务 work/first-render。最终只合并冗余名称：同一 seq_id、同一 name，按中点排序，相邻中点差 ≤1000 bp 归于一簇，每簇标记最长基因，长度相同保留排序首个。48 个有名基因中选取 38 个文字标签、抑制 10 个重复标签；全部 143 个箭头仍绘制。阈值在 Design Spec 的 `label_policy.merge_distance_bp`，修改后必须重新 CP2 与授权渲染。`*-gene-label-selection.csv` 逐项记录 feat_id 与 draw_label，不能把去重文字误报成去重基因。

## 方向压力测试与复跑

方向图人为改变同一输入第 2、4、6 个基因组的显示方向，上下对比重新同步前后。脚本断言同步后的序列、基因和蛋白链接布局与未扰动数据经蛋白同步所得布局一致。它验证这套输入下的方向变换，属于同数据压力测试；独立新物种、新组装或任意新输入尚未验证。

从 BioFigure 根运行，设 `CASE` 为上述包目录，`TASK` 为项目 `work/2026-10-13-deep-learning/gggenomes`。先在专用库安装本地锁定源码：

```sh
mkdir -p "$TASK/R-lib"
R CMD INSTALL --library="$TASK/R-lib" "$CASE/sources/gggenomes-752e0e19-source.tar.gz"
R_LIBS_USER="$TASK/R-lib" Rscript "$CASE/scripts/prepare_data.R" "$CASE"
python3 "$CASE/scripts/fresh_call.py" --variant main --work-dir "$TASK/call-main" --output-dir "$CASE/results/figures" --r-lib "$TASK/R-lib"
python3 "$CASE/scripts/fresh_call.py" --variant direction --work-dir "$TASK/call-direction" --output-dir "$CASE/results/figures" --r-lib "$TASK/R-lib"
```

每次调用从当前索引重做 prepare/CP2，将 Design Spec 保存为该次独立快照，再签发一次授权，由 R `bf_render_png()` 消费。独立 R 进程复跑放到另一输出目录；比较 PNG 像素及 PDF 栅格像素，不用 PDF 二进制哈希代替视觉一致性。最终 PDF 检查原生文字、字体、字号、画布、裁切与零嵌入位图；并人工/模型查看 PNG 和实际 PDF 渲染。执行、来源一致性、视觉审查、方向压力测试、用户验收分别记录。
