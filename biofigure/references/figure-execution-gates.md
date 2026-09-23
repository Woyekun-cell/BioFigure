# 绘图执行门禁

读过规范、代码运行、打开图片均不等于合规。每图按下列顺序执行；修图和短请求也适用。失败只交诊断或标记预览，不得称完成或PASS。

1. 读取 `references/personal-style.md`、`references/render-execution.md`、`references/reference-quality.md`、`references/reproduction-learning.md`、`static/core/contract.md` 与 `manifest.yaml`；运行 `scripts/route_figure.py 请求.yaml`，再运行 `scripts/plan_figure_method.py --query "任务+图型+数据字段" --output 方法合同.json`。方法合同绑定数据字段、专用包、核心层和失败条件。模型、推理档位和请求长短不改变本门禁。
2. **读图门，未通过禁止写绘图代码。** 先检索并识别科学图型家族、实际用途和专用实现；再把复杂图拆成 panel、数据层、统计层、注释层、标签层、图例与辅助轨道。对每个元素写明角色、几何、位置、数据映射和是否必需；对元素间关系写明包含、对齐、共享排序/坐标、连接、内外轨顺序和阅读顺序。结果必须进入 Design Spec 的 `reference_analysis`。图型未识别、元素没拆全、关系不明或专用包责任不明时返回 `NEEDS_REFERENCE`；禁止按外形猜测后随意拼接。
3. 科学契约与读图门通过后，运行 `scripts/retrieve_reproduction.py --query "任务+图型+数据结构" --require-validated --output 检索.json` 和 `scripts/retrieve_capabilities.py --query "任务+图型+数据结构" --output 能力检索.json`。编码前锁定唯一参考、图型家族、panel拓扑、必要结构、禁止替代项、核心R包及关键函数。`static-code-audited`只证明代码建档，`source-compared-needs-revision`只证明发现缺陷；只有图型家族、panel拓扑、必要结构、文字层级、注释层、信息密度六项全通过，且状态为`source-compared-png`、`review_status=pass`，才满足旧版高保真候选条件；V2还须绑定科学检查和当前运行/视觉证据。先锁定并实测来源方法使用的专用R包；禁止用基础ggplot2替代其核心布局能力。用户已授权且持有来源代码时，可检查包、函数、变换、排序和布局；禁止复制整段代码、来源数据或受限图片，生成脚本按当前数据合同独立重写。检索凭证必须进入CP2。
4. 参考图实际查看、Design Spec、CP0–CP2先完成。读取 `references/enforced-execution.md`。ggplot最终PNG只用 `bf_render_png`；把 `scripts/figure_style.R` 复制进项目并随代码交付。
5. 打开最终PNG，按实际使用尺寸审查，填写对象级inspection与Critic。复现任务必须用当前PNG重新生成原图并排图，分别审查布局、编码、字体、配色、信息密度；旧对照图在PNG变化后立即失效。每张PNG单独ledger。字体检查逐类写出最终pt、位置/旋转方向、裁切、与数据及图例的碰撞结论；任一必要文字不可读或重叠即退回修图。边框检查逐类覆盖坐标轴、分面框、点轮廓、环形轨道、矩阵网格和图例框；除非原图或语义明确要求弱化，线条灰度不得浅于原图同类结构，线宽也不得统一套用主题默认值。调字号或线条后必须重验全部图层。
6. 组合图须检查位置关系，而非只检查元素是否齐全。侧面箱线图、柱图、注释条或插图若对应主图的特定轨道、行或列，必须在同一最终画布按对应层中心线和范围对齐；禁止先各自缩放再简单左右拼接。图例必须占用明确空白区，遮挡数据、标签、显著性标记或外围轨道即退回修图。
7. 字体与信息密度单独验收。逐类比较标题、轴标题、刻度、分面条、注释、显著性和图例在原图中的相对字号与字重；仅“可读”不足以通过。模拟数据须匹配原图的观测数量级、疏密、聚集、异质性、点径分布和空白结构，禁止用均匀随机点、过度平滑曲线或稀疏占位数据替代复杂原图。
6. 运行 `python3 scripts/validate_checkpoints.py checkpoint-ledger.yaml --json`。仅退出码0且CP0–CP4全部PASS可交付；保存输出。渲染凭据仅证明技术预检，不能替代视觉质量。
