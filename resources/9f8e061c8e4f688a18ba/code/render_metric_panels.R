# Usage: Rscript render_metric_panels.R CASE PREVIEW_DIRECTORY AUTHORIZATION
# Recompute inputs with recompute_public_tables.R; preserve source metrics and NAs.
library(ggplot2)
library(dplyr)
library(yaml)
args<-commandArgs(TRUE);stopifnot(length(args)==3)
name<-args[1];work<-normalizePath(args[2]);auth<-args[3]
script<-normalizePath(sub('^--file=','',grep('^--file=',commandArgs(),value=TRUE)))
root<-dirname(dirname(script));skill<-normalizePath(file.path(root,'../../..'))
source(file.path(skill,'scripts/figure_style.R'));font<-bf_font('Arial')
spec<-file.path(root,'data/metadata',paste0(name,'-design-spec.yaml'));design<-read_yaml(spec)
pal<-unlist(design$project_style_contract$semantic_colors)
files<-c(hprc='hprc_mapping_metrics',glue='glue_baseline_metrics',scenic='scenic_perturbation_correlations',scbasset='scbasset_tf_correlations',numbat='numbat_modality_summary')
input<-file.path(root,'results/plot_data',paste0(files[[name]],'.csv'));d<-read.csv(input,check.names=FALSE)
set.seed(20260928)
if(name=='hprc') {
 d$Method<-factor(d$Method,levels=c('vg mpmap (unique)','vg mpmap (multi)','STAR (unique)','STAR (multi)'))
 p<-ggplot(d,aes(TPR,PPV,colour=Reference,shape=Method))+
  geom_point(size=2.5,stroke=.5)+
  scale_colour_manual(values=c('MC spliced graph'=pal[['MC_spliced_graph']],'Spliced GRCh38 reference'=pal[['GRCh38_reference']]),name=NULL)+
  scale_shape_manual(values=c(16,17,1,2),name=NULL)+
  scale_x_continuous(limits=c(.975,1.001),breaks=seq(.975,1,.005),labels=function(z)sprintf('%.3f',z))+
  scale_y_continuous(limits=c(.985,1.001),breaks=seq(.985,1,.005),labels=function(z)sprintf('%.3f',z))+
  labs(x='Mapping recall (author TPR)',y='Mapping precision (author PPV)')+
  bf_theme(font)+guides(shape=guide_legend(nrow=2,byrow=TRUE))+theme(legend.position='bottom',legend.box='vertical')
}
if(name=='glue') {
 label<-c('Chen-2019'='SNARE-seq','Ma-2020'='SHARE-seq','10x-Multiome-Pbmc10k'='10X Multiome')
 d<-d[d$dataset %in% names(label)&is.finite(d$foscttm),]
 d$Dataset<-factor(unname(label[d$dataset]),levels=unname(label))
 methods<-sort(unique(d$method));d$method<-factor(d$method,levels=methods)
 summary<-d %>% group_by(Dataset,method) %>% summarise(mean=mean(foscttm),sd=sd(foscttm),n=n(),.groups='drop')
 missing<-anti_join(expand.grid(Dataset=levels(d$Dataset),method=methods),summary,by=c('Dataset','method'))
 p<-ggplot(d,aes(method,foscttm))+
  geom_col(data=summary,aes(y=mean,fill=method),width=.6,colour=NA)+
  geom_errorbar(data=summary[is.finite(summary$sd),],aes(y=mean,ymin=mean-sd,ymax=mean+sd),width=.2,linewidth=.3)+
  geom_point(position=position_jitter(width=.13,height=0,seed=20260928),size=.65,alpha=.6)+
  geom_text(data=missing,aes(x=method,y=.03,label='N.A.'),inherit.aes=FALSE,family=font$family,size=7/.pt,angle=90)+
  facet_grid(Dataset~.)+scale_fill_manual(values=pal[methods],guide='none')+
  scale_x_discrete(drop=FALSE)+scale_y_continuous(limits=c(0,.7),breaks=seq(0,.7,.1),labels=function(z)sprintf('%.1f',z),expand=expansion(mult=c(0,.02)))+
  labs(x='Method',y='FOSCTTM')+bf_theme(font)+
  theme(axis.text.x=element_text(angle=45,hjust=1),panel.spacing.y=grid::unit(4,'mm'),legend.position='none')
}
if(name=='scenic') {
 d<-d[is.finite(d$spearman),];d$Method<-factor(d$Method,levels=c('SCENIC+','SCENIC','GRaNIE','CellOracle','FigR','Pando'))
 p<-ggplot(d,aes(Method,spearman))+
  geom_boxplot(aes(fill=Method),width=.5,outlier.shape=NA,linewidth=.35,alpha=.58)+
  geom_point(aes(colour=Method),position=position_jitter(width=.12,height=0,seed=20260928),size=1.1,alpha=.85)+
  geom_hline(yintercept=0,linewidth=.3,colour='#BDBDBD',linetype='dashed')+
  scale_fill_manual(values=pal[levels(d$Method)],guide='none')+
  scale_colour_manual(values=pal[levels(d$Method)],guide='none')+
  scale_y_continuous(limits=c(-.2,.5),breaks=c(-.2,0,.2,.4),labels=function(z)sprintf('%.1f',z))+
  labs(x='Method',y='Spearman correlation')+bf_theme(font)+theme(legend.position='none')
}
if(name=='scbasset') {
 p<-ggplot(d,aes(chromVAR,scBasset))+
  geom_abline(slope=1,intercept=0,colour=pal[['reference_line']],linewidth=.4,linetype='dashed')+
  geom_point(size=1.2,alpha=.72,colour=pal[['paired_TF']])+
  scale_x_continuous(limits=c(-1,1),breaks=seq(-1,1,.5),labels=function(z)sprintf('%.1f',z))+
  scale_y_continuous(limits=c(-1,1),breaks=seq(-1,1,.5),labels=function(z)sprintf('%.1f',z))+
  coord_fixed()+labs(x='chromVAR correlation',y='scBasset correlation')+bf_theme(font)+theme(legend.position='none')
}
if(name=='numbat') {
 d$modality<-factor(d$modality,levels=c('Expression','Alleles','Joint'))
 p<-ggplot(d,aes(CHROM,mean,colour=modality,linetype=modality,shape=modality))+
  geom_line(linewidth=.45)+geom_point(size=1.5,stroke=.4)+
  scale_colour_manual(values=pal[c('Expression','Alleles','Joint')],name=NULL)+
  scale_linetype_manual(values=c(Expression='dashed',Alleles='dotted',Joint='solid'),name=NULL)+
  scale_shape_manual(values=c(Expression=1,Alleles=2,Joint=16),name=NULL)+
  scale_x_continuous(breaks=1:22,labels=as.character(1:22))+
  scale_y_continuous(limits=c(0,1),breaks=seq(0,1,.25),labels=function(z)format(z,trim=TRUE,nsmall=2))+
  labs(x='Chromosome / called segment',y='Mean CNV posterior')+bf_theme(font)+theme(legend.position='bottom')
}
width<-design$output_size$width_mm;height<-design$output_size$height_mm
boxes<-data.frame(id=c('data','labels','legend'),x=c(30,1,30),y=c(4,4,height-14),w=c(width-36,27,width-36),h=c(height-30,height-30,10))
out<-file.path(work,paste0(files[[name]],'.png'))
bf_render_png(p,out,font,design$text_contract$allowed_text,width,height,width,c(spec,script,file.path(skill,'scripts/figure_style.R'),input),boxes,
 authorization=auth,skill_root=skill,publication_size_class=design$output_size$size_class)
grDevices::quartz(type='pdf',file=file.path(root,'results/figures',paste0(files[[name]],'.pdf')),width=width/25.4,height=height/25.4,family='Arial')
print(p);invisible(dev.off())
ggsave(file.path(work,paste0(files[[name]],'.svg')),p,device=svglite::svglite,width=width,height=height,units='mm',bg='white')
cat(name,'PANEL_RENDER_OK\n')
