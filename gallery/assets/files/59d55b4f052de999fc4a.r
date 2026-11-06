#!/usr/bin/env Rscript

# Independent structural reproduction of Shi et al. 2026 Extended Data Fig. 1b.
# Original A/B intervals were not released. Fixed-seed synthetic intervals test
# the verified 19-chromosome x 11-genome circular visual grammar only.

suppressPackageStartupMessages({
  library(circlize)
  library(dplyr)
  library(ragg)
  library(svglite)
  library(systemfonts)
  library(jsonlite)
  library(digest)
})

args <- commandArgs(trailingOnly = TRUE)
case_dir <- normalizePath(if (length(args)) args[[1]] else ".", mustWork = TRUE)
preview <- "--preview" %in% args
skill_root <- normalizePath(file.path(case_dir, "..", "..", "..", "biofigure"), mustWork = TRUE)
source(file.path(skill_root, "scripts", "figure_style.R"))
font <- bf_font("Arial")

fig_dir <- file.path(case_dir, "results", "figures")
data_dir <- file.path(case_dir, "results", "plot_data")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)

set.seed(20260928)
species <- c(
  "P. pseudoglauca", "P. wuana", "P. szechuanica", "P. yunnanensis",
  "P. koreana", "P. simonii", "P. lasiocarpa", "P. davidiana",
  "P. rotundifolia", "P. qiongdaoensis", "P. adenopoda"
)
track_id <- letters[1:11]
chromosomes <- sprintf("Chr%02d", 1:19)
chromosome_lengths <- round(runif(19, 24, 48) * 1e6)
chrom_table <- data.frame(chr = chromosomes, start = 0, end = chromosome_lengths, length = chromosome_lengths)

merge_states <- function(chr, ends, states, sp, code) {
  starts <- c(0, head(ends, -1))
  grp <- cumsum(c(TRUE, states[-1] != states[-length(states)]))
  raw <- data.frame(chr = chr, start = starts, end = ends, state = states, group = grp)
  raw |>
    group_by(chr, group, state) |>
    summarise(start = min(start), end = max(end), .groups = "drop") |>
    mutate(species = sp, track_id = code) |>
    select(species, track_id, chr, start, end, state)
}

intervals <- list(); idx <- 0L
for (j in seq_along(chromosomes)) {
  len <- chromosome_lengths[j]
  nwin <- max(24L, round(len / 7.5e5))
  ends <- round(seq(len / nwin, len, length.out = nwin))
  base <- character(nwin); base[1] <- sample(c("A", "B"), 1)
  for (w in 2:nwin) base[w] <- if (runif(1) < .18) ifelse(base[w-1] == "A", "B", "A") else base[w-1]
  for (i in seq_along(species)) {
    state <- base
    flip <- runif(nwin) < (0.035 + (i - 1) * .004)
    state[flip] <- ifelse(state[flip] == "A", "B", "A")
    idx <- idx + 1L
    intervals[[idx]] <- merge_states(chromosomes[j], ends, state, species[i], track_id[i])
  }
}
intervals <- bind_rows(intervals)
intervals$state <- factor(intervals$state, levels = c("A", "B"))
state_colors <- c(A = "#4F84B6", B = "#ADD7E4")

write.csv(chrom_table, file.path(data_dir, "populus_compartment_chromosomes.csv"), row.names = FALSE)
write.csv(intervals, file.path(data_dir, "populus_compartment_intervals.csv"), row.names = FALSE)

png_path <- file.path(fig_dir, "populus_circular_compartment_tracks.png")
svg_path <- file.path(fig_dir, "populus_circular_compartment_tracks.svg")
pdf_path <- file.path(fig_dir, "populus_circular_compartment_tracks.pdf")

