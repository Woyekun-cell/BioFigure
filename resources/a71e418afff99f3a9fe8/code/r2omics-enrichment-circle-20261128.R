# Rscript --vanilla render.R plot_data.csv r2omics-enrichment-circle
# R2Omics base panel, cb1/cb3, adapted from the author's published function:
# https://www.r2omics.cn/docs/gallery/omicsChart/enrichCircos/#cb1-9
# Dependencies: circlize, dplyr, gridGraphics, ggplot2, ragg, systemfonts and Arial.

suppressPackageStartupMessages({
  library(circlize)
  library(grid)
  library(ggplot2)
})

options(warn = 2)
args <- commandArgs(TRUE)
stopifnot(length(args) %in% c(2L, 4L))
input <- normalizePath(args[1])
out <- args[2]
width <- 183
height <- 149
font <- "Arial"
text_ink <- "#1F2E38"
background_key <- "#E3ABBA"
foreground <- "#B6A7D9"
classes <- c("biological process" = "#77B7A8",
             "cellular component" = "#94ADD5",
             "molecular function" = "#DEBA77")
p_colors <- c("#F9E8EA", "#F0CED6", "#E2ABBA", "#D48EA3", "#C27790")
canvas_x <- c(-1.105, 1.64)
canvas_y <- c(-1.115, 1.115)
stopifnot(font %in% systemfonts::system_fonts()$family)

data <- read.csv(input, check.names = FALSE, stringsAsFactors = FALSE)
data <- data[order(data$sector_order), ]
# Preserve the author's per-class P selection and Ratio sorting.
items <- dplyr::ungroup(dplyr::arrange(dplyr::slice_min(dplyr::group_by(data, Class),
         PValue, n = 6, with_ties = FALSE), dplyr::desc(Ratio), .by_group = TRUE))
stopifnot(identical(items$TermID, data$TermID), !anyDuplicated(data$TermID),
          nrow(data) == 18L, all(as.integer(table(data$Class)) == 6L),
          all(data$PValue > 0), all(data$PValue <= 1),
          all(abs(data$Enrichment + log10(data$PValue)) < 1e-6),
          all(abs(data$Ratio - data$fg_term_num / data$bg_term_num) < 1e-9),
          all(abs(data$sector_plot_limit - log10(max(data$bg_pro_num) + 1)) < 1e-10),
          all(abs(data$background_plot_end - log10(data$bg_term_num+1)) < 1e-10),
          all(abs(data$foreground_plot_end - log10(data$fg_term_num+1)) < 1e-10),
          all(abs(data$relative_rich_factor - data$Ratio/max(data$Ratio)) < 1e-10))

fill <- unname(classes[data$Class])
p_max <- round(max(data$Enrichment)) + 1
p_map <- colorRamp2(seq(0, p_max, length.out = length(p_colors)), p_colors)
df1 <- data.frame(TermID = data$TermID, start = 0, end = data$sector_plot_limit)
df2 <- data.frame(TermID = data$TermID, start = 0, end = data$background_plot_end,
                  n = data$bg_term_num, fill = p_map(data$Enrichment))
df3 <- data.frame(TermID = data$TermID, start = 0, end = data$foreground_plot_end,
                  n = data$fg_term_num, fill = foreground)
df4 <- data.frame(TermID = data$TermID, start = 0, end = data$sector_plot_limit,
                  ratio = 10 * data$relative_rich_factor, fill = fill)
geometry <- new.env(parent = emptyenv())

