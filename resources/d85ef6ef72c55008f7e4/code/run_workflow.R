args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) stop("Usage: Rscript run_workflow.R scores.csv metrics.json output-directory")
script_file <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])
source(file.path(dirname(normalizePath(script_file)), "draw_figure.R"))
scores <- read.csv(args[1], check.names = FALSE, stringsAsFactors = FALSE,
                    colClasses = c(community = "character", group = "character"))
config <- jsonlite::read_json(args[2], simplifyVector = TRUE)
figure <- build_gradient_ridges(scores, config)
if (dir.exists(args[3]) && length(list.files(args[3], all.files = TRUE, no.. = TRUE))) {
  stop("Output directory must be empty")
}
dir.create(args[3], recursive = TRUE, showWarnings = FALSE)
stem <- file.path(args[3], "gradient-ridgeline")
width <- 42 * nrow(config$metrics) + 57
height <- max(65, min(170, 6.4 * length(figure$row_levels) + 35.6))
grDevices::quartz(type = "pdf", file = paste0(stem, ".pdf"),
                 width = width / 25.4, height = height / 25.4, family = "Arial")
print(figure$plot)
invisible(dev.off())
ggsave(paste0(stem, ".png"), figure$plot, width = width, height = height,
        units = "mm", device = ragg::agg_png, dpi = 320, bg = "white")
write.csv(figure$scores, file.path(args[3], "processed_scores.csv"), row.names = FALSE)
write.csv(figure$row_counts, file.path(args[3], "group_counts.csv"), row.names = FALSE)
curves <- do.call(rbind, lapply(seq_along(figure$plots), function(i) {
  x <- ggplot_build(figure$plots[[i]])$data[[1]]
  data.frame(metric = config$metrics$metric[i],
             group = figure$row_levels[as.integer(x$y)],
             percentile = x$x, density = x$density, fill = x$fill)
}))
write.csv(curves, file.path(args[3], "density_curves.csv"), row.names = FALSE)
jsonlite::write_json(list(rows = nrow(figure$scores), groups = nrow(figure$row_counts),
                          metrics = config$metrics$metric, bandwidth = config$bandwidth,
                          height_scale = config$height_scale, width_mm = width,
                          height_mm = height), file.path(args[3], "workflow-settings.json"),
                     pretty = TRUE, auto_unbox = TRUE)
writeLines(capture.output(sessionInfo()), file.path(args[3], "sessionInfo.txt"))
