#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args)) args[[1]] else "docs/assets/gallery"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
options(warn = 2)

required <- c("ggplot2", "ggrepel", "patchwork", "circlize", "grid", "ragg", "systemfonts", "scales")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Missing R packages: ", paste(missing, collapse = ", "))

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_file <- normalizePath(sub("^--file=", "", script_arg[[1]]))
skill_root <- normalizePath(file.path(dirname(script_file), "..", ".."))
source(file.path(skill_root, "scripts", "figure_style.R"))
font <- bf_font("Arial")
font_family <- font$family

COL <- c(navy = "#315B7D", blue = "#73A1BE", teal = "#4F8F8A", ochre = "#C59A45",
         coral = "#C56F61", plum = "#81739C", sage = "#9BAF88", grey = "#B7BAB8")

theme_bf <- function(size = 8) {
  ggplot2::theme_classic(base_family = font_family, base_size = size) +
    ggplot2::theme(
      text = ggplot2::element_text(family = font_family, colour = "#202020"),
      axis.title = ggplot2::element_text(size = size + 0.5),
      axis.text = ggplot2::element_text(size = size - 0.5),
      axis.line = ggplot2::element_line(linewidth = 0.35, colour = "#202020"),
      axis.ticks = ggplot2::element_line(linewidth = 0.3, colour = "#202020"),
      panel.background = ggplot2::element_rect(fill = "white", colour = NA),
      plot.background = ggplot2::element_rect(fill = "white", colour = NA),
      legend.background = ggplot2::element_rect(fill = "white", colour = NA),
      legend.key = ggplot2::element_rect(fill = "white", colour = NA),
      legend.position = "right",
      legend.title = ggplot2::element_text(size = size - 0.5),
      legend.text = ggplot2::element_text(size = size - 1),
      legend.key.height = grid::unit(3.5, "mm"),
      plot.margin = ggplot2::margin(5, 6, 5, 5, unit = "mm")
    )
}

save_plot <- function(plot, filename, width_mm = 112, height_mm = 88) {
  path <- file.path(out_dir, filename)
  ragg::agg_png(path, width = width_mm, height = height_mm, units = "mm",
                res = 300, background = "white", scaling = 1)
  print(plot)
  grDevices::dev.off()
  invisible(path)
}

ellipse_data <- function(data, group_col, x_col, y_col, level = 0.90) {
  pieces <- lapply(split(data, data[[group_col]]), function(d) {
    center <- colMeans(d[c(x_col, y_col)])
    eig <- eigen(stats::cov(d[c(x_col, y_col)]), symmetric = TRUE)
    theta <- seq(0, 2 * pi, length.out = 121)
    circle <- rbind(cos(theta), sin(theta)) * sqrt(stats::qchisq(level, df = 2))
    xy <- t(center + eig$vectors %*% diag(sqrt(pmax(eig$values, 0))) %*% circle)
    data.frame(x = xy[, 1], y = xy[, 2], group = d[[group_col]][1])
  })
  do.call(rbind, pieces)
}

# Metabolomics: PCA with sample-level points and restrained 90% covariance ellipses.
set.seed(20260920)
met_groups <- c("Control", "Heat", "Hypoxia", "Recovery")
centers <- matrix(c(-2.0, 0.2, 1.2, 1.6, 1.6, -1.4, -0.4, -0.7), ncol = 2, byrow = TRUE)
met <- do.call(rbind, lapply(seq_along(met_groups), function(i) {
  data.frame(group = met_groups[[i]], replicate = sprintf("%s-%02d", substr(met_groups[[i]], 1, 1), 1:8),
             PC1 = rnorm(8, centers[i, 1], 0.42), PC2 = rnorm(8, centers[i, 2], 0.36))
}))
met$group <- factor(met$group, levels = met_groups)
met_ellipse <- ellipse_data(met, "group", "PC1", "PC2")
p_pca <- ggplot2::ggplot(met, ggplot2::aes(PC1, PC2)) +
  ggplot2::geom_path(data = met_ellipse, ggplot2::aes(x, y, colour = group), linewidth = 0.55) +
  ggplot2::geom_point(ggplot2::aes(fill = group), shape = 21, colour = "#202020", stroke = 0.25, size = 2.4) +
  ggplot2::scale_colour_manual(values = unname(COL[c("navy", "coral", "plum", "teal")]), guide = "none") +
  ggplot2::scale_fill_manual(values = unname(COL[c("navy", "coral", "plum", "teal")]), name = "Group") +
  ggplot2::labs(x = "PC1 (34.8%)", y = "PC2 (18.6%)") + theme_bf()
