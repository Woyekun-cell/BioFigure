score_palette <- c(low = "#385997", low_mid = "#41A8A4", center = "#F6E7A5",
                   high_mid = "#F28B54", high = "#A92451", missing = "#B3BBC3")

load_points <- function(path) {
  cells <- read.csv(path, colClasses = "character", na.strings = c("", "NA"))
  required <- c("cell_id", "umap1", "umap2", "score")
  if (!all(required %in% names(cells)) || nrow(cells) < 2L)
    stop("Need two or more rows with cell_id, umap1, umap2, score")
  cells <- cells[, required]
  if (anyNA(cells$cell_id) || any(!nzchar(trimws(cells$cell_id))) || anyDuplicated(cells$cell_id))
    stop("cell_id must be nonempty and unique")
  for (name in required[-1]) {
    original <- cells[[name]]
    value <- suppressWarnings(as.numeric(original))
    if (any(is.na(value) & !is.na(original)))
      stop(paste("Non-numeric", name))
    cells[[name]] <- value
  }
  if (!all(is.finite(cells$umap1)) || !all(is.finite(cells$umap2)))
    stop("Both coordinates must be finite")
  if (any(is.infinite(cells$score)) || any(cells$score < 0 | cells$score > 1, na.rm = TRUE) ||
      all(is.na(cells$score)))
    stop("Need at least one score in [0, 1], and no out-of-range scores")
  cells
}

score_embedding <- function(cells, family = "Arial") {
  cells <- cells[order(cells$score, cells$cell_id, na.last = FALSE), ]
  x <- range(cells$umap1)
  y <- range(cells$umap2)
  span <- max(diff(x), diff(y))
  if (!is.finite(span) || span <= 0) stop("Embedding must have nonzero spatial extent")
  step <- 0.095 * span
  ox <- x[1] - 0.027 * span
  oy <- y[1] - 0.022 * span
  axes <- data.frame(x = ox, y = oy, xend = c(ox + step, ox), yend = c(oy, oy + step))
  ggplot2::ggplot(cells, ggplot2::aes(umap1, umap2)) +
    ggplot2::geom_point(ggplot2::aes(colour = score), size = .71, shape = 16,
                        stroke = 0, alpha = .55) +
    ggplot2::geom_segment(data = axes, ggplot2::aes(x, y, xend = xend, yend = yend),
                          inherit.aes = FALSE, color = "#25313B", linewidth = .32,
                          arrow = grid::arrow(length = grid::unit(1.65, "mm"), type = "closed")) +
    ggplot2::annotate("text", x = ox + step/2, y = oy - 0.023*span, label = "UMAP1",
                      size = 7.5, size.unit = "pt", family = family, colour = "#25313B") +
    ggplot2::annotate("text", x = ox - 0.022*span, y = oy + step/2, label = "UMAP2",
                      size = 7.5, size.unit = "pt", family = family, colour = "#25313B", angle = 90) +
    ggplot2::scale_colour_gradientn(
      name = "Potency score", colours = unname(score_palette[1:5]), limits = c(0, 1),
      breaks = c(0, .5, 1), labels = c("0  Differentiated", "0.5", "1  Stem-like"),
      na.value = unname(score_palette["missing"]),
      guide = ggplot2::guide_colourbar(barwidth = grid::unit(3, "mm"),
              barheight = grid::unit(29, "mm"), display = "rectangles", nbin = 100)
    ) +
    ggplot2::coord_fixed(xlim = c(ox - .064 * span, x[2] + .025 * span),
                        ylim = c(oy - .055 * span, y[2] + .025 * span), expand = FALSE) +
    ggplot2::theme_void(base_family = family, base_size = 8) +
    ggplot2::theme(
      legend.position = "right", legend.justification = "center",
      legend.title = ggplot2::element_text(family = family, size = 8, color = "#25313B"),
      legend.text = ggplot2::element_text(family = family, size = 7, color = "#25313B"),
      legend.box.margin = ggplot2::margin(0, 0, 0, 3, unit = "mm"),
      plot.margin = ggplot2::margin(3, 4, 3, 3, unit = "mm"),
      plot.background = ggplot2::element_rect(fill = "white", color = NA),
      panel.background = ggplot2::element_rect(fill = "white", color = NA)
    )
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 2L) stop("Usage: Rscript draw_score_embedding.R INPUT.csv OUTPUT_DIR")
  if (!dir.exists(args[2])) dir.create(args[2], recursive = TRUE)
  family <- if (Sys.info()[["sysname"]] == "Darwin") "Arial" else "sans"
  figure <- score_embedding(load_points(args[1]), family)
  ggplot2::ggsave(file.path(args[2], "embedding-score.png"), figure, width = 122, height = 112,
                  units = "mm", dpi = 300, device = ragg::agg_png, bg = "white")
  if (Sys.info()[["sysname"]] == "Darwin") {
    grDevices::quartz(type = "pdf", file = file.path(args[2], "embedding-score.pdf"),
                      width = 122/25.4, height = 112/25.4, family = family, bg = "white")
  } else {
    grDevices::pdf(file.path(args[2], "embedding-score.pdf"),
                   width = 122/25.4, height = 112/25.4, bg = "white", useDingbats = FALSE)
  }
  print(figure)
  invisible(grDevices::dev.off())
}
