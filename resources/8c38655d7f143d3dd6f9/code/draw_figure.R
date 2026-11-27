# Duchêne et al., Nature (2025), Fig. 2c. Run with Rscript draw_figure.R [output-dir].
# Inputs are in plot_data/ and silhouettes/ next to this script.
args <- commandArgs(TRUE)
self_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
self <- normalizePath(sub("^--file=", "", self_arg), mustWork = TRUE)
case <- dirname(self)
out <- if (length(args)) args[1] else file.path(case, "figures")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
library(ggplot2)
width <- 120
height <- 166
font_name <- "Arial"
pcs <- c("PC1", "PC2", "PC3")
yc <- setNames(c(133, 81, 29), pcs)
xc <- 27
radius <- 21.5
gray_branch <- "#AEB8BF"
gray_ring <- c("#6C808D", "#A7B6BE")
palette_id <- "scico-navia"

input <- file.path(case, "plot_data", paste0("duchene-fig2c-", c("branches", "tip-clades", "callouts"), ".csv"))
branches <- read.csv(input[1])
tips <- read.csv(input[2])
notes <- read.csv(input[3])
stopifnot(identical(as.integer(table(branches$pc)), rep(434L, 3)),
          nrow(tips) == 218L, nrow(notes) == 6L)
scale_radius <- radius / max(tips$radius)
skill <- Sys.getenv("BIOFIGURE_ROOT", file.path(path.expand("~"), ".codex", "skills", "biofigure"))
helper <- normalizePath(file.path(skill, "scripts", "figure_style.R"), mustWork = TRUE)
source(helper)
palette_file <- normalizePath(file.path(skill, "palettes", "continuous-luts.csv"), mustWork = TRUE)
palette_table <- read.csv(palette_file)
palette_table <- palette_table[palette_table$palette_id == palette_id, ]
stopifnot(nrow(palette_table) == 256L)
# Use the saturated part of the BioFigure Navia LUT. Its extremes are
# intentionally out of the palette slice; the scientific readout keeps all values.
palette <- palette_table$hex[26:178]
hex_for <- function(value, limits) {
  index <- 1L + round((length(palette) - 1L) * (value - limits[1]) / diff(limits))
  palette[index]
}
xy <- function(r, theta, pc) cbind(x = xc + r * cos(theta), y = unname(yc[pc]) + r * sin(theta))
ranges <- lapply(pcs, function(pc) range(branches$loading[branches$pc == pc & branches$significant]))
names(ranges) <- pcs
branches$color <- gray_branch
for (pc in pcs) {
  use <- branches$pc == pc & branches$significant
  branches$color[use] <- hex_for(branches$loading[use], ranges[[pc]])
}
branches <- branches[order(branches$significant), ]
radial <- cbind(branches,
                xy(branches$parent_radius * scale_radius, branches$child_angle, branches$pc))
ends <- xy(branches$child_radius * scale_radius, branches$child_angle, branches$pc)
radial$xend <- ends[, 1]
radial$yend <- ends[, 2]

