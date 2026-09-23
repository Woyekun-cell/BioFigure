#!/usr/bin/env Rscript
suppressPackageStartupMessages({library(ggplot2); library(gghalves); library(ggpubr); library(dplyr)})
set.seed(7601)
groups <- c("Conven_Amb","Conven_Warm","Conserv_Amb","Conserv_Warm")
means <- c(12.7,14.6,12.3,13.8)
d <- data.frame(treatment=factor(rep(groups,each=8),levels=groups),value=unlist(lapply(means,function(m) rnorm(8,m,.55))))
cols <- c(Conven_Amb="#3C439B",Conven_Warm="#B13F43",Conserv_Amb="#4CA08F",Conserv_Warm="#E7B34F")
p <- ggplot(d,aes(treatment,value,colour=treatment))+
  geom_half_violin(position=position_nudge(x=.28),side="r",trim=FALSE,alpha=.82,width=.55,linewidth=.65)+
  geom_boxplot(width=.34,outlier.shape=NA,fill="white",linewidth=.7)+
  geom_jitter(width=.11,size=1.7,alpha=.55)+
  stat_summary(fun=mean,geom="point",shape=21,size=2,fill="#303030",colour="#303030")+
  annotate("segment",x=1,xend=2,y=16.55,yend=16.55,linewidth=.45)+annotate("text",x=1.5,y=16.70,label="***",size=3.5)+
  annotate("segment",x=3,xend=4,y=16.15,yend=16.15,linewidth=.45)+annotate("text",x=3.5,y=16.30,label="**",size=3.5)+
  scale_colour_manual(values=cols)+scale_y_continuous(limits=c(10.5,17),breaks=c(12,14,16),expand=c(0,0))+
  labs(x=NULL,y=NULL,title="Soil temperature (°C)")+
  theme_bw(base_size=10)+theme(legend.position="none",panel.grid=element_blank(),panel.border=element_rect(colour="#333333",linewidth=.7),plot.title=element_text(hjust=.5,size=12,face="plain",margin=margin(5,0,5,0)),axis.text=element_text(colour="#222222"),axis.text.x=element_text(angle=35,hjust=1,size=8.5),plot.margin=margin(6,12,6,6))
ggsave("results/figures/issue076_raincloud.png",p,width=5.2,height=4.7,dpi=300,bg="white")
write.csv(transform(d,source="simulated",seed=7601),"results/plot_data/issue076_raincloud.csv",row.names=FALSE)