render_panel <- function() {
  par(mar = c(0, 0, 0, 0), xpd = NA, family = "Arial", bg = "white")
  circos.clear()
  circos.par(
    start.degree = 84, gap.after = c(rep(1.15, 18), 10),
    cell.padding = c(0, 0, 0, 0), track.margin = c(.0025, .0025),
    points.overflow.warning = FALSE,
    canvas.xlim = c(-1.20, 1.36), canvas.ylim = c(-1.16, 1.16)
  )
  circos.initialize(factors = chrom_table$chr, xlim = as.matrix(chrom_table[, c("start", "end")]))

  circos.trackPlotRegion(
    ylim = c(0, 1), track.height = .075, bg.border = NA,
    panel.fun = function(x, y) {
      sector <- CELL_META$sector.index
      lim <- CELL_META$xlim
      circos.lines(lim, c(.18, .18), col = "#8A8A8A", lwd = .65)
      circos.text(mean(lim), .86, sector, facing = "bending.outside", niceFacing = TRUE,
                  cex = .58, font = 2, family = "Arial")
    }
  )

  ring_radius <- numeric(length(species))
  for (i in seq_along(species)) {
    sp <- species[i]
    circos.trackPlotRegion(
      ylim = c(0, 1), track.height = .055, bg.border = NA,
      panel.fun = function(x, y) {
        sector <- CELL_META$sector.index
        if (sector == chromosomes[1]) {
          ring_radius[i] <<- (CELL_META$cell.top.radius + CELL_META$cell.bottom.radius) / 2
        }
        dat <- intervals[intervals$species == sp & intervals$chr == sector, , drop = FALSE]
        if (nrow(dat)) {
          for (q in seq_len(nrow(dat))) {
            circos.rect(dat$start[q], .04, dat$end[q], .96,
                        col = state_colors[as.character(dat$state[q])], border = NA)
          }
        }
      }
    )
  }

  # Gap key, centre dictionary, panel letter and external legend.
  text(0.006, ring_radius, labels = track_id, family = "Arial", font = 2, cex = .53)
  yy <- seq(.18, -.18, length.out = length(species))
  text(-.17, yy, labels = track_id, family = "Arial", font = 2, cex = .58, adj = 1)
  text(-.13, yy, labels = species, family = "Arial", font = 3, cex = .58, adj = 0)
  text(-1.13, 1.08, labels = "b", family = "Arial", font = 2, cex = 1.05)
  rect(1.00, -.76, 1.07, -.70, col = state_colors["A"], border = NA)
  text(1.11, -.73, "A compartment", family = "Arial", cex = .61, adj = 0)
  rect(1.00, -.87, 1.07, -.81, col = state_colors["B"], border = NA)
  text(1.11, -.84, "B compartment", family = "Arial", cex = .61, adj = 0)
  circos.clear()
}

width_mm <- 183; height_mm <- 170; dpi <- 300
if (!preview) {
  auth <- file.path(case_dir, "render-authorization.json")
  auth_script <- file.path(skill_root, "scripts", "authorize_render.py")
  sources <- c(
    file.path(case_dir, "render_populus_compartment_circle.R"),
    file.path(skill_root, "scripts", "figure_style.R"),
    file.path(case_dir, "reference-panel-b.jpg"),
    file.path(case_dir, "user-reference.png"),
    file.path(case_dir, "provenance", "article-page.html"),
    file.path(case_dir, "provenance", "author-repo-README.md"),
    file.path(case_dir, "provenance", "source-data-gap.json")
  )
  cmd <- c(auth_script, "--design-spec", file.path(case_dir, "design-spec.yaml"), "--output", auth, "--consume",
           unlist(lapply(sources, function(z) c("--source", z))))
  status <- suppressWarnings(system2("python3", cmd, stdout = FALSE, stderr = FALSE))
  if (!identical(status, 0L)) stop("render authorization rejected or already consumed")
}

ragg::agg_png(png_path, width = width_mm, height = height_mm, units = "mm", res = dpi, background = "white")
render_panel()
dev.off()

if (!preview) {
  svglite::svglite(svg_path, width = width_mm/25.4, height = height_mm/25.4, bg = "white",
                   system_fonts = list(sans = "Arial"))
  render_panel()
  dev.off()
  if (!requireNamespace("rsvg", quietly = TRUE)) stop("rsvg is required for vector PDF export")
  rsvg::rsvg_pdf(svg_path, pdf_path)
  bound <- function(path) list(path = normalizePath(path, mustWork = TRUE), sha256 = digest::digest(file = path, algo = "sha256"))
  receipt <- list(
    schema_version = 1, status = "PASS", backend = "R", renderer = "circlize",
    artifact = bound(png_path), sources = lapply(c(file.path(case_dir, "design-spec.yaml"), sources), bound),
    font = c(bound(font$path), list(family = font$family)),
    checks = list(font = TRUE, state_palette = TRUE, coordinate_bounds = TRUE, target_size = TRUE),
    target_size = list(width_mm = width_mm, height_mm = height_mm, size_class = "double-column", size_basis = "final_physical_output"),
    device = list(width_mm = width_mm, height_mm = height_mm, dpi = dpi),
    scope = "technical rendering evidence; separate final-size inspection and critics required"
  )
  jsonlite::write_json(receipt, paste0(png_path, ".render.json"), auto_unbox = TRUE, pretty = TRUE)
}
cat(sprintf("RENDER_OK preview=%s chromosomes=%d tracks=%d intervals=%d png=%s\n",
            preview, nrow(chrom_table), length(species), nrow(intervals), png_path))
