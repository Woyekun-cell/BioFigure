---
name: biofigure
description: 根据生物数据、实验设计与研究目的判断适合的图型，解释首选与备选；设计、绘制、精修或审查科研图，R优先兼容Python，核验科学语义与实际成图。
---

# BioFigure 3.5.1

保留静态科学契约、manifest动态路由、Pattern/Atlas检索与CP0–CP4架构。先理解数据和研究情景，再选择图型及实现。

## 入口分流

- 数据选图或新图：先读 [语义与情景理解](references/semantic-context.md)，实际剖析输入，再读 [选图](references/selection.md)。未指定图型也能启动，不要求用户先命名图型。
- 指定图型：仍检查数据是否支持；可行则沿用，冲突时说明原因和替代方案，不擅自更换。
- 复现/修图：沿用已核验的情景与图型，只复查变化的输入、映射和解释；不重新盘问已知信息。
- 只问“适合画什么”：交付选择、理由、限制及关键待确认项；无需渲染或伪造CP通过。

## 决策与执行

1. 将事实、推断、未知及候选选择写入既有Design Spec的 `semantic_context` 与 `chart_decision`；未有Spec时先在回复记录，后续绘图原样转入，不默认新增报告。字段见语义规范。
2. 图型确定后读 `manifest.yaml` 的 `always_load`，运行 `scripts/route_figure.py 请求.yaml`，按领域加载参考。读取 [执行门禁](references/figure-execution-gates.md) 和 [首版约束](references/first-render-policy.md)；遇到桑基、火山、环形 UMAP、系统发育树或三元图，读 [SciDraw 36–45 包范式](references/scidraw-package-recipes-36-45.md)；遇到渐变小提琴、山脊、样本环图、哑铃组合或双三角矩阵，读 [SciDraw 46–55 包范式](references/scidraw-package-recipes-46-55.md)；遇到时序、地图组成、花瓣环柱、气泡矩阵或多条件对数曲线，读 [SciDraw 56–65 包范式](references/scidraw-package-recipes-56-65.md)；遇到分面组成、径向堆积、双组相关热图、OncoPrint、桑基堆积或多组火山图，读 [顶刊案例 001–010 配方](references/topjournal-recipes-001-010.md)。完整执行检索、读图、方法合同、渲染及验图门禁。
3. 语义层只是前置决策，不替代科学契约、Design Spec、CP0–CP4、Critic或视觉证据。关键实验设计未知时允许数据QC和条件式建议，暂停依赖该信息的推断或绘图。

## 能力验收

能力验收与案例学习先读 [benchmark协议](references/benchmark-protocol.md)。历史PASS不代表V2通过；严格检索用 `--require-benchmark`，无结果按待验证方法处理。单例用 `audit_reference_fidelity.py --bundle ... --root ...`；无bundle只查库存。

科学正确、技术合规、参考质量与用户认可分别报告。Skill不能强制平台调用工具；不得把规则存在、脚本运行或成图打开当成全面验证。
