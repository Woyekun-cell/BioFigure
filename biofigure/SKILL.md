---
name: biofigure
description: 设计、绘制、精修或审查生物科研图；R优先，兼容Python，检查科学语义、字体、排版与实际成图。
---

# BioFigure 3.5.1

## Benchmark 验收

能力验收和案例学习先读 `references/benchmark-protocol.md`。历史 `review_status=pass` 仅是旧版审查，不代表 V2 通过；严格检索用 `--require-benchmark`，无结果则按待验证方法实施，禁止宣称已获高保真认证。单例以 `audit_reference_fidelity.py --bundle ... --root ...` 核验；无bundle只查库存。

## 执行门禁

读过规范、代码运行、打开图片均不等于合规。每图按下列顺序执行；修图和短请求也适用。失败只交诊断或标记预览，不得称完成或PASS。

1. 读取 `references/personal-style.md`、`references/render-execution.md`、`references/reference-quality.md`、`references/reproduction-learning.md`、`static/core/contract.md` 与 `manifest.yaml`；运行 `scripts/route_figure.py 请求.yaml`，再运行 `scripts/plan_figure_method.py --query "任务+图型+数据字段" --output 方法合同.json`。方法合同绑定数据字段、专用包、核心层和失败条件。模型、推理档位和请求长短不改变本门禁。
2. 科学契约后运行 `scripts/retrieve_reproduction.py --query "任务+图型+数据结构" --require-validated --output 检索.json` 和 `scripts/retrieve_capabilities.py --query "任务+图型+数据结构" --output 能力检索.json`。编码前锁定唯一参考、图型家族、panel拓扑、必要结构、禁止替代项、核心R包及关键函数。`static-code-audited`只证明代码建档，`source-compared-needs-revision`只证明发现缺陷；只有图型家族、panel拓扑、必要结构、文字层级、注释层、信息密度六项全通过，且状态为`source-compared-png`、`review_status=pass`，才满足旧版高保真候选条件；V2还须绑定科学检查和当前运行/视觉证据。先锁定并实测来源方法使用的专用R包；禁止用基础ggplot2替代其核心布局能力。用户已授权且持有来源代码时，可检查包、函数、变换、排序和布局；禁止复制整段代码、来源数据或受限图片，生成脚本按当前数据合同独立重写。检索凭证必须进入CP2。
3. 参考图实际查看、Design Spec、CP0–CP2先完成。读取 `references/enforced-execution.md`。ggplot最终PNG只用 `bf_render_png`；把 `scripts/figure_style.R` 复制进项目并随代码交付。
4. 打开最终PNG，按实际使用尺寸审查，填写对象级inspection与Critic。复现任务必须用当前PNG重新生成原图并排图，分别审查布局、编码、字体、配色、信息密度；旧对照图在PNG变化后立即失效。每张PNG单独ledger。
5. 运行 `python3 scripts/validate_checkpoints.py checkpoint-ledger.yaml --json`。仅退出码0且CP0–CP4全部PASS可交付；保存输出。渲染凭据仅证明技术预检，不能替代视觉质量。

## 首版就实现

- 默认R、纯白、真实Arial/Helvetica文件；全部文字层显式字体，禁止sans回退。字体报错修设备或字体解析，不改成默认字体。
- 编码前列允许文本。默认无总标题、副标题、编号、脚注；必要组名、变量与单位保留。用户明确要求额外文字时记录原文授权并加入清单。
- 先定最终mm尺寸和字号、实测文字、分配数据/标签/图例槽位；离散热图单格正方，分类条≤3mm，图例外置；气泡细黑边。配色按语义与用户要求。
- 先预检再导出同一对象。字体、文字、尺寸、源文件或Spec变化，旧凭据失效；不得仅修用户指出的一项后沿用旧验收。
- 复现训练与视觉验证默认只输出PNG。包“已安装”、包“可加载”、函数“可运行”和PNG“已验图”分别记录；任何一级失败不得写成已学会。

门禁代码与阈值不由绘图任务自行删改。不得补写假凭据、从成图反向批准所有文字或降级Critic过检。未受托不重跑NGS。

Skill不能强制平台调用工具；可核验门禁约束实际执行流程，人工/模型视觉观察仍是可信声明。科学正确、技术合规、参考质量与用户认可分别报告。

回复只写已完成动作、证据、缺陷和下一步。避免“全面提升”“一键顶刊”“效果拉满”等宣传语，也不使用套话式总结；文件、数量、状态和限制用可核验名称表达。

VS Code/Codex安装与短请求处理见 `references/vscode-execution.md`。NEEDS_SPEC/NEEDS_REFERENCE必须先补齐条件；METHOD_CANDIDATE不代表允许渲染。
