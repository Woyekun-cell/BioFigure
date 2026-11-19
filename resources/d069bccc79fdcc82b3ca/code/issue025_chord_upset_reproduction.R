#!/usr/bin/env Rscript
suppressPackageStartupMessages({library(ComplexHeatmap); library(circlize); library(grid)})
set.seed(2501)
out1 <- "results/figures/issue025_chord.png"; out2 <- "results/figures/issue025_upset.png"
dir.create(dirname(out1), recursive=TRUE, showWarnings=FALSE)
sets <- c("D","J1","J2","I","C1","C2","C3")
genes <- paste0("G", sprintf("%03d", 1:180))
lst <- setNames(lapply(seq_along(sets), function(i) sample(genes, 54 + i*5)), sets)
mat <- matrix(sample(0:18, 49, replace=TRUE), 7, dimnames=list(sets,sets)); diag(mat) <- 0
pal <- setNames(c("#D95F4A","#4BA6B8","#2C9876","#445D8C","#D49A7A","#78949F","#9C846F"),sets)
ragg::agg_png(out1, width=1800, height=1800, res=260, background="white")
circos.clear(); circos.par(start.degree=88,gap.degree=3,canvas.xlim=c(-1.18,1.18),canvas.ylim=c(-1.18,1.18))
chordDiagram(mat, grid.col=pal, transparency=.28, annotationTrack="grid", preAllocateTracks=list(track.height=.09))
circos.trackPlotRegion(track.index=2,bg.border=NA,panel.fun=function(x,y){s=get.cell.meta.data("sector.index"); circos.text(CELL_META$xcenter,CELL_META$ylim[1],s,facing="bending.inside",niceFacing=TRUE,cex=.8,col="#263238")})
title("Shared programs across tissues",font.main=2,cex.main=1.35,line=-1); dev.off()
ragg::agg_png(out2, width=2200, height=1300, res=260, background="white")
m <- make_comb_mat(lst); m <- m[comb_size(m)>=2]; ht <- UpSet(m, set_order=sets,
  top_annotation=upset_top_annotation(m, gp=gpar(fill="#345B73",col=NA), annotation_name_side="left"),
  comb_col="#243A4A", bg_col=c("#EFF3F5","#D7E3E8"), pt_size=unit(3,"mm"), lwd=2)
draw(ht, padding=unit(c(14,8,8,8),"mm")); grid.text("Intersection structure",y=unit(.985,"npc"),gp=gpar(fontface=2,fontsize=14)); dev.off()
write.csv(data.frame(source="simulated", seed=2501, set=sets, n=vapply(lst,length,integer(1))), "results/plot_data/issue025_chord_upset.csv", row.names=FALSE)
