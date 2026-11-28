# Reproduce Bizard Advanced Enrichment Analysis Barplot (p2).
# Rscript --vanilla render.R plot_data.csv bizard-rounded-enrichment
# R packages: ggplot2, ragg, systemfonts, gground (and Arial).
# gground version used: remotes::install_github("dxsbiocc/gground@b809d7446b429893a601c881a46cc605a7295b73")
# Author source: https://github.com/openbiox/Bizard/blob/main/Omics/TextEnrichmentBarPlot.qmd#L265-L315
suppressPackageStartupMessages(library(ggplot2))

args <- commandArgs(TRUE)
stopifnot(length(args) %in% c(2L, 4L))
self <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))
local_library <- file.path(dirname(self), "R-library")
if (dir.exists(local_library)) .libPaths(c(local_library, .libPaths()))
input <- normalizePath(args[1])
out <- args[2]

font <- "Arial"
stopifnot(font %in% systemfonts::system_fonts()$family)
category_colors <- c(BP = "#B0DCCF", CC = "#C7D8EB", MF = "#D9CBE7", KEGG = "#DFC1CD")
gene_colors <- c(BP = "#276458", CC = "#365981", MF = "#684F7C", KEGG = "#78485C")
ink <- "#20232B"
edge <- "#505765"
width <- 183
height <- 158
origin <- -22
right <- origin + width
axis_base <- 9.8
x_scale <- 11
group_gap <- 1.55
gene_line <- 2.70

d <- read.csv(input, stringsAsFactors = FALSE)
d <- d[order(d$display_order), ]
stopifnot(nrow(d) == 20L, !anyDuplicated(d$term_id), all(d$count > 0),
          all(d$fdr > 0 & d$fdr <= 1), all(abs(d$log10_fdr + log10(d$fdr)) < 1e-9),
          identical(rle(d$category)$values, names(category_colors)),
          all(lengths(strsplit(d$gene_symbols, ", ", fixed = TRUE)) == d$count),
          identical(gsub("\n", " ", d$gene_label), d$gene_symbols))
groups_before <- cumsum(c(0, head(d$category, -1) != tail(d$category, -1)))
wrapped <- strsplit(d$gene_label, "\n", fixed = TRUE)
step <- 6.24 + gene_line * (lengths(wrapped) - 1L)
d$y <- 153.4 - c(0, cumsum(head(step, -1))) - group_gap * groups_before
gene_rows <- do.call(rbind, lapply(seq_len(nrow(d)), function(i) {
  data.frame(category = d$category[i], label = wrapped[[i]],
             y = d$y[i] - 2.85 - gene_line * (seq_along(wrapped[[i]]) - 1L))
}))
bands <- do.call(rbind, lapply(names(category_colors), function(category) {
  in_group <- d$category == category
  span <- c(min(gene_rows$y[gene_rows$category == category]) - 1.0, max(d$y[in_group]) + 2.1)
  data.frame(category = category, ymin = span[1], ymax = span[2], y = mean(span))
}))
ticks <- data.frame(value = seq(0, 12, 2))
ticks$x <- x_scale * ticks$value
key <- data.frame(x = 143.5, y = c(78, 70, 62), count = c(10, 20, 30))
rule_end <- 12.32 * x_scale
stopifnot(min(gene_rows$y) > axis_base + 2.2, max(d$log10_fdr) * x_scale < rule_end)

