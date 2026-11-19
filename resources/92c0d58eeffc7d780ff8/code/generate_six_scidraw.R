#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(ggplot2); library(dplyr); library(tidyr); library(patchwork)
  library(vegan); library(ggtern); library(corrplot); library(ggnewscale)
  library(circlize); library(ggrepel); library(ragg)
})
source('scripts/figure_style.R')
font_info <- bf_font('Arial')
set.seed(8012)
graphics.off()
dir.create('results/figures',recursive=TRUE,showWarnings=FALSE)
dir.create('results/plot_data',recursive=TRUE,showWarnings=FALSE)
font <- 'Arial'
theme_pub <- function(size=9) theme_classic(base_size=size,base_family=font)+theme(text=element_text(family=font,color='black'),axis.line=element_line(linewidth=.35),axis.ticks=element_line(linewidth=.35),legend.key.size=unit(3,'mm'),legend.text=element_text(size=size-.5),legend.title=element_text(size=size),plot.margin=margin(4,4,4,4,'mm'))
save_plot <- function(name,p,w,h,allowed){
  path<-file.path('results/figures',paste0(name,'.png'))
  boxes<-data.frame(id=c('labels','data','legend'),x=c(0,.16*w,.82*w),y=c(0,0,0),w=c(.14*w,.64*w,.16*w),h=c(h,h,h))
  bf_render_png(p,path,font_info,unique(as.character(allowed)),w,h,w,
    c(normalizePath('scripts/generate_six_scidraw.R'),normalizePath('scripts/figure_style.R'),normalizePath('data/metadata/design-spec.yaml')),boxes,dpi=300)
}

save_plot_raw <- function(name,p,w,h){ragg::agg_png(file.path('results/figures',paste0(name,'.png')),width=w,height=h,units='mm',res=300,background='white');print(p);dev.off()}

# 1 PCoA with aligned marginal boxplots
set.seed(8101)
n<-36; groups<-factor(rep(c('Control','Diet A','Diet B'),each=12)); taxa<-matrix(rgamma(n*30,2),n)
taxa[groups=='Diet A',1:7]<-taxa[groups=='Diet A',1:7]*1.8;taxa[groups=='Diet B',8:14]<-taxa[groups=='Diet B',8:14]*2
dist<-vegdist(taxa,'bray');ord<-cmdscale(dist,k=2,eig=TRUE);pc<-100*ord$eig[1:2]/sum(abs(ord$eig));d<-data.frame(sample=sprintf('S%02d',1:n),group=groups,PCo1=ord$points[,1],PCo2=ord$points[,2]);write.csv(d,'results/plot_data/pcoa_marginal.csv',row.names=FALSE)
perm<-vegan::adonis2(dist~groups,permutations=999);perm_label<-sprintf('PERMANOVA\nR² = %.3f\nP = %.3f',perm$R2[1],perm$`Pr(>F)`[1])
cols<-c('Control'='#3F78A8','Diet A'='#E07A5F','Diet B'='#58A37B')
main<-ggplot(d,aes(PCo1,PCo2,color=group,shape=group))+stat_ellipse(linewidth=.55,show.legend=FALSE)+geom_point(size=2.3,alpha=.9)+scale_color_manual(values=cols,name='Group')+scale_shape_manual(values=c(16,17,15),name='Group')+labs(x=sprintf('PCo1 (%.1f%%)',pc[1]),y=sprintf('PCo2 (%.1f%%)',pc[2]))+theme_pub(9)
top<-ggplot(d,aes(PCo1,group,fill=group))+geom_boxplot(orientation='y',width=.58,outlier.shape=NA,linewidth=.35,show.legend=FALSE)+geom_point(position=position_jitter(height=.08),size=.65,show.legend=FALSE)+scale_fill_manual(values=cols,guide='none')+scale_x_continuous(limits=range(d$PCo1)*1.08)+labs(x=NULL,y=NULL)+theme_pub(8)+theme(legend.position='none',axis.text=element_blank(),axis.ticks=element_blank())
right<-ggplot(d,aes(group,PCo2,fill=group))+geom_boxplot(width=.58,outlier.shape=NA,linewidth=.35,show.legend=FALSE)+geom_point(position=position_jitter(width=.08),size=.65,show.legend=FALSE)+scale_fill_manual(values=cols,guide='none')+scale_y_continuous(limits=range(d$PCo2)*1.08)+labs(x=NULL,y=NULL)+theme_pub(8)+theme(legend.position='none',axis.text=element_blank(),axis.ticks=element_blank())
stats<-ggplot()+annotate('text',x=0,y=0,label=perm_label,family=font,size=2.7,lineheight=.95)+xlim(-1,1)+ylim(-1,1)+theme_void(base_family=font)+theme(panel.border=element_rect(colour='#444444',fill=NA,linewidth=.35))
pcoa_comp<-(top+stats)/(main+right)+plot_layout(widths=c(4,1.15),heights=c(1.15,4),guides='collect')&theme(legend.position='bottom')
save_plot_raw('01_pcoa_marginal',pcoa_comp,165,135)

