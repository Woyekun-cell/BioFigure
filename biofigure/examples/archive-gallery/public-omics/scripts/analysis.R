#!/usr/bin/env Rscript

## BioFigure end-to-end lightweight rendering demo.
## Input data are processed fixtures; this script does not run FASTQ/BAM workflows.

suppressPackageStartupMessages({
  library(Matrix)
  library(data.table)
  library(ggplot2)
  library(patchwork)
  library(uwot)
  library(irlba)
  library(Biostrings)
  library(ragg)
})

options(stringsAsFactors = FALSE, width = 120)
set.seed(20260903)

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_path <- if (length(file_arg)) normalizePath(sub("^--file=", "", file_arg[1])) else normalizePath("analysis.R")
out_root <- dirname(script_path)
fig_dir <- file.path(out_root, "figures")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

data_root <- Sys.getenv("BIOFIGURE_FIXTURE_ROOT")
if (!nzchar(data_root) || !dir.exists(data_root)) stop("Set BIOFIGURE_FIXTURE_ROOT to the public fixture directory")
scrna_root <- file.path(data_root, "01_单细胞RNA_10x_PBMC1k")
atac_root <- file.path(data_root, "02_ATAC-seq_ENCODE_K562")
chip_root <- file.path(data_root, "03_ChIP-seq_ENCODE_K562_H3K27ac")
zfish_root <- file.path(data_root, "04_斑马鱼_参考基因组_GRCz12ab")
croaker_root <- file.path(data_root, "05_大黄鱼_参考基因组_L_crocea_2.0")

pink_blue <- c("#F8D7E8", "#F2A6C9", "#DCCBFF", "#A6C8FF", "#4169E1")
pink_blue_div <- c("#F2A6C9", "#FFFFFF", "#86B6FF")
font_family <- "Arial"

theme_pub <- function(base_size = 8.5) {
  theme_classic(base_size = base_size, base_family = font_family) %+replace%
    theme(
      plot.background = element_rect(fill = "#FFFFFF", colour = NA),
      panel.background = element_rect(fill = "#FFFFFF", colour = NA),
      panel.grid = element_blank(),
      axis.line = element_line(linewidth = 0.3, colour = "#1A1A1A"),
      axis.ticks = element_line(linewidth = 0.3, colour = "#1A1A1A"),
      axis.text = element_text(colour = "#1A1A1A", size = 7.5),
      axis.title = element_text(colour = "#1A1A1A", size = 8.5),
      legend.background = element_blank(),
      legend.key = element_blank(),
      legend.title = element_text(size = 7.5),
      legend.text = element_text(size = 7),
      strip.background = element_rect(fill = "#F8D7E8", colour = NA),
      strip.text = element_text(size = 7.5, face = "bold"),
      plot.margin = margin(5.5, 7, 5.5, 5.5)
    )
}

save_png <- function(plot_obj, name, width_mm = 183, height_mm = 120, dpi = 300) {
  path <- file.path(fig_dir, paste0(name, ".png"))
  ragg::agg_png(path, width = width_mm / 25.4, height = height_mm / 25.4,
                units = "in", res = dpi, background = "white")
  print(plot_obj)
  dev.off()
  message(sprintf("PNG %s %.1f KB", basename(path), file.info(path)$size / 1024))
  invisible(path)
}

read_lines_gz <- function(path) {
  con <- gzfile(path, open = "rt")
  on.exit(close(con), add = TRUE)
  readLines(con, warn = FALSE)
}

read_gff <- function(path) {
  data.table::fread(path, sep = "\t", header = FALSE, fill = TRUE, comment.char = "#",
                    col.names = paste0("V", 1:9), showProgress = FALSE)
}

attr_value <- function(x, key) {
  hit <- regexec(paste0("(?:^|;)", key, "=([^;]+)"), x, perl = TRUE)
  m <- regmatches(x, hit)
  vapply(m, function(z) if (length(z) >= 2) z[2] else NA_character_, character(1))
}

