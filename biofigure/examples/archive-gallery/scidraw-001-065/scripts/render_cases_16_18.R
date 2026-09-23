#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(tidygraph)
  library(ggraph)
  library(ggplot2)
  library(ggnewscale)
  library(circlize)
  library(ragg)
})
set.seed(20260920)
args <- commandArgs(trailingOnly = FALSE)
script <- normalizePath(sub('^--file=', '', args[grep('^--file=', args)]))
root <- normalizePath(file.path(dirname(script), '..'))
fig_dir <- file.path(root, 'results', 'figures')
data_dir <- file.path(root, 'results', 'plot_data')
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)

categories <- c('Misc. metabolism', 'Stress response', 'Carbon metabolism',
                'Uncharacterized', 'Cellular processes', 'Prophages', 'Other',
                'Single genes', 'Virulence', 'AA/Nucleotide metabolism')
category_n <- c(8, 9, 7, 10, 6, 6, 6, 7, 9, 8)
category_col <- setNames(c('#F47A25', '#DF3E54', '#147747', '#55403C', '#3483C5',
                           '#EC5258', '#59655E', '#D6A14A', '#B94337', '#62449A'), categories)
prefix <- c('Met', 'Str', 'Car', 'Unc', 'Cel', 'Pro', 'Oth', 'Sg', 'Vir', 'Aa')
leaf <- unlist(Map(function(p, n) paste0(p, '_', seq_len(n)), prefix, category_n))
leaf_category <- rep(categories, category_n)
leaf_value <- pmax(0.15, rgamma(length(leaf), shape = 1.45, scale = 0.55))
node <- data.frame(name = c('Core', categories, leaf),
                   type = c('root', rep('category', length(categories)), rep('leaf', length(leaf))),
                   category = c(categories[1], categories, leaf_category),
                   value = c(0, rep(0, length(categories)), leaf_value))
edge <- rbind(data.frame(from = 1, to = seq_along(categories) + 1),
              data.frame(from = rep(seq_along(categories) + 1, category_n),
                         to = seq_along(leaf) + length(categories) + 1))
edge$category <- node$category[edge$to]
graph <- tbl_graph(node, edge, directed = TRUE)
layout <- create_layout(graph, layout = 'dendrogram', circular = TRUE)
leaf_layout <- as.data.frame(layout)[as.data.frame(layout)$type == 'leaf', ]
stopifnot(nrow(leaf_layout) == length(leaf),
          setequal(as.character(leaf_layout$name), as.character(leaf)),
          all(leaf_layout$category %in% names(category_col)),
          !anyNA(category_col))
leaf_layout$theta <- atan2(leaf_layout$y, leaf_layout$x)
leaf_layout$outer_radius <- 1.02 + 0.12 * leaf_layout$value / max(leaf_layout$value)
leaf_layout$label_radius <- 1.18 + 0.12 * leaf_layout$value / max(leaf_layout$value)
leaf_layout$label_x <- leaf_layout$label_radius * cos(leaf_layout$theta)
leaf_layout$label_y <- leaf_layout$label_radius * sin(leaf_layout$theta)
leaf_layout$angle <- leaf_layout$theta * 180 / pi
leaf_layout$flip <- leaf_layout$angle > 90 | leaf_layout$angle < -90
leaf_layout$label_angle <- ifelse(leaf_layout$flip, leaf_layout$angle + 180, leaf_layout$angle)
leaf_layout$label_hjust <- ifelse(leaf_layout$flip, 1, 0)
category_layout <- as.data.frame(layout)[as.data.frame(layout)$type == 'category', ]
category_layout$label <- c('Misc.\nmetabolism', 'Stress\nresponse', 'Carbon\nmetabolism',
                           'Uncharacterized', 'Cellular\nprocesses', 'Prophages',
                           'Other', 'Single\ngenes', 'Virulence', 'AA/Nucleotide\nmetabolism')
category_layout$label_x <- category_layout$x * 1.30
category_layout$label_y <- category_layout$y * 1.30

