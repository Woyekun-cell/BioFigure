# Structural regression repair of existing simulation; not blind generation.
#!/usr/bin/env Rscript
suppressPackageStartupMessages({library(ggplot2);library(ggridges);library(patchwork);library(dplyr);library(tidyr);library(ragg);library(systemfonts)})
font <- 'Arial'; stopifnot(systemfonts::match_fonts(font)$path != '')
set.seed(7001)
genera <- c("Streptococcus","Bacteroides","Parabacteroides","Limosilactobacillus","Megamonas","Ligilactobacillus","Escherichia","Bilophila","Bifidobacterium","Agathobaculum","Parolsenella","Dorea","Anaerobutyricum","Gemmiger","Lachnospira","Roseburia","Prevotella","Faecalibacterium","Agathobacter","Blautia_A")
negative_n <- c(19,11,8,6,7,5,4,4,4,3,6,14,4,5,0,1,1,1,0,0)
positive_n <- c(1,0,0,0,0,0,0,0,0,2,1,1,3,4,4,5,5,5,7,12)
negative_mu <- seq(-.030,-.010,length.out=20)
positive_mu <- seq(.012,.035,length.out=20)
d <- bind_rows(lapply(seq_along(genera), function(i) {
  data.frame(
    Genus = genera[i],
    value = c(rnorm(negative_n[i], negative_mu[i], .0035),
              rnorm(positive_n[i], positive_mu[i], .0035))
  )
}))
d$Genus <- factor(d$Genus,levels=genera)
dens <- ggplot(d,aes(value,Genus,fill=after_stat(x)))+geom_segment(data=data.frame(Genus=factor(genera,levels=genera)),aes(x=-.045,xend=.060,y=Genus,yend=Genus),inherit.aes=FALSE,colour="#444444",linewidth=.25)+geom_density_ridges_gradient(scale=1.2,rel_min_height=0,colour="#4A4A4A",linewidth=.25)+scale_fill_gradient2(low="#397CB5",mid="#F7F7F4",high="#75C69D",midpoint=0)+scale_x_continuous(limits=c(-.045,.060),breaks=c(-.03,0,.03,.06))+labs(x="β1 (MAG)",y=NULL)+theme_classic(base_size=10,base_family=font)+theme(text=element_text(family=font),legend.position="none",axis.text.y=element_text(size=8.4),axis.line.y=element_blank(),axis.ticks.y=element_blank(),plot.margin=margin(5,10,5,5))
b <- d |> mutate(Direction=ifelse(value>0,"Positive","Negative")) |> count(Genus,Direction) |> mutate(n=ifelse(Direction=="Negative",-n,n))
bars <- ggplot(b,aes(n,Genus,fill=Direction))+geom_col(colour="#333333",linewidth=.25,width=.82)+geom_vline(xintercept=0,linewidth=.4)+scale_fill_manual(values=c(Negative="#397CB5",Positive="#75C69D"))+scale_x_continuous(breaks=c(-20,-15,-10,-5,0,5,10),labels=abs,expand=c(0,0))+coord_cartesian(xlim=c(-20,12),clip="off")+labs(x="Number of MAGs",y=NULL)+theme_classic(base_size=10,base_family=font)+theme(text=element_text(family=font),legend.position="none",axis.text.y=element_blank(),axis.ticks.y=element_blank(),axis.line.y=element_blank(),plot.margin=margin(5,5,5,10))
p <- dens+bars+plot_layout(widths=c(3,2))
dir.create("results/figures",recursive=TRUE,showWarnings=FALSE);dir.create("results/plot_data",recursive=TRUE,showWarnings=FALSE)
ragg::agg_png("results/figures/scidraw_ridge_bipolar.png",width=150,height=180,units='mm',res=300,background='white');print(p);dev.off()
write.csv(transform(d,source="simulated",seed=7001),"results/plot_data/scidraw_ridge_bipolar.csv",row.names=FALSE)