save_plot(p_pca, "domain-metabolomics-pca.png")

# Multi-omics: paired sample factor association.
set.seed(20260921)
n_pair <- 42
multi <- data.frame(group = rep(c("Control", "Stress", "Recovery"), each = 14),
                    rna = rnorm(n_pair))
multi$group <- factor(multi$group, levels = c("Control", "Stress", "Recovery"))
multi$metabolite <- 0.72 * multi$rna + rep(c(-0.18, 0.28, 0.05), each = 14) + rnorm(n_pair, sd = 0.48)
fit <- stats::lm(metabolite ~ rna, data = multi)
r_value <- stats::cor(multi$rna, multi$metabolite)
p_multi <- ggplot2::ggplot(multi, ggplot2::aes(rna, metabolite)) +
  ggplot2::geom_smooth(method = "lm", formula = y ~ x, se = TRUE, colour = "#555555",
                       fill = "#D9D9D9", linewidth = 0.55) +
  ggplot2::geom_point(ggplot2::aes(fill = group), shape = 21, colour = "#202020", stroke = 0.22, size = 2.3) +
  ggplot2::annotate("text", x = min(multi$rna), y = max(multi$metabolite), hjust = 0, vjust = 1,
                    label = sprintf("Pearson r = %.2f", r_value), family = font_family, size = 2.6) +
  ggplot2::scale_fill_manual(values = unname(COL[c("navy", "coral", "teal")]), name = "Group") +
  ggplot2::labs(x = "RNA factor score", y = "Metabolite factor score") + theme_bf()
save_plot(p_multi, "domain-multiomics-association.png")

# Single-cell: simulated UMAP embedding with an external legend.
set.seed(20260922)
cell_types <- c("Progenitor", "Myeloid", "B cell", "T cell", "Endothelial", "Stromal")
umap_centers <- matrix(c(-2.1, 1.5, -2.0, -0.9, -0.2, 0.3, 0.8, 1.8, 2.1, -0.6, 0.8, -1.8), ncol = 2, byrow = TRUE)
umap <- do.call(rbind, lapply(seq_along(cell_types), function(i) {
  angle <- runif(380, 0, 2 * pi); radius <- sqrt(runif(380))
  data.frame(cell_type = cell_types[[i]],
             UMAP1 = umap_centers[i, 1] + 0.72 * radius * cos(angle) + rnorm(380, 0, 0.09),
             UMAP2 = umap_centers[i, 2] + 0.52 * radius * sin(angle) + rnorm(380, 0, 0.09))
}))
umap$cell_type <- factor(umap$cell_type, levels = cell_types)
p_umap <- ggplot2::ggplot(umap, ggplot2::aes(UMAP1, UMAP2, colour = cell_type)) +
  ggplot2::geom_point(size = 0.55, alpha = 0.72) +
  ggplot2::scale_colour_manual(values = unname(COL[c("navy", "coral", "ochre", "teal", "plum", "sage")]), name = "Cell type") +
  ggplot2::labs(x = "UMAP1", y = "UMAP2") + ggplot2::coord_equal() + theme_bf() +
  ggplot2::theme(axis.text = ggplot2::element_blank(), axis.ticks = ggplot2::element_blank())
save_plot(p_umap, "domain-single-cell-umap.png", 112, 90)

