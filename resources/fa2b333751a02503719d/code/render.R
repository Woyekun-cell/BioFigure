#!/usr/bin/env Rscript
# Selected published Fig1a: exact author pEH23 layers, new semantic palette.
# No raw SyRI/GFF/sequence analysis and no full Nature Fig1 reconstruction.
suppressPackageStartupMessages({
  library(ggplot2); library(cowplot); library(yaml); library(jsonlite)
})
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 3L)
root <- normalizePath(args[[1]])
work <- normalizePath(args[[2]])
auth <- normalizePath(args[[3]])
skill <- normalizePath(file.path(root, '../../../..'))
source(file.path(skill, 'scripts/figure_style.R'))
font <- bf_font('Arial')
options(warn = 2)
cowplot::set_null_device('agg')
spec_path <- file.path(root, 'data/metadata/design-spec.yaml')
design <- read_yaml(spec_path)
width <- design$output_size$width_mm
height <- design$output_size$height_mm
stopifnot(width == 180, height == 170)
source_lock <- fromJSON(file.path(root, 'data/metadata/source-lock.json'))
for (i in seq_len(nrow(source_lock$assets))) {
  a <- source_lock$assets[i, ]
  stopifnot(digest::digest(file = file.path(root, a$path), algo = 'sha256') == a$sha256)
}

# Rebuild from the original data.frames; never build/render the old saved plot.
stored <- new.env(parent = baseenv())
loaded <- load(file.path(root, 'data/raw/EH23ideo.RData'), envir = stored)
stopifnot('pEH23' %in% loaded)
author_plot <- get('pEH23', envir = stored)
pull <- function(indices, filename, expected_n) {
  frames <- lapply(indices, function(i) {
    d <- author_plot$layers[[i]]$data
    stopifnot(is.data.frame(d)); d$author_layer <- i; d
  })
  d <- do.call(rbind, frames)
  csv <- read.csv(file.path(root, 'results/plot_data', filename), check.names = FALSE)
  stopifnot(nrow(d) == expected_n, isTRUE(all.equal(d, csv,
    check.attributes = FALSE, tolerance = 1e-12)))
  d
}
chromosomes <- pull(1:2, 'fig1a-chromosome-pairs.csv', 20L)
polygons <- pull(3:4, 'fig1a-synteny-polygons.csv', 2100L)
windows <- pull(5:6, 'fig1a-cpg-gene-windows.csv', 1487L)
loci <- pull(12:17, 'fig1a-locus-markers.csv', 4457L)
stopifnot(length(unique(chromosomes$chrom_num)) == 10L,
          length(unique(paste(polygons$author_layer, polygons$ID))) == 105L,
          sum(loci$sstart > loci$send) == 155L,
          max(windows$gcnt) == 156, min(windows$gcnt) == 0,
          all(is.finite(windows$iCGs)), range(windows$iCGs) == c(0, 1),
          sum(windows$Win_length < 1e6) == 20L)
gene_max <- max(windows$gcnt)
gene_palette <- viridisLite::viridis(100, option = 'D', begin = 0.06, end = 0.95)
gene_index <- as.integer(windows$gcnt / gene_max * 99 + 1)
windows$new_color <- gene_palette[gene_index]
palette_table <- data.frame(index = 1:100,
  lower_gene_count = (0:99) / 99 * gene_max, color = gene_palette)
write.csv(palette_table, file.path(root, 'results/plot_data/fig1a-gene-palette.csv'), row.names = FALSE)
colors <- design$palette_semantics
base_theme <- bf_theme(font, size = 7) + theme(
  plot.margin = margin(1.5, 1.0, 1.5, 1.5, unit = 'mm'),
  axis.line = element_line(linewidth = 0.18, colour = '#33373D'),
  axis.ticks = element_line(linewidth = 0.18, colour = '#33373D'),
  axis.ticks.length = grid::unit(0.8, 'mm'),
  axis.title.x = element_text(margin = margin(t = 2, unit = 'mm')),
  axis.title.y = element_text(margin = margin(r = 2, unit = 'mm')),
  legend.position = 'none')

