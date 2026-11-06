#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(patchwork)
  library(ragg)
})

set.seed(20260913)
root <- normalizePath(file.path(dirname(commandArgs(trailingOnly = FALSE)[grep("--file=", commandArgs(trailingOnly = FALSE))] |> sub("--file=", "", x = _)), ".."))
fig_dir <- file.path(root, "results", "figures")
data_dir <- file.path(root, "results", "plot_data")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)

font_family <- "Arial"
if (!font_family %in% systemfonts::system_fonts()$family) stop("Arial is unavailable")
theme_bf <- function(base_size = 10) {
  theme_classic(base_size = base_size, base_family = font_family) +
    theme(text = element_text(family = font_family, colour = "black"),
          axis.text = element_text(colour = "black"),
          legend.key = element_blank(), plot.background = element_rect(fill = "white", colour = NA))
}
save_plot <- function(plot, filename, width_mm, height_mm, dpi = 300) {
  ggsave(file.path(fig_dir, filename), plot, width = width_mm, height = height_mm,
         units = "mm", dpi = dpi, device = ragg::agg_png, bg = "white")
}

# 055 / issue 048: graph topology + community detection + stress layout + cluster hulls.
suppressPackageStartupMessages({library(igraph); library(ggraph); library(graphlayouts); library(ggforce)})
sizes <- c(48,44,41,38,36,34,32,30,28,26,24,22)
pref <- matrix(0.00005, length(sizes), length(sizes)); diag(pref) <- seq(0.13, 0.21, length.out = length(sizes))
net <- sample_sbm(sum(sizes), pref, sizes, directed = FALSE, loops = FALSE)
cluster_starts <- cumsum(c(1,head(sizes,-1)))
cluster_ends <- cumsum(sizes)
bridges <- as.vector(rbind(cluster_ends[-length(cluster_ends)],cluster_starts[-1]))
net <- add_edges(net,bridges)
net <- simplify(net)
net <- induced_subgraph(net,which(components(net)$membership==which.max(components(net)$csize)))
communities <- cluster_louvain(net)
V(net)$cluster <- factor(membership(communities))
V(net)$degree <- degree(net)
edge_ends <- ends(net, E(net))
member <- membership(communities)
E(net)$same_cluster <- member[edge_ends[, 1]] == member[edge_ends[, 2]]
xy <- graphlayouts::layout_with_stress(net)
layout_df <- create_layout(net, layout = xy)
pal <- hcl.colors(nlevels(V(net)$cluster), "Dark 3")
p055 <- ggraph(layout_df) +
  ggforce::geom_mark_hull(aes(x = x, y = y, group = cluster, fill = cluster),
                          alpha = .075, colour = "grey65", linewidth = .18,
                          concavity = 4, expand = unit(1.3, "mm"), show.legend = FALSE) +
  geom_edge_link(aes(alpha = same_cluster), colour = "grey45", linewidth = .16,
                 show.legend = FALSE) +
  geom_node_point(aes(fill = cluster, size = degree), shape = 21, colour = "white", stroke = .16) +
  scale_fill_manual(values = pal, guide = "none") +
  scale_size(range = c(.9, 2.4), guide = "none") +
  scale_edge_alpha_manual(values = c(`FALSE` = .20, `TRUE` = .42)) +
  coord_equal(clip = "off") + theme_void(base_family = font_family) +
  theme(plot.margin = margin(4, 4, 4, 4, "mm"))
write.csv(as_data_frame(net, what = "edges"), file.path(data_dir, "figure_055_network_edges.csv"), row.names = FALSE)
save_plot(p055, "figure_055_cluster_network_code_driven.png", 170, 150)

