# 绘图执行门禁

任一步失败，只交诊断或预览。

1. **所有绘图写代码前必须检索匹配模板与参考代码，读图读码后适配，original不豁免。** 从Skill根运行`prepare_figure.py`；原创回执`design_discovery`记录`reference-first-v1`、PUBLIC候选、`optional_archive_search`及`locked_template_search`。原创免DOI/私人档案，不免此门；来源/复现继续原retrieval/source/template/learned合同，不要求原创新字段，材料缺失不得偷换模式。
2. **设计门，未通过禁止写绘图代码。** 来源模式还须打开原尺寸参考和源码/方法卡，按原证据合同绑定。原创按[模式合同](reference-modes.md)写`reference_evidence.design_precedent`的policy_id、策略及structure、code、data_mapping、typography、legend_and_layout、adaptation六项review。`reviewed-reference`须选候选ID、绑定完整files，给原尺寸读图/读码真实观察；`packaged-replay`锁实际renderer，不放行任意新脚本；`pattern-fallback`按selected_pattern，逐一拒绝三层全部候选并写fallback_reason。公共runner仅packaged-replay，不自称看图。
3. 完整写`reference_analysis`与六维`design_target`，核面板、映射、拓扑、层级及专用包职责。命中锁定模板按[稳定复用](stable-template-reuse.md)做当次固定复跑，绑定回执、候选与哈希。按当前数据独立适配，禁止基础图层替代关键专用包；`validate_design_spec.py`通过才编码。
4. `output_size`按内容密度确定：低密度1–2面板用单栏89–90 mm；中密度、3面板或长标签用1.5栏120–136 mm；高密度或≥4面板用双栏180–183 mm；常规高度≤170 mm。非标准尺寸须写期刊/用户依据。画布、密度、留白和字号一起锁定，禁止放大画布掩盖拥挤。
5. `font_contract`列出最终尺寸的axis、title、legend、strip、annotation、panel label；普通文字≥5 pt，<6 pt须有依据。R用`bf_render_png`验证Design Spec尺寸、栏宽和缩放后字号。复现原图需保留更强字号层级时，显式填写schema中的`source_typography_contract`，绑定已查看原图哈希、各角色依据和比例上限；仍须检查实际PDF字号、可读性及碰撞，不得隐藏大字或虚填规格。
6. 打开最终PNG及所需PDF；复现图并排比原图。数据标记必须有语义彩色，黑白终图或仅装饰有色记REVISE；逐项查结构、配色、图文比例、文字位置、重叠、裁切、面板对齐、点径与线宽。复杂组合按中心线/轨道对齐，先给图例留位。重绘后旧检查失效。
7. 逐字核画布直到最底边。caption/footer/脚注、样本设计、处理日期、方法与筛选阈值段落全部移图外，科学正确也禁止；AI备注/内部状态同样移出。白名单/标题授权不豁免。CP4必须记录`footer_absent`实际观察；发现记`footer_text=true`与`unrequested_text=true`，REVISE后重画重审。正常轴/图例、面板内紧凑n与P/q可保留；见[文字硬门](enforced-execution.md#图内文字)。
8. `validate_checkpoints.py`全PASS才交付。CP4始终执行完整publication与领域审查；原创填`design-quality`、来源模式填`reference-quality`，两者均保留hierarchy、geometry、palette、typography、marks、annotation六维及相同证据阈值。CP4须human/model评审；自动检查不可单独PASS。渲染回执只证明流程绑定。

基准规则见[协议](benchmark-protocol.md)、[判定](benchmark-case-method.md)与[审阅](benchmark-review-operations.md)。
