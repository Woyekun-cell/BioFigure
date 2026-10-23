# 64–80期方法验证图库

`generate_064_080_gallery.R`依据图型、专用包和布局关系独立编写，使用固定随机种子与模拟数据生成20张PNG及对应CSV。它不包含来源代码、来源数据或来源图片。

运行：

```bash
Rscript --vanilla biofigure/examples/reproduction-gallery/generate_064_080_gallery.R /tmp/biofigure-064-080
```

这组案例展示不同图型的信息层、字体、图例与布局，配套固定种子的模拟输入便于继续修改。脚本可生成 20 张图；分类图库选取其中结构不同的代表图。
