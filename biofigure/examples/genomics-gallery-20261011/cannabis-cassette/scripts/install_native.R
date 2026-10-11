#!/usr/bin/env Rscript
# Install acquired original native package in a new isolated task library only.
a<-commandArgs(TRUE);stopifnot(length(a)==2L)
source<-normalizePath(a[1]);lib<-normalizePath(a[2],mustWork=FALSE);dir.create(lib,recursive=TRUE,showWarnings=FALSE)
deps<-c('dplyr','ggplot2','magrittr','tidyr','tidyselect','viridisLite','cowplot','ragg','yaml','jsonlite','digest','svglite','systemfonts','magick')
missing<-deps[!vapply(deps,requireNamespace,logical(1),quietly=TRUE)]
if(length(missing))stop('Install required packages explicitly before replay: ',paste(missing,collapse=', '))
status<-system2(file.path(R.home('bin'),'R'),c('CMD','INSTALL',shQuote(paste0('--library=',lib)),shQuote(source)))
stopifnot(status==0L);.libPaths(c(lib,.libPaths()));stopifnot(is.function(BUSCOplot::gg_line_map))
cat('PINNED_NATIVE_BUSCOPLOT_INSTALLED',as.character(packageVersion('BUSCOplot')),'\n')