arc_polygon <- function(theta, radius0, radius1, width, id) {
  a <- seq(theta - width / 2, theta + width / 2, length.out = 5)
  data.frame(id = id, x = c(radius0 * cos(a), radius1 * cos(rev(a))),
             y = c(radius0 * sin(a), radius1 * sin(rev(a))))
}
bar_width <- 2 * pi / length(leaf) * 0.78
bar_poly <- do.call(rbind, lapply(seq_len(nrow(leaf_layout)), function(i) {
  x <- leaf_layout[i, ]
  cbind(arc_polygon(x$theta, 1.02, x$outer_radius, bar_width, i), category = x$category)
}))
base_network <- function() {
  ggraph(layout) +
    geom_edge_diagonal(aes(colour = category), alpha = 0.62, linewidth = 0.38,
                       show.legend = FALSE) +
    geom_node_point(aes(filter = type == 'category', fill = category), shape = 21,
                    size = 3.5, colour = 'white', stroke = 0.4, show.legend = FALSE) +
    geom_label(data = category_layout, aes(label_x, label_y, label = label, colour = category),
              inherit.aes = FALSE, size = 2.8, fontface = 'bold', lineheight = 0.88,
              fill = 'white', linewidth = 0, label.padding = unit(0.8, 'mm'),
              show.legend = FALSE) +
    scale_edge_colour_manual(values = category_col) +
    scale_colour_manual(values = category_col) +
    scale_fill_manual(values = category_col) +
    coord_equal(xlim = c(-1.55, 1.55), ylim = c(-1.55, 1.55), clip = 'off') +
    theme_void(base_family = 'Helvetica') +
    theme(plot.margin = margin(13, 13, 13, 13))
}

p16 <- base_network() +
  geom_polygon(data = bar_poly, aes(x, y, group = id, fill = category),
               inherit.aes = FALSE, colour = '#30343A', linewidth = 0.13,
               alpha = 0.92, show.legend = FALSE) +
  geom_text(data = leaf_layout,
            aes(label_x, label_y, label = name, angle = label_angle,
                hjust = label_hjust, colour = category),
            inherit.aes = FALSE, size = 2.55, show.legend = FALSE)
ggsave(file.path(fig_dir, '16_network_circular_bar.png'), p16,
       width = 10, height = 10, dpi = 200, device = ragg::agg_png, bg = 'white')
write.csv(leaf_layout[, c('name', 'category', 'value', 'theta', 'outer_radius')],
          file.path(data_dir, '16_network_circular_bar.csv'), row.names = FALSE)

leaf_layout$bubble_shape <- rep(c('Circle', 'Square', 'Diamond', 'Triangle'), length.out = nrow(leaf_layout))
p17 <- base_network() +
  ggnewscale::new_scale_fill() +
  geom_point(data = leaf_layout, aes(x, y, fill = value, size = value, shape = bubble_shape),
             colour = '#4B4B4B', stroke = 0.28, inherit.aes = FALSE) +
  geom_text(data = leaf_layout,
            aes(label_x, label_y, label = name, angle = label_angle,
                hjust = label_hjust, colour = category),
            inherit.aes = FALSE, size = 2.55, show.legend = FALSE) +
  scale_fill_gradientn(colours = c('#A3659B', '#568AC3', '#F2D85A', '#DD6B47'),
                       name = 'Value') +
  scale_size_continuous(range = c(1.2, 4.2), name = 'Value') +
  scale_shape_manual(values = c(Circle = 21, Square = 22, Diamond = 23, Triangle = 24),
                     name = 'Marker') +
  theme(legend.position = 'bottom', legend.text = element_text(size = 8),
        legend.title = element_text(size = 8.5), legend.key.height = unit(4, 'mm'))
ggsave(file.path(fig_dir, '17_network_circular_bubble.png'), p17,
       width = 10, height = 10, dpi = 200, device = ragg::agg_png, bg = 'white')
write.csv(leaf_layout[, c('name', 'category', 'value', 'theta', 'bubble_shape')],
          file.path(data_dir, '17_network_circular_bubble.csv'), row.names = FALSE)

# Disease sectors share a score track; gene links connect repeated gene identities.
diseases <- c('Type 2 diabetes', 'Prostate cancer', 'Premature mortality', 'COPD',
              'Lung cancer', 'Renal disease', 'Heart failure', 'Parkinson disease',
              'Colon cancer', 'Breast cancer', 'Acute pancreatitis', 'Multimorbidity')
