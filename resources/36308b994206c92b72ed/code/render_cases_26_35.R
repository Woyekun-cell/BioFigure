#!/usr/bin/env Rscript
# SciDraw source-method studies 26-35. All observations are fixed-seed simulations.
# Original R code is used only to identify packages, mappings, layers and layout.
suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
  library(ggrepel)
  library(ggbeeswarm)
  library(ggnewscale)
  library(scatterpie)
  library(ggh4x)
  library(cowplot)
  library(ragg)
})
set.seed(20260920)
script_arg <- grep('^--file=', commandArgs(FALSE), value = TRUE)
root <- normalizePath(file.path(dirname(sub('^--file=', '', script_arg)), '..'))
fig_dir <- file.path(root, 'results', 'figures')
data_dir <- file.path(root, 'results', 'plot_data')
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
font <- 'Helvetica'
save_fig <- function(name, plot, width, height) {
  ggsave(file.path(fig_dir, name), plot, width = width, height = height,
         dpi = 220, device = ragg::agg_png, bg = 'white')
}
write_data <- function(name, x) write.csv(x, file.path(data_dir, name), row.names = FALSE)
theme_bf <- function() theme_classic(base_family = font, base_size = 9) +
  theme(axis.title = element_text(size = 10), axis.text = element_text(size = 8),
        legend.title = element_text(size = 9), legend.text = element_text(size = 8),
        strip.text = element_text(size = 8.5), plot.margin = margin(7, 9, 7, 7))

# 26. Faceted scatter pies. Pie fractions encode composition; radius encodes count.
set.seed(20260920+26)
species <- c('Klebsiella', 'E. coli', 'Enterobacter', 'Citrobacter', 'Other')
species_cols <- c(Klebsiella='#2CA84D', 'E. coli'='#F59B26',
                  Enterobacter='#D93684', Citrobacter='#3156B9', Other='#666666')
genes26 <- c('Gene A', 'Gene B', 'Gene C')
locations <- sprintf('Site %02d', seq_len(80))
pie <- do.call(rbind, lapply(seq_along(genes26), function(g) {
  rows <- c(11L, 5L, 3L)[g]
  index <- expand.grid(x = seq_along(locations), y = seq_len(rows))
  location_weight <- ifelse(index$x < 21, .13,
                            ifelse(index$x < 37, .055,
                                   ifelse(index$x < 51, .13, .27)))
  row_weight <- c(.29,.30,.25,.24,.13,.08,.065,.055,.05,.045,.04)
  index <- index[index$x <= 69 &
                   runif(nrow(index)) <
                   location_weight*row_weight[index$y]*4*c(1.15,1,.85)[g], ]
  if (!nrow(index)) stop('empty pie facet')
  fractions <- t(replicate(nrow(index), {
    dominant <- sample(1:5, 1, prob=c(.31,.24,.19,.16,.10))
    minority <- sample(5:18, 1)
    parts <- as.vector(rmultinom(1, minority, rep(1,5)))
    parts[dominant] <- parts[dominant] + 100 - minority
    parts
  }))
  colnames(fractions) <- species
  data.frame(gene = genes26[g], x = index$x, y = index$y,
             value_1 = sample(c(.55,.8,1.1,1.5,2.1,2.7),nrow(index),TRUE,
                             prob=c(.26,.25,.20,.12,.10,.07)), fractions / 100,
             check.names = FALSE)
}))
pie$r <- pie$value_1/5
stopifnot(isTRUE(all.equal(pie$r,pie$value_1/5)),length(unique(pie$gene))==3)
pie$gene <- factor(pie$gene, levels = genes26)
p26 <- ggplot() +
  scatterpie::geom_scatterpie(data = pie, aes(x=x,y=y,r=r),
                             cols = species, alpha = 0.88,
                             colour = '#454545', linewidth = 0.13) +
  scatterpie::geom_scatterpie_legend(r=pie$r,x=76,y=2,n=4) +
  facet_grid(gene ~ ., scales='free_y', space='free_y', switch='y') +
  scale_fill_manual(values = species_cols, name = 'Taxon') +
  scale_x_continuous(breaks=seq_along(locations),labels=locations,
                     expand=expansion(add=.6)) +
  scale_y_continuous(breaks=seq_len(11),expand=expansion(add=.6)) +
  labs(x=NULL,y=NULL) +
  theme_bw(base_family=font,base_size=9) +
  theme(panel.grid.major=element_line(colour='#E5E5E5',linewidth=.22),
        panel.grid.minor=element_blank(),panel.border=element_rect(linewidth=.35),
        strip.background=element_rect(fill='white'),
        strip.text.y.left=element_text(angle=90,size=8),
        axis.text.x=element_text(angle=90,hjust=1,vjust=.5,size=7),
        axis.text.y=element_text(size=7),legend.position='right',
        legend.text=element_text(size=8),legend.title=element_text(size=9),
        plot.margin=margin(7,8,20,7))
