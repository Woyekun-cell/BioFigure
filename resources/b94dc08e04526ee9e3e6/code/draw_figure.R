# Marshall et al., Nature Fig. 1b. https://doi.org/10.1038/s41586-026-11325-6
# Counts from the author checklists. Inset from RESOLVE 2017 (Dinerstein et al.).
# Attribution and data sources are listed in README.txt.
args <- commandArgs(TRUE)
self <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
case <- dirname(self)
if (length(args) > 1L) stop("Usage: Rscript --vanilla draw_figure.R [output_directory]")
out <- if (length(args)) args[1] else file.path(case, "figures")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
if (!"Arial" %in% systemfonts::system_fonts()$family) stop("Install Arial before drawing.")
suppressPackageStartupMessages(library(ggplot2))
palette <- c(Mainland="#505862", Palearctic="#4E79A7", Indomalayan="#EDC949",
  Australasia="#AF7AA1", Neotropic="#59A14F", Afrotropic="#E15759", Nearctic="#76B7B2",
  Oceania="#F28E2C", text="#25313B", dots="#DEE3E7", rows="#F5F7F9", outline="#30343B")
sets <- names(palette)[1:8]
realms <- sets[-1]
island_union <- 4128L
columns <- read.csv(file.path(case, "plot_data/upset-intersections.csv"), check.names=FALSE)
stopifnot(nrow(columns)==25L, identical(columns$rank, seq_len(nrow(columns))),
  all(columns$count>=3), all(columns$degree<=3), !anyDuplicated(columns$intersection),
  max(abs(columns$log10_count-log10(columns$count)))<1e-12)
membership <- lapply(seq_len(nrow(columns)), function(i) which(as.logical(columns[i, sets])))
stopifnot(all(lengths(membership)==columns$degree),
  identical(vapply(membership,function(i) paste(sets[i], collapse=" + "),character(1)),columns$intersection))
print_count <- function(x) format(x, big.mark=",", scientific=FALSE, trim=TRUE)
vertices <- read.csv(file.path(case, "plot_data/map-vertices.csv"), colClasses=c(polygon="character"))
ids <- strsplit(vertices$polygon, ".", fixed=TRUE)
vertices$polygon <- interaction(as.integer(vapply(ids,`[`,character(1),1)),
                                as.integer(vapply(ids,`[`,character(1),2)))
stopifnot(setequal(vertices$realm,realms), all(is.finite(vertices$x_m)), all(is.finite(vertices$y_m)))
inset <- ggplot(vertices, aes(x_m, y_m, group = polygon, subgroup = ring, fill = realm)) +
  geom_polygon(rule = "evenodd", linewidth = 0.02, colour = "#FFFFFF") +
  scale_fill_manual(values = palette[realms], guide = "none") + coord_equal(expand = FALSE) +
  theme_void() + theme(plot.margin = margin(0, 0, 0, 0))

rows <- data.frame(set = sets, y = 27.1 - 3.05 * (seq_along(sets) - 1L))
rows$shade <- vapply(unname(palette[sets]), function(hex) {
  rgb <- col2rgb(hex) * 0.62
  grDevices::rgb(rgb[1], rgb[2], rgb[3], maxColorValue = 255)
}, character(1))
x0 <- 25.0
column_step <- 6.2
baseline <- 32
height_scale <- 11.85
columns$x <- x0 + column_step * (columns$rank - 0.5)
columns$top <- baseline + height_scale * columns$log10_count
columns$label <- print_count(columns$count)
columns$color <- unname(palette[columns$bar_key])
matrix_dots <- do.call(rbind, lapply(seq_along(membership), function(i) {
  present <- (seq_along(sets) %in% membership[[i]])
  dot <- if (1L %in% membership[[i]]) rep(palette[["text"]], length(sets)) else unname(palette[sets])
  data.frame(x = columns$x[i], y = rows$y, present, dot = ifelse(present, dot, palette[["dots"]]))
}))
span <- data.frame(x = columns$x, lower = vapply(membership, function(i) min(rows$y[i]), numeric(1)),
  upper = vapply(membership, function(i) max(rows$y[i]), numeric(1)))
