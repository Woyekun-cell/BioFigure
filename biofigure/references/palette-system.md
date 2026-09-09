# BioFigure 配色库

运行库：`palettes/palette-library.yaml`。先按数据语义选 `categorical`、`sequential` 或 `diverging`，再按类别数、背景、标记大小和跨面板一致性选择具体色板。用户颜色优先。

来源分三层：Okabe–Ito、Paul Tol、viridis、Scientific Colour Maps 等强调可访问性；ggsci 的 NPG/AAAS/Lancet/NEJM/JAMA 仅为期刊图形启发，不是期刊官方色标；Morandi、Macaron、Navy–Coral、Marine Stress 是 BioFigure 自定义方案，不宣称天然色盲安全。

分类色不表达大小；顺序色只用于有序或连续量；发散色仅用于存在真实零点、基线或参考中心的变量。禁止因“好看”给无中心数据套发散色，也禁止把类别映射成同色相深浅造成伪顺序。

每次调用记录 palette ID、颜色与语义映射、limits、center、NA色、截断和用户覆盖。`source_claimed_safe` 仍须检查实际点线、透明度与背景；`diagnostic_required` 必须运行 `scripts/palette_check.py`，并用形状、线型或标签补充颜色。

期刊启发色板通过 ggsci 5.2.0 固化为十六进制，避免运行环境变化；连续科学色图记录来源版本。详情见库内 `sources`。

