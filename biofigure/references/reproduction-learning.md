# 复现案例派生学习

本规则对所有模型和推理档位相同；低推理模式不得跳过检索、专用包实测、最终PNG查看、原图对照或CP0–CP4。做不完时写`unverified-preview`，不得写PASS、已学会或顶刊级。

V2验收以[benchmark协议](benchmark-protocol.md)为准。以下历史检索的PASS只作为方法候选，不替代V2证据；独立能力须另做留出输入与生成隔离测试。

## 必做流程

1. 按科学任务、图型、数据形状、候选R包与编码策略检索；优点标签和原文说明只作候选依据。不能确定图型与科学用途时停在`NEEDS_REFERENCE`，不进入编码。
2. 运行`retrieve_reproduction.py --require-validated`。只有`runtime_status=source-compared-png`且`review_status=pass`的记录可作高保真先例；其他状态只用于诊断或待办。无相关先例但论文原图、作者代码和对应数据可核验时，用`primary-source-lock`绑定当前案例源链，不把无关检索结果当替代。
3. 用户已授权且本地持有来源代码时，可以检查包、函数、数据变换、排序键和布局关系；不得复制整段代码、来源数据或受限图片。生成脚本须按当前数据合同独立重写，公开仓库只收自有代码和自生成图。
4. 先实测专用包的核心函数，再写主数据层、必要辅助层、注释、图例和布局；基础`ggplot2`不能替代专用包负责的风险表、聚类对齐、圆形轨道、树外圈或网络布局。
5. 每次PNG变化后重建原图并排图，按最终尺寸检查布局、编码、字体、配色、信息密度、图例重叠、标签碰撞、裁切、描边和面板对齐。
6. 模拟数据只验证方法与视觉结构；用户认可、视觉通过、代码运行和期刊接收分别报告。

## 读图—拆解—关系合同

参考图不是形状素材集。编码前必须完成 `reference_analysis`：

1. `figure_family` 和 `semantic_purpose`：用专业名称识别图型，说明它回答的科学问题；禁止只写“圆图”、“复杂图”或“很像某图”。
2. `panels`：列出每个面板的边界、主次、阅读顺序和共享对象。内嵌图、风险表、集合图、色标和外轨均是独立元素，不得省略。
3. `elements`：每个元素必须有 `id/role/geometry/position/data_mapping/required`。复杂环图至少分出中心内容、内圈注释、主数据轨、分区带、外圈标签和图例。
4. `relationships`：每条关系必须有 `from/to/type/shared_key`，其中 `type` 限定为包含、对齐、共享排序、共享坐标、连接、内外轨、对照或阅读顺序。没有数据关系的形状相似不得当作复现。
5. `spatial_topology`：写明直角/极坐标/树/网络坐标、左右上下或内外顺序、公用轴与对齐键。
6. `required_structures` 与 `forbidden_substitutions`：前者缺一项即失败；后者显式写出不允许的简化，例如“不得用普通极坐标色块代替分扇区多轨环形热图”。

只有元素清单覆盖参考图全部必要层、关系可由数据键实现、专用包对应到具体层后，才允许编码。编码后逐项反查 `required_structures`，不允许仅因整体轮廓相似就判定通过。

## 按案例读取

- 通用状态、专用包与文字规则：[核心迁移规则](reproduction-core-methods.md)
- SciDraw方法：[SciDraw迁移规则](method-family-scidraw.md)
- 1–20期：[1–20期方法](method-family-001-020.md)
- 21–43期：[21–43期方法](method-family-021-043.md)
- 44–53期：[44–53期方法](method-family-044-053.md)
- 54–63期：[54–63期方法](method-family-054-063.md)
- 64–80期：[64–80期方法](method-family-064-080.md)

`reproduction-derived-corpus.json`只保存派生结构与来源哈希。检索凭据、包版本、执行函数、并排图哈希和对象级检查结果进入当前任务证据，不以语气或模型名称替代证据。
# Source-locked composition benchmark: Populus Figure 2b

The published panel compares four A/B compartment-transition ratios for ten Populus species pairs. When the source table already provides proportions, first verify all expected groups/categories and closure within a declared tolerance, then use `geom_col(position = "stack")` to preserve supplied values. Use `position_fill()` only when the input contains counts or unclosed within-group values and the denominator is scientifically correct. Do not normalize exact proportions a second time without documenting why. When an aligned rank band shares the same group order, keep it in the same ggplot coordinate system as an annotation layer; patchwork output is not accepted by the current `bf_render_png` object preflight.

The author R script is an implementation reference, not the final visual ground truth: the published panel has a different A-to-B/B-to-A palette, angled italic species labels, a `b` panel tag, a Ks rank band, and integer tick labels without percent signs. The supplement provides the 40 proportions, while the code orders ten species by increasing Ks. It does not provide numeric Ks values for that band; reproduce its rank/placement only, never infer quantitative Ks from band thickness. See the source-locked case and evidence bundle registered as `POPULUS-FIG2B-SOURCE-001`.

Visual QA caught a legend failure that a generic “in-panel, no overlap” check had missed: 4 mm keys enlarged the swatches, and an opaque legend background erased the framed panel's top rule. Compare the rendered legend's key dimensions, total span and anchor against the opened source at equal crop size. For this panel, 2.2 mm keys, 4.7 mm horizontal key spacing, a 0.48 horizontal anchor and transparent legend background restored the published placement; the final box preflight reserves a separate legend region above the bars. Keep `inside_top` as a valid Design Spec placement only when render-time layout boxes confirm separation.

See [six-project source study and benchmark record](six-project-benchmark-learning.md) for the project-by-project evidence states, transferable rules, validation layers and source links. A single source-exposed reproduction does not count as blind transfer or general figure-family coverage.