span <- subset(span, lower < upper)
ticks <- data.frame(y = baseline + height_scale * 0:4, label = print_count(10^(0:4)))
main <- ggplot() +
  geom_rect(data = rows[seq(2, nrow(rows), by = 2), ],
    aes(ymin = y - 1.525, ymax = y + 1.525), xmin = x0, xmax = 180,
    fill = palette[["rows"]], colour = NA) +
  geom_rect(data = columns, aes(xmin = x - 2.63, xmax = x + 2.63, ymax = top, fill = color),
    ymin = baseline, colour = palette[["outline"]], linewidth = 0.35) +
  scale_fill_identity() +
  annotate("segment", x = x0, xend = x0, y = baseline, yend = baseline + 4.25 * height_scale,
    colour = palette[["text"]], linewidth = 0.26) +
  geom_segment(data = ticks, aes(y = y, yend = y), x = x0-0.9, xend = x0,
    colour = palette[["text"]], linewidth = 0.26) +
  geom_text(data = ticks, aes(y = y, label = label), x = x0 - 1.7, hjust = 1,
    size = 6.4, size.unit = "pt", family = "Arial", colour = palette[["text"]]) +
  geom_text(data = columns, aes(x, top + 1.6, label = label),
    size = 6.4, size.unit = "pt", family = "Arial", colour = palette[["text"]]) +
  geom_segment(data = span, aes(x, lower, xend = x, yend = upper),
    linewidth = 0.26, colour = palette[["text"]]) +
  geom_point(data = subset(matrix_dots, !present), aes(x, y, fill = dot),
    size = 1.62, stroke = 0.24, shape = 21, colour = "#8A959E") +
  geom_point(data = subset(matrix_dots, present), aes(x, y, fill = dot),
    size = 1.80, stroke = 0.30, shape = 21, colour = palette[["outline"]]) +
  geom_text(data = rows, aes(y = y, label = set, colour = shade), x = x0 - 1.7,
    hjust = 1, size = 6.8, size.unit = "pt", family = "Arial") +
  scale_colour_identity() +
  annotate("segment", x = 6.6, xend = 6.6, y = 4.8, yend = 25.6,
    linewidth = 0.21, colour = "#9AA5AD") +
  annotate("text", x = 3.6, y = 15.2, label = "Island sets (4,128 spp.)", angle = 90,
    size = 6.4, family = "Arial", colour = palette[["text"]], size.unit = "pt") +
  annotate("text", x = 5.4, y = 57.2, label = "Intersection size", angle = 90,
    size = 7.2, family = "Arial", colour = palette[["text"]], size.unit = "pt") +
  annotate("text", x = 2.2, y = 87.2, label = "b", size = 8.5, hjust = 0,
    family = "Arial", fontface = "bold", colour = palette[["text"]], size.unit = "pt") +
  coord_fixed(xlim = c(0, 183), ylim = c(0, 90), expand = FALSE, clip = "off") +
  theme_void() + theme(plot.margin = margin(0, 0, 0, 0))
inset_box <- c(x = 115, y = 57.5, w = 64.5, h = 29.8)
inset_near <- columns$x >= inset_box[["x"]] - column_step / 2
inset_clearance <- inset_box[["y"]] - max(columns$top[inset_near] + 3)
stopifnot(inset_clearance > 1)
p <- cowplot::ggdraw(main) + cowplot::draw_plot(inset, x = inset_box[["x"]] / 183,
  y = inset_box[["y"]] / 90, width = inset_box[["w"]] / 183, height = inset_box[["h"]] / 90)
png <- file.path(out, "bee-upset-fig1b.png")
pdf <- file.path(out, "bee-upset-fig1b.pdf")
ggsave(png, p, device=ragg::agg_png, width=183, height=90, units="mm", dpi=300, bg="white")
if (capabilities("aqua")) {
  grDevices::quartz(type="pdf", file=pdf, width=183/25.4, height=90/25.4, family="Arial", bg="white")
} else {
  grDevices::cairo_pdf(pdf, width=183/25.4, height=90/25.4, family="Arial", bg="white")
}
print(p)
invisible(grDevices::dev.off())
