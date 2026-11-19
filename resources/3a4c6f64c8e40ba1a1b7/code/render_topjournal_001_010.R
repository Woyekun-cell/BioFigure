#!/usr/bin/env Rscript
options(error=function(){traceback(6);q(status=1)})
suppressPackageStartupMessages({
  library(ggplot2); library(dplyr); library(tidyr); library(patchwork)
  library(ggforce); library(ComplexHeatmap); library(circlize)
  library(ggalluvial); library(ggrepel); library(ggbeeswarm); library(grid)
})

set.seed(20260922)
file_arg <- sub("^--file=", "", commandArgs(trailingOnly=FALSE)[grep("^--file=",commandArgs(trailingOnly=FALSE))][1])
if (is.na(file_arg)) stop("Run this file with Rscript")
root <- normalizePath(file.path(dirname(file_arg), ".."))
fig_dir <- file.path(root,"results","figures")
dat_dir <- file.path(root,"results","plot_data")
dir.create(fig_dir,recursive=TRUE,showWarnings=FALSE); dir.create(dat_dir,recursive=TRUE,showWarnings=FALSE)
font <- "Helvetica"
pal <- c("#355C7D","#6C8EBF","#69A6A6","#91C7B1","#F2CC8F","#E89A6B","#D86863","#A85751","#7E5A83","#565264")
theme_bf <- function(base=10) theme_classic(base_size=base,base_family=font) +
  theme(axis.title=element_text(size=base+.5,face="plain",colour="#222222"),
        axis.text=element_text(size=base-1,colour="#333333"),
        strip.text=element_text(size=base,face="bold",colour="#222222"),
        strip.background=element_blank(), legend.title=element_text(size=base-1,face="bold"),
        legend.text=element_text(size=base-1), plot.title=element_text(size=base+2,face="bold"),
        plot.margin=margin(6,8,6,8,"pt"))
savep <- function(p,name,w,h) ggsave(file.path(fig_dir,name),p,width=w,height=h,units="mm",dpi=320,bg="white",device=ragg::agg_png)

# 001 Faceted stacked composition: narrow bars, bottom facet strips, compact legend.
microbes <- paste0("Family ",1:10); days <- factor(c("Day 0","Day 7","Day 10","Day 31"),levels=c("Day 0","Day 7","Day 10","Day 31"))
d1 <- expand_grid(day=days,sample=1:6,microbe=microbes) |>
  group_by(day,sample) |> mutate(raw=rgamma(n(),shape=c(1.4,1.2,2.4,3.4,5.2,3.2,1.5,1.1,.9,.7)),value=raw/sum(raw)) |> ungroup() |>
  mutate(sample_id=paste(day,sample,sep="-"),microbe=factor(microbe,levels=rev(microbes)))
p1 <- ggplot(d1,aes(sample_id,value,fill=microbe)) + geom_col(width=.90,colour="white",linewidth=.12) +
  facet_grid(~day,scales="free_x",space="free_x",switch="x") +
  scale_fill_manual(values=setNames(c("#686868","#9B9B9B","#B7A5C9","#CE8FA5","#E9A4BA","#F1B5C7","#9CD2E5","#66B6D4","#27A6C5","#268F88"),rev(microbes))) +
  scale_y_continuous(labels=scales::label_percent(accuracy=1),expand=c(0,0)) +
  labs(x=NULL,y="Relative abundance",fill=NULL) + theme_bf(9) +
  theme(axis.text.x=element_blank(),axis.ticks.x=element_blank(),panel.spacing.x=unit(1.6,"mm"),
        strip.placement="outside",strip.text.x.bottom=element_text(size=9,margin=margin(t=4)),legend.position="right",
        panel.border=element_rect(colour="#303030",fill=NA,linewidth=.5))
savep(p1,"01_faceted_stacked_composition.png",178,102); write.csv(d1,file.path(dat_dir,"01_faceted_stacked_composition.csv"),row.names=FALSE)

