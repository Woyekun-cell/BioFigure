args<-commandArgs(TRUE);w<-normalizePath(args[1]);library(ggplot2);library(grid)
g<-readRDS(file.path(w,'composed-vector-grob.rds'));g<-gtable::gtable_add_cols(g,unit(4,'mm'),pos=-1);saveRDS(g,file.path(w,'composed-vector-grob.rds'));p<-ggplotify::as.ggplot(g)+theme(text=element_text(family='Arial',size=7),plot.margin=margin(0,0,0,0));saveRDS(p,file.path(w,'render-object.rds'))