save_fig('26_faceted_scatterpie.png', p26, 16, 6.1)
write_data('26_faceted_scatterpie.csv', pie)

# 27. Twelve parameter-condition units, each density over paired posterior estimates.
set.seed(20260920+27)
params <- c('Parameter A','Parameter B','Parameter C')
conditions <- c('Baseline','Environment size','Memory demands','Interaction')
cond_cols <- c(Baseline='#BEBEBE','Environment size'='#B1D8E7',
               'Memory demands'='#BFA0CC',Interaction='#F7B78B')
sim27 <- do.call(rbind,lapply(seq_along(params),function(i)
  do.call(rbind,lapply(seq_along(conditions),function(k) {
    mu <- c(6,0,5,2, 2,0,5,2, 3,0,5,1)[(i-1)*4+k]
    s <- c(1.15,.7,.75,.65)[k]
    data.frame(parameter=params[i],condition=conditions[k],
               estimate=rnorm(50,mu,s),origin='simulation')
  }))))
post27 <- sim27[sample(seq_len(nrow(sim27)),500,replace=TRUE),]
post27$estimate <- post27$estimate+rnorm(nrow(post27),0,.18)
post27$origin <- 'posterior'
pieces <- list()
for (i in seq_along(params)) for(k in seq_along(conditions)) {
  a <- subset(post27,parameter==params[i]&condition==conditions[k])
  b <- subset(sim27,parameter==params[i]&condition==conditions[k])
  ci <- quantile(a$estimate,c(.025,.975))
  top <- ggplot(a,aes(estimate)) +
    geom_density(fill=cond_cols[k],colour='#777777',alpha=.67,linewidth=.35) +
    annotate('segment',x=ci[1],xend=ci[2],y=0,yend=0,
             colour='#D5485A',linewidth=1.2) +
    labs(title=if(i==1)conditions[k] else NULL,x=NULL,y=NULL) +
    theme_bf() + theme(axis.text=element_blank(),axis.ticks=element_blank(),
                       axis.line=element_blank(),plot.title=element_text(size=9,hjust=.5),
                       plot.margin=margin(3,3,0,3))
  bottom <- ggplot(b,aes(estimate,1)) +
    geom_boxplot(aes(group=1),width=.4,orientation='y',outlier.shape=NA,
                 colour='#D64070',fill='white',linewidth=.45) +
    ggbeeswarm::geom_quasirandom(colour='#F0689A',size=.65,
                                 orientation='y',width=.21,groupOnX=FALSE) +
    labs(x=NULL,y=NULL) + theme_bf() +
    theme(axis.text.y=element_blank(),axis.ticks.y=element_blank(),
          axis.line.y=element_blank(),plot.margin=margin(0,3,4,3))
  pieces[[length(pieces)+1L]] <- top / bottom + plot_layout(heights=c(1.15,1))
}
p27 <- patchwork::wrap_plots(pieces,ncol=4)
save_fig('27_parameter_recovery_matrix.png',p27,14.5,6.2)
write_data('27_parameter_recovery.csv',rbind(sim27,post27))

# 28. Two correlated log2FC effects with joint and single-condition classes.
set.seed(20260920+28)
n28 <- 2200L
d28 <- data.frame(id=sprintf('G%04d',seq_len(n28)),x=rnorm(n28,0,1.08))
d28$y <- pmax(-5.8,pmin(4.5,d28$x*1.15+rnorm(n28,0,1.1)))
d28$class <- with(d28,ifelse(x>0.5&y>0.5,'Up in both',
                     ifelse(x < -0.5 & y < -0.5,'Down in both',
                     ifelse((x>.5|y>.5)&x+y>0,'Up in one',
                     ifelse((x < -0.5 | y < -0.5)&x+y<0,'Down in one','Other')))))
d28$class <- factor(d28$class,levels=c('Up in both','Up in one','Down in both','Down in one','Other'))
col28 <- c('Up in both'='#CC2629','Up in one'='#F3C4C6',
           'Down in both'='#2474B3','Down in one'='#C4DDEE',Other='#FFFFFF')
lab28 <- rbind(head(d28[d28$class=='Up in both',][order(-d28$y[d28$class=='Up in both']),],7),
               head(d28[d28$class=='Down in both',][order(d28$y[d28$class=='Down in both']),],7))
