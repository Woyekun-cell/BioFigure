#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(ggplot2); library(patchwork); library(dplyr); library(tidyr)
  library(ggrepel); library(ggnewscale); library(vegan); library(ggbeeswarm)
  library(tidygraph); library(ggraph); library(circlize); library(ape)
})

set.seed(20260917)
root <- normalizePath(file.path(dirname(commandArgs(trailingOnly = FALSE)[grep("--file=", commandArgs(trailingOnly = FALSE))]), ".."), mustWork = FALSE)
root <- sub("^--file=", "", root)
root <- normalizePath(file.path(dirname(root), ".."))
fig_dir <- file.path(root, "results", "figures")
data_dir <- file.path(root, "results", "plot_data")
tab_dir <- file.path(root, "results", "tables")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(tab_dir, recursive = TRUE, showWarnings = FALSE)

pal <- c("Control"="#56B4E9", "Treatment"="#E69F00", "Responder"="#3A78B4", "Non-responder"="#E56B5D")
theme_pub <- theme_classic(base_size = 9, base_family = "Arial") +
  theme(axis.title = element_text(face="bold"), plot.title = element_text(face="bold", size=11),
        legend.title = element_text(face="bold"), legend.key.height=unit(3.5,"mm"),
        plot.margin=margin(7,9,7,7))
savep <- function(i, slug, p, w=8, h=6, dpi=180) {
  f <- file.path(fig_dir, sprintf("%02d_%s.png", i, slug))
  ggsave(f, p, width=w, height=h, dpi=dpi, device=ragg::agg_png, bg="white")
}
write_data <- function(i, slug, x) write.csv(x, file.path(data_dir, sprintf("%02d_%s.csv", i, slug)), row.names=FALSE)

# 01 NMDS with source-like marginal boxplots and annotation block.
n <- 48; taxa <- matrix(rpois(n*28, lambda=8), n)
grp <- factor(rep(c("Control","Treatment"), each=n/2))
ord <- as.data.frame(metaMDS(taxa, k=2, trymax=30, trace=FALSE)$points)
names(ord) <- c("NMDS1","NMDS2"); ord$Group <- grp
ad <- adonis2(taxa ~ grp, method="bray")
p_main <- ggplot(ord,aes(NMDS1,NMDS2,color=Group,fill=Group))+
  stat_ellipse(geom="polygon",alpha=.13,color=NA)+geom_point(shape=21,size=2.6,stroke=.5)+
  annotate("label",x=min(ord$NMDS1),y=max(ord$NMDS2),hjust=0,vjust=1,
           label=sprintf("PERMANOVA\nR² = %.3f\nP = %.3f",ad$R2[1],ad$`Pr(>F)`[1]),size=3,label.size=.2)+
  scale_color_manual(values=pal)+scale_fill_manual(values=pal)+coord_equal()+theme_pub+theme(legend.position="bottom")
p_top <- ggplot(ord,aes(Group,NMDS1,fill=Group))+geom_boxplot(width=.55,outlier.shape=NA)+geom_jitter(width=.08,size=.7)+
  scale_fill_manual(values=pal)+theme_pub+theme(axis.title=element_blank(),axis.text.x=element_blank(),axis.ticks.x=element_blank(),legend.position="none")
p_right <- ggplot(ord,aes(Group,NMDS2,fill=Group))+geom_boxplot(width=.55,outlier.shape=NA)+geom_jitter(width=.08,size=.7)+
  scale_fill_manual(values=pal)+coord_flip()+theme_pub+theme(axis.title=element_blank(),axis.text.y=element_blank(),axis.ticks.y=element_blank(),legend.position="none")
p <- (p_top + plot_spacer()) / (p_main + p_right) + plot_layout(widths=c(4,1),heights=c(1,4))
savep(1,"nmds_marginal_box",p,8,8); write_data(1,"nmds_marginal_box",ord)

