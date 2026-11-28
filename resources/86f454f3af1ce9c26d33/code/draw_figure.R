# Lambuta, Nanni et al. (2023), Figure 1d,e.
# Base measurements come directly from the source-data tables. Rotation and page assembly are native grid.
prepare_pairs <- function(table, order, diagonal=FALSE, direction=1) {
  stopifnot(is.data.frame(table), ncol(table) >= 3L, !anyDuplicated(names(table)),
            length(order) >= 2L, !anyNA(order), all(nzchar(order)), !anyDuplicated(order),
            is.logical(diagonal), length(diagonal) == 1L, !is.na(diagonal),
            length(direction) == 1L, direction %in% c(-1, 1))
  left <- match(table[[1]], order)
  right <- match(table[[2]], order)
  i <- pmin(left, right)
  j <- pmax(left, right)
  n <- length(order)
  expected <- n * (n - 1L) / 2L + n * diagonal
  if (anyNA(i) || (!diagonal && any(i == j)) || anyDuplicated(paste(i, j)) || length(i) != expected) {
    stop("Pair table must contain every declared unordered pair exactly once")
  }
  ratios <- unlist(table[-c(1,2)], use.names=FALSE)
  if (!is.numeric(ratios) || any(!is.finite(ratios) | ratios <= 0)) {
    stop("Every source ratio must be finite and strictly positive")
  }
  data.frame(i=i, j=j, comparison=rep(names(table)[-c(1,2)], each=length(i)),
             ratio=ratios, value=direction*log2(ratios), stringsAsFactors=FALSE)
}

block_split <- function(n, group_sizes) {
  stopifnot(length(group_sizes) > 0L, all(is.finite(group_sizes)), all(group_sizes >= 1),
            all(group_sizes == floor(group_sizes)), sum(group_sizes) == n)
  head(cumsum(group_sizes), -1L)
}

rotate <- function(i, j, n, width, x_center, y_base) {
  step <- width / (2*n)
  list(x=x_center+(i+j-n-1)*step, y=y_base+(j-i)*step)
}

cell_vertices <- function(i, j, n, width, x_center, y_base, diagonal) {
  stopifnot(length(i) == length(j), all(i >= 1 & j <= n & i <= j), diagonal || all(i < j),
            is.finite(width), width > 0)
  u <- outer(c(-.5,.5,.5,-.5), i, "+")
  v <- outer(c(-.5,-.5,.5,.5), j, "+")
  vertices <- rotate(u, v, n, width, x_center, y_base)
  c(vertices, list(cell_mm=width/(sqrt(2)*n)))
}

color_values <- function(value, limit) {
  stopifnot(length(limit) == 1L, is.finite(limit), limit > 0, all(is.finite(value)))
  index <- round((pmin(limit,pmax(-limit,value))+limit)/(2*limit)*512)+1L
  anchors <- c("#053061","#2166AC","#4393C3","#92C5DE","#D1E5F0","#F7F7F7",
               "#FDDBC7","#F4A582","#D6604D","#B2182B","#67001F")
  grDevices::colorRampPalette(anchors)(513)[index]
}

p_label <- function(p) {
  stopifnot(length(p) == 1L, is.finite(p), p > 0, p <= 1)
  if (p >= .001) return(format(signif(p,2),scientific=FALSE,trim=TRUE))
  parts <- strsplit(formatC(p,format="e",digits=1),"e",fixed=TRUE)[[1]]
  exponent <- sub("^-","−",as.character(as.integer(parts[2])))
  paste0(sub("\\.0$","",parts[1])," × 10^{",exponent,"}")
}

mm <- function(x) grid::unit(x,"mm")
ink <- "#16151A"
point <- function(x,y,label,size=6.2,just="centre",angle=0,face="plain") {
  if (length(label)==1L && grepl("[_^]\\{",label)) {
    matches <- gregexpr("[_^]\\{[^}]+\\}|[^_^]+",label,perl=TRUE)
    tokens <- regmatches(label,matches)[[1]]
    style <- substr(tokens,1,1)
    glyphs <- sub("^[^a-zA-Z0-9 ]\\{(.*)\\}$","\\1",tokens)
    scales <- ifelse(style %in% c("_","^"),.84,1)
    shifts <- ifelse(style=="^",.68,ifelse(style=="_",-.48,0))
    pieces <- lapply(seq_along(tokens),function(i)
      grid::textGrob(glyphs[i],mm(0),mm(shifts[i]),just="left",
                     gp=grid::gpar(col=ink,fontfamily="Arial",fontsize=size*scales[i],fontface=face)))
    widths <- lapply(pieces,grid::grobWidth)
    total <- Reduce(`+`,widths)
    offset <- switch(just,left=mm(0),right=-total,-total/2)
    for (i in seq_along(pieces)) {
      pieces[[i]]$x <- offset
      offset <- offset+widths[[i]]
    }
    return(grid::gTree(children=do.call(grid::gList,pieces),
                        vp=grid::viewport(x=mm(x),y=mm(y),width=mm(0),height=mm(0),angle=angle)))
  }
  grid::textGrob(label,mm(x),mm(y),just=just,rot=angle,
                gp=grid::gpar(col=ink,fontfamily="Arial",fontsize=size,fontface=face,lineheight=.98))
}
lines_mm <- function(x,y,color=ink,lwd=.8) {
  grid::linesGrob(mm(x),mm(y),gp=grid::gpar(col=color,lwd=lwd,lineend="butt",linejoin="mitre"))
}

