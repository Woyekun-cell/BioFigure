# 每次绘图

模式：`standard` 做完整科学与布局检查；`publication` 加四 Critic；`reference-guided` 先蒸馏证据；`reproduce` 保持原图语义；`maintenance` 才可改 Pattern 库。全程写 checkpoint ledger。

1. **CP0–CP1**：确认问题、实验单位、样本映射、矩阵层、变换、缺失/零值、统计、方向、单位和尺寸。关键科学语义无法安全推断才问用户；未知项不补造。
2. **路由**：确定 task、message、density、primitive；检索 Pattern 并核对 Renderer。常规图 R 优先，AnnData/Scanpy 等明确例外用 Python。
3. **图级证据**：从 `atlas/top-journal-corpus.yaml` 检索 1–3 个同任务案例。task/pattern 无命中即 `evidence_gap`。publication/reference-guided 模式继续检索原论文并按维护流程入库；普通模式可按出版合同作图，但须声明证据缺口。
4. **CP2**：Figure Design Spec 按首轮布局合同锁定层级、编码、图例、尺寸、Renderer、Critic targets 与各槽位；验证通过才写代码。
5. **渲染**：真实数据或同维度模拟数据，独立单图；纯白、Helvetica/Arial、无冗余标题。密集数据层可栅格化，文字与关键标注保留矢量。
6. **CP3**：actual inspection 按目标尺寸打开 PNG；核对 bbox、裁切、缺字、字体、图例、白底、计数与色阶。失败则对象级修改并重画。
7. **CP4**：Scientific Critic 永远运行；publication 加 Visual、Publication、Anti-AI。Critic、QA、格式、哈希均 PASS 才交付。

交付代码、图、图注、Spec、QA、哈希、inspection、Critic 与 ledger。组图只装配已通过单图。