# 02 violin + two NMDS panels.
alpha <- data.frame(Group=rep(c("Control","Treatment"),each=28), Shannon=c(rnorm(28,3.1,.28),rnorm(28,3.55,.3)))
mk_ord <- function(seed,shift){set.seed(seed); d=data.frame(x=c(rnorm(28),rnorm(28,shift)),y=c(rnorm(28),rnorm(28,-shift/2)),Group=alpha$Group); d}
oa <- mk_ord(2,.8); ob <- mk_ord(3,.45)
pv <- ggplot(alpha,aes(Group,Shannon,fill=Group))+geom_violin(trim=FALSE,color=NA,alpha=.75)+geom_boxplot(width=.15,outlier.shape=NA,fill="white")+
  geom_jitter(width=.07,size=.65,alpha=.65)+scale_fill_manual(values=pal)+labs(title="Alpha diversity",x=NULL)+theme_pub+theme(legend.position="none")
nmds_panel <- function(d,title) ggplot(d,aes(x,y,color=Group,fill=Group))+stat_ellipse(geom="polygon",alpha=.12,color=NA)+geom_point(shape=21,size=2)+
  scale_color_manual(values=pal)+scale_fill_manual(values=pal)+coord_equal()+labs(title=title,x="NMDS1",y="NMDS2")+theme_pub+theme(legend.position="bottom")
p <- pv + nmds_panel(oa,"Bray–Curtis") + nmds_panel(ob,"Weighted UniFrac") + plot_layout(widths=c(.9,1,1),guides="collect")
savep(2,"violin_nmds",p,12,3.7); write_data(2,"violin_nmds",cbind(alpha, NMDS1=oa$x,NMDS2=oa$y))

# 03 immune-subset table forest.
cells <- c("CD8 T cells","CD4 memory T cells","NK cells","B cells","Monocytes","Dendritic cells","Macrophages","Mast cells")
f3 <- data.frame(cell=cells,HR=c(.62,.78,1.35,.91,1.52,.73,1.18,.84),lo=c(.42,.55,.92,.63,1.08,.48,.82,.57),hi=c(.91,1.10,1.98,1.31,2.14,1.10,1.70,1.23),p=c(.018,.16,.11,.61,.017,.13,.38,.37))
f3$y <- rev(seq_len(nrow(f3))); f3$label <- sprintf("%.2f (%.2f–%.2f)",f3$HR,f3$lo,f3$hi)
p <- ggplot(f3)+geom_rect(aes(xmin=-1.35,xmax=5.1,ymin=y-.48,ymax=y+.48,fill=factor(y%%2)),show.legend=FALSE)+
  scale_fill_manual(values=c("0"="white","1"="#F4F6F8"))+geom_vline(xintercept=1,lty=2,color="#8C8C8C")+
  geom_errorbarh(aes(y=y,xmin=lo,xmax=hi),height=.18,color="#2F4B66")+geom_point(aes(HR,y),shape=21,size=2.6,fill="#3E88C8",color="white",stroke=.5)+
  geom_text(aes(-1.25,y,label=sprintf("%02d",seq_along(cell))),hjust=0,size=3,color="white",fontface="bold")+
  geom_point(aes(-1.05,y),shape=21,size=5,fill="#405C78",color=NA)+geom_text(aes(-.72,y,label=cell),hjust=0,size=3.1)+
  geom_text(aes(2.4,y,label=label),hjust=0,size=2.8)+geom_text(aes(4.55,y,label=ifelse(p<.05,sprintf("%.3f*",p),sprintf("%.3f",p))),hjust=1,size=2.8)+
  annotate("text",x=c(-.72,1,2.4,4.55),y=9,label=c("Immune subset","Hazard ratio","HR (95% CI)","P value"),fontface="bold",size=3.2,hjust=c(0,.5,0,1))+
  coord_cartesian(xlim=c(-1.35,5.05),ylim=c(.4,9.4),clip="off")+theme_void(base_family="Arial")+theme(plot.margin=margin(8,8,8,8))
savep(3,"immune_forest",p,11,4.9); write_data(3,"immune_forest",f3)

# 04 paired subgroup forest with table columns.
subs <- c("All patients","Age < 60","Age ≥ 60","Male","Female","Stage I–II","Stage III–IV","Biomarker low","Biomarker high")
f4 <- expand.grid(subgroup=subs, arm=c("Model A","Model B"), stringsAsFactors=FALSE) |>
  mutate(y=rep(rev(seq_along(subs)),each=2)+ifelse(arm=="Model A",.14,-.14), HR=exp(rnorm(n(),log(.82),.28)), se=runif(n(),.12,.24), lo=pmax(.18,HR*exp(-1.96*se)),hi=HR*exp(1.96*se))
