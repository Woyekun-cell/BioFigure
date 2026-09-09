# 顶刊图级视觉语法

本文件记录真实论文图的可迁移设计规律，不把期刊名当作样式。证据在 `atlas/top-journal-corpus.yaml`；调用 `scripts/retrieve_references.py` 按领域、任务和 Pattern 取 1–3 个相近案例。当前为 Nature 系论文种子库，不代表跨出版商全集。没有 task/pattern 命中时返回 `evidence_gap`；参考引导任务需继续检索并审核入库，不能用同领域案例或期刊名补位。

## 共同规律

- 先给主证据最大面积，再放解释和验证；多面板不是等宽仪表盘。
- 白底、薄而稳定的轴线、对齐的 panel 边界；分区靠留白和细分隔，不靠装饰卡片。
- 同一语义跨面板保持同色、同顺序、同坐标范围；颜色数量由变量决定，不由“高级感”决定。
- 图例靠近其负责的证据区且不侵入数据；长类别优先直接标签、分面或扩宽画布。
- 热图/矩阵先保证排序、注释对齐和单元几何；相关矩阵严格方格，表达矩阵按最终可读性决定是否方格。
- 单细胞嵌入复用相同坐标和画布；背景细胞用中性灰，焦点层后绘。UMAP 不解释轴方差。
- ATAC/ChIP/基因组轨道共享坐标框、方向和比例尺；局部高亮不改变信号尺度。
- 比较基因组以物种/染色体/基因的共同顺序为骨架，树、性状、共线性、基因轨道按行锁定。
- 多组学先固定 modality/factor 语义，再组合 factor score、variance、loading、association；相关不画成因果网络。

## 不能机械照搬

已发表不等于每个设计决策都适合新图。长图例、过密标签、彩虹连续色、代码截图、装饰性物种剪影、无筛选的弦图和径向矩阵均可能在原文语境可用，但不自动迁移。每个 Reference Evidence 必须写 `rejected_elements`。

## 首轮代码要求

Design Spec 中列出：选中案例、实际观察、迁移决策、拒绝项。Renderer 只读取迁移后的几何和布局，不读取“Nature 风”“Cell 风”等空泛标签。首轮必须输出独立 PNG 加矢量文件，按目标物理尺寸打开检查；发现重叠、裁切、字体替换或图例侵入时直接重算布局。

权威规范入口：Nature Research Figure Guide、Nature final artwork、Elsevier artwork/accessibility、Science editors' author guide。规范约束生产质量；具体视觉语法来自图级案例观察。
