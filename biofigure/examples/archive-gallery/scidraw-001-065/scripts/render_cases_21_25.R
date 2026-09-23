#!/usr/bin/env Rscript
# Independent, seeded method studies of SciDraw SCICASE-044/046/058/061/136.
# All observations below are simulated; source code and source data are not copied.
suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
  library(ggrepel)
  library(ggbeeswarm)
  library(ragg)
})
set.seed(20260920)
script_arg <- grep('^--file=', commandArgs(FALSE), value = TRUE)
root <- normalizePath(file.path(dirname(sub('^--file=', '', script_arg)), '..'))
fig_dir <- file.path(root, 'results', 'figures')
data_dir <- file.path(root, 'results', 'plot_data')
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
save_fig <- function(name, plot, width, height) {
  ggsave(file.path(fig_dir, name), plot, width = width, height = height,
         dpi = 220, device = ragg::agg_png, bg = 'white')
}
base_font <- 'Helvetica'
plain_theme <- function() theme_classic(base_family = base_font, base_size = 9) +
  theme(axis.title = element_text(size = 10), axis.text = element_text(size = 8),
        legend.title = element_text(size = 9, face = 'bold'),
        legend.text = element_text(size = 8),
        strip.text = element_text(size = 9, face = 'bold'),
        plot.margin = margin(9, 12, 9, 9))

# 21: two independently scaled heatmaps plus an aligned factor-class strip.
states <- c('Immature', 'Neutrophil', 'Monocyte P.', 'Monocyte',
            'Eosinophil', 'Basophil', 'MegEry')
sets <- c('Set 1 (single f.)', 'Set 1 (pairs)', 'Set 2 (single factors)')
counts <- c(11L, 30L, 19L)
features <- unlist(Map(function(prefix, n) sprintf('%s%02d', prefix, seq_len(n)),
                       c('S1_', 'P_', 'S2_'), counts))
feature_set <- rep(sets, counts)
heat <- expand.grid(feature = features, state = states, stringsAsFactors = FALSE)
heat$set <- feature_set[match(heat$feature, features)]
heat$active <- pmin(100, rgamma(nrow(heat), shape = 0.9, scale = 27))
heat$repressed <- pmin(35, rgamma(nrow(heat), shape = 0.8, scale = 8))
heat$active_sig <- heat$active > 57
heat$repressed_sig <- heat$repressed > 23
heat$feature <- factor(heat$feature, levels = features)
heat$state <- factor(heat$state, levels = rev(states))
heat$set <- factor(heat$set, levels = sets)
class_df <- aggregate(cbind(active_sig, repressed_sig) ~ feature + set, heat, any)
class_df$class <- with(class_df, ifelse(active_sig & repressed_sig, 'Dual',
                                ifelse(active_sig, 'Activator',
                                  ifelse(repressed_sig, 'Repressor', 'Other'))))
class_df$class <- factor(class_df$class,
                         levels = c('Activator', 'Dual', 'Repressor', 'Other'))
heat_theme <- theme_bw(base_family = base_font, base_size = 8) +
  theme(panel.grid = element_blank(), panel.spacing.x = unit(1.1, 'mm'),
        strip.background = element_rect(fill = '#E8E8E8', linewidth = 0.25),
        strip.text = element_text(size = 8), axis.text.y = element_text(size = 7.5),
        axis.title.y = element_text(size = 9), axis.ticks.x = element_blank(),
        legend.title = element_text(size = 8), legend.text = element_text(size = 7.5),
        plot.margin = margin(1, 3, 1, 3))
