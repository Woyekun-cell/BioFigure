#!/usr/bin/env Rscript

# Independent structural reproduction of Shi et al. 2026 Extended Data Fig. 1a.
# Original collinearity coordinates were not released. Fixed-seed synthetic
# coordinates test the verified 11-genome x 19-chromosome visual grammar only.

suppressPackageStartupMessages({
  library(ggplot2)
  library(gggenomes)
  library(ggnewscale)
  library(dplyr)
})

args <- commandArgs(trailingOnly = TRUE)
case_dir <- normalizePath(if (length(args)) args[[1]] else ".", mustWork = TRUE)
preview <- "--preview" %in% args
skill_root <- normalizePath(file.path(case_dir, "..", "..", "..", "biofigure"), mustWork = TRUE)
source(file.path(skill_root, "scripts", "figure_style.R"))

fig_dir <- file.path(case_dir, "results", "figures")
data_dir <- file.path(case_dir, "results", "plot_data")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)

set.seed(20260927)
species <- c(
  "P. pseudoglauca", "P. wuana", "P. szechuanica", "P. yunnanensis",
  "P. koreana", "P. simonii", "P. lasiocarpa", "P. davidiana",
  "P. rotundifolia", "P. qiongdaoensis", "P. adenopoda"
)
species_code <- c("Ppse", "Pwua", "Psze", "Pyun", "Pkor", "Psim", "Plas", "Pdav", "Prot", "Pqio", "Pade")
chromosomes <- sprintf("Chr%02d", 1:19)

# Comparable chromosome lengths maintain shared coordinate scale. Values are
# synthetic and intentionally excluded from biological interpretation.
base_lengths <- round(runif(19, 16, 44) * 1e6)
seqs <- do.call(rbind, lapply(seq_along(species), function(i) {
  len <- round(base_lengths * runif(19, .94, 1.06))
  data.frame(
    bin_id = factor(species[i], levels = rev(species)),
    species = species[i], species_code = species_code[i],
    seq_id = paste(species_code[i], chromosomes, sep = "_"),
    chr = chromosomes, start = 0, end = len, length = len,
    clade = ifelse(i <= 7, "Clade I", "Clade II"), stringsAsFactors = FALSE
  )
}))

links <- list(); k <- 0L
add_link <- function(i, chr1, chr2, f1, f2, type, duplicate_index = 1L) {
  len1 <- seqs$length[seqs$species_code == species_code[i] & seqs$chr == chromosomes[chr1]]
  len2 <- seqs$length[seqs$species_code == species_code[i + 1] & seqs$chr == chromosomes[chr2]]
  width1 <- .15 * len1; width2 <- .15 * len2
  start1 <- max(0, min(len1 - width1, f1 * len1))
  start2 <- max(0, min(len2 - width2, f2 * len2))
  if (type == "Inversion") {
    target_start <- start2 + width2; target_end <- start2
  } else {
    target_start <- start2; target_end <- start2 + width2
  }
  k <<- k + 1L
  links[[k]] <<- data.frame(
    link_id = sprintf("L%04d", k), pair_index = i,
    seq_id = paste(species_code[i], chromosomes[chr1], sep = "_"),
    start = start1, end = start1 + width1,
    seq_id2 = paste(species_code[i + 1], chromosomes[chr2], sep = "_"),
    start2 = target_start, end2 = target_end,
    type = type, duplicate_index = duplicate_index, stringsAsFactors = FALSE
  )
}

for (i in 1:10) for (chr in 1:19) {
  jitter <- runif(3, -.035, .035)
  for (b in 1:3) add_link(i, chr, chr, c(.08, .40, .72)[b], c(.08, .40, .72)[b] + jitter[b], "Syntenic")
}
events <- data.frame(
  pair = c(1,2,3,3,4,5,5,6,7,7,8,8,9,9,10,10),
  chr1 = c(2,7,3,14,5,8,16,11,4,17,6,12,9,18,1,15),
  chr2 = c(2,7,3,14,6,8,16,11,4,18,6,12,10,18,1,16),
  f1 = c(.22,.56,.18,.64,.30,.74,.26,.48,.35,.70,.18,.63,.28,.73,.40,.54),
  f2 = c(.62,.20,.70,.26,.42,.20,.68,.16,.75,.26,.60,.22,.52,.30,.18,.66),
  type = c("Inversion","Inversion","Translocation","Inversion","Translocation","Inversion","Duplication","Translocation","Inversion","Translocation","Duplication","Inversion","Translocation","Duplication","Inversion","Translocation"),
  stringsAsFactors = FALSE
)
for (j in seq_len(nrow(events))) {
  e <- events[j, ]
  add_link(e$pair, e$chr1, e$chr2, e$f1, e$f2, e$type)
  if (e$type == "Duplication") add_link(e$pair, e$chr1, max(1, min(19, e$chr2 + 1)), e$f1, min(.82, e$f2 + .16), e$type, 2L)
}
links <- do.call(rbind, links)
links$type <- factor(links$type, levels = c("Syntenic", "Inversion", "Translocation", "Duplication"))