# 2 Ternary cell-state composition: three time panels, shared stage encoding
set.seed(8102)
cell<-bind_rows(lapply(c('0 h','60 h','36 h post'),function(tp)bind_rows(lapply(c('Early','Intermediate','Late'),function(g){x<-matrix(rexp(36),12,3);x<-x/rowSums(x);bias<-switch(g,Early=c(.55,.10,.05),Intermediate=c(.10,.50,.10),Late=c(.05,.10,.55));if(tp=='60 h')bias<-bias[c(2,3,1)];if(tp=='36 h post')bias<-bias[c(3,1,2)];x<-sweep(x,2,bias,'+');x<-x/rowSums(x);data.frame(time=tp,stage=g,EPI=x[,1],TE=x[,2],PrE=x[,3])}))));write.csv(cell,'results/plot_data/ternary_cell_state.csv',row.names=FALSE)
tern_panel<-function(tp){ggtern(filter(cell,time==tp),aes(EPI,TE,PrE,color=stage,shape=stage))+geom_mask()+geom_Tline(Tintercept=seq(.2,.8,.2),colour='#B9C6D2',linetype=2,linewidth=.28)+geom_Lline(Lintercept=seq(.2,.8,.2),colour='#B9C6D2',linetype=2,linewidth=.28)+geom_Rline(Rintercept=seq(.2,.8,.2),colour='#B9C6D2',linetype=2,linewidth=.28)+geom_point(size=2.05,alpha=.88,stroke=.58)+scale_color_manual(values=c(Early='#377EB8',Intermediate='#4DAF4A',Late='#F28E49'),name='Stage')+scale_shape_manual(values=c(Early=17,Intermediate=16,Late=15),name='Stage')+labs(title=tp)+theme_rgbg(base_size=9,base_family=font)+theme(text=element_text(family=font),plot.title=element_text(hjust=.5,face='bold',size=9),tern.axis.title=element_text(size=8,face='bold'),tern.axis.text=element_text(size=6.5),tern.panel.background=element_rect(fill='white',colour=NA),panel.background=element_rect(fill='white',colour=NA),plot.background=element_rect(fill='white',colour=NA),legend.position='none')}
p<-tern_panel('0 h')+tern_panel('60 h')+tern_panel('36 h post')+plot_layout(guides='collect')&theme(legend.position='bottom')
save_plot_raw('02_ternary_cell_state',p,180,82)

# 3 Dense triangular correlation matrix with category-colored labels
set.seed(8103)
pvars<-c(paste0('MAG_',1:8),paste0('Water_',1:7),paste0('Soil_',1:7),paste0('Function_',1:6));types<-rep(c('MAG','Hydrology','Soil','Function'),c(8,7,7,6));z<-matrix(rnorm(110*length(pvars)),110,length(pvars),dimnames=list(NULL,pvars));for(i in 2:ncol(z))z[,i]<-.28*z[,max(1,i-1)]+rnorm(110,0,.85);cm<-cor(z);write.csv(cm,'results/plot_data/correlation_matrix.csv')
ragg::agg_png('results/figures/03_correlation_heatmap.png',width=165,height=145,units='mm',res=300,background='white');par(family=font,mar=c(1,2,2,2));corrplot(cm,method='square',type='upper',order='original',col=colorRampPalette(c('#9B1D5A','#F7F4EF','#2C7FB8'))(120),tl.col=c('#6A2C91','#1FB7C9','#E68A28','#3656A6')[match(types,unique(types))],tl.cex=.70,tl.srt=55,tl.pos='td',cl.pos='b',cl.cex=.75,diag=TRUE,addgrid.col='#E1E1E1');dev.off()

