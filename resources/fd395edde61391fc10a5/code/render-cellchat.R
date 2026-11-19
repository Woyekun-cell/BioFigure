#!/usr/bin/env Rscript
options(warn=1)
# Fixed official CellChat object; no inference, NMF refit or synthetic data.
a<-commandArgs(TRUE);stopifnot(length(a)==4);root<-normalizePath(a[1]);out<-normalizePath(a[2]);sp<-normalizePath(a[3]);auth<-normalizePath(a[4]);skill<-normalizePath(Sys.getenv('BIOFIGURE_SKILL_ROOT'));source(file.path(skill,'scripts/figure_style.R'))
suppressPackageStartupMessages({library(ggplot2);library(ggalluvial);library(circlize);library(dplyr);library(cowplot);library(reshape2);library(grid)})
source(file.path(root,'sources/visualization.R'));font<-bf_font('Arial');spec<-yaml::read_yaml(sp);W<-183;H<-170;pd<-file.path(root,'results/plot_data');x<-readRDS(file.path(root,'data/raw/cellchat_humanSkin_LS.rds'));cells<-levels(slot(x,'idents'));cols<-unlist(spec$palette_semantics[cells]);names(cols)<-cells;pcs<-unlist(spec$palette_semantics[paste('Pattern',1:3)]);names(pcs)<-paste('Pattern',1:3)
# A temporary base device prevents implicit cwd/Rplots.pdf creation.
base_measure_file<-tempfile(fileext='.pdf');grDevices::pdf(base_measure_file,width=7,height=7)
# Native author chord function. Native grid conversion preserves editable vector curves/text.
chord<-ggplotify::as.grob(function(){par(mar=c(.4,.4,.4,.4),family='sans',ps=9);netVisual_chord_gene(x,sources.use=1:4,targets.use=5:11,slot.name='netP',color.use=cols,show.legend=FALSE,lab.cex=.78,small.gap=1.5,big.gap=12,transparency=.42,annotationTrackHeight=.035)})
# Blank receiver sectors are intentional author geometry, not text annotations.
# Apply the resolved final font to captured native vector labels.
clean_grob<-function(g){if(inherits(g,'text')){g$label[!nzchar(trimws(g$label))]<-'';g$gp$fontfamily<-font$family;g$gp$fontsize<-8.5};if(length(g$grobs))g$grobs<-lapply(g$grobs,clean_grob);if(length(g$children))for(i in seq_along(g$children))g$children[[i]]<-clean_grob(g$children[[i]]);g}
chord<-clean_grob(chord);dev.off();unlink(base_measure_file)
# Author's two independent bridges, source threshold and factor orders retained.
river<-function(kind){d<-read.csv(file.path(pd,paste0('outgoing-',kind,'.csv')),check.names=FALSE);d$Contribution[d$Contribution<.5]<-0
 if(kind=='cell'){d$CellGroup<-factor(d$CellGroup,levels=cells);d$Pattern<-factor(d$Pattern,levels=names(pcs));d<-d[,c('CellGroup','Pattern','Contribution')];cn<-c(cols,pcs);labs<-c('Cell groups','Patterns');flow<-'backward'}else{lev<-c('GALECTIN','CXCL','COMPLEMENT','FGF','TNF','CCL','GAS','IL4','CD40','LIGHT','CSF','VEGF','MIF');d$Pattern<-factor(d$Pattern,levels=names(pcs));d$Signaling<-factor(d$Signaling,levels=lev);d<-d[,c('Pattern','Signaling','Contribution')];cn<-c(pcs,setNames(rep('#B8BBC0',length(lev)),lev));labs<-c('Patterns','Signaling');flow<-'forward'}
 dl<-ggalluvial::to_lodes_form(d,axes=1:2,id='connection');p<-ggplot(dl,aes(x=x,y=Contribution,stratum=stratum,alluvium=connection,fill=stratum,label=stratum))+geom_flow(width=.36,aes.flow=flow,alpha=.36,color='transparent')+geom_stratum(width=.36,linewidth=.18,color='#757A80',alpha=.9)+geom_text(stat='stratum',size=6.5/ggplot2::.pt,family=font$family,color='#181B20',lineheight=.95)+scale_fill_manual(values=cn,drop=FALSE)+scale_x_discrete(labels=labs,expand=expansion(add=.28))+scale_y_continuous(expand=expansion(mult=c(.01,.01)))+theme_void(base_family=font$family)+theme(legend.position='none',axis.text.x=element_text(family=font$family,size=7,color='#30343B',margin=margin(t=4)),plot.margin=margin(0,0,0,0))
 p}
