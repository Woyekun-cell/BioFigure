suppressPackageStartupMessages({library(ggplot2);library(ggrepel);library(ggpubr);library(circlize);library(ragg);library(dplyr)})
source('scripts/figure_style.R')
font <- bf_font('Arial'); bf_complexheatmap_font(font)
set.seed(20260915)
for (p in c('results/figures','results/plot_data','results/tables')) dir.create(p,recursive=TRUE,showWarnings=FALSE)
writeLines(capture.output(sessionInfo()),'results/tables/sessionInfo.txt')
writeLines('All observations and effect estimates are simulated. Source code was inspected before writing this script; this is not a blind-generation benchmark.','results/tables/data-origin.txt')

# Two conditions joined by unique gene identifier. Simulation defines effect-estimate SE.
n <- 2600
state <- sample(c('background','up','down','discordant'),n,replace=TRUE,prob=c(.82,.075,.075,.03))
a <- rnorm(n,0,.37); b <- .8*a+rnorm(n,0,.53)
i<-state=='up';a[i]<-rnorm(sum(i),1.30,.45);b[i]<-rnorm(sum(i),2.45,.85)
i<-state=='down';a[i]<-rnorm(sum(i),-1.35,.42);b[i]<-rnorm(sum(i),-2.55,.86)
i<-state=='discordant';a[i]<-rnorm(sum(i),1.2,.5);b[i]<-rnorm(sum(i),-1.8,.6)
left<-data.frame(gene_id=sprintf('Gene%04d',1:n),a,se_a=runif(n,.18,.55))
right<-data.frame(gene_id=left$gene_id,b,se_b=runif(n,.23,.7));right<-right[sample(n),]
d<-merge(left,right,by='gene_id',sort=FALSE)
stopifnot(!anyDuplicated(d$gene_id),nrow(d)==n,all(is.finite(d$a)),all(is.finite(d$b)))
d$qa<-p.adjust(2*pnorm(-abs(d$a/d$se_a)),method='BH');d$qb<-p.adjust(2*pnorm(-abs(d$b/d$se_b)),method='BH')
choose_extreme <- function(value,q,direction){ix<-which(q<.01 & value*direction>0); head(ix[order(-direction*value[ix])],100)}
up<-unique(c(choose_extreme(d$a,d$qa,1),choose_extreme(d$b,d$qb,1)))
down<-unique(c(choose_extreme(d$a,d$qa,-1),choose_extreme(d$b,d$qb,-1)))
d$class<-'Other';d$class[up]<-'Up';d$class[down]<-'Down';d$class[union(up,down)[d$a[union(up,down)]*d$b[union(up,down)]<0]]<-'Discordant'
select_labels<-unique(c(head(up[order(-d$b[up])],7),head(down[order(d$b[down])],7),head(up[order(-d$a[up])],3),head(down[order(d$a[down])],3)))
d$label<-ifelse(seq_len(n)%in%select_labels,d$gene_id,'')
d$size_score<-pmin(10,-log10(pmax(d$qa,1e-300)));d$alpha_score<-pmin(10,-log10(pmax(d$qb,1e-300)))
lab<-d[d$label!='',];lab<-lab[order(lab$b),]
lab$target_y<-lab$b
for(side in c(-1,1)){ix<-which(sign(lab$a)==side);if(length(ix)>1)for(j in 2:length(ix))lab$target_y[ix[j]]<-max(lab$target_y[ix[j]],lab$target_y[ix[j-1]]+.40)}
for(side in c(-1,1)){ix<-which(sign(lab$a)==side);lab$target_y[ix]<-lab$target_y[ix]-max(0,max(lab$target_y[ix])-5.6)}
p<-ggplot(d,aes(a,b))+geom_hline(yintercept=0,colour='#A0A0A0',linewidth=.35)+geom_vline(xintercept=0,colour='#A0A0A0',linewidth=.35)+
 geom_point(data=d[d$class=='Other',],size=.55,alpha=.14,colour='#333333')+
 geom_point(data=d[d$class!='Other',],aes(fill=class,size=size_score,alpha=alpha_score),shape=21,colour='#555555',stroke=.18)+
 scale_fill_manual(values=c(Up='#CB181D',Down='#2171B5',Discordant='#C6A58B'))+scale_size(range=c(1.2,3.1))+scale_alpha(range=c(.28,.8))+
 geom_text_repel(data=lab,aes(label=label),nudge_x=ifelse(lab$a<0,-2.9,2.9)-lab$a,nudge_y=lab$target_y-lab$b,direction='y',hjust=ifelse(lab$a<0,1,0),force=.05,force_pull=10,family=font$family,fontface='italic',size=2.7,seed=61,box.padding=.12,point.padding=.1,max.overlaps=Inf,max.time=.5,min.segment.length=0,segment.size=.16,segment.color='#777777',colour='#161616')+
 scale_x_continuous(breaks=seq(-4,4,2),limits=c(-3.7,3.7))+scale_y_continuous(breaks=seq(-6,6,2),limits=c(-6,6))+
 labs(x='Condition A vs control (log2FC)',y='Condition B vs control (log2FC)')+
 theme_bw(base_size=10,base_family=font$family)+theme(text=element_text(family=font$family),legend.position='none',panel.grid.minor=element_blank(),panel.grid.major=element_line(colour='#E9E9E9',linewidth=.3),plot.margin=margin(8,8,8,8))
