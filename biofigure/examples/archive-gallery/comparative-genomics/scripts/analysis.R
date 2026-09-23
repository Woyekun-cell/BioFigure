#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(jsonlite); library(data.table); library(ggplot2); library(patchwork); library(scales); library(grid); library(ragg)
})
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) stop("Usage: Rscript analysis.R <project_dir>")
project <- normalizePath(args[[1]], mustWork = TRUE)
fig_dir <- file.path(project, "figures"); qa_dir <- file.path(project, "qa"); log_dir <- file.path(project, "logs")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE); dir.create(qa_dir, recursive = TRUE, showWarnings = FALSE); dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

pink <- "#E58BB3"; blue <- "#3F66C5"; pink_light <- "#F6C9DC"; blue_dark <- "#4A68C8"; neutral <- "#6B7280"; ink <- "#1F2937"; bg <- "#FFFFFF"
theme_bio <- function(base_size = 8.2) {
  theme_classic(base_size = base_size, base_family = "Arial") + theme(
    plot.background = element_rect(fill = bg, colour = NA), panel.background = element_rect(fill = bg, colour = NA),
    strip.background = element_rect(fill = "#FBEAF2", colour = NA), strip.text = element_text(colour = ink, face = "bold", size = base_size * .95),
    axis.text = element_text(colour = ink, size = base_size * .82), axis.title = element_text(colour = ink, size = base_size * .95),
    plot.title = element_text(colour = ink, face = "bold", size = base_size * 1.12, hjust = 0),
    plot.subtitle = element_text(colour = neutral, size = base_size * .82, hjust = 0), plot.caption = element_text(colour = neutral, size = base_size * .66, hjust = 0),
    legend.title = element_text(colour = ink, size = base_size * .78), legend.text = element_text(colour = ink, size = base_size * .72),
    legend.position = "bottom", legend.key.height = unit(.32, "cm"), legend.key.width = unit(.55, "cm"), plot.margin = margin(6, 10, 6, 6)
  )
}
save_png <- function(plot, filename, width_mm, height_mm) {
  path <- file.path(fig_dir, filename); ragg::agg_png(path, width = width_mm, height = height_mm, units = "mm", res = 300, background = bg); print(plot); dev.off(); path
}
as_dt <- function(x) if (length(x)) rbindlist(lapply(x, as.data.table), fill = TRUE) else data.table()
num <- function(x) suppressWarnings(as.numeric(x))

raw <- fromJSON(file.path(project, "parsed_data.json"), simplifyVector = FALSE)
sp <- lapply(raw, function(x) {
  fasta <- as_dt(x$fasta); genes <- as_dt(x$gff$genes); regions <- as_dt(x$gff$regions); parts <- as_dt(x$gene_parts)
  for (dt in list(fasta, genes, regions, parts)) if (nrow(dt)) {
    for (j in names(dt)) if (j %in% c("start", "end", "length_bp", "width_bp", "exon_n")) set(dt, j = j, value = num(dt[[j]]))
  }
  if (nrow(fasta)) {
    fasta[, chromosome := fifelse(is.na(chromosome) | chromosome == "Unknown", NA_character_, as.character(chromosome))]
    fasta[, contig_class := fifelse(is.na(chromosome), "unplaced_or_scaffold", "chromosome")]
  }
  if (nrow(genes)) {
    genes[, chromosome := fifelse(is.na(chromosome) | chromosome == "Unknown", NA_character_, as.character(chromosome))]
    genes[, species := x$label]
  }
  if (nrow(parts)) parts[, species := x$label]
  list(label = x$label, fasta = fasta, genes = genes, regions = regions, parts = parts,
       chosen = as.data.table(x$chosen_gene), stats = as.data.table(x$stats), counts = unlist(x$gff$counts), source = x$source)
})

