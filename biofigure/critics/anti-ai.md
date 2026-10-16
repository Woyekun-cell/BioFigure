# Anti-AI Critic

检查大装饰标题、副标题、panel letter误入单图、解释框、UI卡片、圆角、阴影、徽章、无信息渐变、过饱和、过度对称、过量空白和everything-highlighted。

还要检查AI常见排版痕迹：图例压图、标签与标题重叠、默认字体混用、暖灰页面、重复图例、随意缩小字号、颜色循环复用、无意义小标题和画布脚注。

**底部说明为硬失败，与是否科学正确无关。** 检查整幅图最底边：样本设计/日期、方法、筛选阈值串和完整图注不可进入画布；caption、patchwork注释、手写textGrob等同对待。正常轴和分类图例不是脚注。必要n/P/q仅保留面板内紧凑标注。记录`footer_absent`实际观察；有说明则`footer_text=true`和`unrequested_text=true`，必须重绘。

逐字检查当前图内文本：AI备注/署名、自动生成与检查流程、PASS/NOT_VERIFIED、内部案例号、演示/推断免责声明均移图外。把它们写进白名单或获标题授权仍不能PASS；与当前科学内容无关的小字记`unrequested_text=true`并REVISE。保留有依据的ID、轴/单位、图例、n、统计量和比例尺；真正AI研究标签或模拟量纲不因含AI/simulated字样被删。PNG与实际PDF/SVG分别看，不沿用前次检查。

状态为PASS/REVISE/FAIL；每项给可见证据与最小对象级修复。目标是precision、restraint、层级和真实数据密度，不得为了“高级感”删数据、改阈值或添加机制装饰。