# Spatial transcriptomics: hexagonal spots over a simulated tissue footprint.
spatial <- expand.grid(x = seq(-4.8, 4.8, by = 0.32), y = seq(-3.8, 3.8, by = 0.28))
spatial$x <- spatial$x + ifelse(round((spatial$y + 3.8) / 0.28) %% 2, 0.16, 0)
spatial <- spatial[(spatial$x / 4.8)^2 + (spatial$y / 3.7)^2 < 1 & !((spatial$x + 1.6)^2 + (spatial$y - 0.3)^2 < 0.45), ]
set.seed(20260923)
spatial$expression <- 1.7 * exp(-((spatial$x - 1.5)^2 + (spatial$y + 0.5)^2) / 2.2) +
  0.9 * exp(-((spatial$x + 2.0)^2 + (spatial$y - 1.6)^2) / 1.4) + runif(nrow(spatial), 0, 0.12)
p_spatial <- ggplot2::ggplot(spatial, ggplot2::aes(x, y, fill = expression)) +
  ggplot2::geom_point(shape = 21, colour = "white", stroke = 0.12, size = 2.6) +
  ggplot2::scale_fill_gradientn(colours = c("#F3F1ED", "#8EB7C9", "#315B7D", "#6A406D"), name = "Expression") +
  ggplot2::labs(x = "Spatial x (a.u.)", y = "Spatial y (a.u.)") + ggplot2::coord_equal() + theme_bf()
save_plot(p_spatial, "domain-spatial-expression.png", 108, 88)

# Chromatin: sample-aware aggregate signal profile around a reference point.
set.seed(20260924)
positions <- seq(-2000, 2000, by = 50)
profile_raw <- do.call(rbind, lapply(c("Control", "Stress"), function(g) {
  do.call(rbind, lapply(1:5, function(rep) {
    peak <- if (g == "Stress") 1.35 else 0.92
    data.frame(group = g, replicate = rep, position = positions,
               signal = 0.16 + peak * exp(-(positions / 620)^2) + rnorm(length(positions), 0, 0.045))
  }))
}))
profile <- do.call(rbind, lapply(split(profile_raw, list(profile_raw$group, profile_raw$position)), function(d) {
  data.frame(group = d$group[1], position = d$position[1], mean = mean(d$signal),
             se = stats::sd(d$signal) / sqrt(length(unique(d$replicate))))
}))
profile$group <- factor(profile$group, levels = c("Control", "Stress"))
p_profile <- ggplot2::ggplot(profile, ggplot2::aes(position, mean, colour = group, fill = group)) +
  ggplot2::geom_ribbon(ggplot2::aes(ymin = mean - 1.96 * se, ymax = mean + 1.96 * se),
                       linewidth = 0, alpha = 0.16) +
  ggplot2::geom_line(linewidth = 0.75) +
  ggplot2::geom_vline(xintercept = 0, linewidth = 0.3, linetype = 2, colour = "#777777") +
  ggplot2::scale_colour_manual(values = unname(COL[c("navy", "coral")]), name = "Group") +
  ggplot2::scale_fill_manual(values = unname(COL[c("navy", "coral")]), name = "Group") +
  ggplot2::scale_x_continuous(breaks = c(-2000, 0, 2000), labels = c("−2 kb", "TSS", "+2 kb")) +
  ggplot2::labs(x = NULL, y = "Normalized accessibility") + theme_bf()
save_plot(p_profile, "domain-chromatin-profile.png")

# Chromatin: dense region-by-position signal heatmap without decorative cell borders.
set.seed(20260925)
bins <- seq(-1500, 1500, length.out = 61)
regions <- 1:120
peak_width <- runif(length(regions), 260, 780)
peak_height <- sort(runif(length(regions), 0.25, 1.8), decreasing = TRUE)
chrom_heat <- expand.grid(region = regions, position = bins)
chrom_heat$signal <- peak_height[chrom_heat$region] * exp(-(chrom_heat$position / peak_width[chrom_heat$region])^2) +
  runif(nrow(chrom_heat), 0, 0.06)
