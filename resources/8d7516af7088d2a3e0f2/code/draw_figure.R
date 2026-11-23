# Layout adapted from Whiting et al., Nature Ecology & Evolution (2024), Fig. 1a–c.
# Source renderer: RepAdapt/R/04_plot_figures/Figure1_plot.R (James Whiting, MIT).
# Rscript draw_figure.R path/to/plot_data path/to/output
suppressPackageStartupMessages({
  library(ggplot2)
  library(cowplot)
  library(ggridges)
  library(grid)
})

args <- commandArgs(trailingOnly = TRUE)
input <- if (length(args)) args[1] else "results/plot_data"
out <- if (length(args) >= 2) args[2] else "results/figures"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
stopifnot(dir.exists(input))

font <- "Arial"
cowplot::set_null_device("agg")
width_mm <- 182
height_mm <- 125
climate_cols <- c("#2c7bb6", "#abd9e9", "#ffffbf", "#fdae61", "#d7191c")
period_cols <- c("1960s" = "#DF6D72", "2010s" = "#428DBC")
empty <- theme_void(base_size = 7, base_family = font) +
  theme(plot.margin = margin(0, 0, 0, 0, "pt"))

read_input <- function(name) read.csv(file.path(input, name), check.names = FALSE)
world <- read_input("global-bio1.csv.gz")
points <- read_input("global-sampling.csv")
japan <- read_input("japan-bioclim.csv.gz")
sites <- read_input("japan-sites.csv")
grids <- read_input("precipitation-maps.csv.gz")
monthly <- read_input("precipitation-sites.csv")
published <- read_input("published-effect-size.csv")

bounds <- function(v, pad) range(v) + c(-1, 1) * diff(range(v)) * pad
b_x <- bounds(sites$longitude, 0.2)
b_y <- bounds(sites$latitude, 0.2)
w_x <- c(-180, 180)
w_y <- c(-59.5, 84.5)
map_coord <- function(x, y) coord_cartesian(xlim = x, ylim = y, expand = FALSE, clip = "on")
b_ids <- c(3, 4, 6, 8, 11, 16)
groups <- c("1960s", "2010s")
counts <- table(unique(monthly[c("month", "period")])$period)
stopifnot(
  nrow(sites) == 10, !anyDuplicated(sites$site_id),
  setequal(published$site_id, sites$site_id),
  length(unique(points$dataset)) == 29,
  all(complete.cases(points)),
  setequal(unique(japan$bioclim), b_ids),
  setequal(unique(monthly$period), groups),
  setequal(unique(monthly$site_id), sites$site_id),
  setequal(unique(grids$period), groups),
  all(monthly$precipitation_mm >= 0),
  !anyDuplicated(monthly[c("site_id", "month")]),
  all(tapply(monthly$precipitation_mm, monthly$site_id, length) == sum(counts)),
  all(vapply(groups, function(g) length(unique(grids$month[grids$period == g])) == 12, logical(1)))
)

# Clip the colour domain at explicit limits; preserve the actual raster values.
pixel <- 1/6
global_rows <- round((90 - world$latitude) / pixel + .5)
global_cols <- round((world$longitude + 180) / pixel + .5)
stopifnot(!anyDuplicated(cbind(global_rows, global_cols)))
clamp_temp <- pmin(30, pmax(-24, world$temperature_c))
global_colors <- matrix("transparent", nrow = 1080, ncol = 2160)
global_colors[cbind(global_rows, global_cols)] <-
  scales::col_numeric(climate_cols, c(-24, 30))(clamp_temp)
a <- ggplot(points, aes(longitude, latitude)) +
  annotation_raster(as.raster(global_colors), -180, 180, -90, 90, interpolate = FALSE) +
  geom_point(size = .29, alpha = .85, colour = "black", stroke = 0) +
  map_coord(w_x, w_y) + empty

inset <- function(id) {
  panel <- japan[japan$bioclim == id, ]
  ggplot(panel, aes(longitude, latitude)) +
    geom_raster(aes(fill = value), interpolate = FALSE) +
    geom_point(data = sites, size = .54, stroke = 0) +
    scale_fill_gradientn(colours = climate_cols, na.value = "transparent", guide = "none") +
    map_coord(b_x, b_y) + empty +
    theme(panel.border = element_rect(fill = NA, colour = "#202020", linewidth = 0.24))
}

