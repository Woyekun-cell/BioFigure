# SheepGTEx Nature Genetics Fig. 5a. Usage: Rscript draw_figure.R [output-dir]
args <- commandArgs(TRUE)
self <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value=TRUE)))
case <- dirname(self)
out <- if(length(args)) args[1] else file.path(case,"figures")
dir.create(out,recursive=TRUE,showWarnings=FALSE)
library(ggplot2)

skill <- Sys.getenv("BIOFIGURE_ROOT",file.path(path.expand("~"),".codex","skills","biofigure"))
helper <- normalizePath(file.path(skill,"scripts","figure_style.R"),mustWork=TRUE)
lut <- normalizePath(file.path(skill,"palettes","continuous-luts.csv"),mustWork=TRUE)
source(helper)
input <- file.path(case,"plot_data","sheepgtex-fig5a-correlations.csv")
m <- as.matrix(read.csv(input,row.names=1,check.names=FALSE))
stopifnot(identical(dim(m),c(51L,51L)),identical(rownames(m),colnames(m)),
          isSymmetric(m,tol=1e-14),all(diag(m)==1),all(is.finite(m)))
tissues <- rownames(m)
n <- nrow(m)
width <- 182
height <- 154
cell <- 2.48
x_left <- 25.2
y_top <- 147
y_bottom <- y_top-n*cell
font_name <- "Arial"
ink <- "#293840"
outline <- "#42515B"
density_fill <- "#E4ECEF"
left_axis <- c(2.8,22.8)
limits <- c(.6,1)
color <- bf_colour_function(kind="sequential",palette_id="scico-lipari",
                            limits=limits,direction=-1,skill_root=skill)
heat_x <- function(i) x_left+(i-.5)*cell
heat_y <- function(i) y_top-(i-.5)*cell
scale_violin <- function(rho) left_axis[1]+(rho-limits[1])/diff(limits)*diff(left_axis)

tiles <- expand.grid(row=seq_len(n),col=seq_len(n))
tiles$x <- heat_x(tiles$col)
tiles$y <- heat_y(tiles$row)
tiles$color <- NA_character_
lower <- tiles$row>tiles$col
tiles$color[lower] <- color(m[cbind(tiles$row[lower],tiles$col[lower])])
stopifnot(sum(lower)==1275L)
diagonal <- data.frame(x=heat_x(seq_len(n))+.08,y=heat_y(seq_len(n)),
                       label=gsub("_"," ",tissues,fixed=TRUE))

# Density and box marker reproduce the author's row-level anno_density.
# The KDE is drawn on the visible correlation domain; the full row sets its bandwidth.
kde <- lapply(seq_len(n),function(i) {
  d <- density(m[i,])
  keep <- d$x >= limits[1] & d$x <= limits[2]
  list(x=d$x[keep],y=d$y[keep])
})
peak <- max(vapply(kde,function(d)max(d$y),0))
violins <- do.call(rbind,lapply(seq_len(n),function(i){
  k <- kde[[i]]
  x <- scale_violin(k$x)
  d <- k$y/peak*(cell*.43)
  data.frame(row=i, x=c(x,rev(x)),y=heat_y(i)+c(d,-rev(d)))
}))
tails <- do.call(rbind,lapply(seq_len(n),function(i){
  b <- boxplot.stats(m[i,])$stats
  data.frame(x=scale_violin(c(b[1],b[4])),xend=scale_violin(c(b[2],b[5])),y=heat_y(i))
}))
medians <- data.frame(x=scale_violin(apply(m,1,median)),y=heat_y(seq_len(n)))

# Recompute the original two-step clustering on the author's alphabetical order;
# rotate child branches only to recover the published order.
ids <- sort(tissues,method="radix")
initial <- m[ids,ids]
cluster <- function(a) hclust(dist(a,method="maximum"),method="complete")
pass1 <- cluster(initial)
pass2 <- as.dendrogram(cluster(t(initial[pass1$order,pass1$order])))
dend <- dendextend::rotate(pass2,order=tissues)
stopifnot(identical(labels(dend),tissues))
old_dist <- as.matrix(cophenetic(pass2))[tissues,tissues]
new_dist <- as.matrix(cophenetic(dend))[tissues,tissues]
stopifnot(identical(old_dist,new_dist))
dend_data <- ggdendro::dendro_data(dend,type="rectangle")
stopifnot(identical(as.character(dend_data$labels$label),tissues),
          all(dend_data$labels$x==seq_len(n)))
segments <- dend_data$segments
stems_y <- y_bottom-.80
tree_y <- function(y) stems_y-y/attr(dend,"height")*12.4
tree <- data.frame(x=heat_x(segments$x),xend=heat_x(segments$xend),
                   y=tree_y(segments$y),yend=tree_y(segments$yend))

color_range <- c(132,173.5)
key_x <- function(rho) color_range[1]+(rho-limits[1])/diff(limits)*diff(color_range)
edges <- seq(limits[1],limits[2],length.out=257)
guide <- data.frame(x=key_x(head(edges,-1)),xend=key_x(tail(edges,-1))+.004,
                    color=color((head(edges,-1)+tail(edges,-1))/2))