# Rectangular phylogram connectors become arcs at each parent radius.
arcs <- do.call(rbind, lapply(which(branches$parent_radius > 0), function(i) {
  b <- branches[i, ]
  delta <- (b$child_angle - b$parent_angle + pi) %% (2 * pi) - pi
  theta <- b$parent_angle + seq(0, delta, length.out = 21L)
  data.frame(xy(b$parent_radius * scale_radius, theta, b$pc),
             id = i, color = b$color)
}))
clades <- unique(tips$clade)
ring <- do.call(rbind, lapply(pcs, function(pc) {
  do.call(rbind, lapply(seq_along(clades), function(i) {
    angle <- tips$theta[tips$clade == clades[i]]
    pitch <- 2 * pi / nrow(tips)
    theta <- seq(min(angle) - pitch / 2 + 0.004, max(angle) + pitch / 2 - 0.004,
                 length.out = max(14L, 4L * length(angle)))
    outer <- xy(radius + 1.7, theta, pc)
    inner <- xy(radius + 0.35, rev(theta), pc)
    data.frame(rbind(outer, inner), id = paste(pc, i), shade = gray_ring[(i - 1L) %% 2L + 1L])
  }))
}))
leaders <- do.call(rbind, lapply(seq_len(nrow(notes)), function(i) {
  a <- notes[i, ]
  b <- branches[branches$pc == a$pc & branches$child == a$child, ]
  stopifnot(nrow(b) == 1L, b$significant, abs(b$loading - a$loading) < 1e-13)
  lane <- if (i %% 2L == 1L) 25.1 else 20.3
  start <- xy(((b$parent_radius + b$child_radius) / 2) * scale_radius, b$child_angle, a$pc)
  outside <- xy(radius + 2.1, b$child_angle, a$pc)
  exit_y <- yc[a$pc] + lane
  if (outside[2] > exit_y) {
    outside <- start + (outside - start) * ((exit_y - start[2]) / (outside[2] - start[2]))
  }
  data.frame(x = c(start[1], outside[1], outside[1], 54.1),
             y = c(start[2], outside[2], exit_y, exit_y), callout = i)
}))
notes$x <- 55.2
notes$y <- unname(yc[notes$pc]) + rep(c(25.1, 20.3), 3L)
legend <- do.call(rbind, lapply(pcs, function(pc) {
  edges <- seq(55.2, 91.8, length.out = length(palette) + 1L)
  y <- unname(yc[pc])
  data.frame(x0 = head(edges, -1), x1 = tail(edges, -1),
             y0 = y - 15.3, y1 = y - 13.4, color = palette)
}))
ticks <- do.call(rbind, lapply(pcs, function(pc) {
  data.frame(x = c(55.2, 73.5, 91.8), y = unname(yc[pc]) - 17.2,
             anchor = c(0, 0.5, 1),
             label = sprintf("%.3f", seq(ranges[[pc]][1], ranges[[pc]][2], length.out = 3L)))
}))
headers <- data.frame(x = 55.2, y = unname(yc) - 10.7,
                      label = paste(pcs, "branch loading"))
p <- ggplot() +
  geom_polygon(data = ring, aes(x, y, group = id, fill = shade), colour = NA) +
  geom_path(data = arcs, aes(x, y, group = id, colour = color), linewidth = 0.30, lineend = "round") +
  geom_segment(data = radial, aes(x, y, xend = xend, yend = yend, colour = color),
               linewidth = 0.30, lineend = "round") +
  geom_path(data = leaders, aes(x, y, group = callout), colour = "#354A57",
            linewidth = 0.23, linetype = "22", lineend = "round") +
  geom_point(data = leaders[!duplicated(leaders$callout), ], aes(x, y),
             shape = 21, size = 1.25, stroke = 0.28, fill = "white", colour = "#354A57") +
  geom_rect(data = legend, aes(xmin = x0, xmax = x1, ymin = y0, ymax = y1, fill = color),
            colour = NA) +
  geom_text(data = notes, aes(x, y, label = label), family = font_name, size = 6.6,
            size.unit = "pt", hjust = 0, colour = "#243641") +
  geom_text(data = headers, aes(x, y, label = label), family = font_name, size = 7.5,
            size.unit = "pt", fontface = "bold", hjust = 0, colour = "#243641") +
  geom_text(data = ticks, aes(x, y, label = label, hjust = anchor), family = font_name,
            size = 6.2, size.unit = "pt", vjust = 1, colour = "#243641") +
  annotate("text", x = 4, y = 162.4, label = "c", family = font_name, size = 8.8,
           fontface = "bold", size.unit = "pt", hjust = 0, colour = "#243641") +
  annotate("segment", x = 96.7, xend = 100.2, y = 162.4, yend = 162.4,
           linewidth = 0.44, colour = gray_branch) +
  annotate("text", x = 101.2, y = 162.4, label = "P > 0.01", family = font_name,
           size = 6.2, size.unit = "pt", hjust = 0, colour = "#455A66") +
  scale_colour_identity() + scale_fill_identity() +
  coord_fixed(xlim = c(0, width), ylim = c(0, height), expand = FALSE, clip = "on") +
  theme_void(base_family = font_name) +
  theme(plot.margin = margin(0, 0, 0, 0),
        plot.background = element_rect(fill = "white", colour = NA),
        panel.background = element_rect(fill = "white", colour = NA))