# 058 / issue 051: exact galaxy density mechanism from source code.
make_cloud <- function(n, centres, sd = .55) {
  k <- sample(seq_len(nrow(centres)), n, TRUE, centres$weight)
  tibble(UMAP_1 = rnorm(n, centres$x[k], sd), UMAP_2 = rnorm(n, centres$y[k], sd))
}
luad <- make_cloud(1674, tibble(x=c(-1.9,-.3,1.8), y=c(4.5,5.9,-1.8), weight=c(.28,.27,.45)), .48) |> mutate(Field="LUAD\n(n = 1,674)")
nl <- make_cloud(8359, tibble(x=c(-1.6,.4,2.0), y=c(4.3,-.8,.1), weight=c(.18,.48,.34)), .58) |> mutate(Field="NL\n(n = 8,359)")
galaxy <- bind_rows(luad, nl)
hulls <- galaxy |> group_by(Field) |> slice(chull(UMAP_1, UMAP_2))
p058 <- ggplot(galaxy, aes(UMAP_1, UMAP_2)) +
  stat_density_2d(aes(fill = after_stat(density)), geom = "raster", contour = FALSE) +
  geom_polygon(data = hulls, aes(group = Field), fill = NA, colour = "white", linewidth = .35, linetype = "dashed") +
  geom_point(colour = "white", size = .10, alpha = .78) +
  annotate("text", x = .2, y = 3.7, label = "KACs", colour = "white", family = font_family, size = 4.0) +
  annotate("text", x = -1.4, y = .2, label = "Other AICs", colour = "white", family = font_family, size = 3.8) +
  facet_wrap(~Field, nrow = 1) + viridis::scale_fill_viridis(option = "magma", guide = "none") +
  coord_equal() + labs(x = "UMAP 1", y = "UMAP 2") +
  theme_bf(10) + theme(panel.background = element_rect(fill="black", colour="white", linewidth=.4),
                       plot.background = element_rect(fill="black", colour=NA),
                       panel.grid = element_blank(), axis.text = element_text(colour="white"),
                       axis.title = element_text(colour="white"), axis.ticks = element_line(colour="white"),
                       strip.background = element_rect(fill="grey30", colour="grey20"),
                       strip.text = element_text(colour="white", size=10))
write.csv(galaxy, file.path(data_dir, "figure_058_galaxy.csv"), row.names = FALSE)
save_plot(p058, "figure_058_galaxy_density_code_driven.png", 178, 94)

# 059 / issue 052: patient-level spider trajectories, split by genotype using patchwork.
make_patient <- function(id, genetic) {
  times <- sort(unique(c(0, sample(2:36, sample(3:7,1)))))
  slope <- if (genetic == "PPP2R1A mut") rnorm(1,-2.0,2.6) else rnorm(1,-.3,3.5)
  vals <- pmax(-100, pmin(120, slope*times + c(0,cumsum(rnorm(length(times)-1,0,18)))))
  tibble(Acc=id, Genetic=genetic, Time_mo=times, pct_change_from_BL=vals)
}
groups <- c(rep("AKT mut",7), rep("PPP2R1A and AKT WT",8), rep("PPP2R1A mut",8))
spider <- bind_rows(Map(make_patient, sprintf("P%02d", seq_along(groups)), groups))
cols_spider <- c("AKT mut"="#82cbbb", "PPP2R1A and AKT WT"="#8dbbda", "PPP2R1A mut"="#f7b66c")
spider_panel <- function(d, show_y=TRUE) ggplot(d, aes(Time_mo,pct_change_from_BL,group=Acc,colour=Genetic)) +
  geom_line(linewidth=.7, alpha=.88) + geom_hline(yintercept=-30, linetype="dashed", linewidth=.45) +
  scale_color_manual(values=cols_spider, name=NULL) +
  scale_x_continuous(limits=c(0,38), breaks=c(0,12,24,36), minor_breaks=seq(0,36,3)) +
  scale_y_continuous(limits=c(-105,125), breaks=c(-100,-50,0,50,100)) +
  labs(x="Time after baseline (months)", y=if(show_y) "Percentage change from the baseline" else NULL) +
  theme_bf(9) + theme(legend.position="bottom", panel.grid=element_blank())
p059 <- spider_panel(filter(spider, Genetic != "PPP2R1A mut"), TRUE) +
  spider_panel(filter(spider, Genetic == "PPP2R1A mut"), FALSE) +
  plot_layout(guides="collect") & theme(legend.position="bottom")