# 002 Radial stacked bars with four taxonomic sectors, gaps, radial grid and outer labels.
groups <- c("Birds","Reptiles","Amphibians","Mammals"); ng <- c(8,10,4,7)
d2 <- bind_rows(lapply(seq_along(groups),function(g){
  n<-ng[g]; tibble(group=groups[g],taxon=paste0(substr(groups[g],1,1),seq_len(n)),id=seq_len(n),
    EX=runif(n,3,15),EW=runif(n,2,12),CR=runif(n,4,20),EN=runif(n,6,22),VU=runif(n,8,26),DD=runif(n,1,8),NT=runif(n,2,10),LC=runif(n,18,55)) |>
    pivot_longer(EX:LC,names_to="status",values_to="value")
}))
gap <- 2
pos_map <- bind_rows(lapply(seq_along(groups),function(g){
  before <- sum(ng[seq_len(g-1)]) + gap*(g-1)
  tibble(group=groups[g],taxon=paste0(substr(groups[g],1,1),seq_len(ng[g])),position=before+seq_len(ng[g]))
}))
d2 <- d2 |> group_by(group,taxon) |> mutate(value=value/sum(value)*100) |> ungroup() |>
  left_join(pos_map,by=c("group","taxon")) |> mutate(status=factor(status,levels=c("LC","NT","DD","VU","EN","CR","EW","EX")))
p2 <- ggplot(d2,aes(position,value,fill=status)) + geom_col(width=.82,colour="white",linewidth=.12) + coord_polar(start=-.22,clip="off") +
  geom_text(data=pos_map |> group_by(group) |> summarise(position=mean(range(position)),.groups="drop"),
            aes(position,-12,label=group),inherit.aes=FALSE,family=font,fontface="bold",size=3.0,colour="#333333")+
  scale_fill_manual(values=c(LC="#67B876",NT="#C7D96F",DD="#F1D36A",VU="#F2A35E",EN="#E77961",CR="#D45A67",EW="#A9688E",EX="#7C5A91")) +
  scale_x_continuous(breaks=pos_map$position,labels=pos_map$taxon,limits=c(.5,max(pos_map$position)+.5),expand=c(0,0))+
  scale_y_continuous(limits=c(-22,115),breaks=c(25,50,75,100),expand=c(0,0)) + labs(x=NULL,y=NULL,fill="Threat status") +
  theme_void(base_family=font) + theme(axis.text.x=element_text(size=7.2,colour="#333333",face="plain"),
    legend.position="bottom",legend.key.width=unit(5,"mm"),legend.key.height=unit(3,"mm"),legend.text=element_text(size=7),
    legend.title=element_text(size=8,face="bold"),plot.margin=margin(10,16,7,16,"mm"))
savep(p2,"02_radial_stacked_bar.png",155,150); write.csv(d2,file.path(dat_dir,"02_radial_stacked_bar.csv"),row.names=FALSE)

# 003 Paired violin-box panels with exact p-value text and italic gene symbols.
d3 <- expand_grid(gene=c("lacC","gatY–kbaY"),antigen=factor(c("Without","With"),levels=c("Without","With")),id=1:180) |>
  mutate(value=rnorm(n(),ifelse(antigen=="With",.55,-.05)+ifelse(gene=="gatY–kbaY",.45,0),.52))
vp <- function(g){
  dd<-filter(d3,gene==g); pv<-wilcox.test(value~antigen,dd)$p.value
  ggplot(dd,aes(antigen,value,colour=antigen,fill=antigen)) +
    geom_violin(width=.78,alpha=.12,linewidth=.55,trim=FALSE) + geom_boxplot(width=.30,outlier.shape=NA,fill="white",linewidth=.55) +
    stat_summary(fun=mean,geom="point",shape=23,size=2.1,fill="white",stroke=.5) +
    annotate("segment",x=1,xend=2,y=2.2,yend=2.2,linewidth=.4) + annotate("text",x=1.5,y=2.34,label=format.pval(pv,digits=2,eps=2.2e-16),size=3.0,family=font) +
    scale_colour_manual(values=c(Without="#29B7D3",With="#F07D7D"))+scale_fill_manual(values=c(Without="#29B7D3",With="#F07D7D"))+
    coord_cartesian(ylim=c(-1.8,2.55),clip="off") + labs(x="Mucosal A-antigen",y=bquote(ln(.(g)~RPKM))) + theme_bf(9)+theme(legend.position="none")
}
p3 <- vp("lacC") + vp("gatY–kbaY") + plot_annotation(tag_levels="a")
savep(p3,"03_grouped_violin_statistics.png",154,82); write.csv(d3,file.path(dat_dir,"03_grouped_violin_statistics.csv"),row.names=FALSE)