# Each layer uses the same affine transform and its own vertical displacement.
# Boundaries come from exposed grid edges. Interior cells have no outlines.
stack <- function(period) {
  dat <- grids[grids$period == period, ]
  months <- sort(unique(dat$month))
  xx <- sort(unique(grids$longitude))
  yy <- sort(unique(grids$latitude))
  dx <- min(diff(xx))
  dy <- min(diff(yy))
  x0 <- mean(range(xx))
  y0 <- mean(range(yy))
  tx <- function(x, y) (x - x0) + .15 * (y - y0)
  ty <- function(x, y) .45 * (y - y0) + .22 * (x - x0)
  step <- .28
  to_col <- scales::col_numeric(climate_cols, range(grids$precipitation_mm, na.rm = TRUE))
  tiles <- vector("list", length(months) * 2L)
  for (i in rev(seq_along(months))) {
    m <- dat[dat$month == months[i] & is.finite(dat$precipitation_mm), ]
    x <- m$longitude
    y <- m$latitude
    corners_x <- rbind(x - dx/2, x + dx/2, x + dx/2, x - dx/2)
    corners_y <- rbind(y - dy/2, y - dy/2, y + dy/2, y + dy/2)
    shift <- step * (i - 1)
    poly <- polygonGrob(tx(corners_x, corners_y), ty(corners_x, corners_y) - shift,
                        id.lengths = rep(4L, length(x)), default.units = "native",
                        gp = gpar(fill = to_col(m$precipitation_mm), col = NA))
    nx <- as.integer(round((x - min(xx))/dx))
    ny <- as.integer(round((y - min(yy))/dy))
    cell <- nx + (length(xx) + 2L) * ny
    stride <- length(xx) + 2L
    neighbor <- rbind(cell - stride, cell + 1L, cell + stride, cell - 1L)
    exposed <- which(!neighbor %in% cell)
    j <- c(2, 3, 4, 1)
    edges <- segmentsGrob(tx(corners_x, corners_y)[exposed],
                          (ty(corners_x, corners_y) - shift)[exposed],
                          tx(corners_x[j, ], corners_y[j, ])[exposed],
                          (ty(corners_x[j, ], corners_y[j, ]) - shift)[exposed],
                          default.units = "native", gp = gpar(col = "#263342", lwd = .53))
    idx <- 2L * (length(months) - i) + 1L
    tiles[[idx]] <- poly
    tiles[[idx + 1L]] <- edges
  }
  marks <- pointsGrob(tx(sites$longitude, sites$latitude), ty(sites$longitude, sites$latitude),
                      default.units = "native", pch = 21, size = unit(1.0, "mm"),
                      gp = gpar(fill = "white", col = "#192631", lwd = .55))
  xlim <- range(tx(rep(range(xx), 2), rep(range(yy), each = 2))) + c(-.18, .18)
  ylim <- range(ty(rep(range(xx), 2), rep(range(yy), each = 2))) + c(-step * 11 - .12, .12)
  gTree(children = do.call(gList, c(tiles, list(marks))),
        vp = viewport(xscale = xlim, yscale = ylim))
}

# Keep the two lower plots on the same discrete scale, including their margins.
monthly$period <- factor(monthly$period, groups)
eff <- do.call(rbind, lapply(split(monthly, monthly$site_id), function(x) {
  early <- x$period == groups[1]
  n_early <- sum(early)
  n_late <- sum(!early)
  n <- n_early + n_late
  # Conditional rank-sum variance uses mid-ranks and includes the tie correction.
  ranks <- rank(x$precipitation_mm, ties.method = "average")
  rank_sd <- sqrt(n_early * n_late / n * stats::var(ranks))
  stopifnot(is.finite(rank_sd), rank_sd > 0)
  z <- (sum(ranks[early]) - n_early * mean(ranks)) / rank_sd
  data.frame(site_id = x$site_id[1], effect_size = abs(z) / sqrt(n),
             n_1960s = n_early, n_2010s = n_late)
}))
eff$published_effect_size <- published$effect_original[match(eff$site_id, published$site_id)]
eff <- eff[order(-eff$effect_size, eff$site_id), ]
eff$row_from_top <- seq_len(nrow(eff))
write.csv(eff, file.path(out, "precipitation-effect-sizes.csv"), row.names = FALSE)
order_sites <- rev(eff$site_id)
monthly$site <- factor(monthly$site_id, order_sites)
eff$site <- factor(eff$site_id, order_sites)

