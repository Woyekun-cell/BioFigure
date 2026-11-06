#!/usr/bin/env Rscript
# Editable native-R circular annotation method transfer. All published cells and
# saved UMAP coordinates are retained; metadata rings do not polarize the UMAP.
# Usage: Rscript render.R CASE_ROOT WORK_ROOT SINGLE_USE_AUTHORIZATION.json
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 3L)
root <- normalizePath(args[1], mustWork = TRUE)
work <- normalizePath(args[2], mustWork = TRUE)
authorization <- normalizePath(args[3], mustWork = TRUE)
skill <- Sys.getenv("BIOFIGURE_SKILL_ROOT", normalizePath(file.path(root, "../../../.."), mustWork = TRUE))
source(file.path(skill, "scripts/figure_style.R"))
options(warn = 2)
font <- bf_font("Arial")
bf_complexheatmap_font(font)
spec_path <- file.path(root, "data/metadata/design-spec.yaml")
spec <- yaml::read_yaml(spec_path)
palette <- unlist(spec$palette_semantics, use.names = TRUE)
stopifnot(spec$output_size$width_mm == 180, spec$output_size$height_mm == 170,
  spec$output_size$size_class == "double-column", spec$font_contract$family == "Arial",
  normalizePath(spec$font_contract$resolved_font_file) == normalizePath(font$path))
paths <- file.path(root, "data/plot_data", c("embedding_cells.csv", "cluster_summary.csv",
  "metadata_track_segments.csv", "kde_grid.csv", "contour_lines.csv"))
cells <- read.csv(paths[1], stringsAsFactors = FALSE, check.names = FALSE)
clusters <- read.csv(paths[2], stringsAsFactors = FALSE, check.names = FALSE)
segments <- read.csv(paths[3], stringsAsFactors = FALSE, check.names = FALSE)
kde_grid <- read.csv(paths[4], stringsAsFactors = FALSE, check.names = FALSE)
contours <- read.csv(paths[5], stringsAsFactors = FALSE, check.names = FALSE)
qc_path <- file.path(root, "data/metadata/data-qc.json")
qc <- jsonlite::fromJSON(qc_path, simplifyVector = FALSE)
cluster_order <- names(table(cells$celltype))
donor_order <- names(table(cells$patient))
stopifnot(nrow(cells) == 102710L, !anyDuplicated(cells$name), nrow(clusters) == 15L,
  length(donor_order) == 13L, nrow(segments) == 200L, nrow(kde_grid) == 40000L,
  nrow(contours) == 2612L, length(unique(contours$contour_id)) == 18L,
  identical(clusters$celltype, cluster_order), all(c(cluster_order, donor_order,
    "PKD", "control", "density", "text") %in% names(palette)),
  setequal(unique(contours$level), c(.2, .3)),
  all(abs(clusters$log10_n_cells - log10(clusters$n_cells)) < 1e-12),
  sum(clusters$n_cells) == nrow(cells), !"percent.mt" %in% names(cells),
  isTRUE(qc$coordinate_transform$original_aspect_ratio_preserved))
