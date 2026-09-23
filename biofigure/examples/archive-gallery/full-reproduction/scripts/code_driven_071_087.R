#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(ggplot2); library(dplyr); library(tidyr); library(tibble)
  library(patchwork); library(ragg); library(grid)
})

set.seed(20260913)
argv <- commandArgs(trailingOnly = FALSE)
script_path <- sub("--file=", "", argv[grep("--file=", argv)])
root <- normalizePath(file.path(dirname(script_path), ".."))
fig_dir <- file.path(root, "results", "figures")
dat_dir <- file.path(root, "results", "plot_data")
work_dir <- file.path(root, "work", "widgets")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(dat_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(work_dir, recursive = TRUE, showWarnings = FALSE)

font <- "Arial"
stopifnot(font %in% systemfonts::system_fonts()$family)
source(file.path(root,"scripts","figure_style.R"))
bf_complexheatmap_font(bf_font(font))
theme_bf <- function(size = 8) theme_classic(base_size = size, base_family = font) +
  theme(text = element_text(family = font, colour = "#111111"),
        axis.text = element_text(colour = "#111111"),
        legend.background = element_rect(fill = "white", colour = NA),
        legend.key = element_blank(), plot.background = element_rect(fill = "white", colour = NA))
savep <- function(p, name, w, h, dpi = 300) {
  ragg::agg_png(file.path(fig_dir, name), width = w, height = h, units = "mm",
                res = dpi, background = "white")
  on.exit(dev.off(), add = TRUE)
  print(p)
}
png_device <- function(name, w, h, expr) {
  ragg::agg_png(file.path(fig_dir, name), width = w, height = h, units = "mm",
                res = 300, background = "white")
  on.exit(dev.off(), add = TRUE)
  force(expr)
}

# 071 / issue 064A — ggalign chromosome-native radial composition.
suppressPackageStartupMessages(library(ggalign))
load(system.file(package = "circlize", "extdata", "DMR.RData", mustWork = TRUE))
dmr <- bind_rows(Hyper = DMR_hyper, Hypo = DMR_hypo, .id = "state") |>
  relocate(state, .after = last_col())
p071 <- circle_genomic("hg19", radial = coord_radial(inner.radius = .22, rotate.angle = TRUE),
                       direction = "inward") -
  scheme_theme(axis.text.r = element_blank(), axis.ticks.r = element_blank()) +
  plot_ideogram() +
  scale_x_continuous(labels = scales::label_number(scale = 1e-6, suffix = " Mb"), n.breaks = 2) +
  guides(r = "none", r.sec = "axis", theta = guide_axis_theta(angle = 0)) +
  ggalign(dmr) +
  geom_point(aes(middle, log10(distance), colour = state), size = .34, alpha = .72,
             data = function(z) {
               out <- bind_rows(lapply(split(z, z$state), genomic_dist))
               transform(out, middle = (start + end) / 2, distance = pmax(dist, 1))
             }) +
  scale_colour_manual(values = c(Hyper = "#D95F02", Hypo = "#1B9E77"), name = "DMR") +
  ggalign(DMR_hyper, size = .5) +
  geom_density(aes(middle, density), stat = "identity", fill = "#D95F02", colour = "#8D3B00",
               linewidth = .18, data = function(z) transform(genomic_density(z), middle = (start + end)/2)) +
  ggalign(DMR_hypo, size = .5) +
  geom_density(aes(middle, density), stat = "identity", fill = "#1B9E77", colour = "#11664C",
               linewidth = .18, data = function(z) transform(genomic_density(z), middle = (start + end)/2)) &
  theme(text = element_text(family = font), plot.background = element_rect(fill = "white", colour = NA),
        panel.background = element_rect(fill = NA, colour = "#333333", linewidth = .18),
        legend.position = "inside", legend.position.inside = c(.5, .5),
        legend.title = element_text(size = 7), legend.text = element_text(size = 6))
savep(p071, "figure_071_issue064_ggalign_dmr.png", 160, 160)
write.csv(dmr, file.path(dat_dir, "figure_071_dmr.csv"), row.names = FALSE)

# 072 / issue 064B — true nested circlize view with chromosome correspondence.
suppressPackageStartupMessages(library(circlize))
load(system.file(package = "circlize", "extdata", "tagments_WGBS_DMR.RData", mustWork = TRUE))
chr_cols <- setNames(hcl.colors(22, "Dark 3", alpha = .86), paste0("chr", 1:22))
outer_chr <- function() {
  circos.par(start.degree = 90, gap.after = rep(1.6, 22))
  circos.initializeWithIdeogram(chromosome.index = paste0("chr", 1:22),
                                plotType = c("ideogram", "labels"), ideogram.height = .025)
}
inner_frag <- function() {
  circos.par(cell.padding = c(0,0,0,0), gap.after = c(rep(.7, nrow(tagments)-1), 8))
  circos.genomicInitialize(tagments, plotType = NULL)
  circos.genomicTrack(DMR1, ylim = c(-.65,.65), bg.col = adjustcolor(chr_cols[tagments$chr], .18),
    panel.fun = function(region, value, ...) {
      for (yy in c(-.6,-.3,0,.3,.6)) circos.lines(CELL_META$cell.xlim, c(yy,yy), col="#D6D6D6", lty=3, lwd=.45)
      circos.genomicPoints(region, value, pch=16, cex=.38,
                          col=ifelse(value[[1]] > 0,"#C73E3A","#3478A8"))
    })
  circos.track(ylim=c(0,1), track.height=mm_h(1.6), bg.col=chr_cols[tagments$chr])
}
png_device("figure_072_issue064_circlize_nested_dmr.png", 165, 165, {
  par(family=font, mar=c(.3,.3,.3,.3)); circos.clear()
  circos.nested(outer_chr, inner_frag, correspondance,
                connection_col=adjustcolor(chr_cols[correspondance[[1]]], .55))
  circos.clear()
})

# 073–075 / issue 065 — three package-native ternary encodings.
suppressPackageStartupMessages(library(ggtern))
tern <- bind_rows(
  tibble(stage="Young", T=rgamma(54,2.4), L=rgamma(54,4.7), R=rgamma(54,2.2)),
  tibble(stage="Older", T=rgamma(54,4.6), L=rgamma(54,2.1), R=rgamma(54,2.7))) |>
  mutate(total=T+L+R, T=T/total, L=L/total, R=R/total, score=100*(T+.45*R),
         stage=factor(stage,levels=c("Young","Older")))
tern_grid <- list(geom_Tline(Tintercept=seq(.2,.8,.2), colour="#D0D0D0", linewidth=.25, linetype=2),
                  geom_Lline(Lintercept=seq(.2,.8,.2), colour="#D0D0D0", linewidth=.25, linetype=2),
                  geom_Rline(Rintercept=seq(.2,.8,.2), colour="#D0D0D0", linewidth=.25, linetype=2))
base_tern <- ggtern(tern, aes(T,L,R)) + tern_grid +
  Tlab("Temporal") + Llab("Lymphoid") + Rlab("Repair") +
  theme_bw(base_size=8, base_family=font) +
  theme_showarrows() + theme_nomask() +
  theme(panel.background=element_rect(fill="white",colour=NA), tern.axis.arrow=element_line(linewidth=.35),
        tern.axis.title.T=element_text(colour="#8B1A1A",face="bold"),
        tern.axis.title.L=element_text(colour="#163A78",face="bold"),
        tern.axis.title.R=element_text(colour="#16733A",face="bold"),
        legend.position="right", text=element_text(family=font),
        plot.margin=margin(5,5,5,18,"mm"))
p073 <- base_tern + geom_point(aes(fill=stage,shape=stage),size=2.45,stroke=.35,colour="white") +
  scale_fill_manual(values=c(Young="#3B82B8",Older="#EF8848"),name="Age group") +
  scale_shape_manual(values=c(Young=21,Older=24),name="Age group")
p074 <- base_tern + geom_point(aes(fill=score),shape=21,size=2.25,stroke=.28,colour="#303030") +
  scale_fill_viridis_c(option="mako",direction=-1,name="Response\nscore")
p075 <- base_tern + stat_density_tern(aes(fill=after_stat(level)),geom="polygon",bins=7,alpha=.26,colour=NA) +
  geom_point(aes(fill=stage,shape=stage),size=2.1,stroke=.32,colour="white") +
  scale_shape_manual(values=c(Young=22,Older=24),name="Age group") +
  scale_fill_manual(values=c(Young="#2F6EA5",Older="#D95F4E"),name="Age group")
savep(p073,"figure_073_issue065_ternary_groups.png",130,98)
savep(p074,"figure_074_issue065_ternary_continuous.png",130,98)
# avoid dual-fill conflict: contour variant uses outlines and group colour.
p075 <- base_tern + stat_density_tern(aes(fill=after_stat(level)),geom="polygon",bins=8,alpha=.30,colour=NA) +
  scale_fill_viridis_c(option="cividis",name="Density") +
  geom_point(aes(colour=stage,shape=stage),size=2.0,stroke=.55,fill="white") +
  scale_colour_manual(values=c(Young="#2F6EA5",Older="#D95F4E"),name="Age group") +
  scale_shape_manual(values=c(Young=22,Older=24),name="Age group")
savep(p075,"figure_075_issue065_ternary_density.png",130,98)
write.csv(tern,file.path(dat_dir,"figures_073_075_ternary.csv"),row.names=FALSE)

# 076 / issue 067 — semicircular multitrack rainbow heatmap.
n <- 72; split_year <- factor(rep(c("2022","2023"),each=n/2),levels=c("2022","2023"))
mat67 <- matrix(rnorm(n*4, rep(c(-.4,.2,.5,-.1),each=n)), ncol=4)
meta67 <- tibble(year=split_year, cohort=rep(c("C1","C2"),length.out=n),
                 sex=sample(c("Female","Male"),n,TRUE), cmv=sample(c("Negative","Positive"),n,TRUE),
                 response=runif(n,0,1))
png_device("figure_076_issue067_circlize_rainbow_heatmap.png", 185, 120, {
  par(family=font,mar=c(.2,.2,.2,.2)); circos.clear()
  circos.par(start.degree=180,gap.after=c(4,176),cell.padding=c(0,0,0,0))
  cf <- colorRamp2(c(-2,0,2),c("#2C7BB6","#FFFFBF","#D7191C"))
  ann_col <- function(v,cols) colorRamp2(seq_along(cols),unname(cols))[as.numeric(factor(v,levels=names(cols)))]
  circos.heatmap(matrix(as.numeric(factor(meta67$cohort)),ncol=1), split=split_year, cluster=FALSE,
                 col=colorRamp2(1:2,c("#2A9D8F","#E9C46A")),track.height=.025)
  circos.heatmap(matrix(as.numeric(factor(meta67$sex)),ncol=1),cluster=FALSE,
                 col=colorRamp2(1:2,c("#8E7DBE","#62A8D1")),track.height=.025)
  circos.heatmap(matrix(as.numeric(factor(meta67$cmv)),ncol=1),cluster=FALSE,
                 col=colorRamp2(1:2,c("#4DAF4A","#E34A33")),track.height=.025)
  circos.trackPlotRegion(factors=split_year,ylim=c(0,1),track.height=.08,bg.border=NA,
    panel.fun=function(x,y){idx=split_year==CELL_META$sector.index; xx=seq_len(sum(idx))-.5;
      circos.barplot(meta67$response[idx],xx,col="#263238",border=NA)})
  for(j in 1:4) circos.heatmap(mat67[,j],col=cf,cluster=FALSE,track.height=.075,cell.border="white",cell.lwd=.18)
  gp_t <- gpar(fontfamily=font,fontsize=7); gp_l <- gpar(fontfamily=font,fontsize=6)
  lgd <- ComplexHeatmap::packLegend(
    ComplexHeatmap::Legend(title="z score",col_fun=cf,title_gp=gp_t,labels_gp=gp_l,direction="horizontal"),
    ComplexHeatmap::Legend(title="Cohort",at=c("C1","C2"),legend_gp=gpar(fill=c("#2A9D8F","#E9C46A")),title_gp=gp_t,labels_gp=gp_l,nrow=1),
    ComplexHeatmap::Legend(title="Sex",at=c("Female","Male"),legend_gp=gpar(fill=c("#8E7DBE","#62A8D1")),title_gp=gp_t,labels_gp=gp_l,nrow=1),
    ComplexHeatmap::Legend(title="CMV",at=c("Negative","Positive"),legend_gp=gpar(fill=c("#4DAF4A","#E34A33")),title_gp=gp_t,labels_gp=gp_l,nrow=1),
    direction="horizontal",gap=unit(5,"mm"),max_width=unit(165,"mm"))
  ComplexHeatmap::draw(lgd,x=unit(.5,"npc"),y=unit(.10,"npc"),just=c("center","center"))
  circos.clear()
})
write.csv(cbind(meta67,mat67),file.path(dat_dir,"figure_076_multitrack.csv"),row.names=FALSE)

# 077 / issue 068 — clinical matrix with response profile and independent annotation legends.
suppressPackageStartupMessages(library(ComplexHeatmap))
ns <- 54; ng <- 22
expr68 <- matrix(rnorm(ng*ns),ng,ns,dimnames=list(paste0("Feature ",1:ng),paste0("P",sprintf("%02d",1:ns))))
response <- sort(rnorm(ns,0,42),decreasing=TRUE); ord <- order(response,decreasing=TRUE); expr68 <- expr68[,ord]
ann68 <- data.frame(Response=ifelse(response[ord]>0,"Benefit","No benefit"),
                    Histology=sample(c("LUAD","LUSC","Other"),ns,TRUE),
                    Sex=sample(c("Female","Male"),ns,TRUE),
                    Stage=sample(c("I","II","III","IV"),ns,TRUE))
rownames(ann68) <- colnames(expr68)
ha68 <- HeatmapAnnotation(
  `Best response`=anno_barplot(response[ord],gp=gpar(fill=ifelse(response[ord]>0,"#C54A48","#3A78A8"),col=NA),
                              height=unit(15,"mm"),axis_param=list(gp=gpar(fontfamily=font,fontsize=6))),
  df=ann68, col=list(Response=c(Benefit="#D95F59",`No benefit`="#4C78A8"),
                     Histology=c(LUAD="#66C2A5",LUSC="#FC8D62",Other="#8DA0CB"),
                     Sex=c(Female="#B07AA1",Male="#59A14F"),
                     Stage=c(I="#E5F5E0",II="#A1D99B",III="#41AB5D",IV="#006D2C")),
  annotation_name_gp=gpar(fontfamily=font,fontsize=7),annotation_legend_param=list(labels_gp=gpar(fontfamily=font,fontsize=6),title_gp=gpar(fontfamily=font,fontsize=7)))
ht68 <- Heatmap(expr68,name="Expression",top_annotation=ha68,cluster_columns=FALSE,show_column_names=FALSE,
  col=colorRamp2(c(-2,0,2),c("#2166AC","#F7F7F7","#B2182B")),
  row_names_gp=gpar(fontfamily=font,fontsize=6.5),row_dend_width=unit(12,"mm"),
  heatmap_legend_param=list(direction="horizontal",title_gp=gpar(fontfamily=font,fontsize=7),labels_gp=gpar(fontfamily=font,fontsize=6)))
png_device("figure_077_issue068_clinical_heatmap.png", 195, 120, {
  draw(ht68,heatmap_legend_side="bottom",annotation_legend_side="right",padding=unit(c(3,3,3,3),"mm"))
})
write.csv(expr68,file.path(dat_dir,"figure_077_expression.csv"))
write.csv(ann68,file.path(dat_dir,"figure_077_annotations.csv"))

# 078–080 / issue 069 — three independently implemented heatmap grammars.
n69 <- 38; p69 <- 16
mat69 <- matrix(rnorm(p69*n69),p69,n69,dimnames=list(paste0("Protein ",1:p69),paste0("S",1:n69)))
grp69 <- factor(rep(c("Control","Treatment"),each=n69/2)); age69 <- round(runif(n69,25,75))
mat69[1:6,grp69=="Treatment"] <- mat69[1:6,grp69=="Treatment"] + 1.25
ha69 <- HeatmapAnnotation(Group=grp69,Age=age69,
  col=list(Group=c(Control="#4DBBD5",Treatment="#E64B35"),Age=colorRamp2(c(25,75),c("#FFF4B3","#7F0000"))),
  annotation_name_gp=gpar(fontfamily=font,fontsize=7))
ht69 <- Heatmap(mat69,name="z",top_annotation=ha69,col=colorRamp2(c(-2,0,2),c("#2B6CB0","#FFF8D6","#C53030")),
  column_split=grp69,show_column_names=FALSE,row_names_gp=gpar(fontfamily=font,fontsize=7),
  column_title_gp=gpar(fontfamily=font,fontsize=8),row_dend_width=unit(12,"mm"))
png_device("figure_078_issue069_complexheatmap.png",150,108,{draw(ht69,heatmap_legend_side="right",annotation_legend_side="right")})
png_device("figure_079_issue069_pheatmap.png",150,108,{
  pheatmap::pheatmap(mat69,annotation_col=data.frame(Group=grp69,Age=age69,row.names=colnames(mat69)),
    color=colorRampPalette(c("#2B6CB0","#FFF8D6","#C53030"))(101),border_color=NA,
    fontsize=7,fontsize_row=7,show_colnames=FALSE,fontfamily=font)
})
long69 <- as.data.frame(mat69) |> rownames_to_column("protein") |> pivot_longer(-protein,names_to="sample",values_to="z") |>
  mutate(sample=factor(sample,levels=colnames(mat69)),protein=factor(protein,levels=rownames(mat69))) |>
  left_join(tibble(sample=factor(colnames(mat69),levels=colnames(mat69)),group=grp69,age=age69),by="sample")
suppressPackageStartupMessages(library(tidyHeatmap))
th80 <- tidyHeatmap::heatmap(long69,protein,sample,z,scale="row",cluster_rows=FALSE,cluster_columns=FALSE,
  show_column_names=FALSE,row_title="",column_title="",row_names_gp=gpar(fontfamily=font,fontsize=7),
  palette_value=colorRamp2(c(-2,0,2),c("#2B6CB0","#FFF8D6","#C53030"))) |>
  tidyHeatmap::annotation_group(group,palette_grouping=list(group=c(Control="#4DBBD5",Treatment="#E64B35")),
                               show_group_name=FALSE,group_label_fontsize=0,group_strip_height=unit(4,"pt")) |>
  tidyHeatmap::annotation_tile(age,size=unit(3,"mm"),palette=colorRamp2(c(25,75),c("#FEE8C8","#7F0000")))
png_device("figure_080_issue069_tidy_heatmap.png",150,92,{
  ComplexHeatmap::draw(tidyHeatmap::as_ComplexHeatmap(th80),heatmap_legend_side="right",annotation_legend_side="right")
})
write.csv(long69,file.path(dat_dir,"figures_078_080_heatmap.csv"),row.names=FALSE)

# 081 / issue 070 — dense swimmer with aligned patient tracks and separate scales.
suppressPackageStartupMessages(library(ggnewscale))
np <- 46
pat <- tibble(id=factor(sprintf("P%02d",1:np),levels=sprintf("P%02d",np:1)),
              follow=sort(runif(np,8,62)),relapse=sample(c("Relapse","No relapse"),np,TRUE),
              stage=sample(c("I","II","III"),np,TRUE),smoking=sample(c("Never","Former","Current"),np,TRUE))
tx <- pat |> transmute(id,start=0,end=pmax(3,follow-runif(np,2,8)),kind=sample(c("Adjuvant","Observation"),np,TRUE))
events <- pat |> filter(relapse=="Relapse") |> transmute(id,time=follow*runif(n(),.55,.94),event="ctDNA detected")
meta_long <- pat |> select(id,stage,smoking) |> pivot_longer(-id,names_to="track",values_to="value")
p081 <- ggplot() +
  geom_tile(data=meta_long,aes(x=ifelse(track=="stage",-10,-6),y=id,fill=value),width=3.0,height=.72,colour="white",linewidth=.1) +
  scale_fill_manual(values=c(I="#CCEBC5",II="#7BCCC4",III="#2B8CBE",Never="#FDD0A2",Former="#FDAE6B",Current="#E6550D"),name="Clinical track") +
  ggnewscale::new_scale_fill() +
  geom_segment(data=tx,aes(x=start,xend=end,y=id,yend=id,colour=kind),linewidth=3.0,lineend="butt") +
  geom_point(data=events,aes(x=time,y=id,shape=event),size=2.0,stroke=.45,fill="white",colour="#7A0177") +
  geom_point(data=pat,aes(x=follow,y=id,fill=relapse),shape=21,size=2.0,stroke=.35,colour="white") +
  scale_colour_manual(values=c(Adjuvant="#4C78A8",Observation="#B8B8B8"),name="Treatment") +
  scale_fill_manual(values=c(Relapse="#D73027",`No relapse`="#1A9850"),name="Outcome") +
  scale_shape_manual(values=c(`ctDNA detected`=23),name="Event") +
  scale_x_continuous(breaks=seq(0,60,12),limits=c(-13,65),expand=c(0,0)) +
  labs(x="Months from surgery",y=NULL) + theme_bf(7) +
  theme(panel.grid.major.x=element_line(colour="#E8E8E8",linewidth=.25),axis.line.y=element_blank(),
        axis.ticks.y=element_blank(),legend.position="bottom",legend.box="vertical",plot.margin=margin(3,3,3,6,"mm"))
savep(p081,"figure_081_issue070_annotated_swimmer.png",205,150)
write.csv(pat,file.path(dat_dir,"figure_081_patients.csv"),row.names=FALSE)

# 082 / issue 071 — sunburstR HTML widget rendered to PNG.
suppressPackageStartupMessages({library(sunburstR); library(htmlwidgets); library(webshot2)})
sun <- expand_grid(Sex=c("Female","Male"),Stage=c("Early","Late"),Histology=c("LUAD","LUSC"),
                   Response=c("Benefit","Stable"),Cohort=c("C1","C2")) |>
  mutate(path=paste(Sex,Stage,Histology,Response,Cohort,sep="-"),count=sample(3:24,n(),TRUE)) |>
  select(path,count)
w082 <- sunburst(sun,count=TRUE,percent=TRUE,legend=FALSE,width=780,height=780,
                 colors=c("#4E79A7","#F28E2B","#59A14F","#E15759","#B07AA1","#76B7B2"))
html082 <- file.path(work_dir,"figure_082_sunburst.html")
saveWidget(w082,html082,selfcontained=FALSE)
raw082 <- file.path(work_dir,"figure_082_sunburst_raw.png")
webshot2::webshot(html082,raw082,vwidth=860,vheight=820,zoom=2,delay=.8)
sb <- magick::image_read(raw082)
canvas <- magick::image_blank(2180,1720,"white") |> magick::image_composite(sb,offset="+0+0") |>
  magick::image_annotate("Ring hierarchy",font=font,size=44,weight=700,color="#222222",location="+1715+390") |>
  magick::image_annotate("1  Sex\n2  Stage\n3  Histology\n4  Response\n5  Cohort",font=font,size=36,color="#333333",location="+1715+485",degrees=0)
magick::image_write(canvas,file.path(fig_dir,"figure_082_issue071_sunburst.png"),format="png")
write.csv(sun,file.path(dat_dir,"figure_082_sunburst.csv"),row.names=FALSE)

# 083 / issue 072 — nested pie/donut using webr's native geometry.
suppressPackageStartupMessages(library(webr))
pd <- expand_grid(Diagnosis=c("Group A","Group B","Group C"),Smoking=c("Never","Former","Current")) |>
  mutate(n=c(32,18,8,18,26,11,13,19,24))
p083a <- webr::PieDonut(pd,aes(pies=Diagnosis,donuts=Smoking,count=n),r0=.24,r1=.75,r2=1.08,
                        labelposition=2,showRatioThreshold=.25,showPieName=FALSE,showDonutName=FALSE,
                        pieLabelSize=3,donutLabelSize=2.5,title="") +
  theme(text=element_text(family=font),plot.title=element_blank(),legend.position="none")
p083b <- webr::PieDonut(pd,aes(pies=Diagnosis,donuts=Smoking,count=n),r0=.24,r1=.75,r2=1.08,
                        explode=2,explodeDonut=TRUE,labelposition=2,showRatioThreshold=.25,
                        showPieName=FALSE,showDonutName=FALSE,pieLabelSize=3,donutLabelSize=2.5,title="") +
  theme(text=element_text(family=font),plot.title=element_blank(),legend.position="right")
dir.create(file.path(work_dir,"package_runtime"),showWarnings=FALSE)
ragg::agg_png(file.path(work_dir,"package_runtime","issue072_webr_runtime.png"),width=82,height=82,units="mm",res=300,background="white")
print(p083a); dev.off()
nested_donut <- function(dat, highlighted=NULL) {
  d <- dat |> arrange(Diagnosis,Smoking) |> mutate(xmax=cumsum(n),xmin=lag(xmax,default=0),mid=(xmin+xmax)/2)
  inn <- d |> group_by(Diagnosis) |> summarise(n=sum(n),.groups="drop") |>
    mutate(xmax=cumsum(n),xmin=lag(xmax,default=0),mid=(xmin+xmax)/2)
  if(!is.null(highlighted)) {
    gap <- sum(d$n)*.018; idx <- d$Diagnosis==highlighted
    d$xmin[idx] <- d$xmin[idx]+gap; d$xmax[idx] <- d$xmax[idx]+gap
    inn$xmin[inn$Diagnosis==highlighted] <- inn$xmin[inn$Diagnosis==highlighted]+gap
    inn$xmax[inn$Diagnosis==highlighted] <- inn$xmax[inn$Diagnosis==highlighted]+gap
  }
  ggplot() +
    geom_rect(data=inn,aes(xmin=xmin,xmax=xmax,ymin=.26,ymax=.72,fill=Diagnosis),colour="white",linewidth=.35) +
    geom_text(data=inn,aes(x=mid,y=.49,label=Diagnosis),family=font,size=2.6,colour="white",fontface="bold") +
    scale_fill_manual(values=c(`Group A`="#D65337",`Group B`="#16889D",`Group C`="#7974B5"),name="Diagnosis") +
    ggnewscale::new_scale_fill() +
    geom_rect(data=d,aes(xmin=xmin,xmax=xmax,ymin=.75,ymax=1.08,fill=Smoking),colour="white",linewidth=.32) +
    scale_fill_manual(values=c(Never="#F6C4B7",Former="#F08A75",Current="#B7352D"),name="Smoking") +
    coord_polar(theta="x",clip="off") + xlim(0,max(d$xmax)*1.01) + ylim(0,1.22) +
    theme_void(base_family=font) + theme(legend.position="bottom",legend.box="vertical",
      legend.key.size=unit(3,"mm"),legend.text=element_text(size=6.5),legend.title=element_text(size=7))
}
p083 <- nested_donut(pd) + nested_donut(pd,"Group B") + plot_layout(guides="collect") & theme(legend.position="bottom")
savep(p083,"figure_083_issue072_nested_piedonut.png",180,118)
write.csv(pd,file.path(dat_dir,"figure_083_piedonut.csv"),row.names=FALSE)

# 084–085 / issue 073 — polar bars and spline petals.
suppressPackageStartupMessages({library(ggforce); library(ggsci)})
petal <- expand_grid(cell=factor(c("A549","H1975","HCC827","PC9","H1299","H358"),
                                 levels=c("A549","H1975","HCC827","PC9","H1299","H358")),
                     tissue=factor(paste0("T",1:8),levels=paste0("T",1:8)),KO=c("WT","KO")) |>
  mutate(mean=runif(n(),.35,1.0)+ifelse(KO=="KO",runif(n(),-.18,.18),0),se=runif(n(),.025,.075))
p084 <- ggplot(petal,aes(tissue,mean,fill=KO)) +
  geom_col(position=position_dodge(width=.82),width=.75,colour="white",linewidth=.16) +
  geom_errorbar(aes(ymin=pmax(0,mean-se),ymax=mean+se),position=position_dodge(.82),width=.18,linewidth=.25) +
  coord_polar(start=-pi/8,clip="off") + facet_wrap(~cell,nrow=2) +
  scale_fill_manual(values=c(WT="#3C8DAD",KO="#E07A5F")) + labs(x=NULL,y=NULL) +
  theme_void(base_family=font) + theme(strip.text=element_text(size=9,face="bold"),legend.position="bottom",
                                        axis.text.x=element_text(size=6.5),plot.margin=margin(8,7,8,7,"mm"))
savep(p084,"figure_084_issue073_polar_bars.png",175,120)
pet <- expand_grid(category=factor(LETTERS[1:8],levels=LETTERS[1:8]),i=seq_len(90)) |>
  group_by(category) |> mutate(theta=(as.numeric(category)-1)*2*pi/8 + seq(-.33,.33,length.out=n()),
                               r=sin(seq(0,pi,length.out=n()))*(.65+runif(1,.05,.30))) |> ungroup()
labpet <- pet |> group_by(category) |> slice_max(r,n=1,with_ties=FALSE)
p085 <- ggplot(pet,aes(theta,r,group=category,fill=category)) +
  ggforce::stat_bspline(geom="area",n=700,alpha=.92,colour="white",linewidth=.35) +
  geom_text(data=labpet,aes(label=category),family=font,size=3.1,fontface="bold",vjust=-.45) +
  ggsci::scale_fill_npg(guide="none") + coord_radial(inner.radius=.18,clip="off") +
  theme_void(base_family=font) + theme(plot.margin=margin(5,5,5,5,"mm"))
savep(p085,"figure_085_issue073_spline_petals.png",105,105)
write.csv(petal,file.path(dat_dir,"figure_084_polarbars.csv"),row.names=FALSE)

# 086 / issue 074 — hierarchical circular GRN using tidygraph/ggraph.
suppressPackageStartupMessages({library(tidygraph);library(ggraph);library(igraph)})
root_nodes <- paste0("Hub",1:6); branch_nodes <- paste0("Module",1:24); leaf_nodes <- paste0("Gene",sprintf("%02d",1:96))
edges74 <- bind_rows(tibble(from="ROOT",to=root_nodes),
  tibble(from=rep(root_nodes,each=4),to=branch_nodes),
  tibble(from=rep(branch_nodes,each=4),to=leaf_nodes))
g74 <- as_tbl_graph(edges74,directed=TRUE) |> activate(nodes) |>
  mutate(level=case_when(name=="ROOT"~"root",name%in%root_nodes~"hub",name%in%branch_nodes~"module",TRUE~"gene"),
         branch=case_when(name=="ROOT"~"root",name%in%root_nodes~name,name%in%branch_nodes~root_nodes[(match(name,branch_nodes)-1)%/%4+1],TRUE~root_nodes[(match(name,leaf_nodes)-1)%/%16+1]))
p086 <- ggraph(g74,layout="dendrogram",circular=TRUE) +
  geom_edge_diagonal(aes(colour=node1.branch),linewidth=.26,alpha=.45,show.legend=FALSE) +
  geom_node_point(aes(size=level,fill=branch),shape=21,colour="white",stroke=.2,show.legend=FALSE) +
  geom_node_text(aes(label=ifelse(level=="gene",name,""),angle=-((-node_angle(x,y)+90)%%180)+90,
                     hjust=ifelse(x<0,1,0)),family=font,size=1.65,colour="#333333",repel=FALSE) +
  geom_node_text(aes(label=ifelse(level=="hub",name,"")),family=font,size=2.5,colour="white",fontface="bold") +
  scale_size_manual(values=c(root=8,hub=7,module=2.1,gene=.7)) +
  scale_fill_manual(values=c(root="#222222",setNames(ggsci::pal_npg()(6),root_nodes))) +
  scale_colour_manual(values=c(root="#999999",setNames(ggsci::pal_npg()(6),root_nodes))) +
  coord_equal(clip="off",xlim=c(-1.22,1.22),ylim=c(-1.22,1.22)) + theme_void(base_family=font) +
  theme(plot.margin=margin(10,10,10,10,"mm"))
savep(p086,"figure_086_issue074_petal_network.png",165,165)
write.csv(edges74,file.path(dat_dir,"figure_086_network_edges.csv"),row.names=FALSE)

# 087 / issue 075 — scatter pies, explicit radius and external labels.
suppressPackageStartupMessages({library(scatterpie);library(ggrepel);library(ggprism)})
sp <- tibble(pathway=paste0("Pathway ",LETTERS[1:18]),change=runif(18,-45,55),degs=runif(18,15,150),
             up=runif(18,5,70),down=runif(18,5,70)) |> mutate(total=up+down,r=scales::rescale(sqrt(total),c(2.3,5.0)))
p087 <- ggplot(sp,aes(change,degs)) + geom_hline(yintercept=0,colour="#BDBDBD",linewidth=.3) +
  scatterpie::geom_scatterpie(aes(x=change,y=degs,r=r),cols=c("up","down"),colour="white",linewidth=.25,alpha=.95) +
  ggrepel::geom_text_repel(data=slice_max(sp,total,n=8),aes(label=pathway),family=font,size=2.25,
                           min.segment.length=0,box.padding=.45,point.padding=.35,seed=20260913,max.overlaps=Inf) +
  scale_fill_manual(values=c(up="#D95F59",down="#4C78A8"),name="DEG direction") +
  scale_x_continuous(expand=expansion(mult=c(.15,.23))) + scale_y_continuous(expand=expansion(mult=c(.12,.18))) +
  labs(x="Change in composition (%)",y="Number of DEGs") + ggprism::theme_prism(base_size=8,base_family=font,border=TRUE) +
  theme(legend.position="right",plot.margin=margin(3,5,3,3,"mm")) + coord_equal(ratio=.55,clip="off")
savep(p087,"figure_087_issue075_scatterpie.png",155,112)
write.csv(sp,file.path(dat_dir,"figure_087_scatterpie.csv"),row.names=FALSE)

# 088 / issue 077 — paired ridgelines plus bottom barcode rug.
suppressPackageStartupMessages({library(ggridges);library(viridis)})
subg <- factor(paste0("S",1:9),levels=paste0("S",9:1))
ridge <- expand_grid(Subgroup=subg,id=1:85) |> mutate(mu=as.numeric(Subgroup)*.2-1,
  BEMP=rnorm(n(),mu,.45),preMegE=rnorm(n(),-.55*mu,.42))
ridge_panel <- function(var,label) ggplot(ridge,aes(x=.data[[var]],y=Subgroup,fill=after_stat(x))) +
  geom_density_ridges_gradient(scale=1.45,rel_min_height=.01,colour="white",linewidth=.28) +
  geom_rug(data=filter(ridge,id%%10==0),aes(x=.data[[var]],y=NULL),inherit.aes=FALSE,sides="b",alpha=.55,linewidth=.25) +
  scale_fill_viridis_c(option="C",guide="none") + labs(x=label,y=NULL) + theme_bf(7) +
  theme(panel.grid.major.y=element_line(colour="#ECECEC",linewidth=.2),axis.line.y=element_blank(),axis.ticks.y=element_blank())
p088 <- ridge_panel("BEMP","BEMP score") + ridge_panel("preMegE","preMegE score") + plot_layout(widths=c(1,1))
savep(p088,"figure_088_issue077_ridgeline_barcode.png",170,105)
write.csv(ridge,file.path(dat_dir,"figure_088_ridgeline.csv"),row.names=FALSE)

# 089 / issue 079 — proportional stream graph, faceted by region.
suppressPackageStartupMessages(library(ggstream))
stream <- expand_grid(region=c("North India","Kolkata","Bangladesh"),year=seq(2018,2025,by=.15),lineage=paste0("L",1:8)) |>
  group_by(region,lineage) |> mutate(phase=runif(1,0,2*pi),peak=runif(1,2018.5,2024.5),width=runif(1,.35,1.5),
    abundance=exp(-.5*((year-peak)/width)^2)*(runif(1,.25,1.2))) |> group_by(region,year) |>
  mutate(freq=abundance/sum(abundance)) |> ungroup()
p089 <- ggplot(stream,aes(year,freq,fill=lineage)) +
  ggstream::geom_stream(type="proportional",colour="white",linewidth=.18,bw=.25) +
  facet_grid(region~.) + scale_fill_manual(values=hcl.colors(8,"Spectral"),name="Sublineage") +
  scale_x_continuous(breaks=2018:2025,expand=c(0,0)) + labs(x="Year",y="Relative frequency") +
  theme_bf(7.5) + theme(panel.grid=element_blank(),strip.text.y=element_text(angle=0,face="bold"),legend.position="right")
savep(p089,"figure_089_issue079_streamgraph.png",175,126)
write.csv(stream,file.path(dat_dir,"figure_089_stream.csv"),row.names=FALSE)

# 090 / issue 080 — Bangladesh division map with faceted transmission flows.
suppressPackageStartupMessages({library(sf);library(bangladesh)})
bd <- bangladesh::get_map("division")
name_col <- intersect(c("Division","division","NAME_1","ADM1_EN"),names(bd))[1]
if (is.na(name_col)) name_col <- names(bd)[vapply(bd,function(x)is.character(x)||is.factor(x),logical(1))][1]
cent <- suppressWarnings(st_centroid(bd)); xy <- st_coordinates(cent)
cent_df <- tibble(region=as.character(bd[[name_col]]),x=xy[,1],y=xy[,2])
flows <- expand_grid(Source=c("North India","Kolkata"),i=1:18) |>
  mutate(a=sample(seq_len(nrow(cent_df)),n(),TRUE),b=sample(seq_len(nrow(cent_df)),n(),TRUE),
         subpopulation=sample(paste0("L",1:4),n(),TRUE),events=sample(1:8,n(),TRUE),months=runif(n(),0,12)) |>
  filter(a!=b) |> mutate(x=cent_df$x[a],y=cent_df$y[a],xend=cent_df$x[b],yend=cent_df$y[b])
p090 <- ggplot() + geom_sf(data=bd,fill="#F7F7F5",colour="#5E6B73",linewidth=.35) +
  geom_curve(data=flows,aes(x=x,y=y,xend=xend,yend=yend,colour=subpopulation,size=events,alpha=months),
             curvature=.20,arrow=arrow(length=unit(1.2,"mm"),type="closed"),lineend="round") +
  geom_sf_text(data=cent,aes(label=.data[[name_col]]),family=font,size=2.0,colour="#263238",check_overlap=TRUE) +
  facet_wrap(~Source,nrow=1) + scale_colour_manual(values=c(L1="#3B82B8",L2="#E76F51",L3="#2A9D8F",L4="#8E6C8A"),name="Subpopulation") +
  scale_size_continuous(range=c(.25,1.25),name="Transmission events") + scale_alpha_continuous(range=c(.30,.80),name="Months") +
  coord_sf(datum=NA,clip="off") + theme_void(base_family=font) +
  theme(strip.text=element_text(size=8,face="bold"),legend.position="right",plot.margin=margin(3,4,3,3,"mm"))
savep(p090,"figure_090_issue080_flow_map.png",205,105)
write.csv(flows,file.path(dat_dir,"figure_090_flows.csv"),row.names=FALSE)

writeLines(capture.output(sessionInfo()),file.path(root,"results","tables","sessionInfo_071_087.txt"))
cat("GENERATED_20_CODE_DRIVEN_PNG\n")
