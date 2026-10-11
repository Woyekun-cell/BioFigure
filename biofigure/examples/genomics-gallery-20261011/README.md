# 复杂图学习与公开重绘入口

8 个案例保留自有 R 代码、绘图表、PDF、配色/版式配置和来源记录。6 个案例使用作者处理结果，桑基图与 OncoPrint 为明确模拟数据。原作者代码和参考原图不随包发布；固定来源、许可证与适用范围见各案例 `provenance.json`。

公开入口将当前绘图表重绘为新的输出，OHCA 从固定 URL/校验值取得作者处理的 RDS 后调用原生 HiContacts。原作者完整数据处理流程、原论文整幅图高保真及新输入迁移没有由此获得 PASS。原本地源码复现与数值对照另有封存记录。

从仓库根目录运行，输出目录必须新建或为空：

```bash
python3 biofigure/examples/genomics-gallery-20261011/dpm-bubbles/scripts/reproduce.py --source-view-confirmed --output-dir work/dpm-bubbles-new
python3 biofigure/examples/genomics-gallery-20261011/dpm-network/scripts/reproduce.py --source-view-confirmed --output-dir work/dpm-network-new
python3 biofigure/examples/genomics-gallery-20261011/sankey/scripts/reproduce.py --source-view-confirmed --output-dir work/sankey-new
python3 biofigure/examples/genomics-gallery-20261011/oncoprint/scripts/reproduce.py --source-view-confirmed --output-dir work/oncoprint-new
```

Cannabis、Planarian 与 OHCA 的命令参数见对应 `scripts/reproduce.py --help` 和 `provenance.json`。重新查看当前参考图后，使用需要的 `--source-view-confirmed` 参数；它是本次源图查看声明，不是用户验收或视觉 PASS。

每次执行重新生成 preparation receipt、验证 CP2，再签发并消费一次绘图授权。新输出仍需查看实际 PNG/PDF、检查物理尺寸、字体、裁切与图例；脚本运行不会自动授予最终视觉 PASS。目录内 `design-template.yaml` 是模板，不包含可复用的旧授权。

已验证环境为 macOS、R 4.6.1、Arial；所需包列在各配置中。默认不自动安装全部 R 依赖。BUSCOplot 与 HiContacts 的获取/依赖入口保留原许可证，并支持指定任务 R library。其他系统、字体或包版本需要重新核验设备与实际输出，不能沿用此环境的结果。

本批绘图方法的定位索引见 [学习卡](../../references/genomics-source-gallery-learning-20261011.md)，公开文件绑定见 [刷新清单](../../../docs/gallery/refresh-20261011.json)。旧模拟图保存在 `sankey/sources/previous-gallery.png`、`oncoprint/sources/previous-gallery.png`，Git 更新前快照保留完整旧版本。

8 个入口均已在新目录完成一次原生 R 复跑和实际新 PNG、96/120 dpi PDF 预览核验。环境与哈希记录见 [限定范围运行记录](../../../docs/gallery/runtime-validation-20261011.json)；这份记录证明本次固定输入和当前自有版式的执行与审查，不代替下一次输入的准备、授权及视觉验收。