relation_colors <- c(Syntenic = "#D9D9D9", Inversion = "#F4A72C", Translocation = "#86BF3E", Duplication = "#32A9C5")
species_colors <- c("#5A3C88", "#6D5597", "#7F70A4", "#928AAF", "#A5A4BA", "#8CB9C4", "#70A9BA", "#5B96AC", "#407F9D", "#2A6D8C", "#1B5878")
names(species_colors) <- species

genome_layout <- gggenomes(seqs = seqs, links = links, .id = "bin_id", spacing = .075, adjacent_only = TRUE)
top_species <- species[[1]]
label_data <- genome_layout$data$seqs$seqs |>
  dplyr::filter(.data$species == top_species) |>
  dplyr::mutate(label_x = (x + xend) / 2, label_y = y)

p <- genome_layout +
  geom_link(aes(fill = type), color = NA, alpha = .76, offset = .10) +
  scale_fill_manual(
    values = relation_colors, breaks = names(relation_colors),
    limits = names(relation_colors), drop = FALSE, name = NULL
  ) +
  geom_seq(aes(color = species), linewidth = 1.85, lineend = "round") +
  scale_color_manual(values = species_colors, guide = "none") +
  geom_text(
    data = label_data,
    aes(x = label_x, y = label_y, label = ifelse(chr == "Chr01", "Chr01", sub("Chr", "", chr))),
    inherit.aes = FALSE, nudge_y = .23, hjust = .5, vjust = .5,
    size = 1.80, family = "Arial", fontface = "bold"
  ) +
  geom_bin_label(
    aes(label = bin_id), hjust = 0, nudge_left = -1.02, expand_left = .13,
    size = 2.05, family = "Arial", fontface = "italic"
  ) +
  coord_cartesian(clip = "off") +
  theme_void(base_family = "Arial") +
  theme(
    text = element_text(family = "Arial", color = "black"),
    legend.position = "bottom", legend.direction = "horizontal",
    legend.text = element_text(size = 5.5),
    legend.key.width = grid::unit(4.3, "mm"), legend.key.height = grid::unit(2.2, "mm"),
    legend.spacing.x = grid::unit(1.2, "mm"),
    plot.margin = margin(6, 23, 1, 16, unit = "mm"),
    plot.background = element_rect(fill = "white", color = NA),
    panel.background = element_rect(fill = "white", color = NA)
  ) +
  guides(fill = guide_legend(nrow = 1, byrow = TRUE, override.aes = list(alpha = 1)))

# Add a compact cladogram in the reserved left margin using the gggenomes bin y scale.
layout_built <- ggplot_build(p)
y_by_species <- setNames(seq_along(rev(species)), rev(species))
xmin_data <- min(vapply(layout_built$data, function(d) if ("xmin" %in% names(d)) min(d$xmin, na.rm = TRUE) else Inf, numeric(1)), na.rm = TRUE)
span <- max(vapply(layout_built$data, function(d) if ("xmax" %in% names(d)) max(d$xmax, na.rm = TRUE) else -Inf, numeric(1)), na.rm = TRUE) - xmin_data
tree_x <- xmin_data - span * c(.095, .075, .058, .041, .024)