## ------------------------ single-cell RNA ------------------------
message("[1/5] single-cell RNA")
matrix_dir <- file.path(scrna_root, "filtered_feature_bc_matrix")
mtx_con <- gzfile(file.path(matrix_dir, "matrix.mtx.gz"), "rt")
counts <- suppressWarnings(Matrix::readMM(mtx_con))
close(mtx_con)
counts <- as(counts, "CsparseMatrix")
features <- data.table::fread(file.path(matrix_dir, "features.tsv.gz"), header = FALSE,
                              sep = "\t", showProgress = FALSE)
barcodes <- read_lines_gz(file.path(matrix_dir, "barcodes.tsv.gz"))
feature_id <- as.character(features[[1]])
feature_name <- as.character(features[[2]])
feature_name[is.na(feature_name) | feature_name == ""] <- feature_id[is.na(feature_name) | feature_name == ""]
rownames(counts) <- feature_id
colnames(counts) <- barcodes

cell_counts <- Matrix::colSums(counts)
detected <- Matrix::colSums(counts > 0)
mt_idx <- grepl("^(MT-|mt-)", feature_name)
mt_counts <- if (any(mt_idx)) Matrix::colSums(counts[mt_idx, , drop = FALSE]) else rep(0, ncol(counts))
qc <- data.frame(
  cell = barcodes,
  total_counts = as.numeric(cell_counts),
  detected_features = as.numeric(detected),
  mito_percent = as.numeric(mt_counts / pmax(cell_counts, 1) * 100)
)
qc$qc_class <- ifelse(qc$detected_features >= 200 & qc$total_counts >= 500 & qc$mito_percent <= 20, "pass", "review")
qc$qc_class <- factor(qc$qc_class, levels = c("pass", "review"))
keep <- qc$qc_class == "pass"
if (sum(keep) < 100) keep[] <- TRUE
message(sprintf("scRNA matrix %d features x %d cells; QC pass %d/%d", nrow(counts), ncol(counts), sum(keep), nrow(qc)))

qc_long <- rbind(
  data.frame(metric = "Total counts", value = qc$total_counts, class = qc$qc_class),
  data.frame(metric = "Detected features", value = qc$detected_features, class = qc$qc_class),
  data.frame(metric = "Mitochondrial %", value = qc$mito_percent, class = qc$qc_class)
)
p_qc <- ggplot(qc_long, aes(x = class, y = value, fill = class, group = class)) +
  geom_violin(trim = TRUE, scale = "width", colour = "#26324A", linewidth = 0.2) +
  geom_boxplot(width = 0.12, outlier.shape = NA, colour = "#26324A", fill = "#FFFFFF", linewidth = 0.25) +
  scale_fill_manual(values = c(pass = "#F2A6C9", review = "#4169E1"), guide = "none") +
  facet_wrap(~metric, scales = "free_y", nrow = 1) +
  labs(x = NULL, y = "Observed value") + theme_pub() +
  theme(axis.text.x = element_text(angle = 0, hjust = 0.5), strip.placement = "outside")
save_png(p_qc, "01_scrna_qc", 183, 82)

lib_factor <- cell_counts / median(cell_counts)
norm_counts <- Matrix::t(Matrix::t(counts) / lib_factor) * 10000
log_norm <- log1p(norm_counts)
gene_mean <- Matrix::rowMeans(log_norm)
gene_var <- Matrix::rowMeans(log_norm^2) - gene_mean^2
hvg_candidates <- which(!mt_idx & is.finite(gene_var))
hvg_candidates <- hvg_candidates[order(gene_var[hvg_candidates], decreasing = TRUE)]
hvg <- head(hvg_candidates, min(1000, length(hvg_candidates)))
message(sprintf("HVG %d; normalization log1p(CP10K)", length(hvg)))

