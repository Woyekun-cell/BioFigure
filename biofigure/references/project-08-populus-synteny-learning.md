# 案例 08：Populus 全基因组共线性

来源：[Shi 等，Nature Ecology & Evolution 2026](https://www.nature.com/articles/s41559-026-03069-3)，[Extended Data Fig. 1a](https://www.nature.com/articles/s41559-026-03069-3/figures/7)，作者仓库固定提交 `70d98b88fbcbf7ec0dcf8e2c0c56d69dfea27969`。已打开官方图，检索仓库文件树与历史；公开仓库没有该面板脚本或原始共线坐标。

## 可复用语法

- 先固定物种顺序与 19 条染色体顺序；左树、中央轨道、右物种名共享同一行序。
- 染色体必须留缝，不能画成连续长条；链接只在明确的源/目标坐标之间生成。
- 灰色共线带作背景；倒位、易位、重复分别用橙、绿、青突出，四类色义跨图固定。
- 物种名完整斜体置右；图例放底部独立区域。最终尺寸检查裁切、列间距与图例顺序。
- 输入最低合同：assembly/版本、species、chromosome、length、source/target 区间、relation type、phylogeny/order；真实分析还须记录比对与筛选参数。

## 本次验证与边界

独立 R/`gggenomes` 固定种子结构基准：11×19=209 条序列、589 条相邻行链接；坐标边界、10 个相邻物种对和四类关系均通过机器检查。183×82 mm PNG/PDF/SVG 经原图并排与 Scientific、Visual、Publication、Anti-AI、Genome、Reference Quality Critics 检查，0 hard/major/minor。

Pattern：`GEN-SYNTENY-001` v1.1；Atlas：`ATLAS-GEN-SYNTENY-006`；Benchmark：`populus-synteny-edfig1a-001`。仅 reproduction 轨 PASS；transfer/stress 未测。模拟坐标不支持原论文重排、保守性、系统发育或生物学结论。