write.csv(spider, file.path(data_dir, "figure_059_spider.csv"), row.names = FALSE)
save_plot(p059, "figure_059_spider_code_driven.png", 180, 92)

# 060 / issue 053: swimplot bars, response events and aligned clinical annotation tracks.
suppressPackageStartupMessages({library(swimplot); library(ggnewscale)})
npat <- 31
endpoint <- tibble(Acc=sprintf("%03d",101:(100+npat)), Time_mo=sort(runif(npat,4,72)),
                   Genetic=sample(c("AKTalt","No","PPP2R1Amut"),npat,TRUE,prob=c(.24,.51,.25)),
                   PPP2R1A_mutation=as.integer(Genetic=="PPP2R1Amut")) |> arrange(PPP2R1A_mutation,Time_mo)
event_rows <- lapply(seq_len(npat), function(i) {
  k <- sample(1:5,1); t <- sort(runif(k,1,endpoint$Time_mo[i]));
  tibble(Acc=endpoint$Acc[i],Time_mo=t,overallResponse=sample(c("PD","SD","PR","CR"),k,TRUE,prob=c(.25,.35,.3,.1)))
}) |> bind_rows()
ongoing <- endpoint |> filter(Time_mo > 45) |> transmute(Acc, Time_mo=Time_mo-.5, overallResponse="Ongoing")
timeline <- bind_rows(event_rows,ongoing)
endpoint_df <- as.data.frame(endpoint)
timeline_df <- as.data.frame(timeline)
p_swim <- swimmer_plot(endpoint_df,id="Acc",end="Time_mo",name_fill="Genetic",id_order="PPP2R1A_mutation",increasing=FALSE,col="grey25",alpha=1,width=.74) +
  swimmer_points(as.data.frame(filter(timeline,overallResponse!="Ongoing")),id="Acc",time="Time_mo",name_shape="overallResponse",name_col="overallResponse",size=2.0) +
  swimmer_arrows(as.data.frame(filter(timeline,overallResponse=="Ongoing")),id="Acc",arrow_start="Time_mo",cont="overallResponse",name_col="overallResponse",color="#1D76BD",type="open",cex=.7,arrow_positions=c(.1,2),angle=30) +
  coord_flip(clip="off",ylim=c(0,76)) + scale_y_continuous(breaks=seq(0,72,12),expand=c(.02,0)) +
  scale_fill_manual(name="Patient group",values=c(AKTalt="#82cbbb",No="#8dbbda",PPP2R1Amut="#f7b66c")) +
  scale_colour_manual(name="Overall response",values=c(PD="#df3b2f",SD="#222222",PR="#e9cf31",CR="#15945b",Death="#222222"),breaks=c("PD","SD","PR","CR")) +
  scale_shape_manual(name="Overall response",values=c(PD=17,SD=16,PR=15,CR=5),breaks=c("PD","SD","PR","CR")) +
  labs(y="Months since baseline",x=NULL) + theme_bf(8) +
  theme(axis.text.y=element_blank(),axis.ticks.y=element_blank(),legend.position="bottom")
meta <- endpoint |> transmute(Acc=factor(Acc,levels=rev(endpoint$Acc)),
  `Clinical trial`=sample(c("NCT03026062","NCT01928394"),npat,TRUE),
  `Treatment arm`=sample(c("Combination","Sequential"),npat,TRUE),
  `ARID1A mut`=sample(c("Yes","No"),npat,TRUE)) |>
  pivot_longer(-Acc,names_to="var",values_to="value")
p_meta <- ggplot(meta,aes(var,Acc,fill=value)) + geom_tile(colour="white",linewidth=.22,width=.86,height=.86) +
  scale_fill_manual(values=c(NCT03026062="#6AADD6",NCT01928394="#203468",Combination="#B4D88A",Sequential="#00675E",Yes="#F69173",No="#98361F"),guide="none") +
  labs(x=NULL,y=NULL) + theme_void(base_family=font_family) + theme(axis.text.x=element_text(angle=90,hjust=1,vjust=.5,size=7))