p_chrom_heat <- ggplot2::ggplot(chrom_heat, ggplot2::aes(position, region, fill = signal)) +
  ggplot2::geom_raster() +
  ggplot2::scale_fill_gradientn(colours = c("#F7F4EF", "#9BB9C9", "#315B7D", "#1D2E46"), name = "Signal") +
  ggplot2::scale_x_continuous(breaks = c(-1500, 0, 1500), labels = c("−1.5 kb", "Peak", "+1.5 kb")) +
  ggplot2::labs(x = NULL, y = "Regions ordered by signal") + theme_bf() +
  ggplot2::theme(axis.text.y = ggplot2::element_blank(), axis.ticks.y = ggplot2::element_blank())
save_plot(p_chrom_heat, "domain-chromatin-heatmap.png", 106, 90)

# Genome variation: circular chromosomes and simulated SV links.
set.seed(20260926)
chr <- paste0("Chr", 1:8)
chr_len <- c(92, 87, 83, 76, 71, 65, 58, 52)
sv <- data.frame(
  from_chr = sample(chr, 28, replace = TRUE), from = runif(28, 5, 48),
  to_chr = sample(chr, 28, replace = TRUE), to = runif(28, 5, 48),
  type = sample(c("Deletion", "Duplication", "Inversion"), 28, replace = TRUE)
)
for (i in seq_len(nrow(sv))) {
  sv$from[i] <- min(sv$from[i], chr_len[match(sv$from_chr[i], chr)] - 4)
  sv$to[i] <- min(sv$to[i], chr_len[match(sv$to_chr[i], chr)] - 4)
}
sv_cols <- c(Deletion = COL[["navy"]], Duplication = COL[["coral"]], Inversion = COL[["plum"]])
ragg::agg_png(file.path(out_dir, "domain-structural-variation.png"), width = 112, height = 104,
              units = "mm", res = 300, background = "white")
graphics::par(family = font_family, mar = c(1, 1, 1, 6), xpd = NA)
circlize::circos.clear()
circlize::circos.par(start.degree = 90, gap.degree = 5, track.margin = c(0.004, 0.004),
                     cell.padding = c(0, 0, 0, 0), canvas.xlim = c(-1.15, 1.55))
circlize::circos.initialize(factors = chr, xlim = cbind(rep(0, length(chr)), chr_len))
circlize::circos.trackPlotRegion(ylim = c(0, 1.45), track.height = 0.13, bg.border = NA,
  panel.fun = function(x, y) {
    sector <- circlize::CELL_META$sector.index
    circlize::circos.rect(circlize::CELL_META$xlim[1], 0.18, circlize::CELL_META$xlim[2], 0.82,
                          col = ifelse(match(sector, chr) %% 2, "#D8E3E8", "#C8D5DB"), border = "white", lwd = 0.4)
    circlize::circos.text(mean(circlize::CELL_META$xlim), 1.18, sector, facing = "bending.inside",
                          niceFacing = TRUE, cex = 0.55, family = font_family)
  })
for (i in seq_len(nrow(sv))) {
  circlize::circos.link(sv$from_chr[i], c(sv$from[i], sv$from[i] + 2),
                        sv$to_chr[i], c(sv$to[i], sv$to[i] + 2),
                        col = scales::alpha(sv_cols[sv$type[i]], 0.30), border = NA)
}
graphics::legend(1.02, 0.45, legend = names(sv_cols), fill = sv_cols, border = NA,
                 bty = "n", cex = 0.72, title = "SV type", text.font = 1)
circlize::circos.clear()
grDevices::dev.off()

