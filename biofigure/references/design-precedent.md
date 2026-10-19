# 先检索、读图读码，再设计

每次正式绘图先检索匹配模板和代码，包括普通`original`。`prepare_figure.py`在原创回执的`design_discovery`记录公共配对案例、可选学习库及锁定模板候选；缺私有库明确记`UNAVAILABLE`。已学方法更适合时，按ID读取完整合同、原图、代码和失败修法，改用`reference-guided`绑定原有资格与renderer合同。检索排名、文件存在或历史PASS均不证明当前适用。

当前数据的新代码必须在CP2前填写`reference_evidence.design_precedent`。例如已实际查看包内箱线图及代码后：

```yaml
design_precedent:
  policy_id: reference-first-v1
  strategy: reviewed-reference
  candidate_id: PUBLIC-boxplot
  files: [] # 原样复制本次 discovery 候选的 files，含角色、相对路径与SHA-256
  inspection:
    figure_opened: true # 仅在真正打开后填写
    code_read: true # 仅在真正读取相应分支及布局函数后填写
  review:
    structure: 两组箱线叠加全部独立观测，先画箱后画点。
    code: 审核render.R的boxplot分支、position与设备导出；保留细黑描边。
    data_mapping: 当前sample_id唯一，group映射横轴，value及单位映射纵轴；不复制示例统计。
    typography: 当前目标89mm，Arial各角色字号与标签长度写入font_contract。
    legend_and_layout: 单一分组横轴已命名，不增加重复图例；统计标注预留上方空间。
    adaptation: 用当前数据重算箱体及检验，按当前最长标签调整边距；不继承旧视觉PASS。
```

`reviewed-reference`要求配对图、代码、元数据和来源哈希一致，六项review具体对应当前输入。实际采用外部来源/已验adapter走来源模式，不能借原创绕开其合同。查看示例不等于必须复制图型、配色或数值。

`packaged-replay`仅供原封不动运行已分发公共配方，仍填写六项review并绑定同一组files；授权必须包含该配方renderer的精确哈希。它不声明已读图；新写或修改renderer不能使用此策略。脚本成功仍是`RENDERED_PENDING_VISUAL_REVIEW`。

`pattern-fallback`适用于零命中、材料不可用或不合适。填写`fallback_reason`及`rejected_candidates: [{candidate_id: ID, reason: 具体原因}]`，逐一解释发现的公共、学习库和锁定模板候选，仍完成六项review与完整设计。零命中不编造图、代码、DOI或查看记录；按Pattern/官方包语法独立设计，不宣称来源复现质量。

CP2及授权重验当前检索和文件身份；改数据、代码、Spec或环境须重新准备与审查。哈希与查看记录不能证明模型理解原图；最终PNG/PDF必须重新打开，检查字体、密度、图例、方格、裁切和画布底边。不得用缩字、删数据或补AI小字消除失败。