p060 <- p_meta + p_swim + plot_layout(widths=c(1.15,8.85),guides="collect") & theme(legend.position="bottom")
write.csv(endpoint, file.path(data_dir,"figure_060_swimmer_endpoint.csv"),row.names=FALSE)
write.csv(timeline, file.path(data_dir,"figure_060_swimmer_events.csv"),row.names=FALSE)
save_plot(p060,"figure_060_swimmer_code_driven.png",210,125)

# 061 / issue 054: GGally generates all matrix cells and correlations.
suppressPackageStartupMessages({library(GGally); library(ggsci)})
p061 <- ggpairs(iris, mapping=aes(colour=Species,fill=Species), columns=1:4,
  columnLabels=c("Sepal length","Sepal width","Petal length","Petal width"),
  lower=list(continuous=wrap("smooth",alpha=.34,size=.25)),
  upper=list(continuous=wrap("cor",stars=TRUE,method="pearson",display_grid=FALSE)),
  diag=list(continuous=wrap("densityDiag",alpha=.70))) +
  scale_colour_manual(values=c("#ef4936","#4bb4cf","#00a58a")) +
  scale_fill_manual(values=c("#ef4936","#4bb4cf","#00a58a")) +
  theme_bw(base_size=8,base_family=font_family) + theme(panel.grid=element_blank(),strip.background=element_rect(fill="white"),text=element_text(family=font_family))
save_plot(p061,"figure_061_ggally_matrix_code_driven.png",180,150)

# 062 / issue 055: cumulative error-bar positions and a real broken y-axis.
suppressPackageStartupMessages(library(ggbreak))
cell_types <- c("HSC","MPP","MLP","ETP","Pre-BNK","CMP","GMP","MEP","EP","MKP")
raw <- expand_grid(Cell_Type=cell_types,Condition=c("Control","VEXAS"),rep=1:5) |>
  mutate(mu=case_when(Cell_Type=="GMP"~if_else(Condition=="Control",24,38),Cell_Type=="MEP"~if_else(Condition=="Control",9,18),TRUE~runif(n(),.25,3)),
         Value=pmax(.05,rnorm(n(),mu,pmax(.08,mu*.10))))
bar_data <- raw |> group_by(Cell_Type,Condition) |> summarise(Mean=mean(Value),SD=sd(Value),.groups="drop") |>
  mutate(Condition=factor(Condition,c("Control","VEXAS")),Cell_Type=factor(Cell_Type,rev(cell_types)))
error_data <- bar_data |> arrange(Condition,desc(Cell_Type)) |> group_by(Condition) |> mutate(Mean_error_bar=cumsum(Mean)) |> ungroup()
cell_cols <- c(HSC="#ef312d",MPP="#ed7777",MLP="#f1eb9a",ETP="#65bb49",`Pre-BNK`="#118442",CMP="#3d78b8",GMP="#265dad",MEP="#283b76",EP="#a72a2a",MKP="#784546")
p062 <- ggplot() +
  geom_col(data=bar_data,aes(Condition,Mean,fill=Cell_Type),colour="grey20",linewidth=.28,width=.48) +
  geom_errorbar(data=error_data,aes(Condition,ymin=Mean_error_bar-SD,ymax=Mean_error_bar+SD),width=.16,linewidth=.35) +
  scale_fill_manual(values=cell_cols,name=NULL) +
  scale_y_break(c(7,17),scales=2.4,space=.12) +
  labs(y="CD34+ cells per µL",x=NULL) + theme_bf(9) +
  theme(axis.text.x=element_text(angle=55,hjust=1),legend.position="right",legend.key.height=unit(3.5,"mm"))
write.csv(raw,file.path(data_dir,"figure_062_stacked_raw.csv"),row.names=FALSE)
save_plot(p062,"figure_062_ggbreak_stacked_code_driven.png",105,125)

