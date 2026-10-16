# 来源与权利说明 / Provenance and rights notice

BioFigure 自有代码、文档及完全使用自有模拟数据生成的示例图按 MIT License 发布。示例中的名称与数值均为演示用途。
BioFigure-owned code, documentation, and figures generated entirely from first-party synthetic data are released under the MIT License. Names and values in the examples are illustrative.

仓库引用的软件包、论文、网站与外部项目保留各自权利和许可证。链接与方法说明不构成第三方材料的再授权。
Referenced packages, papers, websites, and external projects retain their own rights and licenses. Links and method notes do not relicense third-party material.

SciDraw 学习材料仅保留经过蒸馏的图形特征、来源索引和适用边界；BioFigure 不把上游原始代码或图片声明为自有资产。使用者复制第三方代码或图形前应核对原始来源与许可。
SciDraw learning material is retained only as distilled visual features, source indexes, and scope boundaries. BioFigure does not claim upstream code or images as its own. Users should verify the original source and license before copying third-party code or graphics.

Nature 及其他期刊名称用于描述排版与审稿目标，不表示合作、认可或投稿结果保证。
Nature and other journal names describe layout and review targets and do not imply affiliation, endorsement, or guaranteed acceptance.

精选图库另含公开数据分析与软件包示例，数据来源见[逐图清单](https://github.com/Woyekun-cell/BioFigure/blob/main/docs/gallery/catalog.csv)。第三方数据和软件包保留原许可；图中结果受已提供输入与分析范围限制。历史错误及重复修订版本不纳入精选图库，本地保留原始档案。
The curated gallery also includes public-data analyses and package examples. Data origin is listed in the inventory; third-party licenses remain applicable. Historical erroneous or repeated revisions are excluded from the curated gallery; original local archives are retained.

2026-10-11 的基因组示例使用公开的作者处理结果重绘；自有适配脚本与第三方输入分别记录在各案例 `provenance.json` 中。公开绘图表是来源数据的派生材料，不因仓库的 MIT 许可证而改变原始数据的权利。Cannabis、OHCA 与 Planarian 的原始代码许可证按固定来源记录保留；DPM 仓库未提供代码许可证，因此本仓库仅链接原作者代码，不发布或重新许可其代码与原始 R 对象。第三方原图用于本地对照，未进入公开图廊。
The genomics examples refreshed on 2026-10-11 replot public author-processed results. Per-case provenance distinguishes BioFigure adapters from third-party inputs. Derived plotting tables retain the applicable source-data rights; the repository MIT license does not relicense those inputs. Original Cannabis, OHCA, and Planarian code licenses are recorded at pinned sources. The DPM repository provides no code license, so its original code and raw R objects are linked rather than distributed or relicensed. Reference figures were reviewed locally and are not part of the public gallery.

替换的旧桑基图与 OncoPrint 是 BioFigure 生成的模拟示例，保留在案例 `sources/previous-gallery.png` 和 Git 更新前快照中；当前模拟图不代表原论文或患者数据。全部历史提交与版本标签保留。
The replaced Sankey and OncoPrint images are BioFigure-generated simulated examples. Their prior bytes remain in each case's `sources/previous-gallery.png` and the pre-refresh Git snapshot. The new simulations do not represent original paper or patient data. Existing commits and version tags are preserved.


## 3.8.0 发行范围 / Distribution scope

七个 `examples/portable/` 案例，以及既有桑基图和 OncoPrint，使用一方代码与明确模拟数据，按 MIT 发布。它们不代表论文原始数据或真实生物学结果。454 条学习目录保留来源链接、方法提炼与历史边界；目录存在不表示来源图片、作者代码或数据已获再分发授权，也不表示案例可运行。

The seven `examples/portable/` cases and the existing Sankey and OncoPrint cases use first-party code and explicitly synthetic inputs under MIT. They are not original paper data or real biological results. The 454-record learning catalog retains links, distilled methods and historical boundaries; catalog presence grants no redistribution rights to referenced source material and does not certify runnability.

Cannabis 两案及 Planarian 的公开处理数据派生表保留固定来源仓库的 GPL-3.0 许可；OHCA 的固定处理对象及其派生表保留 MIT 来源与署名。BioFigure 独立适配代码、上游数据内容和外部 R 包分别标注，不用仓库 MIT 覆盖第三方权利。固定来源、修改范围与许可证副本见[逐案许可来源](licenses/third-party-provenance.json)。外部 R 包与字体不打包，继续受其各自许可约束。

Derived processed-data tables for the two Cannabis cases and Planarian retain GPL-3.0 from their pinned source repositories. The pinned OHCA processed object and its derived tables retain the upstream MIT attribution. First-party adapters, third-party data content and external R packages are identified separately; the repository MIT license does not relicense third-party rights. See [per-case provenance and license copies](licenses/third-party-provenance.json). External R packages and fonts are not bundled and retain their own licenses.

DPM 作者 GitHub 仓库没有明确代码/数据许可证。3.8.0 不再分发该两案的五个派生 CSV、两个派生 PDF 和两个图库 PNG，保留一方适配代码、来源链接与 reference-only 缺口说明。论文 CC-BY 许可不被推定覆盖独立 GitHub 输入。此前公开的 Git 历史可能仍含旧文件；本次不改写历史。本地完整研究档案未删除。[撤下清单及哈希](https://github.com/Woyekun-cell/BioFigure/blob/main/docs/gallery/rights-exclusions-3.8.0.json)记录本版排除项。

The DPM author GitHub repository provides no explicit code/data license. Version 3.8.0 no longer distributes its five derived CSVs, two derived PDFs or two gallery PNGs. First-party adapters, source links and explicit reference-only limitations remain. The article's CC-BY notice is not treated as permission for the separate GitHub inputs. Earlier public Git history may still contain those files; this release does not rewrite history or delete the complete local research archive. The [withdrawal manifest](https://github.com/Woyekun-cell/BioFigure/blob/main/docs/gallery/rights-exclusions-3.8.0.json) records excluded files and hashes.
