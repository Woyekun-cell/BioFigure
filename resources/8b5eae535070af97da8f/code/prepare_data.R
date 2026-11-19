P<-normalizePath(commandArgs(TRUE)[1]);W<-file.path(P,'work/2026-10-28-batch-five/sushi');.libPaths(c(file.path(W,'Rlib'),.libPaths()));library(Sushi)
files<-list.files(file.path(W,'data/raw'),pattern='rda$',full.names=TRUE);qc<-list()
for(f in files){e<-new.env();load(f,e);name<-ls(e)[1];d<-e[[name]];write.csv(d,file.path(W,'results/plot_data',paste0(name,'.csv')),row.names=FALSE);qc[[name]]<-list(rows=nrow(d),columns=names(d),missing=sum(is.na(d)),raw_sha256=digest::digest(file=f,algo='sha256'))}
# Selected records follow the unmodified native strict endpoint/anchor-midpoint filters.
env<-new.env();for(f in files)load(f,env)
sel<-list()
for(n in c('Sushi_5C.bedpe','Sushi_ChIAPET_pol2.bedpe')){d<-env[[n]];p1<-rowMeans(d[,2:3]);p2<-rowMeans(d[,5:6]);z<-d[d[,1]=='chr11'&d[,4]=='chr11'&p1>1650000&p1<2350000&p2>1650000&p2<2350000,];sel[[n]]<-z;write.csv(z,file.path(W,'results/plot_data',paste0('selected_',n,'.csv')),row.names=FALSE)}
for(n in c('Sushi_DNaseI.bedgraph','Sushi_ChIPSeq_CTCF.bedgraph','Sushi_ChIPExo_CTCF.bedgraph','Sushi_ChIPSeq_pol2.bed')){d<-env[[n]];r<-if(n=='Sushi_DNaseI.bedgraph')c(1650000,2350000)else if(n=='Sushi_ChIPSeq_pol2.bed')c(2281000,2282400)else c(1860000,1861000);z<-d[d[,1]=='chr11'&((d[,2]>r[1]&d[,2]<r[2])|(d[,3]>r[1]&d[,3]<r[2])),];z<-z[!duplicated(z),];sel[[n]]<-z;write.csv(z,file.path(W,'results/plot_data',paste0('selected_',n,'.csv')),row.names=FALSE)}
qc$selected_rows<-lapply(sel,nrow);qc$assembly<-'NCBI36/hg18, stated in pinned author R/datasetsinfo.R; no liftover';qc$missingness<-'5C name column contains4787 NA identifiers in source; all plotting coordinate,score andsample columns complete. No source value imputed.'
jsonlite::write_json(qc,file.path(W,'evidence/input-qc.json'),pretty=TRUE,auto_unbox=TRUE);capture.output(sessionInfo(),file=file.path(W,'evidence/sessionInfo.txt'))
