# Lambuta, Nanni et al. (2023), Fig. 3c. Published ranks are summarized upstream of this plotting entry point.
prepare_joint_points <- function(table, groups, x="x", y="y", group="group", id="id") {
  fields <- c(id,group,x,y)
  if (!is.data.frame(table) || anyDuplicated(fields) || anyDuplicated(names(table)) ||
      !all(fields %in% names(table))) stop("Expected four distinct fields: id, group, x, y")
  if (!length(groups) || anyNA(groups) || any(!nzchar(groups)) || anyDuplicated(groups))
    stop("Declare unique, nonempty group levels")
  ids <- as.character(table[[id]])
  categories <- as.character(table[[group]])
  if (!length(ids) || anyNA(ids) || any(!nzchar(ids)) || anyDuplicated(ids))
    stop("Point IDs must be nonempty and unique")
  if (!setequal(categories,groups) || min(table(categories)) < 2L)
    stop("Every declared group must occur and contain at least two points")
  if (!is.numeric(table[[x]]) || !is.numeric(table[[y]]) ||
      any(!is.finite(c(table[[x]],table[[y]])))) stop("Paired coordinates must be finite numeric values")
  points <- data.frame(id=ids,group=factor(categories,levels=groups),x=table[[x]],y=table[[y]])
  points <- points[order(points$group, points$id, method="radix"),]
  rownames(points) <- NULL
  points
}

marginal_density <- function(points, axis, groups, gridsize=200L, adjust=1) {
  stopifnot(axis %in% c("x","y"), length(gridsize)==1L, gridsize>=3L,
            gridsize==as.integer(gridsize), length(adjust)==1L, is.finite(adjust), adjust>0,
            length(groups)>0L, !anyDuplicated(groups), all(groups %in% as.character(points$group)))
  do.call(rbind,lapply(groups,function(key) {
    values <- points[[axis]][points$group==key]
    bandwidth <- stats::sd(values)*length(values)^(-.2)*adjust
    if (!is.finite(bandwidth) || bandwidth<=0)
      stop(sprintf("Marginal %s has zero or undefined variance in %s",axis,key))
    coordinate <- seq(min(values)-3*bandwidth,max(values)+3*bandwidth,length.out=gridsize)
    density <- vapply(coordinate,function(at) mean(stats::dnorm(at,values,bandwidth)),numeric(1))
    data.frame(group=factor(key,levels=groups),coordinate=coordinate,density=density,bandwidth=bandwidth)
  }))
}

mm <- function(value) grid::unit(value,"mm")
ink <- "#16151A"
label <- function(x,y,text,size=8.2,just="centre",angle=0,face=1L) {
  grid::textGrob(text, mm(x), mm(y), just=just, rot=angle,
    gp=grid::gpar(col=ink,fontfamily="Arial",fontsize=size,fontface=face,lineheight=1.02))
}
rule <- function(x0,y0,x1,y1,lwd=.8) {
  grid::segmentsGrob(mm(x0),mm(y0),mm(x1),mm(y1), gp=grid::gpar(col=ink,lwd=lwd,lineend="butt"))
}

