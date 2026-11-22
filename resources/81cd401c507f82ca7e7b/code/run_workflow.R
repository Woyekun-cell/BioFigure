args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L) stop("Usage: Rscript run_workflow.R records.csv trait-map.csv cytobands.csv output-directory")
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])
source(file.path(dirname(normalizePath(script)), "draw_figure.R"))
records <- read.csv(args[1], stringsAsFactors = FALSE)
mapping <- read.csv(args[2], stringsAsFactors = FALSE)
bands <- read.csv(args[3], stringsAsFactors = FALSE)
prepared <- prepare_loci(records, mapping, bands)
if (dir.exists(args[4]) && length(list.files(args[4], all.files = TRUE, no.. = TRUE))) {
  stop("Output directory must be empty")
}
dir.create(args[4], recursive = TRUE, showWarnings = FALSE)
output <- normalizePath(args[4])
setwd(output)
palette <- c("#665191", "#4B83A5", "#66A182", "#D09056", "#B7535A", "#D3A246",
             "#7566A4", "#4C98A8", "#A76A8D", "#658A79", "#829B63", "#BC716E",
             "#6287A0", "#AA8A67", "#6EA5A0", "#8B91B8", "#BB865C", "#6F9B82",
             "#AE7992", "#879C62", "#6B8C9E", "#AD906D")
colors <- setNames(rep_len(palette, length(prepared$chromosomes)), prepared$chromosomes)
for (type in c("png", "pdf")) {
  file <- paste0("organ-loci-circos.", type)
  if (type == "png") {
    ragg::agg_png(file, width = 183, height = 183, units = "mm", res = 320, background = "white")
  } else {
    grDevices::quartz(type = "pdf", file = file, width = 183 / 25.4, height = 183 / 25.4, family = "Arial")
  }
  trace <- draw_organ_loci(prepared, bands, colors)
  invisible(dev.off())
}
write.csv(prepared$records, "organ-loci-records.csv", row.names = FALSE)
write.csv(trace$loci, "organ-loci-loci.csv", row.names = FALSE)
write.csv(trace$points, "organ-loci-points.csv", row.names = FALSE)
write.csv(trace$legend, "organ-loci-legend.csv", row.names = FALSE)
writeLines(capture.output(sessionInfo()), "sessionInfo.txt")