p <- ggplot(f4)+geom_rect(data=data.frame(y=rev(seq_along(subs))),aes(xmin=.15,xmax=5.2,ymin=y-.48,ymax=y+.48,fill=factor(y%%2)),inherit.aes=FALSE,show.legend=FALSE)+
  scale_fill_manual(values=c("0"="white","1"="#F6F7F9"))+geom_vline(xintercept=1,lty=2,color="grey55")+
  geom_errorbarh(aes(y=y,xmin=lo,xmax=hi,color=arm),height=.08,linewidth=.7)+geom_point(aes(HR,y,color=arm,shape=arm),size=2.1)+
  geom_text(data=data.frame(subgroup=subs,y=rev(seq_along(subs))),aes(.18,y,label=subgroup),hjust=0,size=3)+
  geom_text(aes(3.05,y,label=sprintf("%.2f (%.2f–%.2f)",HR,lo,hi),color=arm),hjust=0,size=2.45)+
  annotate("text",x=c(.18,1,3.05),y=10,label=c("Subgroup","Hazard ratio","Estimate (95% CI)"),fontface="bold",hjust=c(0,.5,0),size=3.1)+
  scale_color_manual(values=c("Model A"="#2B6FA6","Model B"="#D95F4C"))+coord_cartesian(xlim=c(.15,5.2),ylim=c(.3,10.5),clip="off")+
  theme_void(base_family="Arial")+theme(legend.position="bottom",plot.margin=margin(8,8,8,8))
savep(4,"dual_hr_forest",p,9.4,8); write_data(4,"dual_hr_forest",f4)

# 05 swimmer plot with response segments, events and separate legends.
sw <- data.frame(id=factor(sprintf("P%02d",1:18),levels=sprintf("P%02d",18:1)),arm=rep(c("Cohort A","Cohort B"),9),dur=runif(18,8,30),resp=runif(18,2,8),ongoing=sample(c(TRUE,FALSE),18,TRUE))
ev <- sw |> transmute(id, t=pmin(dur-1,resp+runif(18,2,10)), event=sample(c("PR","CR","PD"),18,TRUE))
p <- ggplot(sw,aes(y=id))+geom_segment(aes(x=0,xend=dur,yend=id,color=arm),linewidth=3,lineend="round")+
  geom_segment(aes(x=resp,xend=dur,yend=id),linewidth=3,color="#78B7B2",lineend="round")+
  geom_point(data=ev,aes(x=t,shape=event),size=2.7,fill="white",color="#20252A")+
  geom_point(data=subset(sw,ongoing),aes(x=dur),shape=24,size=2.8,fill="#20252A")+
  scale_color_manual(values=c("Cohort A"="#C95E75","Cohort B"="#516DA8"))+scale_shape_manual(values=c(PR=21,CR=23,PD=4))+
  labs(x="Months from treatment",y=NULL,color="Cohort",shape="Best response")+theme_pub+theme(panel.grid.major.x=element_line(color="#E8EAED"),legend.position="right")
savep(5,"swimmer",p,10.5,6); write_data(5,"swimmer",merge(sw,ev,by="id"))

# 06 table heatmap uses funkyheatmap's mixed-glyph renderer.
genes <- paste0("Gene ",LETTERS[1:12]); f6 <- data.frame(id=genes,Class=rep(c("Innate","Adaptive","Stromal"),each=4),Effect=runif(12),Evidence=runif(12),Fraction=runif(12),Direction=sample(c("Up","Down"),12,TRUE))
ci6 <- data.frame(id=c("Class","Effect","Evidence","Fraction","Direction"),name=c("Class","Effect","Evidence","Fraction","Direction"),geom=c("text","rect","circle","bar","text"),group=c("Identity","Quantitative","Quantitative","Quantitative","Identity"),palette=c(NA,"effect","evidence","fraction",NA),stringsAsFactors=FALSE)
p <- funkyheatmap::funky_heatmap(f6,column_info=ci6,scale_column=TRUE,add_abc=FALSE)+plot_annotation(theme=theme(text=element_text(family="Arial")))
savep(6,"table_heatmap",p,8.6,7.6); write_data(6,"table_heatmap",f6)

