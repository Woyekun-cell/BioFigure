#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(circlize)
  library(ComplexHeatmap)
  library(eulerr)
  library(grid)
  library(ggplot2)
  library(ggbeeswarm)
  library(dplyr)
  library(tidyr)
  library(ragg)
})

set.seed(20260918)
options(warn = 1)
args <- commandArgs(trailingOnly = FALSE)
script <- normalizePath(sub("^--file=", "", args[grep("^--file=", args)]))
root <- normalizePath(file.path(dirname(script), ".."))
fig_dir <- file.path(root, "results", "figures")
data_dir <- file.path(root, "results", "plot_data")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)

save_plot <- function(file, plot, width, height) {
  ggsave(file.path(fig_dir, file), plot, width = width, height = height,
         dpi = 200, device = ragg::agg_png, bg = "white")
}

make_ring_data <- function(groups, genes_per_group, sample_names) {
  group <- factor(rep(groups, each = genes_per_group), levels = groups)
  prefix <- substr(groups, 1, 2)
  gene <- unlist(lapply(seq_along(groups), function(i) {
    paste0(prefix[i], "_", sprintf("%02d", seq_len(genes_per_group)))
  }))
  module_shift <- seq(-0.8, 0.8, length.out = length(groups))
  mat <- matrix(rnorm(length(gene) * length(sample_names), sd = 0.72), nrow = length(gene))
  mat <- mat + rep(module_shift, each = genes_per_group)
  mat <- t(scale(t(mat)))
  rownames(mat) <- gene
  colnames(mat) <- sample_names
  list(meta = data.frame(gene = gene, group = group), matrix = mat)
}

