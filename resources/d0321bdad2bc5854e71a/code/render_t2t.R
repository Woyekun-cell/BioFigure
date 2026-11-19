# Descriptive regeneration of T2T-Y Figure 3 signal rows from author bigWigs.
# Run after extract_t2t_tracks.py and current BioFigure render authorization.
library(ggplot2)
library(yaml)
args <- commandArgs(TRUE)
stopifnot(length(args)==2)
script <- normalizePath(sub('^--file=','',grep('^--file=',commandArgs(),value=TRUE)))
root <- dirname(dirname(script))
skill <- normalizePath(file.path(root,'../../..'))
work <- normalizePath(args[1])
source(file.path(skill,'scripts/figure_style.R'))
spec <- file.path(root,'data/metadata/t2t-design-spec.yaml')
pal <- unlist(yaml::read_yaml(spec)$project_style_contract$semantic_colors)
input <- file.path(root,'results/plot_data/t2t_y_centromere_tracks.csv')
d <- read.csv(input)
d$panel <- factor(ifelse(d$track=='ONT','ONT CpG (fraction)',ifelse(d$track=='HiFi','HiFi CpG (fraction)','CENP-A signal')),
                  levels=c('ONT CpG (fraction)','HiFi CpG (fraction)','CENP-A signal'))
stopifnot(nrow(d)==3200, all(d$value[d$track %in% c('ONT','HiFi')]<=1,na.rm=TRUE))
font <- bf_font('Arial')
m <- d[d$track %in% c('ONT','HiFi') & is.finite(d$value),]
c <- d[grepl('CENPA',d$track) & is.finite(d$value),]
c$status <- factor(ifelse(c$track=='CENPA_filtered','Filtered','Unfiltered'),levels=c('Unfiltered','Filtered'))
c <- c[order(c$status),]
bounds <- data.frame(panel=factor(levels(d$panel),levels=levels(d$panel)),x=10.4,y=c(1,1,80))
p <- ggplot() + geom_blank(data=bounds,aes(x=x,y=y)) +
 geom_rect(data=m,aes(xmin=start0/1e6,xmax=end0/1e6,ymin=0,ymax=value,fill=track),linewidth=0) +
 geom_rect(data=c,aes(xmin=start0/1e6,xmax=end0/1e6,ymin=0,ymax=value,fill=status),linewidth=0) +
 facet_grid(panel~.,scales='free_y',switch='y') +
 scale_fill_manual(values=c(ONT=pal[['ONT']],HiFi=pal[['HiFi']],Unfiltered=pal[['CENPA_unfiltered']],Filtered=pal[['CENPA_filtered']]),breaks=c('Unfiltered','Filtered'),name=NULL) +
 scale_x_continuous(limits=range(c(d$start0,d$end0))/1e6,breaks=seq(10.4,10.9,.1),labels=function(x)sprintf('%.1f',x),expand=c(0,0)) +
 scale_y_continuous(breaks=function(lim)if(max(lim)<=1.1)c(0,.5,1)else c(0,40,80),labels=function(x)vapply(x,function(z)format(z,trim=TRUE),character(1)),expand=expansion(mult=c(0,.05))) +
 labs(x='chrY position (Mb)',y=NULL) + bf_theme(font) +
 theme(legend.position='bottom',strip.placement='outside',strip.text.y.left=element_text(angle=0),
       panel.spacing.y=grid::unit(4,'mm'),legend.key.width=grid::unit(4,'mm'))
boxes <- data.frame(id=c('data','labels','legend'),x=c(38,1,38),y=c(4,4,97),w=c(139,35,139),h=c(80,80,8))
out <- file.path(work,'t2t_y_centromere_tracks.png')
sources <- c(spec,script,file.path(skill,'scripts/figure_style.R'),input)
bf_render_png(p,out,font,yaml::read_yaml(spec)$text_contract$allowed_text,183,108,183,
              sources,boxes,authorization=args[2],skill_root=skill,publication_size_class='double-column')
# Same ggplot object, exact Arial via macOS Quartz; permanent PDF, temporary SVG.
grDevices::quartz(type='pdf',file=file.path(root,'results/figures/t2t_y_centromere_tracks.pdf'),width=183/25.4,height=108/25.4,family='Arial')
print(p); invisible(dev.off())
ggsave(file.path(work,'t2t_y_centromere_tracks.svg'),p,device=svglite::svglite,width=183,height=108,units='mm',bg='white')
writeLines(capture.output(sessionInfo()),file.path(root,'data/metadata/R-session.txt'))
cat('T2T_SIGNAL_RENDER_OK\n')