r1<-river('cell');r2<-river('signaling')
measure_file<-tempfile(fileext='.png');ragg::agg_png(measure_file,width=W,height=H,units='mm',res=300);r1g<-ggplotGrob(r1);r2g<-ggplotGrob(r2);dev.off();unlink(measure_file)
p<-ggplot()+theme_void(base_family=font$family)+theme(plot.margin=margin(0,0,0,0),plot.background=element_rect(fill='white',colour=NA))+coord_cartesian(xlim=c(0,W),ylim=c(0,H),expand=FALSE,clip='on')
p<-p+annotation_custom(chord,xmin=15,xmax=108,ymin=77,ymax=170)+annotation_custom(r1g,xmin=5,xmax=88,ymin=4,ymax=72)+annotation_custom(r2g,xmin=96,xmax=179,ymin=4,ymax=72)
label<-data.frame(x=c(4,4,135),y=c(165,76,155),label=c('a','b','Cell state'),size=c(8,8,7),face=c('bold','bold','bold'))
label<-rbind(label,data.frame(x=141,y=148-seq(0,11)*4.4,label=cells,size=6.5,face='plain'))
p<-p+geom_point(data=data.frame(x=137,y=148-seq(0,11)*4.4,cell=cells),aes(x,y,fill=cell),shape=22,size=2.5,stroke=0,show.legend=FALSE)+scale_fill_manual(values=cols)
p<-p+geom_text(data=label,aes(x,y,label=label,size=I(size/ggplot2::.pt),fontface=face),hjust=0,family=font$family,lineheight=1)
f<-file.path(pd,c('chord-pathway-edges.csv','chord-lr-edges.csv','outgoing-cell.csv','outgoing-signaling.csv','cell-groups.csv'));sources<-c(sp,file.path(root,'scripts/render-cellchat.R'),file.path(skill,'scripts/figure_style.R'),file.path(root,'sources/visualization.R'),file.path(root,'data/raw/cellchat_humanSkin_LS.rds'),f);boxes<-data.frame(id=c('data','labels','legend'),x=c(5,0,130),y=c(4,4,93),w=c(123,130,48),h=c(164,164,65))
bf_render_png(p,file.path(out,'cellchat-complex.png'),font,unlist(spec$text_contract$allowed_text),W,H,W,sources,boxes,allowed_pairs=c('data:labels'),dpi=300,min_text_pt=6,authorization=auth,skill_root=skill,publication_size_class='double-column')
pdf<-file.path(out,'cellchat-complex.pdf');bf_pdf_open(pdf,W,H,font);print(p);dev.off();bf_pdf_finalize(pdf,font,W,H)
writeLines(capture.output(sessionInfo()),file.path(out,'session-info.txt'));jsonlite::write_json(list(author_chord_function_executed=TRUE,author_river_grammar='two ggalluvial bridges, independent contributions',raw_analysis_run=FALSE,pattern_cutoff=.5,source_cell_order=cells,figure_size_mm=c(W,H),probability_sum=sum(read.csv(f[1])$prob)),file.path(out,'render-metrics.json'),auto_unbox=TRUE,pretty=TRUE,digits=NA)
