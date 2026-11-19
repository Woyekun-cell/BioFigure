#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args)) args[[1]] else "docs/assets/gallery"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
options(warn = 2)

required <- c("ggplot2", "ggrepel", "ComplexHeatmap", "circlize", "grid", "ragg", "systemfonts")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Missing R packages: ", paste(missing, collapse = ", "))

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_file <- normalizePath(sub("^--file=", "", script_arg[[1]]))
skill_root <- normalizePath(file.path(dirname(script_file), "..", ".."))
source(file.path(skill_root, "scripts", "figure_style.R"))
font <- bf_font("Arial")
bf_complexheatmap_font(font)
font_family <- font$family
palette <- c(navy = "#28527A", blue = "#5B8DB8", cream = "#F7F4EF", coral = "#C46A5A", teal = "#4F8F8A")

theme_biofigure <- function() {
  ggplot2::theme_classic(base_family = font_family, base_size = 8) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "white", colour = NA),
      panel.background = ggplot2::element_rect(fill = "white", colour = NA),
      axis.title = ggplot2::element_text(size = 8.5, colour = "#202020"),
      axis.text = ggplot2::element_text(size = 7.5, colour = "#202020"),
      axis.line = ggplot2::element_line(linewidth = 0.35, colour = "#202020"),
      axis.ticks = ggplot2::element_line(linewidth = 0.3, colour = "#202020"),
      legend.position = "right",
      legend.title = ggplot2::element_text(size = 7.5),
      legend.text = ggplot2::element_text(size = 7),
      legend.key.height = grid::unit(3.6, "mm"),
      plot.margin = ggplot2::margin(5, 6, 5, 5, unit = "mm")
    )
}

save_plot <- function(plot, filename, width_mm, height_mm) {
  ragg::agg_png(file.path(out_dir, filename), width = width_mm, height = height_mm,
                units = "mm", res = 300, background = "white", scaling = 1)
  print(plot)
  grDevices::dev.off()
}

# 1. Expression heatmap: 24 genes, 16 samples, four biological groups.
set.seed(20260909)
groups <- rep(c("Control", "Heat", "Hypoxia", "Recovery"), each = 4)
mat <- matrix(rnorm(24 * 16, sd = 0.55), nrow = 24,
              dimnames = list(sprintf("Gene%02d", 1:24), sprintf("S%02d", 1:16)))
mat[1:6, groups == "Heat"] <- mat[1:6, groups == "Heat"] + 1.5
mat[7:12, groups == "Hypoxia"] <- mat[7:12, groups == "Hypoxia"] - 1.4
mat[13:18, groups == "Recovery"] <- mat[13:18, groups == "Recovery"] + 1.0
mat <- t(scale(t(mat)))
group_cols <- c(Control = "#28527A", Heat = "#C46A5A", Hypoxia = "#7D719B", Recovery = "#4F8F8A")
ha <- ComplexHeatmap::HeatmapAnnotation(
  Group = groups, col = list(Group = group_cols),
  simple_anno_size = grid::unit(2.5, "mm"),
  annotation_name_gp = grid::gpar(fontfamily = font_family, fontsize = 7),
  annotation_legend_param = list(
    title_gp = grid::gpar(fontfamily = font_family, fontsize = 7.5),
    labels_gp = grid::gpar(fontfamily = font_family, fontsize = 7)
  )
)
heatmap <- ComplexHeatmap::Heatmap(
  mat, name = "Row z-score", top_annotation = ha,
  col = circlize::colorRamp2(c(-2, -1, 0, 1, 2), c("#183B66", "#78A6C8", "#F7F4EF", "#D89182", "#8E3D3A")),
  width = grid::unit(ncol(mat) * 3.2, "mm"), height = grid::unit(nrow(mat) * 3.2, "mm"),
  rect_gp = grid::gpar(col = "white", lwd = 0.25),
  cluster_columns = FALSE, show_column_names = FALSE,
  row_names_gp = grid::gpar(fontfamily = font_family, fontsize = 6.5),
  column_names_gp = grid::gpar(fontfamily = font_family, fontsize = 6.5),
  heatmap_legend_param = list(
    title_gp = grid::gpar(fontfamily = font_family, fontsize = 7.5),
    labels_gp = grid::gpar(fontfamily = font_family, fontsize = 7),
    grid_width = grid::unit(3, "mm")
  )
)
ragg::agg_png(file.path(out_dir, "template-heatmap.png"), width = 112, height = 104,
              units = "mm", res = 300, background = "white")
grid::grid.newpage()
ComplexHeatmap::draw(heatmap, heatmap_legend_side = "right", annotation_legend_side = "right",
                     padding = grid::unit(c(4, 4, 4, 4), "mm"))