# 004 Two-group correlation heatmaps with upper-triangle significance symbols.
vars4 <- c("BMI","TG","General health","Bristol type","HDL","Diet score","Glucose","Smoker")
mkcor <- function(shift){m<-matrix(rnorm(800),100,8);m[,1]<-scale(m[,2]*.55+rnorm(100));m[,5]<-scale(-m[,2]*.45+rnorm(100));m[,7]<-scale(m[,1]*.42+rnorm(100)+shift);cor(m)}
c41<-mkcor(.25);c42<-mkcor(-.2); dimnames(c41)<-dimnames(c42)<-list(vars4,vars4)
stars <- function(m) matrix(ifelse(abs(m)>.52,"#",ifelse(abs(m)>.36,"*","")),nrow(m),dimnames=dimnames(m))
col4<-colorRamp2(c(-.8,0,.8),c("#2166AC","#F7F7F7","#D73027"))
ht4 <- Heatmap(c41,name="Effect",col=col4,cluster_rows=FALSE,cluster_columns=FALSE,column_title="With mucosal A-antigen",
  cell_fun=function(j,i,x,y,w,h,fill){if(j>=i)grid.text(stars(c41)[i,j],x,y,gp=gpar(fontfamily=font,fontsize=9,fontface="bold"))},
  row_names_gp=gpar(fontfamily=font,fontsize=7),column_names_gp=gpar(fontfamily=font,fontsize=7),column_names_rot=45) +
  Heatmap(c42,name="Effect2",col=col4,cluster_rows=FALSE,cluster_columns=FALSE,column_title="Without mucosal A-antigen",show_heatmap_legend=FALSE,
  cell_fun=function(j,i,x,y,w,h,fill){if(j>=i)grid.text(stars(c42)[i,j],x,y,gp=gpar(fontfamily=font,fontsize=9,fontface="bold"))},
  show_row_names=FALSE,column_names_gp=gpar(fontfamily=font,fontsize=7),column_names_rot=45)
ragg::agg_png(file.path(fig_dir,"04_dual_correlation_heatmap.png"),width=180,height=88,units="mm",res=320,background="white")
draw(ht4,merge_legends=TRUE,heatmap_legend_side="bottom",padding=unit(c(5,5,5,5),"mm")); dev.off()
write.csv(c41,file.path(dat_dir,"04_correlation_with.csv"));write.csv(c42,file.path(dat_dir,"04_correlation_without.csv"))

# 005 Volcano with two shaded gene-set zones, dense neutral points, selected labels and bottom gene-set rugs.
n5<-2200;d5<-tibble(gene=paste0("Gene",seq_len(n5)),logFC=rnorm(n5,0,1.15),padj=pmin(1,10^(-rexp(n5,1.3)))) |>
  mutate(sig=case_when(logFC < -1 & padj<.03~"KRAS dependent",logFC>1 & padj<.03~"KRAS inhibited",TRUE~"NS"),score=-log10(padj))
d5$gene[sample(which(d5$sig!="NS"),12)]<-c("KRAS","FOSL1","MYC","DUSP6","SPARC","ACTA2","COL2A1","TAGLN","NPPA","FBLN5","PAM","ATP2A2")
lab5<-d5 |> filter(gene %in% c("KRAS","FOSL1","MYC","DUSP6","SPARC","ACTA2","COL2A1","TAGLN","NPPA","FBLN5","PAM","ATP2A2"))
p5 <- ggplot(d5,aes(logFC,score)) +
  annotate("rect",xmin=-Inf,xmax=-1,ymin=-Inf,ymax=Inf,fill="#CBDCF1",alpha=.27)+annotate("rect",xmin=1,xmax=Inf,ymin=-Inf,ymax=Inf,fill="#F3CDD0",alpha=.27)+
  geom_point(aes(colour=sig),size=.72,alpha=.55)+geom_hline(yintercept=-log10(.05),linetype=2,colour="#888888",linewidth=.35)+
  geom_vline(xintercept=c(-1,1),linetype=3,colour="#999999",linewidth=.3)+
  geom_text_repel(data=lab5,aes(label=gene),size=2.5,family=font,box.padding=.25,point.padding=.2,max.overlaps=Inf,seed=5,min.segment.length=0)+
  geom_rug(data=filter(d5,sig!="NS"),aes(colour=sig),sides="b",alpha=.45,linewidth=.22)+
  scale_colour_manual(values=c(`KRAS dependent`="#5C88B8",`KRAS inhibited`="#D46A70",NS="#B6B6B6"))+
  labs(x="KRAS vs NS siRNA (log2FC)",y="Significance (−log10 adjusted P)",colour=NULL)+theme_bf(9)+
  theme(legend.position="top",panel.grid.major.y=element_line(colour="#ECECEC",linewidth=.25))
