#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(ape)
  library(ggtree)
  library(ggtreeExtra)
  library(ggnewscale)
  library(ggplot2)
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

phylum_names <- c('Proteobacteria', 'Bacteroidota', 'Actinobacteriota',
                  'Cyanobacteria', 'Firmicutes', 'Planctomycetota',
                  'Chloroflexota', 'Verrucomicrobiota', 'Acidobacteriota',
                  'Campylobacterota')
phylum_cols <- setNames(c('#ED6A23', '#D9423D', '#F2AA78', '#008A83', '#9B7C5D',
                          '#57B5D4', '#9ED7C4', '#7081A5', '#8B6753', '#A698C6'),
                        phylum_names)

descendant_tips <- function(tree, node) {
  children <- tree$edge[tree$edge[, 1] == node, 2]
  if (!length(children)) return(node)
  unlist(lapply(children, function(x) if (x <= length(tree$tip.label)) x
                else descendant_tips(tree, x)))
}
choose_clades <- function(tree, target) {
  clades <- length(tree$tip.label) + 1L
  while (length(clades) < target) {
    sizes <- vapply(clades, function(x) length(descendant_tips(tree, x)), integer(1))
    split_i <- which.max(sizes)
    node <- clades[split_i]
    kids <- tree$edge[tree$edge[, 1] == node, 2]
    if (length(kids) != 2) break
    clades <- append(clades[-split_i], kids)
  }
  clades
}
make_tree_data <- function(n, seed) {
  set.seed(seed)
  tr <- ape::rtree(n)
  tr$tip.label <- sprintf('MAG_%03d', seq_len(n))
  clades <- choose_clades(tr, 10)
  groups <- lapply(clades, function(x) tr$tip.label[descendant_tips(tr, x)])
  names(groups) <- phylum_names
  anno <- data.frame(ID = tr$tip.label, Phylum = NA_character_)
  for (k in seq_along(groups)) anno$Phylum[anno$ID %in% groups[[k]]] <- names(groups)[k]
  stopifnot(!anyNA(anno$Phylum))
  list(tree = tr, grouped = ggtree::groupOTU(tr, groups), anno = anno)
}

x19 <- make_tree_data(700, 19)
a19 <- x19$anno
a19$Genome <- sample(c('WGS', 'MAG', 'SAG'), nrow(a19), TRUE,
                     prob = c(0.47, 0.38, 0.15))
a19$Presence <- sample(c('>=10 samples', '1-9 samples', 'Absent'), nrow(a19), TRUE,
                       prob = c(0.25, 0.41, 0.34))
stopifnot(nrow(a19) == length(x19$tree$tip.label),
          setequal(a19$ID, x19$tree$tip.label),
          all(a19$Phylum %in% names(phylum_cols)))
genome_cols <- c(WGS = '#252525', MAG = '#ED7A20', SAG = '#3977A8')
presence_cols <- c('>=10 samples' = '#087B38', '1-9 samples' = '#77BD81',
                   Absent = '#F5F6F5')
p19 <- ggtree::ggtree(x19$grouped, layout = 'fan', open.angle = 10,
                      aes(colour = factor(group)), linewidth = 0.38) +
  scale_colour_manual(values = phylum_cols, na.value = '#343A40', guide = 'none') +
  ggnewscale::new_scale_fill() +
  ggtreeExtra::geom_fruit(data = a19, geom = geom_tile,
                          mapping = aes(y = ID, fill = Genome),
                          offset = 0.027, pwidth = 0.055, width = 0.8, colour = NA) +
  scale_fill_manual(values = genome_cols, name = 'Genome type') +
  ggnewscale::new_scale_fill() +
  ggtreeExtra::geom_fruit(data = a19, geom = geom_tile,
                          mapping = aes(y = ID, fill = Phylum),
                          offset = 0.035, pwidth = 0.055, width = 0.8, colour = NA) +
  scale_fill_manual(values = phylum_cols, name = 'Phylum', breaks = phylum_names) +
  ggnewscale::new_scale_fill() +
  ggtreeExtra::geom_fruit(data = a19, geom = geom_tile,
                          mapping = aes(y = ID, fill = Presence),
                          offset = 0.035, pwidth = 0.055, width = 0.8, colour = NA) +
  scale_fill_manual(values = presence_cols, name = 'Occurrence') +
  theme(legend.position = 'right', legend.text = element_text(size = 8),
        legend.title = element_text(size = 9, face = 'bold'),
        legend.key.height = unit(4, 'mm'),
        plot.margin = margin(10, 12, 10, 5))
ggsave(file.path(fig_dir, '19_phylogeny_three_heatmaps.png'), p19,
       width = 11.5, height = 7.9, dpi = 200, device = ragg::agg_png, bg = 'white')
write.csv(a19, file.path(data_dir, '19_phylogeny_three_heatmaps.csv'), row.names = FALSE)

x20 <- make_tree_data(600, 20)
a20 <- x20$anno
a20$Coefficient <- pmax(0.025, rbeta(nrow(a20), 1.7, 5.5) * 0.75)
a20$PresenceA <- sample(c('Yes', 'No'), nrow(a20), TRUE, prob = c(.64, .36))
a20$PresenceB <- sample(c('Yes', 'No'), nrow(a20), TRUE, prob = c(.43, .57))
eco20 <- rbind(data.frame(ASV = a20$ID, Phylum = a20$Phylum,
                          Ecosystem = 'Environment A', Presence = a20$PresenceA),
               data.frame(ASV = a20$ID, Phylum = a20$Phylum,
                          Ecosystem = 'Environment B', Presence = a20$PresenceB))
b20 <- data.frame(ASV = a20$ID, Phylum = a20$Phylum,
                  Coefficient = a20$Coefficient)
stopifnot(nrow(eco20) == 2 * length(x20$tree$tip.label),
          all(table(eco20$ASV) == 2),
          setequal(b20$ASV, x20$tree$tip.label),
          all(is.finite(b20$Coefficient) & b20$Coefficient > 0))
p20 <- ggtree::ggtree(x20$tree, layout = 'fan', open.angle = 10,
                      colour = '#292929', linewidth = 0.23) +
  ggtreeExtra::geom_fruit(data = eco20, geom = geom_tile,
                          mapping = aes(y = ASV, x = Ecosystem,
                                        fill = Phylum, alpha = Presence),
                          offset = 0.025, pwidth = 0.12, width = 0.86, colour = NA) +
  scale_fill_manual(values = phylum_cols, name = 'Phylum', breaks = phylum_names) +
  scale_alpha_manual(values = c(Yes = 0.95, No = 0.18), name = 'Presence') +
  ggnewscale::new_scale_fill() +
  ggtreeExtra::geom_fruit(data = b20, geom = geom_col,
                          mapping = aes(y = ASV, x = Coefficient, fill = Phylum),
                          orientation = 'y', offset = 0.025, pwidth = 0.16,
                          width = 0.8, colour = NA) +
  scale_fill_manual(values = phylum_cols, guide = 'none') +
  theme(legend.position = 'right', legend.text = element_text(size = 8),
        legend.title = element_text(size = 9, face = 'bold'),
        legend.key.height = unit(4, 'mm'),
        plot.margin = margin(10, 10, 10, 5))
ggsave(file.path(fig_dir, '20_phylogeny_heatmap_bar.png'), p20,
       width = 11.5, height = 8.1, dpi = 200, device = ragg::agg_png, bg = 'white')
write.csv(a20, file.path(data_dir, '20_phylogeny_heatmap_bar.csv'), row.names = FALSE)
message('Rendered cases 19-20 with grouped fan tree and aligned outer tracks')
