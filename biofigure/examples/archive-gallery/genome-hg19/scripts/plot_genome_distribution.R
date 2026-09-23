options(stringsAsFactors = FALSE)

required <- c("circlize", "ragg", "systemfonts")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Missing packages: ", paste(missing, collapse = ", "))

font_file <- "/System/Library/Fonts/Supplemental/Arial.ttf"
resolved <- systemfonts::match_fonts("Arial")$path[[1]]
if (!file.exists(font_file) || normalizePath(resolved) != normalizePath(font_file)) stop("Arial did not resolve to Arial.ttf")

dir.create("results/figures", recursive = TRUE, showWarnings = FALSE)
dir.create("results/plot_data", recursive = TRUE, showWarnings = FALSE)
dir.create("results/tables", recursive = TRUE, showWarnings = FALSE)

# circlize package-maintained example coordinates: intervals and signed feature values.
load(system.file(package = "circlize", "extdata", "tagments_WGBS_DMR.RData", mustWork = TRUE))
write.csv(tagments, "results/plot_data/genomic_segments_hg19.csv", row.names = FALSE)
write.csv(DMR1, "results/plot_data/genomic_feature_distribution.csv", row.names = FALSE)
write.csv(correspondance, "results/plot_data/segment_correspondence.csv", row.names = FALSE)

chromosomes <- paste0("chr", 1:22)
chr_cols <- setNames(hcl.colors(22, "Dark 3", alpha = 0.86), chromosomes)

outer_genome <- function() {
  circlize::circos.par(start.degree = 90, gap.after = rep(1.6, 22))
  circlize::circos.initializeWithIdeogram(
    species = "hg19", chromosome.index = chromosomes,
    plotType = c("ideogram", "labels"), ideogram.height = 0.025,
    labels.cex = 0.72
  )
}

inner_segments <- function() {
  circlize::circos.par(cell.padding = c(0, 0, 0, 0), gap.after = c(rep(0.7, nrow(tagments) - 1), 8))
  circlize::circos.genomicInitialize(tagments, plotType = NULL)
  circlize::circos.genomicTrack(
    DMR1, ylim = c(-0.65, 0.65), track.height = 0.23,
    bg.col = adjustcolor(chr_cols[tagments$chr], 0.18), bg.border = "#333333",
    panel.fun = function(region, value, ...) {
      for (yy in c(-0.6, -0.3, 0, 0.3, 0.6)) {
        circlize::circos.lines(circlize::CELL_META$cell.xlim, c(yy, yy), col = "#D4D7D9", lty = 3, lwd = 0.45)
      }
      circlize::circos.genomicPoints(region, value, pch = 16, cex = 0.38,
        col = ifelse(value[[1]] > 0, "#C83E3A", "#347AA9"))
    }
  )
  circlize::circos.track(ylim = c(0, 1), track.height = circlize::mm_h(1.6),
    bg.col = chr_cols[tagments$chr], bg.border = "#222222")
}

out <- "results/figures/genome_distribution_circos.png"
ragg::agg_png(out, width = 165, height = 165, units = "mm", res = 300, background = "white")
par(family = "Arial", mar = c(0.3, 0.3, 0.3, 0.3))
circlize::circos.clear()
circlize::circos.nested(outer_genome, inner_segments, correspondance,
  connection_col = adjustcolor(chr_cols[correspondance[[1]]], 0.55))
circlize::circos.clear()
dev.off()

writeLines(capture.output(sessionInfo()), "results/tables/sessionInfo.txt")
cat("NESTED_GENOME_DISTRIBUTION_PNG_OK\n")
