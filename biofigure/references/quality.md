# 成图硬门槛

代码退出0、文件存在、Darwin得分或自动脚本通过都不等于成图通过。必须打开实际PNG，以目标尺寸看全图，再放大局部。

## 必查证据

- 科学：输入/绘出数量、样本与metadata、变换、NA、排序、聚类、单位、n、方向、p/q和色阶中心一致。
- 布局：canvas/data/annotation/legend/label bbox均在画布内且互不相交；无裁切、乱码、字体警告、重复图例和未要求标题。
- 视觉：第一眼重点明确，信息密度均衡；纯白背景；Helvetica/Arial真实生效；颜色语义唯一；最终尺寸下线、点、格子和文字可读。
- 导出：PNG重开；SVG/PDF文字、字体、透明度、栅格层和关键对象复查。密集层栅格化需记录原因和dpi。
- 可复现：代码零警告；记录输入摘要、随机种子、顺序、语言、包版本、字体和设备。

Scientific Critic 永远运行。publication/reference-guided/reproduce 再运行 Visual Critic、Publication Critic、Anti-AI Critic。任何样本错配、错误尺度/方向、重叠、裁切、missing glyph、设备/字体 warning、错误颜色语义或未打开实际成图均为 hard failure；先给对象级修复并重画。

结构化 inspection evidence 是可追责的检查声明，不是“人眼已查看”的密码学证明。当前任务必须有实际 `view_image`/图形查看器打开动作；仅存在 YAML 或仅跑自动脚本不能宣称视觉 PASS。机器门禁独立核对空白、内部主导灰底、白色边角、尺寸、文件哈希与 SVG/PDF 实际字体声明。

离散热图额外测最终单格宽高；密集热图检查全量行保留、栅格层和稀疏标注规则。色觉模拟检查整图，不只色卡；未运行必须写not_verified。
