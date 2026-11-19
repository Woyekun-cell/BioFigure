args<-commandArgs(TRUE);P<-normalizePath(args[1]);W<-file.path(P,'work/2026-10-29-omics-library-next/marker');S<-file.path(P,'biofigure');D<-file.path(P,'results/plot_data');dir.create(D,showWarnings=FALSE,recursive=TRUE)
set.seed(20261030)
types<-c('HSC','MPP','Cycling HSPC','MEP','Erythroblast','Late Erythroid','RBC','Megakaryocyte','GMP','Early Myeloid Progenitor','Late Myeloid','Neutrophil','Monocyte','Macrophages','Ba/Eo/Ma','Cycling DCs','pDC','CLP','Pre-Pro B','Pro-B','Pre-B','Mature B','Plasma Cell','CD4+ T-Cell','CD8+ T-Cell','AEC','SEC','VSMC','THY1+ MSC','Adipo-MSC','OsteoFibro-MSC','Osteo-MSC','Osteoblast','Fibro-MSC','RNAlo MSC')
lineage<-c(rep('HSPC',3),rep('Meg/E',5),rep('Myeloid',9),rep('Lymphoid',8),rep('EC',2),'M',rep('Mesenchymal',7))
palette<-c(HSPC='#8C6BB1','Meg/E'='#B96A88',Myeloid='#5088A7',Lymphoid='#41978C',EC='#D2A14F',M='#677D8D',Mesenchymal='#CB8961')
labelpalette<-c(HSPC='#70518F','Meg/E'='#94516A',Myeloid='#346B8B',Lymphoid='#26796E',EC='#8B661F',M='#485F70',Mesenchymal='#9A5F39')
meta<-data.frame(cell_type=types,lineage=lineage,column_index=1:35)
# Simulated positive per-type means. Names are source-defined structural labels, not author observations.
mat<-matrix(rgamma(350*35,shape=2,scale=.08),350,35);feature_ids<-sprintf('SIM_MARKER_%03d',1:350);selected<-rep('',350)
for(j in 1:35){ix<-((j-1)*10+1):(j*10);mat[ix,j]<-mat[ix,j]+runif(10,3,7);same<-which(lineage==lineage[j]);near<-same[abs(same-j)==1];if(length(near))mat[ix,near]<-mat[ix,near]+matrix(runif(length(ix)*length(near),.25,1),10,length(near));mat[ix,same]<-mat[ix,same]+runif(10,.1,.65)}
markers<-c('AVP','SPINK2','IL7R','GZMA','DNTT','CD79B','PAX5','MZB1','MPO','SRGN','S100A9','LYZ','CD14','C1Q','GATA1','ITGA2B','HBA1','HBA2','CXCL12','LEPR','PDGFRA','NCAM1','FLT1','EMCN','TAGLN','ACTA2')
marker_type<-c(1,2,24,25,19,22,21,23,9,13,12,13,13,14,4,8,6,7,30,29,31,32,26,27,28,28)
used<-integer();marker_rows<-integer()
for(i in seq_along(markers)){j<-marker_type[i];ix<-((j-1)*10+1):(j*10);r<-setdiff(ix,used)[1];used<-c(used,r);selected[r]<-markers[i];marker_rows<-c(marker_rows,r)}
rownames(mat)<-feature_ids;colnames(mat)<-types
zs<-t(scale(t(mat)));stopifnot(all(is.finite(zs)),max(abs(rowMeans(zs)))<1e-12,max(abs(apply(zs,1,sd)-1))<1e-12)
features<-data.frame(feature_id=feature_ids,marker_label=selected,simulated_target_cell=rep(types,each=10),lineage=rep(lineage,each=10),source_label_identity_status=ifelse(selected=='','synthetic feature ID','source marker display label; not independent gene-identity validation'))
colmat<-vapply(seq_along(types),function(j){h<-grDevices::col2rgb(palette[lineage[j]])/255;t<-seq(.78,1.12,length.out=sum(lineage==lineage[j]))[sum(lineage[seq_len(j)]==lineage[j])];grDevices::rgb(pmin(1,h*t)[1],pmin(1,h*t)[2],pmin(1,h*t)[3])},character(1));names(colmat)<-types
write.csv(data.frame(feature_id=feature_ids,mat,check.names=FALSE),file.path(D,'repro046_marker_heatmap_20261029_mean.csv'),row.names=FALSE)
write.csv(data.frame(feature_id=feature_ids,zs,check.names=FALSE),file.path(D,'repro046_marker_heatmap_20261029_zscore.csv'),row.names=FALSE)
write.csv(meta,file.path(D,'repro046_marker_heatmap_20261029_columns.csv'),row.names=FALSE)
write.csv(features,file.path(D,'repro046_marker_heatmap_20261029_features.csv'),row.names=FALSE)
origin<-'Source-guided structural study using authorized fixed-seed simulation (20261030): 350 simulated marker features by 35 source-defined cell types; no author expression values, single-cell reanalysis, cell abundance, differential-expression inference or biological conclusion reconstructed.'
q<-list(method_id='REPRO-046',stem='repro046_marker_heatmap_20261029',origin='synthetic',seed=20261030,data_origin=origin,rows=350,columns=35,selected_markers=markers,width_mm=183,height_mm=158,palette=as.list(palette),marker_label_palette=as.list(labelpalette),cell_colors=as.list(colmat),plot_data_files=paste0('repro046_marker_heatmap_20261029_',c('mean','zscore','columns','features'),'.csv'),source=list(image=file.path(S,'library/topjournal-corpus/results/figures/issue_046/image_001.png'),code=file.path(S,'library/topjournal-corpus/results/code/issue_046',paste0('block_00',1:3,'.R')),source='https://pmc.ncbi.nlm.nih.gov/articles/PMC11162340/',doi='10.1016/j.cell.2024.04.013',panel='Figure 1D marker expression heatmap; scientific heatmap region in tutorial composite',version='Cell 187 (2024) 3120-3140.e29; local tutorial REPRO-046',kind='paper',mapping_resolution='Opened composite: upper source heatmap and lower tutorial redraw both show 35 types, seven lineage blocks, cell-type strip, single-linkage left row dendrogram, right selected-marker leaders and row-scaled expression. Tutorial prose/headings excluded.'))
jsonlite::write_json(q,file.path(W,'input-qc.json'),auto_unbox=TRUE,pretty=TRUE,digits=NA)
capture.output(sessionInfo(),file=file.path(W,'prepare-sessionInfo.txt'))
