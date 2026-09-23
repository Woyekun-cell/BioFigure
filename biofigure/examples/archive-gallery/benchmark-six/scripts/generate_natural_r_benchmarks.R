#!/usr/bin/env Rscript
suppressPackageStartupMessages({library(ggplot2);library(survival)})
args<-commandArgs(trailingOnly=TRUE);out<-if(length(args)) args[1] else 'results/reproduction_benchmark'
dir.create(file.path(out,'figures'),recursive=TRUE,showWarnings=FALSE);dir.create(file.path(out,'plot_data'),recursive=TRUE,showWarnings=FALSE)
source('biofigure/scripts/figure_style.R');font<-bf_font('Arial');set.seed(3200)
cols<-c(Control='#3B6FB6',Treatment='#D95F3D')
emit<-function(id,p,data,allowed,w=100,h=75){
 boxes<-data.frame(id=c('data','labels','legend'),x=c(0,0,.78*w),y=c(0,.85*h,0),w=c(.78*w,.78*w,.22*w),h=c(.85*h,.15*h,.85*h))
 csv<-file.path(out,'plot_data',paste0(id,'.csv'));write.csv(data,csv,row.names=FALSE)
 spec<-file.path(out,'plot_data',paste0(id,'-design.yaml'));writeLines(c('schema_version: "1.0"',paste0('figure_id: ',id),'simulation: true','generation: natural-language-from-blank-script'),spec)
 png<-file.path(out,'figures',paste0(id,'.png'))
 bf_render_png(p,png,font,unique(as.character(allowed)),w,h,w,c(normalizePath('biofigure/benchmark/reproduction/generate_natural_r_benchmarks.R'),normalizePath('biofigure/scripts/figure_style.R'),normalizePath(spec)),boxes,dpi=300)
}
# Natural-language task 1: time-to-event curves with censor marks.
n<-80;survdat<-data.frame(subject_id=sprintf('S%03d',1:n),group=rep(c('Control','Treatment'),each=n/2))
survdat$time_month<-pmin(rexp(n,rate=ifelse(survdat$group=='Treatment',.055,.09)),24);survdat$event<-as.integer(survdat$time_month<24 & runif(n)>.18)
fit<-survfit(Surv(time_month,event)~group,data=survdat);ss<-summary(fit,censored=TRUE)
sd<-data.frame(time=ss$time,survival=ss$surv,event=ss$n.event,group=sub('group=','',ss$strata));ticks<-sd[sd$event==0,]
med=data.frame(group=rownames(summary(fit)$table),median=summary(fit)$table[,'median']);med$group=sub('group=','',med$group)
p<-ggplot(sd,aes(time,survival,color=group))+geom_hline(yintercept=.5,color='#8C939A',linewidth=.3,linetype=3)+geom_segment(data=med,aes(x=median,xend=median,y=0,yend=.5),inherit.aes=FALSE,color='#8C939A',linewidth=.3,linetype=3)+geom_step(linewidth=.72)+geom_point(data=ticks,shape=3,size=1.55,stroke=.5)+scale_color_manual(values=cols,name='Group')+scale_x_continuous('Time (months)',breaks=seq(0,24,6),limits=c(0,24))+scale_y_continuous('Survival probability',breaks=seq(0,1,.25),limits=c(0,1),labels=c('0%','25%','50%','75%','100%'))+bf_theme(font,7)
emit('survival',p,survdat,c('Time (months)','Survival probability','Group','Control','Treatment',as.character(seq(0,24,6)),c('0%','25%','50%','75%','100%')))
# Task 2: square annotated heatmap; group encoded in x labels and top strip color.
genes=paste0('Gene ',LETTERS[1:8]);samples=paste0('S',1:8);hm=expand.grid(gene=genes,sample=samples);hm$group=rep(rep(c('Control','Treatment'),each=4),each=8);hm$z_score=rnorm(nrow(hm));hm$gx=match(hm$sample,samples);hm$gy=9-match(hm$gene,genes);ha=unique(hm[c('sample','group','gx')])
p=ggplot(hm,aes(gx,gy,fill=z_score))+geom_tile(color='white',linewidth=.25)+geom_point(data=ha,aes(x=gx,y=9,color=group),inherit.aes=FALSE,shape=15,size=4.2)+coord_fixed(xlim=c(.5,8.5),ylim=c(.5,9.45),clip='off')+scale_x_continuous('Sample',breaks=1:8,labels=samples)+scale_y_continuous('Gene',breaks=1:8,labels=rev(genes))+scale_fill_gradient2(low='#3B6FB6',mid='white',high='#D95F3D',midpoint=0,name='z score')+scale_color_manual(values=cols,name='Sample group')+bf_theme(font,6.5)
emit('annotated_heatmap',p,hm,c('Sample','Gene','z score','Sample group','Control','Treatment',genes,samples,as.character(-2:2)),100,88)
# Task 3: circular composition.
comp=expand.grid(condition=c('Baseline','Early','Late'),cell_type=c('T cell','B cell','Myeloid','Stromal'));comp$raw=runif(nrow(comp),1,5);comp$proportion=ave(comp$raw,comp$condition,FUN=function(x)x/sum(x));comp$label=ifelse(comp$proportion>=.12,paste0(round(100*comp$proportion),'%'),'')
p=ggplot(comp,aes(x=2,y=proportion,fill=cell_type))+geom_col(width=.72,color='white',linewidth=.35)+geom_text(aes(label=label),position=position_stack(vjust=.5),family=font$family,size=2.2,color='#222222')+coord_polar(theta='y')+xlim(.45,2.45)+facet_wrap(~condition,nrow=1)+scale_y_continuous(breaks=NULL)+scale_fill_manual(values=c('#3B6FB6','#58A6A6','#D9A441','#C06C84'),name='Cell type')+labs(x=NULL,y=NULL)+bf_theme(font,6.7)+theme(axis.text=element_blank(),axis.ticks=element_blank(),axis.line=element_blank(),strip.background=element_blank(),strip.text=element_text(family=font$family,face='bold',size=rel(1)))
emit('circular_composition',p,comp,c('Baseline','Early','Late','Cell type','T cell','B cell','Myeloid','Stromal',unique(comp$label)),125,70)
# Task 4: swimmer plot.
sw=data.frame(patient=factor(sprintf('P%02d',1:12),levels=sprintf('P%02d',12:1)),duration=sort(runif(12,5,22),decreasing=FALSE));sw$response_start=pmax(.8,sw$duration*runif(12,.12,.35));sw$progression=ifelse(runif(12)>.35,sw$duration*runif(12,.65,.95),NA);sw$status=rep(c('PR','CR'),6)
p=ggplot(sw,aes(y=patient))+geom_segment(aes(x=0,xend=duration,yend=patient),linewidth=2.6,color='#B8C2CC',lineend='round')+geom_point(aes(x=response_start,color=status),size=2)+geom_point(aes(x=progression),shape=4,size=2,stroke=.6,na.rm=TRUE)+scale_color_manual(values=c(CR='#3B6FB6',PR='#D95F3D'),name='Best response')+scale_x_continuous('Treatment duration (months)',breaks=seq(0,24,6),limits=c(0,24))+labs(y='Patient')+bf_theme(font,7)
emit('swimmer',p,sw,c('Treatment duration (months)','Patient','Best response','CR','PR',levels(sw$patient),as.character(seq(0,24,6))))
# Task 5: enrichment similarity network with deterministic layout.
nodes=data.frame(term=c('Lipid metabolism','Oxidative stress','Immune response','Cell cycle','DNA repair','Mitochondria'),x=c(0,1,2,.3,1.4,2.2),y=c(1.5,2,1.4,.3,.5,.2),gene_count=c(34,26,31,20,18,29),fdr=c(.001,.004,.008,.015,.028,.006));edges=data.frame(source=c(1,1,2,2,3,4,5),target=c(2,3,3,6,4,5,6),similarity=c(.72,.55,.61,.48,.42,.69,.58));ed=cbind(edges,nodes[edges$source,c('x','y')],xend=nodes$x[edges$target],yend=nodes$y[edges$target])
p=ggplot()+geom_segment(data=ed,aes(x=x,y=y,xend=xend,yend=yend,linewidth=similarity),color='#A7AFB7')+geom_point(data=nodes,aes(x,y,size=gene_count,color=-log10(fdr)))+geom_text(data=nodes,aes(x,y,label=term),family=font$family,size=2.15,vjust=-1.35)+scale_color_gradient(low='#58A6A6',high='#B33A3A',name='−log10(FDR)')+scale_size_continuous(name='Gene count',range=c(3,7))+scale_linewidth(range=c(.25,1),guide='none')+coord_equal(xlim=c(-.35,2.55),ylim=c(-.15,2.35),clip='off')+labs(x=NULL,y=NULL)+bf_theme(font,6.5)+theme(axis.text=element_blank(),axis.ticks=element_blank(),axis.line=element_blank())
emit('enrichment_network',p,cbind(nodes),c(nodes$term,'−log10(FDR)','Gene count',as.character(c(20,25,30)),sprintf('%.1f',c(2,2.5,3))))
# Task 6: repeated-measure time course with raw observations and 95% CI.
ts=expand.grid(subject_id=sprintf('S%02d',1:12),group=c('Control','Treatment'),day=c(0,7,14,28));ts$value=55+as.numeric(factor(ts$group))*2+ts$day*ifelse(ts$group=='Treatment',.55,.12)+as.numeric(factor(ts$subject_id))*rnorm(nrow(ts),0,.12)+rnorm(nrow(ts),0,3);agg=aggregate(value~group+day,ts,function(x)c(mean=mean(x),se=sd(x)/sqrt(length(x))));ag=data.frame(group=agg$group,day=agg$day,mean=agg$value[,'mean'],se=agg$value[,'se']);ag$lo=ag$mean-1.96*ag$se;ag$hi=ag$mean+1.96*ag$se
p=ggplot(ts,aes(day,value,color=group))+geom_line(aes(group=interaction(group,subject_id)),alpha=.12,linewidth=.3)+geom_point(alpha=.25,size=.85)+geom_ribbon(data=ag,aes(x=day,ymin=lo,ymax=hi,fill=group),inherit.aes=FALSE,alpha=.16,color=NA)+geom_line(data=ag,aes(y=mean),linewidth=.9)+geom_point(data=ag,aes(y=mean),size=2)+scale_color_manual(values=cols,name='Group')+scale_fill_manual(values=cols,guide='none')+scale_x_continuous('Day',breaks=c(0,7,14,28))+scale_y_continuous('Response (a.u.)',breaks=seq(40,80,10))+coord_cartesian(ylim=c(40,82))+bf_theme(font,7)
emit('time_series',p,ts,c('Day','Response (a.u.)','Group','Control','Treatment',as.character(c(0,7,14,28)),as.character(seq(40,80,10))))
cat('NATURAL_R_BENCHMARKS_OK\n')