heat_panel <- function(column, sig, cols, max_val, legend_title) {
  ggplot(heat, aes(feature, state)) +
    geom_tile(aes(fill = .data[[column]]), width = 1, height = 1) +
    geom_point(data = heat[heat[[sig]], ], shape = 16, colour = 'white', size = 0.42) +
    scale_fill_gradientn(colours = cols, limits = c(0, max_val),
                         oob = scales::squish, name = legend_title,
                         guide = guide_colorbar(barheight = unit(19, 'mm'),
                                                barwidth = unit(3.2, 'mm'))) +
    facet_grid(~set, scales = 'free_x', space = 'free_x') +
    labs(x = NULL, y = 'Cell state') + heat_theme +
    theme(axis.text.x = element_blank(), strip.text = element_text(size = 8))
}
p21a <- heat_panel('active', 'active_sig', c('#0C0504', '#8C1D05', '#FF3308', '#FFC444'),
                   100, '% active')
p21b <- heat_panel('repressed', 'repressed_sig',
                   c('#090716', '#22118E', '#513DD2', '#62D87C'), 35, '% repressed') +
  theme(strip.text = element_blank(), strip.background = element_blank())
p21c <- ggplot(class_df, aes(feature, 1, fill = class)) +
  geom_tile(width = 1, height = 0.95) +
  facet_grid(~set, scales = 'free_x', space = 'free_x') +
  scale_fill_manual(values = c(Activator = '#66C2A5', Dual = '#FC8D62',
                               Repressor = '#E78AC3', Other = '#8DA0CB'),
                    name = 'Factor-level class') +
  labs(x = NULL, y = NULL) + heat_theme +
  theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5, size = 7),
        axis.text.y = element_blank(), axis.ticks.y = element_blank(),
        strip.text = element_blank(), strip.background = element_blank())
p21 <- (p21a / p21b / p21c) + plot_layout(heights = c(3.3, 3.3, 1.65))
save_fig('21_faceted_dual_heatmap.png', p21, 16.5, 6.6)
write.csv(heat, file.path(data_dir, '21_faceted_dual_heatmap.csv'), row.names = FALSE)

# 22: the threshold is a hyperbola in effect-size versus -log10(P) space.
n22 <- 3600L
vol <- data.frame(gene = sprintf('GENE%04d', seq_len(n22)),
                  epsilon = pmax(-3.1, pmin(3.1, rnorm(n22, 0, 0.78))))
vol$mlog10p <- pmin(4.1, rexp(n22, rate = 1.65) +
                       pmax(0, abs(vol$epsilon) - 0.45) * runif(n22, 0.7, 1.55))
vol$mlog10p[sample(n22, 28)] <- runif(28, 2.5, 4.0)
threshold <- 1.33
vol$group <- ifelse(abs(vol$epsilon) * vol$mlog10p > threshold,
                    ifelse(vol$epsilon > 0, 'Positive hits', 'Negative hits'), 'Other genes')
vol$group[sample(which(vol$group == 'Other genes'), 180)] <- 'Non-targeting'
vol$pathway <- NA_character_
top_hits <- which(vol$group %in% c('Positive hits', 'Negative hits'))
top_hits <- top_hits[order(vol$mlog10p[top_hits], decreasing = TRUE)][seq_len(min(20, length(top_hits)))]
pathways <- c('GPI anchor', 'Ubiquitin/Proteasome', 'Autophagy',
              'Negative autophagy regulators', 'Mitochondria', 'UFMylation')
vol$pathway[top_hits] <- rep(pathways, length.out = length(top_hits))
lab22 <- vol[top_hits[seq_len(min(14, length(top_hits)))], ]
lab22$gene <- sprintf('G%02d', seq_len(nrow(lab22)))
vol$gene[as.integer(rownames(lab22))] <- lab22$gene
path_cols <- c('GPI anchor' = '#164BC4', 'Ubiquitin/Proteasome' = '#8922C2',
               Autophagy = '#2A9F55', 'Negative autophagy regulators' = '#66B657',
               Mitochondria = '#DB4F33', UFMylation = '#C68022')
