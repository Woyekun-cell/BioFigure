#!/usr/bin/env Rscript
# Shi et al., Nature 2025 Fig4c. Native circlize + venn, source-specific adaptation.
# Author plotting code CC-BY-4.0; paper artwork CC-BY-NC-ND-4.0. See source manifest.
a<-commandArgs(TRUE);stopifnot(length(a)==4)
root<-normalizePath(a[1]);out<-normalizePath(a[2]);spec_path<-normalizePath(a[3]);auth<-normalizePath(a[4]);skill<-normalizePath(Sys.getenv('BIOFIGURE_SKILL_ROOT'))
source(file.path(skill,'scripts/figure_style.R'))
options(error=function(){traceback(12);quit(status=1)})
suppressPackageStartupMessages({library(circlize);library(ggplot2);library(grid);library(ggplotify)})
font<-bf_font('Arial');spec<-yaml::read_yaml(spec_path);W<-spec$output_size$width_mm;H<-spec$output_size$height_mm
input<-file.path(root,'results/plot_data/fig4c/regulon-age.csv');rss_file<-file.path(root,'results/plot_data/fig4c/rss.csv')
d<-read.csv(input,check.names=FALSE,na.strings='NA');rss<-read.csv(rss_file,check.names=FALSE)
stopifnot(nrow(d)==68,nrow(rss)==200,length(unique(d$regulon))==17,all(table(d$regulon)==4),all(table(rss$subset)==50))
subs<-c('B03_Bn_NR4A2','B05_Bm_NR4A2','CD4T03_Tn_NR4A1','I06_CD16loNK_NR4A2');short<-c('B03','B05','CD4T03','I06');pal<-setNames(unlist(spec$palette_semantics[short]),subs)
# Author factor levels default alphabetical; preserve explicit locale-independent order.
regs<-sort(unique(d$regulon),method='radix');d<-d[order(match(d$regulon,regs),match(d$subset,subs)),]
m<-as.matrix(d[,3:7]);storage.mode(m)<-'double';stopifnot(sum(is.na(m))==17)
sets<-setNames(lapply(subs,function(s)rss$regulon[rss$subset==s]),short);shared<-Reduce(intersect,sets);stopifnot(length(shared)==17,setequal(shared,regs))
# Derive all 15 nonempty exclusive Venn regions directly from author sets.
u<-sort(unique(unlist(sets)));member<-vapply(sets,function(s)u%in%s,logical(length(u)));codes<-apply(member,1,paste0,collapse='');counts<-as.data.frame(table(codes));write.csv(counts,file.path(out,'venn-exclusive-counts.csv'),row.names=FALSE)
col_fun<-circlize::colorRamp2(seq(0,.1,length.out=4),RColorBrewer::brewer.pal(7,'RdBu')[4:7])
metrics<-list()
ringfun<-function(){
 par(mar=c(0,0,0,0),family=font$family,cex=1,ps=12)
 circos.clear();circos.par(start.degree=62,gap.after=c(rep(2,16),30),points.overflow.warning=FALSE,canvas.xlim=c(-1.10,1.10),canvas.ylim=c(-1.10,1.10))
 circos.heatmap(d$subset,split=factor(d$regulon,levels=regs),col=pal,track.height=.05,cluster=FALSE)
 circos.track(track.index=get.current.track.index(),panel.fun=function(x,y){
  circos.text(CELL_META$xcenter,CELL_META$cell.ylim[2]+convert_y(1,'mm'),CELL_META$sector.index,facing='bending.inside',cex=7/12,adj=c(.5,0),niceFacing=TRUE)
 },bg.border=NA)
 circos.heatmap(m,split=factor(d$regulon,levels=regs),track.height=.5,cluster=FALSE,col=col_fun,na.col='#BEBEBE')
 circos.track(track.index=get.current.track.index(),panel.fun=function(x,y){
  metrics[[CELL_META$sector.index]]<<-list(regulon=CELL_META$sector.index,angular_columns=4,age_tracks=5,cell_xcenter=CELL_META$xcenter,sector_start=CELL_META$cell.start.degree,sector_end=CELL_META$cell.end.degree,track_bottom_radius=CELL_META$cell.bottom.radius,track_top_radius=CELL_META$cell.top.radius)
  if(CELL_META$sector.numeric.index==17){n<-ncol(m);circos.text(rep(CELL_META$cell.xlim[2],n)+convert_x(1,'mm'),n-1:n+.5,colnames(m),cex=7/12,adj=c(0,.5),facing='inside')}
 },bg.border=NA)
 text(0,0,'Cellular activity of\nconvergent regulons\nin CM05',cex=7/12,family=font$family)
 circos.clear()
}
vennfun<-function(){
 par(mar=c(0,0,0,0),family=font$family,ps=12,cex=1)
 venn::venn(sets,ilabels='counts',box=FALSE,ilcs=7/12,sncs=7/12,zcolor=setNames(unname(pal),short),col=NA)
}
# Capture native base geometry as vector grobs at exact eventual physical dimensions.
capture_native<-function(fun,w,h){
 tmp<-tempfile(fileext='.pdf');bf_pdf_open(tmp,w,h,font);on.exit({dev.off();unlink(tmp)})
 scratch<-character(); device<-function(width,height,...){f<-tempfile(fileext='.pdf');scratch<<-c(scratch,f);bf_pdf_open(f,width*25.4,height*25.4,font);dev.control('enable')}
 g<-grid::grid.grabExpr(gridGraphics::grid.echo(fun,device=device),width=w/25.4,height=h/25.4,device=device);unlink(scratch)
 # Native capture and final devices share BioFigure's registered Arial metrics; audit every captured text face.
 fix<-function(x){if(inherits(x,'rect') && length(x$gp$fill)==1 && !is.na(x$gp$fill) && toupper(x$gp$fill)%in%c('WHITE','#FFFFFF','#FFFFFFFF')){x$gp$fill<-NA;x$gp$col<-NA};if(inherits(x,'text'))x$gp$fontfamily<-font$family;if(length(x$grobs))x$grobs<-lapply(x$grobs,fix);if(length(x$children))for(i in seq_along(x$children))x$children[[i]]<-fix(x$children[[i]]);x};fix(g)
}
message('ring capture');ring<-capture_native(ringfun,110,106);message('Venn capture');vg<-capture_native(vennfun,33,33);message('composition')
p<-ggplot()+coord_fixed(xlim=c(0,W),ylim=c(0,H),expand=FALSE,clip='on')+theme_void()+theme(plot.margin=margin(0,0,0,0,'mm'),plot.background=element_rect(fill='white',colour=NA))+
 annotation_custom(ring,xmin=0,xmax=110,ymin=0,ymax=106)+annotation_custom(vg,xmin=103,xmax=136,ymin=65,ymax=98)