joint_plot <- function(points, groups, palette, limits, axes, focus=NULL,
                       marginal_groups=groups, identity=FALSE, ticks=lapply(limits,pretty),
                       panel_label=NULL, marginal_calls=NULL, sample_n=FALSE) {
  points <- prepare_joint_points(points,groups)
  stopifnot(length(palette)==length(groups),setequal(names(palette),groups),
            identical(names(limits),c("x","y")),identical(names(axes),c("x","y")))
  for (axis in c("x","y")) {
    span <- limits[[axis]]
    stopifnot(length(span)==2L,all(is.finite(span)),diff(span)>0,
              all(points[[axis]]>=span[1]&points[[axis]]<=span[2]))
    at <- ticks[[axis]]
    ticks[[axis]] <- at[at>=span[1] & at<=span[2]]
    stopifnot(length(ticks[[axis]]) >= 2L)
  }
  if (identity && !identical(as.numeric(limits$x),as.numeric(limits$y)))
    stop("Use the identity guide only for paired axes with the same limits")
  top_density <- marginal_density(points,"x",marginal_groups)
  right_density <- marginal_density(points,"y",marginal_groups)
  blank <- ggplot2::theme_void(base_family="Arial") +
    ggplot2::theme(plot.margin=ggplot2::margin(0,0,0,0),legend.position="none")
  scatter <- ggplot2::ggplot(points,ggplot2::aes(x=x,y=y)) +
    ggplot2::geom_point(ggplot2::aes(fill=group),shape=21,size=1.37,stroke=.12,colour="#FFFFFF") +
    ggplot2::scale_fill_manual(values=palette) +
    ggplot2::coord_cartesian(xlim=limits$x,ylim=limits$y,expand=FALSE) + blank
  if (identity) scatter$layers <- c(list(ggplot2::geom_abline(slope=1,intercept=0,
    linewidth=.43,linetype="longdash",colour="#222222")),scatter$layers)

  density_plot <- function(d) ggplot2::ggplot(d,ggplot2::aes(x=coordinate,ymin=0,ymax=density,fill=group)) +
    ggplot2::geom_ribbon(alpha=.53,colour=NA) + ggplot2::scale_fill_manual(values=palette) + blank
  top_max <- max(top_density$density)*1.02
  top <- density_plot(top_density) +
    ggplot2::coord_cartesian(xlim=limits$x,ylim=c(0,top_max),expand=FALSE)
  right <- density_plot(right_density) +
    ggplot2::coord_flip(xlim=limits$y,ylim=c(0,max(right_density$density)*1.02),expand=FALSE)

  legend_start <- 88.45
  legend_width <- max(systemfonts::string_width(groups,family="Arial",size=8.1,res=300))/300*25.4
  width <- max(96,legend_start+legend_width+1.1)
  height <- 86
  layout <- list(scatter=c(x=24.2,y=19.6,width=51.2,height=51.2),
                 top=c(x=24.2,y=73.6,width=51.2,height=9.5),
                 right=c(x=78.2,y=19.6,width=11.7,height=51.2))
  x0 <- unname(layout$scatter["x"])
  y0 <- unname(layout$scatter["y"])
  sw <- unname(layout$scatter["width"])
  y_top <- unname(layout$top["y"])
  x_right <- unname(layout$right["x"])
  px <- function(z) x0+sw*(z-limits$x[1])/diff(limits$x)
  py <- function(z) y0+sw*(z-limits$y[1])/diff(limits$y)
  x_ticks <- px(ticks$x)
  y_ticks <- py(ticks$y)
  marks <- list(
    rule(min(x_ticks),y0,max(x_ticks),y0,1),rule(x0,min(y_ticks),x0,max(y_ticks),1),
    rule(x_ticks,y0,x_ticks,y0-1.05,.85),rule(x0,y_ticks,x0-1.05,y_ticks,.85),
    label(x_ticks,y0-3.3,format(ticks$x,trim=TRUE),8.5),
    label(x0-2.0,y_ticks,format(ticks$y,trim=TRUE),8.5,"right"),
    label(x0+sw/2,6.6,axes$x,9.0),
    label(7.5,y0+sw/2,axes$y,9.0,angle=90)
  )
  if (!is.null(panel_label)) marks <- c(marks,list(label(2.3,83.4,panel_label,10.9,face=2L)))
  if (sample_n) marks <- c(marks,list(label(x0+sw-1.2,y0+4.4,paste("n =",nrow(points)),8.7,"right",face=3L)))

  legend_y <- y0+10.2-4.65*(seq_along(groups)-1)
  if (min(legend_y) <= 2) stop("Too many groups for the legend column")
  marks <- c(marks,list(grid::pointsGrob(mm(rep(x_right+8.45,length(groups))),mm(legend_y),pch=21,size=mm(1.58),
    gp=grid::gpar(fill=unname(palette[groups]),col="#FFFFFF",lwd=.5)),
    label(legend_start,legend_y,groups,8.1,"left")))

  if (!is.null(focus)) {
    target <- match(focus$id,points$id)
    stopifnot(!anyNA(target),!anyDuplicated(focus$id),!anyNA(focus$label),all(nzchar(focus$label)))
    for (i in seq_len(nrow(focus))) {
      position <- points[target[i],]
      x <- px(position$x)
      y <- py(position$y)
      at <- focus[i,]
      if (isTRUE(at$box)) marks <- c(marks,list(grid::rectGrob(mm(x),mm(y),mm(2.0),mm(2.0),
        gp=grid::gpar(col=ink,fill=NA,lwd=.82))))
      if (is.finite(at$leader_u) && is.finite(at$leader_v)) {
        end_x <- x + if (isTRUE(at$box)) .84 else -.4
        end_y <- y + if (isTRUE(at$box)) .84 else .5
        marks <- c(marks,list(rule(x0+sw*at$leader_u,y0+sw*at$leader_v,end_x,end_y,.85)))
      }
      marks <- c(marks,list(label(x0+sw*at$u,y0+sw*at$v,at$label,8.15,"left")))
    }
  }
  if (!is.null(marginal_calls)) {
    stopifnot(all(marginal_calls$group %in% marginal_groups))
    for (i in seq_len(nrow(marginal_calls))) {
      at <- marginal_calls[i,]
      density <- top_density[top_density$group==at$group,]
      endpoint <- stats::approx(density$coordinate,density$density,xout=at$coordinate)$y
      stopifnot(is.finite(endpoint))
      x <- x0+sw*at$u
      y <- y_top+9.1
      marks <- c(marks,list(rule(x+at$leader_shift,y-1.03,px(at$coordinate),y_top+9.5*endpoint/top_max,.65),
                            label(x,y,at$group,8.45)))
    }
  }
  annotations <- do.call(grid::grobTree,marks)
  plots <- list(scatter=scatter,top=top,right=right)
  canvas <- cowplot::ggdraw()
  for (name in names(plots)) {
    position <- layout[[name]]
    layer <- grid::grobTree(ggplot2::ggplotGrob(plots[[name]]),
      vp=grid::viewport(name=paste0("joint-",name)))
    canvas <- canvas + cowplot::draw_grob(layer,x=position[["x"]]/width,y=position[["y"]]/height,
      width=position[["width"]]/width,height=position[["height"]]/height)
  }
  canvas <- canvas + cowplot::draw_grob(annotations)
  text_layers <- Filter(function(g) inherits(g,"text"),marks)
  list(plot=canvas,scatter=scatter,top=top,right=right,width_mm=width,height_mm=height,
       layout=layout,top_density=top_density,right_density=right_density,points=points,
       text_layers=text_layers)
}

