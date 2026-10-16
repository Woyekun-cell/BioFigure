# Windows/macOS code compatibility and validation

[中文](#中文) · [English](#english)

## 中文

[查看可选工作流示例](ci/windows-macos-parity.example.yml)。此文件位于 `docs/ci`，仅供审查，不会触发 GitHub Actions。

当前交付范围：Windows/macOS 代码兼容检查，加 macOS 实际绘图验收。按维护者本次要求，不继续 Windows 实机、虚拟机或 CI 测试，不启用自动工作流，也不要求用户追加 GitHub 授权。正常使用 Skill 不需要 `workflow` 权限。Windows 尚未实测，不能标为原生运行已通过。

兼容检查涵盖显式 UTF-8 文件读写、Windows ANSI 终端的 ASCII 安全 JSON 输出、含空格和中文的路径、LF 校验值、`R_GSCMD`／`gswin64c`／`gswin32c`、固定依赖与精确字体。非 UTF-8 输出流回归在 macOS 上模拟测试，不代表运行过 Windows。下述工作流仅作为未来可选验收方案保留。

本轮 macOS 验证完成 15 次正向绘图和 4 次预期拒绝，覆盖 13 个公开案例及外部 CSV／仅 PNG。新 Python 环境、Skill-only 安装、第三工作目录均已实测，R 包和合法系统字体仍复用本机环境。15 张 PNG 和 14 个 PDF 页面逐张检查；其中 14 项来自完整冷安装批次，Planarian 色条修复后以独立单例重新验证。38 项私有／历史测试未运行，未升级为通过。

跨平台验收区分“代码执行”“统计与导出检查”“实际看图”。绿色的 CI 只证明本次技术检查通过；最后的 PNG 和 PDF 仍须查看，才可登记 CP4。

可选的 `Windows and macOS figure parity` 方案使用标准 Windows、macOS runner 和固定 R 4.6.1。每次从 GitHub 当前提交提取 `biofigure/`，仅安装 Skill，不复制仓库其余目录。Python 环境、R 包库、任务输出均新建；从含中文和空格的第三工作目录运行。

七个原创案例自动完成新输入绑定、统计、CP2、一次性授权和 R 绘图。技术检查包含独立重算 Welch 检验及置信区间、全部 2,000 个特征的 BH 校正、PNG 回执哈希、单页 PDF、物理尺寸、嵌入的 Arial、字号、页外文字和实际热图格子尺寸。稀疏热图必须物理正方形；5,000 行总览使用已声明的密集例外。

另外生成独立的外部模拟 CSV：保留 `01` 与 `1` 两个字符串组名及 `mg/L` 单位，分别验证 PNG-only 和 PNG/PDF。缺少测量单位、实验单位、独立性声明或出现重复样本 ID 时，必须在签发绘图授权前拒绝。

工作流先安装 `portable` 依赖并完成上述图与视觉回归检查，再安装 `all-public` 专用依赖、执行旧案例。专用依赖失败时，前一阶段的图和 `platform-smoke.original.json` 保留；汇总结果标明旧案例未运行及原因，不把失败改写成整体通过。

旧案例复跑须显式指定 `--include-replays --source-review-manifest FILE`。该文件记录维护者已实际查看的来源文件及 SHA-256。来源内容变化或缺少真实查看记录会拒绝，不能把“文件存在”写成已查看。来源查看记录只认证参考源；不认证新平台候选图，也不沿用历史 CP4。

Windows 手动使用时，先确认 `python --version` 与 `Rscript --version` 可执行；若没有 `python3` 命令，用 `python` 或 `py -3` 运行同一脚本。Rscript 必须加入当前终端的 PATH。所有项目路径作为独立参数传递，无需修改源码中的本机目录。

若未来启用工作流，候选图和技术 JSON 将作为 Actions artifact 保留 14 天；不上传系统字体、真实研究数据或完整运行环境。字体由机器合法安装的 Arial 提供，不随仓库分发。字体版本和抗锯齿可能产生细微像素差异；统计、语义颜色、布局、尺寸及稀疏方格门禁保留。

运行记录需要逐次读取；本文不宣称任何尚未完成的 Windows 或 macOS 任务通过。

## English

[Review the inactive workflow source](ci/windows-macos-parity.example.yml). This file is stored in `docs/ci` for inspection and does not activate GitHub Actions.

Current delivery scope is Windows/macOS code-compatibility review plus actual macOS figure acceptance. At the maintainer's request, Windows native, virtual-machine and CI testing will not continue; the automatic workflow remains inactive and no additional GitHub authorization is required. Normal Skill use does not require the `workflow` scope. Windows native execution remains unverified.

Compatibility checks cover explicit UTF-8 file I/O, ASCII-safe JSON on Windows ANSI terminal streams, paths with spaces and Chinese characters, LF-bound checksums, `R_GSCMD`/`gswin64c`/`gswin32c`, locked dependencies and exact fonts. Non-UTF-8 stream regression was simulated on macOS and is not a Windows execution claim. The workflow below is retained as an optional future validation protocol.

The macOS run completed 15 positive renders and four expected refusals, covering 13 public cases plus external CSV and PNG-only use. The Python environment, Skill-only installation and third working directory were fresh; R packages and legal system fonts were reused. All 15 PNGs and 14 PDF pages were inspected. Fourteen accepted outputs came from the complete cold-install batch, and Planarian was rerun independently after its colorbar repair. Thirty-eight private/archive tests were not run and are not recorded as passes.

Platform acceptance separates execution, statistical/export checks, and actual figure inspection. Green CI establishes the current technical checks only. The generated PNG and PDF still require inspection before CP4 can be recorded.

The optional `Windows and macOS figure parity` workflow uses standard Windows and macOS runners with R 4.6.1. It extracts only `biofigure/` from the checked-out GitHub commit. Each run creates a Python environment, an explicit R package library, and output projects, then executes from a third working directory containing spaces and Chinese characters.

Seven original examples complete fresh input binding, analysis, CP2, one-use authorization, and R rendering. Technical checks independently recompute the Welch comparison and interval and the full 2,000-feature BH adjustment; verify the PNG receipt hash; and inspect single-page PDF size, embedded Arial, text size, page bounds, and rendered heatmap-cell dimensions. Sparse heatmaps require physical square cells. The 5,000-row overview retains its declared dense exception.

A separately generated external synthetic CSV retains the distinct string group IDs `01` and `1` and the measurement unit `mg/L`. Both PNG-only and PNG/PDF delivery are tested. Missing measurement units, experimental units, independence declarations, or duplicate sample IDs must be refused before render authorization.

The workflow first installs the `portable` dependencies and completes these figures and raster regression checks. It then installs `all-public` specialist dependencies and runs the retained cases. If that installation fails, the first phase's figures and `platform-smoke.original.json` remain available; the combined summary records the unexecuted replay scope and its cause rather than reporting an overall pass.

Legacy fixed-input replays require `--include-replays --source-review-manifest FILE`. The manifest records the maintainer's actual inspection of exact reference-source bytes. Missing inspection or changed hashes are rejected. That review covers the reference only; candidate platform output receives no inherited CP4.

For manual Windows use, first verify `python --version` and `Rscript --version`. If `python3` is unavailable, invoke the same script with `python` or `py -3`. Rscript must be on the terminal PATH. Project paths are separate command arguments; no developer-machine path needs editing.

If the optional workflow is enabled in the future, Actions artifacts will retain candidate figures and technical JSON for 14 days. System fonts, research data, and the environment itself are not uploaded. Arial must be legally installed on the machine and is not redistributed. Font versions and antialiasing can vary slightly; scientific values, semantic colors, layout, physical dimensions, and sparse-cell gates remain required.

Inspect each run's evidence. This document makes no pass claim for a Windows or macOS job that has not completed.
