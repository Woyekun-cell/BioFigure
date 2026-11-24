# Chen et al. Nature Communications Fig. 7a-b, independent rendering of author data.
# Rscript draw_figure.R path/to/plot_data path/to/output
suppressPackageStartupMessages({library(ggplot2); library(grid)})
args <- commandArgs(TRUE)
if (length(args) != 2L) stop("Give the plot-data and output directories.")
input <- normalizePath(args[1], mustWork=TRUE)
dir.create(args[2], recursive=TRUE, showWarnings=FALSE)
output <- normalizePath(args[2], mustWork=TRUE)
files <- list.files(input, pattern="\\.csv$", full.names=TRUE)
read <- function(x) read.csv(file.path(input,x), check.names=FALSE, na.strings="")
survey <- read("survey-observations.csv")
species <- read("species-heatmap.csv")
tree <- read("tree-edges.csv")
anova <- read("author-anova-verification.csv")
metrics <- c("ShiftLower","ShiftUpper","ShiftMean","ChangeSize")
titles <- c("Lower edge shift","Upper edge shift","Mean range shift","Range extent change")
short <- c("lower","upper","mean","extent")
classes <- c("Magnoliopsida","Liliopsida","Pinopsida","Polypodiopsida",
             "Aves","Mammalia","Amphibia","Actinopterygii","Insecta")
palette <- setNames(c("#527CBF","#007BA6","#108783","#4C7547","#8A9C43",
                     "#BF8A14","#B5854F","#A75347","#D35132"),classes)
stopifnot(nrow(survey)==845L, nrow(species)==730L, nrow(tree)==1345L,
          !anyDuplicated(species$tip_label), identical(anova$metric,metrics),
          identical(rle(species$Class)$values,classes),all(survey$Unite=="m/year"),
          !anyNA(survey[c(metrics,"Class","NullEffect")]),!anyNA(species[metrics]))
canvas_width <- 182
canvas_height <- 170
ink <- "#282C31"
border <- "#CCD3DA"
text_size <- 6.1
font <- "Arial"
y_bottom <- 9
y_height <- 149
n <- nrow(species)
y_cell <- y_height/n
y_plot <- function(idx) y_bottom+(idx-.5)*y_cell
x_tree <- function(x) 6+x/max(tree$x_child)*36
x_heat <- c(51.0,58.0,65.0,72.0)
heat_cell_width <- 6.0
limit <- 20
gradient <- scales::col_numeric(c("#FEF428","#CB9EA8","#3609EA"),domain=c(-limit,limit))
mixed <- function(x, opacity) vapply(x, function(color) {
  rgb <- grDevices::col2rgb(color)
  grDevices::rgb(t(rgb*opacity+255*(1-opacity)),maxColorValue=255)
}, character(1))
paper_rect <- function(x1,y1,x2,y2,fill,stroke=NA,width=.55) {
  rectGrob((x1+x2)/(2*canvas_width),(y1+y2)/(2*canvas_height),
      (x2-x1)/canvas_width,(y2-y1)/canvas_height,
      gp=gpar(fill=fill,col=stroke,lwd=width,linejoin="mitre"))
}
rect_layer <- function(grob) annotation_custom(grob,0,canvas_width,0,canvas_height)
runs <- rle(species$Class)
group_hi <- n-c(0L,head(cumsum(runs$lengths),-1L))
group_lo <- n-cumsum(runs$lengths)
class_rects <- paper_rect(43.1,y_bottom+group_lo*y_cell,46.0,
                          y_bottom+group_hi*y_cell,mixed(palette[runs$values],.57))
shade_breaks <- seq(-limit,limit,length.out=129)
shade_x <- seq(7,38,length.out=length(shade_breaks))
key <- paper_rect(head(shade_x,-1),160.9,tail(shade_x,-1)+.04,162.7,
                   gradient((head(shade_breaks,-1)+tail(shade_breaks,-1))/2))