render_joint <- function(figure, directory, style_path="") {
  dir.create(directory,recursive=TRUE,showWarnings=FALSE)
  style <- NULL
  if (nzchar(style_path)) {
    style <- new.env()
    sys.source(style_path,style)
  }
  font <- if (is.null(style)) systemfonts::match_fonts("Arial")$path[1] else style$bf_font("Arial")$path
  if (!grepl("(^|/)Arial[.]ttf$",font)) stop("Arial font unavailable")
  layers <- figure$text_layers
  labels <- unique(unlist(lapply(layers,function(g) g$label),use.names=FALSE))
  sizes <- vapply(layers,function(g) g$gp$fontsize,numeric(1))
  font_check <- all(vapply(layers,function(g) identical(g$gp$fontfamily,"Arial"),logical(1)))
  characters <- setdiff(unique(strsplit(paste(labels,collapse=""),"",fixed=TRUE)[[1]]),"\n")
  glyph_check <- all(systemfonts::glyph_info(characters,path=font)$index>0L)
  stopifnot(font_check,glyph_check,min(sizes)>=6,max(sizes)<=1.6*min(sizes))
  draw <- function() {
    on.exit(grDevices::dev.off(),add=TRUE)
    scene <- ggplot2::ggplotGrob(figure$plot)
    if (!is.null(style)) {
      style$bf_assert_no_canvas_caption(figure$plot)
      style$bf_assert_scientific_grob_text(scene)
    }
    grid::grid.newpage()
    grid::grid.draw(scene)
    grid::grid.force()
    lapply(names(figure$layout),function(name) {
      grid::seekViewport(paste0("joint-",name))
      at <- grid::deviceLoc(grid::unit(0,"npc"),grid::unit(0,"npc"),valueOnly=TRUE)
      extent <- c(x=at$x*25.4,y=at$y*25.4,
                  width=grid::convertWidth(grid::unit(1,"npc"),"mm",valueOnly=TRUE),
                  height=grid::convertHeight(grid::unit(1,"npc"),"mm",valueOnly=TRUE))
      grid::upViewport(0)
      # ragg's page dimensions are constrained to whole device pixels.
      stopifnot(max(abs(extent-figure$layout[[name]]))<.1)
      as.list(c(panel=name,as.list(extent)))
    })
  }
  withCallingHandlers({
    ragg::agg_png(file.path(directory,"figure.png"),figure$width_mm,figure$height_mm,
                  units="mm",res=300,background="white")
    png <- draw()
    pdf <- file.path(directory,"figure.pdf")
    if (capabilities("aqua")) {
      grDevices::quartz(type="pdf",file=pdf,width=figure$width_mm/25.4,
                        height=figure$height_mm/25.4,family="Arial",bg="white")
    } else {
      grDevices::cairo_pdf(pdf,figure$width_mm/25.4,figure$height_mm/25.4,family="Arial",bg="white")
    }
    vector <- draw()
  },warning=function(w) stop(conditionMessage(w),call.=FALSE))
  jsonlite::write_json(list(font=font,width_mm=figure$width_mm,height_mm=figure$height_mm,dpi=300,
    rendered_text=labels,minimum_text_pt=min(sizes),maximum_text_pt=max(sizes),
    font_check=font_check,glyph_check=glyph_check,scientific_grob_text_checked=!is.null(style),
    png_panels=png,pdf_panels=vector,points=nrow(figure$points)),
    file.path(directory,"render-measurements.json"),auto_unbox=TRUE,pretty=TRUE,digits=12)
  writeLines(capture.output(sessionInfo()),file.path(directory,"session-info.txt"))
}

