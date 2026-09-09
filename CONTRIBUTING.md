# 贡献指南 / Contributing

感谢你帮助改进 BioFigure。一般讨论、参考图分享和方向建议请进入 [GitHub Discussions](https://github.com/Woyekun-cell/BioFigure/discussions)；能够复现的问题和明确需求请使用对应的 Issue 表单。<br>
Thank you for improving BioFigure. Use [GitHub Discussions](https://github.com/Woyekun-cell/BioFigure/discussions) for open-ended ideas and visual references, and the matching Issue form for reproducible problems or concrete requests.

## 提交内容 / What to include

图型建议请说明科学问题、图的角色、数据结构、期望后端、交付格式和可公开访问的参考来源。成图问题请附最小代码、依赖版本、输出尺寸、字体解析结果和去敏后的截图。请清楚区分真实数据、模拟数据与示意内容。<br>
For a figure request, describe the scientific question, figure role, data topology, preferred backend, deliverable, and a publicly accessible reference. For rendering problems, include minimal code, package versions, output size, font resolution, and a redacted screenshot. Clearly distinguish measured, simulated, and schematic content.

请勿提交患者标识、未公开研究数据、访问令牌、受限数据库内容或无权再分发的代码与图片。可以用最小模拟数据复现布局问题。<br>
Do not submit patient identifiers, unpublished research data, access tokens, restricted database content, or code and images you cannot redistribute. A minimal simulated dataset is suitable for reproducing layout problems.

## 代码贡献 / Code contributions

1. Fork 仓库并创建范围明确的分支。
2. 保持 R 优先、后端锁定、固定随机种子、纯白背景和真实字体检查。
3. 新增 Pattern、Renderer 或 Critic 时同步更新索引、schema 与测试。
4. 运行 README 中的验证命令，并实际查看目标尺寸下的 PNG。
5. Pull Request 说明科学用途、设计变化、验证证据和已知边界。

1. Fork the repository and create a narrowly scoped branch.
2. Preserve R-first routing, backend locking, fixed seeds, white backgrounds, and real font checks.
3. Update indexes, schemas, and tests when adding a Pattern, renderer, or critic.
4. Run the README validation commands and inspect the PNG at its target size.
5. In the pull request, state the scientific use, design change, validation evidence, and known limits.

维护者会按科学正确性、可复现性、版面质量、来源许可和维护成本评估建议。参考图用于提取视觉原则，提交者仍需提供来源链接并遵守原始许可。<br>
Maintainers evaluate proposals for scientific correctness, reproducibility, layout quality, source licensing, and maintenance cost. Reference figures may guide visual principles; contributors must still provide source links and respect the original license.
