# Navarrete et al. Nature Genetics Fig. 3b, left and center.
# Usage: Rscript draw_figure.R [output-dir]
args <- commandArgs(TRUE)
self <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))
case <- dirname(self)
out <- if (length(args)) args[1] else file.path(case, "figures")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
library(ggplot2)

skill <- Sys.getenv("BIOFIGURE_ROOT", file.path(path.expand("~"), ".codex", "skills", "biofigure"))
helper <- normalizePath(file.path(skill, "scripts", "figure_style.R"), mustWork = TRUE)
source(helper)
family <- "Arial"
width <- 182
height <- 96
cell <- 1.87
x_left <- 17
y_top <- 83.2
mark_step <- 11 * cell + 1.4
species_step <- 6 * cell + 3.65
bottom <- y_top - 3 * species_step - 6 * cell
species <- c("Cfra", "Spun", "Atha", "Ngru")
marks <- c("H3K9ac", "H3K27ac", "H4K16ac", "H3K27me3", "H3K9me3")
features <- c("Promoter", paste("Bin", 1:9), "Last bin")
x_mark <- setNames(x_left + (0:4)*mark_step, marks)
y_species <- setNames(y_top - (0:3)*species_step, species)
group_y <- function(s, c) unname(y_species[s]) - (c - .5)*cell
low <- "#4682B4"
neutral <- "#FFFFFF"
high <- "#CD0000"
missing <- "#B8B8B8"
ink <- "#30343B"
axis_ink <- "#4D5157"

input <- file.path(case, "plot_data", paste0("ichip-fig3b-", c("heatmap", "boxplots"), ".csv"))
coverage <- read.csv(input[1])
genes <- read.csv(input[2])
stopifnot(nrow(coverage)==1320L, nrow(genes)==61460L)
coverage$x <- unname(x_mark[coverage$mark]) + (match(coverage$feature, features)-.5)*cell
coverage$y <- group_y(coverage$species, coverage$cluster)
blocks <- split(coverage, interaction(factor(coverage$mark, levels = marks),
                                      factor(coverage$species, levels = species)), drop = TRUE)
stopifnot(length(blocks)==20L, all(lengths(lapply(blocks, rownames))==66L))
tile_layers <- lapply(blocks, function(b) geom_tile(data=b, aes(x,y,fill=coverage),
                            width=cell,height=cell,linewidth=.13,colour="white"))
frames <- do.call(rbind,lapply(seq_along(blocks),function(i){
  b <- blocks[[i]]
  xx <- range(b$x) + c(-.5,.5)*cell
  yy <- range(b$y) + c(-.5,.5)*cell
  data.frame(x=xx[c(1,2,2,1,1)],y=yy[c(1,1,2,2,1)],block=i)
}))

# Right-hand tracks share each heatmap row center and keep distinct x scales.
tracks <- data.frame(id=c("rna","length"),label=c("Gene\nexpression","Gene\nlength"),
                     field=c("log10_rna_plus_one","log10_gene_length"),
                     axis=c("log10(RNA\ncounts + 1)","log10(gene\nlength)"),
                     floor=c(0,2),ceiling=c(6,5),left=c(128.4,152.6),right=c(148.5,172.0),
                     box_fill=c("#2DB8B3","#AE9CDC"))