savep(p5,"05_gene_set_volcano.png",150,112);write.csv(d5,file.path(dat_dir,"05_gene_set_volcano.csv"),row.names=FALSE)

# 006 Longitudinal line panel plus four aligned distribution summaries.
trt<-factor(c("NS","SMK","NS + abx","SMK + abx"),levels=c("NS","SMK","NS + abx","SMK + abx"));days6<-c(0,7,14,21,28,35)
d6<-expand_grid(treatment=trt,id=1:14,day=days6)|>mutate(base=c(NS=0,SMK=2,`NS + abx`=1,`SMK + abx`=3)[as.character(treatment)],
  value=pmax(0,day*c(NS=.15,SMK=.48,`NS + abx`=.08,`SMK + abx`=.32)[as.character(treatment)]+base+rnorm(n(),0,1.8)))
cols6<-c(NS="#565656",SMK="#43A2CA",`NS + abx`="#F0C33C",`SMK + abx`="#E66B49")
sum6<-d6|>group_by(treatment,day)|>summarise(mean=mean(value),se=sd(value)/sqrt(n()),.groups="drop")
main6<-ggplot(sum6,aes(day,mean,colour=treatment,group=treatment))+geom_line(linewidth=.85)+geom_point(size=2)+geom_errorbar(aes(ymin=mean-se,ymax=mean+se),width=.8,linewidth=.35)+
  scale_colour_manual(values=cols6)+scale_x_continuous(breaks=days6)+labs(x="Day",y="Weight change (%)",colour=NULL)+theme_bf(8)+theme(legend.position="top")
metric6<-d6|>group_by(treatment,id)|>summarise(rate=(last(value)-first(value))/35,auc=sum(value)*7,final=last(value),exposure=mean(value[day<=14]),.groups="drop")|>
  pivot_longer(rate:exposure,names_to="metric",values_to="value")|>mutate(metric=factor(metric,levels=c("rate","auc","final","exposure"),labels=c("Gain rate","iAUC","Final weight","Early exposure")))
small6<-ggplot(metric6,aes(treatment,value,colour=treatment))+geom_boxplot(width=.52,outlier.shape=NA,linewidth=.45)+
  ggbeeswarm::geom_quasirandom(width=.18,size=1.2,alpha=.8)+facet_wrap(~metric,scales="free_y",nrow=1)+scale_colour_manual(values=cols6)+
  labs(x=NULL,y=NULL)+theme_bf(7.2)+theme(legend.position="none",axis.text.x=element_text(angle=35,hjust=1),strip.text=element_text(size=8,face="bold"))
p6<-main6/small6+plot_layout(heights=c(1.05,1))
savep(p6,"06_longitudinal_multi_panel.png",185,132);write.csv(d6,file.path(dat_dir,"06_longitudinal_multi_panel.csv"),row.names=FALSE)

# 007 Exploded pie: only selected groups offset, leader lines and a separate legend.
genes7<-c("KRAS","None","EGFR","BRAF","NF1","MET amp","ERBB2 amp","RIT1","ALK fusion","ROS1 fusion","RET fusion","Other")
val7<-c(32.2,24.4,11.3,7,8.3,2.2,.9,2.2,1.3,1.7,.9,7.6);d7<-tibble(gene=genes7,value=val7)|>mutate(xmax=cumsum(value),xmin=lag(xmax,default=0),mid=(xmin+xmax)/2,
  focus=gene %in% c("NF1","MET amp","ERBB2 amp"),theta=mid/100*2*pi,
  x0=ifelse(focus,.10*sin(theta),0),y0=ifelse(focus,.10*cos(theta),0))
cols7<-setNames(c("#D95F45","#A8D8C1","#F6D7C8","#F0A993","#70B8D4","#5DA4C7","#247BA0","#8B3A3A","#B95656","#D97777","#E99A9A","#D6D6D6"),genes7)
p7<-ggplot(d7)+geom_arc_bar(aes(x0=x0,y0=y0,r0=0,r=1.0,start=xmin/100*2*pi,end=xmax/100*2*pi,fill=gene),colour="white",linewidth=.5)+
  geom_text(data=filter(d7,value>=7),aes(x=x0+.62*sin(theta),y=y0+.62*cos(theta),label=paste0(gene,"\n(",value,"%)")),family=font,size=2.8,colour="#222222")+
  scale_fill_manual(values=cols7)+coord_fixed(xlim=c(-1.35,1.55),ylim=c(-1.2,1.2),clip="off")+theme_void(base_family=font)+
  theme(legend.position="right",legend.text=element_text(size=7.5),legend.key.size=unit(3.5,"mm"),plot.margin=margin(5,8,5,5,"mm"))