text<-data.frame(label=c('Convergent regulons\nin CM05','Cell subset',short,'Activity','Min','Max'),x=c(119.5,119.5,117,117,117,117,119.5,104,132),y=c(100.5,60,52,44,36,28,17,8,8),size=c(8,8,7,7,7,7,8,7,7),hjust=c(.5,.5,0,0,0,0,.5,.5,.5))
text$size<-text$size/ggplot2::.pt
p<-p+geom_text(data=text,aes(x=x,y=y,label=label,size=size,hjust=hjust),family=font$family,lineheight=1.05)+scale_size_identity()
keys<-data.frame(x=111,y=c(52,44,36,28),fill=unname(pal));p<-p+geom_point(data=keys,aes(x=x,y=y,fill=fill),shape=22,size=4,stroke=0,colour='#FFFFFF')+scale_fill_identity()
bars<-data.frame(x=seq(109,127,length.out=200),y=8,fill=col_fun(seq(0,.1,length.out=200)))
legendg<-grid::rectGrob(x=grid::unit(seq(0,1,length.out=200),'npc'),y=.5,width=grid::unit(1/199,'npc'),height=1,gp=grid::gpar(fill=bars$fill,col=NA));p<-p+annotation_custom(legendg,xmin=109,xmax=127,ymin=6.5,ymax=9.5)
# No square-rectangular-matrix contract: native activity cells are annular sectors by construction; legend tile is a color key.
sources<-c(spec_path,file.path(root,'scripts/render-fig4c.R'),file.path(skill,'scripts/figure_style.R'),input,rss_file)
boxes<-data.frame(id=c('data','labels','legend'),x=c(0,103,103),y=c(0,0,44),w=c(103,33,33),h=c(106,44,62))
bf_render_png(p,file.path(out,'fig4c.png'),font=font,allowed_text=unlist(spec$text_contract$allowed_text),width_mm=W,height_mm=H,target_width_mm=W,dpi=300,min_text_pt=7,source_files=sources,boxes=boxes,authorization=auth,skill_root=skill,publication_size_class='one-and-half-column')
pdf<-file.path(out,'fig4c.pdf');bf_pdf_open(pdf,W,H,font);print(p);dev.off();bf_pdf_finalize(pdf,font,W,H)
jsonlite::write_json(list(source='Nature2025 Fig4c',n_activity_values=length(m),n_missing=sum(is.na(m)),n_top50_memberships=nrow(rss),n_union=length(u),shared_regulons=shared,n_shared=length(shared),native_sectors=metrics,source_palette=as.list(pal),activity_breaks=seq(0,.1,length.out=4),activity_colors=RColorBrewer::brewer.pal(7,'RdBu')[4:7],packages=as.list(vapply(c('circlize','venn','ggplotify','gridGraphics','ggplot2','ragg'),function(z)as.character(packageVersion(z)),''))),file.path(out,'render-metrics.json'),auto_unbox=TRUE,pretty=TRUE)
writeLines(capture.output(sessionInfo()),file.path(out,'session-info.txt'))