draw_circular_composite <- function(case, mode = c("upset", "venn")) {
  mode <- match.arg(mode)
  if (mode == "upset") {
    groups <- c("Metabolism", "Cell cycle", "Signaling", "Hypoxia", "Immune")
    group_cols <- c("#AFC8DE", "#E5B5BA", "#EBC9B6", "#D7E3EA", "#E5C9B7")
    col_fun <- colorRamp2(c(-2, 0, 2), c("#2166AC", "#F7F7F7", "#B2182B"))
    ring <- make_ring_data(groups, 12, paste0("Exp_", 1:5))
    gap <- c(rep(5, length(groups) - 1), 18)
  } else {
    groups <- c("Acceleration", "Divergence", "Curl")
    group_cols <- c("#E7B5D1", "#BFDDB4", "#E6D7C9")
    col_fun <- colorRamp2(c(-2, 0, 2), c("#4DAC26", "#F7F7F7", "#D01C8B"))
    ring <- make_ring_data(groups, 24, c("Left ventricle", "Right ventricle", "Outflow tract", "Right atrium", "Left atrium"))
    gap <- c(7, 7, 20)
  }
  meta <- ring$meta
  mat <- ring$matrix
  out <- file.path(fig_dir, sprintf("%02d_%s.png", case, ifelse(mode == "upset", "circular_heatmap_upset", "circular_heatmap_venn")))
  ragg::agg_png(out, width = 1800, height = 1800, res = 220, bg = "white")
  circos.clear()
  circos.par(start.degree = 90, gap.after = gap, track.margin = c(0.003, 0.006),
             cell.padding = c(0, 0, 0, 0), canvas.xlim = c(-1.08, 1.08), canvas.ylim = c(-1.08, 1.08))
  circos.heatmap(mat, split = meta$group, cluster = FALSE, col = col_fun,
                 bg.border = "#4A4A4A", bg.lwd = 0.6, cell.border = "white", cell.lwd = 0.35,
                 rownames.side = "outside", rownames.cex = ifelse(mode == "upset", 0.40, 0.34),
                 rownames.col = "#202124", track.height = 0.29)

  if (mode == "venn") {
    qval <- 10^runif(nrow(meta), -5, -0.3)
    qfun <- colorRamp2(c(0, 0.5, 1), c("#F7F7F7", "#F4A582", "#67001F"))
    circos.trackPlotRegion(ylim = c(0, 1), track.height = 0.045, bg.border = NA,
      panel.fun = function(x, y) {
        g <- CELL_META$sector.index
        ind <- which(meta$group == g)
        xs <- seq(CELL_META$xlim[1], CELL_META$xlim[2], length.out = length(ind) + 2)[-c(1, length(ind) + 2)]
        circos.points(xs, rep(0.5, length(xs)), pch = 18, cex = 0.42,
                      col = qfun(pmin(1, -log10(qval[ind]) / 5)))
      })
  }

  names(group_cols) <- groups
  circos.trackPlotRegion(ylim = c(0, 1), track.height = 0.075,
    bg.col = adjustcolor(group_cols[groups], alpha.f = 0.62), bg.border = "#555555", bg.lwd = 0.5,
    panel.fun = function(x, y) {
      circos.text(CELL_META$xcenter, 0.48, CELL_META$sector.index,
                  facing = "bending.inside", niceFacing = TRUE, cex = 0.7,
                  family = "Helvetica", font = 2)
    })

  if (mode == "upset") {
    universe <- rownames(mat)
    sets <- lapply(seq_along(groups), function(i) {
      own <- meta$gene[meta$group == groups[i]]
      adjacent <- meta$gene[meta$group == groups[(i %% length(groups)) + 1]][1:3]
      unique(c(own, adjacent, sample(universe, 2)))
    })
    names(sets) <- groups
    comb <- make_comb_mat(sets)
    pushViewport(viewport(x = 0.5, y = 0.5, width = 0.37, height = 0.26))
    up <- UpSet(comb, set_order = groups, comb_col = "#2F7FAF", pt_size = unit(1.7, "mm"), lwd = 0.8,
                left_annotation = upset_left_annotation(comb, gp = gpar(fill = adjustcolor(group_cols, 0.65))),
                row_names_gp = gpar(fontsize = 6.5, fontfamily = "Helvetica"),
                top_annotation = upset_top_annotation(comb, gp = gpar(fill = "#2F7FAF")))
    draw(up, newpage = FALSE, background = "transparent")
    grid.text("Morphogenic\ngenes", y = unit(-0.17, "npc"),
              gp = gpar(fontsize = 10, fontface = "bold", fontfamily = "Helvetica"))
    popViewport()
  } else {
    universe <- meta$gene
    sets <- list(
      Acceleration = unique(c(meta$gene[meta$group == "Acceleration"], universe[30:36])),
      Divergence = unique(c(meta$gene[meta$group == "Divergence"], universe[12:18], universe[42:46])),
      Curl = unique(c(meta$gene[meta$group == "Curl"], universe[8:13], universe[29:33]))
    )
    fit <- euler(sets)
    pushViewport(viewport(x = 0.5, y = 0.5, width = 0.25, height = 0.25))
    grid.draw(plot(fit, fills = list(fill = c("#D01C8B", "#4DAC26", "#BDBDBD"), alpha = 0.42),
                   edges = list(col = "#353535", lty = 2, lwd = 1.1), labels = FALSE, quantities = TRUE))
    grid.text("Morphogenic\ngenes", y = unit(-0.10, "npc"),
              gp = gpar(fontsize = 10, fontface = "bold", fontfamily = "Helvetica"))
    popViewport()
  }

  leg <- Legend(title = ifelse(mode == "upset", "Expression", "Expression\nfraction"),
                col_fun = col_fun, at = c(-2, -1, 0, 1, 2),
                title_gp = gpar(fontsize = 7.5, fontfamily = "Helvetica", fontface = "bold"),
                labels_gp = gpar(fontsize = 6.5, fontfamily = "Helvetica"),
                grid_width = unit(2.5, "mm"), grid_height = unit(2.5, "mm"))
  draw(leg, x = unit(0.95, "npc"), y = unit(0.93, "npc"), just = c("right", "top"))
  dev.off()
  circos.clear()
  write.csv(cbind(meta, mat), file.path(data_dir, sprintf("%02d_%s.csv", case, mode)), row.names = FALSE)
}

draw_circular_composite(10, "upset")
draw_circular_composite(11, "venn")

# 12 open semicircular violin + box + raw observations.
groups12 <- c("SARS-CoV-2 Delta", "SARS-CoV-2 Beta", "SARS-CoV-2 Mu", "SARS-CoV-2 Omicron BA.1",
              "SARS-CoV-2 Omicron BA.2", "CoV BNL63", "Pangolin CoV GX-P5L", "Bat CoV RaTG13",
              "SARS-CoV-1", "MERS-CoV", "HCoV-OC43")
d12 <- expand.grid(group = factor(groups12, levels = groups12), replicate = seq_len(38))
d12$group_i <- as.integer(d12$group)
d12$log_value <- pmin(3.65, pmax(0.10, rnorm(nrow(d12),
  mean = seq(1.05, 2.55, length.out = length(groups12))[d12$group_i], sd = 0.22)))
sum12 <- d12 |> group_by(group) |> summarise(mean = mean(log_value), max = max(log_value), .groups = "drop")
cols12 <- setNames(c("#514F9C", "#3E75B6", "#35A0B6", "#43A77A", "#8CBF55", "#D1B541",
                     "#E88943", "#DC5A55", "#B84D80", "#8D64A9", "#6474A8"), groups12)
