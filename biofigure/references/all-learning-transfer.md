# 全量学习与类似图迁移

要求覆盖全部学过的案例。`atlas/learned-method-index.json`从SciDraw、顶刊、论文manifest、Nature六案、MBE面板、番茄合同、awesome图位/布局及来源benchmark汇聚；案例、面板和方法计数分别报告。

发现阶段运行`find_figure_reference.py`，以完整库的紧凑语义索引返回前三条图/码定位卡；无需预读全部主题。选定ID后读取完整合同。正式`prepare_figure.py`仍检索完整方法并重验材料。打开所选候选的`mandatory_read_set`、源图与核心源码；保留已有输入、排序、变换、专用包、色义、对齐和失败修法。新数据允许独立适配；缺原研究输入不阻止合规的新数据绘图。

Spec写`reference_evidence.learned_method_reuse`：`adopted`列方法ID；`rejected`逐条列`method_id/reason`；采用时填写`data_adaptation`和`known_failures_addressed`。CP2重新检索并核对源码/方法页哈希，不能空掉候选来绕过。不同图型、实验单位或数据层级必须给出拒绝依据。

“掌握”按每条方法核验：先新输入迁移，再长标签、多组、缺失/极值及打乱元数据顺序的压力测试；两次独立运行；终尺寸核对全部必要结构、键对齐、尺度、图例和文字。只变seed或重跑原样例不能代表迁移。专用包布局不可用通用形状代替；模拟数据只测试方法，不能生成研究结论。

未测状态不改成PASS。已学源码、一次重绘、固定样例重复、新数据迁移、压力测试和用户验收各自记证据。补齐实际测试后才逐案升级；同族成功不代表其余案例通过。

学习记录中的旧路径、编号冲突、简化替代和待修缺陷必须带入新调用。`work/2026-09-26-six-repositories/`尚存唯一来源证据，迁移并核对哈希前禁止清理。新图/修图验收后将参数、输入合同和失败回归追加原主题包，并重建索引；不依赖对话记忆。

持久验收存`atlas/learned-method-validations.json`。运行`validate_learned_reuse.py --method-id <ID> --new-input <bundle> --repeat <bundle> --stress <bundle>`，仅接收永久目录中同方法的完整证据：新输入须改变维度并绑定不同于原fixture的输入；三次独立进程，前两次同脚本/输入/包且PNG一致；压力合同覆盖长标签、多组、缺失、极值、乱序键。每包仍须预设科研检查、真实输入、六维源图对照及无重叠/裁切/缺字。这认证有界、来源暴露的复用，不认证盲迁移或任意数据。

登记时保留旧证据；索引重建不清空验证表。每次重验原材料、bundle及R/包/实际字体环境，漂移即失效。已验方法须在`adapter_decisions`选择reuse并绑定合格渲染器哈希，实际渲染源也须含同哈希；改实现声明adapt、合同差异及重新验证，不能继承旧PASS。重复须PNG及PDF实际外观相同。

布局另验`source_density_contract`：绑定源图哈希，记录边距、行/格距、面板间距、图例排列及必要空白；review绑定实际渲染器的geometry/QC产物并记录原图对照。无重叠不代表留白合格，不靠缩字、丢点或裁极值提高密度；三角矩阵空区、真实分布空隙等保留依据。用户否定布局后新建版本，旧视觉PASS不迁移。

原源码语法问题列在`atlas/source-syntax-audit.json`，采用时逐条写`source_issue_resolutions`；原始源码不改。已学未验不能升级为掌握。

字号按`layout.md`预设起步，逐角色依实际图文比例调整，同步Spec/样式/输入配置。验收绑定实际布局角色、PDF有效字号与终尺寸可读性观察；预设或最低字号合规不能替代成图审查。
