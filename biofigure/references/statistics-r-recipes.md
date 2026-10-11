# 统计执行配方

将所需函数复制到当前项目并随脚本交付，不引用将来可能迁移的临时文件。函数是有限助手，方法由 [统计计划](statistics-plan-contract.md)决定；missing、重复ID和失败P阻断，不自动丢行。诊断、校正家族与实际n仍须核对。

## 两组与单因素

```r
source("scripts/statistics_helpers.R")
# 输入已核验为独立单位；差值固定为处理减对照。
z <- bf_welch_contrast(d, "response", "group", "animal_id",
                       lhs="treatment", rhs="control")
z <- bf_adjust_contrasts(z, method="none", family_id="primary_contrast")
write.csv(z, "results/tables/comparisons.csv", row.names=FALSE)
# 同一个体两条件，函数按ID对齐；不按行序配对。
p <- bf_paired_contrast(paired, "response", "condition", "animal_id",
                        lhs="post", rhs="pre")
# ≥3独立组总体均值检验；method需依据已锁计划。
w <- bf_oneway_test(d3, "response", "group", "animal_id", method="welch")
```

常规单因素可 `aov(response ~ group, data=d)`；两两Tukey用 `TukeyHSD()` 的已校正P与同时区间。对照/非参数/异方差事后比较选匹配方法，不从所有可能比较中挑显著者。

## 两因素交互与简单效应

```r
fit <- bf_two_factor_model(d, "response", c("treatment","time"), "animal_id")
interaction <- bf_two_factor_interaction(fit, c("treatment","time"))
# 下面为已计划的各时间内处理两两比较；跨时间合并为一个家族。
emm <- emmeans::emmeans(fit, ~ treatment | time)
con <- emmeans::contrast(emm, method="pairwise", adjust="none")
tab <- as.data.frame(summary(con, by=NULL, infer=c(TRUE, TRUE), adjust="none"))
names(tab)[names(tab)=="p.value"] <- "p_raw"
tab <- bf_adjust_contrasts(tab, method="holm", family_id="treatment_within_all_times")
tab$ci_scope <- "pointwise_95_percent"
```

补上实际contrast、direction、目标估计和各比较有效n，再绘图。上例CI未作同时覆盖校正。计划只与对照比较时改用适合的控制对比并明确参照水平；不要仍计算全部两两后只显示部分。

## 其他设计

单因素秩方法用 `kruskal.test()`、适用事后法；配对符号秩用 `wilcox.test(..., paired=TRUE)`，先按ID匹配并核对其目标/假设。多因素非正态不能直接用一个Kruskal–Wallis替代交互模型。

混合设计按 [重复测量规范](statistics-factorial-repeated.md)建立如 `lme4::lmer(response ~ treatment * time + (1|animal_id), data=d)` 的候选模型；先诊断收敛/奇异及相关结构，再使用适合的自由度/推断与emmeans。助手不替用户自动选随机效应、非高斯族或生存模型。三因素以上、稳健、广义、等效等由当前任务脚本独立实现并数值核验。