to_x <- function(value, track) track$left+(value-track$floor)/(track$ceiling-track$floor)*(track$right-track$left)
groups <- expand.grid(cluster=1:6,species=species,KEEP.OUT.ATTRS=FALSE,stringsAsFactors=FALSE)
groups$y <- group_y(groups$species,groups$cluster)
groups$key <- paste(groups$species,groups$cluster)
gene_groups <- split(genes,paste(genes$species,genes$cluster))
groups$count <- vapply(gene_groups[groups$key],nrow,integer(1))
groups$n <- format(groups$count,big.mark=",",trim=TRUE)
groups$label <- paste("GC",groups$cluster)
boxes <- do.call(rbind,lapply(seq_len(nrow(tracks)),function(j) {
  t <- tracks[j,]
  do.call(rbind,lapply(seq_len(nrow(groups)),function(i) {
    g <- groups[i,]
    values <- gene_groups[[g$key]][[t$field]]
    # The author applies scale limits before calculating Tukey hinges.
    values <- values[is.finite(values) & values >= t$floor & values <= t$ceiling]
    q <- quantile(values,c(.25,.5,.75),type=7,names=FALSE)
    delta <- 1.5*(q[3]-q[1])
    whiskers <- range(values[values>=q[1]-delta & values<=q[3]+delta])
    x <- to_x(c(whiskers[1],q,whiskers[2]),t)
    data.frame(y=g$y,id=paste(t$id,g$key),xmin=x[1],xlower=x[2],xmiddle=x[3],
               xupper=x[4],xmax=x[5],box_fill=t$box_fill)
  }))
}))
ticks <- do.call(rbind,lapply(seq_len(nrow(tracks)),function(j) {
  t <- tracks[j,]
  v <- if(t$id=="rna") c(0,2,4,6) else 2:5
  data.frame(x=to_x(v,t),label=as.character(v))
}))
species_labels <- data.frame(y=unname(y_species)-3*cell,label=species)
mark_labels <- data.frame(x=unname(x_mark)+5.5*cell,label=marks)
positions <- expand.grid(feature=features,mark=marks,KEEP.OUT.ATTRS=FALSE,stringsAsFactors=FALSE)
positions$x <- unname(x_mark[positions$mark]) + (match(positions$feature,features)-.5)*cell
tracks$center <- (tracks$left+tracks$right)/2
palette <- scales::pal_gradient_n(c(low,neutral,high))
guide_start <- 91
guide_end <- 115
swatch <- seq(guide_start,guide_end,length.out=129)
guide <- data.frame(x=head(swatch,-1),xend=tail(swatch,-1)+.005,
                    colour=palette((seq_len(128)-.5)/128))
guide_labels <- data.frame(x=seq(guide_start,guide_end,length.out=5),label=as.character(-2:2))
axes_y <- bottom-1.4
box_axis_y <- bottom-2.0

