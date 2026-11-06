#!/usr/bin/env Rscript
# Source-exposed reconstruction of original ggplot tile grammar. No model refitting.
a<-commandArgs(TRUE);stopifnot(length(a)==4);root<-normalizePath(a[1]);out<-normalizePath(a[2]);sp<-normalizePath(a[3]);auth<-normalizePath(a[4]);skill<-normalizePath(Sys.getenv('BIOFIGURE_SKILL_ROOT'));source(file.path(skill,'scripts/figure_style.R'))
suppressPackageStartupMessages({library(ggplot2);library(RColorBrewer);library(magrittr)})
source(file.path(root,'sources/author/dynutils-scaling-47f4f4e.R'));font<-bf_font('Arial');spec<-yaml::read_yaml(sp);W<-183;H<-160
pd<-file.path(root,'results/plot_data/fig2abcd');f<-file.path(pd,c('panel_a_ligand_activity.csv','panel_b_ligand_target.csv','panel_c_target_expression.csv','panel_d_tumor_score.csv'));aa<-read.csv(f[1],check.names=FALSE);bb<-read.csv(f[2],check.names=FALSE);cc<-read.csv(f[3],check.names=FALSE);dd<-read.csv(f[4],check.names=FALSE)
stopifnot(identical(aa$ligand,bb$ligand),identical(names(bb)[-1],names(cc)[-1]),identical(cc$tumor_id,dd$tumor_id),nrow(bb)==20,ncol(bb)==32,nrow(cc)==10,ncol(cc)==32)
scaled<-scale_quantile(as.matrix(cc[,-1]));stopifnot(all(is.finite(scaled)),min(scaled)==0,max(scaled)==1);write.csv(data.frame(tumor_id=cc$tumor_id,scaled,check.names=FALSE),file.path(out,'panel_c_scaled_expression.csv'),row.names=FALSE)
# ggplot's continuous palettes interpolate in Lab; preserve original source endpoints.
grad<-function(vals,breaks,cols){scales::gradient_n_pal(cols,values=scales::rescale(breaks),space='Lab')(scales::rescale(vals,from=range(breaks)))}
exprcols<-colorRampPalette(rev(brewer.pal(7,'RdYlBu')))(100);pemtcols<-colorRampPalette(rev(brewer.pal(7,'Spectral')))(100)
ac<-function(v)grad(v,range(aa$Pearson),c('whitesmoke','darkorange'))
bc<-function(v)grad(v,c(0,.0035,.007),c('whitesmoke','whitesmoke','mediumvioletred'))
# Source gradient2 is centered at0; its negative interval lies outside displayed limits.
bc<-function(v)grad(v,c(0,.007),c('whitesmoke','mediumvioletred'))
ec<-function(v)grad(v,c(0,.5,1),c(exprcols[1],exprcols[50],exprcols[100]))
pc<-function(v)grad(v,c(-max(abs(dd$pEMT_score)),0,max(abs(dd$pEMT_score))),c(pemtcols[1],'whitesmoke',pemtcols[100]))
make<-function(mat,x0,y0,colorfun){mat<-as.matrix(mat);d<-expand.grid(row=seq_len(nrow(mat)),col=seq_len(ncol(mat)));d$value<-as.vector(mat);d$x<-x0+(d$col-.5)*3;d$y<-y0+(d$row-.5)*3;d$fill<-colorfun(d$value);d}
da<-make(matrix(aa$Pearson,ncol=1),28,72,ac);db<-make(bb[,-1],50,72,bc);dc<-make(scaled,50,22,ec);ds<-make(matrix(dd$pEMT_score,ncol=1),166,22,pc)
p<-ggplot()+theme_void(base_family=font$family)+theme(plot.margin=margin(0,0,0,0),plot.background=element_rect(fill='white',colour=NA))+coord_fixed(xlim=c(0,W),ylim=c(0,H),expand=FALSE,clip='on')
for(d in list(da,db,dc,ds))p<-p+geom_tile(data=d,aes(x,y,fill=fill),width=3,height=3,color='white',linewidth=.15)
p<-p+scale_fill_identity()
lab<-function(x,y,label,size=6.5,angle=0,hjust=.5,vjust=.5,face='plain'){data.frame(x,y,label,size,angle,hjust,vjust,face)}
l<-rbind(lab(26,73.5+(0:19)*3,aa$ligand,hjust=1),lab(48,73.5+(0:19)*3,bb$ligand,hjust=1),lab(48,23.5+(0:9)*3,cc$tumor_id,hjust=1),lab(164,23.5+(0:9)*3,dd$tumor_id,hjust=1),lab(51.5+(0:30)*3,134,names(bb)[-1],angle=90,hjust=0,face='italic'),lab(51.5+(0:30)*3,54,names(cc)[-1],angle=90,hjust=0,face='italic'),lab(29.5,148,'Ligand activity',size=7),lab(96.5,153,'Predicted target genes',size=7),lab(167.5,59,'pEMT score',size=7,angle=90,hjust=0),lab(5,102,'Prioritized CAF-ligands',size=7,angle=90),lab(36,37,'Tumor',size=7,angle=90),lab(c(4,39,39,155),c(155,155,67,67),c('a','b','c','d'),size=8,face='bold'))
# Four separate color keys. Numerical summaries remain outside heatmap bodies.
bar<-function(x,y,breaks,fun,ticks,ticklab,title){v<-seq(min(breaks),max(breaks),length.out=128);d<-data.frame(x=x+seq(0,31,length.out=128),y=y,fill=fun(v));p<<-p+geom_segment(data=d,aes(x=x,y=y,xend=x,yend=y+2.5,colour=fill),linewidth=.5,lineend='butt');tx<-x+scales::rescale(ticks,to=c(0,31),from=range(breaks));l<<-rbind(l,lab(tx,y-1.5,ticklab,size=6),lab(x+15.5,y+6,title,size=6))}
bar(7,7,range(aa$Pearson),ac,c(.10,.11,.12),c('0.10','0.11','0.12'),'Pearson correlation')
bar(52,7,c(0,.007),bc,c(0,.0035,.007),c('0','0.0035','0.007'),'Regulatory potential')
bar(97,7,c(0,1),ec,c(0,.25,.5,.75,1),c('0','0.25','0.50','0.75','1.00'),'Scaled expression')
bar(143,7,range(dd$pEMT_score),pc,c(-.5,0,.5,1,1.5),c('-0.5','0','0.5','1.0','1.5'),'pEMT score')
p<-p+scale_colour_identity()
# Explicit per-label physical point sizes, font and justification.
p<-p+geom_text(data=l,aes(x,y,label=label,size=I(size/ggplot2::.pt),angle=angle,hjust=hjust,vjust=vjust,fontface=face),family=font$family,lineheight=1)
sources<-c(sp,file.path(root,'scripts/render-fig2abcd.R'),file.path(skill,'scripts/figure_style.R'),f,file.path(root,'sources/author/dynutils-scaling-47f4f4e.R'));boxes<-data.frame(id=c('data','labels','legend'),x=c(28,0,4),y=c(22,20,3),w=c(141,183,175),h=c(110,137,14))
bf_render_png(p,file.path(out,'fig2abcd.png'),font,unlist(spec$text_contract$allowed_text),W,H,W,sources,boxes,allowed_pairs=c('data:labels'),dpi=300,min_text_pt=6,authorization=auth,skill_root=skill,publication_size_class='double-column')
pdf<-file.path(out,'fig2abcd.pdf');bf_pdf_open(pdf,W,H,font);print(p);dev.off();bf_pdf_finalize(pdf,font,W,H)
# Independently measure the final PDF device too (same native ggplot coordinates).
bf_pdf_open(file.path(out,'pdf-cell-measurement.pdf'),W,H,font);built<-ggplot_build(p);g<-ggplot_gtable(built);grid::grid.draw(g);plan<-bf_ggplot_cell_plan(p,built,TRUE);metrics<-bf_measure_ggplot_cells(plan,g,'square',.01);dev.off();unlink(file.path(out,'pdf-cell-measurement.pdf'))
jsonlite::write_json(list(heatmap_cells=metrics,all_labels=l,quantile_cutoff=.05,quantile_algorithm='R stats::quantile default type7, per target column',figure_size_mm=c(W,H),raw_analysis_run=FALSE,source_scale_code_sha=digest::digest(file=file.path(root,'sources/author/dynutils-scaling-47f4f4e.R'),algo='sha256')),file.path(out,'render-metrics.json'),auto_unbox=TRUE,pretty=TRUE,digits=NA)
writeLines(capture.output(sessionInfo()),file.path(out,'session-info.txt'))
