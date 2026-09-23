options(warn=2)
suppressPackageStartupMessages({library(ggplot2);library(ComplexHeatmap);library(grid)})
source('scripts/figure_style.R')
out <- '../maintenance/2026-09-08'
font<-bf_font('Arial'); bf_complexheatmap_font(font); gp<-gpar(fontfamily=font$family,fontsize=7,col='black')
set.seed(20260908)
genes<-c('hsp70','hsp90','dnajb1','hspa5','sod1','cat','gpx1','prdx1','fasn','acaca','cpt1a','acox1','atg5','atg7','becn1','sqstm1','il1b','tnfa','nfkb1','stat3')
groups<-c('Control','Early stress','Late stress','Recovery')
samples<-paste(rep(c('C','E','L','R'),each=5),rep(1:5,4),sep='')
module<-rep(c('Chaperones','Redox','Lipid','Autophagy','Immune'),each=4)
profiles<-rbind(c(-.7,1.5,.8,-.3),c(-.6,.4,1.4,-.3),c(1,-.6,-1,.6),c(-.6,.3,1,.1),c(-.9,.2,1.4,-.3))
m<-matrix(rnorm(20*20,sd=.24),20,20)
for(i in 1:20) m[i,]<-m[i,]+rep(profiles[ceiling(i/4),],each=5)
m<-t(scale(t(m)));dimnames(m)<-list(genes,samples)
cols<-c('Control'='#486B89','Early stress'='#DFB56D','Late stress'='#A65C6F','Recovery'='#78A69B')
colfun<-circlize::colorRamp2(c(-2,-1,0,1,2),c('#244D7F','#8BBBD5','#FFFFFF','#B9A2CF','#624184'))
body<-bf_square_body(20,20,2.5,row_gaps_mm=rep(1.2,4),column_gaps_mm=rep(1.2,3))
ragg::agg_png(file.path(out,'heatmap.png'),width=108,height=78,units='mm',res=300,background='white')
ha<-HeatmapAnnotation(Group=factor(rep(groups,each=5),levels=groups),col=list(Group=cols),
  show_annotation_name=FALSE,simple_anno_size=unit(2,'mm'),annotation_legend_param=list(Group=list(title_gp=gp,labels_gp=gp,grid_height=unit(2.5,'mm'),grid_width=unit(2.5,'mm'))))
ht<-Heatmap(m,name='Row z-score',col=colfun,top_annotation=ha,
 row_split=factor(module,levels=unique(module)),column_split=factor(rep(groups,each=5),levels=groups),
 cluster_rows=TRUE,cluster_row_slices=FALSE,cluster_columns=FALSE,
 row_title=NULL,column_title=NULL,row_gap=unit(1.2,'mm'),column_gap=unit(1.2,'mm'),
 width=unit(body$width_mm,'mm'),height=unit(body$height_mm,'mm'),
 row_names_gp=gp,column_names_gp=gp,row_names_side='left',column_names_rot=bf_label_angle(samples,font,7,2.5),
 row_dend_side='right',row_dend_width=unit(6,'mm'),rect_gp=gpar(col='white',lwd=.3),
 heatmap_legend_param=list(title_gp=gp,labels_gp=gp,at=c(-2,-1,0,1,2),legend_height=unit(22,'mm'),border=NA))

