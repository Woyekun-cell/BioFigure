# Redraw the scientific vector layers of Zuntini, Carruthers et al. (Nature, 2024), Fig. 1.
# Source artwork and display coordinates: Zenodo 10778207, CC BY 4.0.
# Run: Rscript draw_figure.R path/to/plot-data path/to/output
suppressPackageStartupMessages({
  library(grid)
  library(ggplot2)
  library(cowplot)
})

args <- commandArgs(trailingOnly = TRUE)
input <- if (length(args)) args[1] else "results/plot_data"
out <- if (length(args) >= 2) args[2] else "results/figures"
stopifnot(dir.exists(input))
dir.create(out, recursive = TRUE, showWarnings = FALSE)
cowplot::set_null_device("agg")

width_mm <- 182
height_mm <- 178
font <- "Arial"
source_x <- 850
source_y <- 1025
x_span <- 7350
y_span <- x_span * height_mm / width_mm
x_npc <- function(x) (x - source_x) / x_span
y_npc <- function(y) 1 - (y - source_y) / y_span
line_width <- function(x) x * width_mm / x_span / 25.4 * 96
load_data <- function(file) read.csv(file.path(input, file), stringsAsFactors = FALSE,
                                    na.strings = "", fileEncoding = "UTF-8")

branches <- load_data("branch-strokes.csv.gz")
styles <- load_data("path-styles.csv")
vertices <- load_data("path-vertices.csv.gz")
calibration <- load_data("fossil-calibration-marks.csv")
labels <- load_data("figure-labels.csv")
palette <- load_data("rate-palette.csv")
stopifnot(nrow(branches) == 430103L, length(unique(branches$path_id)) == 200394L,
          nrow(calibration) == 199L, nrow(palette) == 205L,
          nrow(styles) == 35L, !anyDuplicated(styles$path_id),
          setequal(unique(vertices$path_id), styles$path_id),
          all(is.finite(as.matrix(branches[c("x0", "y0", "x1", "y1")]))),
          all(grepl("^#[0-9A-F]{6}$", branches$color)),
          all(labels$font_pt >= 5.5))

poly <- split(vertices, vertices$path_id)
get_grob <- function(row) {
  v <- poly[[as.character(row$path_id)]]
  finish <- if (row$line_type == "dotted") "round" else "butt"
  gp <- gpar(col = row$stroke, fill = row$fill,
             lwd = if (row$width > 0) line_width(row$width) else 0.1,
             lineend = finish, linejoin = "round", lty = row$line_type)
  if (is.na(row$fill)) {
    polylineGrob(x_npc(v$x), y_npc(v$y), id = v$subpath, gp = gp)
  } else {
    pathGrob(x_npc(v$x), y_npc(v$y), id = v$subpath, pathId = rep(1L, nrow(v)),
             rule = row$fill_rule, gp = gp)
  }
}
path_layer <- function(rows) {
  lapply(seq_len(nrow(rows)), function(i) get_grob(rows[i, , drop = FALSE]))
}
labels_layer <- lapply(seq_len(nrow(labels)), function(i) {
  r <- labels[i, ]
  textGrob(r$label, x_npc(r$x), y_npc(r$y), rot = r$rotation,
           gp = gpar(fontfamily = font, fontsize = r$font_pt, col = "#171717"))
})

backgrounds <- path_layer(styles[styles$role == "era-background", ])
foreground <- path_layer(styles[styles$role != "era-background", ])
branch_layer <- segmentsGrob(x_npc(branches$x0), y_npc(branches$y0),
                             x_npc(branches$x1), y_npc(branches$y1),
                             gp = gpar(col = branches$color, lwd = line_width(4),
                                       lineend = "butt"))
# PDF and PNG use the same placement for the published fossil calibration dots.
dot_layer <- circleGrob(x_npc(calibration$x), y_npc(calibration$y),
                        r = unit((calibration$rx + calibration$ry) / 2 *
                                   width_mm / x_span, "mm"),
                        gp = gpar(fill = "#000000", col = NA))

bar_start <- .660
bar_width <- .280
bar_y <- .042
bin_width <- bar_width / nrow(palette)
legend_ramp <- rectGrob(x = bar_start + (palette$bin - .5) * bin_width,
                         y = bar_y, width = bin_width * 1.01, height = .014,
                         gp = gpar(fill = palette$color, col = NA))
tick_pos <- bar_start + c(0, 1/3, 2/3, 1) * bar_width
legend_ticks <- gList(
  segmentsGrob(bar_start, .050, bar_start + bar_width, .050,
               gp = gpar(col = "#333333", lwd = .58)),
  segmentsGrob(tick_pos, .050, tick_pos, .055, gp = gpar(col = "#333333", lwd = .58)),
  textGrob(c("−0.62", "−0.17", "0.29", "0.74"), tick_pos, .0618,
           gp = gpar(fontfamily = font, fontsize = 6)),
  textGrob("Net diversification rate", bar_start + bar_width / 2, .022,
           gp = gpar(fontfamily = font, fontsize = 7))
)
scene <- gTree(children = do.call(gList, c(
  backgrounds, list(branch_layer, dot_layer), foreground, labels_layer,
  list(legend_ramp, legend_ticks)
)))
figure <- ggdraw() + draw_grob(scene)

png <- file.path(out, "angiosperm-fig1.png")
pdf <- file.path(out, "angiosperm-fig1.pdf")
authorization <- Sys.getenv("BIOFIGURE_RENDER_AUTHORIZATION")
if (nzchar(authorization)) {
  helper <- Sys.getenv("BIOFIGURE_R_HELPER")
  spec <- Sys.getenv("BIOFIGURE_DESIGN_SPEC")
  renderer <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
  source(helper)
  design <- yaml::read_yaml(spec)
  boxes <- data.frame(id = c("data", "labels", "legend"),
    x = width_mm * c(.023, .505, .615), y = height_mm * c(.069, .489, .01),
    w = width_mm * c(.935, .48, .365), h = height_mm * c(.917, .064, .055))
  bf_render_png(figure, png, font = bf_font(font),
    allowed_text = unlist(design$text_contract$allowed_text),
    width_mm = width_mm, height_mm = height_mm, target_width_mm = width_mm,
    source_files = c(renderer, helper, spec, list.files(input, full.names = TRUE)),
    boxes = boxes, allowed_pairs = "data:labels", dpi = 360, min_text_pt = 5.5,
    text_size_authorization = "The compact geological ruler and narrow Magnoliids arc retain the original positions and numerical distinctions at figure width.",
    authorization = authorization, skill_root = dirname(dirname(helper)),
    publication_size_class = "custom",
    size_override_basis = "Near-square 182 × 178 mm source circle and separately reserved rate key.")
} else {
  ggsave(png, figure, width = width_mm, height = height_mm, units = "mm", dpi = 360,
         bg = "white", device = ragg::agg_png)
}
if (identical(Sys.info()[["sysname"]], "Darwin")) {
  grDevices::quartz(type = "pdf", file = pdf, width = width_mm / 25.4,
                    height = height_mm / 25.4, bg = "white", family = font)
  grid.newpage()
  grid.draw(scene)
  invisible(dev.off())
} else {
  ggsave(pdf, figure, width = width_mm, height = height_mm, units = "mm",
         bg = "white", family = font, device = grDevices::cairo_pdf)
}
writeLines(capture.output(sessionInfo()), file.path(out, "R-session.txt"))