figure3c <- function(data_directory) {
  pair <- read.csv(file.path(data_directory,"plot-pairs.csv"),check.names=FALSE,
                  stringsAsFactors=FALSE)
  groups <- c("LS","SS","LL")
  pair$id <- paste(pair$chromosome1,pair$chromosome2,sep="|")
  points <- prepare_joint_points(pair,groups,x="control_mean_rank",y="wgd_with_lcs_mean_rank",
                                  group="chromosome_interaction")
  stopifnot(nrow(points)==253L,identical(as.integer(table(points$group)),c(120L,28L,105L)))
  focus <- data.frame(id=c("chr1|chr16","chr5|chr15","chr10|chrX"),
    label=c("Chr. 1–Chr. 16","Chr. 5–Chr. 15","t(10,X)"),
    u=c(.044,.312,.972),v=c(.947,.844,1.025),
    leader_u=c(.200,.548,.970),leader_v=c(.905,.801,1.007),box=c(FALSE,FALSE,TRUE))
  marginal_calls <- data.frame(group=c("LS","SS"),u=c(.109,.715),
                                coordinate=c(83,166),leader_shift=c(2.05,-2.05))
  joint_plot(points,groups,c(LS="#DA272B",SS="#31ACD4",LL="#2D367D"),
    limits=list(x=c(30,250),y=c(30,250)),
    axes=list(x="Interchromosome interaction\nrank (control)",y="Interchromosome interaction\nrank (WGD/LCS)"),
    focus=focus,marginal_groups=c("LS","SS"),identity=TRUE,
    ticks=list(x=seq(50,250,50),y=seq(50,250,50)),panel_label="c",
    marginal_calls=marginal_calls,sample_n=TRUE)
}

if (sys.nframe()==0L) {
  arguments <- commandArgs(trailingOnly=TRUE)
  if (length(arguments)!=2L) stop("Usage: Rscript draw_figure.R INPUT_DIR OUTPUT_DIR")
  render_joint(figure3c(arguments[1]),arguments[2],Sys.getenv("BIOFIGURE_STYLE_R"))
}