heat <- data.frame(x=rep(x_heat,each=n),y=rep(y_plot(species$tree_y),4),
                   value=unlist(species[metrics],use.names=FALSE))
heat$fill <- gradient(heat$value)
stopifnot(nrow(heat)==2920L,!anyNA(heat$fill))
labels <- function(x,y,label,size=text_size,hjust=.5,color=ink,bold=FALSE) {
  annotate("text",x=x,y=y,label=label,size=size,size.unit="pt",family=font,
           hjust=hjust,color=color,fontface=if (bold) "bold" else "plain")
}
panel_x <- c(107,178)
panel_top <- c(167,126.2,85.4,44.6)
panel_bottom <- panel_top-36.6
panel_header <- panel_top-4.9
panel_background <- paper_rect(panel_x[1],panel_bottom,panel_x[2],panel_top,"white",border)
header_background <- paper_rect(panel_x[1],panel_header,panel_x[2],panel_top,"#F0F3F6",border)
labels_y <- function(i) seq(panel_header[i]-2.25,panel_bottom[i]+2.25,length.out=9)
x_pos <- function(x,i) {
  domain <- if (i == 4L) c(-20,21) else c(-8.5,13)
  panel_x[1]+diff(panel_x)*(x-domain[1])/diff(domain)
}
p <- ggplot() +
  rect_layer(class_rects) +
  geom_segment(data=tree,aes(x=x_tree(x_parent),xend=x_tree(x_child),
    y=y_plot(y_child),yend=y_plot(y_child)),linewidth=.115,colour=ink) +
  geom_segment(data=tree,aes(x=x_tree(x_parent),xend=x_tree(x_parent),
    y=y_plot(y_parent),yend=y_plot(y_child)),linewidth=.115,colour=ink) +
  geom_tile(data=heat,aes(x=x,y=y,fill=fill),width=heat_cell_width,height=y_cell) +
  scale_fill_identity() +
  rect_layer(key) +
  labels(7,165.7,"Shift (m/year)",7.5,hjust=0) +
  labels(c(7,14.75,22.5,30.25,38),159.2,c("-20","-10","0","10","20")) +
  labels(mean(c(43.1,46.0)),159.4,"Class",6.3) +
  labels(x_heat,6.2,short,6.5) +
  labels(c(2.7,86),166.4,c("a","b"),9,bold=TRUE) +
  rect_layer(panel_background) + rect_layer(header_background)

