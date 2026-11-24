# Kindt et al., Scientific Data (2025), Fig. 2, independent visual reproduction.
# Usage: Rscript draw_figure.R <plot-data-directory> <output-directory>
suppressPackageStartupMessages({library(grid); library(ggplot2); library(cowplot)})
args <- commandArgs(TRUE)
if (length(args) != 2L) stop("Usage: Rscript draw_figure.R <plot-data-directory> <output-directory>")
input <- normalizePath(args[1], mustWork=TRUE)
dir.create(args[2],showWarnings=FALSE,recursive=TRUE)
output <- normalizePath(args[2],mustWork=TRUE)
files <- file.path(input,c("family-tracks.csv","tree-edges.csv"))
family <- read.csv(files[1])
edges <- read.csv(files[2])
codes <- c("AFR","OAS","EAS","SAM","NAM","AUS","PAC","EUR")
regions <- c("Africa","Tropical Asia","Temperate Asia","Southern America","Northern America",
            "Australasia","Pacific","Europe")
count <- nrow(family)
stopifnot(identical(as.integer(family$rank),seq_len(count)), !anyDuplicated(family$family),
   count >= 2L, all(codes %in% names(family)), !anyNA(family), !anyNA(edges),
   all(family$databases>=0 & family$databases<=60))
values <- as.matrix(family[codes])
stopifnot(all(values>=0), max(values)>1)

width_mm <- 182
height_mm <- 154
xc <- 72.2
yc <- 77
font <- "Arial"
gap <- 8*pi/180
theta <- function(rank) (rank-.5)/count*(2*pi-gap)
x <- function(r,a) (xc+r*cos(a))/width_mm
y <- function(r,a) (yc+r*sin(a))/height_mm
text_gp <- function(pt, color="#26383B") gpar(fontfamily=font,fontsize=pt,col=color)
label <- function(text,x_mm,y_mm,pt=6,color="#26383B",...) {
  textGrob(text,x_mm/width_mm,y_mm/height_mm,gp=text_gp(pt,color),...)
}
zero_color <- "#E3E7E8"
bar_color <- "#65D8B7"
tree_color <- "#25383D"
palette <- viridisLite::viridis(192)
positive_color <- function(v) {
  p <- (sqrt(v)-1)/(sqrt(max(values))-1)
  palette[1L+round(p*(length(palette)-1L))]
}
tiles_color <- rep(zero_color,length(values))
tiles_color[values>0] <- positive_color(values[values>0])

# A wedge is bounded by two concentric arcs; IDs prevent connectors across tips.
ring <- function(a,b,r0,r1,fill) {
  n <- length(a)
  angle <- outer(c(0,.5,1),b-a)+rep(a,each=3L)
  path <- c(rbind(angle,angle[3:1,,drop=FALSE]))
  rr <- c(rbind(matrix(rep(r1,length.out=n),3,n,byrow=TRUE),
                matrix(rep(r0,length.out=n),3,n,byrow=TRUE)))
  polygonGrob(x(rr,path),y(rr,path),id.lengths=rep(6L,n),gp=gpar(fill=fill,col=NA))
}
r_tip <- 36.4
pa <- theta(edges$parent_rank)
ca <- theta(edges$child_rank)
pr <- edges$parent_depth_ma/max(edges$child_depth_ma)*r_tip
cr <- edges$child_depth_ma/max(edges$child_depth_ma)*r_tip
arc_steps <- pmax(2L,ceiling(abs(ca-pa)*46))
arc_theta <- unlist(Map(seq,pa,ca,length.out=arc_steps),use.names=FALSE)
arc_r <- rep(pr,arc_steps)
branch_style <- gpar(col=tree_color,lwd=.48,lineend="butt")
tree <- grobTree(polylineGrob(x(arc_r,arc_theta),y(arc_r,arc_theta),
  id.lengths=arc_steps,gp=branch_style),
  segmentsGrob(x(pr,ca),y(pr,ca),x(cr,ca),y(cr,ca),gp=branch_style))
   
hm_start <- 37.3
hm_step <- 1.63
tile_lo <- theta(rep(family$rank-.492,8))
tile_hi <- theta(rep(family$rank+.492,8))
radius <- hm_start+rep(0:7,each=count)*hm_step
heatmap <- ring(tile_lo,tile_hi,radius,radius+hm_step*.967,tiles_color)
base_bar <- 52.0
span_bar <- 14.4
bar_at <- function(n) base_bar+span_bar*n/60
guide_angle <- seq(0,2*pi-gap,length.out=360)
guides <- lapply(seq(10,60,10),function(v)
  polylineGrob(x(bar_at(v),guide_angle),y(bar_at(v),guide_angle),
    gp=gpar(col="#DDE4E4",lwd=.68,lineend="butt")))
bars <- ring(theta(family$rank-.39),theta(family$rank+.39),base_bar,
             bar_at(family$databases),bar_color)
