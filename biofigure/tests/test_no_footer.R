script <- sub('^--file=','',grep('^--file=',commandArgs(FALSE),value=TRUE)[1])
root <- normalizePath(file.path(dirname(script),'..'))
source(file.path(root,'scripts/figure_style.R'))
library(ggplot2)
options(warn=2)
measurement_file <- tempfile(fileext='.png')
ragg::agg_png(measurement_file,width=90,height=75,units='mm',res=150,background='white')
expect_error <- function(expr,pattern) {
  msg <- tryCatch({force(expr);''},error=function(e)conditionMessage(e))
  if(!grepl(pattern,msg,fixed=TRUE)) stop(paste('expected',pattern,'but got',msg))
}
font <- bf_font('Arial')
p <- ggplot(data.frame(x=1:3,y=2:4),aes(x,y))+geom_point()+
  scale_x_continuous(breaks=1:3)+scale_y_continuous(breaks=2:4)+
  labs(x='Dose',y='Response')+bf_theme(font)
labels <- c('Dose','Response','1','2','3','4')
notes <- c('n = 8 fish per group; infection day 12',
           'FDR <= 0.05; VIP >= 1; FC >= 1.2 or <= 1/1.2')
for(s in notes) {
  expect_error(bf_assert_scientific_text(s),'footer')
  q <- p+annotation_custom(grid::textGrob(s,gp=grid::gpar(fontfamily='Arial')))
  expect_error(bf_prepare(q,font,c(labels,s)),'footer')
}
# Even a compact otherwise legitimate label cannot be a canvas caption.
expect_error(bf_prepare(p+labs(caption='n = 8'),font,c(labels,'n = 8'),allow_headings=TRUE),'caption/footer')
expect_error(bf_prepare(p+labs(title='Liver',caption='n = 8'),font,c(labels,'Liver','n = 8'),allow_headings=TRUE),'caption/footer')
if(requireNamespace('patchwork',quietly=TRUE)) {
  pw <- patchwork::wrap_plots(p,p)+patchwork::plot_annotation(caption='n = 8')
  expect_error(bf_prepare(pw,font,c(labels,'n = 8'),allow_headings=TRUE),'caption/footer')
  expect_error(bf_prepare(patchwork::wrap_plots(p,p),font,labels),'patchwork')
  expect_error(bf_assert_scientific_grob_text(patchwork::patchworkGrob(pw)),'caption/footer')
}
g <- ggplotGrob(p+labs(caption='n = 8'))
expect_error(bf_assert_scientific_grob_text(g),'caption/footer')
manual <- grid::gTree(name='footer',children=grid::gList(grid::textGrob('n = 8')))
expect_error(bf_assert_scientific_grob_text(manual),'caption/footer')
tampered <- bf_prepare(p,font,labels)
tampered$grob <- manual
expect_error(bf_export_png(tampered,tempfile(fileext='.png'),90,75),'caption/footer')
stopifnot(bf_assert_scientific_text(c('n = 8','P = 0.01','-log10(FDR)','Up','Down','Other')))
invisible(bf_prepare(p+annotate('text',x=2,y=3,label='n = 8',family='Arial'),font,c(labels,'n = 8')))
grDevices::dev.off()
unlink(measurement_file)
cat('NO_FOOTER_TESTS_OK\n')