grDevices::dev.off()

# 2. Volcano plot: effect, uncertainty and restrained labels.
set.seed(20260910)
n <- 2500
volcano <- data.frame(
  gene = sprintf("Gene%04d", seq_len(n)),
  log2_fc = rnorm(n, sd = 1.05),
  p_value = pmin(runif(n), stats::pnorm(-abs(rnorm(n, 0, 1.4))) * 2)
)
volcano$q_value <- p.adjust(volcano$p_value, method = "BH")
volcano$status <- factor(ifelse(volcano$q_value < 0.05 & volcano$log2_fc >= 1, "Higher",
                         ifelse(volcano$q_value < 0.05 & volcano$log2_fc <= -1, "Lower", "Not selected")),
                         levels = c("Lower", "Not selected", "Higher"))
labels <- head(volcano[volcano$status != "Not selected", ][order(volcano$q_value[volcano$status != "Not selected"]), ], 8)
volcano_plot <- ggplot2::ggplot(volcano, ggplot2::aes(log2_fc, -log10(pmax(q_value, 1e-300)))) +
  ggplot2::geom_point(ggplot2::aes(fill = status), shape = 21, colour = "#303030", stroke = 0.12,
                      size = 1.15, alpha = 0.72) +
  ggplot2::geom_vline(xintercept = c(-1, 1), colour = "#888888", linewidth = 0.3, linetype = 2) +
  ggplot2::geom_hline(yintercept = -log10(0.05), colour = "#888888", linewidth = 0.3, linetype = 2) +
  ggrepel::geom_text_repel(data = labels, ggplot2::aes(label = gene), family = font_family,
                           size = 2.25, colour = "#202020", box.padding = 0.25,
                           point.padding = 0.18, segment.size = 0.25, min.segment.length = 0,
                           max.overlaps = Inf, seed = 20260910) +
  ggplot2::scale_fill_manual(values = c(Lower = palette[["navy"]], `Not selected` = "#D8D8D8", Higher = palette[["coral"]])) +
  ggplot2::labs(x = expression(log[2]~fold~change), y = expression(-log[10]~adjusted~italic(P)), fill = NULL) +
  ggplot2::coord_cartesian(clip = "off") + theme_biofigure()
save_plot(volcano_plot, "template-volcano.png", 112, 88)

# 3. Single-cell marker dot plot: black outline, area and colour encode separate variables.
cell_types <- c("Progenitor", "Myeloid", "B cell", "T cell", "Endothelial", "Stromal")
markers <- c("SOX4", "LYZ", "CD79A", "CD3D", "KDR", "COL1A1", "MKI67", "HIF1A")
dot <- expand.grid(cell_type = cell_types, marker = markers, KEEP.OUT.ATTRS = FALSE)
set.seed(20260911)
dot$fraction <- runif(nrow(dot), 0.08, 0.55)
dot$average <- rnorm(nrow(dot), 0, 0.45)
for (i in seq_along(cell_types)) {
  idx <- dot$cell_type == cell_types[[i]] & dot$marker == markers[[i]]
  dot$fraction[idx] <- runif(sum(idx), 0.72, 0.94)
  dot$average[idx] <- runif(sum(idx), 1.1, 1.8)
}
dot$cell_type <- factor(dot$cell_type, levels = rev(cell_types))
dot$marker <- factor(dot$marker, levels = markers)
dot_plot <- ggplot2::ggplot(dot, ggplot2::aes(marker, cell_type)) +
  ggplot2::geom_point(ggplot2::aes(size = fraction, fill = average), shape = 21,
                      colour = "black", stroke = 0.25) +
  ggplot2::scale_size_area(name = "Expressing cells", max_size = 6,
                           breaks = c(0.25, 0.50, 0.75), labels = c("25%", "50%", "75%")) +
  ggplot2::scale_fill_gradientn(name = "Average expression",
                               colours = c("#F7F4EF", "#89AFC3", "#28527A")) +
  ggplot2::labs(x = NULL, y = NULL) +
  theme_biofigure() +
  ggplot2::theme(axis.line = ggplot2::element_blank(), axis.ticks = ggplot2::element_blank(),
                 axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
                 panel.grid.major = ggplot2::element_line(colour = "#EAEAEA", linewidth = 0.25),
                 legend.box = "vertical")
save_plot(dot_plot, "template-single-cell-dotplot.png", 124, 84)

writeLines(capture.output(sessionInfo()), file.path(out_dir, "sessionInfo-core.txt"))
message("CORE_GALLERY_RENDERED: ", normalizePath(out_dir))