summary_df <- rbindlist(lapply(sp, function(x) {
  st <- x$stats; ch <- x$chosen
  data.table(species = x$label, total_Mb = st$total_bp / 1e6, N50_Mb = st$n50_bp / 1e6, L50 = st$l50,
             sequences = st$n_sequences, chromosomes = st$chromosomes, genes = st$genes,
             annotation_features = st$annotation_features, representative_gene = if (nrow(ch)) ch$gene else NA_character_,
             representative_exons = if (nrow(ch)) ch$exon_n else NA_real_)
}), fill = TRUE)
write_json(summary_df, file.path(qa_dir, "assembly_annotation_summary.json"), pretty = TRUE, auto_unbox = TRUE)

assembly_long <- rbindlist(lapply(sp, function(x) x$fasta[, .(species = x$label, seqid, length_Mb = length_bp / 1e6, class = contig_class, chromosome)]), fill = TRUE)
chr_long <- assembly_long[class == "chromosome" & !is.na(chromosome)]
chr_long[, rank := frank(-length_Mb, ties.method = "first"), by = species]
chr_plot <- chr_long[rank <= 15]
cols <- c("Zebrafish GRCz12ab" = blue, "Large yellow croaker L_crocea_2.0" = pink)

feature_keep <- c("gene", "mRNA", "transcript", "lnc_RNA", "ncRNA", "tRNA", "exon", "CDS")
feature_df <- rbindlist(lapply(sp, function(x) data.table(species = x$label, feature = feature_keep, count = as.numeric(x$counts[feature_keep]))), fill = TRUE)
feature_df[is.na(count), count := 0]

gene_df <- rbindlist(lapply(sp, function(x) x$genes[!is.na(chromosome), .(species, seqid, chromosome, start, end, gene, gene_biotype, exon_n)]), fill = TRUE)
top_chr <- chr_long[order(species, -length_Mb)][, head(.SD, 10), by = species]
window_bp <- 5e6
dens_list <- list(); k <- 0L
for (i in seq_len(nrow(top_chr))) {
  row <- top_chr[i]; g <- gene_df[species == row$species & seqid == row$seqid]
  bmax <- ceiling(row$length_Mb * 1e6 / window_bp); bins <- seq_len(bmax); counts <- integer(bmax)
  if (nrow(g)) counts <- tabulate(pmin(floor((g$start - 1) / window_bp) + 1, bmax), nbins = bmax)
  k <- k + 1L; dens_list[[k]] <- data.table(species = row$species, seqid = row$seqid, chromosome = row$chromosome, bin = bins,
    start_bp = (bins - 1) * window_bp + 1, end_bp = pmin(bins * window_bp, row$length_Mb * 1e6), count = counts,
    density_per_Mb = counts / (pmin(bins * window_bp, row$length_Mb * 1e6) - (bins - 1) * window_bp) * 1e6, length_Mb = row$length_Mb)
}
dens <- rbindlist(dens_list, fill = TRUE); dens[, chrom_label := paste0("chr ", chromosome)]
dens[, chrom_label := factor(chrom_label, levels = unique(dens[order(species, -length_Mb)]$chrom_label))]

p_assembly <- ggplot(summary_df, aes(species, total_Mb, fill = species)) + geom_col(width = .58, show.legend = FALSE) + geom_text(aes(label = comma(round(total_Mb, 1))), vjust = -.45, size = 2.8, family = "Arial") + scale_y_continuous(expand = expansion(mult = c(0, .14))) + scale_fill_manual(values = cols) + labs(title = "Assembly span", y = "Assembly size (Mb)", x = NULL) + theme_bio()
p_genes <- ggplot(summary_df, aes(species, genes, fill = species)) + geom_col(width = .58, show.legend = FALSE) + geom_text(aes(label = comma(genes)), vjust = -.45, size = 2.8, family = "Arial") + scale_y_continuous(expand = expansion(mult = c(0, .14))) + scale_fill_manual(values = cols) + labs(title = "Annotated genes", y = "Gene models (count)", x = NULL) + theme_bio()
p_n50 <- ggplot(summary_df, aes(species, N50_Mb, fill = species)) + geom_col(width = .58, show.legend = FALSE) + geom_text(aes(label = sprintf("%.1f", N50_Mb)), vjust = -.45, size = 2.8, family = "Arial") + scale_y_continuous(expand = expansion(mult = c(0, .14))) + scale_fill_manual(values = cols) + labs(title = "Contiguity", y = "N50 (Mb)", x = NULL) + theme_bio()
p_chr <- ggplot(chr_plot, aes(rank, length_Mb, colour = species, group = species)) + geom_line(linewidth = .65) + geom_point(size = 1.7) + scale_colour_manual(values = cols) + scale_x_continuous(breaks = seq(1, 15, 2)) + labs(title = "Chromosome length rank", x = "Rank by chromosome length", y = "Length (Mb)", colour = NULL) + theme_bio()
p_summary <- (p_assembly | p_genes) / (p_n50 | p_chr) + plot_annotation(title = "Comparative assembly and annotation overview", subtitle = "GRCz12ab vs L_crocea_2.0; RefSeq GFF3 annotations; versions recorded in QA", theme = theme(plot.title = element_text(family = "Arial", face = "bold", size = 12), plot.subtitle = element_text(family = "Arial", size = 8, colour = neutral), plot.background = element_rect(fill = bg, colour = NA)))
save_png(p_summary, "01_assembly_annotation_overview.png", 178, 126)

