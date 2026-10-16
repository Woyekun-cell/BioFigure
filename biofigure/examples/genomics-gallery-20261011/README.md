# 复杂图学习与公开重绘入口

本版保留 6 个公开执行入口：Cannabis 两案、Planarian、OHCA，以及明确模拟数据的桑基图和 OncoPrint。DPM 气泡图与网络两案转为 reference-only；输入许可未明确，派生 CSV/PDF/PNG 已从本版撤下，仅保留一方适配代码、来源链接及缺口说明。原作者代码和参考原图不随包发布；固定来源、许可证与适用范围见各案例 `provenance.json`。

公开入口将当前绘图表重绘为新的输出，OHCA 从固定 URL/校验值取得作者处理的 RDS 后调用原生 HiContacts。原作者完整数据处理流程、原论文整幅图高保真及新输入迁移没有由此获得 PASS。原本地源码复现与数值对照另有封存记录。

从仓库根目录运行，输出目录必须新建或为空：

```bash
python3 biofigure/examples/genomics-gallery-20261011/sankey/scripts/reproduce.py --source-view-confirmed --output-dir work/sankey-new
python3 biofigure/examples/genomics-gallery-20261011/oncoprint/scripts/reproduce.py --source-view-confirmed --output-dir work/oncoprint-new
```

Cannabis、Planarian 与 OHCA 的命令参数见对应 `scripts/reproduce.py --help` 和 `provenance.json`。重新查看当前参考图后，使用需要的 `--source-view-confirmed` 参数；它是本次源图查看声明，不是用户验收或视觉 PASS。

每次执行重新生成 preparation receipt、验证 CP2，再签发并消费一次绘图授权。新输出仍需查看实际 PNG/PDF、检查物理尺寸、字体、裁切与图例；脚本运行不会自动授予最终视觉 PASS。目录内 `design-template.yaml` 是模板，不包含可复用的旧授权。

已验证环境为 macOS、R 4.6.1、Arial；所需包列在各配置中。默认不自动安装全部 R 依赖。BUSCOplot 与 HiContacts 的获取/依赖入口保留原许可证，并支持指定任务 R library。其他系统、字体或包版本需要重新核验设备与实际输出，不能沿用此环境的结果。

本批绘图方法的定位索引见 [学习卡](../../references/genomics-source-gallery-learning-20261011.md)，公开文件绑定见 [刷新清单](../../../docs/gallery/refresh-20261011.json)。旧模拟图保存在 `sankey/sources/previous-gallery.png`、`oncoprint/sources/previous-gallery.png`，Git 更新前快照保留完整旧版本。

历史 3.7.1 的 8 个入口曾在记录环境完成原生 R 复跑和 PNG/PDF 审阅；本次发行不沿用该状态证明当前安装可执行。DPM 两案本版仅供[原论文](https://www.nature.com/articles/s41467-024-49986-4)参考。环境与哈希记录见 [限定范围运行记录](../../../docs/gallery/runtime-validation-20261011.json)；这份记录证明本次固定输入和当前自有版式的执行与审查，不代替下一次输入的准备、授权及视觉验收。

3.8.0 的可执行状态、依赖、输入许可和文件哈希以 Skill 根内 `public-cases.json` 为准；全新安装与当前渲染仍需分别核验。两 Cannabis 当前自有参考 PNG 已放在各案 `sources/own-reference.png`，无需父仓库图库。