draw(ht,heatmap_legend_side='right',annotation_legend_side='right',merge_legends=TRUE,padding=unit(c(3,3,3,3),'mm'))
dev.off()
font<-bf_font('Arial')
# Marker summaries are descriptive synthetic values, not a differential-expression test.
d<-expand.grid(Gene=genes,Group=groups,KEEP.OUT.ATTRS=FALSE)
d$Gene<-factor(d$Gene,levels=rev(genes)); d$Group<-factor(d$Group,levels=groups)
d$Module<-factor(rep(module,4),levels=unique(module))
d$Mean<-as.vector(sapply(1:4,function(j) tapply(m[,((j-1)*5+1):(j*5)],rep(1:20,5),mean)))
d$Detected<-pmin(.98,pmax(.04,plogis(d$Mean+.1+rnorm(nrow(d),sd=.25))))
p<-ggplot(d,aes(Group,Gene))+geom_point(aes(size=Detected,fill=Mean),shape=21,colour='black',stroke=.22)+
 facet_grid(Module~.,scales='free_y',space='free_y')+
 scale_fill_gradientn(colours=c('#244D7F','#8BBBD5','#FFFFFF','#B9A2CF','#624184'),limits=c(-2,2),breaks=c(-2,0,2),name='Mean z-score')+
 scale_size_area(max_size=3.7,limits=c(0,1),breaks=c(.25,.5,.75,1),labels=c('25','50','75','100'),name='Detected (%)')+
 scale_x_discrete(labels=c('Control','Early\nstress','Late\nstress','Recovery'),expand=expansion(add=.55))+scale_y_discrete(expand=expansion(add=.65))+
 labs(x=NULL,y=NULL)+bf_theme(font)+theme(axis.line=element_blank(),axis.ticks=element_blank(),strip.text=element_blank(),
 panel.spacing.y=unit(2,'mm'),legend.box.spacing=unit(3,'mm'))+
 guides(fill=guide_colourbar(order=1,barheight=unit(20,'mm'),barwidth=unit(2.5,'mm')),size=guide_legend(order=2))
allowed<-c(genes,'Control','Early\nstress','Late\nstress','Recovery','Mean z-score','Detected (%)','-2','0','2','25','50','75','100')
prepared<-bf_prepare(p,font,allowed,width_mm=82,height_mm=98)
bf_export_png(prepared,file.path(out,'dotplot.png'),82,98)
# Independent simulated experimental units, one endpoint, pre-specified control contrasts.
df<-data.frame(Group=factor(rep(groups,each=20),levels=groups),Value=exp(rnorm(80,rep(c(0,.48,.8,.2),each=20),.23)))
tests<-lapply(groups[-1],function(g) t.test(log(df$Value[df$Group==g]),log(df$Value[df$Group=='Control'])))
stats<-data.frame(comparison=paste(groups[-1],'vs Control'),p=sapply(tests,`[[`,'p.value'))
stats$p_adj<-p.adjust(stats$p,'holm'); stats$geometric_mean_ratio<-sapply(tests,function(t) exp(diff(rev(t$estimate)))); stats$ci_low<-sapply(tests,function(t) exp(t$conf.int[1])); stats$ci_high<-sapply(tests,function(t) exp(t$conf.int[2]));write.csv(stats,file.path(out,'statistics.csv'),row.names=FALSE)
stat_labels<-paste0('adj. P = ',formatC(stats$p_adj,format='g',digits=2))
stat_y<-max(df$Value)+.35
ann<-data.frame(Group=factor(groups[-1],levels=groups),y=rep(stat_y,3),label=stat_labels)
p2<-ggplot(df,aes(Group,Value))+geom_violin(aes(fill=Group),width=.72,linewidth=.28,alpha=.32,trim=TRUE)+
 geom_boxplot(width=.16,fill='white',outlier.shape=NA,linewidth=.32)+
 geom_point(aes(fill=Group),shape=21,stroke=.2,size=1.45,position=position_jitter(width=.10,seed=413))+
 geom_text(data=ann,aes(Group,y,label=label),inherit.aes=FALSE,family=font$family,size=7/ggplot2::.pt)+
 scale_fill_manual(values=cols,guide='none')+scale_y_continuous(breaks=0:4,limits=c(0,stat_y+.35),expand=expansion(mult=c(0,.015)))+
 labs(x=NULL,y='Relative abundance')+bf_theme(font)
prepared2<-bf_prepare(p2,font,c(groups,'Relative abundance',as.character(0:4),stat_labels),width_mm=110,height_mm=75)
bf_export_png(prepared2,file.path(out,'distribution.png'),110,75)
svglite::svglite(file.path(out,'heatmap.svg'),width=108/25.4,height=78/25.4,bg='white')
draw(ht,heatmap_legend_side='right',annotation_legend_side='right',merge_legends=TRUE,padding=unit(c(3,3,3,3),'mm'));dev.off()
svglite::svglite(file.path(out,'dotplot.svg'),width=82/25.4,height=98/25.4,bg='white')
grid.draw(prepared$grob);dev.off()
writeLines(capture.output(sessionInfo()),file.path(out,'session-info.txt'))
cat('RENDER_CHECKS_OK\n')
