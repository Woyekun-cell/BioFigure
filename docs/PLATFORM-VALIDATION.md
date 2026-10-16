# Windows and macOS validation

[中文](#中文) · [English](#english)

## 中文

跨平台验收区分“代码执行”“统计与导出检查”“实际看图”。绿色的 CI 只证明本次技术检查通过；最后的 PNG 和 PDF 仍须查看，才可登记 CP4。

`Windows and macOS figure parity` 使用标准 Windows、macOS runner 和固定 R 4.6.1。每次从 GitHub 当前提交提取 `biofigure/`，仅安装 Skill，不复制仓库其余目录。Python 环境、R 包库、任务输出均新建；从含中文和空格的第三工作目录运行。

七个原创案例自动完成新输入绑定、统计、CP2、一次性授权和 R 绘图。技术检查包含独立重算 Welch 检验及置信区间、全部 2,000 个特征的 BH 校正、PNG 回执哈希、单页 PDF、物理尺寸、嵌入的 Arial、字号、页外文字和实际热图格子尺寸。稀疏热图必须物理正方形；5,000 行总览使用已声明的密集例外。

另外生成独立的外部模拟 CSV：保留 `01` 与 `1` 两个字符串组名及 `mg/L` 单位，分别验证 PNG-only 和 PNG/PDF。缺少测量单位、实验单位、独立性声明或出现重复样本 ID 时，必须在签发绘图授权前拒绝。

工作流先安装 `portable` 依赖并完成上述图与视觉回归检查，再安装 `all-public` 专用依赖、执行旧案例。专用依赖失败时，前一阶段的图和 `platform-smoke.original.json` 保留；汇总结果标明旧案例未运行及原因，不把失败改写成整体通过。

旧案例复跑须显式指定 `--include-replays --source-review-manifest FILE`。该文件记录维护者已实际查看的来源文件及 SHA-256。来源内容变化或缺少真实查看记录会拒绝，不能把“文件存在”写成已查看。来源查看记录只认证参考源；不认证新平台候选图，也不沿用历史 CP4。

候选图和技术 JSON 作为 Actions artifact 保留 14 天；不上传系统字体、真实研究数据或完整运行环境。字体由机器合法安装的 Arial 提供，不随仓库分发。字体版本和抗锯齿可能产生细微像素差异；统计、语义颜色、布局、尺寸及稀疏方格门禁保留。

运行记录需要逐次读取；本文不宣称任何尚未完成的 Windows 或 macOS 任务通过。

## English

Platform acceptance separates execution, statistical/export checks, and actual figure inspection. Green CI establishes the current technical checks only. The generated PNG and PDF still require inspection before CP4 can be recorded.

The `Windows and macOS figure parity` workflow uses standard Windows and macOS runners with R 4.6.1. It extracts only `biofigure/` from the checked-out GitHub commit. Each run creates a Python environment, an explicit R package library, and output projects, then executes from a third working directory containing spaces and Chinese characters.

Seven original examples complete fresh input binding, analysis, CP2, one-use authorization, and R rendering. Technical checks independently recompute the Welch comparison and interval and the full 2,000-feature BH adjustment; verify the PNG receipt hash; and inspect single-page PDF size, embedded Arial, text size, page bounds, and rendered heatmap-cell dimensions. Sparse heatmaps require physical square cells. The 5,000-row overview retains its declared dense exception.

A separately generated external synthetic CSV retains the distinct string group IDs `01` and `1` and the measurement unit `mg/L`. Both PNG-only and PNG/PDF delivery are tested. Missing measurement units, experimental units, independence declarations, or duplicate sample IDs must be refused before render authorization.

The workflow first installs the `portable` dependencies and completes these figures and raster regression checks. It then installs `all-public` specialist dependencies and runs the retained cases. If that installation fails, the first phase's figures and `platform-smoke.original.json` remain available; the combined summary records the unexecuted replay scope and its cause rather than reporting an overall pass.

Legacy fixed-input replays require `--include-replays --source-review-manifest FILE`. The manifest records the maintainer's actual inspection of exact reference-source bytes. Missing inspection or changed hashes are rejected. That review covers the reference only; candidate platform output receives no inherited CP4.

Actions artifacts retain candidate figures and technical JSON for 14 days. System fonts, research data, and the environment itself are not uploaded. Arial must be legally installed on the machine and is not redistributed. Font versions and antialiasing can vary slightly; scientific values, semantic colors, layout, physical dimensions, and sparse-cell gates remain required.

Inspect each run's evidence. This document makes no pass claim for a Windows or macOS job that has not completed.
