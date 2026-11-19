#!/usr/bin/env Rscript
# R6 / R11, Allen et al. RainCloudPlots (MIT). Source code is retained unchanged.
# Native ggplot2 StatYdensity; one-sided geometry adapted to current linewidth API.
args<-commandArgs(TRUE);stopifnot(length(args)==4)
root<-normalizePath(args[1]);case<-args[2];out<-normalizePath(args[3]);auth<-normalizePath(args[4])
skill<-normalizePath(Sys.getenv('BIOFIGURE_SKILL_ROOT'));source(file.path(skill,'scripts/figure_style.R'))
library(ggplot2)
font<-bf_font('Arial');spec_path<-Sys.getenv('BIOFIGURE_DESIGN_SPEC',file.path(root,'data/metadata',case,'design-spec.yaml'));spec<-yaml::read_yaml(spec_path)
input<-file.path(root,'results/plot_data',paste0(case,'.csv'));d<-read.csv(input)
GeomHalfCloud<-ggproto('GeomHalfCloud',Geom,
 required_aes=c('x','y'),default_aes=aes(weight=1,colour='grey20',fill='white',linewidth=.5,alpha=NA,linetype=1),draw_key=draw_key_polygon,
 setup_data=function(data,params){data$width<-if(is.null(params$width))resolution(data$x,FALSE)*.9 else params$width;data$xmin<-data$x;data$xmax<-data$x+data$width/2;data},
 draw_group=function(data,panel_params,coord){a<-data[order(data$y),];z<-a[nrow(a):1,];z$x<-z$x+z$violinwidth*(z$xmax-z$xmin);poly<-rbind(a,z,a[1,]);GeomPolygon$draw_panel(poly,panel_params,coord)})
halfcloud<-function(...,adjust,alpha=1,colour=NULL){args<-list(...);if(!is.null(colour))args$colour<-colour;layer(geom=GeomHalfCloud,stat='ydensity',position=position_nudge(x=if(case=='r6').25 else .1),params=c(list(trim=FALSE,scale='area',adjust=adjust,alpha=alpha),args))}
pal<-unlist(spec$palette_semantics)
if(case=='r6'){
 stopifnot(nrow(d)==500);d$group<-factor(d$group,levels=c('Group1','Group2'))
 p<-ggplot(d,aes(x=group,y=score,fill=group,colour=group))+
  halfcloud(adjust=2)+geom_point(position=position_jitter(width=.15,height=0,seed=20261023),size=.25)+
  geom_boxplot(aes(x=as.numeric(group)+.25),outlier.shape=NA,alpha=.3,width=.1,colour='black')+
  coord_flip()+labs(x='Group',y='Score')+guides(fill='none',colour='none')+
  scale_y_continuous(breaks=seq(-50,200,50))
 summary<-aggregate(score~group,d,function(x)c(n=length(x),mean=mean(x),median=median(x),sd=sd(x)))
}else{
 stopifnot(case=='r11',nrow(d)==87);d$time<-factor(d$time,levels=1:3);d$group<-factor(d$group,levels=1:2)
 summary<-do.call(rbind,lapply(split(d,interaction(d$time,d$group)),function(x)data.frame(time=x$time[1],group=x$group[1],n=nrow(x),mean=mean(x$score),sem=sd(x$score)/sqrt(nrow(x)))))
 stopifnot(identical(sort(summary$n),c(11L,11L,11L,18L,18L,18L)))
 p<-ggplot(d,aes(x=time,y=score,fill=group))+
  halfcloud(adjust=1.5,alpha=.5,colour=NA)+
  geom_point(aes(x=as.numeric(time)-.15,colour=group),position=position_jitter(width=.05,height=0,seed=20261023),size=.25,shape=20)+
  geom_boxplot(outlier.shape=NA,alpha=.5,width=.1,colour='black')+
  geom_line(data=summary,aes(x=as.numeric(time)+.1,y=mean,group=group,colour=group),linetype=3)+
  geom_point(data=summary,aes(x=as.numeric(time)+.1,y=mean,colour=group),shape=18)+
  geom_errorbar(data=summary,aes(x=as.numeric(time)+.1,y=mean,colour=group,ymin=mean-sem,ymax=mean+sem),width=.05)+
  labs(x='time',y='score')+scale_y_continuous(breaks=c(0,5,10,15))
}
p<-p+scale_fill_manual(values=pal)+scale_colour_manual(values=pal)+cowplot::theme_cowplot(font_family=font$family,font_size=10.5)+
 theme(axis.text=element_text(size=10.5),axis.title=element_text(size=11.5),legend.text=element_text(size=10.5),legend.title=element_text(size=11.5),legend.key.size=grid::unit(4,'mm'),plot.margin=margin(2,2,2,2,'mm'))
b<-ggplot_build(p);stopifnot(nrow(b$data[[2]])==nrow(d),nrow(b$data[[3]])==if(case=='r6')2 else 6)
write.csv(d,file.path(out,'rendered-input.csv'),row.names=FALSE);write.csv(summary,file.path(out,'summary.csv'),row.names=FALSE)
write.csv(b$data[[1]],file.path(out,'native-density.csv'),row.names=FALSE)
source_files<-c(spec_path,file.path(root,'scripts/render.R'),file.path(skill,'scripts/figure_style.R'),input)
w<-spec$output_size$width_mm;h<-spec$output_size$height_mm
boxes<-if(case=='r6')data.frame(id=c('data','labels','legend'),x=c(18,2,130),y=c(2,h-12,h-12),w=c(116,114,4),h=c(h-16,10,2)) else data.frame(id=c('data','labels','legend'),x=c(14,2,120),y=c(2,h-12,17),w=c(103,114,14),h=c(h-16,10,30))
bf_render_png(p,file.path(out,paste0(case,'.png')),font=font,allowed_text=unlist(spec$text_contract$allowed_text),width_mm=w,height_mm=h,target_width_mm=w,dpi=300,min_text_pt=10.5,source_files=source_files,boxes=boxes,authorization=auth,skill_root=skill,publication_size_class='one-and-half-column')
pdf<-file.path(out,paste0(case,'.pdf'));bf_pdf_open(pdf,w,h,font);print(p);dev.off();bf_pdf_finalize(pdf,font,w,h)
jsonlite::write_json(list(case=case,n=nrow(d),source_rows_preserved=TRUE,jitter_seed=20261023,summary_semantics=if(case=='r6')'Tukey boxes, whiskers 1.5 IQR' else 'Tukey boxes; group means connected with mean +/- SEM; no subject-pair lines',packages=as.list(vapply(c('ggplot2','cowplot','ragg','systemfonts'),function(x)as.character(packageVersion(x)),'')),R=R.version.string),file.path(out,'render-metrics.json'),auto_unbox=TRUE,pretty=TRUE)
writeLines(capture.output(sessionInfo()),file.path(out,'session-info.txt'))
