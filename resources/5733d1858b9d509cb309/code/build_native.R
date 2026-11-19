# Native author example; source data and panel geometry stay with plotgardener.
load_case <- function(P) {
 W<-file.path(P,'work/2026-10-28-batch-five/plotgardener')
 .libPaths(c(file.path(W,'Rlib'),file.path(P,'work/2026-10-11-next-complex-training/ohca/R-library'),.libPaths()))
 suppressPackageStartupMessages({library(plotgardener);library(plotgardenerData);library(TxDb.Hsapiens.UCSC.hg19.knownGene);library(org.Hs.eg.db);library(grid)})
 invisible(W)
}
make_native <- function(P) {
 W<-file.path(P,'work/2026-10-28-batch-five/plotgardener');e<-new.env(parent=globalenv())
 for(p in list.files(file.path(W,'data/raw'),pattern='rda$',full.names=TRUE))load(p,envir=e)
 e$cyto<-read.csv(file.path(W,'results/plot_data/hg19_chr21_cytobands.csv'))
 counter<-0L
 e$plotText<-function(...) {counter<<-counter+1L;x<-plotgardener::plotText(...,fontfamily='Arial');grid::grid.edit(x$name,name=paste0('source_label_',counter));invisible(x)}
 e$pal<-grDevices::colorRampPalette(c('#FAFAF6','#ADD0D2','#3E4F75'),space='Lab')
 code<-paste(readLines(file.path(W,'sources/author-homepage.R')),collapse='\n');code<-substring(code,regexpr('## Create a plotgardener page',code))
 code<-sub('pageCreate(width = 7, height = 4.25, default.units = "inches")','pageCreate(width = 183, height = 112, default.units = "mm", showGuides = FALSE)',code,fixed=TRUE)
 code<-gsub('plotIdeogram(chrom = "chr21", assembly = "hg19",','plotIdeogram(chrom = "chr21", data = cyto, assembly = "hg19",',code,fixed=TRUE)
 code<-gsub('plotHicSquare(data =','plotHicSquare(palette = pal, data =',code,fixed=TRUE)
 code<-gsub('plotHicTriangle(data =','plotHicTriangle(palette = pal, data =',code,fixed=TRUE)
 code<-gsub('digits = 0','digits = 1',code,fixed=TRUE)
 code<-gsub('fontsize = 12','fontsize = 9',code,fixed=TRUE);code<-gsub('fontsize = 6,','fontsize = 6.5,',code,fixed=TRUE)
 code<-gsub('"#253494"','"#405A7D"',code,fixed=TRUE);code<-gsub('"#37a7db"','"#62A5AA"',code,fixed=TRUE)
 eval(parse(text=code),envir=e)
 # These scientific labels make the two source cell-line panels explicit.
 e$plotText(label='GM12878',fontsize=7,x=4.25,y=.92,just=c('center','bottom'),default.units='inches')
 e$plotText(label='IMR90',fontsize=7,x=6,y=.92,just=c('center','bottom'),default.units='inches')
 g<-grid::grid.grab(warn=0,wrap=FALSE)
 normalize_text<-function(x){if(inherits(x,'text')){x$gp$fontfamily<-'Arial';if(is.null(x$gp$fontsize))x$gp$fontsize<-6.5; x$gp$fontsize<-pmax(x$gp$fontsize,6.5)};if(length(x$grobs))x$grobs<-lapply(x$grobs,normalize_text);if(length(x$children))x$children<-do.call(grid::gList,lapply(x$children,normalize_text));x}
 g<-normalize_text(g)
 list(grob=g,objects=as.list(e)[vapply(as.list(e),function(x)inherits(x,c('hicSquare','hicTriangle','genes','signal','ideogram')),logical(1))])
}
