# Usage: Rscript render_source_panels.R CASE WORK_DIRECTORY AUTHORIZATION
# Source Data visualization only; no raw analysis, no new hypothesis tests.
library(ggplot2);library(yaml)
args<-commandArgs(TRUE);stopifnot(length(args)==3)
case<-args[1];work<-normalizePath(args[2]);authorization<-args[3]
script<-normalizePath(sub('^--file=','',grep('^--file=',commandArgs(),value=TRUE)))
root<-dirname(dirname(script));skill<-normalizePath(file.path(root,'../../../..'))
source(file.path(skill,'scripts/figure_style.R'));font<-bf_font('Arial')
spec<-file.path(root,'data/metadata',paste0(case,'-design-spec.yaml'));design<-read_yaml(spec)
files<-c(curve='pan_core_accumulation',sv='sv_type_counts',density='genomic_density_tracks');name<-files[[case]]
input<-file.path(root,'results/plot_data',paste0(name,'.csv'));d<-read.csv(input,check.names=FALSE)
pal<-unlist(design$palette_semantics)
if(case=='curve'){
 d$Class<-factor(ifelse(d$class=='pan','Pan','Core'),levels=c('Pan','Core'))
 p<-ggplot(d,aes(n_genomes,mean,color=Class,fill=Class))+
  geom_ribbon(aes(ymin=min,ymax=max),alpha=.18,colour=NA)+geom_line(linewidth=.6)+geom_point(size=1.7)+
  scale_colour_manual(values=pal[c('Pan','Core')],labels=c(Pan='Pan (mean; range)',Core='Core (mean; range)'),name=NULL)+scale_fill_manual(values=pal[c('Pan','Core')],labels=c(Pan='Pan (mean; range)',Core='Core (mean; range)'),name=NULL)+
  scale_x_continuous(breaks=c(2,4,6,8,10,12,13),minor_breaks=NULL,expand=expansion(mult=c(.03,.03)))+
  scale_y_continuous(breaks=seq(20000,40000,5000),labels=function(x)format(x,trim=TRUE),expand=expansion(mult=c(.04,.04)))+
  labs(x='Number of genomes',y='Gene families')+bf_theme(font)+theme(legend.position='bottom')
}
if(case=='sv'){
 raw_order<-unique(d$accession);labels<-raw_order
 labels[labels=='S. lycopersicum var. cerasiforme']<-'S. lycopersicum (cerasiforme)'
 labels[labels=='S. lycopersicum M82']<-'S. lycopersicum (M82)'
 labels[labels=='S. lycopersicum Heinz1706']<-'S. lycopersicum (Heinz 1706)'
 d$Accession<-factor(d$accession,levels=rev(raw_order));d$Type<-factor(d$sv_type,levels=c('INS','DEL','CNV','INV','TRANS'))
 p<-ggplot(d,aes(count,Accession,fill=Type))+geom_col(width=.72,colour=NA,position=position_stack(reverse=TRUE))+
  scale_y_discrete(labels=setNames(labels,raw_order))+
  scale_fill_manual(values=pal[levels(d$Type)],name=NULL)+
  scale_x_continuous(limits=c(0,80000),breaks=seq(0,80000,20000),labels=function(x)format(x,trim=TRUE),expand=expansion(mult=c(0,.01)))+
  labs(x='Structural variants',y=NULL)+bf_theme(font)+theme(legend.position='bottom',axis.ticks.y=element_blank(),axis.text.y=element_text(face='italic'))
}
if(case=='density'){
 d$Chromosome<-factor(sub('Sly','',d$chrom),levels=sprintf('%02d',1:12))
 d$Track<-factor(d$track,levels=rev(c('Gene','Repeats','INS','DEL','INV','TRANS')))
 # Original per-track normalized values and window centers, no coordinate conversion.
 d$width_mb<-(d$end-d$start+1)/1e6
 p<-ggplot(d,aes(mid_mb,Track,fill=value))+geom_tile(aes(width=width_mb),height=.84)+
  facet_wrap(~Chromosome,ncol=4)+
  scale_fill_gradientn(colours=c('#F3FAE6','#8ED2A1','#2AB7A9','#217AA8','#253A74'),limits=c(0,1),breaks=c(0,.25,.5,.75,1),labels=function(x)sprintf('%.2f',x),name='Normalized density')+
  scale_x_continuous(breaks=c(0,50,100),expand=expansion(mult=c(.01,.01)))+
  coord_cartesian(xlim=c(0,100))+labs(x='Chromosome position (Mb)',y=NULL)+bf_theme(font)+
  theme(legend.position='bottom',axis.line=element_blank(),axis.ticks.y=element_blank(),panel.background=element_rect(fill='#ECEFF1',colour=NA),panel.spacing=grid::unit(3,'mm'),strip.background=element_blank())+
  guides(fill=guide_colourbar(barwidth=grid::unit(40,'mm'),barheight=grid::unit(2.2,'mm'),title.position='top'))
}
width<-design$output_size$width_mm;height<-design$output_size$height_mm
boxes<-data.frame(id=c('data','labels','legend'),x=c(45,1,45),y=c(4,4,height-16),w=c(width-50,42,width-50),h=c(height-26,height-26,13))
out<-file.path(work,paste0(name,'.png'))
bf_render_png(p,out,font,design$text_contract$allowed_text,width,height,width,c(spec,script,file.path(skill,'scripts/figure_style.R'),input),boxes,
 authorization=authorization,skill_root=skill,publication_size_class=design$output_size$size_class)
grDevices::quartz(type='pdf',file=file.path(root,'results/figures',paste0(name,'.pdf')),width=width/25.4,height=height/25.4,family='Arial')
print(p);invisible(dev.off())
ggsave(file.path(work,paste0(name,'.svg')),p,device=svglite::svglite,width=width,height=height,units='mm',bg='white')
cat(case,'SOURCE_PANEL_RENDER_OK\n')