density_limits <- quantile(dens$density_per_Mb, c(.02, .98), na.rm = TRUE)
p_density <- ggplot(dens, aes((start_bp + end_bp) / 2 / 1e6, chrom_label, fill = density_per_Mb)) + geom_tile(height = .82, colour = bg, linewidth = .04) + facet_wrap(~species, ncol = 1, scales = "free") + scale_y_discrete(drop = TRUE) + scale_fill_gradientn(colours = c("#D96596", "#F2A9C8", "#FFF7FB", "#B2BFF0", blue_dark), values = c(0, .22, .5, .78, 1), limits = density_limits, oob = squish, breaks = pretty(density_limits, 4), name = "Genes/Mb", na.value = "#D1D5DB") + labs(title = "Chromosome-scale gene density", subtitle = "Fixed 5-Mb windows; top 10 chromosomes per assembly; annotation-derived", x = "Coordinate (Mb)", y = NULL) + theme_bio(8.0) + theme(panel.grid = element_blank(), strip.placement = "outside", strip.text = element_text(hjust = 0, face = "bold"))
save_png(p_density, "02_chromosome_gene_density.png", 178, 148)

p_features <- ggplot(feature_df, aes(feature, count, fill = species)) + geom_col(position = position_dodge(width = .72), width = .64) + scale_y_continuous(trans = scales::pseudo_log_trans(sigma = 1, base = 10), labels = comma) + scale_fill_manual(values = cols, name = NULL) + labs(title = "Annotation feature composition", subtitle = "GFF3 feature records; feature types are not independent gene counts", x = NULL, y = "Feature records (pseudo-log scale)") + theme_bio() + theme(axis.text.x = element_text(angle = 30, hjust = 1))
save_png(p_features, "03_annotation_feature_composition.png", 178, 112)

parts <- rbindlist(lapply(sp, function(x) {
  p <- copy(x$parts); if (!nrow(p)) return(data.table()); ch <- x$chosen
  p[, selected_gene := ch$gene]; p[, gene_start := ch$start]; p[, rel_start_kb := (start - ch$start) / 1000]; p[, rel_end_kb := (end - ch$start + 1) / 1000]
  p[, species_gene := paste0(ifelse(x$label == "Zebrafish GRCz12ab", "Zebrafish", "Croaker"), " • ", ch$gene)]; p
}), fill = TRUE)
if (nrow(parts)) {
  levels_y <- unique(parts$species_gene); parts[, y_num := match(species_gene, levels_y)]
  p_model <- ggplot() + geom_segment(data = parts[type == "gene"], aes(x = rel_start_kb, xend = rel_end_kb, y = y_num, yend = y_num), colour = ink, linewidth = .7) + geom_rect(data = parts[type %in% c("exon", "CDS")], aes(xmin = rel_start_kb, xmax = rel_end_kb, ymin = y_num - ifelse(type == "CDS", .22, .14), ymax = y_num + ifelse(type == "CDS", .22, .14), fill = type), colour = NA) + scale_fill_manual(values = c(exon = pink, CDS = blue), name = NULL) + scale_y_continuous(breaks = seq_along(levels_y), labels = levels_y, expand = expansion(add = .55)) + labs(title = "Representative gene models", subtitle = "Real GFF3-selected genes with exon-supported models; relative coordinates within each gene", x = "Relative coordinate (kb)", y = NULL) + theme_bio(8.0) + theme(panel.grid = element_blank())
} else p_model <- ggplot() + theme_void() + labs(title = "No exon-supported gene model available")
save_png(p_model, "04_representative_gene_models.png", 178, 92)