savep(p7,"07_exploded_pie.png",165,105);write.csv(d7,file.path(dat_dir,"07_exploded_pie.csv"),row.names=FALSE)

# 008 OncoPrint with clinical annotations and mutation-frequency labels.
genes8<-c("TP53","KRAS","KEAP1","STK11","EGFR","NF1","BRAF","SETD2","RBM10","MGA","MET","ARID1A","PIK3CA","SMARCA4","RB1","CDKN2A")
samples8<-paste0("P",sprintf("%02d",1:72));types8<-c("Missense","Frameshift","Splice","Nonsense")
mat8<-matrix("",length(genes8),length(samples8),dimnames=list(genes8,samples8));probs<-seq(.56,.08,length.out=length(genes8))
for(i in seq_along(genes8)) for(j in seq_along(samples8)) if(runif(1)<probs[i]) mat8[i,j]<-sample(types8,1,prob=c(.55,.17,.15,.13))
ann8<-HeatmapAnnotation(Gender=sample(c("Male","Female"),72,TRUE),Smoking=sample(c("Ever","Never"),72,TRUE),
  col=list(Gender=c(Male="#4DBBD5",Female="#E64B35"),Smoking=c(Ever="#7E6148",Never="#B09C85")),
  annotation_name_gp=gpar(fontfamily=font,fontsize=7),annotation_legend_param=list(labels_gp=gpar(fontfamily=font,fontsize=7),title_gp=gpar(fontfamily=font,fontsize=8,face="bold")))
alter8<-list(background=function(x,y,w,h)grid.rect(x,y,w*.94,h*.94,gp=gpar(fill="#F4F4F4",col=NA)),
  Missense=function(x,y,w,h)grid.rect(x,y,w*.94,h*.72,gp=gpar(fill="#4DBBD5",col=NA)),Frameshift=function(x,y,w,h)grid.rect(x,y,w*.94,h*.72,gp=gpar(fill="#E64B35",col=NA)),
  Splice=function(x,y,w,h)grid.rect(x,y,w*.94,h*.72,gp=gpar(fill="#7E6148",col=NA)),Nonsense=function(x,y,w,h)grid.rect(x,y,w*.94,h*.72,gp=gpar(fill="#3C5488",col=NA)))
ht8<-oncoPrint(mat8,alter_fun=alter8,col=c(Missense="#4DBBD5",Frameshift="#E64B35",Splice="#7E6148",Nonsense="#3C5488"),top_annotation=ann8,
  remove_empty_columns=FALSE,show_column_names=FALSE,row_names_side="left",pct_side="right",row_names_gp=gpar(fontfamily=font,fontsize=7),
  column_order=order(colSums(mat8!=""),decreasing=TRUE),heatmap_legend_param=list(title="Alteration",labels_gp=gpar(fontfamily=font,fontsize=7)))
ragg::agg_png(file.path(fig_dir,"08_oncoprint_landscape.png"),width=190,height=112,units="mm",res=320,background="white")
draw(ht8,show_heatmap_legend=FALSE,show_annotation_legend=FALSE,padding=unit(c(4,5,13,5),"mm"))
lg8 <- packLegend(
  Legend(title="Alteration",at=types8,legend_gp=gpar(fill=c("#4DBBD5","#E64B35","#7E6148","#3C5488")),nrow=1,
         title_gp=gpar(fontfamily=font,fontsize=8,fontface="bold"),labels_gp=gpar(fontfamily=font,fontsize=7)),
  Legend(title="Gender",at=c("Male","Female"),legend_gp=gpar(fill=c("#4DBBD5","#E64B35")),nrow=1,
         title_gp=gpar(fontfamily=font,fontsize=8,fontface="bold"),labels_gp=gpar(fontfamily=font,fontsize=7)),
  Legend(title="Smoking",at=c("Ever","Never"),legend_gp=gpar(fill=c("#7E6148","#B09C85")),nrow=1,
         title_gp=gpar(fontfamily=font,fontsize=8,fontface="bold"),labels_gp=gpar(fontfamily=font,fontsize=7)),
  direction="horizontal",gap=unit(6,"mm"))