main <- ggplot()
for (i in 1:2) {
  z <- chromosomes[chromosomes$author_layer == i, ]
  z$cx <- z$chrom_num + if (i == 1) -0.2 else 0.2
  main <- main + geom_rect(data = z,
    aes(xmin = cx - 0.05, xmax = cx + 0.05, ymin = 1 / 1e6, ymax = Length / 1e6),
    fill = colors$Chromosome, colour = '#454B53', linewidth = 0.20)
}
for (i in 3:4) {
  z <- polygons[polygons$author_layer == i, ]
  main <- main + geom_polygon(data = z,
    aes(x = poly_xs, y = poly_ys / 1e6, group = ID),
    fill = if (i == 3) colors$Synteny else colors$Inversion,
    alpha = if (i == 3) 0.42 else 0.9,
    colour = if (i == 3) '#858A91' else NA,
    linewidth = 0.12)
}
for (i in 5:6) {
  z <- windows[windows$author_layer == i, ]
  z$xmin <- if (i == 5) z$chrn - z$iCGs * 0.28 - 0.2 else z$chrn + 0.2
  z$xmax <- if (i == 5) z$chrn - 0.2 else z$chrn + z$iCGs * 0.28 + 0.2
  main <- main + geom_rect(data = z,
    aes(xmin = xmin, xmax = xmax, ymin = Start / 1e6, ymax = End / 1e6),
    fill = z$new_color, colour = NA)
}
for (i in 12:17) {
  z <- loci[loci$author_layer == i, ]
  is_a <- i %in% c(12, 14, 16)
  z$xmin <- if (is_a) z$chrn - 0.48 else z$chrn + if (i == 13) 0.14 else 0.1
  z$xmax <- if (is_a) z$chrn - if (i == 12) 0.14 else 0.1 else z$chrn + 0.48
  # Rectangles normalize endpoint order only, preserving coordinates and strand.
  z$lower <- pmin(z$sstart, z$send) / 1e6
  z$upper <- pmax(z$sstart, z$send) / 1e6
  key <- if (i <= 13) 'Cannabinoid loci' else if (i <= 15) '5S rDNA' else '45S rDNA'
  main <- main + geom_rect(data = z,
    aes(xmin = xmin, xmax = xmax, ymin = lower, ymax = upper),
    fill = colors[[key]], colour = colors[[key]],
    linewidth = if (i >= 16) 0.6 else 0.22)
}
main <- main + scale_x_continuous(breaks = 1:10,
  labels = c(as.character(1:9), 'X'), expand = c(0, 0)) +
  scale_y_continuous(breaks = seq(0, 80, 10), expand = c(0, 0)) +
  coord_cartesian(xlim = c(0.48, 10.52), ylim = c(-4, 88), clip = 'on') +
  labs(x = 'Chromosome', y = 'Position (Mb)') + base_theme

# Right-hand legend uses the same quantized color table, including its endpoints.
bar <- data.frame(ymin = seq(49, 91, length.out = 101)[1:100],
  ymax = seq(49, 91, length.out = 101)[2:101], color = gene_palette)
categories <- data.frame(label = c('Synteny', 'Inversion', 'Cannabinoid loci', '5S rDNA', '45S rDNA'),
  y = c(42, 36, 30, 24, 18), fill = unlist(colors[c('Synteny', 'Inversion', 'Cannabinoid loci', '5S rDNA', '45S rDNA')]),
  alpha = c(0.42, 0.9, 1, 1, 1))
labels <- data.frame(x = c(0.5, 0.5, 0.5, 4.8, 4.8, 4.8, 0.5, 0.5),
  y = c(101, 97.5, 94, 91, 70, 49, 8, 3),
  label = c('EH23a / EH23b', 'Genes per window', 'Nominal window: 1 Mb', '156', '78', '0',
    'Relative CpG', 'Width: 1 - scaled CpG'))
legend <- ggplot() + geom_rect(data = bar,
  aes(xmin = 0.5, xmax = 3.5, ymin = ymin, ymax = ymax), fill = bar$color, colour = NA) +
  annotate('rect', xmin = 0.5, xmax = 3.5, ymin = 49, ymax = 91,
    fill = NA, colour = '#454B53', linewidth = 0.15) +
  geom_rect(data = categories, aes(xmin = 0.5, xmax = 3.5, ymin = y - 0.8, ymax = y + 0.8),
    fill = categories$fill, alpha = categories$alpha, colour = NA) +
  geom_text(data = categories, aes(x = 4.8, y = y, label = label),
    hjust = 0, family = font$family, size = 7 / .pt, colour = '#24272C') +
  geom_text(data = labels, aes(x = x, y = y, label = label),
    hjust = 0, family = font$family, size = 7 / .pt, colour = '#24272C') +
  coord_cartesian(xlim = c(0, 32), ylim = c(0, 103), clip = 'on', expand = FALSE) +
  theme_void(base_family = font$family, base_size = 7) +
  theme(plot.margin = margin(0, 0, 0, 0, 'mm'),
    plot.background = element_rect(fill = 'white', colour = NA))