plot_panel <- function(tiles, labels, groups, x, y, width, limit, diagonal) {
  n <- length(labels)
  split <- block_split(n, groups)
  stopifnot(length(split) == 1L)
  vertices <- cell_vertices(tiles$i, tiles$j, n, width, x, y, diagonal)
  k <- split + .5
  outline <- rotate(c(.5,.5,n+.5),c(.5,n+.5,n+.5),n,width,x,y)
  block <- rotate(c(.5,k,k),c(k,k,n+.5),n,width,x,y)
  # For a full diagonal, the bottom outline steps around the real self-pair squares.
  lower_i <- rep(seq_len(n),each=2L)+rep(c(-.5,.5),n)
  lower_j <- rep(seq_len(n)-.5,each=2L)
  lower <- rotate(c(lower_i,n+.5),c(lower_j,n+.5),n,width,x,y)
  edges <- if (diagonal) list(lines_mm(outline$x,outline$y), lines_mm(lower$x,lower$y)) else
    list(lines_mm(c(outline$x,outline$x[1]),c(outline$y,outline$y[1])))
  grobs <- c(list(grid::polygonGrob(mm(as.vector(vertices$x)),mm(as.vector(vertices$y)),
                     id.lengths=rep(4L,nrow(tiles)),gp=grid::gpar(fill=color_values(tiles$value,limit),col=NA)),
                  lines_mm(block$x,block$y)),edges)
  if (diagonal) {
    groups_x <- c(outline$x[1],block$x[1],block$x[3],outline$x[3])
    groups_y <- c(outline$y[1],block$y[1],block$y[3],outline$y[3])
    grobs <- c(grobs,
      list(lines_mm(groups_x[1:2]-.43,groups_y[1:2]+.43,"#E32636",1.65),
           lines_mm(groups_x[3:4]+.43,groups_y[3:4]+.43,"#26388A",1.65),
           point(mean(groups_x[1:2])-1.55,mean(groups_y[1:2])+1.25,"A"),
           point(mean(groups_x[3:4])+1.55,mean(groups_y[3:4])+1.25,"B"),
           point(x,y-7.35,"Chromatin subcompartments")))
    bottom <- rotate(seq_len(n),seq_len(n),n,width,x,y)
    for (i in seq_len(n)) grobs <- c(grobs,list(point(bottom$x[i]-.62,y-1.8,labels[i],6.1,"right",45)))
  } else {
    for (i in c(1,3)) {
      s <- if (i==1L) -1 else 1
      coord_x <- block$x[i]+s*.91
      coord_y <- block$y[i]+.91
      grobs <- c(grobs,list(grid::curveGrob(mm(coord_x-1.2),mm(coord_y+s*1.2),
         mm(coord_x+1.2),mm(coord_y-s*1.2),curvature=-.52,ncp=5,
         arrow=grid::arrow(length=mm(.55),ends="both",type="closed"),
         gp=grid::gpar(col=ink,fill=ink,lwd=.52))))
    }
    grobs <- c(grobs,list(point(mean(c(outline$x[1],block$x[2])),y-1.9,"Chr. 1–14,X"),
                          point(mean(c(block$x[2],outline$x[3])),y-1.9,"Chr. 15–22")))
  }
  list(grobs=grobs,vertices=vertices,ids=labels)
}

key <- function(x,y,title,limit,ticks) {
  width <- 13.9
  values <- seq(-limit,limit,length.out=257)
  at <- x+(ticks+limit)/(2*limit)*width
  list(point(x-.9,y,title,6.3,"right"),
       grid::rasterGrob(as.raster(matrix(color_values(values,limit),1L)),
                        mm(x),mm(y),mm(width),mm(2.1),just=c("left","centre"),interpolate=TRUE),
       grid::rectGrob(mm(x),mm(y),mm(width),mm(2.1),just=c("left","centre"),
                      gp=grid::gpar(col=ink,fill=NA,lwd=.7)),
       grid::segmentsGrob(mm(at),mm(y-1.05),mm(at),mm(y-1.52),gp=grid::gpar(col=ink,lwd=.65)),
       point(at,y-2.67,sub("^-","−",as.character(ticks)),6.2))
}

