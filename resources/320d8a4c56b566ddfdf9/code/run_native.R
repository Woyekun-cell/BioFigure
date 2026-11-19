args<-commandArgs(TRUE);P<-normalizePath(args[1]);W<-file.path(P,'work/2026-10-26-augur-example');S<-file.path(P,'biofigure');A<-file.path(S,'benchmark/library/single-cell/augur-2021');.libPaths(c(file.path(W,'Rlib'),.libPaths()))
suppressPackageStartupMessages({library(Matrix);library(dplyr);library(purrr);library(tibble);library(magrittr);library(tidyr);library(rlang);library(tidyselect);library(rsample);library(recipes);library(yardstick);library(parsnip);library(randomForest);library(pbmcapply);library(tester);library(sparseMatrixStats);library(lmtest)})
# Reproduce the package namespace imports when sourcing the pinned functions.
extract<-magrittr::extract;extract2<-magrittr::extract2
for(f in c('select_variance.R','select_random.R','custom_vfold_cv.R','calculate_auc.R'))source(file.path(A,'sources/author-code/R',f))
e<-new.env();load(file.path(A,'data/raw/sc_sim.rda'),envir=e);x<-e$sc_sim;expr<-x@assays$RNA@data;meta<-x@meta.data
stopifnot(identical(dim(expr),c(15697L,600L)),nrow(meta)==600,all(table(meta$cell_type)==200),!anyNA(meta))
# This is the original toy object's positional pairing, exactly as in its README.
# Preserve its metadata row numbers and expression column IDs separately.
metadata<-data.frame(source_row=rownames(meta),matrix_column_id=colnames(expr),meta,check.names=FALSE);write.csv(metadata,file.path(P,'results/plot_data/augur_demo_cells_20261026.csv'),row.names=FALSE)
write.csv(data.frame(feature_id=rownames(expr),row_order=seq_len(nrow(expr))),file.path(P,'results/plot_data/augur_demo_features_20261026.csv'),row.names=FALSE)
jsonlite::write_json(list(status='INPUTS_CHECKED',genes=nrow(expr),cells=ncol(expr),groups=unclass(table(meta$cell_type,meta$label)),data_origin='Author-provided splatter simulated scRNA-seq demonstration; not an empirical cohort.',mapping='Original stored row order, not a newly verified sample-ID join; matrix column IDs and original metadata row indices retained.',condition_event='First factor level control as original yardstick default; same symmetric two-class AUC ordering',statistics='Cell-stratified predictive performance; no animal-level inference, p-values or causal claim.'),file.path(W,'input-qc.json'),pretty=TRUE,auto_unbox=TRUE)
all<-list();smoke<-identical(Sys.getenv('AUGUR_SMOKE'),'1');sizes<-if(smoke)20 else c(10,20,40)
for(size in sizes){
 t<-proc.time()[['elapsed']];ans<-calculate_auc(expr,meta=meta,n_subsamples=if(smoke)2 else 20,subsample_size=size,folds=3,n_threads=1,show_progress=FALSE,rf_params=list(trees=100,mtry=2,min_n=NULL,importance='accuracy'))
 saveRDS(ans,file.path(W,paste0('native-size',size,'.rds')));write.csv(ans$AUC,file.path(P,'results/plot_data',paste0('augur_demo_auc_size',size,'_20261026.csv')),row.names=FALSE);write.csv(ans$results,file.path(P,'results/plot_data',paste0('augur_demo_cv_size',size,'_20261026.csv')),row.names=FALSE);cat('COMPLETE SIZE',size,'seconds',proc.time()[['elapsed']]-t,'\n');flush.console();print(ans$AUC);all[[as.character(size)]]<-ans
}
capture.output(sessionInfo(),file=file.path(W,'analysis-sessionInfo.txt'))
