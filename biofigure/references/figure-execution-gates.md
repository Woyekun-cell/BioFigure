# 绘图执行门禁

任一步失败，只交诊断或预览。

1. 从Skill根运行 `prepare_figure.py`；按[证据模式](reference-modes.md)明确`original`、`reference-guided`或`reproduction`。原创以当前数据和包内Pattern规划，不要求私有来源库；来源模式预检检索 reproduction、top-journal、SciDraw与能力图谱。实际采用的来源、代码或模板材料缺失不得偷换模式。失败、无方法或数据合同缺失时禁写代码。
2. **设计门，未通过禁止写绘图代码。** 原创按数据与科学问题设计面板、图层、位置、共享坐标、排序、轨道和阅读顺序；来源模式还须打开原尺寸参考和源码/方法卡。两者核实专用包职责并完整写入`reference_analysis`；原创不伪填原图或DOI，来源模式禁止按缩略图拼形状。
3. 命中锁定模板先按[稳定复用](stable-template-reuse.md)跑当次固定样例；Spec绑定复跑哈希、真实回执与候选ID，`validate_design_spec.py`通过后才编码。来源代码只用于学习方法；按当前数据独立实现。不得用基础图层替代关键专用包。
4. `output_size`按内容密度确定：低密度1–2面板用单栏89–90 mm；中密度、3面板或长标签用1.5栏120–136 mm；高密度或≥4面板用双栏180–183 mm；常规高度≤170 mm。非标准尺寸须写期刊/用户依据。画布、密度、留白和字号一起锁定，禁止放大画布掩盖拥挤。
5. `font_contract`列出最终尺寸的axis、title、legend、strip、annotation、panel label；普通文字≥5 pt，<6 pt须有依据。R用`bf_render_png`验证Design Spec尺寸、栏宽和缩放后字号。复现原图需保留更强字号层级时，显式填写schema中的`source_typography_contract`，绑定已查看原图哈希、各角色依据和比例上限；仍须检查实际PDF字号、可读性及碰撞，不得隐藏大字或虚填规格。
6. 打开最终PNG；复现图并排比原图。数据标记必须有语义彩色，黑白终图或仅装饰有色记REVISE；逐项查结构、配色、图文比例、文字位置、重叠、裁切、面板对齐、点径与线宽。复杂组合按中心线/轨道对齐，先给图例留位。重绘后旧检查失效。
7. 逐字核画布直到最底边。caption/footer/脚注、样本设计、处理日期、方法与筛选阈值段落全部移图外，科学正确也禁止；AI备注/内部状态同样移出。白名单/标题授权不豁免。CP4必须记录`footer_absent`实际观察；发现记`footer_text=true`与`unrequested_text=true`，REVISE后重画重审。正常轴/图例、面板内紧凑n与P/q可保留；见[文字硬门](enforced-execution.md#图内文字)。
8. `validate_checkpoints.py`全PASS才交付。CP4始终执行完整publication与领域审查；原创填`design-quality`、来源模式填`reference-quality`，两者均保留hierarchy、geometry、palette、typography、marks、annotation六维及相同证据阈值。CP4须human/model评审；自动检查不可单独PASS。渲染回执只证明流程绑定。

基准规则见[协议](benchmark-protocol.md)、[判定](benchmark-case-method.md)与[审阅](benchmark-review-operations.md)。