tree_segments <- data.frame()
add_seg <- function(x, xend, y, yend, clade) {
  tree_segments <<- rbind(tree_segments, data.frame(x = x, xend = xend, y = y, yend = yend, clade = clade))
}
tips <- y_by_species[species]
# Ladder topology approximating the published order; geometry only.
for (i in seq_along(tips)) add_seg(tree_x[5], xmin_data - span*.004, tips[i], tips[i], ifelse(i <= 7,"Clade I","Clade II"))
groups <- list(c(1,2), c(3,4), c(8,9), c(10,11))
for (g in groups) {
  yy <- tips[g]; cl <- ifelse(g[1] <= 7,"Clade I","Clade II")
  add_seg(tree_x[4], tree_x[5], mean(yy), mean(yy), cl); add_seg(tree_x[5], tree_x[5], min(yy), max(yy), cl)
}
node_y <- c(mean(tips[1:2]), mean(tips[3:4]), tips[5], tips[6], tips[7], mean(tips[8:9]), mean(tips[10:11]))
node_cl <- c(rep("Clade I",5),rep("Clade II",2))
for (i in seq_along(node_y)) add_seg(tree_x[3], tree_x[4], node_y[i], node_y[i], node_cl[i])
add_seg(tree_x[3], tree_x[3], min(node_y[1:5]), max(node_y[1:5]), "Clade I")
add_seg(tree_x[3], tree_x[3], min(node_y[6:7]), max(node_y[6:7]), "Clade II")
add_seg(tree_x[2], tree_x[3], mean(node_y[1:5]), mean(node_y[1:5]), "Clade I")
add_seg(tree_x[2], tree_x[3], mean(node_y[6:7]), mean(node_y[6:7]), "Clade II")
add_seg(tree_x[2], tree_x[2], mean(node_y[1:5]), mean(node_y[6:7]), "Clade I")

p <- p +
  ggnewscale::new_scale_color() +
  geom_segment(data = tree_segments, aes(x = x, xend = xend, y = y, yend = yend, color = clade), inherit.aes = FALSE, linewidth = .42) +
  scale_color_manual(values = c("Clade I" = "#2D6AA6", "Clade II" = "#9EC9DD"), guide = "none") +
  annotate("text", x = tree_x[1], y = mean(tips[1:7]), label = "Clade I", family = "Arial", fontface = "bold", size = 1.9, color = "#2D6AA6", hjust = 1) +
  annotate("text", x = tree_x[1], y = mean(tips[8:11]), label = "Clade II", family = "Arial", fontface = "bold", size = 1.9, color = "#9EC9DD", hjust = 1) +
  annotate("text", x = tree_x[1], y = max(tips) + .52, label = "a", family = "Arial", fontface = "bold", size = 3.0, color = "black", hjust = 1)

write.csv(seqs, file.path(data_dir, "populus_synteny_sequences.csv"), row.names = FALSE)
write.csv(links, file.path(data_dir, "populus_synteny_links.csv"), row.names = FALSE)

png_path <- file.path(fig_dir, "populus_whole_genome_synteny.png")
pdf_path <- file.path(fig_dir, "populus_whole_genome_synteny.pdf")
svg_path <- file.path(fig_dir, "populus_whole_genome_synteny.svg")

if (preview) {
  ggsave(png_path, p, width = 183, height = 82, units = "mm", dpi = 300, bg = "white", device = ragg::agg_png)
} else {
  font <- bf_font("Arial")
  boxes <- data.frame(
    id = c("data", "labels", "legend"),
    x = c(16, 0, 62), y = c(7, 0, 0), w = c(165, 16, 59), h = c(73, 80, 7)
  )
  sources <- c(
    file.path(case_dir, "design-spec.yaml"),
    file.path(case_dir, "render_populus_synteny.R"),
    file.path(skill_root, "scripts", "figure_style.R"),
    file.path(case_dir, "reference-panel-a.png"),
    file.path(case_dir, "provenance", "article-page.html"),
    file.path(case_dir, "provenance", "author-repo-README.md"),
    file.path(case_dir, "provenance", "source-data-gap.json")
  )
  allowed_text <- c(
    "a", "Clade I", "Clade II", "Syntenic", "Inversion", "Translocation", "Duplication",
    "Chr01", sprintf("%02d", 2:19), chromosomes, species
  )
  bf_render_png(
    p, png_path, font, allowed_text, 183, 82, 183,
    source_files = sources, boxes = boxes, dpi = 300,
    heading_authorization = "Panel letter and chromosome headers are source-required.",
    min_text_pt = 5, text_size_authorization = "Dense 11 x 19 genome map at 183 mm; 5 pt minimum retained.",
    authorization = file.path(case_dir, "render-authorization.json"), skill_root = skill_root,
    publication_size_class = "double-column"
  )
  ggsave(svg_path, p, width = 183/25.4, height = 82/25.4, device = svglite::svglite, bg = "white")
  if (!requireNamespace("rsvg", quietly = TRUE)) stop("rsvg is required for vector PDF export")
  rsvg::rsvg_pdf(svg_path, pdf_path)
}

cat(sprintf("RENDER_OK preview=%s seqs=%d links=%d png=%s\n", preview, nrow(seqs), nrow(links), png_path))
