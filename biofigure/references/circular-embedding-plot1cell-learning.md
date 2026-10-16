# 环形单细胞嵌入：源码学习与有界迁移

检索：环形 UMAP／t-SNE、外圈注释、plot1cell、global KDE、线粒体比例 percent.mt。此案例只验证现成二维坐标加注释圈，不能当作线粒体基因组环图或生物学轨迹。

## 原始代码与论文对应

- MIT 核心：[plot1cell/R/plot_circlize.R](https://github.com/TheHumphreysLab/plot1cell/blob/f07186f21ce51ff8240700c9ab388b735359dffe/R/plot_circlize.R)。独立可视化实现，README 参考 Nature 2021 Fig.1；该原文是 t-SNE，不能把本实现冒充原作者代码。
- 作者实际环图：[Cell Metabolism 2024 SHARE-seq Figure1/fig1_circular_umap.R](https://github.com/TheHumphreysLab/SHARE-seq-kidney/blob/95eb6e15bca9a593e8d0cc491b0f345b1a0dcf9d/Figure1/fig1_circular_umap.R)，DOI 10.1016/j.cmet.2024.02.015。源码可读但未给 LICENSE，只作本地学习，不作为可再分发包。其 RNA 446267、ATAC 401875 是作者数据，不能用于本次图的计数。
- 本次数据：[Nature Communications 2022](https://www.nature.com/articles/s41467-022-34255-z)，GSE185948 公开轻量元数据保存 102710 点、15 类、13 供者和 UMAP_1/2。原 Fig.1b 是普通 UMAP，本次是同类方法迁移，不是该文环图复现。作者脚本 8_Seurat_object_RNA 明确覆盖 UMAP 坐标以匹配论文。
- 用户截图：[Nature Biomedical Engineering 2026 Fig.2](https://www.nature.com/articles/s41551-026-01621-x/figures/2)。声明未生成自定义代码；没有定位到可直接复用的环图脚本或轻量保存坐标。本次不冒充截图原图复现。

## 函数与处理链

`get_metadata` → `cell_order` → `prepare_circlize_data` → `plot_circlize` → `add_track`。`Seurat` 取已存 embedding 与 metadata；`circlize` 创建扇区、注释轨道、外圈方向与间隔；`MASS::kde2d` 计算全局二维核密度；`dplyr/scales` 分组与配色；`gridGraphics/ggplotify` 将原生 circos/base 图转换为可编辑 grid；`ragg/svglite` 导出。无需重新做测序、聚类或降维，直接读公开 CSV 更轻量。

外圈在数据空间之外，内部仍为笛卡尔二维 embedding，不把细胞点极坐标化。源码按类别排序，以 log10(n_cluster) 决定各类扇区宽度；组内疾病与供者段长度是 count/n_cluster。全圈不是线性细胞丰度比例，各类别圈段不是点的空间角度映射，也不是循环发育轨迹。样本捕获比例不等于组织真实组成。

## 有界修正

1. 原 `transform_coordinates` 对 x/y 分别缩放，会改变形状；本例共同正尺度与平移，原坐标列保留，可逆误差须核验。
2. 分类颜色显式按名字查找。plot1cell 原 `add_track` 会覆盖输入颜色的名字为全局分类顺序，随后按分类名索引；传入颜色须先对齐全局顺序。作者 SHARE 的 `add_track2` 缺少这一步名称对齐，遇缺失类别可错位。
3. 用零起点累计计数边界覆盖 0..log10(n)，修正原首点为1、结束为下一类起点减1的小缝。保留每个真实细胞与稀有 URO1/URO2。
4. 源码全细胞 KDE 绝对等值 .2/.3 是密度轮廓，不是每簇置信区间或生物学边界。本例固定200×200、MASS默认带宽；作者 SHARE 源码把传入网格数忽略而硬编码1000，不能照抄。
5. 原弯曲标签与小轴字可读性不足。新图统一 Arial≥7.5pt，放大圈标签，疾病与供者图例分开。三层轨道依次 cell type／disease／donor。

## percent.mt 与复用条件

公开元数据没有 percent.mt，不补造。真实连续变量若要加环，先问意向：展示每个细胞、每类中位数或供者汇总；必须绑定细胞顺序、连续尺度、单位和独立色条。线粒体基因组物理环图应另检索 circlize 或 GenomeDiagram，使用基因组位置而非 UMAP。

新输入须有唯一细胞键、有限二维坐标、分类元数据、供者设计；barcode 可跨供者重复，不能直接去重。nCount_RNA 来源为小数，保留但不能称原始整数 UMI。生物推断以供者为实验单位；本例仅描述，不进行细胞级显著性检验。每次新数据重新准备、CP2、实际 PNG/PDF 视检、源码比较；本例成功只覆盖当前固定输入、环境与导出。

## 本地入口

`benchmark/library/single-cell/circular-embedding-plot1cell/scripts/prepare_data.R`；同目录 `render.R`；`data/metadata/design-spec.yaml`；`data/metadata/source-learning.json`。完成状态以本次 evidence 与 final PDF 绑定为准，不能沿用历史 PASS。
