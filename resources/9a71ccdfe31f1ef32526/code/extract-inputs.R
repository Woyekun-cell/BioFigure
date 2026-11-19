#!/usr/bin/env Rscript
# Preserve the publisher's four processed sheets. No inference or reordering.
a<-commandArgs(TRUE);stopifnot(length(a)==1);root<-normalizePath(a[1]);p<-file.path(root,'sources/MOESM13.xlsx');out<-file.path(root,'results/plot_data/fig2abcd');dir.create(out,recursive=TRUE,showWarnings=FALSE)
for(s in readxl::excel_sheets(p)){d<-as.data.frame(readxl::read_excel(p,s));write.csv(d,file.path(out,paste0(s,'.csv')),row.names=FALSE)}
