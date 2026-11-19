# Independent colored redraw of exact author summary tables, not author plotting code.
library(ggplot2)
library(yaml)
a<-commandArgs(TRUE);stopifnot(length(a)==3);name<-a[1];preview<-normalizePath(a[2]);auth<-a[3]
script<-normalizePath(sub('^--file=','',grep('^--file=',commandArgs(),value=TRUE)))
root<-dirname(dirname(script));skill<-normalizePath(file.path(root,'../../../..'))
source(file.path(skill,'scripts/figure_style.R'));font<-bf_font('Arial')
spec<-file.path(root,'data/metadata',paste0(name,'-design-spec.yaml'));design<-read_yaml(spec)
input<-file.path(root,'results/plot_data',paste0(name,'.csv'));d<-read.csv(input,check.names=FALSE)
pal<-unlist(design$project_style_contract$semantic_colors)
if(name=='chromosome_length'){
 d$order<-as.integer(sub('Chr','',d$category));d<-d[order(d$order),]
 p<-ggplot(d,aes(factor(order,levels=1:22),value,fill=order))+
  geom_col(width=.7,colour=pal[['outline']],linewidth=.35)+
  scale_fill_gradient(low=pal[['chromosome_low']],high=pal[['chromosome_high']],guide='none')+
  scale_y_continuous(limits=c(0,70),breaks=seq(0,70,10),expand=expansion(mult=c(0,.02)))+
  labs(x='Chromosome',y='Length (Mb)')+bf_theme(font,7)+theme(legend.position='none')
}
if(name=='repeat_content'){
 d$category<-factor(d$category,levels=rev(c('DNA','LINE','SINE','LTR','Satellite','SSR','Unknown')))
 d$species<-factor(d$species,levels=c('P. glenii','N. hainanensis'))
 p<-ggplot(d,aes(category,value,fill=species))+
  geom_col(position=position_dodge(width=.75),width=.64,colour=pal[['outline']],linewidth=.35)+
  coord_flip()+scale_fill_manual(values=pal[c('P. glenii','N. hainanensis')],name=NULL)+
  scale_y_continuous(limits=c(0,14),breaks=seq(0,14,2),expand=expansion(mult=c(0,.02)))+
  labs(x='Repeat class',y='Genome covered (%)')+bf_theme(font,7)+
  theme(legend.position='bottom',legend.key.size=grid::unit(3,'mm'))
}
if(name=='expanded_family_counts'){
 # Sorted deterministically by descending count, then source family ID; display subset only.
 d<-d[order(-d$value,d$category),];d<-head(d,15);d$category<-factor(d$category,levels=rev(d$category))
 p<-ggplot(d,aes(category,value))+geom_col(width=.66,fill=pal[['family_count']],colour=pal[['outline']],linewidth=.35)+
  coord_flip()+scale_y_continuous(limits=c(0,85),breaks=c(0,25,50,75),expand=expansion(mult=c(0,.02)))+
  labs(x='Expanded family (top 15)',y='Genes listed in source')+bf_theme(font,7)+theme(legend.position='none')
}
w<-design$output_size$width_mm;h<-design$output_size$height_mm
boxes<-data.frame(id=c('data','labels','legend'),x=c(30,1,30),y=c(4,4,86),w=c(100,27,100),h=c(74,74,10))
files<-c(spec,script,file.path(skill,'scripts/figure_style.R'),input)
out<-file.path(preview,paste0(name,'.png'))
bf_render_png(p,out,font,design$text_contract$allowed_text,w,h,w,files,boxes,authorization=auth,skill_root=skill,publication_size_class=design$output_size$size_class)
grDevices::quartz(type='pdf',file=file.path(root,'results/figures',paste0(name,'.pdf')),width=w/25.4,height=h/25.4,family='Arial')
print(p);invisible(dev.off())
ggsave(file.path(preview,paste0(name,'.svg')),p,device=svglite::svglite,width=w,height=h,units='mm',bg='white')
cat('COLORED_SOURCE_TABLE_REDRAW_OK',name,'\n')