plot <- ggplot() +
  # Native rounded columns and category blocks, as in the author's p2.
  gground::geom_round_col(data = d, aes(x = x_scale * log10_fdr, y = y, fill = category),
                         position = "identity", orientation = "y", width = 3.5,
                         radius = grid::unit(.75, "mm"), colour = NA) +
  gground::geom_round_rect(data = bands,
    aes(xmin = -19.8, xmax = -9.1, ymin = ymin, ymax = ymax, fill = category),
    radius = grid::unit(1.5, "mm"), colour = NA) +
  geom_point(data = d, aes(x = -4.9, y = y, size = count, fill = category),
             shape = 21, colour = edge, stroke = .22) +
  geom_text(data = bands, aes(x = -14.45, y = y, label = category),
            family = font, fontface = "bold", colour = ink, size = 8.5, size.unit = "pt") +
  geom_text(data = d, aes(x = -4.9, y = y, label = count),
            family = font, colour = ink, size = 7, size.unit = "pt") +
  geom_text(data = d, aes(x = 1.15, y = y, label = term), hjust = 0,
            family = font, fontface = "bold.italic", colour = ink, size = 8.2, size.unit = "pt") +
  geom_text(data = gene_rows, aes(x = 1.15, y = y, label = label, colour = category), hjust = 0,
            family = font, fontface = "italic", size = 7, size.unit = "pt") +
  annotate("segment", x = 0, xend = rule_end, y = axis_base, yend = axis_base,
           colour = ink, linewidth = .37) +
  geom_segment(data = ticks, aes(x = x, xend = x), y = axis_base, yend = axis_base - 1.3,
               colour = ink, linewidth = .29) +
  geom_text(data = ticks, aes(x = x, label = value), y = axis_base - 2.9,
            family = font, colour = ink, size = 7.5, size.unit = "pt") +
  annotate("text", x = rule_end / 2, y = 3, label = "-log10(FDR)",
           family = font, fontface = "bold", colour = ink, size = 9, size.unit = "pt") +
  annotate("text", x = 140.9, y = 84.6, label = "Count", hjust = 0,
           family = font, fontface = "bold", colour = ink, size = 8.5, size.unit = "pt") +
  geom_point(data = key, aes(x = x, y = y, size = count),
             shape = 21, fill = "white", colour = edge, stroke = .22) +
  geom_text(data = key, aes(x = x + 5.7, y = y, label = count), hjust = 0,
            family = font, colour = ink, size = 7.5, size.unit = "pt") +
  scale_size_area(max_size = 7.8, limits = c(0, max(d$count)), guide = "none") +
  scale_fill_manual(values = category_colors, guide = "none") +
  scale_colour_manual(values = gene_colors, guide = "none") +
  coord_fixed(xlim = c(origin, right), ylim = c(0, height), expand = FALSE) +
  theme_void(base_family = font) +
  theme(plot.background = element_rect(fill = "white", colour = NA),
        plot.margin = margin(0, 0, 0, 0))

# Verify that the rounded columns retain all exact zero-to-FDR spans.
built <- ggplot_build(plot)
bars <- built$data[[1]]
stopifnot(nrow(bars) == nrow(d), all(bars$xmin == 0),
          all(abs(bars$xmax - x_scale * d$log10_fdr) < 1e-8),
          all(abs(bars$y - d$y) < 1e-8))
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)

if (length(args) == 4L) {
  skill <- Sys.getenv("BIOFIGURE_ROOT", file.path(path.expand("~"), ".codex", "skills", "biofigure"))
  helper <- file.path(skill, "scripts", "figure_style.R")
  source(helper)
  spec_path <- normalizePath(args[3])
  prep <- normalizePath(args[4])
  spec <- yaml::read_yaml(spec_path)
  sources <- c(spec_path, self, normalizePath(helper), input, spec$reference_evidence$primary_source_lock)
  auth <- paste0(out, ".authorization.json")
  command <- c(file.path(skill, "scripts", "authorize_render.py"), "--receipt", prep,
     "--design-spec", spec_path, "--output", auth,
     unlist(lapply(sources[-1], function(value) c("--source", value))))
  stopifnot(system2("python3", shQuote(command)) == 0L)
  boxes <- data.frame(id = c("labels", "data", "legend"),
      x = c(2, 21.7, 160), y = c(11, 1, 58), w = c(19.5, 137, 20), h = c(146, 156, 32))
  bf_render_png(plot, paste0(out, ".png"), bf_font(font), unlist(spec$text_contract$allowed_text),
                width, height, width, sources, boxes, dpi = 360, authorization = auth,
                skill_root = skill, min_text_pt = 7, publication_size_class = "double-column")
  bf_pdf_open(paste0(out, ".pdf"), width, height, bf_font(font))
  print(plot)
  invisible(dev.off())
  invisible(bf_pdf_finalize(paste0(out, ".pdf"), bf_font(font), width, height))
} else {
  ggsave(paste0(out, ".png"), plot, device = ragg::agg_png, width = width, height = height,
         units = "mm", dpi = 360, bg = "white")
  if (isTRUE(capabilities("aqua"))) {
    grDevices::quartz(type = "pdf", file = paste0(out, ".pdf"), width = width / 25.4,
                     height = height / 25.4, family = font, bg = "white")
    print(plot)
    invisible(dev.off())
  } else {
    ggsave(paste0(out, ".pdf"), plot, device = grDevices::cairo_pdf, width = width, height = height,
           units = "mm", family = font, bg = "white")
  }
}
