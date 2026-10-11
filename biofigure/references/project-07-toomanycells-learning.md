# Project 07：TooManyCells Figure 2

来源：Schwartz 等，*Nature Methods* 2020，doi:10.1038/s41592-020-0748-5；作者仓库固定为 `da685389a46cdfab8a3eaf9f761e9a5d04ea339a`。已打开仓库内原尺寸面板并核对 README 命令与 `Options.hs` 参数。

## 可复用视觉语法

1. 径向树表达细胞 clade 父子关系；枝宽映射后代细胞数，枝色按后代标签组成加权混合。
2. 叶端用 pie ring 保留组成；图例必须在树区外并跨面板固定语义与顺序。
3. 先剪枝再注释。完整树和剪枝树用于不同信息密度；剪枝规则必须写明。
4. 模块度圆点与节点编号是互斥覆盖层，复用同一剪枝坐标，禁止叠在同一密集面板。
5. 黑色数据区可提高彩色细枝辨识度，但最终画布、外边距和图例仍保持白底。

## 本次验证

独立 R `grid` 实现生成 191 节点完整树、51 节点剪枝树和 26 个剪枝末端；输出 183×154 mm PNG/PDF/SVG及四张 plot-data CSV。原尺寸修正过一次被裁切的面板字母。scientific、visual、publication、anti-ai、reference-quality Critic 均 PASS，0 hard/major/minor。

边界：输入为固定种子模拟；原 11 器官矩阵未绑定，因此只证明结构与视觉语法，不证明原数值、原拓扑、生物学结论或像素一致。Benchmark：`toomanycells-fig2-001`；Pattern：`SC-CLADE-TREE-001`；Atlas：`ATLAS-SC-TREE-005`。