# Physical slots leave 3mm between source axes and the legend band.
main_slot <- c(x = 0.5, y = 3.5, w = 145, h = 160.5)
legend_slot <- c(x = 148.5, y = 4.5, w = 30, h = 159)
composite <- ggdraw() + draw_plot(main,
  x = main_slot['x'] / width, y = main_slot['y'] / height,
  width = main_slot['w'] / width, height = main_slot['h'] / height) +
  draw_plot(legend, x = legend_slot['x'] / width, y = legend_slot['y'] / height,
    width = legend_slot['w'] / width, height = legend_slot['h'] / height) +
  draw_label('Fig. 1a | Author data', x = 14 / width, y = 168 / height,
    hjust = 0, vjust = 1, fontfamily = font$family, size = 8, fontface = 'plain')

main_built <- ggplot_build(main)
actual_rows <- vapply(main_built$data, nrow, integer(1))
stopifnot(identical(actual_rows, c(10L, 10L, 800L, 1300L, 744L, 743L,
                                  52L, 56L, 63L, 4237L, 45L, 4L)))
stopifnot(all(vapply(main_built$data, function(d) {
  geometry <- intersect(c('x', 'y', 'xmin', 'xmax', 'ymin', 'ymax'), names(d))
  all(vapply(d[geometry], function(x) all(is.finite(x)), logical(1)))
}, logical(1))))

# Device measurement of gtable fixed margins gives the actual inner data box.
measurement_path <- file.path(work, 'gtable-measurement.png')
ragg::agg_png(measurement_path, width = width, height = height, units = 'mm', res = 300)
g <- ggplotGrob(main)
pi <- g$layout[g$layout$name == 'panel', ]
left <- grid::convertWidth(sum(g$widths[seq_len(pi$l - 1L)]), 'mm', valueOnly = TRUE)
right <- grid::convertWidth(sum(g$widths[(pi$r + 1L):length(g$widths)]), 'mm', valueOnly = TRUE)
top <- grid::convertHeight(sum(g$heights[seq_len(pi$t - 1L)]), 'mm', valueOnly = TRUE)
bottom <- grid::convertHeight(sum(g$heights[(pi$b + 1L):length(g$heights)]), 'mm', valueOnly = TRUE)
invisible(dev.off())
data_bbox <- list(x = unname(main_slot['x'] + left),
  y = unname(main_slot['y'] + bottom),
  width = unname(main_slot['w'] - left - right),
  height = unname(main_slot['h'] - top - bottom))
source_aspect <- 717 / 799
new_aspect <- data_bbox$width / data_bbox$height
relative_aspect_error <- abs(new_aspect / source_aspect - 1)
stopifnot(relative_aspect_error < 0.05)
metrics <- list(schema_version = 1, units = 'mm', final_canvas = list(width = width, height = height),
  main_slot = as.list(main_slot), legend_slot = as.list(legend_slot),
  actual_data_bbox = data_bbox, fixed_main_margins = list(left = left, right = right, top = top, bottom = bottom),
  chromosome_pitch = data_bbox$width / (10.52 - 0.48),
  one_mb_window_height = data_bbox$height / 92,
  minimum_font_pt = 7, legend_category_pitch = 159 / 103 * 6,
  reference_aspect = list(source_bbox_pixels_approx = c(width = 717, height = 799),
    source_aspect_approx = source_aspect, actual_inner_aspect = new_aspect,
    relative_error = relative_aspect_error, maximum_allowed_relative_error = 0.05,
    first_wide_version_rejected = TRUE, final_canvas_height_restores_source_geometry = TRUE),
  source_density = list(source_paired_centers = 0.4, source_chromosome_body_width = 0.1,
    source_max_CpG_width = 0.28, preserved_order = '1..9,X', all_rows_retained = TRUE,
    gap_basis = 'Actual source chromosome lengths and genomic distributions; not padded to equal length'))