allowed<-c(d$gene_id,as.character(seq(-6,6,2)),'Condition A vs control (log2FC)','Condition B vs control (log2FC)')
boxes<-data.frame(id=c('data','labels','legend'),x=c(20,0,150),y=c(8,8,0),w=c(125,18,10),h=c(132,132,6))
bf_render_png(p,'results/figures/logfc.png',font,allowed,160,160,160,c('scripts/draw_three.R','scripts/figure_style.R','design-spec.yaml'),boxes)
write.csv(d,'results/plot_data/logfc.csv',row.names=FALSE)

# Four independent groups; each simulated mouse is an experimental unit.
types<-c('DC','cDC','cDC1','cDC2','pDC','mDC','CD11b+','rDC')
groups<-c('GF mock','SPF mock','GF PCV13','SPF PCV13')
mu<-c(1100,1650,1050,1700,140,3500,4000,560);eff<-c(480,1050,100,90,220,950,120,400)
z<-expand.grid(mouse=1:6,group=groups,cell=types,KEEP.OUT.ATTRS=FALSE)
z$group<-factor(z$group,levels=groups);z$cell<-factor(z$cell,levels=types)
z$value<-vapply(seq_len(nrow(z)),function(i){k<-as.integer(z$cell[i]);g<-as.integer(z$group[i]);rnorm(1,mu[k]+c(0,180,-80,eff[k])[g],max(35,mu[k]*.13))},numeric(1));z$value<-pmax(z$value,1)
z$id<-paste(z$group,z$mouse,sep='_')
z$x<-as.integer(z$cell)+(as.integer(z$group)-2.5)*.19
st<-do.call(rbind,lapply(seq_along(types),function(k){v<-z[z$cell==types[k],];tt<-t.test(v$value[v$group=='GF PCV13'],v$value[v$group=='SPF PCV13']);data.frame(cell=types[k],p=tt$p.value,xmin=k+.095,xmax=k+.285,y.position=max(v$value)+330)}))
st$group1<-'GF PCV13';st$group2<-'SPF PCV13'
st$q<-p.adjust(st$p,'BH');st$label<-ifelse(st$q<.001,'***',ifelse(st$q<.01,'**',ifelse(st$q<.05,'*','ns')))
p2<-ggplot(z,aes(x,value,colour=group,shape=group))+geom_vline(xintercept=seq(1.5,7.5),linetype='dotted',linewidth=.45,colour='#777777')+
 geom_point(size=2.4,stroke=.75)+scale_shape_manual(values=c(1,1,16,16))+scale_colour_manual(values=c('#3853A2','#31B24C','#3853A2','#31B24C'))+
 scale_x_continuous(breaks=1:8,labels=types,limits=c(.5,8.5),expand=c(0,0))+scale_y_continuous(breaks=c(0,2000,4000,6000),labels=c('0','2,000','4,000','6,000'),limits=c(0,6200),expand=c(0,0))+
 ggpubr::stat_pvalue_manual(st,label='label',xmin='xmin',xmax='xmax',y.position='y.position',tip.length=.006,bracket.size=.3,size=3,family=font$family,inherit.aes=FALSE)+
 labs(x=NULL,y='CD86 MFI',colour=NULL,shape=NULL)+theme_classic(base_size=10,base_family=font$family)+theme(text=element_text(family=font$family),axis.text.x=element_text(angle=45,hjust=1),legend.position='right',legend.key.height=grid::unit(5,'mm'),plot.margin=margin(8,8,8,8))
allowed2<-c(types,groups,'0','2,000','4,000','6,000','CD86 MFI','ns','*','**','***')
boxes2<-data.frame(id=c('data','labels','legend'),x=c(22,0,172),y=c(8,8,20),w=c(147,20,37),h=c(91,91,70))
bf_render_png(p2,'results/figures/grouped.png',font,allowed2,210,120,210,c('scripts/draw_three.R','scripts/figure_style.R','design-spec.yaml'),boxes2)
write.csv(z,'results/plot_data/grouped.csv',row.names=FALSE);write.csv(st,'results/tables/grouped_tests.csv',row.names=FALSE)

