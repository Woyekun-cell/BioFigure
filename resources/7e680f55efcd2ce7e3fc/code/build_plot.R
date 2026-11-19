# Official ggtreeExtra p5 structure with packaged tutorial annotations.
P <- normalizePath(commandArgs(TRUE)[1],mustWork=TRUE)
W <- file.path(P,'work/2026-10-26-two-complex-biofigure-benchmark/ggtree-extra-palette')
D <- file.path(P,'data/raw/ggtree_extra_p5_20261026')
.libPaths(c(file.path(P,'work/2026-10-26-two-complex-biofigure-benchmark/ggtree-extra/Rlib'),.libPaths()))
suppressPackageStartupMessages({library(ggtreeExtra);library(ggstar);library(ggplot2);library(ggtree);library(treeio);library(ggnewscale)})
source(file.path(P,'biofigure/scripts/figure_style.R'))
# Resolve named categorical colors through the current shared runtime; no HEX literals.
official_palettes <- function() {
 ids <- c(Location='biofigure-bright-8',Type='npg-inspired-10',Type2='tol-bright-7')
 files <- c(Location='tree_tippoint_bar.csv',Type='first_ring_discrete.csv',Type2='second_ring_continuous.csv')
 mappings <- lapply(names(ids),function(v) {
  tab <- read.csv(file.path(D,files[[v]]),stringsAsFactors=FALSE)
  bf_palette(ids[[v]],kind='categorical',levels=sort(unique(tab[[v]])),skill_root=file.path(P,'biofigure'))
 });names(mappings)<-names(ids)
 list(variable_palette_ids=as.list(ids),variable_colors=lapply(mappings,as.list),
  palette_library=list(path=normalizePath(file.path(P,'biofigure/palettes/palette-library.yaml')),sha256=digest::digest(file=file.path(P,'biofigure/palettes/palette-library.yaml'),algo='sha256')),
  function_source=list(path=normalizePath(file.path(P,'biofigure/scripts/figure_style.R')),sha256=digest::digest(file=file.path(P,'biofigure/scripts/figure_style.R'),algo='sha256')),
  adaptation='User-authorized built-in categorical palette adaptation of official p5; source alpha mapping unchanged.')
}
make_official_p5 <- function() {
 tree <- ape::read.tree(file.path(D,'tree.nwk'))
 dat1 <- read.csv(file.path(D,'tree_tippoint_bar.csv'),stringsAsFactors=FALSE)
 dat2 <- read.csv(file.path(D,'first_ring_discrete.csv'),stringsAsFactors=FALSE)
 dat3 <- read.csv(file.path(D,'second_ring_continuous.csv'),stringsAsFactors=FALSE)
 stopifnot(length(tree$tip.label)==230L,nrow(dat1)==230L,nrow(dat2)==1024L,nrow(dat3)==200L,
           !anyDuplicated(tree$tip.label),!anyDuplicated(dat1$ID),
           all(dat1$ID%in%tree$tip.label),all(dat2$ID%in%tree$tip.label),all(dat3$ID%in%tree$tip.label))
 maps <- official_palettes()$variable_colors
 pal <- unlist(maps$Location)
 p <- ggtree(tree,layout='fan',open.angle=10,linewidth=.3)
 p2 <- p + geom_fruit(data=dat1,geom=geom_star,
   mapping=aes(y=ID,fill=Location,size=Length,starshape=Group),position='identity',starstroke=.2) +
  scale_size_continuous(range=c(1,3),guide=guide_legend(keywidth=.5,keyheight=.5,override.aes=list(starshape=15),order=2)) +
  scale_fill_manual(values=pal,guide='none') +
  scale_starshape_manual(values=c(1,15),guide=guide_legend(keywidth=.5,keyheight=.5,order=1))
 p3 <- p2 + new_scale_fill() + geom_fruit(data=dat2,geom=geom_tile,
  mapping=aes(y=ID,x=Pos,fill=Type),offset=.08,pwidth=.25) +
  scale_fill_manual(values=unlist(maps$Type),guide=guide_legend(keywidth=.5,keyheight=.5,order=3))
 p4 <- p3 + new_scale_fill() + geom_fruit(data=dat3,geom=geom_tile,
  mapping=aes(y=ID,x=Type2,alpha=Alpha,fill=Type2),pwidth=.15) +
  scale_fill_manual(values=unlist(maps$Type2),guide=guide_legend(keywidth=.5,keyheight=.5,order=4)) +
  scale_alpha_continuous(range=c(0,.4),guide=guide_legend(keywidth=.5,keyheight=.5,order=5))
 p5 <- p4 + new_scale_fill() + geom_fruit(data=dat1,geom=geom_col,
  mapping=aes(y=ID,x=Abundance,fill=Location),pwidth=.4,
  axis.params=list(axis='x',text.angle=-45,text.size=6.5/ggplot2::.pt,hjust=0),grid.params=list(size=.15)) +
  scale_fill_manual(values=pal,guide=guide_legend(keywidth=.5,keyheight=.5,order=6)) +
  theme(text=element_text(family='Arial',size=7),legend.position='right',legend.background=element_rect(fill=NA),
    legend.title=element_text(family='Arial',size=7),legend.text=element_text(family='Arial',size=6.5),
    axis.text=element_text(family='Arial',size=6.5),axis.title=element_text(family='Arial',size=7),
    strip.text=element_text(family='Arial',size=7),legend.spacing.y=grid::unit(.02,'cm'),
    plot.background=element_rect(fill='#FFFFFF',colour=NA),panel.background=element_rect(fill='#FFFFFF',colour=NA),
    plot.margin=margin(3,3,3,3,'mm'))
 # Explicit font on the package-generated axis text layers.
 for(i in seq_along(p5$layers))if(inherits(p5$layers[[i]]$geom,c('GeomText','GeomLabel'))) {
  p5$layers[[i]]$aes_params$family <- 'Arial'
  p5$layers[[i]]$aes_params$size <- 6.5/ggplot2::.pt
 }
 p5
}
collect_grob_text <- function(g,inherited=grid::gpar()) {
 gp<-inherited;for(k in names(g$gp))gp[[k]]<-g$gp[[k]]
 out<-list(labels=character(),families=character(),sizes=numeric())
 if(inherits(g,'text')&&length(g$label))out<-list(labels=as.character(g$label),families=gp$fontfamily,sizes=gp$fontsize)
 for(child in c(g$grobs,as.list(g$children))) {
  x<-collect_grob_text(child,gp);for(k in names(out))out[[k]]<-c(out[[k]],x[[k]])
 }
 out
}
if(Sys.getenv('BF_MEASURE_ONLY')=='1') {
 p<-make_official_p5();f<-file.path(W,'measure-only.png');ragg::agg_png(f,width=183,height=170,units='mm',res=150,background='white')
 g<-ggplotGrob(p);x<-collect_grob_text(g);dev.off();unlink(f)
 jsonlite::write_json(list(text=unique(x$labels),families=unique(x$families),sizes=unique(x$sizes),coord=class(p$coordinates)),file.path(W,'draft-measurements.json'),pretty=TRUE,auto_unbox=TRUE)
 cat('MEASURE_ONLY_OK\n')
}