p <- ggplot() + tile_layers +
  geom_path(data=frames,aes(x,y,group=block),linewidth=.19,colour="#70757A") +
  geom_boxplot(data=boxes,aes(y=y,group=id,xmin=xmin,xlower=xlower,xmiddle=xmiddle,
                             xupper=xupper,xmax=xmax,colour=I(ink),fill=I(box_fill)),
               stat="identity",position="identity",orientation="y",width=cell*.62,linewidth=.26,outlier.shape=NA) +
  geom_segment(data=groups,aes(y=y,yend=y),x=15.8,xend=16.5,linewidth=.19,colour=axis_ink) +
  geom_segment(data=species_labels,aes(y=y-3*cell,yend=y+3*cell),
               x=16.5,xend=16.5,linewidth=.19,colour=axis_ink) +
  geom_segment(data=mark_labels,aes(x=x-5.5*cell,xend=x+5.5*cell),
               y=axes_y,yend=axes_y,linewidth=.21,colour=axis_ink) +
  geom_segment(data=positions,aes(x=x,xend=x),y=axes_y,yend=axes_y-.53,
               linewidth=.17,colour=axis_ink) +
  geom_segment(data=tracks,aes(x=left,xend=right),y=box_axis_y,yend=box_axis_y,
               linewidth=.21,colour=axis_ink) +
  geom_segment(data=ticks,aes(x=x,xend=x),y=box_axis_y,yend=box_axis_y-.68,
               linewidth=.19,colour=axis_ink) +
  geom_segment(data=guide,aes(x=x,xend=xend,colour=colour),y=7.45,yend=7.45,linewidth=1.65,lineend="butt") +
  geom_segment(data=guide_labels,aes(x=x,xend=x),y=6.78,yend=6.2,linewidth=.20,colour=axis_ink) +
  annotate("segment",x=119.5,xend=122.0,y=7.45,yend=7.45,linewidth=1.65,colour=missing) +
  annotate("text",x=124,y=7.45,label="Missing",family=family,size=5.8,size.unit="pt",hjust=0,colour=ink) +
  geom_text(data=mark_labels,aes(x=x,label=label),y=88.0,family=family,size=7.3,size.unit="pt",colour=ink) +
  geom_text(data=tracks,aes(x=center,label=label),y=89.2,family=family,size=6.45,size.unit="pt",lineheight=.92,colour=ink) +
  annotate("text",x=179.5,y=88.0,label="n",family=family,fontface="italic",size=6.45,size.unit="pt",hjust=1,colour=ink) +
  annotate("text",x=1.7,y=92,label="b",family=family,fontface="bold",size=8.9,size.unit="pt",hjust=0,colour=ink) +
  geom_text(data=species_labels,aes(y=y,label=label),x=1.7,family=family,size=6.45,size.unit="pt",hjust=0,colour=ink) +
  geom_text(data=groups,aes(y=y,label=label),x=15.0,family=family,size=5.9,size.unit="pt",hjust=1,colour=ink) +
  geom_text(data=groups,aes(y=y,label=n),x=179.6,family=family,size=6.1,size.unit="pt",hjust=1,colour=ink) +
  geom_text(data=positions,aes(x=x,label=feature),y=axes_y-1.25,family=family,size=5.9,size.unit="pt",
            angle=90,hjust=1,colour=ink) +
  geom_text(data=ticks,aes(x=x,label=label),y=box_axis_y-2.7,family=family,size=5.9,size.unit="pt",colour=ink) +
  geom_text(data=tracks,aes(x=center,label=axis),y=17.8,family=family,size=6.45,size.unit="pt",lineheight=.92,colour=ink) +
  annotate("text",x=mean(c(guide_start,guide_end)),y=10.85,label="log2(norm. coverage)",
           family=family,size=5.8,size.unit="pt",colour=ink) +
  geom_text(data=guide_labels,aes(x=x,label=label),y=4.7,family=family,size=5.8,size.unit="pt",colour=ink) +
  scale_fill_gradient2(low=low,mid=neutral,high=high,midpoint=0,limits=c(-2,2),
                       oob=scales::squish,na.value=missing,guide="none") +
  scale_colour_identity(guide="none") +
  coord_fixed(xlim=c(0,width),ylim=c(0,height),expand=FALSE,clip="on") +
  cowplot::theme_nothing() +
  theme(plot.margin=margin(0,0,0,0),plot.background=element_rect(fill="white",colour=NA),
        panel.background=element_rect(fill="white",colour=NA))

paths <- file.path(out,paste0("ichip-fig3b.",c("png","pdf")))
font <- bf_font(family)
auth <- Sys.getenv("BIOFIGURE_RENDER_AUTH")
if (nzchar(auth)) {
  spec_file <- Sys.getenv("BIOFIGURE_DESIGN_SPEC")
  spec <- yaml::read_yaml(spec_file)
  bbox <- data.frame(id=c("data","labels","legend"),x=c(17,12,88),y=c(bottom,12.5,3.3),
                     w=c(163,167,46),h=c(y_top-bottom,bottom-13,8.1))
  bf_render_png(p,paths[1],font,unlist(spec$text_contract$allowed_text),width,height,width,
                c(spec_file,self,helper,input),bbox,dpi=420,authorization=auth,
                min_text_pt=5.8,text_size_authorization="Twenty small source heatmaps at 182 mm with 55 vertical feature labels; verified at actual size.",
                publication_size_class="double-column",skill_root=skill)
} else {
  ggsave(paths[1],p,device=ragg::agg_png,width=width,height=height,units="mm",dpi=420,bg="white")
}
bf_pdf_open(paths[2],width,height,font)
print(p)
if (nzchar(auth)) {
  built <- ggplot_build(p)
  plan <- bf_ggplot_cell_plan(p,built,heatmap_required=TRUE)
  cells <- bf_measure_ggplot_cells(plan,ggplot_gtable(built))
}
invisible(dev.off())
pdf_audit <- bf_pdf_finalize(paths[2],font,width,height)
if (nzchar(auth)) {
  pdf_audit$heatmap_cells <- cells
  jsonlite::write_json(pdf_audit,paste0(paths[2],".audit.json"),auto_unbox=TRUE,pretty=TRUE,digits=NA)
}
