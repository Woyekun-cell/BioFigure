script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value=TRUE)[1])
root <- normalizePath(file.path(dirname(script), '..'))
source(file.path(root, 'scripts/figure_style.R'))
library(ggplot2)
expect_error <- function(expr, pattern) {
  msg <- tryCatch({force(expr); ''}, error=function(e) conditionMessage(e))
  stopifnot(grepl(pattern, msg, fixed=TRUE))
}
rgba <- function(x) as.numeric(grDevices::col2rgb(x, alpha=TRUE)[4,])/255
style <- bf_mark_style('replicate-point')
stopifnot(style$fill_alpha < 1, style$edge_alpha == 1, style$shape == 21)
expect_error(bf_mark_style('unknown'), 'unknown mark role')
expect_error(bf_fill_alpha('#28527A', 1.5), 'alpha must')
expect_error(bf_fill_alpha('#28527A', NA_real_), 'alpha must')
expect_error(bf_fill_alpha('#28527A', c(.3,.4)), 'alpha must')
stopifnot(abs(rgba(bf_fill_alpha('#28527A', .7))-.7)<.004)
d <- data.frame(x=1:8, y=c(2,3,1,4,3,5,4,6), group=rep(c('A','B'),4))
p <- ggplot(d,aes(x,y)) + geom_point(
  aes(fill=stage(group,after_scale=bf_fill_alpha(fill,.7))),
  shape=21,colour='#30343B',stroke=.25,alpha=NA_real_,size=2) +
  scale_fill_manual(values=c(A='#28527A',B='#C97864'))
b <- ggplot_build(p)$data[[1]]
stopifnot(all(rgba(b$colour)==1), all(abs(rgba(b$fill)-.7)<.004))
stopifnot(bf_check_mark_layers(p,list(list(layer=1,role='replicate-point'))))
# Global alpha must not wash out the ring.
bad <- ggplot(d,aes(x,y))+geom_point(shape=21,fill='#28527A',colour='#30343B',alpha=.7,stroke=.25)
expect_error(bf_check_mark_layers(bad,list(list(layer=1,role='replicate-point'))),'edge opacity')
solid <- ggplot(d,aes(x,y))+geom_point(shape=21,fill='#28527A',colour='#30343B',alpha=1,stroke=.25)
expect_error(bf_check_mark_layers(solid,list(list(layer=1,role='replicate-point'))),'fill opacity')
stopifnot(bf_check_mark_layers(solid,list(list(layer=1,role='replicate-point',override_reason='user requests opaque sample markers'))))
dense <- ggplot(d,aes(x,y))+geom_point(shape=16,colour='#28527A',alpha=.3)
stopifnot(bf_check_mark_layers(dense,list(list(layer=1,role='dense-point'))))
expect_error(bf_check_mark_layers(dense,list(list(layer=1,role='summary-line'))),'geometry')
expect_error(bf_check_mark_layers(dense,list(list(layer=2,role='dense-point'))),'layer index')
expect_error(bf_check_mark_layers(dense,list(list(layer=1,role='dense-point'),list(layer=1,role='dense-point'))),'duplicate')
opaque_dense <- ggplot(d,aes(x,y))+geom_point(alpha=1)
expect_error(bf_check_mark_layers(opaque_dense,list(list(layer=1,role='dense-point'))),'point opacity')
hollow <- ggplot(d,aes(x,y))+geom_point(shape=21,fill=NA,colour='#30343B',stroke=.25)
stopifnot(bf_check_mark_layers(hollow,list(list(layer=1,role='hollow-point'))))
bubble <- ggplot(d,aes(x,y,fill=y,size=x))+geom_point(shape=21,colour='#30343B',stroke=.25,alpha=1)+scale_size_area()
stopifnot(bf_check_mark_layers(bubble,list(list(layer=1,role='continuous-bubble'))))
washed <- ggplot(d,aes(x,y,size=x)) + geom_point(
  aes(fill=stage(y,after_scale=bf_fill_alpha(fill,.5))),
  shape=21,colour='#30343B',stroke=.25,alpha=NA_real_) + scale_size_area()
expect_error(bf_check_mark_layers(washed,list(list(layer=1,role='continuous-bubble'))),'continuous fill')
line <- ggplot(d,aes(x,y))+geom_line(colour='#28527A',alpha=.25,linewidth=.25)+geom_line(colour='#28527A',alpha=1,linewidth=.6)
stopifnot(bf_check_mark_layers(line,list(list(layer=1,role='individual-line'),list(layer=2,role='summary-line'))))
expect_error(bf_check_mark_layers(line,list(list(layer=1,role='summary-line'),list(layer=2,role='summary-line'))),'line opacity')
expect_error(bf_check_mark_layers(line,list(list(layer=1,role='individual-line'))),'cover all')
expect_error(bf_check_mark_layers(p,list(list(layer=1,role='replicate-point',fill_alpha=.4))),'differs from contract')
expect_error(bf_check_mark_layers(washed,list(list(layer=1,role='continuous-bubble',override_reason='user prefers softer color'))),'actual colorbar')
compound <- dense + geom_smooth(method='lm',formula=y~x,se=TRUE,alpha=.9)
expect_error(bf_check_mark_layers(compound,list(list(layer=1,role='dense-point'))),'unsupported compound')
segment <- ggplot(d,aes(x,y))+geom_segment(aes(xend=x+1,yend=y+1),alpha=.25)
stopifnot(bf_check_mark_layers(segment,list(list(layer=1,role='individual-line'))))
band <- ggplot(d,aes(x,y))+geom_ribbon(aes(ymin=y-.5,ymax=y+.5),fill='#28527A',colour=NA,alpha=.18)
stopifnot(bf_check_mark_layers(band,list(list(layer=1,role='uncertainty-band'))))
defaults_before <- ggplot2::GeomPoint$default_aes
invisible_dense <- ggplot(d,aes(x,y))+geom_point(alpha=0)
expect_error(bf_check_mark_layers(invisible_dense,list(list(layer=1,role='dense-point',override_reason='looks cleaner'))),'invisible data')
expect_error(bf_check_mark_layers(p,list(list(layer=1,role='replicate-point',fill_opacity=.2))),'unknown mark field')
hidden_box <- ggplot(d,aes(group,y))+geom_boxplot(
  aes(fill=stage(group,after_scale=bf_fill_alpha(fill,.32))),colour='#30343B',alpha=NA_real_,
  box.colour='transparent',median.colour='transparent',whisker.colour='transparent')
expect_error(bf_check_mark_layers(hidden_box,list(list(layer=1,role='distribution-fill',fill_alpha=.32,edge_alpha=1))),'boxplot sub-mark')
invisible(bf_mark_style('dense-point'))
stopifnot(identical(defaults_before,ggplot2::GeomPoint$default_aes))
cat('MARK_STYLE_TESTS_OK\n')