# Shared volcano and enrichment helpers for 07–09.
volc_data <- function(seed){set.seed(seed); d=data.frame(gene=paste0("G",1:500),logFC=rnorm(500,0,1.25),p=runif(500)); d$mlog=-log10(d$p); d$class=ifelse(d$p<.04 & d$logFC>1,"Up",ifelse(d$p<.04 & d$logFC< -1,"Down","NS")); d}
volc <- function(d,title="Differential expression") ggplot(d,aes(logFC,mlog,color=class))+geom_point(size=.9,alpha=.75)+geom_vline(xintercept=c(-1,1),lty=2,color="grey55")+geom_hline(yintercept=-log10(.04),lty=2,color="grey55")+scale_color_manual(values=c(Down="#2D79B7",NS="#C9CDD2",Up="#D95852"))+labs(title=title,x="log2 fold change",y="-log10 P")+theme_pub+theme(legend.position="top")
enrich_bar <- function(side){d=data.frame(term=paste(c("Cytokine signaling","Lipid metabolism","Cell cycle","ECM organization","Oxidative stress"),side),score=sort(runif(5,2,6)));ggplot(d,aes(score,reorder(term,score),fill=score))+geom_col(width=.68)+scale_fill_gradient(low="#F6D6C9",high=if(side=="Up")"#B5354B" else "#2B6CA3")+labs(title=paste(side,"pathways"),x="-log10 FDR",y=NULL)+theme_pub+theme(legend.position="none")}
d7 <- volc_data(7); p <- volc(d7)+enrich_bar("Up")+enrich_bar("Down")+plot_layout(widths=c(1.15,1,1));savep(7,"volcano_enrichment_1",p,12,4);write_data(7,"volcano_enrichment_1",d7)
d8 <- volc_data(8); p <- enrich_bar("Down")+volc(d8,"Contrasts")+enrich_bar("Up")+plot_layout(widths=c(1,1.2,1));savep(8,"volcano_enrichment_2",p,12,4.4);write_data(8,"volcano_enrichment_2",d8)

# 09 enrichment network is rendered by aPEAR from source-like enrichment columns.
d9 <- volc_data(9); genes9 <- paste0("G",1:90)
nodes <- data.frame(ID=paste0("P",1:20),Description=paste("Pathway",1:20),p.adjust=10^runif(20,-6,-2),NES=rnorm(20),setSize=sample(15:45,20),core_enrichment=sapply(1:20,function(i)paste(sample(genes9,18),collapse="/")))
pnet <- aPEAR::enrichmentNetwork(nodes,simMethod="jaccard",clustMethod="hier",drawEllipses=TRUE,fontSize=3,repelLabels=TRUE,minClusterSize=2)+theme(legend.position="bottom")
p <- volc(d9)+pnet+plot_layout(widths=c(.95,1.2));savep(9,"volcano_enrichment_network",p,11,5.3);write_data(9,"volcano_enrichment_network",nodes)

