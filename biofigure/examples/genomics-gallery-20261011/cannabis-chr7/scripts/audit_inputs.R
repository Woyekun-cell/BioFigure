#!/usr/bin/env Rscript
# Public current-table audit and matrix reconstruction; no plotting/raw reanalysis.
load_public_inputs<-function(root){
 lock<-jsonlite::fromJSON(file.path(root,'data/metadata/source-lock.json'))
 for(i in seq_len(nrow(lock$assets))){a<-lock$assets[i,];stopifnot(digest::digest(file=file.path(root,a$path),algo='sha256')==a$sha256)}
 formal<-identical(lock$case_kind,'cannabis-cassette');path<-file.path(root,'results/plot_data')
 busco<-read.csv(file.path(path,'busco-coordinates.csv'),stringsAsFactors=FALSE,check.names=FALSE,na.strings=c('','NA'))
 samples<-read.csv(file.path(path,'sample-order.csv'),stringsAsFactors=FALSE,check.names=FALSE,na.strings=c('','NA'))
 marks<-read.csv(file.path(path,'synthase-markers.csv'),stringsAsFactors=FALSE,check.names=FALSE,na.strings=c('','NA'))
 pal<-read.csv(file.path(path,'busco-palette.csv'),stringsAsFactors=FALSE,check.names=FALSE)
 stopifnot(identical(samples$sample_index,seq_len(nrow(samples))),!anyDuplicated(samples$sample),nrow(samples)==if(formal)76L else 31L)
 ids<-unique(busco$busco_id);stopifnot(length(ids)==147L,identical(busco$busco_id,rep(ids,nrow(samples))),identical(busco$sample,rep(samples$sample,each=147L)))
 stopifnot(identical(busco$sample_index,rep(seq_len(nrow(samples)),each=147L)),all(marks$sample_index==match(marks$sample,samples$sample)))
 visible<-function(x)if(formal)is.finite(x)&x>=0&x<=4.1e6 else is.finite(x)
 stopifnot(identical(visible(busco$display_bp),busco$visible),identical(visible(marks$display_bp),marks$visible))
 busc<-matrix(busco$display_bp,nrow=147L,ncol=nrow(samples),dimnames=list(ids,samples$sample))
 finite<-sum(is.finite(busc));stopifnot(finite==if(formal)10744L else 4254L,sum(visible(busco$display_bp))==if(formal)173L else 4254L)
 if(formal){stopifnot(nrow(marks)==4414L,sum(marks$visible&marks$stringency=='low')==2600L,sum(marks$visible&marks$stringency=='high')==106L,identical(as.integer(table(factor(samples$chemotype,levels=c('I','II','III','IV')))),c(32L,16L,20L,8L)))}
 else stopifnot(nrow(marks)==31L,sum(marks$source_sstart_bp>marks$source_send_bp)==23L)
 marks$sstart<-marks$display_bp;marks$Sample<-marks$sample;marks$sseqid<-marks$sample
 list(formal=formal,busc=as.data.frame(busc,check.names=FALSE),busco=busco,sample_csv=samples,markers=marks,low=marks[marks$stringency=='low',,drop=FALSE],high=marks[marks$stringency=='high',,drop=FALSE],palette=pal,lock=lock)
}
if(sys.nframe()==0L){a<-commandArgs(TRUE);stopifnot(length(a)==2L);x<-load_public_inputs(normalizePath(a[1]));jsonlite::write_json(list(status='CURRENT_PUBLIC_TABLE_AUDIT_PASS',samples=nrow(x$sample_csv),BUSCO=147,busco_cells=nrow(x$busco),finite_cells=sum(is.finite(x$busco$display_bp)),visible_busco=sum(x$busco$visible),marker_rows=nrow(x$markers),visible_markers=sum(x$markers$visible),source_row_order_preserved=TRUE,current_table_only=TRUE,authorraw_recomputed=FALSE),a[2],auto_unbox=TRUE,pretty=TRUE)}