# 4 Patient swimmer with multiple fill scales
set.seed(8104)
pat<-data.frame(patient=factor(sprintf('P%02d',1:28),levels=sprintf('P%02d',28:1)),duration=sort(runif(28,10,84)),treatment=sample(c('CDK4/6i','PARPi'),28,TRUE),response=sample(c('CR','PR','SD'),28,TRUE),response_time=runif(28,2,14),status=sample(c('Progression','Ongoing'),28,TRUE),line=sample(c('1','2','>2'),28,TRUE),brca=sample(c('LOH','No LOH'),28,TRUE),prior=sample(c('Yes','No'),28,TRUE),endocrine=sample(c('Sensitive','Resistant'),28,TRUE))
pat$has_second<-pat$duration>24;pat$first_end<-ifelse(pat$has_second,pat$duration*runif(28,.30,.58),pat$duration);pat$second_start<-pmin(pat$first_end+runif(28,1.2,3.2),pat$duration);pat$second_treatment<-ifelse(pat$treatment=='CDK4/6i','PARPi','CDK4/6i')
segments<-bind_rows(transmute(pat,patient,start=0,end=first_end,treatment),transmute(filter(pat,has_second),patient,start=second_start,end=duration,treatment=second_treatment));gaps<-filter(pat,has_second)
write.csv(pat,'results/plot_data/patient_swimmer.csv',row.names=FALSE)
p<-ggplot(pat,aes(y=patient))+geom_segment(data=gaps,aes(x=first_end,xend=second_start,yend=patient),colour='#C9C9C9',linewidth=2.65,lineend='butt')+geom_segment(data=segments,aes(x=start,xend=end,y=patient,yend=patient,color=treatment),inherit.aes=FALSE,linewidth=2.65,lineend='butt')+scale_color_manual(values=c('CDK4/6i'='#E56B6F','PARPi'='#5E88B7'),name='Treatment')+ggnewscale::new_scale_color()+geom_point(aes(x=response_time,color=response),size=1.8)+scale_color_manual(values=c(CR='#204E5F',PR='#6FA4B8',SD='#C2CDD2'),name='Best response')+geom_point(aes(x=duration,shape=status),size=1.8)+scale_shape_manual(values=c(Progression=18,Ongoing=16),name='Status')+geom_segment(data=filter(pat,status=='Ongoing'),aes(x=duration,xend=duration+2.5,yend=patient),arrow=arrow(length=unit(1.1,'mm')),linewidth=.35)+geom_point(aes(x=-14,fill=line),shape=22,size=2.25)+scale_fill_manual(values=c('1'='#D7EAF2','2'='#7FB4C9','>2'='#1F6E83'),name='Line')+ggnewscale::new_scale_fill()+geom_point(aes(x=-10,fill=brca),shape=22,size=2.25)+scale_fill_manual(values=c(LOH='#E783AE','No LOH'='#F5C7DD'),name='BRCA2')+ggnewscale::new_scale_fill()+geom_point(aes(x=-6,fill=prior),shape=22,size=2.25)+scale_fill_manual(values=c(Yes='#73B99A',No='#E8F1EC'),name='Prior platinum')+ggnewscale::new_scale_fill()+geom_point(aes(x=-2,fill=endocrine),shape=22,size=2.25)+scale_fill_manual(values=c(Sensitive='#E9C46A',Resistant='#A44A3F'),name='Endocrine')+annotate('text',x=c(-14,-10,-6,-2),y=29.2,label=c('Line','BRCA2','Prior','Endocrine'),angle=55,size=2.9,hjust=0,family=font)+scale_x_continuous('Time (months)',breaks=seq(0,84,12),limits=c(-17,90))+labs(y=NULL)+theme_pub(9)+theme(legend.position='right',legend.box='vertical',legend.text=element_text(size=6.8),legend.title=element_text(size=7.2),plot.margin=margin(8,3,3,3,'mm'))
save_plot('04_patient_swimmer',p,220,170,c('Time (months)','Treatment','CDK4/6i','PARPi','Best response','CR','PR','SD','Status','Progression','Ongoing','Line','1','2','>2','BRCA2','Prior','Prior platinum','Endocrine','Yes','No','LOH','No LOH','Sensitive','Resistant',sprintf('P%02d',1:28),as.character(seq(0,84,12))))

# 5 Chord diagram with outer quantitative track
set.seed(8105)
regions<-paste0('Region_',sprintf('%02d',1:12));drivers<-paste0('Driver_',sprintf('%02d',1:10));m<-matrix(sample(0:14,length(regions)*length(drivers),TRUE),nrow=length(regions),dimnames=list(regions,drivers));write.csv(m,'results/plot_data/chord_links.csv')
alln<-c(regions,drivers);gridcols<-setNames(c(colorRampPalette(c('#2F7EBB','#65C2A5'))(12),colorRampPalette(c('#E6B84A','#A64B8C'))(10)),alln)
ragg::agg_png('results/figures/05_chord_outer_track.png',width=170,height=170,units='mm',res=300,background='white')
par(family=font);circos.clear();circos.par(start.degree=88,gap.degree=c(rep(1.2,length(alln)-1),7),track.margin=c(.002,.002))
chordDiagram(m,grid.col=gridcols,transparency=.55,annotationTrack='grid',preAllocateTracks=list(track.height=.23))
circos.trackPlotRegion(track.index=1,ylim=c(0,1.52),bg.border=NA,panel.fun=function(x,y){
  sn<-CELL_META$sector.index;val<-if(sn%in%regions) sum(m[sn,]) else sum(m[,sn]);scaled<-val/max(c(rowSums(m),colSums(m)))
  cuts<-base::seq(CELL_META$xlim[1],CELL_META$xlim[2],length.out=7)
  phase<-match(sn,alln)/3;profile<-pmin(1.35,scaled*(.72+.28*sin(seq_len(6)+phase)))
  for(k in seq_len(6)) circos.rect(cuts[k],0,cuts[k+1],profile[k],col=adjustcolor(gridcols[sn],alpha.f=.9),border='white',lwd=.35)
  circos.segments(CELL_META$xlim[1],1.07,CELL_META$xlim[2],1.07,col='#424242',lwd=.45)
  circos.text(CELL_META$xcenter,1.34,sn,facing='clockwise',niceFacing=TRUE,adj=c(0,.5),cex=.56)
})
legend(x=-1.58,y=1.48,legend=c('Regions','Drivers'),fill=c('#4699A9','#C27B76'),border=NA,bty='n',cex=.68,title='Outer track')
circos.clear();dev.off()