# 067 / issue 060: native WeightedTreemaps Voronoi tessellation in a circle.
suppressPackageStartupMessages({library(WeightedTreemaps); library(ComplexHeatmap)})
countries <- tibble(
  Income.group=rep(c("Low income","Lower middle income","Upper middle income","High income"),c(8,14,15,10)),
  ISO3=c("COD","ETH","UGA","MOZ","BDI","RWA","MWI","NER","IND","IDN","KHM","NGA","PAK","VNM","BGD","KEN","TZA","GHA","CIV","BOL","VEN","NIC","HND","BRA","CHN","RUS","THA","MEX","COL","PER","ARG","ECU","CUB","GTM","DOM","BLZ","CAN","USA","GBR","FRA","DEU","JPN","KOR","AUS","NZL","POL","ROU"),
  Achievable.mitigation=c(.87,.07,.10,.05,.03,.04,.03,.03,1.45,.95,.39,.25,.18,.14,.05,.07,.13,.13,.17,.15,.14,.20,.08,2.06,1.35,.48,.53,.35,.13,.08,.05,.07,.09,.15,.02,.01,.65,.55,.08,.10,.12,.09,.08,.07,.04,.03,.03)) |>
  mutate(Income.group=factor(Income.group,levels=c("Low income","Lower middle income","Upper middle income","High income")),
         label=paste(ISO3,format(Achievable.mitigation,nsmall=2),sep="\n"))
tm <- voronoiTreemap(countries,levels=c("Income.group","label"),cell_size="Achievable.mitigation",shape="circle",seed=123)
png_path <- file.path(fig_dir,"figure_067_weighted_voronoi_code_driven.png")
ragg::agg_png(png_path,width=165,height=165,units="mm",res=300,background="white")
par(mar=c(.4,.4,.4,.4),family=font_family)
drawTreemap(tm,label_size=2.7,label_color="white",border_size=c(2.4,1.2),border_color="#555555",color_level=1,color_palette=c("#ff6545","#ff913d","#76c8aa","#514092"))
dev.off()
write.csv(countries,file.path(data_dir,"figure_067_voronoi.csv"),row.names=FALSE)

# 068 / issue 061: real dcurves::dca on a binary endpoint and fitted probabilities.
suppressPackageStartupMessages(library(dcurves))
n <- 650
dca_data <- tibble(age=rnorm(n,62,11),famhistory=rbinom(n,1,.28),marker=rnorm(n),
                   latent=-2.1+.017*(age-60)+.65*famhistory+1.10*marker+rnorm(n,0,.35)) |>
  mutate(cancer=rbinom(n,1,plogis(latent)))
mods <- list(age=glm(cancer~age,data=dca_data,family=binomial),fam=glm(cancer~famhistory,data=dca_data,family=binomial),
             marker=glm(cancer~marker,data=dca_data,family=binomial),combined=glm(cancer~age+famhistory+marker,data=dca_data,family=binomial))
dca_data <- dca_data |> mutate(Age_Model=predict(mods$age,type="response"),Family_History=predict(mods$fam,type="response"),Marker_Model=predict(mods$marker,type="response"),Prediction_Model=predict(mods$combined,type="response"))
dca_obj <- dcurves::dca(cancer~Age_Model+Family_History+Marker_Model+Prediction_Model,data=dca_data,
                        thresholds=seq(0,.25,.01),
                        as_probability=c("Age_Model","Family_History","Marker_Model","Prediction_Model"),
                        label=list(Age_Model="Age Model",Family_History="Family History",Marker_Model="Marker Model",Prediction_Model="Prediction Model"))
dca_tbl <- as_tibble(dca_obj) |> filter(!is.na(net_benefit))
p068 <- ggplot(dca_tbl,aes(threshold,net_benefit,colour=label,linetype=label)) +
  geom_line(linewidth=.85) +
  scale_colour_manual(values=c("Treat All"="#762f8e","Treat None"="#999999","Age Model"="#deb352","Family History"="#3ca29d","Marker Model"="#063b52","Prediction Model"="#914248")) +
  scale_linetype_manual(values=c("Treat All"="dashed","Treat None"="dashed","Age Model"="solid","Family History"="solid","Marker Model"="solid","Prediction Model"="solid")) +
  scale_x_continuous(limits=c(0,.25),expand=c(0,0)) + scale_y_continuous(breaks=seq(-.02,.14,.02)) +
  coord_cartesian(ylim=c(-.03,.15)) +
  labs(x="Threshold Probability",y="Net Benefit",colour=NULL,linetype=NULL) + theme_bf(9) + theme(legend.position="right")