curve <- data.frame(x = seq(-3.2, 3.2, length.out = 600))
curve <- subset(curve, abs(x) > 0.3)
curve$y <- threshold / abs(curve$x)
p22 <- ggplot(vol, aes(epsilon, mlog10p)) +
  geom_point(data = subset(vol, group == 'Other genes'),
             aes(colour = group), alpha = 0.13, size = 0.7) +
  geom_point(data = subset(vol, group == 'Non-targeting'),
             aes(colour = group), alpha = 0.45, size = 0.75) +
  geom_point(data = subset(vol, group == 'Positive hits'),
             aes(colour = group), alpha = 0.62, size = 1.0) +
  geom_point(data = subset(vol, group == 'Negative hits'),
             aes(colour = group), alpha = 0.65, size = 1.0) +
  geom_line(data = curve, aes(x, y, group = x > 0),
            inherit.aes = FALSE, linewidth = 0.45, linetype = 'dotted') +
  geom_vline(xintercept = c(-0.3, 0.3), linetype = 'dotted', linewidth = 0.35) +
  geom_point(data = subset(vol, !is.na(pathway)), aes(fill = pathway),
             shape = 21, colour = '#1D1D1D', size = 2, stroke = 0.4) +
  scale_fill_manual(values = path_cols, name = 'Pathway') +
  scale_colour_manual(values = c('Other genes' = '#252525',
                                 'Non-targeting' = '#9B9B9B',
                                 'Positive hits' = '#C89BC9',
                                 'Negative hits' = '#91C9DC'),
                      breaks = c('Other genes', 'Non-targeting',
                                 'Positive hits', 'Negative hits'),
                      name = 'Significant') +
  ggrepel::geom_text_repel(data = lab22, aes(label = gene), size = 2.8,
                           family = base_font, fontface = 'italic',
                           max.overlaps = Inf, min.segment.length = 0,
                           box.padding = 0.2, point.padding = 0.15,
                           seed = 20260920, show.legend = FALSE) +
  coord_cartesian(xlim = c(-3.35, 3.35), ylim = c(0, 4.25), clip = 'off') +
  scale_x_continuous(breaks = -3:3) +
  labs(x = 'Knockdown phenotype (AU)', y = expression(-log[10](P))) +
  plain_theme() + theme(legend.position = 'right', legend.key.size = unit(4.2, 'mm'))
save_fig('22_hyperbolic_volcano.png', p22, 11.3, 5.6)
write.csv(vol, file.path(data_dir, '22_hyperbolic_volcano.csv'), row.names = FALSE)

# 23: diagonal RNA/translation decision bands are geometric, not quadrant labels alone.
n23 <- 750L
qdat <- data.frame(gene = sprintf('G%03d', seq_len(n23)),
                   total = pmax(-5, pmin(5, rnorm(n23, 0, 1.35))))
qdat$poly <- pmax(-5, pmin(5, qdat$total * 0.88 + rnorm(n23, 0, 0.62)))
qdat$delta <- qdat$poly - qdat$total
qdat$mode <- ifelse(abs(qdat$delta) > 0.7, 'translation',
                    ifelse(abs(qdat$total) > 0.7, 'abundance', 'offsetting'))
qdat$class <- with(qdat, ifelse(mode == 'translation',
                        ifelse(delta > 0, 'Translation up', 'Translation down'),
                        ifelse(mode == 'abundance',
                          ifelse(total > 0, 'RNA abundance up', 'RNA abundance down'),
                          ifelse(total * poly < 0,
                                 ifelse(total > 0, 'Offsetting (RNA up)',
                                        'Offsetting (RNA down)'), 'Background'))))
qcols <- c('Translation up' = '#ED9A78', 'Translation down' = '#8F302C',
           'RNA abundance up' = '#94D9AB', 'RNA abundance down' = '#285947',
           'Offsetting (RNA up)' = '#BBD8E8',
           'Offsetting (RNA down)' = '#42699B', Background = '#B8B8B8')
