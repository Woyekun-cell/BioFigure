#!/usr/bin/env Rscript
# Native author SCclust1.0.8 analysis. Only old-R vector && compatibility is patched.
a<-commandArgs(TRUE);stopifnot(length(a)==2);root<-normalizePath(a[1]);out<-a[2];dir.create(out,recursive=TRUE,showWarnings=FALSE);out<-normalizePath(out)
options(error=function(){save.image(file.path(out,'error-workspace.RData'));traceback(30);quit(status=1)})
library(futile.logger);flog.threshold(DEBUG)
for(f in list.files(file.path(root,'sources/author/SCclust/R'),full.names=TRUE))source(f)
legacy<-readLines(file.path(root,'sources/author/SCclust/R/find_clones.R'));patched<-gsub('!is.na(new_node_compliant) && !is.na(node_compliant)','(!is.na(new_node_compliant))[1L] && (!is.na(node_compliant))[1L]',legacy,fixed=TRUE);stopifnot(sum(legacy!=patched)==1);writeLines(patched,file.path(out,'find_clones.R4-compat.R'));eval(parse(text=patched))
# Instrumentation only: progress at each tenth iteration. Statistical code unchanged.
simtxt<-readLines(file.path(root,'sources/author/SCclust/R/simfisher.R'));simtxt<-gsub('for(i in 1:nsim){','for(i in 1:nsim){ if(i%%10==0) message("SCclust simulation ",i,"/",nsim)',simtxt,fixed=TRUE);eval(parse(text=simtxt))
gc_df<-load_table(file.path(root,'data/raw/mm9.varbin.gc.content.5k.bowtie.k50.from.uber.txt.gz'));gc_df$chrom.numeric<-chrom_numeric(gc_df$bin.chrom)
uber_seg<-load_table(file.path(root,'data/raw/KPCLOH.Tumor2.DP.SP.5k.seg.quantal.primary.txt.gz'));cells<-uber_cells(uber_seg,skip=3)$cells;pins<-calc_pinmat(gc_df,uber_seg,keepboundaries=TRUE);pinmat_df<-pins$pinmat;pins_df<-pins$pins;stopifnot(length(cells)==185,nrow(uber_seg)==5000,nrow(pinmat_df)==1105)
saveRDS(list(cells=cells,pinmat=pinmat_df,pins=pins_df),file.path(out,'pinmat.rds'))
fisherfile<-file.path(out,'fisher-nsim150-seed123.rds')
if(file.exists(fisherfile)){fisher<-readRDS(fisherfile)}else{RNGkind("L'Ecuyer-CMRG");set.seed(123);fisher<-sim_fisher_wrapper(pinmat_df,pins_df,njobs=8,nsim=150,nsweep=10,seedme=123);saveRDS(fisher,fisherfile)}
true_pv<-fisher$true;sim_pv<-fisher$sim;mfdr<-fisher_fdr(true_pv,sim_pv,cells);mdist<-fisher_dist(true_pv,cells);hc<-hclust_tree(pinmat_df,mfdr,mdist);tree_df<-tree_py(mdist,method='average');saveRDS(list(hc=hc,tree=tree_df,mfdr=mfdr,mdist=mdist),file.path(out,'tree-before-clone.rds'))
hc<-find_clones(hc,climbtoshare=3,nshare=4,fdrthres=-3,sharemin=.85)
# This panel uses the primary clone stripe only. No subclone stripe is drawn.
# construct_clonetracks with an empty subclone list preserves the exact parent clone IDs.
clonetrack<-construct_clonetracks(hc,list(),clonetype='soft');saveRDS(list(hc=hc,clonetrack=clonetrack),file.path(out,'clone-primary.rds'))
filenames<-case_filenames(out,'KPCLOH.Tumor2.DP.SP.result');save_table(filenames$cells,data.frame(cell=cells));save_table(filenames$seg,uber_seg);save_table(filenames$featuremat,pinmat_df);save_table(filenames$features,pins_df);save_table(filenames$tree,tree_df);save_table(filenames$clone,clonetrack)
writeLines(capture.output(sessionInfo()),file.path(out,'session-info.txt'));message('AUTHOR PRIMARY TREE AND CLONE COMPLETE')