stat_theme <- theme_classic(base_size = 7, base_family = font) +
  theme(axis.text.y = element_blank(), axis.ticks.y = element_blank(),
        axis.line.y = element_blank(), axis.line.x = element_line(linewidth = .24),
        axis.ticks.x = element_line(linewidth = .22), axis.ticks.length = unit(1, "mm"),
        axis.text.x = element_text(colour = "#202020", size = 6),
        axis.title.x = element_text(size = 7, margin = margin(t = 3)),
        axis.title.y = element_text(size = 7, margin = margin(r = 4)),
        legend.position = "none", plot.margin = margin(0, 3, 1, 3))
site_scale <- function() scale_y_discrete(limits = order_sites, drop = FALSE,
                                         expand = expansion(add = c(.52, 1.4)))
ridge <- ggplot(monthly, aes(precipitation_mm, site, fill = period,
                             group = interaction(site, period))) +
  stat_density_ridges(from = 0, quantiles = 2, quantile_lines = TRUE, colour = "#22242a",
                      alpha = .55, scale = 1.25, linewidth = .21,
                      rel_min_height = 0) +
  site_scale() + scale_fill_manual(values = period_cols) +
  scale_x_continuous(limits = NULL, breaks = seq(0, 1600, 200),
                     expand = expansion(mult = c(.02, .025))) +
  labs(x = "Monthly precipitation (mm)", y = "Sampling location") + stat_theme

bars <- ggplot(eff, aes(effect_size, site)) +
  geom_col(fill = "#F0CC21", colour = "#282522", linewidth = .24, width = .86) +
  site_scale() +
  scale_x_continuous(breaks = scales::breaks_pretty(n = 4), labels = scales::label_number(accuracy = .01),
                     expand = expansion(mult = c(0, .03))) +
  labs(x = "Climate change effect size", y = NULL) + stat_theme
stopifnot(identical(
  ggplot_build(ridge)$layout$panel_params[[1]]$y.range,
  ggplot_build(bars)$layout$panel_params[[1]]$y.range))

# Draw the zoom cone in canvas coordinates behind the six panels.
loc <- list(x = .014, y = .383, width = .741, height = .457)
a_to_x <- function(x) loc$x + loc$width * (x - min(w_x))/diff(w_x)
a_to_y <- function(y) loc$y + loc$height * (y - min(w_y))/diff(w_y)
zoom <- c(xmin = 122, xmax = 149, ymin = 29, ymax = 52)
zx <- a_to_x(zoom[1:2])
zy <- a_to_y(zoom[3:4])
cone_style <- gpar(fill = "#D9D9D9", col = NA, alpha = .60)
lower_cone <- polygonGrob(x = c(zx[1], zx[2], .458, .142),
                          y = c(zy[1], zy[1], .372, .372), gp = cone_style)
right_cone <- polygonGrob(x = c(zx[2], .772, .772, zx[2]),
                          y = c(zy[2], .931, .401, zy[1]), gp = cone_style)
frame <- rectGrob(x = mean(zx), y = mean(zy), width = diff(zx), height = diff(zy),
                  gp = gpar(fill = NA, col = "#303030", lwd = .7))

label <- function(text, x, y, size = 7, ...) {
  draw_label(text, x = x, y = y, fontfamily = font, size = size, ...)
}
bar_x <- .462 + seq(0, .105, length.out = 100)
temperature_key <- rasterGrob(matrix(grDevices::colorRampPalette(climate_cols)(100), nrow = 1),
                              x = mean(range(bar_x)), y = .934, width = .105, height = .016,
                              interpolate = TRUE)
f <- ggdraw() +
  draw_plot(a, loc$x, loc$y, loc$width, loc$height) +
  draw_grob(lower_cone) + draw_grob(right_cone) + draw_grob(frame) +
  draw_grob(temperature_key) +
  label("Annual mean temperature (°C) (BIOCLIM-1)", .449, .936, 7, hjust = 1) +
  label("a", .014, .974, 9.5, fontface = "bold", hjust = 0) +
  label("b", .743, .974, 9.5, fontface = "bold", hjust = 0) +
  label("c", .014, .352, 9.5, fontface = "bold", hjust = 0)
