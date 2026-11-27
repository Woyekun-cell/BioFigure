# Input consists of per-feature results and a named display order.
circular_effect <- function(markers, regions, fold_change = 1.2, q_limit = 0.01, label_n = 2L) {
  stopifnot(all(c("domain", "gene", "avg_log2FC", "p_val_adj") %in% names(markers)),
            all(c("domain", "color") %in% names(regions)), nrow(regions) >= 2L,
            is.numeric(markers$avg_log2FC), is.numeric(markers$p_val_adj),
            is.finite(fold_change), fold_change > 1, is.finite(q_limit), q_limit > 0, q_limit <= 1,
            is.finite(label_n), label_n >= 0, label_n == as.integer(label_n),
            all(!is.na(markers$domain) & nzchar(markers$domain)),
            all(!is.na(markers$gene) & nzchar(markers$gene)),
            all(!is.na(regions$domain) & nzchar(regions$domain)),
            all(grepl("^#[[:xdigit:]]{6}$", regions$color)), !anyDuplicated(regions$domain),
            !anyDuplicated(markers[c("domain", "gene")]),
            all(markers$domain %in% regions$domain),
            all(is.finite(markers$avg_log2FC)), all(is.finite(markers$p_val_adj)),
            all(markers$p_val_adj >= 0 & markers$p_val_adj <= 1))
  cutoff <- log2(fold_change)
  # A decimal CSV round-trip can move a threshold tie by one floating-point step.
  tolerance <- 4 * .Machine$double.eps * max(1, cutoff)
  points <- markers[markers$p_val_adj < q_limit & abs(markers$avg_log2FC) > cutoff + tolerance, , drop = FALSE]
  if (!nrow(points)) stop("No markers meet the display thresholds")
  points <- points[order(match(points$domain, regions$domain), points$gene, method = "radix"), , drop = FALSE]
  points$direction <- ifelse(points$avg_log2FC > 0, "Upregulated", "Downregulated")
  points$sector <- match(points$domain, regions$domain)
  step <- 2 * pi / nrow(regions)
  zero <- 0.65
  half_band <- 0.070
  slope <- min(0.32 / max(c(0.001, -points$avg_log2FC)), 0.28 / max(c(0.001, points$avg_log2FC)))
  radius <- function(effect) zero - sign(effect) * half_band - slope * effect
  # The zero band is a label track. Jitter changes angle alone.
  points$radius <- radius(points$avg_log2FC)
  jitter <- (seq_len(nrow(points)) * (sqrt(5) - 1) / 2) %% 1 - 0.5
  points$angle <- step * (points$sector - 0.5 + jitter * 0.70)
  points$x <- points$radius * sin(points$angle)
  points$y <- points$radius * cos(points$angle)
  wedge <- function(sector, inner, outer, gap = 0.04) {
    angle <- seq((sector - 1 + gap) * step, (sector - gap) * step, length.out = 40)
    theta <- c(angle, rev(angle))
    r <- rep(c(inner, outer), each = length(angle))
    data.frame(domain = regions$domain[sector], x = r * sin(theta), y = r * cos(theta))
  }
  sectors <- seq_len(nrow(regions))
  bands <- do.call(rbind, lapply(sectors, wedge, inner = zero - half_band, outer = zero + half_band, gap = 0.008))
  extents <- do.call(rbind, lapply(sectors, function(sector) {
    observed <- points$radius[points$sector == sector]
    if (!length(observed)) return(NULL)
    wedge(sector, min(c(zero - half_band, observed)) - 0.024, max(c(zero + half_band, observed)) + 0.024)
  }))
  theta <- step * (sectors - 0.5)
  ring_labels <- transform(regions, x = zero * sin(theta), y = zero * cos(theta),
                           angle = ((-theta * 180 / pi + 90) %% 180) - 90)
  ranked <- points[order(-abs(points$avg_log2FC), points$p_val_adj, points$gene, method = "radix"), , drop = FALSE]
  labels <- do.call(rbind, lapply(split(ranked, list(ranked$domain, ranked$direction), drop = TRUE), head, n = label_n))
  inner_edges <- tapply(points$radius, points$domain, min)
  outer_edges <- tapply(points$radius, points$domain, max)
  clearance <- 0.035 + 0.0065 * nchar(labels$gene) * abs(sin(labels$angle)) + 0.013 * abs(cos(labels$angle))
  label_radius <- unname(ifelse(labels$avg_log2FC > 0, inner_edges[labels$domain] - clearance,
                                outer_edges[labels$domain] + clearance))
  label_offset <- label_radius - labels$radius
  direction_colors <- c(Upregulated = "#BB423C", Downregulated = "#167EA4")
  key <- data.frame(direction = names(direction_colors), x = -0.16, y = c(0.058, -0.044))
  plot <- ggplot2::ggplot() +
    ggplot2::geom_polygon(data = extents, ggplot2::aes(x, y, group = domain), fill = "#EFF0F2") +
    ggplot2::geom_point(data = points, ggplot2::aes(x, y, colour = direction), size = 0.64, alpha = 0.70, stroke = 0) +
    ggplot2::geom_polygon(data = bands, ggplot2::aes(x, y, group = domain, fill = domain), color = "#FFFFFF", linewidth = 0.19) +
    ggplot2::geom_text(data = ring_labels, ggplot2::aes(x, y, label = domain, angle = angle),
                       color = "#151722", size = 7.3, size.unit = "pt", family = "Arial") +
    ggrepel::geom_text_repel(data = labels, ggplot2::aes(x, y, label = gene), seed = 867L, max.time = 5, max.iter = 20000,
                            size = 6.3 / ggplot2::.pt, color = "#222530", family = "Arial",
                            nudge_x = label_offset * sin(labels$angle),
                            nudge_y = label_offset * cos(labels$angle), force_pull = 1.5,
                            box.padding = 0.32, point.padding = 0.08, segment.size = 0.19,
                            segment.color = "#616876", min.segment.length = 0.08, max.overlaps = Inf) +
    ggplot2::geom_point(data = key, ggplot2::aes(x, y, colour = direction), size = 2.1, stroke = 0) +
    ggplot2::geom_text(data = key, ggplot2::aes(x + 0.033, y, label = direction), hjust = 0, family = "Arial",
                       size = 7.3, size.unit = "pt", color = "#151722") +
    ggplot2::scale_colour_manual(values = direction_colors, guide = "none") +
    ggplot2::scale_fill_manual(values = setNames(regions$color, regions$domain), guide = "none") +
    ggplot2::coord_equal(xlim = c(-1.18, 1.18), ylim = c(-1.18, 1.18), expand = FALSE) +
    ggplot2::theme_void(base_family = "Arial", base_size = 7.3) +
    ggplot2::theme(plot.background = ggplot2::element_rect(fill = "white", colour = NA),
                   panel.background = ggplot2::element_rect(fill = "white", colour = NA),
                   plot.margin = ggplot2::margin(2, 2, 2, 2, unit = "mm"))
  list(plot = plot, points = points, labels = labels, zero_radius = zero, band_halfwidth = half_band, slope = slope)
}