load_plate <- function(input) {
  read <- function(f) read.csv(file.path(input,f),check.names=FALSE,stringsAsFactors=FALSE)
  chr <- read.delim(file.path(input,"hg19-order.tsv"),check.names=FALSE,stringsAsFactors=FALSE)
  chrom <- chr$chromosome[order(chr$length,decreasing=TRUE)]
  comp <- c("A.1.1","A.1.2","A.2.1","A.2.2","B.1.1","B.1.2","B.2.1","B.2.2")
  dp <- read("d-pvalues.csv")
  ep <- read("e-pvalues.csv")
  d <- read("d-ratios.csv")
  e <- read("e-ratios.csv")
  comparison <- names(d)[-c(1,2)]
  stopifnot(identical(comparison,names(e)[-c(1,2)]),identical(comparison,dp$comparison),
            identical(comparison,ep$comparison),length(chrom)==23L,length(comparison)==5L)
  d <- prepare_pairs(d,chrom)
  e <- prepare_pairs(e,comp,diagonal=TRUE,direction=-1)
  headings <- c("CP-A TP53^{−/−} C3","RPE TP53^{−/−} (Noc + DCB)",
                "RPE TP53^{−/−} (DCB)","K562","RPE TP53^{−/−}")
  treatment <- c(rep("WGD vs diploid",4),"CIN-only vs diploid")
  x <- c(20.8,55.2,89.6,124,158.4)
  y_d <- 13.1
  y_e <- 19.7
  items_d <- list(point(1.8,33.6,"d",8,face="bold"))
  items_e <- list(point(1.8,40.2,"e",8,face="bold"))
  panels <- list()
  for (i in seq_along(comparison)) {
    di <- plot_panel(d[d$comparison==comparison[i],],chrom,c(15,8),x[i],y_d,31.5,.5,FALSE)
    ei <- plot_panel(e[e$comparison==comparison[i],],comp,c(4,4),x[i],y_e,28.3,4,TRUE)
    panels[[paste0("d",i)]] <- di
    panels[[paste0("e",i)]] <- ei
    items_d <- c(items_d,di$grobs,
     list(point(x[i]-9.7,y_d+17.75,headings[i],6.4),
          point(x[i]-10.5,y_d+15.45,treatment[i],6.4),
          point(x[i]-12.28,y_d+8.1,paste0("P = ",p_label(dp[["pvalue(LL vs LS)"]][i])),6.0,angle=45),
          point(x[i]+11.2,y_d+9.9,paste0("P = ",p_label(dp[["pvalue(SS vs LS)"]][i])),6.0,angle=-45)))
    items_e <- c(items_e,ei$grobs,
     list(point(x[i]-9.7,y_e+17.4,headings[i],6.4),
          point(x[i]-10.5,y_e+15.1,treatment[i],6.4),
          point(x[i]+5.05,y_e+10.55,paste0("P_{A vs B} = ",p_label(ep$wilcoxon_pvalue[i])),6.1,"left")))
  }
  items_d <- c(items_d,key(73.5,7.5,"log_{2}[FC (chromatic contact)]",.5,c(-.4,0,.4)),
                list(point(92.4,7.5,"Chromosomes sorted by length",6.3,"left"),
                     grid::polygonGrob(mm(c(125.7,139.6,139.6)),mm(c(6.4,6.4,9.1)),
                                       gp=grid::gpar(fill="#A8A9AA",col=NA))))
  items_e <- c(items_e,key(98,7.7,"log_{2}(gain vs loss of contacts ratio)",4,seq(-4,4,2)))
  text_grobs <- function(item) {
    if (inherits(item,"text")) return(list(item))
    unlist(lapply(item$children,text_grobs),recursive=FALSE)
  }
  d_row <- do.call(grid::grobTree,c(items_d,list(vp=grid::viewport(name="wgd-d-row"))))
  e_row <- do.call(grid::grobTree,c(items_e,list(vp=grid::viewport(name="wgd-e-row"))))
  canvas <- cowplot::ggdraw() +
    cowplot::draw_grob(d_row,x=0,y=43/80,width=1,height=37/80) +
    cowplot::draw_grob(e_row,x=0,y=0,width=1,height=43/80)
  text_layers <- c(text_grobs(d_row),text_grobs(e_row))
  list(plot=canvas,rows=list(d_row,e_row),panels=panels,text_layers=text_layers,
       text=unique(unlist(lapply(text_layers,function(g) g$label),use.names=FALSE)))
}

