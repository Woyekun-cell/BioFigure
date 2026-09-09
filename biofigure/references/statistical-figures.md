# 基础图也要精修

先识别实验单位与比较问题，再加载[分布契约](chart-distribution.md)、[降维契约](chart-ordination.md)、[差异契约](chart-differential.md)或[时间契约](chart-time.md)。分布、配对、时间、效应量、计数不必统一柱状图。小样本优先显示真实观测；小提琴需要足够数据支撑密度，不用平滑形状掩盖样本少。

配对线按真实ID连接；缺配对不补连。误差线明确SD/SEM/CI及算法；图上n是独立实验单位，不是技术重复数。已有P/q原样读取，不为画星号重算多组t检验。

时间序列按真实间隔摆放，分类时间另说明；不同个体横断面均值线不等于个体轨迹。对数轴、断轴或截断需明确，零值不能直接丢弃。

标签按科学重点和确定规则选取，避让且保留引导线；记录未标注数量，不为全标而缩到不可读。散点密集可用透明度/密度层；需抽样则说明范围、种子和数量。

最终检查：点和线清晰、误差端不截断、图例不遮数据、分组间距合理、共享轴可比。只保留必要轴线/刻度；不添加装饰性标题、背景块或随机图标。

依据：[小样本图形表达研究](https://journals.plos.org/plosbiology/article?id=10.1371/journal.pbio.1002128)、[Nature图形指南](https://research-figure-guide.nature.com/figures/preparing-figures-our-specifications/)。具体期刊和研究设计优先，不把一种图型规定为全部任务答案。