# Circular multi-track composites (10–11) implemented with polar layers plus central inset.
ring <- expand.grid(gene=paste0("G",sprintf("%02d",1:36)),track=c("RNA","ATAC","Protein"));ring$idx=as.integer(factor(ring$gene));ring$value=rnorm(nrow(ring));ring$track_y=as.integer(factor(ring$track))*1.2+ring$value*.32
pring <- ggplot(ring,aes(idx,track_y,fill=value))+geom_tile(width=.92,height=.78,color="white",linewidth=.15)+coord_polar()+scale_fill_gradient2(low="#2467A4",mid="white",high="#D24B4B")+theme_void()+theme(legend.position="bottom")
sets <- data.frame(x=c(-.55,.55,0),y=c(.15,.15,-.38),lab=c("A","B","C"),n=c(18,14,11))
upbars <- data.frame(x=1:5,n=c(18,14,11,7,5)); updots <- expand.grid(x=1:5,set=1:3); updots$on=c(1,0,0, 0,1,0, 0,0,1, 1,1,0, 1,0,1)
pcenter <- ggplot()+geom_col(data=upbars,aes(x,n),fill="#3686B8",width=.65)+geom_segment(data=subset(updots,on==1) |> group_by(x) |> summarise(y=min(set),yend=max(set)),aes(x=x,xend=x,y=y,yend=yend),linewidth=.5)+geom_point(data=updots,aes(x,set,fill=factor(on)),shape=21,size=2.1)+scale_fill_manual(values=c("0"="#E1E5E8","1"="#222831"),guide="none")+scale_y_continuous(breaks=1:3,labels=c("A","B","C"),sec.axis=sec_axis(~.,name=NULL))+theme_classic(base_size=7)+theme(axis.title=element_blank(),axis.text.x=element_blank(),axis.ticks.x=element_blank(),plot.margin=margin(2,2,2,2))
p <- pring + inset_element(pcenter,.28,.28,.72,.72);savep(10,"circular_heatmap_upset",p,8,8);write_data(10,"circular_heatmap_upset",ring)
pvenn <- ggplot(sets,aes(x,y))+geom_point(aes(size=n,fill=lab),shape=21,alpha=.36,color="#374151",stroke=.7)+geom_text(aes(label=lab),fontface="bold",size=4)+scale_size(range=c(35,45),guide="none")+scale_fill_manual(values=c(A="#4C83C3",B="#E58A50",C="#57A66B"),guide="none")+coord_equal(xlim=c(-1.25,1.25),ylim=c(-1.25,1.25))+theme_void()
p <- pring + inset_element(pvenn,.27,.27,.73,.73);savep(11,"circular_heatmap_venn",p,8,8);write_data(11,"circular_heatmap_venn",ring)

# 12 half violin / raincloud arranged radially.
d12 <- expand.grid(group=paste0("Cell ",1:8),rep=1:22);d12$value=rnorm(nrow(d12),rep(seq(-.8,.8,length.out=8),each=22),.38)
p <- ggplot(d12,aes(group,value,fill=group))+geom_violin(trim=FALSE,width=.92,color="white",linewidth=.25)+geom_boxplot(width=.12,outlier.shape=NA,fill="white",linewidth=.3)+geom_quasirandom(size=.45,alpha=.42,width=.14)+coord_radial(theta="x",start=-pi/2,end=pi/2,inner.radius=.32,clip="off")+scale_fill_brewer(palette="Set2")+theme_void(base_family="Arial")+theme(legend.position="none",plot.margin=margin(35,35,35,35))
savep(12,"semicircle_violin",p,8,8);write_data(12,"semicircle_violin",d12)

# 13 fan boxplots with points and central title.
d13 <- expand.grid(group=paste0("T",1:12),rep=1:18);d13$value=runif(nrow(d13),1,5)+rep(seq(0,2,length.out=12),each=18)
p <- ggplot(d13,aes(group,value,fill=group))+geom_boxplot(width=.72,outlier.shape=NA,linewidth=.35)+geom_quasirandom(size=.35,alpha=.42,width=.16)+coord_radial(theta="x",start=-pi/2,end=pi/2,inner.radius=.3,clip="off")+scale_fill_manual(values=hcl.colors(12,"Spectral"))+ylim(0,8)+annotate("text",x=6.5,y=.45,label="Expression\nacross groups",fontface="bold",size=4)+theme_void(base_family="Arial")+theme(legend.position="none",plot.margin=margin(30,30,30,30))
savep(13,"fan_boxplot",p,8,8);write_data(13,"fan_boxplot",d13)

# 14 circular grouped trajectories with significance ring.
d14 <- expand.grid(group=c("Control","Treatment","Recovery"),time=1:36);d14$value=ifelse(d14$group=="Control",3.2,ifelse(d14$group=="Treatment",4.0,2.5))+sin(d14$time/3+as.integer(factor(d14$group)))*.55+rnorm(nrow(d14),0,.08)
sig <- data.frame(time=1:36,y=5.55,lab=ifelse(1:36 %in% c(4,5,11,18,24,31,32),"*",""),name=paste0("Feature ",1:36),angle=90-(1:36-.5)*360/36)
p <- ggplot(d14,aes(time,value,color=group,group=group))+geom_hline(yintercept=2:5,color="#E4E7EA",linewidth=.28)+geom_line(linewidth=.72)+geom_point(size=1.15)+geom_text(data=sig,aes(time,5.55,label=lab),inherit.aes=FALSE,size=3.4)+geom_text(data=sig,aes(time,6.05,label=name,angle=angle),inherit.aes=FALSE,size=1.65,hjust=ifelse(sig$angle< -90,1,0))+coord_polar(clip="off")+scale_color_manual(values=c(Control="#45A7D9",Treatment="#E98A00",Recovery="#D04C59"))+labs(color=NULL)+ylim(0,6.25)+theme_void(base_family="Arial")+theme(legend.position="bottom",plot.margin=margin(38,38,38,38))
savep(14,"circular_trajectory",p,8,8);write_data(14,"circular_trajectory",d14)