lab28$id <- sprintf('G%02d',seq_len(nrow(lab28)))
p28 <- ggplot(d28,aes(x,y)) +
  geom_point(shape=21,fill='white',colour='#292929',size=1.8,stroke=.35,alpha=.82) +
  geom_point(data=subset(d28,class!='Other'),aes(fill=class),
             shape=21,colour='#292929',size=2.9,stroke=.3,alpha=.9) +
  geom_hline(yintercept=0,linewidth=.45) + geom_vline(xintercept=0,linewidth=.45) +
  geom_abline(intercept=0,slope=1,linetype='dashed',linewidth=.42) +
  ggrepel::geom_text_repel(data=lab28,aes(label=id),size=3.7,family=font,
                           fontface='italic',seed=20260920,max.overlaps=Inf,
                           box.padding=.22,point.padding=.12,show.legend=FALSE) +
  scale_fill_manual(values=col28,name=NULL) +
  coord_cartesian(xlim=c(-4.4,4.1),ylim=c(-5.8,4.5),clip='off') +
  labs(title='Comparison A versus B',
       x='log2FC: comparison A',y='log2FC: comparison B') +
  theme_bw(base_family=font,base_size=9) +
  theme(panel.grid=element_blank(),plot.title=element_text(size=17,hjust=.5),
        axis.title=element_text(size=10),axis.text=element_text(size=8),
        legend.position='right',legend.text=element_text(size=8),
        legend.key.height=unit(4,'mm'))
save_fig('28_dual_effect_scatter.png',p28,9,9)
write_data('28_dual_effect_scatter.csv',d28)

# 29. Statistical significance is an independent encoding from x/y direction.
set.seed(20260920+29)
n29 <- 850L
d29 <- data.frame(x=pmax(-5,pmin(5,rnorm(n29,0,1.8))))
d29$y <- pmax(-5,pmin(5,d29$x*.9+rnorm(n29,0,.58)))
d29$p_x <- pmin(1,exp(-abs(d29$x)*runif(n29,2.5,4)))
d29$p_y <- pmin(1,exp(-abs(d29$y)*runif(n29,2.5,4)))
d29$class <- with(d29,ifelse(p_x<.05&p_y<.05,'Both significant',
                      ifelse(p_x<.05,'Total RNA only',
                      ifelse(p_y<.05,'Polysome RNA only','Not significant'))))
cols29 <- c('Polysome RNA only'='#A742B7','Total RNA only'='#3684C9',
            'Both significant'='#8E7CC6','Not significant'='#BFC3C6')
p29 <- ggplot(d29,aes(x,y,colour=class)) +
  geom_point(size=1.5,alpha=.8) +
  geom_hline(yintercept=c(-.5,.5),linetype='dashed',linewidth=.35) +
  geom_vline(xintercept=c(-.5,.5),linetype='dashed',linewidth=.35) +
  annotate('text',x=-4.7,y=4.5,label='Discordant',hjust=0,size=3.2,family=font) +
  annotate('text',x=1.1,y=4.5,label='Concordant',hjust=0,size=3.2,family=font) +
  annotate('text',x=-4.7,y=-4.6,label='Concordant',hjust=0,size=3.2,family=font) +
  annotate('text',x=1.1,y=-4.6,label='Discordant',hjust=0,size=3.2,family=font) +
  annotate('text',x=-4.7,y=4.05,label='↓ totalRNA',hjust=0,size=2.9,
           family=font,colour='#777777') +
  annotate('text',x=-4.7,y=3.62,label='↑ polyRNA',hjust=0,size=2.9,
           family=font,colour='#222222') +
  scale_colour_manual(values=cols29,name=NULL) +
  coord_cartesian(xlim=c(-5.2,5.2),ylim=c(-5.2,5.2),clip='off') +
  labs(x=expression(log[2]*'(fold change) total RNA'),
       y=expression(log[2]*'(fold change) polysome RNA')) +
  theme_bf() + theme(legend.position='right',legend.key.height=unit(4,'mm'))
save_fig('29_significance_quadrants.png',p29,9.2,4.6)
write_data('29_significance_quadrants.csv',d29)

# 30. Two biological lineages, each with spatial and temporal contrasts.
set.seed(20260920+30)
make_beeswarm <- function(types,comparison,spread,seed) {
  set.seed(seed)
  do.call(rbind,lapply(seq_along(types),function(i) {
    n <- sample(430:680,1);mu <- sin(i*.7)*spread*.55 + cos(i*.27)*spread*.25
    data.frame(cell_type=types[i],comparison=comparison,
               effect=pmax(-spread,pmin(spread,rnorm(n,mu,spread*.18))))
  }))
}
chondro <- c('InterzoneChon','ChondroPro1','ChondroPro2','CyclingChon',
             'DLK1+Chon','PAX7+Chon','ArticularChon1','ArticularChon2',
             'FacialChon','HypertrophicChon','MandibularChon','RestingChon')