key_tick <- data.frame(x=key_x(seq(.6,1,.1)),label=c("0.6","0.7","0.8","0.9","1.0"))
left_tick <- data.frame(x=scale_violin(c(.6,.75,.9,1)),label=c("0.60","0.75","0.90","1.0"))
axis_y <- y_bottom-.84

p <- ggplot() +
  geom_tile(data=tiles,aes(x,y,fill=color),width=cell,height=cell,colour=NA) +
  geom_polygon(data=violins,aes(x,y,group=row),fill=density_fill,colour=outline,linewidth=.17) +
  geom_segment(data=tails,aes(x=x,xend=xend,y=y,yend=y),linewidth=.17,colour=outline) +
  geom_segment(data=medians,aes(x=x,xend=x,y=y-.38,yend=y+.38),linewidth=.28,colour=outline) +
  geom_segment(data=tree,aes(x=x,xend=xend,y=y,yend=yend),linewidth=.23,colour=outline,lineend="square") +
  annotate("segment",x=left_axis[1],xend=left_axis[2],y=axis_y,yend=axis_y,linewidth=.21,colour=outline) +
  geom_segment(data=left_tick,aes(x=x,xend=x),y=axis_y,yend=axis_y-.65,linewidth=.18,colour=outline) +
  geom_text(data=left_tick,aes(x=x,label=label),y=axis_y-2.45,family=font_name,size=6.0,size.unit="pt",colour=ink) +
  annotate("text",x=mean(left_axis),y=axis_y-6.1,label="Spearman rho",family=font_name,size=6.5,size.unit="pt",colour=ink) +
  geom_text(data=diagonal,aes(x,y,label=label),hjust=0,family=font_name,size=6.25,size.unit="pt",colour=ink) +
  annotate("text",x=color_range[1],y=145.4,label="cis-eQTL Spearman correlation",hjust=0,
           family=font_name,size=6.5,size.unit="pt",colour=ink) +
  geom_segment(data=guide,aes(x=x,xend=xend,colour=color),y=141.55,yend=141.55,
               linewidth=2.4,lineend="butt") +
  geom_segment(data=key_tick,aes(x=x,xend=x),y=140.64,yend=139.94,linewidth=.18,colour=outline) +
  geom_text(data=key_tick,aes(x=x,label=label),y=137.95,family=font_name,size=6.0,size.unit="pt",colour=ink) +
  annotate("text",x=2.0,y=150.2,label="a",hjust=0,family=font_name,fontface="bold",size=9.0,size.unit="pt",colour=ink) +
  scale_fill_identity(na.value=NA,guide="none") +
  scale_colour_identity(guide="none") +
  coord_fixed(xlim=c(0,width),ylim=c(0,height),expand=FALSE,clip="on") +
  cowplot::theme_nothing() +
  theme(plot.margin=margin(0,0,0,0),plot.background=element_rect(fill="white",colour=NA),
        panel.background=element_rect(fill="white",colour=NA))

paths <- file.path(out,paste0("sheepgtex-fig5a.",c("png","pdf")))
font <- bf_font(font_name)
auth <- Sys.getenv("BIOFIGURE_RENDER_AUTH")
if(nzchar(auth)){
  spec_file <- Sys.getenv("BIOFIGURE_DESIGN_SPEC")
  spec <- yaml::read_yaml(spec_file)
  # The diagonal label and top-right guide boxes overlap the lattice's rectangular
  # envelope. They occupy the uncolored top triangle, so their painted areas are disjoint.
  bounds <- data.frame(id=c("data","labels","legend"),x=c(25.2,25.5,130.0),y=c(y_bottom,y_bottom,136.0),
                       w=c(n*cell,151.0,46.4),h=c(n*cell,n*cell,12.5))
  bf_render_png(p,paths[1],font,unlist(spec$text_contract$allowed_text),width,height,width,
                c(spec_file,self,helper,input,lut),bounds,
                allowed_pairs=c("data:labels","data:legend","labels:legend"),
                dpi=420,authorization=auth,publication_size_class="double-column",skill_root=skill)
} else {
  ggsave(paths[1],p,device=ragg::agg_png,width=width,height=height,units="mm",dpi=420,bg="white")
}
bf_pdf_open(paths[2],width,height,font)
print(p)
if(nzchar(auth)){
  built <- ggplot_build(p)
  plan <- bf_ggplot_cell_plan(p,built,heatmap_required=TRUE)
  cells <- bf_measure_ggplot_cells(plan,ggplot_gtable(built))
}
invisible(dev.off())
pdf_audit <- bf_pdf_finalize(paths[2],font,width,height)
if(nzchar(auth)){
  pdf_audit$heatmap_cells <- cells
  jsonlite::write_json(pdf_audit,paste0(paths[2],".audit.json"),auto_unbox=TRUE,pretty=TRUE,digits=NA)
}
