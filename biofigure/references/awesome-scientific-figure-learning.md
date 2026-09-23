# Awesome Scientific Figure 候选学习层

来源：[项目目录固定版本](https://github.com/nehSgnaiL/awesome-scientific-figure/tree/8632aa34fcc1b0b2c3f66a7b1ddd4c0e587a25a8)。只将目录标题、图号、论文 DOI 和标签录入 `atlas/awesome-scientific-figure-candidates.json`；科学任务字段是据标题作的候选推断。未审原图、图注、Source Data、作者代码和素材许可，不得称为已训练、已复现或已验证方法。

用 `python3 scripts/retrieve_awesome_figures.py --domain imaging-assay --task 'antibody comparison'` 查候选；返回的 `verified_reference_evidence_gap` 恒为 `true`。不能以候选代替 `retrieve_references.py` 的已读图证据，也不能作为 CP0–CP4 或参考忠实度 PASS。

学习顺序：①原论文核对图号、图注、实验单位、面板、统计与数据；②查 Source Data、绘图代码及许可；③记录可迁移结构、科学限制和不应复用的特定叙事；④独立 R 重绘，原数据缺失则明确模拟；⑤目标尺寸验图，分别做复现、迁移、压力测试。每类只保留有新增方法价值的一例；完成前留在候选层。具体里程碑见 `docs/superpowers/plans/2026-09-23-awesome-scientific-figure-learning.md`。
