suppressPackageStartupMessages({library(readxl);library(ggplot2);library(patchwork);library(rstatix)})
source <- 'work/2026-10-29-journal-bulk-four/sources/reverse-SourceDataFig3.xlsx'
out <- 'results/plot_data/nature_reverse_metabolomics_fig3a_20261029'
x <- as.data.frame(read_excel(source,sheet='Fig. 3a'))
stopifnot(nrow(x)==32760,all(c('Abundance','Abundance_0_adj','Diagnosis','Compound','Method','Sample')%in%names(x)))
x <- x[x$Method!='HILIC-pos',]
x$AA <- sub('-.*','',x$Compound);x$Core<-sub('^[^-]+-','',x$Compound)
chosen <- c('Glu','Ile/Leu','Met','Phe','Trp','Tyr');x<-x[x$AA%in%chosen,]
x$Diagnosis<-factor(x$Diagnosis,levels=c('nonIBD','CD','UC'))
axis_top<-c(Glu=3e6,`Ile/Leu`=5e5,Met=1e6,Phe=5e6,Trp=5e5,Tyr=8e5)
axis_step<-c(Glu=1e6,`Ile/Leu`=1e5,Met=2.5e5,Phe=1e6,Trp=1e5,Tyr=2e5)
x$within_source_axis<-x$Abundance<=axis_top[x$AA]
stopifnot(nrow(x)>7000,!anyNA(x$Abundance),all(x$Abundance>=0))
write.csv(x,paste0(out,'_plot_data.csv'),row.names=FALSE)
write.csv(data.frame(AA=chosen,axis_top=axis_top[chosen],observations=as.integer(table(factor(x$AA,levels=chosen))),outside_axis=vapply(chosen,function(a)sum(x$AA==a & !x$within_source_axis),integer(1))),paste0(out,'_axis_scope.csv'),row.names=FALSE)
# Match author code: pairwise Wilcoxon on zero-adjusted abundance, BH within each amino-acid/bile-core group.
stats <- do.call(rbind,lapply(split(x,interaction(x$AA,x$Core,drop=TRUE)),function(z){
 if(length(unique(z$Diagnosis))<3)return(NULL)
 q<-rstatix::pairwise_wilcox_test(z,Abundance_0_adj~Diagnosis,p.adjust.method='BH')
 data.frame(AA=z$AA[1],Core=z$Core[1],q[,c('group1','group2','p','p.adj')])
}))
write.csv(stats,paste0(out,'_pairwise_wilcox.csv'),row.names=FALSE)
cols<-c(CD='#C96A7E',nonIBD='#7198B6',UC='#4B9B91')
plots<-lapply(chosen,function(a){
 z<-x[x$AA==a,];cores<-unique(z$Core);z$Core<-factor(z$Core,levels=cores)
 sig<-stats[stats$AA==a & stats$p.adj<.05,]
 ymax<-axis_top[[a]]
 if(nrow(sig)){
   sig$core_x<-match(sig$Core,cores)
   offsets<-c(nonIBD=-.24,CD=0,UC=.24)
   sig$xmin<-sig$core_x+offsets[sig$group1]
   sig$xmax<-sig$core_x+offsets[sig$group2]
   sig$level<-ave(seq_len(nrow(sig)),sig$Core,FUN=seq_along)
   sig$y<-ymax*(.91+.045*sig$level)
   sig$label<-ifelse(sig$p.adj<1e-4,'****',ifelse(sig$p.adj<1e-3,'***',ifelse(sig$p.adj<.01,'**','*')))
 }
 plot<-ggplot(z,aes(x=Core,y=Abundance,fill=Diagnosis,color=Diagnosis))+geom_boxplot(position=position_dodge2(width=.72,preserve='single'),width=.64,outlier.shape=NA,linewidth=.38,alpha=.72)+geom_point(data=z[z$within_source_axis,],position=position_jitterdodge(jitter.width=.21,dodge.width=.72,seed=101),size=.30,alpha=.34,stroke=0)
 if(nrow(sig)) plot<-plot+geom_segment(data=sig,aes(x=xmin,xend=xmax,y=y,yend=y),inherit.aes=FALSE,linewidth=.28,color='#38424A')+geom_text(data=sig,aes(x=(xmin+xmax)/2,y=y+ymax*.022,label=label),inherit.aes=FALSE,size=2.1,color='#38424A')
 plot+scale_fill_manual(values=cols)+scale_color_manual(values=cols)+scale_y_continuous(breaks=seq(0,ymax,by=axis_step[[a]]),labels=scales::label_scientific(digits=2),expand=expansion(mult=c(.01,.01)))+coord_cartesian(ylim=c(0,ymax*1.1))+labs(title=a,x=NULL,y=if(a%in%c('Glu','Phe'))'Peak area' else NULL)+theme_classic(base_size=8,base_family='sans')+theme(plot.title=element_text(hjust=.5,face='bold',size=11),axis.text.x=element_text(angle=45,hjust=1,size=7),axis.title.y=element_text(size=9),legend.position='bottom',plot.margin=margin(6,7,7,7))
})
p<-wrap_plots(plots,ncol=3,guides='collect')&theme(legend.position='bottom',legend.title=element_blank(),legend.text=element_text(size=8))
ggsave('results/figures/nature_reverse_metabolomics_fig3a_20261029.pdf',p,width=205,height=155,units='mm',device='pdf')
ggsave('results/figures/nature_reverse_metabolomics_fig3a_20261029.png',p,width=205,height=155,units='mm',dpi=300,bg='white')
cat('rows',nrow(x),'stats',nrow(stats),'\n')
