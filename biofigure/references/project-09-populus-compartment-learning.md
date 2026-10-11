# 案例 09：Populus 圆形 A/B compartment 轨道

来源：[Shi 等，Nature Ecology & Evolution 2026](https://www.nature.com/articles/s41559-026-03069-3)，[Extended Data Fig. 1b](https://www.nature.com/articles/s41559-026-03069-3/figures/7)，作者仓库固定提交 `70d98b88fbcbf7ec0dcf8e2c0c56d69dfea27969`。官方面板与用户参考均已打开；公开仓库没有面板脚本或逐区间 compartment 数据。

## 可复用规则

- 染色体长度决定扇区角宽；Chr01–Chr19 顺序固定，Chr19/Chr01 间预留顶部缺口。
- 物种轨道按 a–k 从外到内固定，中央字典必须使用相同顺序。
- A/B 是二分类状态：深蓝/浅蓝固定，不用连续色阶；绘图前检查区间边界、重叠、缺口和覆盖终点。
- 相邻同态区间先合并，再画同心轨；中心孔、轨道宽度、外圈标签和图例空间按最终尺寸一起审查。
- 圆形图不能只检查“元素存在”；还要量圆盘占比、中心孔比例、扇区标签角度、图例侵入和轨道顺序。

## 验证与边界

独立 R/`circlize` 固定种子结构基准：19 个染色体扇区、11 个物种轨、209 个物种-染色体组合、2406 个合并 A/B 区间。坐标边界、连续无重叠覆盖、a–k 顺序和两态色义通过；183×170 mm PNG/PDF/SVG 经原图并排及 6 类 Critics 检查，0 hard/major/minor。

Pattern：`GEN-CIRC-COMPARTMENT-001`；Atlas：`ATLAS-GEN-COMPARTMENT-007`；Benchmark：`populus-compartment-edfig1b-001`。仅 reproduction 轨 PASS；transfer/stress 未测。模拟区间不支持原论文 compartment switch、保守性或生物学结论。