for (cl in cluster_order) for (tr in c("disease", "patient")) {
  s <- segments[segments$celltype == cl & segments$track == tr, ]
  extent <- clusters$log10_n_cells[match(cl, cluster_order)]
  stopifnot(nrow(s) > 0L, abs(s$x0[1]) < 1e-12, abs(tail(s$x1, 1) - extent) < 1e-12,
    all(s$x1 > s$x0), abs(sum(s$proportion) - 1) < 1e-12,
    all(abs(s$proportion - s$n_cells / s$n_cluster) < 1e-12),
    all(abs(s$x0[-1] - head(s$x1, -1)) < 1e-12))
}
width <- 180; height <- 170
circle_mm <- c(xmin = 20, xmax = 160, ymin = 25, ymax = 165)
native_xlim <- native_ylim <- c(-1.12, 1.12)
mm_per_native_unit <- 140 / diff(native_xlim)
circle_center <- c(x = 90, y = 95)
point_colors <- grDevices::adjustcolor(unname(palette[cells$celltype]), alpha.f = .25)
stopifnot(!anyNA(point_colors), max(sqrt(cells$x^2 + cells$y^2)) <= .69 + 1e-12)
native_tracks <- data.frame()
native_segments <- data.frame()
native_primitive <- list()
draw_native <- function() {
  circlize::circos.clear()
  on.exit(circlize::circos.clear(), add = TRUE)
  graphics::par(mar = rep(0, 4), oma = rep(0, 4), xaxs = "i", yaxs = "i",
    family = font$family, bg = "white")
  circlize::circos.par(start.degree = 0, clock.wise = TRUE, gap.degree = as.numeric(clusters$gap_after_deg),
    cell.padding = rep(0, 4), track.margin = c(.004, .004),
    canvas.xlim = native_xlim, canvas.ylim = native_ylim,
    points.overflow.warning = FALSE)
  circlize::circos.initialize(factors = factor(cluster_order, levels = cluster_order),
    xlim = cbind(rep(0, length(cluster_order)), clusters$log10_n_cells))
  for (track in c("celltype", "disease", "patient")) {
    current_track <- track
    circlize::circos.trackPlotRegion(ylim = c(0, 1), track.height = .012,
      bg.border = NA, panel.fun = function(x, y) {
        cl <- circlize::get.cell.meta.data("sector.index")
        ti <- circlize::get.cell.meta.data("track.index")
        start_deg <- circlize::get.cell.meta.data("cell.start.degree")
        end_deg <- circlize::get.cell.meta.data("cell.end.degree")
        top <- circlize::get.cell.meta.data("cell.top.radius")
        bottom <- circlize::get.cell.meta.data("cell.bottom.radius")
        xlim <- circlize::get.cell.meta.data("xlim")
        native_tracks <<- rbind(native_tracks, data.frame(celltype = cl, track = current_track,
          track_index = ti, start_degree_native = start_deg, end_degree_native = end_deg,
          x0 = xlim[1], x1 = xlim[2], outer_radius_native = top, inner_radius_native = bottom,
          width_mm = (top - bottom) * mm_per_native_unit))
        if (current_track == "celltype") {
          ss <- data.frame(category = cl, x0 = xlim[1], x1 = xlim[2],
            n_cells = clusters$n_cells[match(cl, cluster_order)], proportion = 1)
        } else {
          ss <- segments[segments$celltype == cl & segments$track == current_track, ]
        }
        for (i in seq_len(nrow(ss))) {
          color <- unname(palette[ss$category[i]])
          stopifnot(length(color) == 1L, !is.na(color))
          circlize::circos.rect(ss$x0[i], 0, ss$x1[i], 1, col = color, border = NA)
          native_corners <- circlize::circlize(c(ss$x0[i], ss$x1[i]), c(0, 1),
            sector.index = cl, track.index = ti)
          native_segments <<- rbind(native_segments, data.frame(celltype = cl, track = current_track,
            category = ss$category[i], n_cells = ss$n_cells[i], proportion = ss$proportion[i],
            x0 = ss$x0[i], x1 = ss$x1[i], theta0_native = native_corners[1, "theta"],
            theta1_native = native_corners[2, "theta"], radius0_native = native_corners[1, "rou"],
            radius1_native = native_corners[2, "rou"], color = color))
        }
      })
  }
  actual_usr <- graphics::par("usr")
  stopifnot(max(abs(actual_usr - c(native_xlim, native_ylim))) < 1e-12,
    abs(graphics::par("pin")[1] - graphics::par("pin")[2]) < 1e-12)
  # Prepared absolute all-cell KDE contours, never per-cluster confidence limits.
  for (id in unique(contours$contour_id)) {
    cc <- contours[contours$contour_id == id, ]
    graphics::lines(cc$x, cc$y, col = grDevices::adjustcolor(palette[["density"]], .7), lwd = .65,
      lty = if (cc$level[1] == .2) 2 else 1)
  }
  # One full vector points primitive. No sampling, rasterization or recalculated UMAP.
  graphics::points(cells$x, cells$y, pch = 16, cex = .105, col = point_colors)
  native_primitive <<- list(usr = actual_usr, device_inches = graphics::par("din"),
    plot_inches = graphics::par("pin"), point_n = nrow(cells), pch = 16,
    cex = .105, alpha = .25, contour_order = "before_all_points",
    contour_lwd_base = .65)
}
# A square offscreen vector capture preserves Cartesian aspect ratio. GridGraphics
# translates native polygons/lines/points to editable grid primitives, not a bitmap.
native_grob <- grid::grid.grabExpr(gridGraphics::grid.echo(draw_native),
  width = 140 / 25.4, height = 140 / 25.4, warn = 0)