for (t in seq(-20, 30, 10)) {
  f <- f + label(t, min(bar_x) + (t + 24)/54 * diff(range(bar_x)), .914, 6)
}
for (i in seq_along(b_ids)) {
  x <- .779 + ((i - 1) %% 2) * .108
  y <- .821 - ((i - 1) %/% 2) * .212
  f <- f + draw_plot(inset(b_ids[i]), x, y, .099, .098) +
    label(paste0("BIOCLIM-", b_ids[i]), x + .0495, y + .119, 6.6)
}

labels <- c("1961–1969", "2010–2018")
for (i in seq_along(groups)) {
  x <- .103 + (i - 1) * .163
  f <- f + draw_grob(stack(groups[i]), x, .084, .148, .220) +
    label(paste0(labels[i], "\nPrecipitation  n = ", counts[groups[i]]),
          x + .074, .336, 7, lineheight = .91)
}
process_arrow <- segmentsGrob(x0 = .425, y0 = .190, x1 = .468, y1 = .190,
                              arrow = grid::arrow(type = "closed", length = unit(1.35, "mm")),
                              gp = gpar(col = "#536478", fill = "#536478", lwd = .95))
f <- f + draw_grob(process_arrow) +
  draw_plot(ridge, .486, .037, .255, .270) +
  draw_plot(bars, .758, .037, .228, .270) +
  label("Precipitation change\n1960s–2010s", .625, .336, 7, lineheight = .91)
for (i in seq_along(groups)) {
  kx <- .568 + (i - 1) * .077
  f <- f + draw_grob(rectGrob(x = kx, y = .020, width = unit(2.22, "mm"),
                            height = unit(1.95, "mm"),
                            gp = gpar(fill = period_cols[i], col = "#22242a", lwd = .75))) +
    label(groups[i], kx + .0105, .020, 6.4, hjust = 0)
}

authorization <- Sys.getenv("BIOFIGURE_RENDER_AUTHORIZATION")
if (nzchar(authorization)) {
  helper <- Sys.getenv("BIOFIGURE_R_HELPER")
  spec <- Sys.getenv("BIOFIGURE_DESIGN_SPEC")
  renderer_path <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
  source(helper)
  design <- yaml::read_yaml(spec)
  boxes <- data.frame(id = c("data", "labels", "legend", "insets", "precipitation"),
                      x = width_mm * c(.014, .014, .15, .772, .10),
                      y = height_mm * c(.383, .963, .900, .384, .008),
                      w = width_mm * c(.741, .032, .44, .22, .89),
                      h = height_mm * c(.457, .031, .055, .574, .342))
  bf_render_png(f, file.path(out, "repadapt-fig1abc.png"), font = bf_font(font),
                allowed_text = unlist(design$text_contract$allowed_text),
                width_mm = width_mm, height_mm = height_mm, target_width_mm = width_mm,
                source_files = c(renderer_path, helper, spec, list.files(input, full.names = TRUE)),
                boxes = boxes, dpi = 300, min_text_pt = 6,
                heading_authorization = "Source panel identifiers, climate variable labels and period labels.",
                authorization = authorization, skill_root = dirname(dirname(helper)),
                publication_size_class = "double-column")
} else {
  ggsave(file.path(out, "repadapt-fig1abc.png"), f, width = width_mm, height = height_mm,
         units = "mm", dpi = 300, bg = "white", device = ragg::agg_png)
}
pdf_path <- file.path(out, "repadapt-fig1abc.pdf")
if (identical(Sys.info()[["sysname"]], "Darwin")) {
  # Quartz PDF places raster scanlines bottom-first in the affected macOS R build.
  orient_quartz_rasters <- function(grob) {
    if (inherits(grob, "rastergrob")) {
      raster <- grob$raster
      grob$raster <- as.raster(raster[rev(seq_len(nrow(raster))), , drop = FALSE])
    }
    if (length(grob$grobs)) grob$grobs <- lapply(grob$grobs, orient_quartz_rasters)
    if (length(grob$children)) {
      grob$children <- do.call(gList, lapply(grob$children, orient_quartz_rasters))
    }
    grob
  }
  grDevices::quartz(type = "pdf", file = pdf_path, width = width_mm / 25.4,
                    height = height_mm / 25.4, family = font, bg = "white")
  grid.draw(orient_quartz_rasters(ggplotGrob(f)))
  invisible(grDevices::dev.off())
} else {
  ggsave(pdf_path, f, width = width_mm, height = height_mm, units = "mm",
         device = grDevices::cairo_pdf, family = font, bg = "white")
}
writeLines(capture.output(sessionInfo()), file.path(out, "R-session.txt"))