# Comparative genomics: aligned chromosomes and syntenic blocks.
set.seed(20260927)
genomes <- c("Species A", "Species B", "Species C")
block_cols <- COL[c("navy", "teal", "ochre", "coral", "plum", "sage")]
blocks <- do.call(rbind, lapply(seq_along(genomes), function(g) {
  starts <- cumsum(c(2, sample(8:13, 7, replace = TRUE)))
  data.frame(genome = genomes[g], y = 4 - g, block = paste0("B", 1:8),
             xmin = starts, xmax = starts + sample(5:9, 8, replace = TRUE), order = if (g == 1) 1:8 else sample(1:8))
}))
blocks <- blocks[order(blocks$genome, blocks$order), ]
blocks$plot_xmin <- ave(blocks$xmax - blocks$xmin, blocks$genome, FUN = function(w) cumsum(c(2, head(w + 2, -1))))
blocks$plot_xmax <- blocks$plot_xmin + (blocks$xmax - blocks$xmin)
links <- list(); link_id <- 0
for (g in 1:2) for (b in paste0("B", 1:8)) {
  a <- blocks[blocks$genome == genomes[g] & blocks$block == b, ]
  z <- blocks[blocks$genome == genomes[g + 1] & blocks$block == b, ]
  link_id <- link_id + 1
  links[[link_id]] <- data.frame(id = link_id, block = b,
    x = c(a$plot_xmin, a$plot_xmax, z$plot_xmax, z$plot_xmin),
    y = c(a$y - 0.13, a$y - 0.13, z$y + 0.13, z$y + 0.13))
}
links <- do.call(rbind, links)
p_synteny <- ggplot2::ggplot() +
  ggplot2::geom_polygon(data = links, ggplot2::aes(x, y, group = id, fill = block), alpha = 0.14, colour = NA) +
  ggplot2::geom_rect(data = blocks, ggplot2::aes(xmin = plot_xmin, xmax = plot_xmax, ymin = y - 0.13, ymax = y + 0.13, fill = block),
                     colour = "white", linewidth = 0.25) +
  ggplot2::scale_fill_manual(values = unname(rep(block_cols, length.out = 8)), guide = "none") +
  ggplot2::scale_y_continuous(breaks = 3:1, labels = genomes, limits = c(0.55, 3.45)) +
  ggplot2::labs(x = "Relative genomic position", y = NULL) + theme_bf() +
  ggplot2::theme(axis.line.y = ggplot2::element_blank(), axis.ticks.y = ggplot2::element_blank(),
                 axis.text.y = ggplot2::element_text(size = 8), panel.grid = ggplot2::element_blank())
save_plot(p_synteny, "domain-synteny.png", 122, 76)

# Imaging assay: simulated two-condition fluorescence plate with explicit scale bars.
make_channel <- function(condition, channel, seed) {
  set.seed(seed)
  x <- 1:72; y <- 1:72; grid <- expand.grid(x = x, y = y)
  nuclei <- matrix(0, 72, 72); marker <- matrix(0, 72, 72)
  for (i in 1:18) {
    cx <- runif(1, 8, 64); cy <- runif(1, 8, 64); amp <- runif(1, 0.65, 1)
    nuclei <- nuclei + amp * outer(x, y, function(a, b) exp(-((a - cx)^2 + (b - cy)^2) / 10))
    marker_amp <- if (condition == "Stress") runif(1, 0.65, 1.0) else runif(1, 0.15, 0.45)
    marker <- marker + marker_amp * outer(x, y, function(a, b) exp(-((a - cx)^2 + (b - cy)^2) / 34))
  }
  nuclei <- pmin(nuclei / max(nuclei), 1); marker <- pmin(marker / max(marker), 1)
  if (channel == "Nuclei") rgb <- grDevices::rgb(0.05 * nuclei, 0.18 * nuclei, 0.95 * nuclei)
  else rgb <- grDevices::rgb(pmin(0.90 * marker + 0.05 * nuclei, 1), 0.12 * nuclei, pmin(0.78 * marker + 0.90 * nuclei, 1))
  transform(grid, condition = condition, channel = channel, colour = as.vector(rgb))
}
img <- do.call(rbind, list(make_channel("Control", "Nuclei", 11), make_channel("Stress", "Nuclei", 12),
                           make_channel("Control", "Marker overlay", 11), make_channel("Stress", "Marker overlay", 12)))