stopifnot(inherits(native_grob, "grob"), nrow(native_tracks) == 45L,
  nrow(native_segments) == 215L)
point_grobs <- list(); raster_n <- 0L
audit_grob <- function(g) {
  if (inherits(g, "rastergrob")) raster_n <<- raster_n + 1L
  if (inherits(g, "points")) point_grobs[[length(point_grobs) + 1L]] <<- g
  if (!is.null(g$children)) for (ch in g$children) audit_grob(ch)
  if (!is.null(g$grobs)) for (ch in g$grobs) audit_grob(ch)
}
audit_grob(native_grob)
captured_point_n <- sum(vapply(point_grobs, function(g) length(g$x), integer(1)))
stopifnot(raster_n == 0L, captured_point_n == 102710L, length(point_grobs) == 1L)
captured_points <- point_grobs[[1]]
stopifnot(max(abs(as.numeric(captured_points$x) - cells$x)) < 1e-12,
  max(abs(as.numeric(captured_points$y) - cells$y)) < 1e-12,
  identical(unname(captured_points$gp$col), unname(point_colors)))
# Check actual native sector angles against the preparation contract modulo 360.
ring0 <- native_tracks[native_tracks$track == "celltype", ]
angle_error <- function(actual, clockwise) abs(((actual + clockwise + 180) %% 360) - 180)
stopifnot(max(angle_error(ring0$start_degree_native, clusters$theta_start_clockwise_deg)) < 1e-10,
  max(angle_error(ring0$end_degree_native, clusters$theta_end_clockwise_deg)) < 1e-10,
  max(abs((ring0$start_degree_native - ring0$end_degree_native) - clusters$angle_width_deg)) < 1e-10)
texts <- data.frame()
add_text <- function(id, label, x, y, size = 7.500001, face = "plain", angle = 0,
                     hjust = .5, vjust = .5, region = "labels", color = palette[["text"]]) {
  texts <<- rbind(texts, data.frame(id = id, label = label, x = x, y = y,
    size_pt = size, face = face, angle = angle, hjust = hjust, vjust = vjust,
    region = region, color = color, stringsAsFactors = FALSE))
}
outer_angle <- -(clusters$theta_start_clockwise_deg + clusters$theta_end_clockwise_deg) / 2
tangent_angle <- ((outer_angle + 90 + 90) %% 180) - 90
outer <- data.frame(celltype = cluster_order, theta_degrees = outer_angle,
  x = circle_center["x"] + 65 * cos(outer_angle * pi / 180),
  y = circle_center["y"] + 65 * sin(outer_angle * pi / 180), angle = tangent_angle)
for (i in seq_len(nrow(outer))) add_text(paste0("outer_", outer$celltype[i]), outer$celltype[i],
  outer$x[i], outer$y[i], size = 8.000001, angle = outer$angle[i])
add_text("cell_total", "102,710 cells", 90, 148, size = 8.500001, face = "bold")
add_text("category_total", "15 cell types | 13 donors", 90, 142.8)
# Three direct names in the source12-degree gap identify the outer-to-inner tracks.
track_callouts <- data.frame(track = c("celltype", "disease", "patient"),
  label = c("Cell type", "Disease", "Donor"), theta = c(9, 6, 3))
for (i in seq_len(nrow(track_callouts))) {
  rr <- native_tracks[native_tracks$track == track_callouts$track[i], ][1, ]
  radius <- mean(c(rr$outer_radius_native, rr$inner_radius_native))
  th <- track_callouts$theta[i] * pi / 180
  track_callouts$x[i] <- circle_center["x"] + radius * mm_per_native_unit * cos(th)
  track_callouts$y[i] <- circle_center["y"] + radius * mm_per_native_unit * sin(th)
  track_callouts$xend[i] <- 157
  track_callouts$yend[i] <- track_callouts$y[i]
  add_text(paste0("track_name_",i), track_callouts$label[i], 159, track_callouts$y[i], hjust = 0)
}

