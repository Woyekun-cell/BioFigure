# 十篇论文：透明度与图层布局

2026-10-13重新查看保存的原论文图，核官方元数据与可得作者源码。图/码路径、SHA256、观察及缺口在[证据表](../atlas/mark-opacity-study-20261013.json)；调用规则见[点线层级](mark-opacity.md)。

| 论文 | 实看图 | 可迁移布局 |
|---|---|---|
| [SCENIC+，Nature Methods 2023](https://www.nature.com/articles/s41592-023-01938-4) | Fig2g/4e–f | 轻轨道高亮、淡观测、强边界 |
| [GLUE，Nature Biotechnology 2022](https://www.nature.com/articles/s41587-022-01284-4) | Fig3/4 | 细点云、清晰轮廓、浅边际填充、白心均值 |
| [Numbat，Nature Biotechnology 2023](https://www.nature.com/articles/s41587-022-01468-y) | Fig2 | 淡基因组背景点、清晰段估计与稀疏样本点 |
| [scBasset，Nature Methods 2022](https://www.nature.com/articles/s41592-022-01562-8) | Fig4/5 | 密集小点、空心箱体、醒目主曲线 |
| [人类泛基因组，Nature 2023](https://www.nature.com/articles/s41586-023-05896-x) | Fig2 | 浅支持柱、前景气泡、共享色义 |
| [Hochgerner，Nature Neuroscience 2018](https://www.nature.com/articles/s41593-017-0056-2) | Fig2/4 | 浅灰网络底层、前景细胞与共坐标 |
| [Han，Nature Communications 2020](https://www.nature.com/articles/s41467-020-17968-x) | Fig5 | 强弱边证据、细环节点、图例留白 |
| [Wahle，Nature Biotechnology 2023](https://www.nature.com/articles/s41587-023-01747-2) | Fig6 | 灰网络、重点节点、清晰箱体统计线 |
| [HMO，Nature Communications 2022](https://www.nature.com/articles/s41467-022-29867-4) | Fig5 | 稀疏主线清晰、颜色/线型分控；横轴为指标 |
| [Trevino，Cell 2021](https://doi.org/10.1016/j.cell.2021.07.039) | Fig3，作者PDF第7页 | 淡全局背景、重点轨迹、定量气泡、清晰图例 |

精确alpha只在作者代码支持的相应层记录；源码函数或相关补图参数不能冒充正式面板数值。Trevino所看PDF为作者保存的article-in-press版本，终刊元数据另核。Numbat于2022在线发表、2023卷期刊出。

由此确定按密度与角色设置视觉权重的范式：保留清晰轮廓与主要证据，减轻高密度或辅助层。`bf_mark_style()`参数为当前BioFigure建议起点；新数据、尺寸和环境重新看图。