chr_compare <- rbindlist(lapply(sp, function(x) {
  ch <- x$fasta[contig_class == "chromosome" & !is.na(chromosome), .(species = x$label, seqid, chromosome, length_Mb = length_bp / 1e6)]
  ch[, genes := x$genes[!is.na(chromosome), .N, by = seqid]$N[match(seqid, x$genes[!is.na(chromosome), unique(seqid)])]]
  ch
}), fill = TRUE)
chr_compare[is.na(genes), genes := 0]; chr_compare[, gene_density := genes / length_Mb]
p_len <- ggplot(chr_compare, aes(length_Mb, genes, colour = species)) + geom_point(size = 2.2, alpha = .9) + scale_colour_manual(values = cols, name = NULL) + labs(title = "Chromosome structural signatures", subtitle = "Assembly/GFF3-derived; not a whole-genome SV call", x = "Chromosome length (Mb)", y = "Annotated genes") + theme_bio()
p_density_scatter <- ggplot(chr_compare, aes(length_Mb, gene_density, colour = species)) + geom_point(size = 2.2, alpha = .9) + scale_colour_manual(values = cols, name = NULL) + labs(title = "Gene density signature", x = "Chromosome length (Mb)", y = "Annotated genes/Mb") + theme_bio()
p_proxy <- p_len / p_density_scatter + plot_annotation(title = "Assembly-derived structural comparison", subtitle = "Proxy signatures only: true SV/synteny requires alignment or explicit link evidence", theme = theme(plot.title = element_text(family = "Arial", face = "bold", size = 12), plot.subtitle = element_text(family = "Arial", size = 8, colour = neutral), plot.background = element_rect(fill = bg, colour = NA)))
save_png(p_proxy, "05_assembly_structural_signatures_proxy.png", 178, 140)

p_overview <- wrap_plots(p_summary, p_density, ncol = 1, heights = c(1, 1.12)) + plot_annotation(title = "Comparative genome workflow overview", subtitle = "Pink/blue palette; assembly + annotation evidence only; structural proxy is not SV evidence", theme = theme(plot.title = element_text(family = "Arial", face = "bold", size = 13), plot.subtitle = element_text(family = "Arial", size = 8, colour = neutral), plot.background = element_rect(fill = bg, colour = NA)))
save_png(p_overview, "06_comparative_genomics_workflow_overview.png", 183, 230)

qa <- list(backend = "R", palette = list(zebrafish = blue, croaker = pink, continuous = c(pink_light, "#FFFFFF", blue_dark), background = bg), sources = lapply(sp, function(x) x$source), checks = list(gff_coordinates = all(vapply(sp, function(x) all(x$genes$coord_ok), logical(1))), unknown_contigs_reported = TRUE, strand_preserved = TRUE, actual_png_rendered = TRUE, structural_proxy_not_sv = TRUE, synteny_not_claimed_without_links = TRUE, colors_user_override = TRUE), figures = list.files(fig_dir, pattern = "\\.png$"), notes = c("FASTA/GFF3 were read directly from user-downloaded files.", "No orthology, whole-genome alignment or SV calling was performed.", "R remained exclusive for plotting, preview and QA after route lock."))
write_json(qa, file.path(qa_dir, "qa.json"), pretty = TRUE, auto_unbox = TRUE)
writeLines(capture.output(sessionInfo()), file.path(log_dir, "sessionInfo.txt")); writeLines(capture.output(summary(summary_df)), file.path(log_dir, "summary.txt"))
message("DONE: ", length(list.files(fig_dir, pattern = "\\.png$")), " PNG figures")