osteo <- c('LimbMes','LEPR+Mes','CranialMes','PArchMes','FacialMes',
           'SutureMes1','SutureMes2','Preosteoblast','HHIP+PreOB',
           'Osteoblast','Osteocyte','MatureOsteocyte','Mixed')
stopifnot(length(chondro)==12,length(osteo)==13)
dat30 <- rbind(make_beeswarm(c(chondro,osteo),'Anterior–posterior',5,301),
               make_beeswarm(c(chondro,osteo),'5 PCW–11 PCW',1,302),
               make_beeswarm(osteo,'Cranial: anterior–posterior',4,303),
               make_beeswarm(osteo,'Cranial: 5 PCW–11 PCW',1,304))
bee_plot <- function(x,col,labels=TRUE) {
  x$cell_type <- factor(x$cell_type,levels=rev(unique(x$cell_type)))
  direction <- switch(unique(x$comparison),
                      'Anterior–posterior'='Appendicular  ←     →  Cranium',
                      '5 PCW–11 PCW'='5 PCW  ←     →  11 PCW',
                      'Cranial: anterior–posterior'='Anterior  ←     →  Posterior',
                      'Cranial: 5 PCW–11 PCW'='5 PCW  ←     →  11 PCW')
  ggplot(x,aes(effect,cell_type)) +
    geom_vline(xintercept=0,linetype='dashed',linewidth=.38) +
    ggbeeswarm::geom_quasirandom(colour=col,alpha=.82,size=.1,
                                 orientation='y',width=.33,groupOnX=FALSE) +
    coord_cartesian(xlim=range(x$effect)*1.05) +
    labs(x='logFC',y=NULL,title=direction) +
    theme_bw(base_family=font,base_size=8) +
    theme(plot.title=element_text(size=10.5,hjust=.5),
          panel.grid=element_blank(),
          panel.border=element_rect(colour='#424242',linewidth=.45),
          axis.text.y=if(labels)element_text(size=10.5) else element_blank(),
          axis.ticks.y=element_blank(),axis.line.y=element_blank(),
          axis.text.x=element_text(size=9),axis.title.x=element_text(size=10),
          plot.margin=margin(6,5,4,5))
}
bracket_panel <- function(total, groups) {
  g <- data.frame(y0=vapply(groups,`[[`,numeric(1),'y0'),
                  y1=vapply(groups,`[[`,numeric(1),'y1'),
                  label=vapply(groups,`[[`,character(1),'label'))
  ggplot(g) +
    geom_segment(aes(x=.82,xend=.82,y=y0,yend=y1),linewidth=.42) +
    geom_segment(aes(x=.82,xend=1,y=y0,yend=y0),linewidth=.42) +
    geom_segment(aes(x=.82,xend=1,y=y1,yend=y1),linewidth=.42) +
    geom_text(aes(x=.39,y=(y0+y1)/2,label=label),angle=90,
              size=3.2,family=font) +
    coord_cartesian(xlim=c(0,1),ylim=c(.5,total+.5),clip='off') +
    theme_void(base_family=font) +
    theme(plot.margin=margin(25,0,25,0))
}
top_bracket <- bracket_panel(length(c(chondro,osteo)),list(
  list(y0=14,y1=25,label='Chondrogenic'),
  list(y0=1,y1=13,label='Osteogenic')))
bottom_bracket <- bracket_panel(length(osteo),list(
  list(y0=1,y1=13,label='Cranial osteogenic')))
p30 <- (top_bracket +
        bee_plot(subset(dat30,comparison=='Anterior–posterior'),'#DB5066') +
        bee_plot(subset(dat30,comparison=='5 PCW–11 PCW'),'#5476B2',FALSE) +
        plot_layout(widths=c(.8,4.6,4.6))) /
       (bottom_bracket +
        bee_plot(subset(dat30,comparison=='Cranial: anterior–posterior'),'#A271AF') +
        bee_plot(subset(dat30,comparison=='Cranial: 5 PCW–11 PCW'),'#5476B2',FALSE) +
        plot_layout(widths=c(.8,4.6,4.6))) +
       plot_layout(heights=c(1.65,1))
save_fig('30_faceted_cell_beeswarm.png',p30,12.5,16.37)
write_data('30_faceted_cell_beeswarm.csv',dat30)

# 31. Conventional vertical-threshold volcano with separate labelled hits.
set.seed(20260920+31)
n31 <- 460L
d31 <- data.frame(id=sprintf('G%04d',seq_len(n31)),
                  effect=c(rnorm(280,1.24,.42),rnorm(100,-1.65,.55),
                           rnorm(80,0,.43)))