save_circular_effect_pdf <- function(path, plot, width = 183, height = 170) {
  if (capabilities("aqua")) {
    grDevices::quartz(type = "pdf", file = path, width = width / 25.4, height = height / 25.4, family = "Arial")
    on.exit(invisible(grDevices::dev.off()))
    print(plot)
  } else {
    ggplot2::ggsave(path, plot, width = width, height = height, units = "mm", device = grDevices::cairo_pdf, family = "Arial")
  }
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 3L) stop("Usage: Rscript draw_circular_volcano.R markers.csv regions.csv output-directory")
  markers <- read.csv(args[1], check.names = FALSE, colClasses = c(domain = "character", gene = "character"))
  regions <- read.csv(args[2], colClasses = "character")
  out <- args[3]
  dir.create(out, showWarnings = FALSE, recursive = TRUE)
  fig <- circular_effect(markers, regions)
  ggplot2::ggsave(file.path(out, "circular-volcano.png"), fig$plot,
                 width = 183, height = 170, units = "mm", dpi = 320, device = ragg::agg_png)
  save_circular_effect_pdf(file.path(out, "circular-volcano.pdf"), fig$plot)
  write.csv(fig$points, file.path(out, "displayed-markers.csv"), row.names = FALSE)
  write.csv(fig$labels, file.path(out, "gene-labels.csv"), row.names = FALSE)
}
