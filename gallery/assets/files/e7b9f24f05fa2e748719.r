suppressPackageStartupMessages({library(ggplot2);library(patchwork);library(ragg);library(dplyr)})
source('scripts/figure_style.R');font<-bf_font('Arial');bf_complexheatmap_font(font)
set.seed(20260916)
# Independently simulated linear regression coefficients and t-based confidence intervals.
k<-21;d<-data.frame(condition=paste('Trait',LETTERS[1:k]),n=sample(45:300,k,TRUE),beta=sort(rnorm(k,.25,.42),decreasing=TRUE),se=runif(k,.07,.28),mean=runif(k,0,1.5),sd=runif(k,.1,1))
d$lo<-d$beta-qt(.975,d$n-2)*d$se;d$hi<-d$beta+qt(.975,d$n-2)*d$se;d$q<-p.adjust(2*pt(-abs(d$beta/d$se),d$n-2),'BH');d$y<-k:1
d$ci<-sprintf('%.2f (%.2f, %.2f)',d$beta,d$lo,d$hi);d$ms<-sprintf('%.2f (%.2f)',d$mean,d$sd);d$ql<-ifelse(d$q<.001,'<0.001',sprintf('%.3f',d$q));d$color<-ifelse(d$beta>.6,'#D62B32',ifelse(d$beta>.2,'#85B9DB','#222222'))
p<-ggplot(d,aes(y=y))+annotate('rect',xmin=.2,xmax=.6,ymin=.5,ymax=21.5,fill='#E8F0F6')+annotate('rect',xmin=.6,xmax=1.6,ymin=.5,ymax=21.5,fill='#FDEAEA')+
 geom_segment(aes(x=pmax(lo,-.8),xend=pmin(hi,1.6),yend=y),linewidth=.23,colour='#555555')+
 geom_segment(data=d[d$hi>1.6,],aes(x=1.50,xend=1.6,yend=y),arrow=grid::arrow(length=grid::unit(1.1,'mm'),type='closed'),linewidth=.25)+
 geom_segment(data=d[d$lo< -.8,],aes(x=-.7,xend=-.8,yend=y),arrow=grid::arrow(length=grid::unit(1.1,'mm'),type='closed'),linewidth=.25)+
 geom_point(aes(x=beta,fill=color),shape=22,size=1.9,stroke=.25)+scale_fill_identity()+
 annotate('text',x=c(-.3,.4,1.1),y=22,label=c('Lower','Moderate','High'),family=font$family,size=2.5,colour=c('#555555','#609BCA','#D95359'))+
 annotate('segment',x=c(0,.2,.6),xend=c(0,.2,.6),y=.5,yend=21.5,linetype=2,linewidth=.25,colour=c('#444444','#609BCA','#D95359'))+
 geom_text(aes(x=-4.8,label=condition),family=font$family,hjust=0,size=2.6)+geom_text(aes(x=-3,label=n),family=font$family,hjust=0,size=2.6)+geom_text(aes(x=-2.1,label=ms),family=font$family,hjust=0,size=2.6)+geom_text(aes(x=1.95,label=ci),family=font$family,hjust=0,size=2.6)+geom_text(aes(x=3.65,label=ql),family=font$family,hjust=0,size=2.6)+
 annotate('text',x=c(-4.8,-3,-2.1,1.95,3.65),y=23,label=c('Trait','N','Mean (SD)','β (95% CI)','q'),family=font$family,hjust=0,fontface='bold',size=2.8)+
 annotate('segment',x=-4.8,xend=4.2,y=c(10.5,16.5),yend=c(10.5,16.5),linetype=2,linewidth=.2,colour='#999999')+
 scale_x_continuous(limits=c(-5,4.3),breaks=seq(-.8,1.6,.4),guide=guide_axis(cap='both'))+scale_y_continuous(limits=c(.2,24),breaks=NULL)+labs(x='β',y=NULL)+theme_classic(base_size=9,base_family=font$family)+theme(axis.line.y=element_blank(),axis.ticks.y=element_blank(),plot.margin=margin(7,7,7,7))
ragg::agg_png('results/figures/forest.png',width=220,height=125,units='mm',res=300,background='white');print(p);dev.off();write.csv(d,'results/plot_data/forest.csv',row.names=FALSE)