hv_df <- data.frame(mean = gene_mean[hvg_candidates], variance = gene_var[hvg_candidates], hvg = FALSE)
hv_df$hvg[seq_len(length(hvg))] <- TRUE
p_hvg <- ggplot(hv_df, aes(x = mean, y = variance, colour = hvg)) +
  geom_point(alpha = 0.28, size = 0.45) +
  scale_colour_manual(values = c(`FALSE` = "#B6BDD7", `TRUE` = "#E67DB0"),
                      labels = c(`FALSE` = "Other genes", `TRUE` = "Top HVG")) +
  labs(x = "Mean log-normalized expression", y = "Variance", colour = NULL) + theme_pub()
save_png(p_hvg, "02_scrna_hvg", 120, 100)

## Use all cell-called barcodes for the embedding; QC class remains visible in the QC figure.
x <- as.matrix(log_norm[hvg, , drop = FALSE])
x <- t(scale(t(x)))
x[!is.finite(x)] <- 0
x <- t(x)
pc_fit <- irlba::prcomp_irlba(x, n = 20, center = FALSE, scale. = FALSE)
pc <- as.data.frame(pc_fit$x)
colnames(pc) <- paste0("PC", seq_len(ncol(pc)))
pc$cell <- barcodes
pc$cluster <- factor(kmeans(pc[, paste0("PC", 1:15)], centers = 8, nstart = 20)$cluster)
set.seed(20260903)
umap_xy <- uwot::umap(pc[, paste0("PC", 1:15)], n_neighbors = 30, min_dist = 0.3,
                      metric = "cosine", n_threads = 2, verbose = FALSE)
umap_df <- data.frame(UMAP1 = umap_xy[, 1], UMAP2 = umap_xy[, 2], cell = barcodes,
                      cluster = pc$cluster, qc_class = qc$qc_class)
cluster_cols <- setNames(colorRampPalette(pink_blue)(nlevels(umap_df$cluster)), levels(umap_df$cluster))
var_pct <- (pc_fit$sdev^2 / sum(pc_fit$sdev^2)) * 100
pc_plot <- ggplot(pc, aes(PC1, PC2, colour = cluster)) +
  geom_point(size = 0.65, alpha = 0.72) +
  scale_colour_manual(values = cluster_cols) +
  labs(x = sprintf("PC1 (%.1f%%)", var_pct[1]), y = sprintf("PC2 (%.1f%%)", var_pct[2]), colour = "Cluster") +
  theme_pub()
save_png(pc_plot, "03_scrna_pca", 150, 120)

umap_plot <- ggplot(umap_df, aes(UMAP1, UMAP2, colour = cluster)) +
  geom_point(size = 0.7, alpha = 0.75) +
  scale_colour_manual(values = cluster_cols) +
  labs(x = "UMAP 1", y = "UMAP 2", colour = "Cluster") + theme_pub() +
  theme(axis.text = element_blank(), axis.ticks = element_blank())
save_png(umap_plot, "04_scrna_umap", 150, 120)

cluster_mean <- sapply(levels(umap_df$cluster), function(cl) {
  cluster_cells <- umap_df$cluster == cl
  Matrix::rowMeans(log_norm[, cluster_cells, drop = FALSE])
})
if (is.vector(cluster_mean)) cluster_mean <- matrix(cluster_mean, ncol = 1)
rownames(cluster_mean) <- feature_name
candidate_markers <- unique(unlist(lapply(seq_len(ncol(cluster_mean)), function(j) {
  others <- if (ncol(cluster_mean) > 1) rowMeans(cluster_mean[, -j, drop = FALSE]) else cluster_mean[, j]
  score <- cluster_mean[, j] - others
  names(sort(score, decreasing = TRUE))[seq_len(min(5, length(score)))]
})))
candidate_markers <- head(candidate_markers, 30)
marker_mat <- cluster_mean[candidate_markers, , drop = FALSE]
marker_long <- reshape2::melt(marker_mat, varnames = c("gene", "cluster"), value.name = "expression")
marker_long$gene <- factor(marker_long$gene, levels = rev(candidate_markers))
p_marker <- ggplot(marker_long, aes(x = cluster, y = gene, fill = expression)) +
  geom_tile(colour = "#FFFFFF", linewidth = 0.2) +
  scale_fill_gradientn(colours = pink_blue, name = "Mean\nlog-expression") +
  labs(x = "Cluster", y = "Candidate marker") + theme_pub() +
  theme(axis.text.y = element_text(size = 6), axis.text.x = element_text(angle = 0, hjust = 0.5))
