#!/usr/bin/env Rscript
suppressPackageStartupMessages({library(ggplot2); library(dplyr); library(tidyr); library(aplot)})
set.seed(2801); n <- 24
patients <- sprintf("P%02d",1:n)
d <- tibble(id=patients, follow=sort(sample(230:920,n)), tx_start=sample(15:90,n,TRUE)) |>
  mutate(tx_end=pmin(follow-25,tx_start+sample(90:350,n,TRUE)), death=ifelse(runif(n)<.28,follow,NA), progression=pmin(follow-15,tx_end+sample(15:180,n,TRUE)), id=factor(id,levels=id))
anno <- crossing(id=d$id, variable=factor(c("Sex","Stage","Response"),levels=c("Sex","Stage","Response"))) |>
  mutate(value=case_when(variable=="Sex"~sample(c("Female","Male"),n(),TRUE),variable=="Stage"~sample(c("III","IV"),n(),TRUE),TRUE~sample(c("PR","SD","PD"),n(),TRUE)))
p <- ggplot(d,aes(y=id))+geom_segment(aes(x=0,xend=follow,yend=id),colour="#A7B0B5",linetype=3)+
  geom_segment(aes(x=tx_start,xend=tx_end,yend=id),linewidth=2.2,colour="#69B3C5",lineend="round")+
  geom_point(aes(x=progression),shape=24,size=2.3,fill="#F2C84B")+geom_point(aes(x=death),shape=4,size=2.4,stroke=1,colour="#B5483A",na.rm=TRUE)+
  scale_x_continuous(expand=expansion(mult=c(0,.03)))+scale_y_discrete(labels=NULL)+labs(x="Days after surgery",y=NULL,title="Longitudinal treatment and event history",subtitle="Simulated cohort; visual grammar learned from issue 28")+
  theme_classic(base_size=11)+theme(axis.line.y=element_blank(),axis.ticks.y=element_blank(),plot.title=element_text(face=2,size=15),plot.subtitle=element_text(colour="#65737A"))
a <- ggplot(anno,aes(variable,id,fill=value))+geom_tile(colour="white",linewidth=.6)+
  scale_fill_manual(values=c(Female="#D97B6C",Male="#65B8AA",III="#7CB5D7",IV="#2F6C9E",PR="#73B7A6",SD="#6B8FAA",PD="#D2AA68"))+
  labs(x=NULL,y=NULL)+theme_void(base_size=10)+theme(axis.text.x=element_text(angle=45,hjust=1),axis.text.y=element_text(),legend.position="none")
fig <- p %>% insert_left(a,width=.22)
ggsave("results/figures/issue028_swimmer.png",fig,width=8,height=8.8,dpi=300,bg="white")
write.csv(transform(d,source="simulated",seed=2801),"results/plot_data/issue028_swimmer.csv",row.names=FALSE)
