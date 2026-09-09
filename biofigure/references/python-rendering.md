# Python 兼容实现

Python 用于 AnnData/Scanpy 原生对象、Python 专用基因组轨道或用户指定；普通统计图与复杂矩阵默认先考虑 R。沿用已有 embedding、layer、样本顺序和颜色字典，不为画得更分离而重算分析。

字体只接受系统实际存在的 Arial 或 Helvetica。用 font_manager.findfont(..., fallback_to_default=False) 验证；找不到即报错，不回退 DejaVu。figure、axes、savefig 均为 #FFFFFF；svg.fonttype="none"，pdf.fonttype=42。

写代码前按 canvas/data/annotation/legend bbox 分配 figure.add_axes 或 GridSpec；最长标签和图例尺寸进入布局。tight_layout/constrained_layout 只可在已分配空间内微调。渲染后测所有关键 bbox 是否在画布内且互不相交。

Scanpy 输出必须显式关闭默认标题，固定 legend_loc、frameon、size、alpha、palette、vmin/vmax 和 save 路径；同一 embedding 跨图共享坐标范围。稀有群体用绘制顺序、形状或直接标签保护。

密集点或矩阵只栅格化数据层，文字/轴/关键标注保留矢量。首轮打开 PNG 检查缺字、裁切、重叠和白底；代码退出0不算视觉通过。依据：[Matplotlib字体](https://matplotlib.org/stable/users/explain/text/fonts.html)、[Scanpy绘图](https://scanpy.readthedocs.io/en/latest/tutorials/plotting/advanced.html)。