marks_angle <- 2*pi-gap/2
hm_mid <- hm_start+(.5+0:7)*hm_step
ticks <- c(0,20,40,60)
bar_pos <- bar_at(ticks)
marks <- grobTree(
  textGrob(as.character(1:8),x(hm_mid,marks_angle),y(hm_mid,marks_angle),gp=text_gp(6)),
  textGrob(as.character(ticks),x(bar_pos,marks_angle),y(bar_pos,marks_angle),gp=text_gp(6))
)

selected <- family[family$show_label,]
ann_angle <- theta(selected$rank)
ann_theta <- ann_angle + ifelse(selected$family=="Melastomataceae",2*pi/180,0)
ann_r <- 69.4+ifelse(selected$family=="Melastomataceae",4.1,0)+ifelse(selected$family=="Annonaceae",1.5,0)
ann_rotate <- (ann_theta*180/pi+180)%%180-90
family_labels <- grobTree(
  segmentsGrob(x(66.6,ann_angle), y(66.6,ann_angle),x(67.75,ann_angle),y(67.75,ann_angle),
               gp=gpar(col="#697B7F",lwd=.68)),
  textGrob(selected$family,x(ann_r,ann_theta),y(ann_r,ann_theta),rot=ann_rotate,gp=text_gp(6.3))
)

key_x <- 148
bar_x <- key_x+2.3
legend_start <- 93.2
legend_length <- 24.7
bounds <- seq(legend_start,legend_start+legend_length,length.out=length(palette)+1)
mids <- (head(bounds,-1)+tail(bounds,-1))/2
legend_ticks <- c(1,100,500,1000,2000)
legend_y <- legend_start+legend_length*(sqrt(legend_ticks)-1)/(sqrt(max(values))-1)
key <- grobTree(
  label("Native tree species",key_x,124,7.5,just="left"),
  rectGrob(bar_x/width_mm,mids/height_mm,4.6/width_mm,
    (diff(bounds)[1]+.04)/height_mm,gp=gpar(fill=palette,col=NA)),
  segmentsGrob((bar_x+2.3)/width_mm,legend_y/height_mm,(bar_x+3.4)/width_mm,legend_y/height_mm,
    gp=gpar(col="#708082",lwd=.48)),
  label(as.character(legend_ticks),bar_x+4.8,legend_y,6,just="left"),
  rectGrob((key_x+1.2)/width_mm,88.7/height_mm,2.4/width_mm,2.4/height_mm,gp=gpar(fill=zero_color,col=NA)),
  label("0 species",key_x+3.7,88.7,6.4,just="left"),
  label("Region",key_x,78.9,7.5,just="left"),
  label(as.character(1:8),key_x+.3,seq(72.7,43.3,length.out=8),6.4,just="left"),
  label(regions,key_x+4.5,seq(72.7,43.3,length.out=8),6.4,just="left"),
  rectGrob((key_x+1.2)/width_mm,32.0/height_mm,2.4/width_mm,2.4/height_mm,gp=gpar(fill=bar_color,col=NA)),
  label("Contributing databases",key_x+3.7,32,6.4,just="left")
)

scene <- do.call(grobTree,c(list(tree,heatmap),guides,list(bars,marks,family_labels,key)))
figure <- ggdraw()+draw_grob(scene)
png <- file.path(output,"agroforestry-fig2.png")
pdf <- file.path(output,"agroforestry-fig2.pdf")
authorization <- Sys.getenv("BIOFIGURE_RENDER_AUTHORIZATION")
if (nzchar(authorization)) {
  helper <- Sys.getenv("BIOFIGURE_R_HELPER")
  spec <- Sys.getenv("BIOFIGURE_DESIGN_SPEC")
  renderer <- sub("^--file=","",grep("^--file=",commandArgs(),value=TRUE))
  source(helper)
  design <- yaml::read_yaml(spec)
  boxes <- data.frame(id=c("data","labels","legend"),x=c(5,1.4,146),y=c(10,1.8,27),
     w=c(134,141.5,35),h=c(134,150,102))
  bf_render_png(figure,png,font=bf_font(font),allowed_text=unlist(design$text_contract$allowed_text),
    width_mm=width_mm,height_mm=height_mm,target_width_mm=width_mm,
    source_files=c(renderer,helper,spec,sort(files)),boxes=boxes,allowed_pairs="data:labels",
    dpi=360,min_text_pt=6,authorization=authorization,skill_root=dirname(dirname(helper)),
    publication_size_class="double-column")
} else {
  ggsave(png,figure,width=width_mm,height=height_mm,units="mm",dpi=360,bg="white",device=ragg::agg_png)
}
if (identical(Sys.info()[["sysname"]],"Darwin")) {
  grDevices::quartz(type="pdf",file=pdf,width=width_mm/25.4,height=height_mm/25.4,bg="white",family=font)
  grid.newpage()
  grid.draw(scene)
  invisible(dev.off())
} else {
  ggsave(pdf,figure,width=width_mm,height=height_mm,units="mm",bg="white",family=font,device=grDevices::cairo_pdf)
}
writeLines(capture.output(sessionInfo()),file.path(output,"R-session.txt"))