qdat$class <- factor(qdat$class, levels = names(qcols))
q_lab <- qdat[order(abs(qdat$total) + abs(qdat$poly), decreasing = TRUE)[1:7], ]
q_lab$gene <- sprintf('G%02d', seq_len(nrow(q_lab)))
counter <- as.data.frame(table(qdat$class), stringsAsFactors = FALSE)
counter <- counter[counter$Freq > 0 & counter$Var1 != 'Background', ]
names(counter) <- c('class', 'n')
counter$label <- paste0(counter$class, ': ', counter$n)
counter$x <- c(-4.65, -4.65, 4.0, 4.0, -4.65, 4.0)[seq_len(nrow(counter))]
counter$y <- c(4.7, 4.05, -3.0, -3.65, 3.4, -4.3)[seq_len(nrow(counter))]
p23 <- ggplot(qdat, aes(total, poly)) +
  geom_point(colour = '#C5C5C5', size = 1.05, alpha = 0.65) +
  geom_point(data = subset(qdat, class != 'Background'), aes(colour = class),
             size = 1.2, alpha = 0.85) +
  geom_hline(yintercept = 0, linetype = 'dashed', linewidth = 0.35) +
  geom_vline(xintercept = 0, linetype = 'dashed', linewidth = 0.35) +
  geom_abline(intercept = 0, linetype = 'dashed', linewidth = 0.35) +
  geom_hline(yintercept = c(-0.5, 0.5), linewidth = 0.45) +
  geom_vline(xintercept = c(-0.5, 0.5), linewidth = 0.45) +
  geom_abline(intercept = c(-0.5, 0.5), linewidth = 0.45) +
  geom_tile(data = counter, aes(x, y, fill = class),
            inherit.aes = FALSE, width = 0.46, height = 0.46,
            colour = '#2B2B2B', linewidth = 0.3) +
  geom_text(data = counter, aes(x + 0.31, y, label = n),
            inherit.aes = FALSE, hjust = 0, size = 2.8, family = base_font) +
  ggrepel::geom_text_repel(data = q_lab, aes(label = gene),
                           colour = '#161616', size = 3, family = base_font,
                           seed = 20260920, min.segment.length = 0,
                           max.overlaps = Inf, box.padding = 0.25,
                           segment.colour = '#B1392E') +
  scale_colour_manual(values = qcols, name = NULL,
                      breaks = setdiff(names(qcols), 'Background')) +
  scale_fill_manual(values = qcols, guide = 'none') +
  scale_x_continuous(breaks = seq(-4, 4, 2)) +
  scale_y_continuous(breaks = seq(-4, 4, 2)) +
  coord_equal(xlim = c(-5.2, 5.2), ylim = c(-5.2, 5.2), clip = 'off') +
  labs(title = 'Simulated RNA–translation comparison',
       x = expression('Total RNA ('*log[2]*'FC)'),
       y = expression('Polysome-associated RNA ('*log[2]*'FC)')) +
  plain_theme() +
  theme(plot.title = element_text(size = 11, hjust = 0.5),
        legend.position = 'right', legend.key.size = unit(4.5, 'mm'))
save_fig('23_rna_translation_quadrants.png', p23, 9.5, 7.6)
write.csv(qdat, file.path(data_dir, '23_rna_translation_quadrants.csv'), row.names = FALSE)

# 24: one high-density quasi-random point field for 21 cell classes.
cell_types <- c('Neural cell', 'Megakaryocyte', 'Fibroblast', 'Macrophage',
                'Neutrophil', 'Haem progenitor', 'DC', 'Melanocyte', 'ILC',
                'Skeletal muscle', 'Mural cell', 'Vascular endothelium',
                'Monocyte', 'Schwann cell', 'Adipocyte', 'Mast cell', 'Erythroid',
                'Lymphatic endothelium', 'Keratinocyte', 'T cell', 'B cell')