img$condition <- factor(img$condition, levels = c("Control", "Stress"))
img$channel <- factor(img$channel, levels = c("Nuclei", "Marker overlay"))
bars <- data.frame(condition = c("Control", "Stress"), channel = "Marker overlay",
                   x = 51, xend = 66, y = 7, yend = 7)
p_image <- ggplot2::ggplot(img, ggplot2::aes(x, y, fill = colour)) +
  ggplot2::geom_raster() + ggplot2::scale_fill_identity() +
  ggplot2::geom_segment(data = bars, ggplot2::aes(x = x, xend = xend, y = y, yend = yend),
                        inherit.aes = FALSE, colour = "white", linewidth = 1.2, lineend = "butt") +
  ggplot2::facet_grid(channel ~ condition) + ggplot2::coord_equal(expand = FALSE) +
  ggplot2::theme_void(base_family = font_family, base_size = 8) +
  ggplot2::theme(plot.background = ggplot2::element_rect(fill = "white", colour = NA),
                 panel.spacing = grid::unit(1.2, "mm"),
                 strip.text = ggplot2::element_text(family = font_family, size = 8, colour = "#202020"),
                 plot.margin = ggplot2::margin(5, 5, 5, 5, "mm"))
save_plot(p_image, "domain-imaging-assay.png", 112, 96)

# Machine learning: ROC discrimination and calibration shown together.
set.seed(20260928)
truth <- rbinom(360, 1, 0.43)
score <- stats::plogis(-0.7 + 1.65 * truth + rnorm(360, 0, 1.0))
thresholds <- seq(1, 0, length.out = 201)
roc <- do.call(rbind, lapply(thresholds, function(t) {
  pred <- score >= t
  data.frame(FPR = sum(pred & truth == 0) / sum(truth == 0), TPR = sum(pred & truth == 1) / sum(truth == 1))
}))
cal <- data.frame(score = score, truth = truth, bin = cut(score, breaks = seq(0, 1, 0.1), include.lowest = TRUE))
cal <- do.call(rbind, lapply(split(cal, cal$bin), function(d) data.frame(predicted = mean(d$score), observed = mean(d$truth), n = nrow(d))))
p_roc <- ggplot2::ggplot(roc, ggplot2::aes(FPR, TPR)) +
  ggplot2::geom_abline(slope = 1, intercept = 0, linewidth = 0.35, linetype = 2, colour = "#9A9A9A") +
  ggplot2::geom_line(linewidth = 0.8, colour = COL[["navy"]]) +
  ggplot2::labs(x = "False-positive rate", y = "True-positive rate") + ggplot2::coord_equal() + theme_bf()
p_cal <- ggplot2::ggplot(cal, ggplot2::aes(predicted, observed)) +
  ggplot2::geom_abline(slope = 1, intercept = 0, linewidth = 0.35, linetype = 2, colour = "#9A9A9A") +
  ggplot2::geom_line(linewidth = 0.65, colour = COL[["coral"]]) +
  ggplot2::geom_point(ggplot2::aes(size = n), shape = 21, fill = COL[["coral"]], colour = "#202020", stroke = 0.22) +
  ggplot2::scale_size_area(name = "Bin n", max_size = 4) +
  ggplot2::labs(x = "Mean predicted probability", y = "Observed frequency") +
  ggplot2::coord_equal(xlim = c(0, 1), ylim = c(0, 1)) + theme_bf()
p_ml <- p_roc + p_cal + patchwork::plot_annotation(tag_levels = "A", theme = ggplot2::theme(plot.tag = ggplot2::element_text(family = font_family, face = "bold", size = 9)))
save_plot(p_ml, "domain-ml-evaluation.png", 156, 78)