# Real median anchors are retained separately. Label offsets improve readability;
# moved labels have leaders pointing to the original class median, including URO1/2.
inner <- data.frame(celltype = cluster_order,
  anchor_x = circle_center["x"] + mm_per_native_unit * clusters$median_x,
  anchor_y = circle_center["y"] + mm_per_native_unit * clusters$median_y,
  x = c(77,58,89,107,90,96,105,94,128,100,87,60,73,96,109),
  y = c(105,103,95,90,131,119,108,84.5,89,61,64.5,70,69,77,77),
  stringsAsFactors = FALSE)
inner$displacement_mm <- sqrt((inner$x - inner$anchor_x)^2 + (inner$y - inner$anchor_y)^2)
leaders <- inner[inner$displacement_mm > 1, ]
leaders$color <- unname(palette[leaders$celltype])
for (i in seq_len(nrow(inner))) add_text(paste0("inner_", inner$celltype[i]), inner$celltype[i],
  inner$x[i], inner$y[i], region = "inner")
keys <- data.frame()
add_key <- function(category, x, y) {
  keys <<- rbind(keys, data.frame(category = category, xmin = x, xmax = x + 2,
    ymin = y - .9, ymax = y + .9, color = unname(palette[category])))
}
add_text("disease_title", "Disease", 8, 18.5, size = 8.000001, hjust = 0, region = "legend")
add_key("PKD", 26, 18.5); add_text("disease_PKD", "PKD", 29, 18.5, hjust = 0, region = "legend")
add_key("control", 47, 18.5); add_text("disease_control", "Control", 50, 18.5, hjust = 0, region = "legend")
add_text("density_title", "Global density", 116, 18.5, hjust = 0, region = "legend")
add_text("density_02", "0.2", 145, 18.5, hjust = 0, region = "legend")
add_text("density_03", "0.3", 165, 18.5, hjust = 0, region = "legend")
density_keys <- data.frame(x = c(139,159), xend = c(143,163), y = 18.5, yend = 18.5, level = c(.2,.3), linetype = c("dashed","solid"))
add_text("donor_title", "Donor", 8, 11.5, size = 8.000001, hjust = 0, region = "legend")
for (i in seq_len(8)) {
  x <- 26 + (i - 1) * 18.4
  category <- paste0("PKD", i)
  add_key(category, x, 11.5)
  add_text(paste0("donor_", category), category, x + 3, 11.5, hjust = 0, region = "legend")
}
for (i in seq_len(5)) {
  x <- 26 + (i - 1) * 27.4
  category <- paste0("control", i)
  add_key(category, x, 5)
  add_text(paste0("donor_", category), category, x + 3, 5, hjust = 0, region = "legend")
}
stopifnot(all(texts$label %in% spec$text_contract$allowed_text), !anyNA(keys$color))
# Actual registered Arial glyph extents at final physical size, including rotated
# tangent labels, bold counts and the full 13-donor legend. Reject collisions.
grDevices::pdf(NULL, width = width / 25.4, height = height / 25.4, family = font$family)
grid::grid.newpage()
text_metrics <- do.call(rbind, lapply(seq_len(nrow(texts)), function(i) {
  z <- texts[i, ]
  g <- grid::textGrob(z$label, x = grid::unit(z$x, "mm"), y = grid::unit(z$y, "mm"),
    just = c(z$hjust, z$vjust), rot = z$angle,
    gp = grid::gpar(fontfamily = font$family, fontface = z$face, fontsize = z$size_pt, lineheight = .95))
  data.frame(z, xmin_mm = grid::convertX(grid::grobX(g, 180), "mm", valueOnly = TRUE),
    xmax_mm = grid::convertX(grid::grobX(g, 0), "mm", valueOnly = TRUE),
    ymin_mm = grid::convertY(grid::grobY(g, 270), "mm", valueOnly = TRUE),
    ymax_mm = grid::convertY(grid::grobY(g, 90), "mm", valueOnly = TRUE),
    actual_width_mm = grid::convertWidth(grid::grobWidth(g), "mm", valueOnly = TRUE),
    actual_height_mm = grid::convertHeight(grid::grobHeight(g), "mm", valueOnly = TRUE))
}))
grDevices::dev.off()
stopifnot(all(text_metrics$xmin_mm >= 0), all(text_metrics$xmax_mm <= width),
  all(text_metrics$ymin_mm >= 0), all(text_metrics$ymax_mm <= height),
  all(text_metrics$ymin_mm[text_metrics$region == "legend"] >= 2),
  all(text_metrics$ymax_mm[text_metrics$region == "legend"] <= 22))
