#!/usr/bin/env Rscript
suppressPackageStartupMessages({library(ClusterGVis);library(ComplexHeatmap);library(circlize)})
script_path <- sub('^--file=', '', commandArgs(FALSE)[grep('^--file=', commandArgs(FALSE))][1])
root <- normalizePath(file.path(dirname(script_path), '..'), mustWork=TRUE)
dir.create(file.path(root,'results/plot_data'),recursive=TRUE,showWarnings=FALSE)
dir.create(file.path(root,'results/figures'),recursive=TRUE,showWarnings=FALSE)
set.seed(5901)
data(exps, package='ClusterGVis')
write.csv(exps,file.path(root,'data/raw/issue059_exps.csv'),row.names=TRUE)
cm <- clusterData(obj=exps, cluster.method='mfuzz', cluster.num=8)
write.csv(cm$wide.res,file.path(root,'results/plot_data/issue059_cluster_heatmap.csv'),row.names=FALSE)
mark_genes <- rownames(exps)[seq(40,nrow(exps),length.out=28)]
stage <- factor(c('Early','Early','Intermediate','Intermediate','Late','Late'),levels=c('Early','Intermediate','Late'))
phase <- factor(c('D1','D2','D3','D4','D5','D6'),levels=paste0('D',1:6))
top_anno <- HeatmapAnnotation(
  Stage=stage, Phase=phase,
  col=list(Stage=c(Early='#4E79A7',Intermediate='#59A14F',Late='#E15759'),
           Phase=setNames(c('#9EC1E6','#6FA8DC','#8FD0C7','#56B4A9','#E7B66B','#D98362'),paste0('D',1:6))),
  gp=grid::gpar(col='white'), annotation_height=grid::unit(c(2.4,2.4),'mm'))
grDevices::pdf(NULL)
ht <- visCluster(
  object=cm, plotType='both', column_names_rot=45,
  markGenes=mark_genes, markGenesSide='right',
  genesGp=c('italic',8,'#202020'),
  show_row_dend=FALSE, lineSide='left',
  clusterOrder=1:8,
  htColList=list(col_range=c(-2,0,2),col_color=c('#3B6FB6','#F7F7F5','#D95F3D')),
  heatmapAnnotation=top_anno,
  addBar=TRUE, textbarPos=c(.82,.18),
  boxCol=c('#4E79A7','#59A14F','#E15759','#B07AA1','#F28E2B','#76B7B2','#EDC948','#9C755F'))
grDevices::dev.off()
png <- file.path(root,'results/figures/issue059_cluster_heatmap.png')
ragg::agg_png(png,width=190,height=210,units='mm',res=300,background='white')
draw(ht,heatmap_legend_side='bottom',annotation_legend_side='right',padding=grid::unit(c(4,7,4,4),'mm'))
dev.off()
cat('ISSUE059_CLUSTERGVIS_REPRODUCTION_OK\n')