d31$mlog10p <- pmax(.1,rexp(n31,.68)+
                       pmax(0,d31$effect-.65)*runif(n31,14,28)+
                       pmax(0,-d31$effect-1.1)*runif(n31,3,9))
d31$mlog10p <- pmin(70,d31$mlog10p)
selected <- order(d31$mlog10p,decreasing=TRUE)[1:6]
d31$mlog10p[selected] <- c(52,49,39,18,8,2.1)
d31$effect[selected] <- c(1.55,2.03,1.71,-1.21,-1.53,-.81)
d31$group <- ifelse(seq_len(n31)%in%selected,'Selected',
                    ifelse(abs(d31$effect)>1&d31$mlog10p>-log10(.05),
                           'Significant','Background'))
stopifnot(nrow(d31)==460L, all(c('Background','Significant','Selected') %in% d31$group))
labels31 <- d31[selected,];labels31$id <- sprintf('G%02d',seq_len(nrow(labels31)))
p31 <- ggplot(d31,aes(effect,mlog10p)) +
  geom_point(data=subset(d31,group=='Background'),shape=21,fill='#D9D9D9',
             colour='#333333',size=2.5,stroke=.4) +
  geom_point(data=subset(d31,group=='Significant'),shape=21,fill='#E4C8D8',
             colour='#333333',size=5,stroke=.5) +
  geom_point(data=subset(d31,group=='Selected'),shape=21,fill='#790984',
             colour='#222222',size=8,stroke=.5) +
  geom_vline(xintercept=c(-1,1),linetype='dashed',linewidth=.5) +
  geom_hline(yintercept=-log10(.05),linetype='dashed',linewidth=.5) +
  ggrepel::geom_label_repel(data=labels31,aes(label=id),family=font,
                            fontface='italic',size=5,fill='white',
                            label.padding=unit(.7,'mm'),label.size=.2,
                            seed=20260920,box.padding=.35,point.padding=.25,
                            max.overlaps=Inf,segment.colour='#777777',
                            xlim=c(-2.65,2.85),ylim=c(0,68)) +
  coord_cartesian(xlim=c(-3.3,3.4),ylim=c(0,71),clip='off') +
  labs(x=expression(log[2]*'(FC)'),y=expression(-log[10]*'(adjusted P)')) +
  theme_bf() + theme(axis.title=element_text(size=17),axis.text=element_text(size=13),
                     plot.margin=margin(12,15,8,8))
save_fig('31_vertical_volcano.png',p31,8.6,7.16)
write_data('31_vertical_volcano.csv',d31)

# 32. Two triangle-specific percentage scales and significance marks.
set.seed(20260920+32)
factors <- c('Cebpa','Spi1','Elk1','Trp53','Fli1','Nfyc','Klf4','Ddit3',
             'Klf1','Stat5a','Sp1','Fos','Nfkb1','Spdef','Mecom','Yy1','Cic',
             'Myb','Lyl1','Irf7','Gata1','Creb1','Myc','Gata2','Nr2c2',
             'Tcf3','Ikzf1','Tfap2a','Gfi1','Gfi1b','Runx1','Meis1',
             'Pbx1','Meis2','Tcf12','Rxrg','Zbtb7a','Nfix','Cebpe','Ctcf')
n32 <- length(factors)
d32 <- expand.grid(x=seq_len(n32),y=seq_len(n32))
d32$active <- ifelse(runif(nrow(d32))<.20,0,
                     pmin(100,rgamma(nrow(d32),1.05,29) +
                            38*(1-d32$x/n32)^3))
d32$repressed <- ifelse(runif(nrow(d32))<.24,0,
                        pmin(35,rgamma(nrow(d32),.9,15) +
                               12*(d32$x/n32)^4))
hot32 <- d32$x <= 9 & runif(nrow(d32)) < .48
d32$active[hot32] <- runif(sum(hot32),70,95)
hot_repressed32 <- d32$x >= n32-7 & runif(nrow(d32)) < .32
d32$repressed[hot_repressed32] <- runif(sum(hot_repressed32),23,34)
d32$significant <- runif(nrow(d32))<.18
d32$region <- ifelse(d32$x+d32$y<n32+1,'Active',
                     ifelse(d32$x+d32$y>n32+1,'Repressed','Diagonal'))
