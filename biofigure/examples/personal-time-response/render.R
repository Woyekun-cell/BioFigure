# Rebuild the two aligned summaries from tidy, unit-level observations.
# Never materialize an implicit Rplots.pdf in the caller's working directory.
options(device = function(...) grDevices::pdf(file = NULL))
suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
})
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) stop("Usage: Rscript render.R <plot_data.csv> <design.json> <output_dir>")
data <- read.csv(args[1], colClasses = "character", check.names = FALSE, na.strings = "")
design <- jsonlite::fromJSON(args[2])
check <- function(ok, description) if (!isTRUE(ok)) stop(description, call. = FALSE)

required <- c("observation_id", "subject_id", "group", "time", "value")
check(all(required %in% names(data)) && nrow(data) > 0, "Missing observations or columns")
data <- data[required]
check(!anyNA(data) && all(nzchar(trimws(unlist(data[1:3])))), "Missing observation fields")
check(!anyDuplicated(data$observation_id), "Duplicate observation ID")
data$time <- as.numeric(data$time)
data$value <- as.numeric(data$value)
check(all(is.finite(data$time)) && all(is.finite(data$value)), "Non-finite time or response")
check(design$sampling %in% c("independent", "repeated"), "Unknown sampling design")
palette <- unlist(design$group_colors, use.names = TRUE)
groups <- names(palette)[names(palette) %in% data$group]
check(length(groups) == 2 && setequal(groups, data$group) && !anyDuplicated(groups),
      "Two conditions and their named colors are required")
invisible(col2rgb(palette[groups]))
check(is.character(design$time_label) && nzchar(design$time_label) &&
      is.character(design$value_label) && nzchar(design$value_label), "Both axes need labels")
data$group <- factor(data$group, levels = groups)
data <- data[order(data$group, data$subject_id, data$time, data$observation_id), ]
check(!anyDuplicated(data[c("subject_id", "time")]) &&
      !anyDuplicated(unique(data[c("subject_id", "group")])$subject_id),
      "Duplicate subject visit or subject shared by conditions")
repeated <- design$sampling == "repeated"
check(repeated == (anyDuplicated(data$subject_id) > 0L), "Declared sampling conflicts with subject IDs")
visits <- sort(unique(data$time))
if (!is.null(design$planned_times)) {
  plan <- as.numeric(design$planned_times)
  check(all(is.finite(plan)) && !anyDuplicated(plan) && all(visits %in% plan), "Invalid planned visits")
  visits <- sort(plan)
}
check(length(unique(data$time)) >= 2, "At least two observed times are required")

# Every plotted individual edge has an exported pair of observation IDs. A missed
# scheduled visit breaks the trajectory, including when both conditions missed it.
edges <- data.frame(from_id = character(), to_id = character(), group = character(),
                    x = numeric(), xend = numeric(), y = numeric(), yend = numeric())
if (repeated) {
  earlier <- seq_len(nrow(data) - 1L)
  later <- earlier + 1L
  visit_index <- match(data$time, visits)
  adjacent <- data$subject_id[earlier] == data$subject_id[later] &
              visit_index[later] == visit_index[earlier] + 1L
  a <- earlier[adjacent]
  b <- later[adjacent]
  edges <- data.frame(from_id = data$observation_id[a], to_id = data$observation_id[b],
                      group = data$group[a], x = data$time[a], xend = data$time[b],
                      y = data$value[a], yend = data$value[b])
}

cells <- split(data, list(data$group, data$time), drop = TRUE)
summary <- do.call(rbind, lapply(cells, function(cell) {
  q <- quantile(cell$value, c(.25, .75), names = FALSE)
  data.frame(group = cell$group[1], time = cell$time[1], n = nrow(cell),
             mean = mean(cell$value), low = q[1], high = q[2])
}))
summary <- summary[order(summary$group, summary$time), ]
# Break group mean lines at completely missing scheduled cells.
summary$run <- ave(match(summary$time, visits), summary$group,
                   FUN = function(i) cumsum(c(TRUE, diff(i) != 1L)))
run <- interaction(summary$group, summary$run, drop = TRUE)
mean_lines <- summary[ave(seq_along(run), run, FUN = length) > 1, ]