# Twenty amino-acid substitutions at sixty positions; values are simulated energies.
aa<-strsplit('ACDEFGHIKLMNPQRSTVWY','')[[1]];s<-60
m<-matrix(rnorm(s*20,0,.30),20,s);spikes<-c(5,13,23,31,42,52,58);m[,spikes]<-m[,spikes]+rep(c(1.3,1.6,1.2,1.7,1.5,1.4,1.7),each=20);m[,c(18,38)]<-m[,c(18,38)]-.8
h<-expand.grid(aa=1:20,site=1:s);h$ddg<-as.vector(m);av<-data.frame(site=1:s,mean=colMeans(m));lo<--1;hi<-2;av$mapped<-1+(av$mean-lo)*19/(hi-lo)
p2<-ggplot(h,aes(site,aa))+coord_fixed(ratio=1)+geom_raster(aes(fill=ddg),interpolate=FALSE)+scale_fill_gradientn(colours=c('#008100','#6AED51','#CCFE90','#FEF5B0','#FEB483','#FE5841','#F80103'),limits=c(-1.5,3),breaks=seq(-1.5,3,.5),oob=scales::squish,name='Simulated mutation energy')+
 geom_hline(yintercept=1+(0-lo)*19/(hi-lo),linetype=2,linewidth=.3)+geom_line(data=av,aes(site,mapped),inherit.aes=FALSE,linetype=2,colour='#444444',linewidth=.28)+geom_point(data=av,aes(site,mapped,colour=mean>0),inherit.aes=FALSE,size=1.2)+scale_colour_manual(values=c('#2C43EC','#F80660'),guide='none')+
 scale_x_continuous(breaks=seq(1,60,2),labels=paste0('S',seq(1,60,2)),expand=c(0,0))+scale_y_continuous(breaks=1:20,labels=aa,expand=c(0,0),sec.axis=sec_axis(~(. -1)/19*(hi-lo)+lo,name='Mean energy (kcal/mol)',breaks=c(-1,0,1,2)))+
 labs(x='Position',y='Substitution')+guides(fill=guide_colourbar(direction='horizontal',title.position='top',barwidth=grid::unit(155,'mm'),barheight=grid::unit(3,'mm')))+theme_classic(base_size=9,base_family=font$family)+theme(legend.position='top',axis.text.x=element_text(angle=90,hjust=1,vjust=.5),legend.title=element_text(size=9),plot.margin=margin(6,6,6,6))
ragg::agg_png('results/figures/mutation.png',width=220,height=110,units='mm',res=300,background='white');print(p2);dev.off();write.csv(h,'results/plot_data/mutation.csv',row.names=FALSE);write.csv(av,'results/plot_data/mutation_means.csv',row.names=FALSE)

# Repeated trial traces within each illustrative subject: SEM is across trials, not mice.
t<-seq(-20,120,by=1);z<-expand.grid(time=t,trial=1:10,group=c('ACSF','SHU9119'),mouse=1:3)
z$value<-mapply(function(t,g,mo){rise<-if(t<0)0 else (1-exp(-t/9))*exp(-t/350);mu<-rise*c(.125,.11,.09)[mo]*ifelse(g=='ACSF',1,c(.48,.6,.3)[mo]);mu+rnorm(1,0,.014)},z$time,z$group,z$mouse)
su<-z |> group_by(time,group,mouse) |> summarise(mean=mean(value),sem=sd(value)/sqrt(n()),.groups='drop')
parts<-lapply(1:3,function(i)ggplot(su[su$mouse==i,],aes(time,mean,colour=group))+geom_hline(yintercept=0,linetype=2,linewidth=.35)+geom_errorbar(aes(ymin=mean-sem,ymax=mean+sem),width=0,alpha=.22,linewidth=.4)+geom_line(linewidth=.5)+scale_colour_manual(values=c(ACSF='#808080',SHU9119='#F15A24'))+scale_x_continuous(breaks=c(0,40,80,120),limits=c(-20,120),expand=c(0,0))+scale_y_continuous(breaks=seq(-.05,.15,.05),limits=c(-.05,.15))+labs(x='Time (s)',y=if(i==1)'−ΔF/F₀' else NULL,title=paste('Mouse',i))+theme_classic(base_size=10,base_family=font$family)+theme(legend.position=if(i==3)'right' else 'none',legend.title=element_blank(),plot.title=element_text(hjust=.5,size=10),axis.text=element_text(colour='#222222')))
parts[[1]]<-parts[[1]]+annotate('segment',x=0,xend=0,y=-.034,yend=-.007,arrow=grid::arrow(length=grid::unit(1.4,'mm')),linewidth=.3)+annotate('text',x=15,y=-.038,label='cAMP',family=font$family,size=2.7)
p3<-wrap_plots(parts,nrow=1)+plot_layout(widths=c(1,1,1.25))
ragg::agg_png('results/figures/time.png',width=230,height=90,units='mm',res=300,background='white');print(p3);dev.off();write.csv(z,'results/plot_data/time_raw.csv',row.names=FALSE);write.csv(su,'results/plot_data/time_summary.csv',row.names=FALSE)
writeLines(capture.output(sessionInfo()),'results/tables/sessionInfo.txt')
writeLines('Simulation; source inspected then independently coded. Forest: simulated estimates and t confidence intervals; mutation: synthetic energies; time: within-subject trial mean and SEM, no group population inference.','results/tables/scope.txt')