measure_panels <- function(panels) {
  lapply(names(panels),function(id) {
    grid::seekViewport(paste0("wgd-",substr(id,1,1),"-row"))
    on.exit(grid::upViewport(0),add=TRUE)
    panel <- panels[[id]]
    vx <- panel$vertices$x
    vy <- panel$vertices$y
    edge <- function(a,b) {
      dx <- grid::convertWidth(mm(vx[b,]-vx[a,]),"mm",valueOnly=TRUE)
      dy <- grid::convertHeight(mm(vy[b,]-vy[a,]),"mm",valueOnly=TRUE)
      sqrt(dx^2+dy^2)
    }
    widths <- edge(1,2)
    heights <- edge(2,3)
    n <- length(panel$ids)
    actual_width <- grid::convertWidth(grid::unit(1,"npc"),"mm",valueOnly=TRUE)
    actual_height <- grid::convertHeight(grid::unit(1,"npc"),"mm",valueOnly=TRUE)
    stopifnot(min(vx)>0,min(vy)>0,max(vx)<actual_width,max(vy)<actual_height)
    stopifnot(max(abs(widths/heights-1)) < 1e-9,
              max(abs(widths-panel$vertices$cell_mm)) < 1e-9)
    list(matrix_id=id,panel_id=id,rows=n,columns=n,matrix_rows=n,matrix_columns=n,
         body_width_mm=n*widths[1],body_height_mm=n*heights[1],
         cell_width_mm=widths[1],cell_height_mm=heights[1],
         visible_cells=length(widths),measurement_method="final_body_viewports_mm")
  })
}

main <- function(args) {
  if (length(args) != 2L) stop("Usage: Rscript draw_figure.R INPUT_DIR OUTPUT_DIR")
  dir.create(args[2],recursive=TRUE,showWarnings=FALSE)
  warn <- function(w) stop(conditionMessage(w),call.=FALSE)
  style_path <- Sys.getenv("BIOFIGURE_STYLE_R")
  style <- NULL
  if (nzchar(style_path)) {
    style <- new.env()
    sys.source(style_path,style)
  }
  font <- if (is.null(style)) systemfonts::match_fonts("Arial")$path[1] else style$bf_font("Arial")$path
  if (!grepl("(^|/)Arial[.]ttf$",font)) stop("Arial font unavailable")
  plate <- load_plate(args[1])
  font_check <- all(vapply(plate$text_layers,function(g) identical(g$gp$fontfamily,"Arial"),logical(1)))
  stopifnot(font_check)
  sizes <- vapply(plate$text_layers,function(g) g$gp$fontsize,numeric(1))
  stopifnot(min(sizes) >= 5, max(sizes) <= 1.6*min(sizes))
  glyphs <- unique(strsplit(paste0(plate$text,collapse=""),"",fixed=TRUE)[[1]])
  glyph_check <- all(systemfonts::glyph_info(glyphs,path=font)$index>0L)
  if (!glyph_check) stop("Missing glyph in Arial")
  draw <- function() {
    on.exit(grDevices::dev.off(),add=TRUE)
    grid::grid.newpage()
    scene <- ggplot2::ggplotGrob(plate$plot)
    if (!is.null(style)) {
      style$bf_assert_no_canvas_caption(plate$plot)
      style$bf_assert_scientific_grob_text(scene)
      for (row in plate$rows) style$bf_assert_scientific_grob_text(row)
    }
    grid::grid.draw(scene)
    grid::grid.force()
    measured <- measure_panels(plate$panels)
    if (!is.null(style)) style$bf_assert_cell_metrics(measured)
    measured
  }
  withCallingHandlers({
    ragg::agg_png(file.path(args[2],"figure.png"),183,80,units="mm",res=300,background="white")
    raster <- draw()
    pdf <- file.path(args[2],"figure.pdf")
    if (capabilities("aqua")) {
      grDevices::quartz(type="pdf",file=pdf,width=183/25.4,height=80/25.4,
                        family="Arial",bg="white")
    } else {
      grDevices::cairo_pdf(pdf,183/25.4,80/25.4,family="Arial",bg="white")
    }
    vector <- draw()
  },warning=warn)
  stopifnot(identical(raster,vector))
  jsonlite::write_json(list(font=font,width_mm=183,height_mm=80,dpi=300,
     minimum_text_pt=min(sizes),maximum_text_pt=max(sizes),font_check=font_check,glyph_check=glyph_check,
     scientific_grob_text_checked=!is.null(style),
     rendered_text=plate$text,heatmap_cells=raster,pdf_heatmap_cells=vector),
     file.path(args[2],"render-measurements.json"),auto_unbox=TRUE,pretty=TRUE,digits=12)
  writeLines(capture.output(sessionInfo()),file.path(args[2],"session-info.txt"))
}

if (sys.nframe() == 0L) main(commandArgs(trailingOnly=TRUE))
