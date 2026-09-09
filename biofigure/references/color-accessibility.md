# 配色与可访问性

先读[配色系统](palette-system.md)，运行库为 `palettes/palette-library.yaml`。用户提供颜色优先；未指定时按数据语义、类别数、背景和标记大小检索色板，不把“Nature风”“莫兰迪”或“马卡龙”当固定标准。

定性色只区分类别，不暗示大小；顺序色用于有序/连续量；发散色仅在真实零值、基线或参考中心存在时使用。记录 palette ID、语义映射、limits、center、NA色及截断。不同单位不得共用色标，任意范围中点不得冒充生物学零点。

浅色填充配深色轮廓或文字；浅色细线在白底慎用。红蓝、红绿和多类别图应增加位置、标签、线型或形状，颜色不得成为唯一证据。分类颜色跨面板保持同义，不按出现顺序循环。

`source_claimed_safe` 只说明来源声明，不能认证当前图；`diagnostic_required` 必须检查正常、deutan、protan，必要时 tritan 与灰度。检查实际点、线、透明度和背景，而非只看色卡。渐变相邻色接近属正常现象，应检查整体亮度顺序、数据范围和中心。

诊断命令：
```sh
python scripts/palette_check.py --kind categorical --colors '#4477AA' '#EE6677'
python scripts/validate_palette_library.py
```
CAM02-UCS 距离阈值仅作筛查，不是无障碍或期刊认证。依据：[colorspace](https://colorspace.r-forge.r-project.org/articles/color_vision_deficiency.html)、[ColorBrewer](https://colorbrewer2.org/learnmore/schemes.html)、[Scientific Colour Maps](https://www.fabiocrameri.ch/colourmaps/)。
