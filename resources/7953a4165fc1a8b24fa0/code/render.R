# Usage: Rscript render.R WORK_DIRECTORY AUTHORIZATION
# Mean +/- SD; raw independent simulated units; Tukey letters at alpha=.05.
suppressPackageStartupMessages({library(ggplot2);library(yaml)})
args <- commandArgs(TRUE);stopifnot(length(args)==2)
work <- normalizePath(args[1]);auth <- args[2]
script <- normalizePath(sub('^--file=','',grep('^--file=',commandArgs(),value=TRUE)))
root <- dirname(dirname(script));skill <- normalizePath(file.path(root,'../../../..'))
source(file.path(skill,'scripts/figure_style.R'));font <- bf_font('Arial')
spec <- file.path(root,'data/metadata/design-spec.yaml');design <- read_yaml(spec)
points_path <- file.path(root,'results/plot_data/anova_tukey_n8_points.csv')
summary_path <- file.path(root,'results/plot_data/anova_tukey_n8_summary.csv')
stats_path <- file.path(root,'results/tables/tukey.csv')
d <- read.csv(points_path);s <- read.csv(summary_path);t <- read.csv(stats_path)
groups <- c('Control','A','B','C');d$group <- factor(d$group,levels=groups);s$group <- factor(s$group,levels=groups)
stopifnot(nrow(d)==32,nrow(t)==6,all(table(d$group)==8))
for(i in seq_len(nrow(t))) {
  lhs <- s$letter[s$group==t$lhs[i]];rhs <- s$letter[s$group==t$rhs[i]]
  shared <- length(intersect(strsplit(lhs,'')[[1]],strsplit(rhs,'')[[1]]))>0
  stopifnot(shared==(t$p_adj[i]>=.05))
}
pal <- unlist(design$palette_semantics)
p <- ggplot(s,aes(group,mean,fill=group))+
  geom_col(width=.58,colour='#30343B',linewidth=.35)+
  geom_errorbar(aes(ymin=mean-SD,ymax=mean+SD),width=.20,linewidth=.35,colour='#30343B')+
  geom_point(data=d,aes(x=group,y=value),inherit.aes=FALSE,
    position=position_nudge(x=d$x_offset),shape=21,size=1.75,
    stroke=.25,fill='white',colour='#30343B')+
  geom_text(aes(y=letter_y,label=letter),family=font$family,size=7/.pt,colour='#30343B')+
  scale_fill_manual(values=pal,guide='none')+
  scale_x_discrete(labels=setNames(paste0(groups,'\n(n = 8)'),groups),expand=expansion(add=.55))+
  scale_y_continuous(limits=c(0,20),breaks=seq(0,20,5),expand=expansion(mult=c(0,.015)),minor_breaks=NULL)+
  labs(x='Group',y='Simulated value (a.u.)')+
  bf_theme(font,size=7)+theme(legend.position='none',axis.title.x=element_text(margin=margin(t=4)),
     axis.title.y=element_text(margin=margin(r=4)),axis.text.x=element_text(lineheight=1.12),
     plot.margin=margin(3,3,3,3,'mm'))
width <- design$output_size$width_mm;height <- design$output_size$height_mm
boxes <- data.frame(id=c('data','labels','legend'),x=c(15,1,15),y=c(4,4,73),w=c(72,12,72),h=c(65,65,9))
sources <- c(spec,script,file.path(skill,'scripts/figure_style.R'),points_path,summary_path,stats_path)
out <- file.path(work,'anova_tukey_n8.png')
bf_render_png(p,out,font,design$text_contract$allowed_text,width,height,width,sources,boxes,
    authorization=auth,skill_root=skill,publication_size_class='single-column')
# Quartz embeds Arial on this macOS runtime; export the identical plot with fixed jitter.
grDevices::quartz(type='pdf',file=file.path(root,'results/figures/anova_tukey_n8.pdf'),
                  width=width/25.4,height=height/25.4,family='Arial')
print(p);invisible(dev.off())
ggsave(file.path(work,'anova_tukey_n8.svg'),p,device=svglite::svglite,width=width,height=height,units='mm',bg='white')
cat('COLORED_OUTLINED_BAR_RENDER_OK\n')