save_png(p_marker, "05_scrna_candidate_marker_heatmap", 183, 135)

## ------------------------ ATAC-seq ------------------------
message("[2/5] ATAC-seq")
atac_path <- file.path(atac_root, "ENCFF117MSK_IDR_thresholded_peaks_GRCh38.bed.gz")
atac <- data.table::fread(atac_path, sep = "\t", header = FALSE, showProgress = FALSE)
setnames(atac, paste0("V", 1:10), c("chrom", "start", "end", "name", "score", "strand", "signal", "pvalue", "qvalue", "summit"))
atac[, width := end - start]
atac[, chrom_order := factor(chrom, levels = c(paste0("chr", 1:22), "chrX", "chrY", "chrM"))]
atac[, rank_signal := frank(-signal, ties.method = "first")]
atac_chrom <- atac[, .(peaks = .N), by = chrom_order][!is.na(chrom_order)]
atac_chrom <- atac_chrom[order(chrom_order)]
p_atac_width <- ggplot(atac, aes(x = log10(width))) +
  geom_histogram(bins = 55, fill = "#C7CEFF", colour = "#FFFFFF", linewidth = 0.12) +
  labs(x = "Peak width (log10 bp)", y = "Peak count") + theme_pub()
p_atac_signal <- ggplot(atac, aes(x = signal, group = 1)) +
  geom_density(fill = "#F2A6C9", alpha = 0.8, colour = "#4169E1", linewidth = 0.25) +
  labs(x = "ATAC signal value", y = "Density") + theme_pub()
p_atac_chr <- ggplot(atac_chrom, aes(x = chrom_order, y = peaks, fill = peaks)) +
  geom_col(colour = "#FFFFFF", linewidth = 0.18) +
  scale_fill_gradientn(colours = pink_blue, guide = "none") +
  labs(x = "Chromosome", y = "Peaks") + theme_pub() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
save_png(p_atac_width + p_atac_signal + p_atac_chr + plot_layout(ncol = 3), "06_atac_peak_landscape", 183, 78)

top_atac <- atac[order(rank_signal)][seq_len(min(120, .N))]
p_atac_rank <- ggplot(top_atac, aes(x = rank_signal, y = signal, colour = signal)) +
  geom_line(linewidth = 0.35, colour = "#A6B7EE") +
  geom_point(size = 1.2) +
  scale_colour_gradientn(colours = pink_blue) +
  labs(x = "Rank by signal", y = "Signal value", colour = "Signal") + theme_pub()
save_png(p_atac_rank, "07_atac_top_peak_rank", 150, 110)

atac_map <- atac[sample(.N, min(.N, 15000))]
p_atac_map <- ggplot(atac_map, aes(x = start / 1e6, y = chrom_order, colour = signal)) +
  geom_point(alpha = 0.38, size = 0.45) +
  scale_colour_gradientn(colours = pink_blue) +
  labs(x = "Peak midpoint proxy (Mb within chromosome)", y = NULL, colour = "Signal") + theme_pub()
save_png(p_atac_map, "08_atac_chromosome_peak_map", 183, 135)

