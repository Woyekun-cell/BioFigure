# Input is the authors' public data/figure_data/fig_2.csv at
# https://github.com/CSSLab/social-dimensions/tree/93a0ac41dfe454e3c71124470a8254ca30cb33a3
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Usage: Rscript prepare_example.R fig_2.csv output-directory")
if (dir.exists(args[2]) && length(list.files(args[2], all.files = TRUE, no.. = TRUE))) {
  stop("Output directory must be empty")
}
scores <- read.csv(args[1], stringsAsFactors = FALSE, check.names = FALSE,
                    colClasses = c(name = "character", cluster_name = "character"))
metrics <- c("age", "gender", "partisan")
fields <- as.vector(rbind(paste0(metrics, "_pctl"), paste0(metrics, "_raw")))
stopifnot(all(c("name", "cluster_name", fields) %in% names(scores)),
            !anyDuplicated(scores$name))
group <- scores$cluster_name
group[grepl("^General interest [0-9]+$", group)] <- "General interest"
group[grepl("^Gaming [0-9]+$", group)] <- "Gaming"
group[group == "Recreational drugs"] <- "Drugs"
output <- data.frame(community = scores$name, group = group, scores[fields])
config <- list(bandwidth = 3.5, height_scale = 40,
  merged_groups = c("General interest", "Gaming"),
  metrics = list(
    list(metric = "age", title = "Age", x_label = "← Young     Old →",
          palette = RColorBrewer::brewer.pal(11, "PiYG")),
    list(metric = "gender", title = "Gender", x_label = "← Masculine     Feminine →",
          palette = RColorBrewer::brewer.pal(11, "PuOr")),
    list(metric = "partisan", title = "Partisan", x_label = "← Left wing     Right wing →",
          palette = c("#3B4CC0", "#9EBEFF", "#DDDCDC", "#F7AC8E", "#B40426"))))
dir.create(args[2], recursive = TRUE, showWarnings = FALSE)
readr::write_csv(output, file.path(args[2], "community_scores.csv"))
jsonlite::write_json(config, file.path(args[2], "metrics.json"), auto_unbox = TRUE, pretty = TRUE)
