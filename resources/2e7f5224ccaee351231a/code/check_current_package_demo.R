library(jsonlite)
library(hdf5r)
case_root <- normalizePath(commandArgs(trailingOnly=TRUE)[1])

library(hdf5r)
m <- case_root;f<-H5File$new(file.path(m,'data/raw/package-example/inst/extdata/MEFISTO_model.hdf5'),'r')
groups <- as.character(f[['groups/groups']]$read())
Kgs <- f[['training_stats/Kg']]$read();scales<-f[['training_stats/scales']]$read()
rows<-list();stats<-list()
for(g in groups){
 mn<-f[[paste0('Z_predictions/',g,'/mean')]]$read();vr<-f[[paste0('Z_predictions/',g,'/variance')]]$read();tm<-as.vector(f[['Z_predictions/new_values']]$read())
 # hdf5r exposes dimensions as 3 factors x 50 predictions for this source.
 if(ncol(mn)==length(tm)){mn<-t(mn);vr<-t(vr)}
 stopifnot(nrow(mn)==length(tm),all(is.finite(mn)),all(is.finite(vr)),all(vr>=0))
 for(k in seq_len(ncol(mn)))rows[[length(rows)+1]]<-data.frame(group=g,factor=paste0('Factor',k),time=tm,mean=mn[,k],variance=vr[,k],lower=mn[,k]-1.96*sqrt(vr[,k]),upper=mn[,k]+1.96*sqrt(vr[,k]))
 stats[[g]]<-list(shape=dim(mn),min_variance=min(vr),max_variance=max(vr))
}
# hdf5r order: groups x groups x factors.
stopifnot(dim(Kgs)[1]==length(groups),dim(Kgs)[2]==length(groups))
ker <- lapply(seq_len(dim(Kgs)[3]),function(k){x<-Kgs[,,k];stopifnot(max(abs(x-t(x)))<1e-8,all(abs(x)<=1+1e-8));list(factor=k,max_asymmetry=max(abs(x-t(x))),min_eigenvalue=min(eigen(x,symmetric=TRUE)$values),diag=diag(x))})
stopifnot(all(scales>=0 & scales<=1))
dir.create(file.path(m,'results/plot_data'),recursive=TRUE,showWarnings=FALSE)
write.csv(do.call(rbind,rows),file.path(m,'results/plot_data/current_package_demo_interpolation.csv'),row.names=FALSE)
write_json(list(status='CHECKED_NONRENDER_CURRENT_PACKAGE_EXAMPLE_ONLY',groups=groups,factors=dim(Kgs)[3],prediction_stats=stats,group_kernels=ker,smoothness=scales,interval_formula='mean +/- 1.96 sqrt(variance), matching paper-analysis Rmd 412-415',original_Fig2_evodevo_model='NOT_ACQUIRED_NOT_VERIFIED',model_fit_run=FALSE),file.path(m,'data/metadata/nonrender-checks.json'),pretty=TRUE,auto_unbox=TRUE)
f$close_all()