# 15 nested bars with two scales and source-like embedded bars.
d15 <- data.frame(group=paste0("Strain ",1:16),DrugA=runif(16,.6,2.7),DrugB=runif(16,45,155));d15$group=factor(d15$group,levels=d15$group)
p <- ggplot(d15,aes(group))+geom_col(aes(y=DrugA,fill="Drug A"),width=.68,alpha=.82)+geom_col(aes(y=DrugB/60,fill="Drug B"),width=.34,alpha=.78)+geom_point(aes(y=DrugA),shape=21,size=1.7,fill="white")+geom_point(aes(y=DrugB/60),shape=21,size=1.7,fill="#6A8CAF")+scale_fill_manual(values=c("Drug A"="#DDEAF3","Drug B"="#F1DDA2"),name=NULL)+scale_y_continuous(name="Drug A (OD600)",sec.axis=sec_axis(~.*60,name="Drug B (ng/mL)"))+labs(x=NULL)+theme_pub+theme(axis.text.x=element_text(angle=52,hjust=1),legend.position="top",panel.grid.major.y=element_line(color="#ECEEF0"))
savep(15,"nested_bar",p,10,5);write_data(15,"nested_bar",d15)

# 16–17 circular network plus outer bar/bubble tracks using ggraph/tidygraph.
make_tree <- function(seed){set.seed(seed); cats=paste0("Module ",1:8); leaves=unlist(lapply(1:8,function(i)paste0("M",i,"_",1:8))); nd=data.frame(name=c("Core",cats,leaves),type=c("root",rep("category",8),rep("leaf",64)),value=runif(73,1,8),group=c("Core",LETTERS[1:8],rep(LETTERS[1:8],each=8))); ed=rbind(data.frame(from=1,to=2:9),do.call(rbind,lapply(1:8,function(i)data.frame(from=i+1,to=(10:73)[((i-1)*8+1):(i*8)]))));tbl_graph(nd,ed,directed=TRUE)}
g16 <- make_tree(16)
p16 <- ggraph(g16,layout="dendrogram",circular=TRUE)+geom_edge_diagonal(aes(color=node1.group),alpha=.5,show.legend=FALSE)+geom_node_point(aes(size=ifelse(type=="leaf",value,ifelse(type=="category",3,.8)),fill=group),shape=21,color="white")+geom_node_text(aes(label=ifelse(type=="leaf",name,ifelse(type=="category",name,"")),filter=type!="root",color=group),size=2.15,repel=FALSE)+scale_fill_manual(values=c(Core="#666666",setNames(hcl.colors(8,"Dark 3"),LETTERS[1:8])))+scale_color_manual(values=c(Core="#666666",setNames(hcl.colors(8,"Dark 3"),LETTERS[1:8])))+scale_size(range=c(1,6),guide="none")+theme_void()+theme(legend.position="none",plot.margin=margin(30,30,30,30))
savep(16,"network_circular_bar",p16,8,8);write_data(16,"network_circular_bar",as.data.frame(activate(g16,nodes)))
g17 <- make_tree(17)
p17 <- ggraph(g17,layout="dendrogram",circular=TRUE)+geom_edge_diagonal(aes(alpha=after_stat(index)),color="#98A3AE")+geom_node_point(aes(size=value,color=value,shape=group),alpha=.9)+geom_node_text(aes(label=ifelse(type=="leaf",name,""),filter=type=="leaf"),size=2.0)+scale_color_viridis_c(option="C")+scale_shape_manual(values=setNames(rep(c(21,22,23,24),2),LETTERS[1:8]))+scale_size(range=c(1.2,6))+theme_void()+theme(legend.position="bottom",plot.margin=margin(30,30,30,30))
savep(17,"network_circular_bubble",p17,8,8);write_data(17,"network_circular_bubble",as.data.frame(activate(g17,nodes)))