text_overlaps <- list()
for (i in seq_len(nrow(text_metrics) - 1L)) for (j in (i + 1L):nrow(text_metrics)) {
  a <- text_metrics[i, ]; b <- text_metrics[j, ]
  if (min(a$xmax_mm, b$xmax_mm) - max(a$xmin_mm, b$xmin_mm) > .02 &&
      min(a$ymax_mm, b$ymax_mm) - max(a$ymin_mm, b$ymin_mm) > .02) {
    text_overlaps[[length(text_overlaps) + 1L]] <- c(a$id, b$id)
  }
}
if (length(text_overlaps)) stop("Actual text-bbox collision: ",
  paste(vapply(text_overlaps, paste, character(1), collapse = " / "), collapse = "; "))
label_backgrounds <- text_metrics[text_metrics$region == "inner", ]
p <- ggplot2::ggplot() +
  ggplot2::annotation_custom(native_grob, xmin = circle_mm["xmin"], xmax = circle_mm["xmax"],
    ymin = circle_mm["ymin"], ymax = circle_mm["ymax"]) +
  ggplot2::geom_segment(data = track_callouts, ggplot2::aes(x=x, y=y, xend=xend, yend=yend), colour=palette[["text"]], linewidth=.12) +
  ggplot2::geom_segment(data = leaders, ggplot2::aes(x = anchor_x, y = anchor_y,
    xend = x, yend = y, colour = color), linewidth = .14, lineend = "round") +
  ggplot2::geom_rect(data = label_backgrounds, ggplot2::aes(xmin = xmin_mm - .3, xmax = xmax_mm + .3,
    ymin = ymin_mm - .2, ymax = ymax_mm + .2), fill = grDevices::adjustcolor("white", .86), colour = NA) +
  ggplot2::geom_rect(data = keys, ggplot2::aes(xmin = xmin, xmax = xmax,
    ymin = ymin, ymax = ymax, fill = color), colour = NA) +
  ggplot2::geom_segment(data = density_keys, ggplot2::aes(x = x, y = y, xend = xend, yend = yend, linetype=linetype),
    colour = grDevices::adjustcolor(palette[["density"]], .7), linewidth = .23) +
  ggplot2::geom_text(data = texts, ggplot2::aes(x = x, y = y, label = label, angle = angle,
    hjust = hjust, vjust = vjust, fontface = face, size = size_pt / ggplot2::.pt, colour = color),
    family = font$family, lineheight = .95) +
  ggplot2::scale_size_identity(guide = "none") + ggplot2::scale_fill_identity(guide = "none") +
  ggplot2::scale_colour_identity(guide = "none") + ggplot2::scale_linetype_identity(guide="none") +
  ggplot2::coord_fixed(xlim = c(0, width), ylim = c(0, height), expand = FALSE, clip = "off") +
  ggplot2::theme_void(base_family = font$family, base_size = 7.5) +
  ggplot2::theme(plot.margin = ggplot2::margin(0, 0, 0, 0, "mm"),
    plot.background = ggplot2::element_rect(fill = "white", colour = NA),
    panel.background = ggplot2::element_rect(fill = "white", colour = NA))
macro <- data.frame(id = c("data", "labels", "legend"), x = c(20, 0, 8),
  y = c(25, 25, 2), w = c(140, 180, 164), h = c(140, 145, 20))
# One YAML only; source order is shared with the caller's single-use authorization.
sources <- c(spec_path, file.path(root, "scripts/render.R"), file.path(skill, "scripts/figure_style.R"),
  paths, qc_path)
auth_doc <- jsonlite::fromJSON(authorization, simplifyVector = FALSE)
dpi <- 600
if (!is.null(auth_doc$render$dpi)) dpi <- as.numeric(auth_doc$render$dpi)
if (!is.null(auth_doc$dpi)) dpi <- as.numeric(auth_doc$dpi)
stopifnot(dpi %in% c(400, 600))
prefix <- "circular_embedding_adpkd_recolored"
png <- file.path(work, paste0(prefix, ".png"))
bf_render_png(p, png, font = font, allowed_text = spec$text_contract$allowed_text,
  width_mm = width, height_mm = height, target_width_mm = width, dpi = dpi,
  min_text_pt = 7.5, source_files = sources, boxes = macro, allowed_pairs = "data:labels",
  authorization = authorization, skill_root = skill, publication_size_class = "double-column")