write_json(metrics, file.path(root, 'evidence/layout-metrics.json'), pretty = TRUE, auto_unbox = TRUE)
qc <- list(schema_version = 1, status = 'AUTHOR_LAYER_REPLOT_QC_PASS', method_id = source_lock$method_id,
  source_objects = loaded, source_ggplot_never_built = TRUE,
  source_data_csv_equivalence = 'all.equal tolerance1e-12, check.attributes FALSE; drawing directly from RData',
  input_rows = list(chromosomes = 20, polygon_vertices = 2100, windows = 1487, loci = 4457),
  polygon_blocks = list(SYN = length(unique(polygons$ID[polygons$author_layer == 3])),
                        INV = length(unique(polygons$ID[polygons$author_layer == 4]))),
  built_layer_rows = actual_rows, lost_rows = 0,
  reverse_locus_endpoints_normalized = 155, whole_chromosome_flips = 0,
  gene_range = range(windows$gcnt), shared_max_gene_count = gene_max,
  native_window_length_range = range(windows$Win_length),
  short_terminal_windows = sum(windows$Win_length < 1e6),
  count_scale = 'Raw genes per native window; nominal1Mb,20 shorter terminal windows. No per-Mb normalization.',
  gene_palette_index_formula = 'as.integer(gcnt/shared_max*99+1)',
  gene_palette_realized_colours = length(unique(windows$new_color)),
  inverse_scaled_CpG_range = range(windows$iCGs), gene_palette_id = 'viridis-D-100 begin0.06 end0.95',
  statistics_required = FALSE, raw_pipeline_run = FALSE, simulated_data = FALSE,
  scope = 'Only selected Fig1a author-layer geometry and new palette; not full Fig1 or new-input transfer')
write_json(qc, file.path(root, 'evidence/scientific-checks.json'), pretty = TRUE, auto_unbox = TRUE)

sources <- c(spec_path, file.path(root, 'scripts/render.R'), file.path(skill, 'scripts/figure_style.R'),
  file.path(root, 'data/metadata/source-lock.json'), file.path(root, source_lock$assets$path))
boxes <- data.frame(id = c('data', 'labels', 'legend'),
  x = c(0.5, 14, 148.5), y = c(3.5, 165.5, 4.5),
  w = c(145, 125, 30), h = c(160.5, 4, 159))
preview <- file.path(work, 'fig1a-author-recolored.png')
receipt <- bf_render_png(composite, preview, font, design$text_contract$allowed_text,
  width, height, width, sources, boxes, authorization = auth, skill_root = skill,
  publication_size_class = 'double-column', min_text_pt = 7,
  heading_authorization = 'User requested selected Fig1a author-data recolor; panel identifier records scope without adding a scientific conclusion')
grDevices::quartz(type = 'pdf', file = file.path(root, 'results/figures/fig1a-author-recolored.pdf'),
  width = width / 25.4, height = height / 25.4, family = font$family)
print(composite); invisible(dev.off())
ggsave(file.path(work, 'fig1a-author-recolored.svg'), composite, device = svglite::svglite,
  width = width, height = height, units = 'mm', bg = 'white')
file.copy(preview, file.path(work, 'first-color-render.png'), overwrite = FALSE)
file.copy(paste0(preview, '.render.json'), file.path(root, 'evidence/render-receipt.json'), overwrite = TRUE)
writeLines(capture.output(sessionInfo()), file.path(root, 'data/metadata/environment.txt'))
write_json(list(R = R.version.string, packages = lapply(c('ggplot2', 'cowplot', 'viridisLite',
  'ragg', 'yaml', 'jsonlite', 'systemfonts', 'digest', 'svglite'), function(p)
    list(package = p, version = as.character(packageVersion(p)))),
  font = font, seed = NULL, seed_basis = 'No stochastic operation; exact source geometry'),
  file.path(root, 'data/metadata/environment.json'), pretty = TRUE, auto_unbox = TRUE)
cat('AUTHORIZED_R_RENDER_OK; SOURCE_FIG1A_RECOLORED; 20/2100/1487/4457 rows; target180x170mm\n')
