# 染色体与区间分布 / Chromosome and interval distribution

固定种子20260915生成10条模拟染色体、区间及效应点，使用circlize::circos.nested绘图。仅演示布局；未完成全部CP及独立迁移验收。
Fixed seed 20260915 generates ten simulated chromosomes, intervals, and signed effects. Rendered with circlize::circos.nested as a layout example; full CP and independent-transfer validation remain incomplete.

安装circlize、ragg、systemfonts和真实Arial字体，从本目录运行：
Install circlize, ragg, systemfonts, and Arial, then run from this directory:

```sh
Rscript draw.R
```

生成PNG及四份CSV至results目录。
Writes a PNG and four plotting CSV files under results.
