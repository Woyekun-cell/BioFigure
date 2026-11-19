args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(if (length(args)) args[[1]] else '.', mustWork = TRUE)
source(file.path(root, 'scripts/figure_style.R'))
data_path <- file.path(root, 'results/plot_data/linear_scatter.csv')
output_path <- file.path(root, 'results/figures/linear_scatter.png')
figure_data <- read.csv(data_path, stringsAsFactors = FALSE)
stopifnot(nrow(figure_data) == 320L, !anyNA(figure_data), !anyDuplicated(figure_data$observation_id))
font <- bf_font('Arial')
plot <- ggplot2::ggplot(figure_data, ggplot2::aes(x = x, y = y)) +
  ggplot2::geom_smooth(method = 'lm', formula = y ~ x, se = TRUE,
                       linewidth = 0.8, colour = '#B15D4A', fill = '#D5AEA5', alpha = 0.24) +
  ggplot2::geom_point(shape = 16, size = 1.65, alpha = 0.56, colour = '#244F6A') +
  ggplot2::scale_x_continuous(breaks = seq(0, 10, 2), limits = c(0, 10), expand = ggplot2::expansion(mult = 0)) +
  ggplot2::scale_y_continuous(breaks = seq(0, 12, 2), limits = c(-1, 12), expand = ggplot2::expansion(mult = 0)) +
  ggplot2::labs(x = 'Simulated X (a.u.)', y = 'Simulated Y (a.u.)') +
  bf_theme(font, size = 8) +
  ggplot2::theme(
    legend.position = 'none',
    panel.grid.major.y = ggplot2::element_line(colour = '#E7EBED', linewidth = 0.2),
    panel.grid.major.x = ggplot2::element_blank(),
    axis.line = ggplot2::element_line(colour = '#303A42', linewidth = 0.27),
    axis.ticks = ggplot2::element_line(colour = '#303A42', linewidth = 0.27),
    plot.margin = ggplot2::margin(4, 4, 4, 4, unit = 'mm'))
allowed_text <- c('Simulated X (a.u.)', 'Simulated Y (a.u.)', as.character(seq(0, 12, 2)))
boxes <- data.frame(id = c('data', 'labels', 'legend'),
                    x = c(18, 0, 121), y = c(5, 5, 5),
                    w = c(100, 16, 8), h = c(73, 73, 73))
receipt <- bf_render_png(plot, output_path, font, allowed_text,
                         width_mm = 130, height_mm = 88, target_width_mm = 130,
                         source_files = c(file.path(root, 'scripts/plot_linear.R'),
                                          file.path(root, 'scripts/figure_style.R'),
                                          file.path(root, 'scripts/design-spec.yaml'), data_path),
                         boxes = boxes, dpi = 300)
fit <- stats::lm(y ~ x, data = figure_data)
cat(sprintf('slope=%.4f, R2=%.4f, n=%d\n', unname(stats::coef(fit)[2]), summary(fit)$r.squared, nrow(figure_data)))
cat(output_path, '\n')

pdf_path <- file.path(root, 'results/figures/linear_scatter.pdf')
grDevices::quartz(type = 'pdf', file = pdf_path, width = 130 / 25.4, height = 88 / 25.4, family = font$family, bg = 'white')
print(plot)
grDevices::dev.off()

writeLines(capture.output(sessionInfo()), file.path(root, 'results/environment.txt'))
