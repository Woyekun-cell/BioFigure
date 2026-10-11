# 绘图执行门禁

任一步失败，只交诊断或预览。

1. 从Skill根运行 `prepare_figure.py`；预检必须含 reproduction、top-journal、SciDraw与能力图谱。失败、无方法或数据合同缺失时禁写代码。
2. **读图门，未通过禁止写绘图代码。** 打开原尺寸参考和源码/方法卡；核实专用包职责。拆出面板、图层、位置、共享坐标、排序、轨道和阅读顺序，写入`reference_analysis`。禁止按缩略图拼形状。
3. 命中锁定模板先按[稳定复用](stable-template-reuse.md)跑当次固定样例；Spec绑定复跑哈希、真实回执与候选ID，`validate_design_spec.py`通过后才编码。来源代码只用于学习方法；按当前数据独立实现。不得用基础图层替代关键专用包。
4. `output_size`按内容密度确定：低密度1–2面板用单栏89–90 mm；中密度、3面板或长标签用1.5栏120–136 mm；高密度或≥4面板用双栏180–183 mm；常规高度≤170 mm。非标准尺寸须写期刊/用户依据。画布、密度、留白和字号一起锁定，禁止放大画布掩盖拥挤。
5. `font_contract`列出最终尺寸的axis、title、legend、strip、annotation、panel label；普通文字≥5 pt，<6 pt须有依据。R用`bf_render_png`验证Design Spec尺寸、栏宽和缩放后字号。
6. 打开最终PNG；复现图并排比原图。数据标记必须有语义彩色，黑白终图或仅装饰有色记REVISE；逐项查结构、配色、图文比例、文字位置、重叠、裁切、面板对齐、点径与线宽。复杂组合按中心线/轨道对齐，先给图例留位。重绘后旧检查失效。
7. `validate_checkpoints.py`全PASS才交付。CP4须human/model评审；自动检查不可单独PASS。渲染回执只证明流程绑定。

基准规则见[协议](benchmark-protocol.md)、[判定](benchmark-case-method.md)与[审阅](benchmark-review-operations.md)。
