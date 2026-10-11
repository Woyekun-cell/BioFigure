# 复杂基因组图与图库修订：2026-10-11

这组 benchmark 保存数据到图型、作者处理步骤、原生函数、版式、色义与导出方法。六个作者处理数据案例与两个明确模拟示例已完成当前输入的数值核验、实际 PNG/PDF 检查和独立复跑；不授予整篇论文复现或任意新数据迁移资格。使用新的输入或环境时仍需重新检索、来源比较、prepare、CP2 与终图审阅。

| 检索 ID | 数据与图型 | 主要代码处理与包 | 版式／边界 |
|---|---|---|---|
| BENCH-genomics-cannabis-busco-chr7-2025 | 147 BUSCO×76基因组＋合酶坐标，锚定局部对照 | BUSCOplot、ggplot2；作者分组顺序、BUSCO锚定、仅缺失锚点均值补位 | 0–4.1Mb窗口、分组线与高低密度三角；原始NA保留，不把整染色体压入局部窗口 |
| BENCH-genomics-cannabis-public-chr7-2025 | 147 BUSCO×31基因组＋31 CBDAS位点，整chr7点线图 | BUSCOplot；公共样本固定末端，反向BLAST保留作者sstart语义 | 0–80Mb，交叉路径为真实坐标；正式补图编号未验证 |
| BENCH-genomics-dpm-hoxa10-bubbles-2024 | 两通路37/23基因×OE/KD，120个气泡 | ggplot2、ggforce；作者基因顺序与raw P/log2FC，仿射圆面积及可见最小直径 | 两纵向矩阵、共同色尺/尺寸图例、斜体基因与5 CGC标记；通路标签为FWER，缺原星号依据不补造 |
| BENCH-genomics-dpm-hoxa10-network-2024 | 225通路及完整GMT成员，证据半饼网络 | igraph、ggforce；明确新设OC≥0.5，2183边、25连通分量、11孤点，固定seed布局 | 节点面积按作者term_size；等分半饼只编码OE/KD存在，不表示定量贡献；原Cytoscape阈值/坐标未公开 |
| BENCH-genomics-ohca-microc-loops-2024 | 作者RDS的200个5kb分箱、19667联系记录、31个可见环 | HiCExperiment、HiContacts::plotMatrix；balanced值log10，原[-4,-1.2]squish；score≥0.4、q≤1e-6 | 方形联系矩阵、对角线、环与色尺；作者book案例，正式论文面板未定位；缺少的Scc1/边界轨道不补造 |
| BENCH-genomics-planarian-haplotype-dotplot-2026 | 作者已翻向/拼接坐标，19637比对、39274端点 | data.table、ggplot2；原lenAln>1000、percentID>0.5、mapQ=60，按单条identity着色 | 4×4坐标框与作者query1/3/2/4顺序；保留maxEnd边界，不二次翻向；180mm正方形例外有来源依据 |
| BENCH-gallery-multiomics-alluvial-2026 | 明确模拟1800匹配特征、27完整路径、9节点 | ggalluvial原生长表alluvium/stratum；逐阶段守恒，固定Low/Neutral/High顺序 | 136×115mm、节点内状态/数量、深色描边、流色持续表示DNA起点；不作因果解释 |
| BENCH-gallery-multievent-oncoprint-2026 | 明确模拟144肿瘤×12基因、424事件、56多事件单元 | ComplexHeatmap::oncoPrint；事件集合分层，行按不同肿瘤频率排序，样本/注释同键同序 | 3×48组、顶端计数/注释、右频率、独立下方图例；保留13零事件样本，分母144，不能把事件总数当肿瘤数 |

作者案例来源：[Cannabis Nature论文](https://www.nature.com/articles/s41586-025-09065-0)、[作者代码](https://github.com/ViningLab/CannabisPangenome)；[DPM论文](https://www.nature.com/articles/s41467-024-49986-4)、[作者代码](https://github.com/reimandlab/DPM_publication_code)；[OHCA论文](https://www.nature.com/articles/s41467-024-44761-x)、[作者book代码](https://github.com/js2264/OHCA)；[涡虫论文](https://www.nature.com/articles/s41467-026-74605-9)、[作者代码](https://github.com/Jeremias-Brand/SmedAsex)。具体commit、资产hash、原图定位及处理合同在对应case记录和子包；DPM仓库未声明源码许可，不将第三方源码混入BioFigure许可。

导出教训：当前macOS的Quartz会翻转某些原生栅格图层，而向量圈/轴不随之翻转。Micro-C终稿使用同一原生HiContacts几何、`rasterize=FALSE`向量PDF解决；PNG预览和实际PDF必须分别打开比较。不能用系统`capabilities(cairo)=TRUE`代替实际设备测试，也不能靠人为翻数据修饰设备错误。相同数值不保证版式或渲染正确。

彩色从首个有效渲染开始；每次修订绑定新授权与实际终尺寸检查。旧图、首版、冻结来源与Git快照保留；新稿仅取代图库展示。方法检索入口返回候选，源资产缺失或hash变化必须如实报告，不能沿用本次局部PASS。
