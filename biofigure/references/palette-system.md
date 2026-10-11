# BioFigure 配色库

运行库：`palettes/palette-library.yaml`。先按数据语义选 `categorical`、`sequential` 或 `diverging`，再按类别数、背景、标记大小和跨面板一致性选择具体色板。用户颜色优先。

来源分三层：Okabe–Ito、Paul Tol、viridis、Scientific Colour Maps 等强调可访问性；ggsci 的 NPG/AAAS/Lancet/NEJM/JAMA 仅为期刊图形启发，不是期刊官方色标；Morandi、Macaron、Navy–Coral、Marine Stress 是 BioFigure 自定义方案，不宣称天然色盲安全。

分类色不表达大小；顺序色只用于有序或连续量；发散色仅用于存在真实零点、基线或参考中心的变量。禁止因“好看”给无中心数据套发散色，也禁止把类别映射成同色相深浅造成伪顺序。
白色中心只表示声明过的中性值；两端须按相同limits映射，跨可比面板锁定中心和范围。若零附近仍含重要差异，避免过宽白区造成信息消失。

每次调用记录 palette ID、颜色与语义映射、limits、center、NA色、截断和用户覆盖。`source_claimed_safe` 仍须检查实际点线、透明度与背景；`diagnostic_required` 必须运行 `scripts/palette_check.py`，并用形状、线型或标签补充颜色。

从论文学习配色时，分别标明“源码参数”“原图观察”“内部质控图”；仅看原图不能宣称精确 HEX。类别颜色用标签→色值命名映射，不依赖数组顺序；若两个脚本顺序不一致，先核对实际标签。不同模态或量纲各用独立色标，可比较面板的同一变量才锁定色标范围。随机生成的质控类别色不能冒充发表图配色。

## 项目一致性硬门

项目首图创建唯一 `project-style.yaml`，锁定 palette ID、变量→色值、字体角色字号和允许尺寸等级。每张 Design Spec 用相对路径与 SHA-256 绑定；`validate_design_spec.py` 逐项比对。相同语义跨图必须同色，同一项目不得因图型切换而换色系。确需偏离时写 `exception_basis`，更新注册表哈希并使旧验收失效。

期刊启发色板通过 ggsci 5.2.0 固化为十六进制，避免运行环境变化；连续科学色图记录来源版本。详情见库内 `sources`。

## 用户彩色验收要求

首次渲染即使用语义彩色；参考图黑白时记录用户覆盖，不沿用黑白作为终图。颜色对应类别、模态或连续量，单类别可用单一彩色，不反造类别。轴线和文字可用中性色；只有背景、标题或图例有颜色不算数据图通过。CP4的`semantic_color`检查必须记录`colored_data_marks: true`与实际成图证据，仍须逐图审查可读性；批量交付展示所有终图。
