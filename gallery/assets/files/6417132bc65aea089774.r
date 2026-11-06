suppressPackageStartupMessages({
  library(CMplot)
  library(ragg)
  library(systemfonts)
})

set.seed(20260917)

required <- c("CMplot", "ragg", "systemfonts")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Missing R packages: ", paste(missing, collapse = ", "))

font <- systemfonts::match_fonts("Arial")
font_info <- systemfonts::font_info(path = font$path[[1]])
if (!grepl("Arial", font_info$family[[1]], ignore.case = TRUE)) {
  stop("Arial resolution failed; font fallback is not accepted")
}

for (d in c("data/raw", "results/plot_data", "results/figures", "results/tables")) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

chromosome_lengths <- round(seq(126, 68, length.out = 12) * 1e6)
n_per_chromosome <- sample(620:820, 12, replace = TRUE)

variants <- do.call(rbind, lapply(seq_len(12), function(chromosome) {
  n <- n_per_chromosome[[chromosome]]
  data.frame(
    SNP = sprintf("sim_chr%02d_%05d", chromosome, seq_len(n)),
    Chromosome = chromosome,
    Position = sort(sample.int(chromosome_lengths[[chromosome]], n)),
    P = runif(n, min = 1e-6, max = 1)
  )
}))

# Inject five narrow association peaks. These P values are simulated solely to
# verify peak structure, thresholds, labels, and visual density.
peak_spec <- data.frame(
  Chromosome = c(2, 4, 7, 9, 11),
  Fraction = c(0.34, 0.71, 0.48, 0.78, 0.39),
  Strength = c(10.8, 8.9, 12.2, 9.6, 8.4)
)

lead_snps <- character(nrow(peak_spec))
for (i in seq_len(nrow(peak_spec))) {
  chr <- peak_spec$Chromosome[[i]]
  target <- chromosome_lengths[[chr]] * peak_spec$Fraction[[i]]
  candidates <- which(variants$Chromosome == chr)
  near <- candidates[order(abs(variants$Position[candidates] - target))[seq_len(13)]]
  distance_rank <- rank(abs(variants$Position[near] - target), ties.method = "first")
  signal <- peak_spec$Strength[[i]] - 0.32 * (distance_rank - 1) + rnorm(length(near), 0, 0.18)
  variants$P[near] <- 10^(-pmax(signal, 5.2))
  lead <- near[[which.min(variants$P[near])]]
  lead_snps[[i]] <- variants$SNP[[lead]]
}

variants <- variants[order(variants$Chromosome, variants$Position), ]
bonferroni <- 0.05 / nrow(variants)
chr_offsets <- c(0, cumsum(chromosome_lengths[-length(chromosome_lengths)]))
plot_data <- transform(
  variants,
  Cumulative_position = Position + chr_offsets[Chromosome],
  Minus_log10_P = -log10(P),
  Significant = P < bonferroni,
  Lead = SNP %in% lead_snps
)

write.csv(variants, "data/raw/simulated_gwas.csv", row.names = FALSE)
write.csv(plot_data, "results/plot_data/manhattan_simulated.csv", row.names = FALSE)
write.csv(
  merge(peak_spec, plot_data[plot_data$Lead, c("SNP", "Chromosome", "Position", "P")], by = "Chromosome"),
  "results/tables/injected_peaks.csv",
  row.names = FALSE
)

plot_input <- variants[, c("SNP", "Chromosome", "Position", "P")]

ragg::agg_png(
  "results/figures/manhattan_simulated.png",
  width = 180,
  height = 92,
  units = "mm",
  res = 300,
  background = "white"
)
par(family = font_info$family[[1]], xaxs = "i", yaxs = "i")
CMplot(
  plot_input,
  plot.type = "m",
  LOG10 = TRUE,
  col = c("#243B53", "#6B8EAD"),
  band = 0.65,
  pch = 16,
  cex = 0.52,
  points.alpha = 80,
  threshold = bonferroni,
  threshold.col = "#C23B33",
  threshold.lty = 1,
  threshold.lwd = 1.15,
  amplify = TRUE,
  signal.col = "#C23B33",
  signal.cex = 0.78,
  highlight = lead_snps[seq_len(3)],
  highlight.col = "#7A0019",
  highlight.cex = 1.15,
  highlight.pch = 21,
  highlight.text = paste0("Locus ", LETTERS[seq_len(3)]),
  highlight.text.col = "#52121A",
  highlight.text.cex = 0.72,
  highlight.text.font = 2,
  chr.labels = as.character(seq_len(12)),
  axis.cex = 0.82,
  axis.lwd = 0.9,
  lab.cex = 0.95,
  lab.font = 1,
  ylab = expression(-log[10](italic(P))),
  mar = c(3.1, 4.7, 1.2, 1),
  box = FALSE,
  file.output = FALSE,
  verbose = FALSE
)
usr <- par("usr")
text(
  usr[[1]] + 0.015 * diff(usr[1:2]), -log10(bonferroni) + 0.22,
  labels = sprintf("Bonferroni  P < %.2g", bonferroni),
  adj = c(0, 0), cex = 0.62, col = "#9A2E29",
  family = font_info$family[[1]]
)
dev.off()

writeLines(capture.output(sessionInfo()), "results/tables/sessionInfo.txt")
writeLines(
  c(
    "SIMULATED DATA: no biological association claim.",
    sprintf("Variants: %d", nrow(variants)),
    sprintf("Bonferroni threshold: %.10g", bonferroni),
    "P values are independently simulated with five injected local peaks."
  ),
  "results/tables/scope.txt"
)

cat("SIMULATED_MANHATTAN_PNG_OK\n")
