options(stringsAsFactors = FALSE)
set.seed(20260915)

required <- c("circlize", "ragg", "systemfonts")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Missing packages: ", paste(missing, collapse = ", "))
font_match <- systemfonts::match_fonts("Arial")
font_info <- systemfonts::font_info(path=font_match$path[[1]])
if (!grepl("Arial", font_info$family[[1]], ignore.case=TRUE)) stop("Install Arial; font fallback is not accepted")

dir.create("results/figures", recursive = TRUE, showWarnings = FALSE)
dir.create("results/plot_data", recursive = TRUE, showWarnings = FALSE)

# New data contract: chromosome lengths -> selected segments -> signed features.
chromosomes <- data.frame(
  chr = sprintf("Chr%02d", 1:10), start = 0,
  end = c(118, 107, 96, 88, 81, 74, 67, 59, 52, 45) * 1e6
)

segment_rows <- list(); feature_rows <- list(); k <- 1L
for (i in seq_len(nrow(chromosomes))) {
  n_seg <- if (i <= 4) 4L else if (i <= 8) 3L else 2L
  anchors <- seq(8e6, chromosomes$end[i] - 8e6, length.out = n_seg)
  for (j in seq_len(n_seg)) {
    width <- sample(seq(2.2e6, 5.0e6, by = 0.2e6), 1)
    left <- round(max(1, anchors[j] - width / 2 + runif(1, -1.5e6, 1.5e6)))
    right <- round(min(chromosomes$end[i], left + width))
    id <- sprintf("S%02d", k)
    segment_rows[[k]] <- data.frame(segment = id, start = left, end = right, outer_chr = chromosomes$chr[i])
    n_feature <- sample(12:30, 1)
    pos <- sort(sample(seq(left + 1000, right - 1000), n_feature))
    centre <- (left + right) / 2
    effect <- pmax(-0.62, pmin(0.62, 0.38 * sin((pos - centre) / width * 2 * pi + i / 3) + rnorm(n_feature, 0, 0.12)))
    feature_rows[[k]] <- data.frame(segment = id, start = pos, end = pos + sample(120:900, n_feature, TRUE), effect = effect)
    k <- k + 1L
  }
}
segments <- do.call(rbind, segment_rows)
features <- do.call(rbind, feature_rows)
correspondence <- data.frame(
  chr = segments$outer_chr, start = segments$start, end = segments$end,
  segment = segments$segment, inner_start = segments$start, inner_end = segments$end
)

write.csv(chromosomes, "results/plot_data/independent_chromosomes.csv", row.names = FALSE)
write.csv(segments, "results/plot_data/independent_segments.csv", row.names = FALSE)
write.csv(features, "results/plot_data/independent_features.csv", row.names = FALSE)
write.csv(correspondence, "results/plot_data/independent_correspondence.csv", row.names = FALSE)

chr_cols <- setNames(hcl.colors(nrow(chromosomes), "BluYl", rev = TRUE), chromosomes$chr)
segment_cols <- unname(chr_cols[segments$outer_chr])

outer_layer <- function() {
  circlize::circos.par(start.degree = 90, gap.after = rep(2.4, nrow(chromosomes)), cell.padding = c(0, 0, 0, 0))
  circlize::circos.initialize(chromosomes$chr, xlim = chromosomes[, c("start", "end")])
  circlize::circos.trackPlotRegion(ylim = c(0, 1.55), track.height = 0.082, bg.border = NA,
    panel.fun = function(x, y) {
      sector <- circlize::CELL_META$sector.index
      lim <- circlize::CELL_META$xlim
      base_col <- chr_cols[sector]
      bins <- seq(lim[1], lim[2], length.out = 15)
      shades <- rep(c("#F5F5F5", "#BFC5C8", "#E3E5E6", "#8C9397"), length.out = length(bins) - 1)
      for (b in seq_len(length(bins) - 1)) {
        circlize::circos.rect(bins[b], 0.20, bins[b + 1], 0.82, col = shades[b], border = NA)
      }
      circlize::circos.rect(lim[1], 0.20, lim[2], 0.82, col = NA, border = "#242424", lwd = 0.7)
      # Small accent marks locate selected segments without adding labels.
      ss <- segments[segments$outer_chr == sector, ]
      if (nrow(ss)) for (z in seq_len(nrow(ss))) circlize::circos.rect(ss$start[z], 0.20, ss$end[z], 0.82, col = adjustcolor(base_col, 0.78), border = NA)
      circlize::circos.text(mean(lim), 1.24, sector, facing = "bending.outside", niceFacing = TRUE,
        cex = 0.68, family = "Arial", font = 2)
    })
}

inner_layer <- function() {
  inner <- segments[, c("segment", "start", "end")]
  circlize::circos.par(cell.padding = c(0, 0, 0, 0), gap.after = c(rep(0.85, nrow(inner) - 1), 9))
  circlize::circos.genomicInitialize(inner, plotType = NULL)
  circlize::circos.genomicTrack(features, ylim = c(-0.66, 0.66), track.height = 0.245,
    bg.col = adjustcolor(segment_cols, 0.14), bg.border = "#2E3336",
    panel.fun = function(region, value, ...) {
      for (yy in c(-0.6, -0.3, 0, 0.3, 0.6)) {
        circlize::circos.lines(circlize::CELL_META$cell.xlim, c(yy, yy), col = "#D2D5D7", lty = 3, lwd = 0.42)
      }
      cols <- ifelse(value[[1]] >= 0, "#C84B42", "#2F78A7")
      circlize::circos.genomicPoints(region, value, pch = 16, cex = 0.44, col = cols)
    })
  circlize::circos.track(ylim = c(0, 1), track.height = circlize::mm_h(1.8), bg.col = segment_cols, bg.border = "#202426")
}

out <- "results/figures/genome_distribution_independent.png"
ragg::agg_png(out, width = 165, height = 165, units = "mm", res = 300, background = "white")
par(family = "Arial", mar = c(0.35, 0.35, 0.35, 0.35))
circlize::circos.clear()
circlize::circos.nested(outer_layer, inner_layer, correspondence,
  connection_col = adjustcolor(chr_cols[correspondence$chr], 0.48))
circlize::circos.clear()
dev.off()
cat("INDEPENDENT_GENOME_DISTRIBUTION_PNG_OK\n")
