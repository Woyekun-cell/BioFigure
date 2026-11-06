make_plot<-function(P){
 C<-file.path(P,'biofigure/benchmark/library/single-cell/fleck-gli3-circular-20261028');W<-file.path(P,'work/2026-10-28-batch-six/fleck');z<-readRDS(file.path(W,'computed.rds'))
 suppressPackageStartupMessages({library(ggraph);library(ggplot2);library(grid)})
 ggraph(z$layout)+
  geom_edge_diagonal(aes(colour=sign(estimate)),linewidth=.36,alpha=.77,show.legend=TRUE)+
  scale_edge_colour_gradientn(colours=c('#B16D8C','#4D99A5'),limits=c(-1,1),breaks=c(-1,1),labels=c('Repressing','Activating'),name='GRN interactions',guide='legend')+
  geom_node_point(size=1.2,shape=21,stroke=.22,colour='#5F6569',fill='#D6DADB')+
  geom_node_point(aes(filter=root),size=7,shape=21,stroke=.25,colour='#737D80',fill='#EEF1F1')+
  geom_node_text(aes(label=name,filter=root),family='Arial',size=7.2/.pt,colour='#3B4246')+
  geom_node_label(aes(label=name,filter=is_tf&!root),family='Arial',size=7.2/.pt,fontface='italic',label.padding=unit(.17,'mm'),label.r=unit(.7,'mm'),label.size=.12,colour='#3B4246',fill='white',repel=TRUE,seed=20261028,force=.8,max.overlaps=Inf,min.segment.length=0,segment.colour='#A0A5A6',segment.size=.15)+
  scale_x_continuous(limits=c(-1.25,1.25),expand=c(0,0))+
  scale_y_continuous(limits=c(-1.25,1.25),expand=c(0,0),transform='reverse')+
  coord_flip(clip='off')+theme_void(base_family='Arial',base_size=7.2)+theme(aspect.ratio=1,plot.margin=margin(2,2,2,2,'mm'),legend.position='bottom',legend.title=element_text(size=7.2),legend.text=element_text(size=7.2),legend.key.width=unit(8,'mm'),legend.spacing.x=unit(1.5,'mm'))
}