ink <- "#20333E"
light <- "#DFE6E8"
axis_x <- scale_x_continuous(breaks = visits, limits = range(visits),
                             expand = expansion(mult = c(.065, .065)))
axis_y <- scale_y_continuous(limits = range(data$value), expand = expansion(mult = c(.10, .12)))
frame <- theme_minimal(base_size = 11) +
  theme(text = element_text(colour = ink), panel.grid.minor = element_blank(),
        panel.grid.major.x = element_blank(), panel.grid.major.y = element_line(colour = light, linewidth = .30),
        axis.title = element_text(size = 10), axis.text = element_text(colour = ink),
        plot.title = element_text(size = 13, face = "bold", margin = margin(b = 5)),
        legend.position = if (is.null(design$legend_position)) "top" else design$legend_position, legend.title = element_blank(),
        legend.key.width = grid::unit(14, "mm"), legend.margin = margin(0, 0, 2, 0),
        strip.text = element_text(face = "bold", colour = ink, hjust = 0),
        panel.spacing.x = grid::unit(8, "mm"), plot.margin = margin(5, 9, 5, 7))
if (identical(design$grid, "none")) frame <- frame + theme(panel.grid.major.y = element_blank())
mean_view <- ggplot(summary, aes(time, mean, colour = group, shape = group)) +
  geom_line(data = mean_lines, aes(group = interaction(group, run), linetype = group), linewidth = .9) +
  geom_point(size = 2.8) +
  scale_colour_manual(values = palette) + scale_shape_manual(values = setNames(c(16, 17), groups)) +
  scale_linetype_manual(values = setNames(c("solid", "longdash"), groups)) +
  axis_x + axis_y + frame + labs(title = "Condition means", x = NULL, y = design$value_label)
detail <- ggplot(data, aes(time, value)) +
  geom_linerange(data = summary[summary$n >= 2, ], aes(x = time, ymin = low, ymax = high, colour = group),
                 inherit.aes = FALSE, linewidth = 3.2, alpha = .38, lineend = "butt")
emphasize_points <- identical(design$point_emphasis, "points")
point_size <- if (emphasize_points) 2.55 else 1.65
line_alpha <- if (emphasize_points) .24 else .55
if (nrow(edges)) {
  detail <- detail + geom_segment(data = edges, aes(x = x, xend = xend, y = y, yend = yend),
                                  inherit.aes = FALSE, colour = "#576A73", alpha = line_alpha, linewidth = .34)
}
detail <- detail + geom_point(aes(colour = group), size = point_size, alpha = .82) +
  facet_wrap(vars(group), nrow = 1) + scale_colour_manual(values = palette, guide = "none") +
  axis_x + axis_y + frame +
  labs(title = "Observations and middle 50%", x = design$time_label, y = design$value_label)
caption <- if (repeated) "Thin lines join consecutive visits of the same individual." else
  "Each point represents a different individual."
caption <- paste("Bars span the 25th to 75th percentiles.", caption)
if (identical(design$source, "synthetic")) caption <- paste(caption, "Simulated data.")
figure <- (mean_view / detail) + plot_layout(heights = c(1, 1.08)) +
  plot_annotation(caption = caption, theme = theme(
    plot.caption = element_text(size = 8, colour = "#465D69", hjust = 0, margin = margin(t = 6)),
    plot.margin = margin(10, 12, 9, 12)))

out <- args[3]
dir.create(out, recursive = TRUE, showWarnings = FALSE)
pdf_path <- file.path(out, "preview.pdf")
ggsave(pdf_path, figure, device = grDevices::pdf, width = 8.6, height = 5.7, bg = "white", useDingbats = FALSE)
rasterizer <- Sys.which("pdftoppm")
check(nzchar(rasterizer), "pdftoppm is required to rasterize the verified PDF")
status <- system2(rasterizer, c("-r", "145", "-png", "-singlefile",
                                shQuote(pdf_path), shQuote(file.path(out, "preview"))))
check(status == 0L, "PDF rasterization failed")
write.csv(summary[c("group", "time", "n", "mean", "low", "high")], file.path(out, "summary.csv"), row.names = FALSE)
write.csv(edges[c("from_id", "to_id")], file.path(out, "links.csv"), row.names = FALSE)
