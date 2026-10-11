# Nature 基因组与多组学学习入口

按 T2T-Y、HPRC、SCENIC+、GLUE、Numbat、scBasset 顺序学习。原图与固定版本源码见[案例合同](../library/nature-genomics-multiomics/data/metadata/cases.json)；实际运行范围见[复现台账](../benchmark/library/nature-genomics-multiomics/data/metadata/reproduction-status.json)。仍为candidate，待用户验收；不得把局部作者处理数据复算称为原始测序全流程复现。

## 已运行的六个案例

- T2T-Y Fig.3：从作者IGV会话提取同一chrY窗口的ONT、HiFi及两条CENP-A轨道，800个精确区间重叠max分箱；HiFi除100，缺失留空。仅三行信号，不含完整结构与StainedGlass。
- HPRC ED10b：运行作者R核心计算，得到六个TPR/PPV点。输入为作者原有模拟读段评价表，本次没有另造数据；保留作者分母定义。
- SCENIC+：读取六方法264,012行扰动表，按作者padj<0.01、|log2FC|>1复算Spearman，96个方法/扰动组合。未定义相关留NA；另审计作者将三个SCENIC+系数替换为SCENIC值的步骤。此图为补充表复算，不是Fig.3g的F1。
- GLUE Fig.2c：公开Baseline表的FOSCTTM按数据集/方法复算均值、样本SD与种子点；缺方法显示N.A.，单种子不造SD。没有重新训练整合模型。
- Numbat：固定v1.1.0 ATC2示例，执行作者compute_posterior函数，核对3,806条似然/先验记录、173个细胞、22段；不是论文Fig.2 ROC复现，后者缺sc_scores.rds。
- scBasset Fig.5b：203个TF原始配对点；另复算Fig.5b/g单侧Wilcoxon。Source Data中HSC347，图注344；保留差异，不自行删三个细胞。

## 选图与迁移

位置关系用共享组装、方向与窗口的分层轨道；每个模态独立单位。整合嵌入必须复用联合坐标，混合度不当生物学正确性。配对方法指标用恒等线散点，标清匹配对象；新模板MO-METRIC-001不假设因子模型。方法重复分布用原始点与箱线/均值SD；模型种子不当供体n。调控重叠按交集/行集合分母，允许不对称。

重复执行入口：[reproduce_panels.py](../benchmark/library/nature-genomics-multiomics/scripts/reproduce_panels.py)。先查本地真实输入与来源，默认离线重算；最终PDF、plot data、脚本、环境和QC永久保留，PNG/SVG预览放work。统计见[统计迁移](statistics-multiomics-learning.md)。原图或许可不明源码只供本地审阅。

用户补充：首版即用语义彩色；六案逐图验色，黑白不记视觉PASS；批量交付完整展示。GLUE学习固定源码display.yaml的方法配色，其余按项目锁定模态/类别色，不制造新统计分组。