pdf <- file.path(root, "results/figures", paste0(prefix, ".pdf"))
dir.create(dirname(pdf), recursive = TRUE, showWarnings = FALSE)
grDevices::quartz(type = "pdf", file = pdf, width = width / 25.4, height = height / 25.4,
  family = font$family, bg = "white")
print(p); grDevices::dev.off()
svg <- file.path(work, paste0(prefix, "-gate-qa.svg"))
svglite::svglite(svg, width = width / 25.4, height = height / 25.4, bg = "white",
  system_fonts = list(sans = font$family))
print(p); grDevices::dev.off()
bind <- function(path) list(path = normalizePath(path, mustWork = TRUE),
  sha256 = digest::digest(file = path, algo = "sha256"))
packages <- c("circlize", "MASS", "gridGraphics", "ggplotify", "ggplot2", "ragg", "systemfonts",
  "yaml", "jsonlite", "digest", "svglite")
metrics <- list(schema_version = 1, scope = spec$scientific_message,
  counts = list(cells = nrow(cells), captured_vector_points = captured_point_n, cell_types = nrow(clusters),
    donors = length(donor_order), metadata_tracks = 3L, metadata_segments = nrow(segments),
    all_track_rectangles = nrow(native_segments), density_lines = length(unique(contours$contour_id)),
    density_vertices = nrow(contours), outer_labels = nrow(outer), inner_labels = nrow(inner),
    center_leader_lines = nrow(leaders), raster_grobs = raster_n, excluded_cells = 0L),
  geometry = list(canvas_mm = c(width, height), circle_mm = as.list(circle_mm),
    native_canvas_xlim = native_xlim, native_canvas_ylim = native_ylim,
    circle_center_mm = as.list(circle_center), mm_per_native_unit = mm_per_native_unit,
    coordinate_transform = qc$coordinate_transform, native_primitives = native_primitive,
    sector_order = cluster_order, sector_width_rule = "320*log10(n)/sum(log10(n)) degrees",
    gap_after_degrees = clusters$gap_after_deg, polar_transform_applied_to_cells = FALSE,
    actual_track_geometry = native_tracks, actual_segment_geometry = native_segments,
    actual_native_angle_verified = TRUE),
  palette = as.list(palette), point_alpha = .25,
  actual_point_coordinate_and_named_color_match = TRUE,
  global_density = qc$kde, density_line_mapping = density_keys, track_name_callouts = track_callouts, inner_class_label_mapping = inner,
  outer_class_label_mapping = outer, legend_mapping = keys,
  actual_text_metrics_mm = text_metrics, text_bbox_collisions = text_overlaps,
  source_files = lapply(sources, bind), artifacts = list(pdf = bind(pdf), png = bind(png), svg_qa = bind(svg)),
  render_receipt = bind(paste0(png, ".render.json")),
  environment = list(R = R.version.string, platform = R.version$platform,
    packages = as.list(setNames(vapply(packages, function(x) as.character(utils::packageVersion(x)),
      character(1)), packages)), font = list(family = font$family, path = font$path,
        sha256 = digest::digest(file = font$path, algo = "sha256"))),
  scientific_boundary = "Published processed coordinates reused unchanged under one common scale; exact captured-cell conditional metadata fractions only; no biological inferential n, percent.mt, sequencing or UMAP recomputation",
  original_paper_ring_fidelity = "NOT_APPLICABLE_METHOD_TRANSFER",
  new_input_transfer = "NOT_VERIFIED", stress_qualification = "NOT_VERIFIED",
  CP4 = "PENDING_ACTUAL_SOURCE_AND_FINAL_SIZE_REVIEW")
dir.create(file.path(root, "results/tables"), recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(metrics, file.path(root, "results/tables/render-metrics.json"),
  pretty = TRUE, auto_unbox = TRUE, digits = 17)
cat("Native R vector render written; source and final-size visual QA remains required.\n")
