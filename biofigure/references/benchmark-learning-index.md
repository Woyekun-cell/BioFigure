# 学习与 Benchmark 总入口

索引覆盖全部已学记录；发现阶段按图型、数据含义与科研问题检索，避免先读全部主题与完整JSON。同主题继续追加。原图、源码、运行、原图对照、新输入迁移和用户验收分别记录。

```bash
python3 scripts/find_figure_reference.py --query "相关气泡图 分组 correlation"
python3 scripts/find_figure_reference.py --case-id SCICASE-024
python3 scripts/find_figure_reference.py --list-types
python3 scripts/find_figure_reference.py --type "森林图" --query "置信区间"
python3 scripts/retrieve_learned_methods.py --case-id SCICASE-024
```

第一步默认前三条定位卡，不调用R、PDF或复用认证；按原始ID绑定路径。来源页资产可能含教程拼图/复现图，不能自动当论文原图；代码预览仅前两个片段，选ID后读全合同。材料缺失/配对冲突必须重审。第二步看卡；第三步只读选定合同、必读材料与原图。将`learned_method_id`写入request重新prepare，CP2说明采用/拒绝、数据适配及缺陷处理。正式门禁完整，不用轻检索替代。

轻索引`atlas/figure-reference-catalog.json`自动按完整索引及生成器内容哈希失效；`--refresh`重建。新增学习仍先运行`build_learned_method_index.py`，同步生成轻索引。历史登记不代表当前资格；原图质量需人工看图，排名只反映元数据匹配。

分类入口：`library/按图型检索/类别/来源图、对应代码/图型_用途_原ID/`，保留原始文件，用中文相对软链接集中浏览。`00_分类总索引.tsv`保留原名、路径、哈希、图/码定位和风险；`01_链接清单.json`用于核验、重建与限定清理。复合图有交叉入口；论文总览、无明确图型及已知配对冲突分列。分类依据标题/图合同，不从绘图包或错误旧标签推断。来源页候选不等于论文原图，代码回原路径执行以保留依赖；40条旧分段待核提示保留。更新学习后运行`python3 scripts/organize_figure_library.py --refresh`；先验哈希/冲突，同名普通文件或错误软链接拒绝覆盖，未列文件不清理。
## 全部主题

- SciDraw：157项，[案例入口](scidraw-benchmark-index.md)、[学习](scidraw-learning.md)。代码/源图配对与历史错误须重审；内部模拟不等于新输入迁移。
- 顶刊：83篇、365代码块、99期合集；[1–80](topjournal-001-080-learning.md)、[86/89/97/98](topjournal-081-100-learning.md)。训练序号不等于期号；源图与源码在`library/topjournal-corpus/`，复现材料在`benchmark/library/topjournal/`。缺原数据及未通过项保留。
- 单细胞七案： [Han](han-foregut-single-cell-learning.md)、[Wahle](wahle-retinal-single-cell-learning.md)、[Hochgerner](hochgerner-dentate-single-cell-learning.md)、[Trevino](trevino-cortex-single-cell-learning.md)、[Yu](yu-interneuron-single-cell-learning.md)、[Ma](ma-primate-pfc-single-cell-learning.md)、[Fleck五类方法](../library/single-cell/fleck-organoid/data/metadata/source-manifest.json)。源图/源码/输入缺口在`library/single-cell/*/data/metadata/source-manifest.json`；未证明整套原图复现。
- 基因组六案：`library/genomics/`中的ape-t2t、arabidopsis-27、barley-pantranscriptome、rpe1-reference、[大麻泛基因组](../library/genomics/cannabis-pangenome/data/metadata/source-manifest.json)、[DPM多组学](../library/genomics/dpm-multiomics/data/metadata/source-manifest.json)。29配方定位输入、源码与原图。新两案学习共线性双编码轨道、散点边际分布、方向热图、气泡阵列、证据网络；作者表与原码缺口分别记录，未运行原图渲染。旧案选定结构模拟/表重绘不等于原文数值、全图或全流程复现。
- [Nature基因组/多组学六案](nature-genomics-multiomics-learning.md)：六篇、11选定图；限定作者表复算另记，仍为候选。
- [MBE冻融](msad040-visualization-learning.md)：23主面板、22补图及补表；S5/S9/S13限定重绘，无作者绘图源码。
- [番茄泛基因组](pangenome-learning.md)：15选图合同及统计/源码差异；Fig2a–c源表重绘，不等于全流程。
- [awesome视觉布局](awesome-scientific-figure-learning.md)：29图位、12布局合同；视觉语法不认证原科学方法或数据。
- [六项目](six-project-benchmark-learning.md)、`benchmark/cases/`、`benchmark/evidence/`：mCA、Pearson、RA、QC、Populus、TooManyCells及已验收合同；固定结构成功不继承为新数据PASS。
- `benchmark/library/core-examples/`：线性、桑基、ANOVA和三角相似度等基础样例，方法及数据边界分别保留。

## 状态与复用

读[全量迁移](all-learning-transfer.md)、[缺陷](all-learning-audit-defects.md)及[固定样例重复](stable-template-reuse.md)。源码与历史PASS只是证据；每条方法通过新输入、压力、独立复跑和终尺寸验收后，登记持久验证表。每次调用重新验哈希，不靠对话记忆。

问题/单位 → 检索/选定方法 → CP2 → 编码 → 终尺寸成图审查 → 归档原主题。保留原始输入、脚本、终图、环境及QC；唯一work证据迁移并验哈希前禁止清理。

复杂基因组作者数据图与图库修订：见[八例来源与方法索引](genomics-source-gallery-learning-20261011.md)。
