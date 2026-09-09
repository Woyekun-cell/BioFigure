# 案例检索与 Pattern Distillation

本库提供可追溯参考，不是模型训练权重；不得声称“读过即掌握”或保证顶刊录用。

先用 `scripts/retrieve_references.py` 按领域、任务、Pattern 检索 `atlas/top-journal-corpus.yaml`。陌生图型或明确参考任务，再查原论文图号、图注、Source Data、Code Availability、作者仓库和官方 vignette。公众号只能启发审美，不能替代原始证据；无代码则标“视觉参考”，不得伪造链接或复现状态。

检索同类科学问题和数据结构，不只搜“好看”：PCA 查尺度/解释率，火山查效应/阈值，富集查背景/比值，轨道查坐标/归一化，树与共线性查 ID/关系，单细胞查样本/细胞层。

每个案例记录论文、图号、资产哈希、输入/尺度、视觉观察、可迁移决策、拒绝项、代码路径/版本、许可和验证日期。严格区分：已检索、已读代码、已运行、已看成图；区分原数据复现、模拟结构复现、风格迁移和新数据分析。

蒸馏 visual hierarchy、geometry、layout、density、annotation、legend、ordering、whitespace、color semantics，以及画布比例、data/annotation/legend bbox、字体、标签预算、矢量/栅格层和最终尺寸。不能只记 theme 或脚本。

优先级：同问题作者代码/官方 vignette > 有 Source Data 的论文图 > 仅图片。至少记录正例与失效边界；截图不能支持猜包、参数或数据处理。代码可运行仍须看图。复用前核对许可与归属；公开可读不等于可再分发。

Pattern Library 运行时只读；仅 maintenance 经测试和审核后写入 Atlas。失败案例也记录边界。详证按需加载，核心热启动包 7200 字前压缩。