# Only use independent, explicitly licensed PhyloPic assets.
icons <- data.frame(file = c("cariama-cristata.png", "trogon.png", "cariama-cristata.png",
                             "gavia-immer.png", "accipiter-nisus.svg"),
                    pc = c("PC1", "PC1", "PC2", "PC2", "PC3"),
                    x = c(65, 81.5, 65, 83, 76), y_rel = c(1, 1, 1, 0, 1),
                    max_w = c(13, 9, 13, 18, 17), max_h = c(17, 15, 17, 10, 17))
icon_files <- file.path(case, "silhouettes", icons$file)
stopifnot(all(file.exists(icon_files)))
for (i in seq_len(nrow(icons))) {
  icon <- icons[i, ]
  bmp <- if (endsWith(icon$file, ".svg")) rsvg::rsvg(icon_files[i], width = 768)
         else png::readPNG(icon_files[i])
  if (dim(bmp)[3] == 2L) bmp <- bmp[, , c(1, 1, 1, 2), drop = FALSE]
  visible <- which(bmp[, , 4] > 0.01, arr.ind = TRUE)
  bmp <- bmp[seq(min(visible[, 1]), max(visible[, 1])),
             seq(min(visible[, 2]), max(visible[, 2])), , drop = FALSE]
  xy_unit <- min(icon$max_w / dim(bmp)[2], icon$max_h / dim(bmp)[1])
  half_w <- xy_unit * dim(bmp)[2] / 2
  half_h <- xy_unit * dim(bmp)[1] / 2
  y <- yc[icon$pc] + icon$y_rel
  p <- p + annotation_custom(grid::rasterGrob(bmp, interpolate = TRUE),
                              xmin = icon$x - half_w, xmax = icon$x + half_w,
                              ymin = y - half_h, ymax = y + half_h)
}
paths <- file.path(out, paste0("duchene-fig2c.", c("png", "pdf")))
authorization <- Sys.getenv("BIOFIGURE_RENDER_AUTH")
if (nzchar(authorization)) {
  spec_file <- Sys.getenv("BIOFIGURE_DESIGN_SPEC")
  spec <- yaml::read_yaml(spec_file)
  boxes <- data.frame(id = c("data", "labels", "legend"), x = c(3.5, 54.2, 55),
                      y = c(5.5, 39, 8), w = c(47, 61, 38), h = c(151, 123, 114))
  bf_render_png(p, paths[1], bf_font(font_name), unlist(spec$text_contract$allowed_text),
                width, height, width,
                c(spec_file, self, helper, input, palette_file, unique(icon_files)),
                boxes, allowed_pairs = "labels:legend",
                dpi = 420, authorization = authorization,
                publication_size_class = "one-and-half-column")
} else {
  ggsave(paths[1], p, device = ragg::agg_png, width = width, height = height, units = "mm", dpi = 420, bg = "white")
}
bf_pdf_open(paths[2], width, height, bf_font(font_name))
print(p)
invisible(grDevices::dev.off())
audit <- bf_pdf_finalize(paths[2], bf_font(font_name), width, height)
if (nzchar(authorization)) {
  jsonlite::write_json(audit, paste0(paths[2], ".pdf-audit.json"), auto_unbox = TRUE, pretty = TRUE)
}
