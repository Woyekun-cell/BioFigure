#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(survival)
  library(ggsurvfit)
  library(ggplot2)
})

script_path <- sub('^--file=', '', commandArgs(FALSE)[grep('^--file=', commandArgs(FALSE))][1])
root <- normalizePath(file.path(dirname(script_path), '..'), mustWork=TRUE)
dir.create(file.path(root, 'data/raw'), recursive=TRUE, showWarnings=FALSE)
dir.create(file.path(root, 'results/plot_data'), recursive=TRUE, showWarnings=FALSE)
dir.create(file.path(root, 'results/figures'), recursive=TRUE, showWarnings=FALSE)

dat <- survival::lung[, c('inst','time','status','age','sex')]
dat <- dat[complete.cases(dat), ]
dat$subject_id <- sprintf('L%03d', seq_len(nrow(dat)))
dat$group <- factor(dat$sex, levels=c(1,2), labels=c('Placebo + CF','Serplulimab + CF'))
write.csv(dat, file.path(root, 'data/raw/issue020_lung.csv'), row.names=FALSE)
write.csv(dat[, c('subject_id','group','time','status','age')], file.path(root, 'results/plot_data/issue020_survival.csv'), row.names=FALSE)

fit <- survfit2(Surv(time / 30.4375, status == 2) ~ group, data=dat)
palette <- c('#E05133', '#4877B9')
p <- fit |>
  ggsurvfit(linewidth=0.8) +
  add_risktable(
    risktable_height=0.28,
    risktable_stats='{n.risk} ({cum.censor})',
    stats_label=list(n.risk='Number at risk', cum.censor='number censored'),
    size=3.5,
    hjust=0.5,
    theme=list(
      theme_risktable_default(axis.text.y.size=10, plot.title.size=10),
      theme(plot.title=element_text(family='Arial', face='bold'))
    )
  ) +
  add_risktable_strata_symbol(symbol='●', size=10) +
  add_censor_mark(size=2.2, shape=3) +
  add_quantile(y_value=0.5, linetype='dashed', color='#4B4B4B', linewidth=0.45) +
  labs(x='Time since randomization (months)', y='Overall survival (%)') +
  scale_x_continuous(breaks=seq(0, 32, 4), limits=c(-2.2,34.2), expand=c(0,0)) +
  scale_y_continuous(breaks=seq(0,1,.25), labels=seq(0,100,25), limits=c(0,1), expand=c(0,0)) +
  scale_color_manual(values=palette) +
  scale_fill_manual(values=palette) +
  guides(color=guide_legend(ncol=1)) +
  theme_classic(base_family='Arial', base_size=10) +
  theme(
    axis.text=element_text(color='#242424'),
    axis.title=element_text(color='#242424'),
    axis.ticks.length=unit(1.4,'mm'),
    axis.line=element_line(linewidth=.45, color='#242424'),
    legend.title=element_blank(),
    legend.text=element_text(size=9),
    legend.position=c(.17,.16),
    legend.background=element_rect(fill='white', color=NA),
    plot.margin=margin(5,8,2,6)
  )

png_path <- file.path(root, 'results/figures/issue020_survival.png')
ragg::agg_png(png_path, width=180, height=125, units='mm', res=300, background='white')
print(p)
dev.off()
cat('ISSUE020_REPRODUCTION_OK\n')
