#!/usr/bin/env Rscript
# R-native port of original SCGV model/view coordinates; frozen author SCclust tree.
a<-commandArgs(TRUE);stopifnot(length(a)==4);root<-normalizePath(a[1]);out<-a[2];dir.create(out,recursive=TRUE,showWarnings=FALSE);out<-normalizePath(out);specpath<-normalizePath(a[3]);auth<-normalizePath(a[4]);skill<-normalizePath(Sys.getenv('BIOFIGURE_SKILL_ROOT'));source(file.path(skill,'scripts/figure_style.R'))
suppressPackageStartupMessages({library(ggplot2);library(grid);library(jsonlite)})
spec<-yaml::read_yaml(specpath);font<-bf_font('Arial');W<-180;H<-135;D<-file.path(root,'results/plot_data/fig3a-t2');cn<-read.csv(file.path(D,'rounded-cn.csv'),check.names=FALSE);ord<-read.csv(file.path(D,'cell-order.csv'),check.names=FALSE);tr<-read.csv(file.path(D,'tree-segments.csv'));ch<-read.csv(file.path(D,'chromosome-bins.csv'));cols<-jsonlite::fromJSON(file.path(D,'source-colors.json'));stopifnot(nrow(cn)==5000,ncol(cn)==187,nrow(ord)==185,identical(colnames(cn)[-(1:2)],ord$cell_id),nrow(tr)==184*3)
mat<-as.matrix(cn[,-(1:2)]);stopifnot(all(is.finite(mat)),all(mat==round(mat)));z<-data.frame(x=rep(seq_len(185)-.5,each=5000),y=rep(seq_len(5000)-.5,times=185),fill=cols$cn_colors[pmin(4,pmax(0,as.vector(mat)))+1])
# Exact185-cell columns and source5000-bin positions. No per-cell outlines.
ytree<-function(v)-200-v/max(c(tr$y,tr$yend))*1600
tr$yp<-ytree(tr$y);tr$yep<-ytree(tr$yend);cl<-data.frame(x=ord$cell_x,y=-110,fill=ord$clone_color);lc<-c(SP='#E69F00',DP='#2171B5',Unknown='#8A8F98');ln<-data.frame(x=ord$cell_x,y=5120,fill=unname(lc[ord$lineage]));stopifnot(sum(ord$lineage=='Unknown')==2,sum(ord$lineage=='SP')==129,sum(ord$lineage=='DP')==54)
# Merge only adjacent same-color annotation cells into exact interval runs, avoiding PDF hairline seams.
stripruns<-function(x,ymin,ymax){rr<-rle(x);ends<-cumsum(rr$lengths);data.frame(xmin=c(0,head(ends,-1)),xmax=ends,ymin=ymin,ymax=ymax,fill=rr$values)}
cl<-stripruns(ord$clone_color,-167.5,-52.5);ln<-stripruns(unname(lc[ord$lineage]),5065,5175)
# Source-native tree path coordinates retain all184 internal-node links.
p<-ggplot()+geom_raster(data=z,aes(x=x,y=y,fill=fill),interpolate=FALSE)+geom_segment(data=tr,aes(x=x,xend=xend,y=yp,yend=yep),linewidth=.18,color='#8FC5AE',lineend='square')+geom_rect(data=cl,aes(xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax,fill=fill),color=NA)+geom_rect(data=ln,aes(xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax,fill=fill),color=NA)+scale_fill_identity()+geom_segment(data=data.frame(y=ch$end),aes(x=0,xend=185,y=y,yend=y),linewidth=.12,color='#C2C5C9')+geom_rect(aes(xmin=0,xmax=185,ymin=0,ymax=5000),fill=NA,color='#ABB1B7',linewidth=.2)
# Border GeomRect is explicitly a layout object, handled outside the cell geometry parser.
# Use annotation_custom for vector borders to avoid misclassifying a whole-panel frame as one data cell.
p$layers<-p$layers[-6]
p<-p+annotation_custom(rectGrob(gp=gpar(fill=NA,col='#ABB1B7',lwd=.55)),xmin=0,xmax=185,ymin=0,ymax=5000)
# Reference labels are sparse chromosome IDs; all21 chromosome blocks including3Y bins remain.
show<-ch$chromosome%in%c(as.character(seq(1,19,2)),'X')
p<-p+scale_x_continuous(expand=c(0,0),breaks=NULL)+scale_y_reverse(limits=c(5360,-2000),expand=c(0,0),breaks=ch$centre[show],labels=ch$chromosome[show])+coord_cartesian(xlim=c(0,220),clip='off',expand=FALSE)+theme_void(base_family=font$family,base_size=7)+theme(axis.text.y=element_text(family=font$family,size=7,color='#252A31',margin=margin(r=2)),plot.margin=margin(5,3,2,15,'mm'),plot.background=element_rect(fill='white',color=NA))
textdf<-data.frame(x=c(92.5,-17,-17,-2,-2),y=c(-1940,2500,-1000,-110,5120),label=c('PDAC (T2)','Chromosome','Distance','Clone','Lineage'),angle=c(0,90,90,0,0),hjust=c(.5,.5,.5,1,1),size=c(8,8,8,7,7)/ggplot2::.pt)
p<-p+geom_text(data=textdf,aes(x=x,y=y,label=label,angle=angle,hjust=hjust,size=size),family=font$family,color='#252A31',vjust=.5)+scale_size_identity()
# Native SCGV distance labels ascend downward, matching DendrogramViewer.draw_ylabels.
maxh<-max(c(tr$y,tr$yend));vals<-seq(0,maxh,length.out=5);td<-data.frame(x=-2,y=ytree(maxh-vals),label=as.character(round(vals)))
p<-p+geom_text(data=td,aes(x=x,y=y,label=label),family=font$family,size=7/ggplot2::.pt,hjust=1,color='#252A31')
# Reserved outside-matrix legend; scientific symbols only.
legendfun<-function(){grobTree(textGrob('Copy number',x=0,y=1,just=c('left','top'),gp=gpar(fontfamily=font$family,fontsize=7,col='#252A31')),do.call(gList,lapply(1:5,function(i)grobTree(rectGrob(x=.07,y=1-i*.095,width=.14,height=.06,gp=gpar(fill=cols$cn_colors[i],col='#8D949C',lwd=.35)),textGrob(c('0','1','2','3','4+')[i],x=.22,y=1-i*.095,just='left',gp=gpar(fontfamily=font$family,fontsize=7))))),textGrob('Lineage',x=0,y=.39,just='left',gp=gpar(fontfamily=font$family,fontsize=7,col='#252A31')),do.call(gList,lapply(1:3,function(i)grobTree(rectGrob(x=.07,y=.39-i*.095,width=.14,height=.06,gp=gpar(fill=lc[i],col=NA)),textGrob(names(lc)[i],x=.22,y=.39-i*.095,just='left',gp=gpar(fontfamily=font$family,fontsize=7))))))}
p<-p+annotation_custom(legendfun(),xmin=191,xmax=219,ymin=1450,ymax=4000)
sources<-c(specpath,file.path(root,'scripts/render-fig3a-t2.R'),file.path(skill,'scripts/figure_style.R'),file.path(D,c('rounded-cn.csv','cell-order.csv','tree-segments.csv','chromosome-bins.csv','source-colors.json')))
boxes<-data.frame(id=c('data','labels','legend'),x=c(16,0,155),y=c(9,0,40),w=c(134,15,24),h=c(87,135,60));png<-file.path(out,'fig3a-t2.png')
bf_render_png(p,png,font=font,allowed_text=unlist(spec$text_contract$allowed_text),width_mm=W,height_mm=H,target_width_mm=W,dpi=300,min_text_pt=7,source_files=sources,boxes=boxes,authorization=auth,skill_root=skill,publication_size_class='double-column')
# Preserve discrete CN image colors during official font embedding: Flate, no JPEG/downsampling.
original_gs_run<-.bf_gs_run;.bf_gs_run<-function(command,args){if(any(args=='-sDEVICE=pdfwrite'))args<-append(args,c('-dAutoFilterColorImages=false','-dColorImageFilter=/FlateEncode','-dAutoFilterGrayImages=false','-dGrayImageFilter=/FlateEncode','-dDownsampleColorImages=false','-dDownsampleGrayImages=false'),after=which(args=='-sDEVICE=pdfwrite'));original_gs_run(command,args)}
pdf<-file.path(out,'fig3a-t2.pdf');bf_pdf_open(pdf,W,H,font);print(p);dev.off();bf_pdf_finalize(pdf,font,W,H)
receipt<-jsonlite::fromJSON(paste0(png,'.render.json'),simplifyVector=FALSE);pdffile<-file.path(out,'pdf-cells.json');
# Re-measure actual same matrix viewport on the PDF device, not only the PNG canvas.
bf_pdf_open(tempfile(fileext='.pdf'),W,H,font);prepared<-bf_prepare(p,font,unlist(spec$text_contract$allowed_text),width_mm=W,height_mm=H,dpi=300,heatmap_required=TRUE,cell_mode='dense-overview',annotation_layers=spec$heatmap_cell_contract$annotation_layers);grid.draw(prepared$grob);pc<-bf_measure_ggplot_cells(prepared$cell_plan,prepared$grob,'dense-overview',.01);dev.off();jsonlite::write_json(pc,pdffile,auto_unbox=TRUE,pretty=TRUE,digits=NA)
jsonlite::write_json(list(bins=5000,cells=185,tree_links=184,tree_segments=nrow(tr),cn_categories=cols$cn_colors,unmapped_lineage=ord$cell_id[ord$lineage=='Unknown'],native_geometry_port=TRUE,no_reclustering=TRUE,all_rows_retained=TRUE,all_cells_retained=TRUE,pdf_hybrid='matrix raster; tree/labels/clone/lineage native vectors',native_y_bins='equal-mappable bin indices; no false bp axis',annotation_rows=2),file.path(out,'render-metrics.json'),auto_unbox=TRUE,pretty=TRUE)
writeLines(capture.output(sessionInfo()),file.path(out,'session-info.txt'))