draw(lg8,x=unit(.5,"npc"),y=unit(.035,"npc"),just=c("center","bottom"));dev.off()
write.csv(mat8,file.path(dat_dir,"08_oncoprint_landscape.csv"))

# 009 Alluvial stacked proportions: two distinct biological stratifications.
cell9<-paste0("Type ",LETTERS[1:8]);time9<-factor(c("Uninjured","1 day","7 days","14 days","1 month","2 months"),levels=c("Uninjured","1 day","7 days","14 days","1 month","2 months"))
d9a<-expand_grid(time=time9,cell=cell9)|>group_by(time)|>mutate(raw=rgamma(n(),shape=runif(8,.8,4)),value=raw/sum(raw)*100,panel="Time course")|>ungroup()
region9<-factor(c("<1 mm","1–5 mm","5–10 mm","10–20 mm",">20 mm"),levels=c("<1 mm","1–5 mm","5–10 mm","10–20 mm",">20 mm"))
d9b<-expand_grid(time=region9,cell=cell9)|>group_by(time)|>mutate(raw=rgamma(n(),shape=runif(8,.8,5)),value=raw/sum(raw)*100,panel="Distance from injury")|>ungroup()
d9<-bind_rows(d9a,d9b)|>mutate(time=as.character(time),panel=factor(panel,levels=c("Time course","Distance from injury")))
p9<-ggplot(d9,aes(x=time,y=value,alluvium=cell,stratum=cell,fill=cell))+
  geom_alluvium(width=.54,alpha=.82,knot.pos=.48,colour=NA)+geom_stratum(width=.58,colour="white",linewidth=.28)+
  facet_wrap(~panel,scales="free_x",nrow=1)+scale_fill_manual(values=setNames(c("#335C81","#4F79A7","#83A7C5","#E6A2A6","#D97883","#F0D263","#B7C853","#4FB0A5"),cell9))+
  scale_y_continuous(labels=function(x)paste0(x,"%"),expand=c(0,0))+labs(x=NULL,y="Percentage of cells",fill="Cell type")+theme_bf(8)+
  theme(axis.text.x=element_text(angle=48,hjust=1),legend.position="bottom",legend.key.width=unit(4,"mm"),panel.spacing=unit(8,"mm"),panel.border=element_rect(colour="#333333",fill=NA,linewidth=.45))
savep(p9,"09_alluvial_stacked_composition.png",190,108);write.csv(d9,file.path(dat_dir,"09_alluvial_stacked_composition.csv"),row.names=FALSE)

# 010 Ten compact volcano panels with shared thresholds and non-overlapping labels.
d10<-expand_grid(cluster=factor(0:9,levels=0:9),gene=1:420)|>mutate(logFC=rnorm(n(),0,1.05),padj=pmin(1,10^(-rexp(n(),1.2))),score=-log10(padj),
  sig=case_when(logFC>1&padj<.01~"Up",logFC< -1&padj<.01~"Down",TRUE~"NS"))|>
  group_by(cluster)|>mutate(label=ifelse(rank(-score,ties.method="first")<=3,paste0("G",gene),NA_character_))|>ungroup()
p10<-ggplot(d10,aes(logFC,score))+geom_point(aes(colour=sig),size=.45,alpha=.55)+geom_vline(xintercept=c(-1,1),linetype=3,linewidth=.22,colour="#8A8A8A")+
  geom_hline(yintercept=2,linetype=3,linewidth=.22,colour="#8A8A8A")+geom_text_repel(data=filter(d10,!is.na(label)),aes(label=label),size=1.7,family=font,
    max.overlaps=Inf,box.padding=.12,point.padding=.08,segment.size=.18,min.segment.length=0,seed=10)+facet_wrap(~cluster,nrow=2)+
  scale_colour_manual(values=c(Down="#3F7CAC",NS="#B8B8B8",Up="#D95D65"))+coord_cartesian(xlim=c(-4,4),ylim=c(0,6),clip="off")+
  labs(x="log2 fold change",y="−log10 adjusted P",colour=NULL)+theme_bf(7)+theme(legend.position="top",strip.text=element_text(size=8,face="bold"),panel.spacing=unit(2.3,"mm"))
savep(p10,"10_multi_group_volcano.png",190,118);write.csv(d10,file.path(dat_dir,"10_multi_group_volcano.csv"),row.names=FALSE)

writeLines(capture.output(sessionInfo()),file.path(root,"results","tables","sessionInfo.txt"))
cat("Rendered TopJournal issues 001-010\n")