d32$x_label <- factor(factors[d32$x],levels=factors)
d32$y_label <- factor(factors[d32$y],levels=rev(factors))
p32 <- ggplot() +
  geom_tile(data=subset(d32,region=='Active'),
            aes(x_label,y_label,fill=active),width=1,height=1) +
  scale_fill_gradientn(colours=c('#070605','#A32008','#F44314','#FFDD42'),
                       limits=c(0,100),name='% active') +
  ggnewscale::new_scale_fill() +
  geom_tile(data=subset(d32,region=='Repressed'),
            aes(x_label,y_label,fill=repressed),width=1,height=1) +
  scale_fill_gradientn(colours=c('#080716','#21136B','#3334CD','#55D682'),
                       limits=c(0,35),name='% repressed') +
  geom_point(data=subset(d32,region!='Diagonal'&significant),
             aes(x_label,y_label),shape=16,colour='white',size=.55) +
  scale_x_discrete(position='top',expand=c(0,0)) +
  scale_y_discrete(expand=c(0,0)) +
  coord_fixed() + labs(x=NULL,y=NULL) +
  theme_bw(base_family=font,base_size=8) +
  theme(panel.grid=element_blank(),axis.ticks=element_blank(),
        axis.text.x.top=element_text(angle=90,hjust=0,vjust=.5,size=8.5),
        axis.text.y=element_text(size=8.5),
        legend.position='right',legend.title=element_text(size=10),
        legend.text=element_text(size=8.5),
        plot.margin=margin(10,12,10,10))
save_fig('32_symmetric_dual_heatmap.png',p32,12.3,10.4)
write_data('32_symmetric_dual_heatmap.csv',d32)

# 33. Paired subjects and paired tests remain aligned in each facet.
set.seed(20260920+33)
types <- c('Plasma','CD27+ effector B','CD27- effector B',
           'CD95 memory B','Core memory B','Type 2 polarized memory B')
ages <- c('Young','Older');days <- c('Day 0','Day 7')
d33 <- do.call(rbind,lapply(seq_along(types),function(t)
  do.call(rbind,lapply(ages,function(a)
    do.call(rbind,lapply(seq_len(22),function(id) {
      base <- rnorm(1,0,.75)+ifelse(a=='Older',.25,-.15)+sin(t)*.2
      data.frame(type=types[t],age=a,id=paste0(a,'-',id),
                 day=days,value=c(base+rnorm(1,0,.25),
                                  base+rnorm(1,0,.25)+c(-.25,.35,.2,.5,-.2,.3)[t]))
    }))))))
d33$group <- factor(paste(d33$day,d33$age,sep='_'),
                    levels=c('Day 0_Young','Day 7_Young',
                             'Day 0_Older','Day 7_Older'))
d33$type <- factor(d33$type,levels=types)
pvals33 <- do.call(rbind,lapply(types,function(t)do.call(rbind,lapply(ages,function(a) {
  z <- subset(d33,type==t&age==a)
  z0 <- z$value[z$day=='Day 0'];z7 <- z$value[z$day=='Day 7']
  data.frame(type=t,age=a,p=wilcox.test(z0,z7,paired=TRUE,exact=FALSE)$p.value,
             y=max(z$value)+.55,x=ifelse(a=='Young',1.5,3.5))
}))))
pvals33$type <- factor(pvals33$type,levels=types)
pvals33$label <- sprintf('p = %.2g',pvals33$p)
p33 <- ggplot(d33,aes(group,value,fill=age)) +
  geom_boxplot(outlier.shape=NA,width=.55,linewidth=.35,alpha=.86) +
  geom_line(aes(group=interaction(age,id)),linewidth=.15,
            linetype='dotted',colour='#505050',alpha=.65) +
  geom_point(size=.75,colour='#252525',position=position_jitter(width=.04,height=0)) +
  geom_segment(data=pvals33,aes(x=x-.38,xend=x+.38,y=y,yend=y),
               inherit.aes=FALSE,linewidth=.35) +
  geom_segment(data=pvals33,aes(x=x-.38,xend=x-.38,y=y-.09,yend=y),
               inherit.aes=FALSE,linewidth=.35) +
  geom_segment(data=pvals33,aes(x=x+.38,xend=x+.38,y=y-.09,yend=y),
               inherit.aes=FALSE,linewidth=.35) +
  geom_text(data=pvals33,aes(x=x,y=y+.17,label=label),inherit.aes=FALSE,
            size=2.55,family=font) +
  ggh4x::facet_wrap2(~type,nrow=1,scales='free_y') +
  scale_fill_manual(values=c(Young='#258D80',Older='#C58B2B'),name=NULL) +
  scale_x_discrete(guide=legendry::guide_axis_nested(key='_')) +
  scale_y_continuous(expand=expansion(mult=c(.05,.22))) +
  labs(x=NULL,y='Frequency (CLR)') +
  theme_classic(base_family=font,base_size=8) +
  theme(strip.background=element_rect(fill='#9A7775',colour=NA),
        strip.text=element_text(size=8,colour='white'),
        axis.text.x=element_text(angle=0,hjust=.5,size=8.5),
        axis.text.y=element_text(size=8.5),axis.title.y=element_text(size=10),
        legend.position='none',panel.spacing=unit(2,'mm'),
        plot.margin=margin(8,8,12,8))
