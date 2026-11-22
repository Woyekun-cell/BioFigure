# Gradient ridgelines adapted from the public issue 108 tutorial.
# Reference: Waller and Anderson, Nature 600 (2021), doi:10.1038/s41586-021-04167-x.
# Position uses global percentile. Fill uses the globally standardized raw score.
library(ggplot2)
library(ggridges)
library(patchwork)

prepare_scores <- function(scores, metrics) {
  required <- c("community", "group", paste0(metrics$metric, "_raw"))
  stopifnot(all(required %in% names(scores)), nrow(scores) >= 2L)
  stopifnot(!anyNA(scores[required]), !anyDuplicated(scores$community),
            all(nzchar(scores$community)), all(nzchar(scores$group)),
            !"All" %in% scores$group)
  for (metric in metrics$metric) {
    value <- scores[[paste0(metric, "_raw")]]
    stopifnot(is.numeric(value), all(is.finite(value)))
    population_sd <- sqrt(mean((value - mean(value))^2))
    stopifnot(population_sd > 0)
    scores[[paste0(metric, "_z")]] <- (value - mean(value)) / population_sd
    percentile <- paste0(metric, "_pctl")
    if (!percentile %in% names(scores)) {
      scores[[percentile]] <- 100 * (rank(value, ties.method = "average") - 1) / length(value)
    }
    position <- scores[[percentile]]
    stopifnot(is.numeric(position), all(is.finite(position)),
              all(position >= 0 & position <= 100),
              all(diff(position[order(value)]) >= -1e-10))
  }
  stopifnot(all(table(scores$group) >= 2L))
  scores
}

make_metric_plot <- function(scores, metric, row_levels, row_labels, bandwidth, height_scale) {
  raw_name <- paste0(metric$metric, "_pctl")
  score_lookup <- data.frame(percentile = scores[[raw_name]],
                          z = scores[[paste0(metric$metric, "_z")]])
  plot_data <- data.frame(percentile = scores[[raw_name]], group = scores$group)
  plot_data <- rbind(plot_data, transform(plot_data, group = "All"))
  plot_data$group <- factor(plot_data$group, levels = row_levels)

  # The color lookup uses all communities once, before the All row is appended.
  ggplot(plot_data, aes(x = percentile, y = group)) +
    geom_ridgeline_gradient(
      aes(height = after_stat(height_scale * density),
          fill = after_stat(approx(score_lookup$percentile, score_lookup$z,
                                   xout = x, rule = 2, ties = mean)$y)),
      stat = "density", orientation = "x", bw = bandwidth,
      bounds = c(0, 100), colour = "grey42", linewidth = 0.28
    ) +
    geom_vline(xintercept = 50, linetype = "dashed", linewidth = 0.28,
               colour = "grey35") +
    scale_x_continuous(limits = c(0, 100), breaks = c(0, 100),
                       expand = expansion(add = 1.5)) +
    scale_y_discrete(labels = row_labels,
                     expand = expansion(add = c(0.1, 0.65))) +
    scale_fill_gradientn(colours = unlist(metric$palette),
                         limits = c(-3, 3), oob = scales::squish,
                         breaks = c(-3, 0, 3), labels = c("−3σ", "0", "3σ")) +
    guides(fill = guide_colourbar(barwidth = grid::unit(30, "mm"),
                                  barheight = grid::unit(1.8, "mm"),
                                  display = "rectangles", nbin = 128)) +
    labs(title = metric$title, x = metric$x_label, y = NULL, fill = NULL) +
    theme_minimal(base_size = 6.5, base_family = "Arial") +
    theme(panel.grid = element_blank(),
          panel.grid.major.y = element_line(colour = "grey84", linewidth = 0.2),
          plot.title = element_text(size = 8, hjust = 0.5, margin = margin(b = 4)),
          axis.title.x = element_text(size = 7, margin = margin(t = 3)),
          axis.text = element_text(size = 6.5, colour = "#30343B"),
          legend.text = element_text(size = 6.5),
          plot.margin = margin(2, 3, 2, 3), legend.position = "bottom",
          legend.margin = margin(0, 0, 0, 0),
          legend.box.spacing = grid::unit(1, "mm"),
          legend.frame = element_rect(colour = "grey40", linewidth = 0.2))
}

build_gradient_ridges <- function(scores, config) {
  metrics <- config$metrics
  stopifnot(nrow(metrics) >= 1L, !anyDuplicated(metrics$metric),
            all(c("metric", "title", "x_label", "palette") %in% names(metrics)),
            is.numeric(config$bandwidth), config$bandwidth > 0,
            is.numeric(config$height_scale), config$height_scale > 0)
  scores <- prepare_scores(scores, metrics)
  counts <- table(scores$group)
  counts <- counts[order(-as.integer(counts), names(counts))]
  row_levels <- rev(c("All", names(counts)))
  row_counts <- c(All = nrow(scores), counts)
  row_names <- names(row_counts)
  row_names[row_names %in% config$merged_groups] <-
    paste0(row_names[row_names %in% config$merged_groups], "†")
  row_labels <- setNames(paste0(row_names, " (", scales::comma(as.integer(row_counts)), ")"),
                         names(row_counts))
  plots <- lapply(seq_len(nrow(metrics)), function(i) {
    p <- make_metric_plot(scores, metrics[i, ], row_levels, row_labels,
                          config$bandwidth, config$height_scale)
    if (i > 1L) p <- p + theme(axis.text.y = element_blank())
    p
  })
  list(plot = wrap_plots(plots, nrow = 1), plots = plots, scores = scores,
       row_counts = data.frame(group = names(row_counts), n = as.integer(row_counts)),
       row_levels = row_levels)
}