draw_ring <- function() {
  circos.clear()
  on.exit(circos.clear(), add = TRUE)
  par(mai = rep(0, 4), omi = rep(0, 4), ps = 10, cex = 1, family = font, bg = "white",
      col = text_ink, xpd = NA)
  circos.par(start.degree = 0, gap.degree = 1, track.margin = c(.01, .01),
             canvas.xlim = canvas_x, canvas.ylim = canvas_y)
  circos.genomicInitialize(df1, plotType = "none")
  stopifnot(identical(get.all.sector.index(), data$TermID))

  # 1. Outer color-coded GO sectors and correctly calibrated log count ticks.
  circos.trackPlotRegion(ylim = c(0,1), track.height = .08,
    bg.border = NA, bg.col = fill, panel.fun = function(x, y) {
      circos.text(mean(CELL_META$xlim), .50, CELL_META$sector.index, cex = .67,
                  facing = "inside", niceFacing = TRUE, col = text_ink)
    })
  for (sector in data$TermID) {
    marks <- c(0, 10, 100)
    circos.axis(h = "top", sector.index = sector, track.index = 1,
                major.at = log10(marks + 1), labels = as.character(marks),
                labels.cex = .60, labels.facing = "clockwise", minor.ticks = 4,
                major.tick.length = mm_y(1), lwd = .46, col = "#526472", labels.col = text_ink)
  }

  # 2 and 3. Author's shared log-length rectangles and raw count labels.
  count_track <- function(df, cex) {
    circos.genomicTrack(df, ylim = c(0, 1), track.height = .1, bg.border = "white",
      panel.fun = function(region, value, ...) {
        circos.genomicRect(region, value, ytop = 0, ybottom = 1, col = value[[2]], border = NA, ...)
        circos.genomicText(region, value, y = .5, labels = value[[1]], adj = c(.5,.5),
                           cex = cex, col = text_ink, facing = "inside", niceFacing = TRUE, ...)
      })
  }
  count_track(df2, .80)
  count_track(df3, .84)

  # 4. Radial bars use the author's maximum-normalized ratio and original track height.
  circos.genomicTrack(df4, ylim = c(0,10), track.height = .35, bg.border = "white",
    bg.col = "#E7EDF0", panel.fun = function(region, value, ...) {
      for (level in 1:9) {
        circos.lines(CELL_META$cell.xlim, rep(level, 2), col = "white", lwd = .42)
      }
      circos.genomicRect(region, value, ytop = 0, ybottom = value[[1]],
                         col = value[[2]], border = NA, ...)
    })
  stopifnot(length(get.all.track.index()) == 4)
  geometry$x <- grconvertX(0, "user", "ndc")
  geometry$y <- grconvertY(0, "user", "ndc")
  xr <- diff(grconvertX(c(-1,1), "user", "inches"))
  yr <- diff(grconvertY(c(-1,1), "user", "inches"))
  stopifnot(abs(xr-yr) < 1e-7)
  geometry$circle_diameter_mm <- 25.4 * xr
}

draw_legends <- function() {
  label_face <- gpar(fontfamily = font, fontsize = 8, col = text_ink)
  title_face <- gpar(fontfamily = font, fontsize = 8.4, fontface = "bold", col = text_ink)
  track_y <- geometry$y * height + c(3.9,0,-3.9)
  track_x <- geometry$x * width - 16.0
  grid.rect(x=unit(track_x,"mm"),y=unit(track_y,"mm"),width=unit(4,"mm"),
            height=unit(3.8,"mm"),gp=gpar(fill="#F2F5F6",col=NA))
  grid.points(x=unit(rep(track_x,3),"mm"),y=unit(track_y,"mm"),pch=c(15,15,17),size=unit(2.7,"mm"),
              gp=gpar(col=c(background_key,foreground,classes[1])))
  grid.text(c("Background genes","Selected genes","Relative rich factor"),
            x=unit(track_x+3.1,"mm"),y=unit(track_y,"mm"),just="left",gp=label_face)

  guide_x <- 147.5
  guide_y <- c(99,95,91)
  grid.text("Class",x=unit(guide_x,"mm"),y=unit(104.5,"mm"),just="left",gp=title_face)
  grid.rect(x=unit(guide_x+1.4,"mm"),y=unit(guide_y,"mm"),width=unit(2.8,"mm"),
            height=unit(2.8,"mm"),gp=gpar(fill=unname(classes),col=NA))
  grid.text(names(classes),x=unit(guide_x+4.3,"mm"),y=unit(guide_y,"mm"),just="left",gp=label_face)
  grid.text("-log10(P)",x=unit(guide_x,"mm"),y=unit(83.5,"mm"),just="left",gp=title_face)
  p_y <- 48
  bar_height <- 30
  steps <- 100
  ramp <- p_map(p_max*((seq_len(steps)-.5)/steps))
  grid.rect(x=unit(guide_x+1.6,"mm"),y=unit(p_y+bar_height*((seq_len(steps)-.5)/steps),"mm"),
            width=unit(3.2,"mm"),height=unit(bar_height/steps+.018,"mm"),gp=gpar(fill=ramp,col=NA))
  tick_y <- p_y + bar_height * seq(0,p_max)/p_max
  grid.segments(x0=unit(guide_x+3.2,"mm"),x1=unit(guide_x+4.1,"mm"),
                y0=unit(tick_y,"mm"),y1=unit(tick_y,"mm"),gp=gpar(col="#667784",lwd=.6))
  grid.text(as.character(seq(0,p_max)),x=unit(guide_x+5.3,"mm"),y=unit(tick_y,"mm"),
            just="left",gp=label_face)
}

