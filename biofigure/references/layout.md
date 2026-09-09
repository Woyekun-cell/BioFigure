# 排版与信息层次

先确定目标宽高mm，再分配五个 bbox：data、annotation、legend、labels、outer margin。每个 bbox 记录位置、物理尺寸和最长内容；热图树高、分片gap、色条长度、图例行列数都进入计算。

首轮布局顺序：测最长文本 → 预留标签 → 放数据区 → 放注释 → 在数据区外放图例 → 检查余白。不要先画满画布再靠 tight_layout、patchwork spacer 或缩小字体抢救。

所有位置必须由画布、字体实测 bbox 和预留槽位推导；禁止把试出来的绝对坐标当通用方案。复杂图先计算极坐标半径、树/轨道宽度、中心嵌图和色标占位，首轮碰撞说明布局合同需重算。

硬检查：所有关键 bbox 在 canvas 内；互斥槽位相交或关键文字遮挡证据即失败；合法的直接标签、嵌入矩阵数值与树旁注释记录对象级允许关系。R用grid viewport/grob尺寸，Python用renderer bbox；自动检测后仍须打开实际PNG。背景必须纯白，非数据空白应有节奏但不能挤压内容。

## 文字—面板尺度

先用最长文本和 cap-height 估算 labels/annotation/strip 的物理 bbox，再定字号与 panel 间距。通用预览轴/图例 7–9 pt；明确按Nature当前投稿规范时普通文字5–7 pt、组图编号8 pt，优先7 pt并按最终尺寸检查，strip 标题 ≤ 1.15×轴标题，数值标注 ≤ base size，通用预览字号下限6 pt，期刊5 pt只在确实可读时使用。标题或数值与边框至少留 1 个 cap-height，strip 高度至少 1.5 个 cap-height；超长标签依次换行/缩写、扩大面板、减少标签，最后才缩小字号。若 bbox 越界、压线、遮挡或文字视觉重量大于数据区，判 `REVISE`；不得靠裁切、`clip=off` 或透明度掩盖。

单图不添加panel letter、总标题、副标题、解释框。组图先逐张通过，再按绘图区而非含长标签的外框对齐；共享图例只用于变量、单位、变换和limits完全一致的映射。组装后重新测bbox、字体、格子和色阶。

若固定版面与可读性冲突，优先分块、换行、减少按规则选出的标签或拆分主图/扩展图；不得拉伸矩阵、静默删数据或把字体压到不可读。依据：[patchwork](https://patchwork.data-imaginist.com/articles/guides/layout.html)、[Nature面板](https://research-figure-guide.nature.com/figures/building-and-exporting-figure-panels/)。

统计区高度按最大数据标记/误差线上界、注释文字高度与预设比较层数推导；不要凭常数把y轴扩大一倍。气泡矩阵按最大点径与行列间距设计，避免小点稀疏地散在大画布上。