# 6 Volcano with gene-set score tracks
set.seed(8106)
ng<-1800;vol<-data.frame(gene=paste0('G',1:ng),log2FC=rnorm(ng,0,1));vol$FDR<-p.adjust(2*pnorm(-abs(vol$log2FC*2+rnorm(ng))),method='BH');vol$set<-sample(c('Other','KRAS UP','KRAS DN'),ng,TRUE,prob=c(.91,.045,.045));siggenes<-c('KRAS','MYC','FOSL1');ix<-order(vol$FDR)[1:3];vol$gene[ix]<-siggenes;vol$log2FC[ix]<-c(-1.8,1.65,2.15);vol$FDR[ix]<-c(2e-6,5e-6,1e-5);vol$set[ix]<-'Signature';write.csv(vol,'results/plot_data/volcano_gsea.csv',row.names=FALSE)
track<-filter(vol,set%in%c('KRAS UP','KRAS DN'));track$y0<-ifelse(track$set=='KRAS UP',-.55,-1.15)
p<-ggplot(vol,aes(log2FC,-log10(FDR)))+
  annotate('rect',xmin=-3,xmax=-.5,ymin=-log10(.05),ymax=7,fill='#DCE8F3')+
  annotate('rect',xmin=.5,xmax=3,ymin=-log10(.05),ymax=7,fill='#E4EDC7')+
  geom_hline(yintercept=-log10(.05),linetype=3,colour='#8A8A8A',linewidth=.4)+
  geom_vline(xintercept=c(-.5,.5),linetype=3,colour='#8A8A8A',linewidth=.4)+
  geom_point(shape=21,size=.85,stroke=.25,alpha=.32,fill='white')+
  geom_point(data=filter(vol,set!='Other'),aes(fill=set),shape=21,size=1.4,stroke=.35)+
  geom_label_repel(data=filter(vol,set=='Signature'),aes(label=gene),family=font,size=2.7,box.padding=.35,min.segment.length=0,max.overlaps=Inf)+
  geom_linerange(data=track,aes(ymin=y0-.22,ymax=y0+.22,color=set),linewidth=.22)+
  annotate('text',x=-1.75,y=7.35,label='KRAS UP',family=font,size=3.0,colour='#3F78A8',fontface='bold')+
  annotate('text',x=1.25,y=7.35,label='KRAS DN',family=font,size=3.0,colour='#71913A',fontface='bold')+
  annotate('text',x=c(-2.45,2.45),y=6.85,label='Top-ranked',family=font,size=2.5)+
  annotate('text',x=-2.95,y=c(-.55,-1.15),label=c('KRAS UP','KRAS DN'),family=font,size=2.5,hjust=0,colour=c('#D19A00','#777777'))+
  scale_fill_manual(values=c('KRAS UP'='#E3B43A','KRAS DN'='#9E9E9E','Signature'='#24BFC8'),guide='none')+
  scale_color_manual(values=c('KRAS UP'='#E3B43A','KRAS DN'='#9E9E9E'),guide='none')+
  scale_x_continuous('Treatment vs control (log2FC)',breaks=-3:3)+
  scale_y_continuous('Significance (-log10 FDR)',breaks=c(0,2,4,6))+
  coord_cartesian(xlim=c(-3,3),ylim=c(-1.6,7.7),clip='off')+theme_pub(9)+theme(plot.margin=margin(3,4,4,5,'mm'))
save_plot('06_volcano_gsea',p,135,115,c('Treatment vs control (log2FC)','Significance (-log10 FDR)','KRAS UP','KRAS DN','Top-ranked','KRAS','MYC','FOSL1',as.character(-3:7)))
if(file.exists('Rplots.pdf')) unlink('Rplots.pdf')
cat('SIX_SCIDRAW_PNG_OK\n')