save_fig('33_faceted_paired_boxplot.png',p33,17.5,4.48)
write_data('33_faceted_paired_boxplot.csv',d33)
write_data('33_faceted_paired_boxplot_tests.csv',pvals33)

# 34. Facet gaps encode trajectory groups; dot size and fill encode separate measures.
set.seed(20260920+34)
cell34 <- c('Activated fibroblast','Fibroblast','Cardiomyocyte','Endothelial',
            'Pericyte','Macrophage','VSMC','Lymphocyte','Endocardial',
            'Adipocyte','Neuronal','Lymphatic endothelial','Mast cell','Epicardial')
groups34 <- c('Trajectory A','Trajectory B','Trajectory C')
gene_groups34 <- list(
  c('CRISPLD2','COL4A4','FBLN5','C7','NEGR1'),
  c('PBX1','CLSTN2','RIMS1','KCNMA1','PRRX1','PRELP'),
  c('JAZF1','FAT1','ITGA10','ENPP1','FN1','CADM1','PALLD','TENM3',
    'SLC44A5','FAP','FAM155A','AEBP1','THBS4','FGF14','POSTN','COL22A1'))
genes34 <- unlist(gene_groups34)
stopifnot(length(cell34)==14L,length(genes34)==27L,
          identical(as.integer(lengths(gene_groups34)),c(5L,6L,16L)))
d34 <- expand.grid(gene=genes34,cell=cell34,stringsAsFactors=FALSE)
d34$trajectory <- groups34[rep(seq_along(gene_groups34),lengths(gene_groups34))[
  match(d34$gene,genes34)]]
d34$pct <- pmin(1,rbeta(nrow(d34),.55,8)*1.25)
d34$expr <- pmax(0,rgamma(nrow(d34),1,1.1))
featured <- d34$cell=='Activated fibroblast'
d34$pct[featured] <- runif(sum(featured),.58,.94)
d34$expr[featured] <- d34$expr[featured]+runif(sum(featured),.9,2.4)
secondary <- d34$cell=='Fibroblast'
d34$pct[secondary] <- runif(sum(secondary),.4,.76)
d34$expr[secondary] <- d34$expr[secondary]+runif(sum(secondary),.5,1.7)
hot34 <- d34$cell %in% c('Cardiomyocyte','Endocardial','Neuronal','Epicardial') &
  runif(nrow(d34))<.10
d34$pct[hot34] <- pmin(1,d34$pct[hot34]+runif(sum(hot34),.25,.65))
d34$expr[hot34] <- d34$expr[hot34]+runif(sum(hot34),.6,2)
d34$gene <- factor(d34$gene,levels=rev(genes34))
d34$cell <- factor(d34$cell,levels=cell34)
d34$trajectory <- factor(d34$trajectory,levels=groups34)
p34 <- ggplot(d34,aes(cell,gene)) +
  geom_point(aes(size=pct,fill=expr),shape=21,colour='black',stroke=.35) +
  facet_grid(trajectory~.,scales='free_y',space='free_y',switch='y') +
  scale_size_continuous(range=c(0,5),limits=c(0,1),
                        breaks=c(.2,.4,.6,.8,1),labels=c('20%','40%','60%','80%','100%'),
                        name='Pct nuclei\nexpr > 0') +
  scale_fill_distiller(palette='Greens',direction=1,name='Avg\nexpr') +
  labs(x=NULL,y=NULL) +
  theme_bw(base_family=font) +
  theme(panel.grid=element_blank(),panel.spacing.y=unit(1.6,'mm'),
        panel.border=element_rect(colour='black',linewidth=.6),
        strip.background.y=element_rect(colour='white',fill='white'),
        strip.placement='outside',strip.text.y.left=element_blank(),
        axis.ticks=element_blank(),
        axis.text.x=element_text(angle=90,hjust=1,colour='black',size=13),
        axis.text.y=element_text(colour='black',size=13,vjust=.5),
        legend.text=element_text(size=13),legend.title=element_text(size=13),
        plot.margin=margin(8,10,10,8)) +
  guides(fill=guide_colorbar(ticks=FALSE,barheight=unit(28,'mm'),
                             frame.colour='black'))
save_fig('34_bubble_heatmap_blank_rows.png',p34,8.5,11.33)
write_data('34_bubble_heatmap_blank_rows.csv',d34)