p12 <- ggplot(d12, aes(group, log_value, fill = group, colour = group)) +
  geom_violin(width = 0.40, scale = "width", linewidth = 0.42, alpha = 0.82) +
  geom_boxplot(width = 0.09, outlier.shape = NA, fill = "white", colour = "#30343B", linewidth = 0.30,
               staplewidth = 0.55) +
  geom_quasirandom(shape = 21, size = 0.42, stroke = 0, width = 0.08, alpha = 0.28) +
  geom_text(data = sum12, aes(y = 3.90, label = group), angle = 90, hjust = -0.03,
            fontface = "bold", size = 2.25, show.legend = FALSE) +
  geom_text(data = sum12, aes(x = group, y = pmin(max + 0.13, 3.62), label = sprintf("%.1f", mean)),
            inherit.aes = FALSE, size = 2.15, family = "Helvetica") +
  scale_fill_manual(values = cols12) + scale_colour_manual(values = cols12) +
  scale_y_continuous(limits = c(0, 4.25), breaks = 0:4, expand = c(0, 0)) +
  coord_radial(start = -pi/2, end = pi/2, inner.radius = 0.12, r.axis.inside = TRUE,
               rotate.angle = TRUE, clip = "off") +
  theme_minimal(base_family = "Helvetica", base_size = 9) +
  theme(axis.title = element_blank(), axis.text.x = element_blank(), legend.position = "none",
        panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "#D8DDE3", linewidth = 0.35),
        plot.margin = margin(10, 34, 8, 34))
save_plot("12_semicircle_violin.png", p12, 8.2, 6.2)
write.csv(d12, file.path(data_dir, "12_semicircle_violin.csv"), row.names = FALSE)

# 13 open fan boxplot + raw observations + mean labels.
groups13 <- groups12
d13 <- expand.grid(group = factor(groups13, levels = groups13), replicate = seq_len(42))
d13$group_i <- as.integer(d13$group)
d13$value <- pmin(3.85, pmax(0.10, rnorm(nrow(d13),
  mean = seq(0.75, 2.65, length.out = length(groups13))[d13$group_i], sd = 0.34)))
sum13 <- d13 |> group_by(group) |> summarise(mean = mean(value), max = max(value), .groups = "drop")
cols13 <- setNames(c("#A71B4B", "#D44D35", "#ED820A", "#F7B347", "#FCDE85", "#D5E6B2",
                     "#BAEEAE", "#61D4AF", "#00B1B5", "#0084B3", "#584B9F"), groups13)
p13 <- ggplot(d13, aes(group, value, colour = group)) +
  geom_boxplot(width = 0.40, outlier.shape = NA, linewidth = 0.34, fill = NA, staplewidth = 0.50) +
  geom_quasirandom(size = 0.50, width = 0.17, alpha = 0.72) +
  geom_text(data = sum13, aes(x = group, y = max + 0.14, label = sprintf("%.1f", mean)),
            inherit.aes = FALSE, size = 2.15, family = "Helvetica") +
  geom_text(data = sum13, aes(y = 4.05, label = group), angle = 90, hjust = -0.03,
            fontface = "bold", size = 2.2, show.legend = FALSE) +
  scale_colour_manual(values = cols13) +
  scale_y_continuous(limits = c(0, 4.35), breaks = 0:4, expand = c(0, 0)) +
  coord_radial(start = -pi/3, end = pi/3, inner.radius = 0.30, r.axis.inside = FALSE,
               rotate.angle = TRUE, clip = "off") +
  theme_minimal(base_family = "Helvetica", base_size = 9) +
  theme(axis.title = element_blank(), axis.text.x = element_blank(), legend.position = "none",
        panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "#D8DDE3", linewidth = 0.35),
        plot.margin = margin(12, 42, 8, 42))
save_plot("13_fan_boxplot.png", p13, 8.2, 6.2)
write.csv(d13, file.path(data_dir, "13_fan_boxplot.csv"), row.names = FALSE)

# 14 circular grouped profiles with explicit domain gaps and significance labels.
domains <- c("Somatic symptoms", "Sleep", "Affective", "Interpersonal", "Pain quality",
             "Physical quality", "Stress", "Resources", "Somatic experiences")
