---
name: biofigure
description: 设计、绘制、精修或审查生物科研图；R优先，兼容Python，检查科学语义、字体、排版与实际成图。
---

# BioFigure 3.2.0

## 执行门禁

读过规范、代码运行、打开图片均不等于合规。每图按下列顺序执行；修图和短请求也适用。失败只交诊断或标记预览，不得称完成或PASS。

1. 读取 `references/personal-style.md`、`references/render-execution.md`、`references/reference-quality.md`、`references/reproduction-learning.md`、`static/core/contract.md` 与 `manifest.yaml`；运行 `scripts/route_figure.py 请求.yaml`。
2. 科学契约后运行 `scripts/retrieve_reproduction.py --query "任务+图型+数据结构" --output 检索.json`，只读3–5个派生案例。禁止查看或复制案例原代码；从空白脚本按用户数据自然编码。检索凭证必须进入CP2。
3. 参考图实际查看、Design Spec、CP0–CP2先完成。读取 `references/enforced-execution.md`。ggplot最终PNG只用 `bf_render_png`；把 `scripts/figure_style.R` 复制进项目并随代码交付。
4. 打开最终PNG，按实际使用尺寸审查，填写对象级inspection与Critic。每张PNG单独ledger。
5. 运行 `python3 scripts/validate_checkpoints.py checkpoint-ledger.yaml --json`。仅退出码0且CP0–CP4全部PASS可交付；保存输出。渲染凭据仅证明技术预检，不能替代视觉质量。

## 首版就实现

- 默认R、纯白、真实Arial/Helvetica文件；全部文字层显式字体，禁止sans回退。字体报错修设备或字体解析，不改成默认字体。
- 编码前列允许文本。默认无总标题、副标题、编号、脚注；必要组名、变量与单位保留。用户明确要求额外文字时记录原文授权并加入清单。
- 先定最终mm尺寸和字号、实测文字、分配数据/标签/图例槽位；离散热图单格正方，分类条≤3mm，图例外置；气泡细黑边。配色按语义与用户要求。
- 先预检再导出同一对象。字体、文字、尺寸、源文件或Spec变化，旧凭据失效；不得仅修用户指出的一项后沿用旧验收。

门禁代码与阈值不由绘图任务自行删改。不得补写假凭据、从成图反向批准所有文字或降级Critic过检。未受托不重跑NGS。

Skill不能强制平台调用工具；可核验门禁约束实际执行流程，人工/模型视觉观察仍是可信声明。科学正确、技术合规、参考质量与用户认可分别报告。
