#!/usr/bin/env Rscript
# Schema/QC only; original serialized objects are read without re-running upstream HiCool.
suppressPackageStartupMessages(library(S4Vectors)); suppressPackageStartupMessages(library(jsonlite))
args<-commandArgs(trailingOnly=TRUE); stopifnot(length(args)==1L); root<-normalizePath(args[[1]])
x<-readRDS(file.path(root,'data/raw/microC_with-loops.rds'))
regions_table<-function(gis){r<-attr(gis,'regions'); ir<-attr(r,'ranges'); data.frame(start=attr(ir,'start'),end=attr(ir,'start')+attr(ir,'width')-1L)}
gis<-attr(x,'interactions'); r<-regions_table(gis); scores<-attr(attr(x,'scores'),'listData')
loops<-attr(attr(x,'topologicalFeatures'),'listData')$loops; lr<-regions_table(loops); lm<-attr(attr(loops,'elementMetadata'),'listData')
a1<-attr(loops,'anchor1');a2<-attr(loops,'anchor2')
keep<-lm$score>=0.4 & lm$qvalue<=1e-6
# Native plotting keeps loops only where both anchors overlap the actual interactions' region.
visible<-lr$start[a1]<=max(r$end)&lr$end[a1]>=min(r$start)&lr$start[a2]<=max(r$end)&lr$end[a2]>=min(r$start)
qc<-list(schema_version=1,purpose='Author processed-input QC only; no plotting or raw-NGS recomputation',object_class=class(x)[1],focus=attr(x,'focus'),resolution_bp=attr(x,'resolution'),backing_file=attr(x,'fileName'),backing_file_exists=file.exists(attr(x,'fileName')),backing_file_required_for_loaded_plot='NOT_REQUIRED_FOR_IN_MEMORY_PLOTMATRIX; refocus/zoom would require it',bins=nrow(r),coordinate_range=c(min(r$start),max(r$end)),bin_widths=unique(r$end-r$start+1L),interactions=length(attr(gis,'anchor1')),sum_count=sum(scores$count),count_range=range(scores$count),balanced_range=range(scores$balanced),balanced_missing=sum(is.na(scores$balanced)),log10_balanced_range=range(log10(scores$balanced)),source_color_limits=c(-4,-1.2),clamped_low=sum(log10(scores$balanced)< -4),clamped_high=sum(log10(scores$balanced)> -1.2),loop_annotation_rows=length(a1),loop_filtered_rows=sum(keep),loop_filtered_visible_rows=sum(keep&visible),loop_unfiltered_visible_rows=sum(visible),loop_filter='score >= 0.4 & qvalue <= 1e-6; both anchors overlap selected matrix region',native_symmetrical_tile_rows=2L*length(attr(gis,'anchor1')),input_mutated=FALSE,scientific_unit='binned interaction counts and author loop calls within one HFFc6 processed sample; not independent biological replicates')
path<-file.path(root,'data/metadata/source-input-qc.json'); value<-toJSON(qc,auto_unbox=TRUE,pretty=TRUE,digits=NA)
if(file.exists(path)) stopifnot(identical(paste(readLines(path),collapse='\n'),value)) else writeLines(value,path)
cat(value,'\n')
