# VS Code 中执行 BioFigure

适用 Codex 扩展。将完整 biofigure 目录放到项目 `.agents/skills/biofigure`，或个人 `~/.agents/skills/biofigure`；不要只复制SKILL.md。脚本以技能目录为根定位资源，项目数据路径用绝对路径。其他扩展是否读取该位置须单独验证。

请求示例：`$biofigure 用CSV画β森林图，estimate/lower/upper为估计与95%CI，label为行名；先核对字段，按Skill门禁执行。`

短请求先读取入口；未指定图型时先依据数据和问题提出首选/备选，不由检索器替用户决策。实验单位、配对、比较方向等必要科学字段缺失才返回NEEDS_SPEC；不擅自生成模拟数据。方法规划结果不是渲染许可证。

交付前运行validate_checkpoints，并查看最终PNG。脚本退出0不代表视觉通过；缺少CP证据只能给标明状态的预览。换模型或推理档位仍执行同一流程。不能保证宿主一定调用Skill，也不能将规则文件当作跨模型实测。

官方说明：https://developers.openai.com/codex/skills