write.csv(dca_tbl,file.path(data_dir,"figure_068_dca.csv"),row.names=FALSE)
save_plot(p068,"figure_068_dcurves_code_driven.png",165,95)

# 069 / issue 062: fan tree plus four independent ggtreeExtra fruit tracks.
suppressPackageStartupMessages({library(ggtree); library(ggtreeExtra); library(ggnewscale); library(ape)})
tree <- rtree(72); tree$tip.label <- sprintf("Gen%02d",seq_len(72))
phy <- sample(c("Actinobacteriota","Firmicutes","Alphaproteobacteria","Bacteroidota","Others"),72,TRUE)
meta_tree <- tibble(label=tree$tip.label,PhyClass=phy,Source_Group=sample(c("CRBC genomes","Published genomes"),72,TRUE))
base_tree <- full_join(tree,select(meta_tree,label,PhyClass),by="label")
pgp <- expand_grid(label=tree$tip.label,Type=c("P","N","Fe","IAA","GA","CK")) |> mutate(Prop=runif(n()))
bgc <- expand_grid(label=tree$tip.label,Class=c("NRPS","PKS","RiPPs","Terpene")) |> group_by(label) |> mutate(Comp=rgamma(n(),2),Comp=Comp/sum(Comp)) |> ungroup()
gcf <- tibble(label=tree$tip.label,SUM=sample(1:42,72,TRUE),Legend="GCF median")
p069 <- ggtree(base_tree,layout="fan",open.angle=35,linewidth=.22,aes(colour=PhyClass)) +
  scale_colour_manual(values=c(Actinobacteriota="#7fbd4c",Firmicutes="#87461d",Alphaproteobacteria="#f4a000",Bacteroidota="#397bb6",Others="#bdbdbd"),name="I: Taxonomy",na.translate=FALSE) +
  geom_fruit(data=select(meta_tree,label,Source_Group),geom=geom_col,aes(y=label,x=1,fill=Source_Group),pwidth=.08,offset=.025,width=.78) +
  scale_fill_manual(values=c(`CRBC genomes`="#61bfbe",`Published genomes`="#F0CEA0"),name="II: Group") + new_scale_fill() +
  geom_fruit(data=pgp,geom=geom_tile,aes(y=label,x=Type,fill=Prop),pwidth=.38,offset=.045) +
  scale_fill_gradientn(colours=c("white","#edaa53","#388E3C"),name="III: PGP ratio") + new_scale_fill() +
  geom_fruit(data=bgc,geom=geom_col,aes(y=label,x=Comp,fill=Class),pwidth=.65,offset=.08,width=.78) +
  scale_fill_manual(values=c(NRPS="#E6996C",PKS="#AF605D",RiPPs="#D8CF71",Terpene="#599F69"),name="IV: BGC class") + new_scale_fill() +
  geom_fruit(data=gcf,geom=geom_col,aes(y=label,x=SUM,fill=Legend),pwidth=.28,offset=.025,width=.75) +
  scale_fill_manual(values=c(`GCF median`="#AB4823"),name="V: Median GCF") +
  theme(legend.position="right",legend.text=element_text(size=6,family=font_family),legend.title=element_text(size=7,family=font_family),plot.margin=margin(3,3,3,3,"mm"))
write.csv(meta_tree,file.path(data_dir,"figure_069_tree_metadata.csv"),row.names=FALSE)
save_plot(p069,"figure_069_ggtreeextra_code_driven.png",220,175)

writeLines(capture.output(sessionInfo()),file.path(root,"results","tables","sessionInfo_non_single_cell_055_069.txt"))
message("Rendered package-driven figures: 055, 058, 059, 060, 061, 062, 067, 068, 069")
