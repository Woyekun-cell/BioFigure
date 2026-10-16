script <- sub('^--file=','',grep('^--file=',commandArgs(FALSE),value=TRUE)[1])
root <- normalizePath(file.path(dirname(script),'..'))
source(file.path(root,'scripts/figure_style.R'))
library(ggplot2)
options(warn=2)
expect_error <- function(expr,pattern) {
  msg <- tryCatch({force(expr);''},error=function(e)conditionMessage(e))
  if(!grepl(pattern,msg,fixed=TRUE)) stop(paste('expected',pattern,'but got',msg))
}
font <- bf_font('Arial')
d <- expand.grid(x=1:4,y=1:8)
d$value <- seq_len(nrow(d))
p <- ggplot(d,aes(x,y,fill=value))+geom_tile()+
  scale_x_continuous(breaks=1:4,expand=c(0,0))+
  scale_y_continuous(breaks=1:8,expand=c(0,0))+
  labs(x=NULL,y=NULL)+guides(fill='none')+bf_theme(font)
labels <- as.character(1:8)
# These numeric-coordinate tiles previously escaped the discrete-only check.
expect_error(bf_prepare(p,font,labels,width_mm=90,height_mm=75),'square')
expect_error(bf_prepare(p+coord_fixed(ratio=2),font,labels,width_mm=90,height_mm=75),'square')
good <- bf_prepare(p+coord_fixed(),font,labels,width_mm=90,height_mm=75)
invisible(bf_prepare(p+theme(aspect.ratio=2),font,labels,width_mm=90,height_mm=75))
invisible(bf_prepare(p+coord_fixed()+facet_wrap(~I('A')),font,c(labels,'A'),width_mm=90,height_mm=75))
stopifnot(length(good$heatmap_cells)>0)
stopifnot(all(vapply(good$heatmap_cells,function(x)abs(x$cell_width_mm/x$cell_height_mm-1)<.01,logical(1))))
expect_error(bf_prepare(p+theme(aspect.ratio=1),font,labels,width_mm=90,height_mm=75),'square')
# A changed grob layout must be remeasured on export, not trusted from prepare.
bad <- good
bad$grob$respect <- FALSE
out <- tempfile(fileext='.png')
expect_error(bf_export_png(bad,out,90,75),'square')
stopifnot(!file.exists(out))
pr <- ggplot(d,aes(factor(x),factor(y),fill=value))+geom_raster()+
  labs(x=NULL,y=NULL)+guides(fill='none')+bf_theme(font)
expect_error(bf_prepare(pr,font,labels,width_mm=90,height_mm=75),'square')
invisible(bf_prepare(pr+coord_fixed(),font,labels,width_mm=90,height_mm=75))
strip <- geom_tile(data=data.frame(x=1:4,y=9,value=4),aes(x,y),width=1,height=.15,fill='grey')
expect_error(bf_prepare(p+coord_fixed()+strip,font,labels,width_mm=90,height_mm=75),'square')
invisible(bf_prepare(p+coord_fixed()+strip,font,labels,width_mm=90,height_mm=75,
  annotation_layers=list(list(layer=2L,role='categorical-strip'))))
expect_error(bf_prepare(p+coord_fixed(),font,labels,width_mm=90,height_mm=75,
  annotation_layers=list(list(layer=1L,role='categorical-strip'))),'matrix')
# Dense permission follows the displayed matrix, never a raw-input count.
expect_error(bf_prepare(p,font,labels,cell_mode='dense-overview'),'small displayed')
dd<-expand.grid(x=1:4,y=1:500); dd$value<-seq_len(nrow(dd))
dense<-ggplot(dd,aes(x,y,fill=value))+geom_raster()+
  scale_x_continuous(breaks=NULL)+scale_y_continuous(breaks=NULL)+
  labs(x=NULL,y=NULL)+guides(fill='none')+bf_theme(font)
invisible(bf_prepare(dense,font,character(),cell_mode='dense-overview'))
expect_error(bf_prepare(dense+coord_cartesian(ylim=c(1,20)),font,character(),
  cell_mode='dense-overview'),'clipped heatmap')
# Actual native slice dimensions exclude split gaps, legends and annotations.
if(requireNamespace('ComplexHeatmap',quietly=TRUE)) {
  f <- tempfile(fileext='.png')
  ragg::agg_png(f,width=90,height=90,units='mm',res=150,background='white')
  bf_complexheatmap_font(font)
  m <- matrix(seq_len(32),8,4)
  make <- function(h) ComplexHeatmap::Heatmap(m,name='expr',
    width=grid::unit(20,'mm'),height=grid::unit(h,'mm'),
    row_split=rep(1:2,each=4),column_split=rep(1:2,each=2),
    row_gap=grid::unit(2,'mm'),column_gap=grid::unit(4,'mm'),
    cluster_rows=FALSE,cluster_columns=FALSE,show_heatmap_legend=FALSE)
  ht <- ComplexHeatmap::draw(make(40))
  expect_error(bf_complexheatmap_cell_metrics(ht,'expr'),'square')
  ht <- ComplexHeatmap::draw(make(34))
  native <- bf_complexheatmap_cell_metrics(ht,'expr')
  stopifnot(length(native)==4L)
  stopifnot(all(vapply(native,function(x)abs(x$cell_width_mm-4)<.01&&abs(x$cell_height_mm-4)<.01,logical(1))))
  grDevices::dev.off()
  unlink(f)
}
cat('SQUARE_CELL_TESTS_OK\n')