# 35. Two bile-acid blocks, shared factor columns, signed colour and stars.
set.seed(20260920+35)
acid <- c('CA','CDCA','DCA','UDCA','LCA','TCA','GCA',
          'Ala-CA','Arg-CA','Glu-CA','Glu-CDCA','Glu-DCA','Glu-UDCA',
          'His-CA','His-CDCA','His-DCA','His-UDCA',
          'Ile-CA','Ile-CDCA','Ile-DCA','Ile-UDCA',
          'Leu-CA','Leu-CDCA','Leu-DCA','Leu-UDCA',
          'Lys-CA','Lys-CDCA','Lys-DCA','Lys-UDCA',
          'Met-CDCA','Met-DCA','Met-UDCA',
          'Phe-CA','Phe-CDCA','Phe-DCA','Phe-UDCA',
          'Ser-CA','Trp-CDCA','Trp-DCA','Tyr-CA','Tyr-CDCA','Tyr-DCA')
blocks <- c(rep('Conventional',7),rep('BBAA',length(acid)-7))
enzymes <- c('FXR','VDR','CAR','PXR','AHR','PPARα','PPARδ','PPARγ')
d35 <- expand.grid(acid=acid,enzyme=enzymes,stringsAsFactors=FALSE)
d35$block <- blocks[match(d35$acid,acid)]
stopifnot(!anyNA(d35$block),length(unique(acid))==length(acid),
          nrow(d35)==42L*length(enzymes),
          identical(as.integer(table(factor(blocks,levels=c('Conventional','BBAA')))),c(7L,35L)))
d35$log10FC <- pmax(0,pmin(2,
                          rnorm(nrow(d35),.33,.10) +
                          c(.08,-.04,.03,-.02,.06,.04,0,-.02)[match(d35$enzyme,enzymes)]))
high35 <- runif(nrow(d35))<.08
low35 <- !high35 & runif(nrow(d35))<.08
d35$log10FC[high35] <- pmin(2,d35$log10FC[high35]+runif(sum(high35),.35,1.1))
d35$log10FC[low35] <- pmax(0,d35$log10FC[low35]-runif(sum(low35),.18,.42))
d35$p <- pmin(1,pmax(.0005,exp(-abs(d35$log10FC-.30)*5)*runif(nrow(d35),.01,.42)))
d35$star <- ifelse(d35$p<.008,'**',ifelse(d35$p<.05,'*',''))
d35$acid <- factor(d35$acid,levels=acid)
d35$enzyme <- factor(d35$enzyme,levels=enzymes)
d35$block <- factor(d35$block,levels=c('Conventional','BBAA'))
acid_limits35 <- c(rev(acid[8:length(acid)]),'skip',rev(acid[1:7]))
p35_core <- ggplot(d35,aes(enzyme,acid)) +
  geom_tile(aes(fill=log10FC),colour='black',linewidth=.28) +
  scale_fill_gradientn(colours=c('#6FCFCF','white','#DD6048'),
                       values=c(0,.15,1),name='Fold\nChange',
                       limits=c(0,2),breaks=c(0,1,2),
                       labels=c(expression(10^0),expression(10^1),expression(10^2))) +
  scale_y_discrete(limits=acid_limits35) +
  scale_x_discrete(expand=c(0,0)) +
  annotate('rect',xmin=.5,xmax=8.5,ymin=.5,ymax=43.5,
           fill=NA,colour='black',linewidth=.6) +
  geom_text(aes(label=star,colour=log10FC<.30),size=4,vjust=.75,
            family=font,show.legend=FALSE) +
  scale_colour_manual(values=c(`TRUE`='#145444',`FALSE`='#7C2115')) +
  labs(x=NULL,y=NULL) +
  theme_bw(base_family=font) +
  theme(panel.grid=element_blank(),panel.border=element_blank(),
        axis.text.x=element_text(angle=45,hjust=1,size=9,colour='black'),
        axis.text.y=element_text(size=9),
        axis.ticks.length=unit(1.5,'mm'),axis.ticks=element_line(linewidth=.6),
        legend.position='top',plot.margin=margin(5,5,5,0,'mm')) +
  guides(fill=guide_colorbar(position='top',direction='horizontal',
                             barwidth=unit(28,'mm'),barheight=unit(2.8,'mm'),
                             title.position='left',ticks.colour='black',
                             frame.colour='black'))
anno35 <- cowplot::ggdraw() +
  cowplot::draw_label('Conventional\nBile Acids',y=.84,angle=90,size=9,fontfamily=font) +
  cowplot::draw_label('BBAAs',y=.42,angle=90,size=9,fontfamily=font)
p35 <- cowplot::plot_grid(anno35,p35_core,ncol=2,rel_widths=c(.1,.9))
save_fig('35_faceted_significance_heatmap.png',p35,6.6,13.2)
write_data('35_faceted_significance_heatmap.csv',d35)
message('Rendered source-method studies 26-35')
