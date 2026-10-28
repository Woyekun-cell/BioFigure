# Python 候补：官方授权渲染

R 为主要绘图路线；Python 仅在用户明确指定、需保留既有 Python 原生流程或 R 无合适实现时作为候补，记录选择原因。Spec 前锁后端，R 失败不静默改用 Python；切换须重新准备、授权和审阅，质控要求不降低。沿用 AnnData/Scanpy 已有 embedding、layer、样本顺序和颜色字典，不为画得更分离而重算分析。

首版官方入口是 `scripts/figure_style.py`，接受 Matplotlib `Figure`；seaborn/Scanpy 须先取得实际 Figure。其他对象、pyGenomeTracks/pyGenomeViz 或 CLI 的直接文件导出不自动取得正式凭据。支持 PNG 及 Design Spec 声明的 PDF/SVG；保存图片或生成回执均不自动授予 CP3/CP4 PASS。

当前明确拒绝需专用 cell-geometry 适配器的矩形热图，以及需要独立字形审计的 MathText/TeX 和文字 path effects（例如 Scanpy 标签描边）；普通 Unicode 文字检查真实字体的 charmap。需要热图时可在新 Spec 中改锁 R，重新准备、授权和渲染，不复用 Python 的旧证据。

## 环境与执行顺序

在当前项目运行，先把环境变量设为实际安装的 Skill 根目录。Matplotlib 使用可选依赖，不增加 R-only 路径的安装负担；seaborn/Scanpy 按任务另行准备。记录当前 Python、绘图库和系统字体版本，不沿用历史 R 案例或其他平台的通过状态。

```bash
export BIOFIGURE_SKILL_ROOT="/实际安装路径/biofigure"
python3 -m pip install -r "$BIOFIGURE_SKILL_ROOT/requirements-python.txt"
python3 "$BIOFIGURE_SKILL_ROOT/scripts/prepare_figure.py" request.yaml --output preparation-receipt.json
python3 "$BIOFIGURE_SKILL_ROOT/scripts/validate_design_spec.py" design-spec.yaml --preparation-receipt preparation-receipt.json
```

请求和 Spec 均锁 Python，保留同一套科学、统计与设计契约。准备与 CP2 通过后才写 `plot.py`；完成当前输入、真实字体、文字清单、物理尺寸及布局代码后，再签发授权。假设实际输入名为 `plot-data.csv`，签发顺序为绘图脚本、当前官方 helper、输入：

```bash
python3 "$BIOFIGURE_SKILL_ROOT/scripts/authorize_render.py" \
  --receipt preparation-receipt.json --design-spec design-spec.yaml \
  --source plot.py \
  --source "$BIOFIGURE_SKILL_ROOT/scripts/figure_style.py" \
  --source plot-data.csv --output authorization.json
python3 plot.py
```

有额外输入、统计表或渲染配置时，一并绑定；消费时保持相同 `source_files` 顺序。Spec 用独立 `design_spec` 参数，不重复放入 `source_files`。改脚本、输入、Spec 或 helper 后重新准备相应证据并签发新授权；一次授权只消费一次。

## 在现有绘图脚本中调用

`bf_font(family="Arial")` 返回实际字体的 `family`、`path` 和 `sha256`；只接受真实 Arial/Helvetica，缺失时报错，不回退 DejaVu。用 `with bf_style(font, size=7):` 包住创建 Figure 的绘图代码；它是局部 `rc_context`，不改用户全局配置。

下面是放入 `plot.py` 的导出片段。`fig` 是前面已按当前输入与 Spec 创建的 Matplotlib Figure；在创建它时应用上述样式。白名单来自事先批准的变量、标签和刻度，不能从最终 Text 列表反向批准。

```python
import os
import sys
from pathlib import Path

skill_root = Path(os.environ["BIOFIGURE_SKILL_ROOT"]).expanduser().resolve()
sys.path.insert(0, str(skill_root / "scripts"))
import figure_style as bf

# 在此之前，以 bf.bf_style(bf.bf_font("Arial"), size=7) 上下文创建 fig。
receipt = bf.bf_render(
    fig,
    "figure.png",
    design_spec="design-spec.yaml",
    authorization="authorization.json",
    source_files=[
        Path(__file__).resolve(),
        Path(bf.__file__).resolve(),
        Path("plot-data.csv").resolve(),
    ],
    dpi=300,
)
```

`bf_render(fig, png_path, *, design_spec, authorization, source_files, dpi=300, boxes=None, allowed_pairs=())` 从 Spec 读取物理尺寸、字体、最小终尺寸字号、允许文字/标题及导出格式。`source_files` 必须包含正在执行的脚本和实际导入的 helper 自身；不手写另一个同名 helper 路径。

需要声明槽位时，`boxes` 为毫米单位的 `[{"id": ..., "x": ..., "y": ..., "w": ..., "h": ...}]`；`allowed_pairs` 使用按 ID 排序的 `id1:id2` 键，逐对说明允许关系。实际 artist 使用设置的 `gid` 或回执中的 `text-N` / `axes-N` / `legend-N` ID。入口在真实 `draw` 后检查文字、axes 和图例边界及碰撞；槽位声明不证明所有数据标记没有真实遮挡。

## 成图与验收

helper 使用 `biofigure-matplotlib-v1` 标识，写入 `figure.png.render.json`，绑定当前 PNG、所选 PDF/SVG、Spec、授权、字体与来源文件哈希；`exports` 逐项记录 `path`、`sha256` 和 `format`。回执 `status: PASS` 仅表示技术预检通过，不等于 CP3/CP4。figure、axes 和导出背景保持 `#FFFFFF`；密集数据可栅格化，文字、轴和关键标注保留矢量。

渲染后打开当前 PNG 及每种交付 PDF/SVG，按最终物理尺寸检查缺字、文字位置、裁切、重叠、白底、配色、方格与图例。Scanpy 关闭未批准标题，固定图例、点径、透明度和颜色范围；跨图复用同一 embedding 范围。绘图库默认主题与 `rcParams` 不能替代逐对象检查。

CP3 绑定当前渲染回执；inspection 填写该回执的 `render_receipt_sha256` 和实际观察，CP4 完成相应 Critics 与 `final_size_checks`。随后运行：

```bash
python3 "$BIOFIGURE_SKILL_ROOT/scripts/validate_checkpoints.py" checkpoint-ledger.yaml --json
```

技术检查、实际审图和用户认可分别记录。按[变更范围与收口规则](workflow.md#按变更范围复核与收口)完成必要检查后交付；不因无关文案或归档改动重复绘图，也不因 PNG 字节相同复用旧授权或审阅。

字体及上游绘图约束参考：[Matplotlib 字体](https://matplotlib.org/stable/users/explain/text/fonts.html)、[Scanpy 绘图](https://scanpy.readthedocs.io/en/latest/tutorials/plotting/advanced.html)。这些上游文档不替代当前 helper 与文件的验证。

