# 个人图库与偏好维护

## 静默学习与个人收藏

- 用户明确指定或反复修改的视觉设置记作 `request`；本次独立选择、已在最终绘图参数核实的特征记作 `output`。原封套用的模板、期刊规定、上次学得的默认、未采用的草稿均不计。沿用同一 task ID 处理返工。每个图族、每个特征分别统计最近五个有信号的不同任务：同一值获得三次明确要求，或在其中四次出现，自动用于下次；后来的习惯按同一规则更新。静默写入，无需确认或通知。
- 主绘图 Agent 或既有反馈 Agent 用 `python3 <Skill根>/scripts/personal_style.py observe --family time-series --task <稳定任务ID> --feature point_emphasis --value points --source request`。已经按最终渲染核定时可用 `--source output`。当前结构化特征为 `point_emphasis`（points/balanced）、`grid`（light/none）与 `legend_position`（top/right/bottom/left）。仅记录审美设置；一张图的实验单位、配对、统计和出处总从任务输入核实。
- 当前任务设计与明示要求优先。需要选参考时，prepare 可读匹配图族的个人设置和最多三个已星标的参考指针。只用星标图作审美线索，可附用户喜欢的特征标签。使用同一份本地 SQLite，环境变量 `BIOFIGURE_PERSONAL_DB` 可切换个人库。
- 完成绘图只交付到项目输出目录。只有用户说收藏、保存到个人图库或导入参考时才收图。使用 `python3 <Skill根>/scripts/personal_style.py import <图片> [--family <图族>] [--star] [--tag <风格描述>]`，已有参考可用 `star <ID>` 或 `unstar <ID>`。macOS 可主动运行同一脚本的 `pick` 打开系统选图框并点「★ 喜欢并导入」；日常绘图保持后台。导入按内容去重，原图与项目数据留在原处。

## 日常命令

`biofigure` 是可选 PATH 快捷命令，下列示例也可用 Skill 根下的 `bin/biofigure`。图片、请求文件和输出目录均相对于调用者当前目录。命令通过共享的个人 SQLite 协作；默认位于 `~/.local/share/biofigure/personal.sqlite`，主动收藏的图片保存在该文件旁边的 `personal.sqlite.images/`。备份个人图库时保留两者。按项目或用户隔离时，给各宿主设置相同的 `BIOFIGURE_PERSONAL_DB` 绝对路径。

| 意图 | 调用 |
|---|---|
| 导入参考并标记喜欢的部分 | `biofigure gallery import "参考图.png" --star --tag "图例在底部"`，返回可复用的图卡 ID |
| 查看、点星、取消星标 | `biofigure gallery list`、`biofigure gallery star 图卡ID --tag "留白"`、`biofigure gallery unstar 图卡ID` |
| 用几张参考重新设计 | `biofigure gallery brief --family time-series "保留趋势，突出原始点" "参考甲.png" "参考乙.png"`；支持任意数量的临时图片路径、个人图卡 ID、方法 ID，完整仓库也能读已构建的公开图库 ID |
| 让 Agent 自己找参考 | `biofigure gallery brief --family time-series "比较两组随时间的变化"`。返回少量匹配候选、已学设置与星标，宿主读取选中的材料、设计并验证 |
| 看当前图族习惯 | `biofigure gallery get --family time-series` |
| 运行随包模拟例 | `biofigure preview-time ./time-preview`。输出目录应为空或尚未创建；用 `--input 数据目录` 换数据 |
| 明确收藏成图 | `biofigure gallery save ./time-preview` 核对预览哈希后入库；其他成图传文件，如 `biofigure gallery save 图.png --family matrix` |

时间预览包含原始绘图表、设计、[示例代码和来源](../examples/personal-time-response/method.json)。自有数据按示例提供 `plot_data.csv` 与 `design.json`，逐行给 observation_id、subject_id、group、time、value，声明重复或独立取样与组别配色。结果包括 PDF、PNG、分组汇总表、实际连线表和 checks.json。它检验描述性图层、采样设计与实际数据的一致性。正式投稿图继续走 prepare、CP2、实际成图审阅与 CP4。

## 网页图库与反馈调度

在仓库根运行 `sh biofigure/bin/gallery-local`，再打开 `http://127.0.0.1:18807/BioFigure/`。本机版可提问、收藏、选图、编辑图卡和执行重绘。首次启动建立各自的示例快照，图片和公开材料按浏览与选图需要缓存。用 `--refresh-examples` 更新快照，已有缓存可加 `--offline`，已有示例文件可用 `--site <目录>`。

网页使用当前用户的个人 SQLite 保存 Star；隐藏图卡和修改标题、简介使用该档案旁的独立数据库。默认档案为 `~/.local/share/biofigure/personal.sqlite`。不同部署可用 `BIOFIGURE_PERSONAL_DB` 设置各自路径。新图默认保存到 `~/.local/share/biofigure/drawings/personal/`，更换档案时使用对应的独立子目录，可用 `--outputs` 指定目录。这些个人操作和产物保存在本机。

网页可选已登录的 Codex、Claude Code、Google Antigravity、Gemini CLI、OpenCode、CodeBuddy CLI，或填写 API Key。本机 CLI 可沿用各自登录和默认模型。个人 Google 账号选 Antigravity（`agy`），Gemini API 则使用 Google 发放的 API Key。兼容 API 可自定义服务地址与模型。优先使用 PATH 中的 CodeBuddy CLI，也支持含完整 CLI 的 WorkBuddy 应用包。连接配置随个人档案保存，Key 存在本机 `personal-host.json`，权限为 `0600`。协议和地址未变时，留空可保留 Key。更换地址需重填 Key。

每次提问保留所选图 ID 和来源，最多附 12 张缩略图。选择修改方案并点击执行后，所选服务使用原脚本和绘图输入重绘，返回 PNG、PDF、可编辑脚本和本次检查文件。多图时指定要修改的主图。可基于上次结果继续修改，刷新页面后恢复任务。原始材料缺失或运行失败时显示具体原因。结果是待审预览，科研与视觉验收按当前成图进行。

API 问答只开放读取所选材料的工具；重绘仅写本次任务目录，脚本通过 macOS `sandbox-exec` 或 Linux `bwrap` 运行，禁网络并限制文件访问。未检测到可用安全运行器时不执行脚本，返回具体原因。API 模型需支持对应协议的图像与工具调用；服务端拒绝或能力缺失会显示错误，不切换模型。

Personal Agent 可按时间调用 `biofigure gallery changes --after <上次游标>` 查看增量，或调用 `biofigure feedback consume-gallery --store <本机反馈队列目录>` 消费一批。两端使用同一 `BIOFIGURE_PERSONAL_DB`。返回 `more: true` 时继续消费下一批。消费按个人库和事件序号去重，重跑只处理增量。星标和撤星是参考信号，设计修改保留 task 范围。绘图继续按当前输入核实科研设计。

## 扩展自己的规范

仅某个项目或期刊要求的字体、留白、图例等写进该任务的设计配置，来源标为 `journal` 或 `template`。若当前数据更适合另一种画法，给出首选及依据；数据允许时可切回个人样式。为新风格增加可执行选项时，在 `scripts/personal_style.py` 的 `FEATURES` 声明可选值，在适用的 renderer 实现，并用新数据核对实际图像和数据映射。个性化与科研验证使用各自的证据。