## ------------------------ ChIP-seq ------------------------
message("[3/5] ChIP-seq")
chip_path <- file.path(chip_root, "ENCFF038DDS_replicated_peaks_GRCh38.bed.gz")
chip <- data.table::fread(chip_path, sep = "\t", header = FALSE, showProgress = FALSE)
setnames(chip, paste0("V", 1:10), c("chrom", "start", "end", "name", "score", "strand", "signal", "pvalue", "qvalue", "summit"))
chip[, width := end - start]
chip[, chrom_order := factor(chrom, levels = c(paste0("chr", 1:22), "chrX", "chrY", "chrM"))]
chip[, rank_signal := frank(-signal, ties.method = "first")]
chip_chrom <- chip[, .(peaks = .N), by = chrom_order][!is.na(chrom_order)]
chip_chrom <- chip_chrom[order(chrom_order)]
p_chip_width <- ggplot(chip, aes(x = log10(width))) +
  geom_histogram(bins = 55, fill = "#C7CEFF", colour = "#FFFFFF", linewidth = 0.12) +
  labs(x = "Peak width (log10 bp)", y = "Peak count") + theme_pub()
p_chip_signal <- ggplot(chip, aes(x = signal, group = 1)) +
  geom_density(fill = "#F2A6C9", alpha = 0.8, colour = "#4169E1", linewidth = 0.25) +
  labs(x = "H3K27ac signal value", y = "Density") + theme_pub()
p_chip_chr <- ggplot(chip_chrom, aes(x = chrom_order, y = peaks, fill = peaks)) +
  geom_col(colour = "#FFFFFF", linewidth = 0.18) +
  scale_fill_gradientn(colours = pink_blue, guide = "none") +
  labs(x = "Chromosome", y = "Peaks") + theme_pub() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
save_png(p_chip_width + p_chip_signal + p_chip_chr + plot_layout(ncol = 3), "09_chip_peak_landscape", 183, 78)

top_chip <- chip[order(rank_signal)][seq_len(min(120, .N))]
p_chip_rank <- ggplot(top_chip, aes(x = rank_signal, y = signal, colour = signal)) +
  geom_line(linewidth = 0.35, colour = "#A6B7EE") +
  geom_point(size = 1.2) +
  scale_colour_gradientn(colours = pink_blue) +
  labs(x = "Rank by signal", y = "H3K27ac signal value", colour = "Signal") + theme_pub()
save_png(p_chip_rank, "10_chip_top_peak_rank", 150, 110)

chip_map <- chip[sample(.N, min(.N, 15000))]
p_chip_map <- ggplot(chip_map, aes(x = start / 1e6, y = chrom_order, colour = signal)) +
  geom_point(alpha = 0.38, size = 0.45) +
  scale_colour_gradientn(colours = pink_blue) +
  labs(x = "Peak midpoint proxy (Mb within chromosome)", y = NULL, colour = "Signal") + theme_pub()
save_png(p_chip_map, "11_chip_chromosome_peak_map", 183, 135)

## ------------------------ assembly and annotation ------------------------
message("[4/5] genomes and GFF3")
read_assembly <- function(label, root, fasta_name, gff_name) {
  fasta_path <- file.path(root, fasta_name)
  gff_path <- file.path(root, gff_name)
  dna <- Biostrings::readDNAStringSet(fasta_path)
  ids <- sub("\\s.*$", "", names(dna))
  freq <- Biostrings::letterFrequency(dna, letters = c("A", "C", "G", "T", "N"))
  denom <- rowSums(freq[, c("A", "C", "G", "T"), drop = FALSE])
  seq_stats <- data.frame(seqid = ids, length_bp = as.numeric(width(dna)),
                          gc_percent = as.numeric((freq[, "G"] + freq[, "C"]) / pmax(denom, 1) * 100),
                          n_percent = as.numeric(freq[, "N"] / pmax(width(dna), 1) * 100))
  rm(dna, freq)
  invisible(gc())
  gff <- read_gff(gff_path)
  setnames(gff, paste0("V", 1:9), c("seqid", "source", "type", "start", "end", "score", "strand", "phase", "attributes"))
  gff[, width_bp := end - start + 1L]
  gene <- gff[type == "gene", .(seqid, start, end, width_bp, strand)]
  feature_counts <- gff[, .(features = .N), by = type][order(-features)]
  gene_counts <- gene[, .(genes = .N), by = seqid]
  regions <- gff[type == "region", .(seqid, attributes)]
  regions[, chromosome := attr_value(attributes, "chromosome")]
  regions[, is_chromosome := !is.na(chromosome)]
  seq_stats <- data.table::as.data.table(merge(seq_stats, gene_counts, by = "seqid", all.x = TRUE))
  seq_stats[is.na(genes), genes := 0L]
  seq_stats[, gene_density := genes / (length_bp / 1e6)]
  seq_stats <- data.table::as.data.table(merge(seq_stats, regions[, .(seqid, chromosome, is_chromosome)], by = "seqid", all.x = TRUE))
  seq_stats[is.na(is_chromosome), is_chromosome := FALSE]
  list(label = label, seq_stats = seq_stats, feature_counts = feature_counts, gene = gene, gff = gff)
}