# Convert the author's native circular vectors to one grid grob. No raster marks are embedded.
offscreen <- function(width, height) {
  ragg::agg_png(tempfile(fileext = ".png"), width = width, height = height,
                units = "in", pointsize = 10, res = 144, background = "white")
  dev.control(displaylist = "enable")
}
grob <- grid.grabExpr({
    gridGraphics::grid.echo(draw_ring, newpage = FALSE, device = offscreen)
    draw_legends()
  }, width = width/25.4, height = height/25.4, device = offscreen)
stopifnot(!is.null(grob), geometry$x > .37, geometry$x < .43,
          abs(geometry$y-.5) < .01, geometry$circle_diameter_mm > 120)
plot <- ggplot() + annotation_custom(grob, xmin=0, xmax=width, ymin=0, ymax=height) +
  coord_fixed(xlim=c(0,width),ylim=c(0,height),expand=FALSE) +
  theme_void(base_family=font) +
  theme(plot.margin=margin(0,0,0,0), plot.background=element_rect(fill="white",colour=NA))

dir.create(dirname(out), showWarnings=FALSE, recursive=TRUE)
if (length(args) == 4L) {
  skill <- Sys.getenv("BIOFIGURE_ROOT",file.path(path.expand("~"),".codex","skills","biofigure"))
  helper <- file.path(skill,"scripts","figure_style.R")
  source(helper)
  spec_path <- normalizePath(args[3])
  prep <- normalizePath(args[4])
  spec <- yaml::read_yaml(spec_path)
  self <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value=TRUE)))
  sources <- c(spec_path,self,normalizePath(helper),input,spec$reference_evidence$primary_source_lock)
  auth <- paste0(out,".authorization.json")
  command <- c(file.path(skill,"scripts","authorize_render.py"),"--receipt",prep,
    "--design-spec",spec_path,"--output",auth,unlist(lapply(sources[-1], function(path)c("--source",path))))
  stopifnot(system2("python3",shQuote(command))==0L)
  boxes <- data.frame(id=c("data","labels","legend","center"),
    x=c(4,4,146.5,54), y=c(5,5,46,64), w=c(138,138,35,35), h=c(139,139,61,21))
  bf_render_png(plot,paste0(out,".png"),bf_font(font),unlist(spec$text_contract$allowed_text),
    width,height,width,sources,boxes,allowed_pairs=c("data:labels","center:data","center:labels"),
    dpi=360,authorization=auth,skill_root=skill,min_text_pt=7,publication_size_class="double-column")
  bf_pdf_open(paste0(out,".pdf"),width,height,bf_font(font))
  print(plot)
  invisible(dev.off())
  bf_pdf_finalize(paste0(out,".pdf"),bf_font(font),width,height)
} else {
  ggsave(paste0(out,".png"),plot,device=ragg::agg_png,width=width,height=height,
         units="mm",dpi=360,bg="white")
  if (isTRUE(capabilities("aqua"))) {
    grDevices::quartz(type="pdf",file=paste0(out,".pdf"),width=width/25.4,height=height/25.4,family=font,bg="white")
    print(plot)
    invisible(dev.off())
  } else {
    ggsave(paste0(out,".pdf"),plot,device=grDevices::cairo_pdf,width=width,height=height,
           units="mm",family=font,bg="white")
  }
}