disease_n <- c(18, 13, 11, 12, 14, 11, 11, 10, 11, 12, 11, 10)
gene_pool <- sprintf('GENE%02d', seq_len(48))
d18 <- do.call(rbind, lapply(seq_along(diseases), function(i) {
  n <- disease_n[i]
  data.frame(group = diseases[i], x = seq_len(n) - 0.5,
             gene = sample(gene_pool, n), score = pmin(1, pmax(0.04,
               0.9 * exp(-(seq_len(n) - 1) / (n / 3.1)) + runif(n, -0.05, 0.05))),
             direction = sample(c('positive', 'negative'), n, replace = TRUE,
                                prob = c(0.32, 0.68)))
}))
d18$colour <- ifelse(d18$direction == 'positive', '#F26D53', '#2867A8')
shared <- subset(d18, gene %in% names(which(table(gene) > 1)))
link_pairs <- do.call(rbind, lapply(split(shared, shared$gene), function(x) {
  x <- x[!duplicated(x$group), ]
  if (nrow(x) < 2) return(NULL)
  x <- x[seq_len(min(3, nrow(x))), ]
  data.frame(gene = x$gene[1], from = x$group[1], x1 = x$x[1],
             to = x$group[-1], x2 = x$x[-1])
}))
link_pairs <- head(link_pairs, 65)
stopifnot(nrow(link_pairs) > 0,
          all(link_pairs$from %in% diseases), all(link_pairs$to %in% diseases),
          all(d18$score >= 0 & d18$score <= 1))
names(disease_n) <- diseases
f18 <- file.path(fig_dir, '18_circular_lollipop_links.png')
ragg::agg_png(f18, width = 1900, height = 1900, res = 220, bg = 'white')
circos.clear()
circos.par(start.degree = 90, gap.after = c(rep(2.0, length(diseases) - 1), 5.0),
           track.margin = c(0.007, 0.007), cell.padding = c(0, 0, 0, 0),
           canvas.xlim = c(-1.15, 1.15), canvas.ylim = c(-1.15, 1.15))
circos.initialize(factors = factor(diseases, levels = diseases),
                  xlim = cbind(rep(0, length(diseases)), disease_n))
label_rows <- do.call(rbind, lapply(split(d18, factor(d18$group, levels = diseases)), function(x) {
  head(x[order(-x$score), ], 3)
}))
label_data <- data.frame(group = label_rows$group, start = label_rows$x - 0.1,
                         end = label_rows$x + 0.1, gene = label_rows$gene)
circos.genomicLabels(label_data, labels.column = 4, facing = 'reverse.clockwise',
                     side = 'outside', cex = 0.60, col = label_rows$colour,
                     connection_height = convert_height(2.0, 'mm'), line_lwd = 0.28)
circos.trackPlotRegion(ylim = c(0, 1), track.height = 0.07,
  bg.col = '#E9E9E9', bg.border = '#333333', bg.lwd = 0.5,
  panel.fun = function(x, y) {
    circos.text(CELL_META$xcenter, 0.52, CELL_META$sector.index,
                facing = 'bending.inside', niceFacing = TRUE,
                cex = 0.62, family = 'Helvetica')
  })
circos.trackPlotRegion(ylim = c(0, 1.05), track.height = 0.36,
  bg.border = '#333333', bg.lwd = 0.5,
  panel.fun = function(x, y) {
    v <- d18[d18$group == CELL_META$sector.index, ]
    circos.lines(c(CELL_META$xlim[1], CELL_META$xlim[2]), c(0.2, 0.2),
                 col = '#D4D8DC', lwd = 0.5)
    for (j in seq_len(nrow(v))) {
      circos.lines(rep(v$x[j], 2), c(0, v$score[j]), col = v$colour[j], lwd = 0.85)
      circos.points(v$x[j], v$score[j], pch = 16, col = v$colour[j], cex = 0.36)
    }
    if (CELL_META$sector.index == diseases[1]) {
      circos.yaxis(side = 'left', at = seq(0, 1, by = 0.2), labels.cex = 0.42,
                   tick.length = convert_length(1.0, 'mm'))
    }
  })
for (i in seq_len(nrow(link_pairs))) {
  z <- link_pairs[i, ]
  circos.link(z$from, z$x1, z$to, z$x2,
              col = adjustcolor('#496473', alpha.f = 0.46),
              border = NA, lwd = 0.48)
}
circos.clear()
dev.off()
write.csv(d18[, c('group', 'x', 'gene', 'score', 'direction')],
          file.path(data_dir, '18_circular_lollipop_links.csv'), row.names = FALSE)
write.csv(link_pairs, file.path(data_dir, '18_circular_lollipop_links_edges.csv'), row.names = FALSE)
message('Rendered cases 16-18 with source-method structure')