zfish <- read_assembly("Zebrafish GRCz12ab", zfish_root,
                       "GCF_052040795.1_GRCz12ab_genomic.fna.gz",
                       "GCF_052040795.1_GRCz12ab_genomic.gff3.gz")
croaker <- read_assembly("Large yellow croaker L_crocea_2.0", croaker_root,
                         "GCF_000972845.2_L_crocea_2.0_genomic.fna.gz",
                         "GCF_000972845.2_L_crocea_2.0_genomic.gff3.gz")

assembly_plot <- function(obj, prefix) {
  s <- as.data.table(obj$seq_stats)
  s <- s[order(-length_bp)]
  top <- s[seq_len(min(30, .N))]
  top$seqid <- factor(top$seqid, levels = rev(top$seqid))
  p_len <- ggplot(top, aes(x = length_bp / 1e6, y = seqid, fill = length_bp)) +
    geom_col(colour = "#FFFFFF", linewidth = 0.18) +
    scale_fill_gradientn(colours = pink_blue, guide = "none") +
    labs(x = "Sequence length (Mb)", y = NULL) + theme_pub() +
    theme(axis.text.y = element_text(size = 6))
  p_gc <- ggplot(s, aes(x = length_bp / 1e6, y = gc_percent, colour = gc_percent, size = log10(length_bp))) +
    geom_point(alpha = 0.85) + scale_colour_gradientn(colours = pink_blue) +
    scale_size_continuous(range = c(1.4, 4), guide = "none") +
    labs(x = "Sequence length (Mb)", y = "GC (%)", colour = "GC (%)") + theme_pub()
  struct <- s[order(-length_bp)][seq_len(min(100, .N))]
  p_struct <- ggplot(struct, aes(x = reorder(seqid, gene_density), y = gene_density, fill = n_percent)) +
    geom_col(colour = "#FFFFFF", linewidth = 0.12) +
    scale_fill_gradientn(colours = pink_blue, name = "N (%)") +
    labs(x = "Top assembly sequences (ordered)", y = "Genes / Mb") + theme_pub() +
    theme(axis.text.x = element_blank(), axis.ticks.x = element_blank())
  save_png(p_len + p_gc + p_struct + plot_layout(ncol = 3), paste0(prefix, "_assembly"), 183, 105)

  fc <- as.data.table(obj$feature_counts)[seq_len(min(14, nrow(obj$feature_counts)))]
  fc$type <- factor(fc$type, levels = rev(fc$type))
  p_fc <- ggplot(fc, aes(x = features, y = type, fill = features)) +
    geom_col(colour = "#FFFFFF", linewidth = 0.15) + scale_fill_gradientn(colours = pink_blue, guide = "none") +
    labs(x = "Annotated features", y = NULL) + theme_pub() + theme(axis.text.y = element_text(size = 6))
  gene <- as.data.table(obj$gene)
  p_gene <- ggplot(gene[sample(.N, min(.N, 10000))], aes(x = log10(width_bp))) +
    geom_histogram(bins = 55, fill = "#F2A6C9", colour = "#FFFFFF", linewidth = 0.12) +
    labs(x = "Gene span (log10 bp)", y = "Genes") + theme_pub()
  dens <- as.data.table(obj$seq_stats)[order(-gene_density)][seq_len(min(.N, 30))]
  dens$seqid <- factor(dens$seqid, levels = rev(dens$seqid))
  p_dens <- ggplot(dens, aes(x = gene_density, y = seqid, fill = gene_density)) +
    geom_col(colour = "#FFFFFF", linewidth = 0.15) + scale_fill_gradientn(colours = pink_blue, guide = "none") +
    labs(x = "Genes / Mb", y = NULL) + theme_pub() + theme(axis.text.y = element_text(size = 6))
  save_png(p_fc + p_gene + p_dens + plot_layout(ncol = 3), paste0(prefix, "_gff_features"), 183, 105)

  ## This is an assembly structural-signature/SV-proxy figure, not a validated SV call set.
  proxy <- as.data.table(obj$seq_stats)
  proxy[, class := ifelse(is_chromosome, "Chromosome-like", "Unplaced/scaffold-like")]
  p_proxy <- ggplot(proxy, aes(x = gene_density, y = n_percent, colour = length_bp, shape = class)) +
    geom_point(alpha = 0.8, size = 2.4) + scale_colour_gradientn(colours = pink_blue, name = "Length (bp)") +
    labs(x = "Gene density (genes / Mb)", y = "N-content (%)", shape = NULL) + theme_pub()
  proxy_bar <- proxy[order(-length_bp)][seq_len(min(100, .N))]
  p_unplaced <- ggplot(proxy_bar, aes(x = reorder(seqid, length_bp), y = length_bp / 1e6, fill = n_percent)) +
    geom_col(colour = "#FFFFFF", linewidth = 0.12) + scale_fill_gradientn(colours = pink_blue, name = "N (%)") +
    labs(x = "Top assembly sequences (ordered)", y = "Length (Mb)") + theme_pub() +
    theme(axis.text.x = element_blank(), axis.ticks.x = element_blank())
  save_png(p_proxy + p_unplaced + plot_layout(ncol = 2), paste0(prefix, "_assembly_structural_signatures_SV_proxy"), 183, 100)
}