# Mechanism diagram: evidence-aware edges and no quantitative claim.
save_mechanism <- function(path) {
  ragg::agg_png(path, width = 132, height = 72, units = "mm", res = 300, background = "white")
  grid::grid.newpage()
  node <- function(x, y, label, fill, r = 0.060, fontsize = 7.2) {
    grid::grid.circle(x = grid::unit(x, "npc"), y = grid::unit(y, "npc"), r = grid::unit(r, "npc"),
                      gp = grid::gpar(fill = fill, col = "#303030", lwd = 0.8))
    grid::grid.text(label, x = grid::unit(x, "npc"), y = grid::unit(y, "npc"),
                    gp = grid::gpar(fontfamily = font_family, fontsize = fontsize, col = "#202020"))
  }
  edge <- function(x0, y0, x1, y1, col, lty = 1) {
    grid::grid.lines(x = grid::unit(c(x0, x1), "npc"), y = grid::unit(c(y0, y1), "npc"),
                     arrow = grid::arrow(length = grid::unit(2.2, "mm"), type = "closed"),
                     gp = grid::gpar(col = col, lwd = 1.2, lty = lty))
  }
  edge(0.16, 0.58, 0.31, 0.58, COL[["navy"]]); edge(0.44, 0.60, 0.59, 0.70, COL[["teal"]])
  edge(0.44, 0.56, 0.59, 0.44, COL[["ochre"]], 2); edge(0.71, 0.70, 0.82, 0.60, COL[["coral"]])
  edge(0.71, 0.44, 0.82, 0.56, COL[["coral"]], 2)
  node(0.10, 0.58, "Stress", "#DCE8EE"); node(0.38, 0.58, "Sensor", "#D9E8E2")
  node(0.65, 0.72, "TF-A", "#F1E5C8"); node(0.65, 0.42, "TF-B", "#E6DFED")
  node(0.90, 0.58, "Response", "#EED8D3", r = 0.078, fontsize = 6.6)
  grid::grid.lines(x = grid::unit(c(0.09, 0.15), "npc"), y = grid::unit(c(0.16, 0.16), "npc"), gp = grid::gpar(col = "#555555", lwd = 1.2))
  grid::grid.text("Supported interaction", x = grid::unit(0.17, "npc"), y = grid::unit(0.16, "npc"), just = "left",
                  gp = grid::gpar(fontfamily = font_family, fontsize = 7))
  grid::grid.lines(x = grid::unit(c(0.52, 0.58), "npc"), y = grid::unit(c(0.16, 0.16), "npc"), gp = grid::gpar(col = "#555555", lwd = 1.2, lty = 2))
  grid::grid.text("Hypothesized interaction", x = grid::unit(0.60, "npc"), y = grid::unit(0.16, "npc"), just = "left",
                  gp = grid::gpar(fontfamily = font_family, fontsize = 7))
  grDevices::dev.off()
}
save_mechanism(file.path(out_dir, "domain-mechanism.png"))

# Multi-panel main-figure grammar assembled from already defined plots.
p_multi_small <- p_multi + ggplot2::theme(legend.position = "none")
p_profile_small <- p_profile + ggplot2::theme(legend.position = "none")
p_pca_small <- p_pca + ggplot2::theme(legend.position = "none")
p_umap_small <- p_umap + ggplot2::theme(legend.position = "none")
p_panel <- (p_pca_small | p_umap_small) / (p_profile_small | p_multi_small) +
  patchwork::plot_annotation(tag_levels = "A", theme = ggplot2::theme(plot.tag = ggplot2::element_text(family = font_family, face = "bold", size = 9)))
save_plot(p_panel, "domain-multipanel-evidence.png", 174, 132)

writeLines(capture.output(sessionInfo()), file.path(out_dir, "sessionInfo-domain.txt"))
message("DOMAIN_GALLERY_RENDERED: ", normalizePath(out_dir))
