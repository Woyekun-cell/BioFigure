#!/usr/bin/env Rscript
# BioFigure independent plot replay from the published S8-derived plotting rows.
# Siraj et al., Nature 2026, DOI 10.1038/s41586-026-10121-6, Fig.2d.
# Author code is linked in ATTRIBUTION.txt, not included in this package.
# Rscript draw.R [plot_data_csv] [output_prefix]
# No BioFigure installation, API, network, workbook or raw sequencing data is needed.
suppressPackageStartupMessages(library(ggplot2))
args <- commandArgs(trailingOnly=TRUE)
self <- normalizePath(sub("^--file=","",grep("^--file=",commandArgs(),value=TRUE)))
root <- dirname(self)
stopifnot(length(args)<=2)
input <- normalizePath(if(length(args)>=1)args[1] else file.path(root,"plot_data","siraj-ranked-correlation.csv"),mustWork=TRUE)
output <- if(length(args)==2)args[2] else file.path(root,"output","siraj-nature-fig2d")
dir.create(dirname(output),recursive=TRUE,showWarnings=FALSE)
font <- "Arial"
arial <- systemfonts::match_fonts(font)
if(!grepl("Arial",basename(arial$path),fixed=TRUE))stop("Arial is required; install it before replay.")
cell_levels <- c("A549","HCT116","HEPG2","K562","SKNSH")
cell_labels <- c("A549","HCT116","HepG2","K562","SK-N-SH")
cell_colors <- c(A549="#CCBB44",HCT116="#228833",HEPG2="#AA3377",K562="#4477AA",SKNSH="#EE6677")
points <- read.csv(input,na.strings=NA,stringsAsFactors=FALSE)
stopifnot(nrow(points)==479L,!anyNA(points),!anyDuplicated(points$tf),
          identical(as.integer(points$rank),seq_len(nrow(points))),all(diff(points$cor)<=0),
          all(points$lowci<=points$cor & points$cor<=points$highci),all(points$cell_type %in% cell_levels))
points$cell_type <- factor(points$cell_type, levels = cell_levels)
top <- points[points$label != "" & points$cor > 0, ]
bottom <- points[points$label != "" & points$cor < 0, ]
# Separate the selected TF names while tethering each label to its true interval.
top$text_x <- seq(6, 174, length.out = nrow(top))
bottom$text_x <- seq(418, 499, length.out = nrow(bottom))
width <- 136
height <- 119

p <- ggplot(points, aes(rank, cor, color = cell_type)) +
  geom_hline(yintercept = 0, colour = "#303033", linewidth = 0.34) +
  geom_linerange(aes(ymin = lowci, ymax = highci), linewidth = 0.16, alpha = 0.65) +
  geom_point(size = 1.25, alpha = 0.94) +
  geom_segment(data = top, aes(x = rank, xend = text_x, y = highci + .015, yend = 1.015),
    inherit.aes = FALSE, colour = "#74767A", linewidth = .19) +
  geom_segment(data = bottom, aes(x = rank, xend = text_x, y = lowci - .015, yend = -.985),
    inherit.aes = FALSE, colour = "#74767A", linewidth = .19) +
  geom_text(data = top, aes(x = text_x, y = 1.045, label = label), inherit.aes = FALSE,
    family = font, size = 8.7, size.unit = "pt", color = "#202125",
    angle = 49, hjust = 0, vjust = 0.5) +
  geom_text(data = bottom, aes(x = text_x, y = -1.013, label = label), inherit.aes = FALSE,
    family = font, size = 8.7, size.unit = "pt", color = "#202125",
    angle = 49, hjust = 1, vjust = 0.5) +
  scale_color_manual(values = cell_colors, breaks = cell_levels, labels = cell_labels,
    drop = FALSE) +
  scale_x_continuous(expand = expansion(mult = 0), breaks = NULL) +
  scale_y_continuous(breaks = seq(-1, 1, by = 0.5),
    labels = c("−1.0", "−0.5", "0", "0.5", "1.0"), expand = expansion(mult = 0)) +
  coord_cartesian(xlim = c(1, 499), ylim = c(-1.24, 1.25), clip = "off") +
  guides(color = guide_legend(override.aes = list(size = 2.4, linewidth = .55, alpha = 1))) +
  labs(x = NULL, y = "Correlation of allelic effect\nand occupied motif",
    color = "Cell type", tag = "d") +
  theme_classic(base_size = 9, base_family = font) +
  theme(
    text = element_text(colour = "#202125"),
    axis.line.y = element_line(colour = "#303033", linewidth = .30),
    axis.line.x = element_blank(), axis.ticks.x = element_blank(),
    axis.text.y = element_text(size = 8.2, colour = "#303033"),
    axis.title.y = element_text(size = 9.5, margin = margin(r = 6)),
    axis.ticks.y = element_line(colour = "#303033", linewidth = .26),
    axis.ticks.length.y = grid::unit(1.1, "mm"),
    legend.position = "inside", legend.position.inside = c(.055, .43),
    legend.justification.inside = c(0, 1),
    legend.key.height = grid::unit(4.9, "mm"),
    legend.key.width = grid::unit(5.0, "mm"),
    legend.margin = margin(0, 0, 0, 0),
    legend.title = element_text(size = 8.7),
    legend.text = element_text(size = 8.2),
    legend.background = element_blank(), legend.key = element_blank(),
    plot.margin = margin(7, 7, 4, 5),
    plot.tag = element_text(size = 10.5, face = "bold"),
    plot.tag.position = "topleft"
  )

ggsave(paste0(output,".png"),p,device=ragg::agg_png,width=width,height=height,units="mm",dpi=360,bg="white")
pdf <- paste0(output, ".pdf")
if (capabilities("aqua")) {
  grDevices::quartz(type = "pdf", file = pdf, width = width / 25.4,
    height = height / 25.4, family = font, bg = "white")
} else {
  grDevices::cairo_pdf(filename = pdf, width = width / 25.4,
    height = height / 25.4, family = font, bg = "white")
}
print(p)
invisible(dev.off())

cat("REPLAY_COMPLETE",paste0(output,".png"),pdf,"\n")