feature_counts <- c(9, 8, 10, 8, 8, 9, 9, 8, 9)
features <- unlist(Map(function(d, n) paste0(gsub(" ", "_", substr(d, 1, 5)), "_", seq_len(n)), domains, feature_counts))
domain <- rep(domains, feature_counts)
gap <- 2
starts <- integer(length(domains)); ends <- integer(length(domains)); cursor <- 1
ids <- integer(length(features)); k <- 1
for (i in seq_along(domains)) {
  starts[i] <- cursor
  idx <- k:(k + feature_counts[i] - 1)
  ids[idx] <- cursor:(cursor + feature_counts[i] - 1)
  ends[i] <- max(ids[idx])
  cursor <- ends[i] + gap + 1
  k <- max(idx) + 1
}
feature_tbl <- data.frame(feature = features, domain = factor(domain, levels = domains), id = ids)
profile_names <- c("PT1 avoidant", "PT2 psychosomatic", "PT3 somatic", "PT4 distress")
d14 <- tidyr::crossing(feature_tbl, profile = factor(profile_names, levels = profile_names)) |>
  mutate(profile_i = as.integer(profile), domain_i = as.integer(domain),
         value = 0.45 * sin(id / 4 + profile_i * 0.9) + (profile_i - 2.5) * 0.18 +
                 (domain_i - 5) * 0.035 + rnorm(n(), 0, 0.06))
sig_features <- sample(features, 13)
label14 <- feature_tbl |> mutate(sig = ifelse(feature %in% sig_features, "*", ""), label = paste0(feature, sig),
  angle = 90 - 360 * (id - 0.5) / (max(ids) + gap),
  hjust = ifelse(angle < -90, 1, 0), angle = ifelse(angle < -90, angle + 180, angle), y = 1.82)
base14 <- data.frame(domain = domains, start = starts, end = ends, title = (starts + ends) / 2) |>
  mutate(angle = 90 - 360 * (title - 0.5) / (max(ids) + gap),
         hjust = ifelse(angle < -90, 1, 0), angle = ifelse(angle < -90, angle + 180, angle))
grid14 <- tidyr::crossing(base14, tick = c(-1.0, -0.5, 0, 0.5, 1.0))
cols14 <- c("PT1 avoidant"="#E88900", "PT2 psychosomatic"="#49A6D8", "PT3 somatic"="#CF4759", "PT4 distress"="#6F63A8")
p14 <- ggplot(d14) +
  annotate("rect", xmin = -Inf, xmax = Inf, ymin = -4.3, ymax = -1.72, fill = "#FAFAFA") +
  geom_segment(data = grid14, aes(x = start - 0.35, xend = end + 0.35, y = tick, yend = tick),
               inherit.aes = FALSE, colour = "#C9CED4", linewidth = 0.32) +
  geom_line(aes(id, value, group = interaction(profile, domain), colour = profile), linewidth = 0.82) +
  geom_point(aes(id, value, colour = profile), size = 1.25) +
  geom_segment(data = base14, aes(x = start - 0.45, xend = end + 0.45, y = -1.38, yend = -1.38),
               inherit.aes = FALSE, colour = "#32373C", linewidth = 0.55) +
  geom_segment(data = base14, aes(x = title, xend = title, y = -1.52, yend = -1.38),
               inherit.aes = FALSE, colour = "#32373C", linewidth = 0.55) +
  geom_text(data = base14, aes(title, -2.12, label = stringr::str_wrap(domain, 11)),
            inherit.aes = FALSE, size = 2.55, family = "Helvetica", lineheight = 0.88, colour = "#30343B") +
  geom_text(data = label14, aes(id, y, label = label, angle = angle, hjust = hjust),
            inherit.aes = FALSE, size = 2.05, colour = "#555B63", family = "Helvetica") +
  annotate("text", x = min(ids), y = c(-1, -0.5, 0, 0.5, 1),
           label = c("-1", "-0.5", "0", "+0.5", "+1"), size = 2.25, family = "Helvetica") +
  scale_colour_manual(values = cols14, name = NULL) +
  scale_x_continuous(limits = c(0.5, max(ids) + gap + 0.5), expand = c(0, 0)) +
  scale_y_continuous(limits = c(-4.3, 2.15), expand = c(0, 0)) +
  coord_polar(clip = "off") +
  theme_void(base_family = "Helvetica", base_size = 9) +
  theme(legend.position = "right", legend.text = element_text(size = 8.5),
        legend.key.height = unit(4.0, "mm"), plot.margin = margin(10, 6, 10, 6))
save_plot("14_circular_grouped_profiles.png", p14, 8.8, 8.2)
write.csv(d14, file.path(data_dir, "14_circular_grouped_profiles.csv"), row.names = FALSE)

message("Rendered cases 10-14 with source-derived structure contracts")
