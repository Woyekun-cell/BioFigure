library(ggplot2)

draw_marker_matrix <- function(input_dir, font = "Arial") {
  read <- function(name) read.csv(file.path(input_dir,paste0(name,".csv")),stringsAsFactors=FALSE)
  bubbles <- read("bubbles")
  markers <- read("markers")
  rows <- read("rows")
  branches <- read("branches")
  roots <- read("roots")
  valid_order <- function(i) identical(sort(as.integer(i)),seq_along(i)) && all(i == as.integer(i))
  stopifnot(!anyDuplicated(markers$gene), !anyDuplicated(rows$cell_type),
            valid_order(markers$x), valid_order(rows$y),
            nrow(bubbles)==nrow(markers)*nrow(rows), !anyDuplicated(bubbles[c("gene","cell_type")]),
            all(is.finite(bubbles$scaled)), all(is.finite(bubbles$pct) & bubbles$pct>=0 & bubbles$pct<=100),
            all(grepl("^#[0-9A-Fa-f]{6}$",c(markers$color,rows$color))),
            all(branches$yend[branches$xend == -5.4] %in% rows$y))
  bubbles$x <- markers$x[match(bubbles$gene, markers$gene)]
  bubbles$y <- rows$y[match(bubbles$cell_type, rows$cell_type)]
  stopifnot(!anyNA(bubbles$x),!anyNA(bubbles$y))
  ggplot() +
    geom_rect(data=bubbles,aes(xmin=x-.5,xmax=x+.5,ymin=y-.5,ymax=y+.5),
              fill="white",colour="#E9E7ED",linewidth=.12) +
    geom_rect(data=markers,aes(xmin=x-.5,xmax=x+.5,ymin=.11,ymax=.31,fill=I(color)),colour=NA) +
    geom_point(data=bubbles,aes(x=x,y=y,size=pct,fill=scaled),shape=21,colour="#57466C",stroke=.055) +
    geom_segment(data=branches,aes(x=x,y=y,xend=xend,yend=yend),colour="#A293BF",linewidth=.45,lineend="round") +
    geom_point(data=rows,aes(x=-5.25,y=y,fill=I(color)),shape=21,colour="white",stroke=.18,size=2.5) +
    geom_text(data=rows,aes(x=-4.6,y=y,label=cell_type),family=font,hjust=0,size=7/.pt) +
    geom_text(data=roots,aes(x=x,y=y,label=lineage),family=font,hjust=1,size=7/.pt) +
    scale_fill_gradientn(colours=c("#F4F0FA","#A49BCC","#4A1486"),breaks=-1:2,name="Scaled mean expression",
      guide=guide_colourbar(display="rectangles",order=1,title.position="left",barwidth=grid::unit(23,"mm"),barheight=grid::unit(2,"mm"))) +
    scale_size_area(max_size=2.35,limits=c(0,100),breaks=seq(0,100,25),name="Expression (%)",
      guide=guide_legend(order=2,title.position="left",override.aes=list(fill="white",colour="#57466C",stroke=.22))) +
    scale_x_continuous(breaks=markers$x,labels=markers$gene,expand=expansion(0)) +
    scale_y_continuous(breaks=NULL,expand=expansion(0)) +
    coord_fixed(ratio=1,xlim=c(-13.6,nrow(markers)+.5),ylim=c(.05,nrow(rows)+.58),clip="off") +
    labs(x=NULL,y=NULL) +
    theme_minimal(base_family=font,base_size=7) +
    theme(panel.grid=element_blank(),axis.text.x=element_text(size=7,angle=90,hjust=1,vjust=.5,colour="#16121B"),
          legend.text=element_text(size=7),legend.title=element_text(size=7),legend.position="top",legend.box="horizontal",legend.spacing.x=grid::unit(4,"mm"),
          legend.box.spacing=grid::unit(2,"mm"),legend.margin=margin(0),
          legend.key.width=grid::unit(4,"mm"),legend.key.height=grid::unit(3,"mm"),
          plot.margin=margin(5,5,5,5,"mm"))
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly=TRUE)
  if (length(args) != 2L) stop("Usage: Rscript draw_figure.R plot_data_directory output_directory")
  dir.create(args[2],recursive=TRUE,showWarnings=FALSE)
  p <- draw_marker_matrix(args[1])
  for (ext in c("png","pdf")) {
    file <- file.path(args[2],paste0("marker-bubble-tree.",ext))
    if (ext=="png") ragg::agg_png(file,width=183,height=71,units="mm",res=320,background="white")
    else grDevices::quartz(type="pdf",file=file,width=183/25.4,height=71/25.4,family="Arial")
    print(p)
    invisible(dev.off())
  }
}