# Sector-specific scales use mean + SEM; no cross-unit radial magnitude comparison.
sectors<-c('Forks','Crossings','Length','SurfArea','AvgDiam','RootVolume','Tips');treatments<-c('KB','BC','BAc')
base<-c(13000,390,59000,7800,650,2700,2900)
raw<-expand.grid(replicate=1:6,group=treatments,category=sectors,KEEP.OUT.ATTRS=FALSE)
raw$category<-factor(raw$category,levels=sectors);raw$group<-factor(raw$group,levels=treatments)
raw$value<-vapply(seq_len(nrow(raw)),function(i){k<-as.integer(raw$category[i]);g<-as.integer(raw$group[i]);rnorm(1,base[k]*c(.45,.70,1)[g],base[k]*.055)},numeric(1))
sumtab<-raw |> group_by(category,group) |> summarise(mean=mean(value),sem=sd(value)/sqrt(n()),.groups='drop')
# Tukey letters follow tested pairwise decisions, not a preassigned ordering.
if(!requireNamespace('multcompView',quietly=TRUE))stop('multcompView needed for tested compact letters')
tukey_tables<-list();sumtab$letter<-NA_character_
for(cat in sectors){sub<-raw[raw$category==cat,];h<-TukeyHSD(aov(value~group,data=sub))$group;letters<-multcompView::multcompLetters(h[,'p adj'])$Letters;ix<-which(sumtab$category==cat);sumtab$letter[ix]<-letters[as.character(sumtab$group[ix])];tukey_tables[[cat]]<-data.frame(category=cat,contrast=rownames(h),h,check.names=FALSE)}
write.csv(raw,'results/plot_data/circular_raw.csv',row.names=FALSE);write.csv(sumtab,'results/plot_data/circular.csv',row.names=FALSE);write.csv(do.call(rbind,tukey_tables),'results/tables/circular_tukey.csv',row.names=FALSE)
sector_cols<-c('#F6EABD','#F5DEEA','#F3B8C8','#EB76A1','#A1CF78','#9DC593','#DEE8D5')
bar_cols<-c('#6DC5E5','#B6DDED','#E2EFF4')
ragg::agg_png('results/figures/circular.png',width=170,height=170,units='mm',res=300,background='white')
par(family=font$family,mar=c(1,1,1,1),cex=.9)
circos.clear();circos.par(start.degree=90,gap.degree=7,cell.padding=c(0,0,0,0),track.margin=c(.012,.012),canvas.xlim=c(-1.18,1.18),canvas.ylim=c(-1.18,1.18))
circos.initialize(factors=factor(sectors,levels=sectors),xlim=c(0,1))
circos.trackPlotRegion(ylim=c(0,1),track.height=.035,bg.col=sector_cols,bg.border='#454545',panel.fun=function(x,y){})
circos.trackPlotRegion(ylim=c(0,1),track.height=.10,bg.border=NA,panel.fun=function(x,y){circos.text(.5,.5,CELL_META$sector.index,facing='bending.inside',niceFacing=TRUE,cex=.85)})
circos.trackPlotRegion(ylim=c(0,1),track.height=.49,bg.col=adjustcolor(sector_cols,alpha.f=.26),bg.border='#555555',panel.fun=function(x,y){
 cat<-CELL_META$sector.index;sub<-sumtab[sumtab$category==cat,];top<-max(sub$mean+sub$sem)*1.18;step<-10^floor(log10(top))/2;upper<-ceiling(top/step)*step
 for(q in c(.25,.5,.75)){circos.lines(c(0,1),c(q,q),col='#888888',lty=2,lwd=.5);circos.text(.005,q,format(round(q*upper),trim=TRUE),facing='clockwise',adj=c(.5,0),cex=.47)}
 for(j in 1:3){xx<-c(.22,.50,.78)[j];yy<-sub$mean[j]/upper;se<-sub$sem[j]/upper
 circos.rect(xx-.085,0,xx+.085,yy,col=bar_cols[j],border='#333333',lwd=.6)
 circos.segments(xx,yy-se,xx,yy+se,lwd=.6);circos.segments(xx-.025,yy+se,xx+.025,yy+se,lwd=.6);circos.segments(xx-.025,yy-se,xx+.025,yy-se,lwd=.6)
 circos.text(xx,yy+se+.055,sub$letter[j],facing='inside',niceFacing=TRUE,cex=.7)
 }
})
legend('topright',legend=treatments,fill=bar_cols,border='#333333',bty='n',cex=.78,inset=c(0,0),x.intersp=.7,y.intersp=.95)
circos.clear();invisible(dev.off())
stopifnot(nrow(sumtab)==21,nrow(raw)==126,all(sumtab$sem>0),nrow(z)==192,all(st$q>=0 & st$q<=1))
writeLines('3 PNG rendered; 2600 unique genes, 192 mouse-category observations, 126 circular observations. Data simulated; compare source structure separately.','results/tables/runtime-checks.txt')