assembly_plot(zfish, "12_zebrafish")
assembly_plot(croaker, "15_croaker")

## Comparative summary across the two assemblies.
summary_df <- data.frame(
  species = c("Zebrafish\nGRCz12ab", "Large yellow croaker\nL_crocea_2.0"),
  total_mb = c(sum(zfish$seq_stats$length_bp), sum(croaker$seq_stats$length_bp)) / 1e6,
  sequences = c(nrow(zfish$seq_stats), nrow(croaker$seq_stats)),
  genes = c(nrow(zfish$gene), nrow(croaker$gene))
)
summary_long <- reshape2::melt(summary_df, id.vars = "species", variable.name = "metric", value.name = "value")
summary_long$metric <- factor(summary_long$metric, levels = c("total_mb", "sequences", "genes"),
                              labels = c("Assembly size (Mb)", "FASTA sequences", "GFF3 genes"))
p_summary <- ggplot(summary_long, aes(x = species, y = value, fill = value)) +
  geom_col(width = 0.68, colour = "#FFFFFF", linewidth = 0.25) +
  geom_text(aes(label = format(round(value, 0), big.mark = ",")), vjust = -0.35, size = 2.7, family = font_family) +
  scale_fill_gradientn(colours = pink_blue, guide = "none") +
  facet_wrap(~metric, scales = "free_y", nrow = 1) +
  labs(x = NULL, y = "Observed value") + theme_pub() +
  theme(axis.text.x = element_text(size = 7), strip.placement = "outside")
save_png(p_summary, "18_comparative_assembly_summary", 183, 92)

message(sprintf("Done: %d PNG files in %s", length(list.files(fig_dir, pattern = "\\.png$")), fig_dir))
message("Boundary: SV proxy panels show assembly gaps/unplaced-sequence signatures; no validated SV calls are inferred from single assemblies.")