cell_cols <- c('#D7B5BB','#B7BACE','#C7E2DF','#079E39','#EA7389',
               '#ADB5DA','#F3AD85','#EB8701','#446AAD','#E22B69',
               '#74B985','#B7D7C0','#7A82B4','#81C5C5','#C57180',
               '#004892','#7E8EC5','#9C1543','#ECCDC1','#EDA4B0','#00ABA7')
cell_data <- do.call(rbind, lapply(seq_along(cell_types), function(i) {
  n <- sample(190:320, 1)
  mu <- c(-.42,.08,.49,.42,.31,.28,.45,.39,.58,.43,.5,.46,
          .41,.39,.55,.46,.35,.43,.49,.48,.44)[i]
  early_fraction <- c(.82,.16,.40,.34,.28,.25,.18,.16,.30,.25,.11,
                      .13,.15,.20,.11,.12,.18,.13,.15,.14,.11)[i]
  n_early <- round(n * early_fraction)
  x <- c(rnorm(n - n_early, mu, 0.13),
         rnorm(n_early, ifelse(i == 1, -0.48, -0.37), 0.16))
  data.frame(cell_type = cell_types[i], logFC = pmax(-1.05, pmin(1.05, x)))
}))
cell_data$cell_type <- factor(cell_data$cell_type, levels = rev(cell_types))
cell_data$stage <- ifelse(cell_data$logFC < 0, 'Early', 'Late')
stripe <- data.frame(cell_type = factor(cell_types, levels = rev(cell_types)),
                     col = cell_cols)
p24 <- ggplot(cell_data, aes(logFC, cell_type)) +
  geom_vline(xintercept = 0, linetype = 'dashed', colour = '#9B9B9B', linewidth = 0.35) +
  ggbeeswarm::geom_quasirandom(aes(colour = stage),
                              size = 0.45, alpha = 0.65,
                              groupOnX = FALSE, width = 0.36) +
  geom_tile(data = stripe, aes(x = -1.16, y = cell_type),
            inherit.aes = FALSE, width = 0.055, height = 0.75,
            fill = stripe$col, show.legend = FALSE) +
  scale_colour_manual(values = c(Early = '#BF827B', Late = '#7779BC'), guide = 'none') +
  scale_x_continuous(breaks = c(-1, 0, 1), limits = c(-1.2, 1.12)) +
  labs(x = 'log(fold change)', y = NULL) +
  plain_theme() +
  annotate('segment', x = -0.02, xend = -0.56, y = 0.10, yend = 0.10,
           colour = '#BD817D', linewidth = 0.7,
           arrow = grid::arrow(length = unit(2.3, 'mm'))) +
  annotate('segment', x = 0.02, xend = 0.56, y = 0.10, yend = 0.10,
           colour = '#7779BC', linewidth = 0.7,
           arrow = grid::arrow(length = unit(2.3, 'mm'))) +
  annotate('text', x = -0.82, y = 0.10, label = 'Early gestation',
           hjust = 0.5, size = 2.8, family = base_font) +
  annotate('text', x = 0.84, y = 0.10, label = 'Late gestation',
           hjust = 0.5, size = 2.8, family = base_font) +
  expand_limits(y = -0.2) +
  theme(axis.text.y = element_text(size = 9), axis.ticks.y = element_blank(),
        axis.line.y = element_blank(), plot.margin = margin(8, 16, 10, 8))
save_fig('24_cell_abundance_beeswarm.png', p24, 9.4, 10.8)
write.csv(cell_data, file.path(data_dir, '24_cell_abundance_beeswarm.csv'), row.names = FALSE)

# 25: shared family order and colour across three vertically aligned comparisons.
orders <- c('Burkholderiales','Chitinophagales','Sphingomonadales',
            'Rhizobiales','Pseudomonadales','Bacillales','Clostridiales',
            'Flavobacteriales','Rickettsiales','Verrucomicrobiales',
            'Peptostreptococcales','Acetobacterales','Actinomycetales',
            'Caulobacterales','Oscillatoriales','Planctomycetales',
            'Myxococcales','Desulfovibrionales','Bacteroidales',
            'Chromatiales','Nitrosomonadales','Enterobacterales',
            'Lactobacillales','Fusobacteriales','Xanthomonadales')
