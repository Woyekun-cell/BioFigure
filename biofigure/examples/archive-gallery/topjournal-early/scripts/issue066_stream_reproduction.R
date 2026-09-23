#!/usr/bin/env Rscript
suppressPackageStartupMessages({library(ggplot2); library(ggstream); library(dplyr)})
set.seed(6601)
age <- seq(40,90,by=1); cells <- c("Naive CD8 T","Central memory","Effector memory","GZMK+ EM","KLRF1+ effector","Adaptive NK")
d <- expand.grid(Age=age,cell_type=cells) |> as_tibble() |> group_by(Age) |>
  mutate(raw=case_when(cell_type==cells[1]~1.8-.022*(Age-40),cell_type==cells[2]~1.15-.006*(Age-40),cell_type==cells[3]~.55+.014*(Age-40),cell_type==cells[4]~.7+.007*(Age-40),cell_type==cells[5]~.25+.015*(Age-40),TRUE~.35+.011*(Age-40))+runif(n(),-.07,.07),percentage=pmax(raw,.04)/sum(pmax(raw,.04))) |> ungroup()
pal <- c("#4C78A8","#72B7B2","#F2CF5B","#F28E62","#B279A2","#8A9A5B")
p <- ggplot(d,aes(Age,percentage,fill=cell_type))+
  geom_stream(type="proportional",bw=1.2,colour="white",linewidth=.25)+
  scale_fill_manual(values=setNames(pal,cells))+scale_y_continuous(labels=scales::label_percent(),expand=c(0,0))+
  scale_x_continuous(breaks=seq(40,90,10),expand=c(0,0))+labs(x="Age (years)",y="Share of immune compartment",title="Age-related immune composition",subtitle="Simulated trajectories; ggstream proportional geometry")+
  theme_classic(base_size=12)+theme(legend.position="right",legend.title=element_blank(),plot.title=element_text(face=2,size=16),plot.subtitle=element_text(colour="#65737A"),axis.line=element_line(linewidth=.45))
ggsave("results/figures/issue066_stream.png",p,width=8,height=5.2,dpi=300,bg="white")
write.csv(transform(d,source="simulated",seed=6601),"results/plot_data/issue066_stream.csv",row.names=FALSE)
