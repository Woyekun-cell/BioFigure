#!/usr/bin/env Rscript
# Public CSV replay QC. Author TSV/raw NGS is not an input to this entry.
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==1L)
root<-normalizePath(args[[1]]);options(warn=2)
config<-jsonlite::read_json(file.path(root,'data/metadata/execution-config.json'),simplifyVector=FALSE)
bind<-function(p)list(path=normalizePath(p),sha256=digest::digest(file=p,algo='sha256'))
for(asset in config$plot_data){p<-file.path(root,asset$path);stopifnot(digest::digest(file=p,algo='sha256')==asset$sha256)}
prefix<-'planarian_haplotype_recolored';paths<-file.path(root,'results/plot_data',paste0(prefix,'_',c('alignments','endpoints','boundaries'),'.csv'))
d<-data.table::fread(paths[1],data.table=FALSE);e<-data.table::fread(paths[2],data.table=FALSE);b<-data.table::fread(paths[3],data.table=FALSE)
stopifnot(nrow(d)==19637L,nrow(e)==39274L,nrow(b)==8L,!anyDuplicated(d$source_row),all(d$lenAln>1000),all(d$mapQ==60),all(d$percentID>.5),all(d$percentID<=1))
stopifnot(max(abs(d$percentID-d$numResidueMatches/d$lenAln))<1e-12)
expected<-rbind(data.frame(source_row=d$source_row,endpoint='start',refID=d$refID,queryID=d$queryID,x_bp=d$refStart2,y_bp=d$queryStart2,percentID=d$percentID),
 data.frame(source_row=d$source_row,endpoint='end',refID=d$refID,queryID=d$queryID,x_bp=d$refEnd2,y_bp=d$queryEnd2,percentID=d$percentID))
stopifnot(identical(e,expected),identical(b$chromosome,c('Chr1_h1','Chr2_h1','Chr3_h1','Chr4_h1','Chr1_h2','Chr3_h2','Chr2_h2','Chr4_h2')),
 all(b$boundary_bp==c(327420891,599719742,718812687,764943622,218353489,440331194,708248419,754928366)))
dir.create(file.path(root,'results/tables'),recursive=TRUE,showWarnings=FALSE)
jsonlite::write_json(list(status='PASS',scope='Public sealed plot CSV replay only; author full TSV filtering and formal paper panel not rerun or certified',
 alignments=nrow(d),endpoints=nrow(e),boundaries=nrow(b),plot_data=lapply(paths,bind),endpoint_table_reconstructed_from_alignment_table=TRUE,
 coordinate_reorientation=FALSE,downsampling=FALSE,raw_analysis_rerun=FALSE,field_definitions=list(
 boundary_bp='Archived full-input source maxEnd coordinate; retained from the sealed public CSV, not recalculated from selected alignments',
 offset_bp='Metadata unused by renderer: reference additive offset; query observed saved-coordinate minimum, not additive offset'),
 statistics='Descriptive alignment records; no inferential test or replicate reconstruction'),file.path(root,'results/tables/input-QC.json'),pretty=TRUE,auto_unbox=TRUE)
pkgs<-c('ggplot2','data.table','grid','ragg','systemfonts','yaml','jsonlite','digest','svglite')
jsonlite::write_json(list(R=R.version.string,platform=R.version$platform,packages=lapply(pkgs,function(p)list(package=p,version=as.character(packageVersion(p)))),
 seed=NULL,session=capture.output(sessionInfo())),file.path(root,'data/metadata/environment.json'),pretty=TRUE,auto_unbox=TRUE)
cat('PUBLIC_CSV_QC_PASS:19637alignments39274endpoints\n')