order_cols <- c('#DD504E','#EB784C','#F3A13D','#F5D46B','#D8F090',
                '#B0D6A7','#69C477','#8BB2C3','#3881AE','#DACCE3',
                '#AC87BD','#EBC5DE','#CE73B0','#BA4093','#CCDEB6',
                '#A1C273','#658B3C','#F2E7C9','#DEC575','#947A23',
                '#87D1D0','#41ABA9','#B5C4D7','#879EBE','#9A9192')
comparisons <- c('B_AZM vs B', 'Co_FL_AZM vs Co_FL', 'Co_PS_AZM vs Co_PS')
bubble <- do.call(rbind, lapply(seq_along(comparisons), function(k) {
  do.call(rbind, lapply(seq_along(orders), function(i) {
    n <- sample(4:9, 1)
    data.frame(comparison = comparisons[k], order = orders[i],
               family = paste0(substr(orders[i], 1, 5), '_', seq_len(n)),
               x = i + runif(n, -0.28, 0.28),
               log2FC = pmax(-4.1, pmin(4.1, rnorm(n, 0, 0.85) +
                                    ifelse(i <= 3, runif(1, -0.4, 0.4), 0))),
               abundance = ifelse(runif(n) < 0.08,
                                  runif(n, 0.05, 0.12), runif(n, 0.002, 0.025)),
               significant = runif(n) < 0.28)
  }))
}))
bubble$comparison <- factor(bubble$comparison, levels = comparisons)
bubble$color <- order_cols[match(bubble$order, orders)]
bubble$fill <- ifelse(bubble$significant, bubble$color, '#FFFFFF')
panel_label <- data.frame(comparison = factor(comparisons, levels = comparisons),
                          x = 25.35, log2FC = -3.55, label = comparisons)
p25 <- ggplot(bubble, aes(x, log2FC)) +
  geom_hline(yintercept = 0, colour = '#A0A0A0', linewidth = 0.27) +
  geom_vline(xintercept = seq(1.5, 24.5, 1), colour = '#E7E7E7', linewidth = 0.19) +
  geom_point(aes(size = abundance, fill = fill, colour = color),
             shape = 21, stroke = 0.42, alpha = 0.87) +
  geom_text(data = panel_label, aes(x, log2FC, label = label),
            inherit.aes = FALSE, hjust = 1, vjust = 0, size = 3.1,
            family = base_font) +
  scale_fill_identity() + scale_colour_identity() +
  scale_size_area(max_size = 7.5, guide = 'none') +
  facet_grid(comparison ~ .) +
  scale_x_continuous(breaks = seq_along(orders), labels = orders,
                     expand = expansion(add = 0.55)) +
  scale_y_continuous(breaks = c(-4, -2, 0, 2, 4)) +
  coord_cartesian(ylim = c(-4.2, 4.2), clip = 'off') +
  labs(x = NULL, y = expression(log[2]*'(FCs)')) +
  theme_bw(base_family = base_font, base_size = 9) +
  theme(panel.grid = element_blank(), panel.spacing.y = unit(1.7, 'mm'),
        strip.background = element_blank(), strip.text.y = element_blank(),
        axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5, size = 7),
        axis.text.y = element_text(size = 8), axis.title.y = element_text(size = 10),
        plot.margin = margin(8, 9, 10, 6))
save_fig('25_otu_bubble_manhattan.png', p25, 13.4, 9.9)
write.csv(bubble[, c('comparison','order','family','x','log2FC','abundance','significant')],
          file.path(data_dir, '25_otu_bubble_manhattan.csv'), row.names = FALSE)
message('Rendered cases 21-25')