# 18 circular lollipop with correlation links.
d18 <- data.frame(feature=paste0("M",1:40),value=runif(40,.25,1),group=rep(LETTERS[1:8],each=5));d18$i=1:40
links <- data.frame(from=sample(d18$feature,24),to=sample(d18$feature,24),corr=runif(24,-1,1))
f18 <- file.path(fig_dir,"18_circular_lollipop_links.png"); ragg::agg_png(f18,width=1440,height=1440,res=180,bg="white")
circos.clear();circos.par(start.degree=90,gap.degree=rep(c(2,1,1,1,3),8),cell.padding=c(0,0,0,0),track.margin=c(.006,.006))
circos.initialize(factors=d18$feature,xlim=cbind(rep(0,40),rep(1,40)))
cols=setNames(hcl.colors(8,"Dark 3"),LETTERS[1:8])
circos.trackPlotRegion(ylim=c(0,1),track.height=.14,bg.border=NA,panel.fun=function(x,y){s=CELL_META$sector.index;row=d18[d18$feature==s,];circos.lines(c(.5,.5),c(0,row$value),col=cols[row$group],lwd=1.3);circos.points(.5,row$value,pch=16,cex=.7,col=cols[row$group]);circos.text(.5,1.12,s,cex=.42,facing="clockwise",niceFacing=TRUE,adj=c(0,.5),col=cols[row$group])})
for(i in seq_len(nrow(links))){co=if(links$corr[i]>0)adjustcolor("#D55E5E",.25) else adjustcolor("#3C78B5",.25);circos.link(links$from[i],.5,links$to[i],.5,col=co,border=NA)}
title("Correlation landscape",cex.main=.9);dev.off();circos.clear();write_data(18,"circular_lollipop_links",d18)

# 19–20 fan phylogeny plus aligned heatmap/bar tracks (ggtree family semantics).
tr <- rtree(28); tr$tip.label <- paste0("Taxon_",sprintf("%02d",1:28)); tip_order <- tr$tip.label
mat <- expand.grid(label=tip_order,track=c("Genome","Habitat","Trait"));mat$value=rnorm(nrow(mat));mat$x=as.integer(factor(mat$track))+1.2
ptree <- ggtree::ggtree(tr,layout="fan",open.angle=18,size=.35,color="#77808A")+ggtree::geom_tiplab2(size=1.9,offset=.35,align=TRUE,linesize=.2)
p19 <- ptree + ggtreeExtra::geom_fruit(data=mat,geom=geom_tile,mapping=aes(y=label,x=track,fill=value),offset=.06,pwidth=.45,width=.82,height=.82)+scale_fill_gradient2(low="#2866A4",mid="white",high="#C7434B")+theme(legend.position="bottom",plot.margin=margin(15,35,15,15))
savep(19,"phylogeny_three_heatmaps",p19,10.5,7.6);write_data(19,"phylogeny_three_heatmaps",mat)
mat2 <- expand.grid(label=tip_order,track=c("Clade","Status"));mat2$value=rnorm(nrow(mat2));bars=data.frame(label=tip_order,coef=rnorm(28))
p20 <- ptree + ggtreeExtra::geom_fruit(data=mat2,geom=geom_tile,mapping=aes(y=label,x=track,fill=value),offset=.05,pwidth=.25,width=.8,height=.82)+scale_fill_gradient2(low="#3374B8",mid="white",high="#D95F4C")+
  ggnewscale::new_scale_fill()+ggtreeExtra::geom_fruit(data=bars,geom=geom_col,mapping=aes(y=label,x=abs(coef),fill=coef>0),offset=.04,pwidth=.35,width=.72)+scale_fill_manual(values=c("TRUE"="#D95F4C","FALSE"="#3F7FB5"),name="Coefficient")+theme(legend.position="bottom",plot.margin=margin(15,30,15,15))
savep(20,"phylogeny_heatmap_bar",p20,10,8);write_data(20,"phylogeny_heatmap_bar",merge(mat2,bars,by="label"))

writeLines(capture.output(sessionInfo()),file.path(tab_dir,"sessionInfo.txt"))
message("Rendered 20 figures to ",fig_dir)