boxes <- list()
for (i in seq_along(metrics)) {
  ypos <- labels_y(i)
  metric <- metrics[i]
  stats <- anova[i,]
  tick <- if (i==4L) c(-10,0,10,20) else c(-5,0,5,10)
  guide <- data.frame(x=x_pos(tick,i),y=panel_bottom[i],end=panel_header[i])
  boxes[[i]] <- do.call(rbind,lapply(seq_along(classes),function(j) {
      values <- survey[[metric]][survey$Class==classes[j]]
      quartiles <- quantile(values,c(.25,.50,.75),names=FALSE,type=7)
      spread <- diff(quartiles[c(1,3)])*1.5
      kept <- values[values>=quartiles[1]-spread & values<=quartiles[3]+spread]
      data.frame(y=ypos[j],lower=x_pos(quartiles[1],i),median=x_pos(quartiles[2],i),
                 upper=x_pos(quartiles[3],i),whisker_lo=x_pos(min(kept),i),
                 whisker_hi=x_pos(max(kept),i),col=unname(palette[j]))
  }))
  bx <- boxes[[i]]
  points <- data.frame(x=x_pos(survey[[metric]],i),y=ypos[match(survey$Class,classes)] +
    (((survey$survey_row_id*137L)%%173L)/172-.5)*.46)
  text_p <- if (stats$p < .0001) formatC(stats$p,format="e",digits=1) else
    formatC(stats$p,format="f",digits=if(stats$p<.01) 4 else 3)
  test_label <- sprintf("F(%d, %d) = %.2f, p = %s",stats$df1,stats$df2,stats$f,text_p)
  p <- p +
    geom_segment(data=guide,aes(x=x,xend=x,y=y,yend=end),colour="#E6EBEF",linewidth=.19) +
    annotate("segment",x=x_pos(0,i),xend=x_pos(0,i),y=panel_bottom[i],yend=panel_header[i],
             colour="#9AA3AA",linewidth=.37,linetype="dashed") +
    geom_point(data=points,aes(x=x,y=y),colour="#414953",size=.41,alpha=.24) +
    geom_segment(data=bx,aes(x=whisker_lo,xend=whisker_hi,y=y,yend=y,colour=col),linewidth=.30) +
    rect_layer(paper_rect(bx$lower,bx$y-.98,bx$upper,bx$y+.98,
                           mixed(bx$col,.21),bx$col,.80)) +
    geom_segment(data=bx,aes(x=median,xend=median,y=y-.98,yend=y+.98,colour=col),linewidth=.48) +
    rect_layer(paper_rect(103.4,ypos-.54,104.7,ypos+.54,palette)) +
    labels(102.6,ypos,classes,text_size,hjust=1) +
    labels(109,mean(c(panel_header[i],panel_top[i])),titles[i],7.2,hjust=0,bold=TRUE) +
    labels(176.3,mean(c(panel_header[i],panel_top[i])),test_label,6.25,hjust=1) +
    labels(x_pos(tick,i),panel_bottom[i]-1.65,as.character(tick))
}
p <- p + labels(mean(panel_x),3.1,"Range shift (m/year)",7.5) + scale_colour_identity() +
  coord_cartesian(xlim=c(0,canvas_width),ylim=c(0,canvas_height),expand=FALSE) +
  theme_void(base_family=font) +
  theme(plot.margin=margin(0,0,0,0,"mm"),plot.background=element_rect(fill="white",color=NA))
name <- "climate-range-shift-fig7"
png <- file.path(output,paste0(name,".png"))
pdf <- file.path(output,paste0(name,".pdf"))
auth <- Sys.getenv("BIOFIGURE_RENDER_AUTHORIZATION")
if (nzchar(auth)) {
  helper <- Sys.getenv("BIOFIGURE_R_HELPER")
  spec <- Sys.getenv("BIOFIGURE_DESIGN_SPEC")
  script <- sub("^--file=","",grep("^--file=",commandArgs(),value=TRUE))
  source(helper)
  design <- yaml::read_yaml(spec)
  bounds <- data.frame(id=c("data","labels","legend"),x=c(6,77,6),y=c(7,2,158.1),
                       w=c(172,102,33),h=c(160,165,9))
  bf_render_png(p,png,font=bf_font(font),allowed_text=unlist(design$text_contract$allowed_text),
                width_mm=canvas_width,height_mm=canvas_height,target_width_mm=canvas_width,
                source_files=c(script,helper,spec,sort(files)),boxes=bounds,
                allowed_pairs=c("data:labels","data:legend"),dpi=360,min_text_pt=6.1,
                authorization=auth,skill_root=dirname(dirname(helper)),publication_size_class="double-column")
} else {
  ggsave(png,p,width=canvas_width,height=canvas_height,units="mm",dpi=360,bg="white",device=ragg::agg_png)
}
if (capabilities("aqua")) {
  grDevices::quartz(type="pdf",file=pdf,width=canvas_width/25.4,height=canvas_height/25.4,
                    family=font,bg="white")
  print(p)
  invisible(grDevices::dev.off())
} else {
  ggsave(pdf,p,width=canvas_width,height=canvas_height,units="mm",bg="white",
         family=font,device=grDevices::cairo_pdf)
}
writeLines(capture.output(sessionInfo()),file.path(output,"R-session.txt"))
