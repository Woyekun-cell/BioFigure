#!/usr/bin/env Rscript
# Formal Fig.4b only: source-complete Merian paintings and real-branch phylogram.
# Original layout was reviewed before this adapted physical-mm renderer was written.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 3L)
root <- normalizePath(args[1], mustWork = TRUE)
work <- normalizePath(args[2], mustWork = TRUE)
authorization <- normalizePath(args[3], mustWork = TRUE)
skill <- Sys.getenv("BIOFIGURE_SKILL_ROOT", normalizePath(file.path(root, "../../../.."), mustWork = TRUE))
source(file.path(skill, "scripts", "figure_style.R"))
options(warn = 2)
font <- bf_font("Arial")
bf_complexheatmap_font(font)
spec_path <- file.path(root, "data/metadata/design-spec.yaml")
spec <- yaml::read_yaml(spec_path)
stopifnot(spec$output_size$width_mm == 180, spec$output_size$height_mm == 170,
          spec$output_size$size_class == "double-column", spec$font_contract$family == "Arial",
          normalizePath(spec$font_contract$resolved_font_file) == normalizePath(font$path))
italic_font <- systemfonts::match_fonts("Arial", italic = TRUE)
bold_font <- systemfonts::match_fonts("Arial", weight = "bold")
stopifnot(file.exists(italic_font$path), file.exists(bold_font$path),
          systemfonts::font_info(path = italic_font$path)$family[1] == "Arial",
          systemfonts::font_info(path = bold_font$path)$family[1] == "Arial")
paths <- file.path(root, "data/plot_data", c("fig4b_chromosomes.csv", "fig4b_loci.csv", "fig4b_ggtree_data.csv"))
chr <- read.csv(paths[1], stringsAsFactors = FALSE, check.names = FALSE)
loci <- read.csv(paths[2], stringsAsFactors = FALSE, check.names = FALSE)
tree <- read.csv(paths[3], stringsAsFactors = FALSE, check.names = FALSE)
species <- c("Anthocharis_cardamines", "Aporia_crataegi", "Pieris_rapae", "Pieris_brassicae", "Pieris_napi")
# User-selected three-anchor gradient supplies named categorical identities;
# the progression has no ordinal or numeric biological meaning.
palette <- unlist(spec$palette_semantics, use.names = TRUE)
merians <- c("MZ", paste0("M", 1:31))
stopifnot(nrow(chr) == 120L, nrow(loci) == 20316L, nrow(tree) == 9L,
  sum(tree$isTip) == 5L, sum(tree$node != tree$parent) == 8L,
  setequal(chr$species, species), setequal(tree$label[tree$isTip], species),
  all(c(merians, "self", "ancestral", "rearranged", "tree") %in% names(palette)),
  !anyDuplicated(paste(loci$species, loci$busco_id)),
  all(loci$marker_end_bp - loci$marker_start_bp == 40000),
  sum(loci$paint_class == "self") == 10964L, sum(loci$paint_class != "self") == 9352L)
width <- 180; height <- 170; column_width <- 31.2; column_pitch <- 34
data_bottom <- 38; data_top <- 125; column_left <- 7 + column_pitch * (0:4)
domain_records <- vector("list", length(species))
axes <- data.frame(); ticks <- data.frame()
for (name in c("xmin_mm","xmax_mm","ymin_mm","ymax_mm","row_pitch_mm")) chr[[name]] <- NA_real_
for (name in c("xmin_mm","xmax_mm","ymin_mm","ymax_mm")) loci[[name]] <- NA_real_
for (i in seq_along(species)) {
  ci <- which(chr$species == species[i]); li <- which(loci$species == species[i])
  n_chr <- length(ci)
  expected_order <- order(match(chr$rearrangement_status[ci], c("fusion", "split", "ancestral")), chr$chromosome_id[ci])
  stopifnot(identical(expected_order, seq_along(ci)),
            identical(chr$author_order_within_species[ci], seq_len(n_chr)))
  # Original scale_x_continuous(expand=c(.005,1)), trained on every rectangle.
  source_range <- range(c(0, chr$chromosome_length_bp[ci], loci$marker_start_bp[li], loci$marker_end_bp[li]))
  span <- diff(source_range)
  domain <- source_range + c(-1, 1) * (.005 * span + 1)
  x_map <- function(z) column_left[i] + column_width * (z - domain[1]) / diff(domain)
  pitch <- (data_top - data_bottom) / n_chr
  centers <- data_top - (seq_len(n_chr) - .5) * pitch
  chr$xmin_mm[ci] <- x_map(0); chr$xmax_mm[ci] <- x_map(chr$chromosome_length_bp[ci])
  chr$ymin_mm[ci] <- centers - .4 * pitch; chr$ymax_mm[ci] <- centers + .4 * pitch
  chr$row_pitch_mm[ci] <- pitch
  cm <- match(loci$chromosome_id[li], chr$chromosome_id[ci])
  stopifnot(!anyNA(cm))
  loci$xmin_mm[li] <- x_map(loci$marker_start_bp[li]); loci$xmax_mm[li] <- x_map(loci$marker_end_bp[li])
  loci$ymin_mm[li] <- chr$ymin_mm[ci][cm]; loci$ymax_mm[li] <- chr$ymax_mm[ci][cm]
  values_mb <- scales::breaks_extended(n = 5)(domain / 1e6)
  values_mb <- values_mb[values_mb * 1e6 >= domain[1] & values_mb * 1e6 <= domain[2]]
  labels <- format(values_mb, trim = TRUE, scientific = FALSE)
  labels <- sub("\\.0+$", "", labels)
  ticks <- rbind(ticks, data.frame(species = species[i], bp = values_mb * 1e6,
    x = x_map(values_mb * 1e6), label = labels, stringsAsFactors = FALSE))
  axes <- rbind(axes, data.frame(x = column_left[i], xend = column_left[i] + column_width,
    y = data_bottom, yend = data_bottom))
  domain_records[[i]] <- list(species = species[i], source_range_bp = source_range,
    source_expanded_domain_bp = domain, column_left_mm = column_left[i],
    column_width_mm = column_width, row_pitch_mm = pitch, rows = n_chr)
}
stopifnot(identical(as.integer(table(factor(chr$species, levels = species))), c(30L,25L,25L,15L,25L)),
  all(loci$xmax_mm > loci$xmin_mm), all(loci$ymax_mm > loci$ymin_mm))
chr$outline_color <- unname(palette[ifelse(chr$rearrangement_status == "ancestral", "ancestral", "rearranged")])
loci$fill_color <- unname(palette[loci$paint_class])
stopifnot(!anyNA(chr$outline_color), !anyNA(loci$fill_color))
tree$x_mm <- column_left[1] + column_width / 2 + column_pitch * (tree$y - 1)
tree$y_mm <- 166 - 32 * tree$x / max(tree$x)
child <- tree[tree$node != tree$parent, , drop = FALSE]
parent <- tree[match(child$parent, tree$node), , drop = FALSE]
stopifnot(nrow(child) == 8L, all(abs((child$x - parent$x) - child$branch.length) < 1e-15))
branches <- rbind(
  data.frame(parent = child$parent, child = child$node, piece = "across",
    x = parent$x_mm, xend = child$x_mm, y = parent$y_mm, yend = parent$y_mm),
  data.frame(parent = child$parent, child = child$node, piece = "down",
    x = child$x_mm, xend = child$x_mm, y = parent$y_mm, yend = child$y_mm))
stopifnot(all(abs(tree$x_mm[tree$isTip] -
   (column_left[match(tree$label[tree$isTip], species)] + column_width / 2)) < 1e-12))
dot <- tree[tree$node == 7L, , drop = FALSE]
texts <- data.frame()
add_text <- function(id, label, x, y, size = 7.500001, face = "plain", angle = 0,
                     hjust = .5, vjust = .5, region = "tree") {
  texts <<- rbind(texts, data.frame(id = id, label = label, x = x, y = y,
    size_pt = size, face = face, angle = angle, hjust = hjust, vjust = vjust,
    region = region, stringsAsFactors = FALSE))
}
add_text("panel", "b", 3, 167, size = 8.000001, face = "bold", hjust = 0)
for (i in seq_along(species)) {
  tip <- tree[tree$label == species[i] & !is.na(tree$label), , drop = FALSE]
  stopifnot(nrow(tip) == 1L)
  add_text(paste0("species_", i), gsub("_", " ", species[i]), tip$x_mm, tip$y_mm - 4, face = "italic")
  add_text(paste0("chr_count_", i), paste0("n = ", sum(chr$species == species[i])), tip$x_mm, tip$y_mm - 7)
}
# Source branch-event annotations retained verbatim; physical positions are reflowed
# within the reviewed tree region, never inferred or recalculated.
add_text("event_1", "1 fusion", tree$x_mm[tree$node == 1] + 2, 157, hjust = 0)
add_text("event_7", "18 fusions, 38 fissions", dot$x_mm + 2.5, dot$y_mm + 2.6, hjust = 0)
add_text("clade_7", "Pierini", dot$x_mm, dot$y_mm - 3.3)
add_text("event_2", "39 fusions\n13 fissions", tree$x_mm[tree$node == 2] + 2, 145.5, hjust = 0)
add_text("event_8", "35 fusions,\n9 fissions", tree$x_mm[tree$node == 8] + 2.5, 148, hjust = 0)
add_text("event_3", "10 fusions", tree$x_mm[tree$node == 3] + 2, 137.3, hjust = 0)
for (i in seq_len(nrow(ticks))) add_text(paste0("tick_", i), ticks$label[i], ticks$x[i], 35.8,
  angle = 90, hjust = 1, region = "axes")
add_text("axis_title", "Chromosome position (Mb)", 90, 25.8, size = 8.000001, region = "axes")
add_text("merian_title", "Merian element", 7, 22, size = 8.000001, hjust = 0, region = "legend")
keys <- data.frame()
for (i in seq_along(merians)) {
  row <- if (i <= 17L) 1L else 2L
  index <- if (row == 1L) i - 1L else i - 18L
  x <- 7 + 8.8 * index; y <- if (row == 1L) 17.4 else 12.6
  keys <- rbind(keys, data.frame(merian = merians[i], xmin = x, xmax = x + 1.6,
    ymin = y - 1.2, ymax = y + 1.2, color = palette[[merians[i]]]))
  add_text(paste0("key_", merians[i]), merians[i], x + 2.3, y, hjust = 0, region = "legend")
}
dominant_x <- 7 + 8.8 * 15L
keys <- rbind(keys, data.frame(merian = "self", xmin = dominant_x, xmax = dominant_x + 1.6,
  ymin = 11.4, ymax = 13.8, color = palette[["self"]]))
add_text("key_self", "Dominant element", dominant_x + 2.3, 12.6, hjust = 0, region = "legend")
add_text("status_title", "Rearrangement status", 7, 5.5, size = 8.000001, hjust = 0, region = "legend")
status_keys <- data.frame(status = c("ancestral", "rearranged"), xmin = c(45,79),
  xmax = c(48,82), ymin = 4.3, ymax = 6.7,
  color = unname(palette[c("ancestral", "rearranged")]))
add_text("key_ancestral", "Ancestral", 50, 5.5, hjust = 0, region = "legend")
add_text("key_rearranged", "Rearranged", 84, 5.5, hjust = 0, region = "legend")
stopifnot(all(texts$label %in% spec$text_contract$allowed_text))
# Actual font metrics on a registered Arial PDF measurement device, including
# italic/bold faces, multiline source events and vertical source-axis ticks.
grDevices::pdf(NULL, width = width / 25.4, height = height / 25.4, family = font$family)
grid::grid.newpage()
metric_rows <- lapply(seq_len(nrow(texts)), function(i) {
  z <- texts[i, ]
  g <- grid::textGrob(z$label, x = grid::unit(z$x, "mm"), y = grid::unit(z$y, "mm"),
    just = c(z$hjust,z$vjust), rot = z$angle,
    gp = grid::gpar(fontfamily = font$family, fontface = z$face, fontsize = z$size_pt, lineheight = .95))
  data.frame(z, xmin_mm = grid::convertX(grid::grobX(g, 180), "mm", valueOnly = TRUE),
    xmax_mm = grid::convertX(grid::grobX(g, 0), "mm", valueOnly = TRUE),
    ymin_mm = grid::convertY(grid::grobY(g, 270), "mm", valueOnly = TRUE),
    ymax_mm = grid::convertY(grid::grobY(g, 90), "mm", valueOnly = TRUE),
    actual_width_mm = grid::convertWidth(grid::grobWidth(g), "mm", valueOnly = TRUE),
    actual_height_mm = grid::convertHeight(grid::grobHeight(g), "mm", valueOnly = TRUE))
})
text_metrics <- do.call(rbind, metric_rows)
grDevices::dev.off()
stopifnot(all(text_metrics$xmin_mm >= 0), all(text_metrics$xmax_mm <= width),
          all(text_metrics$ymin_mm >= 0), all(text_metrics$ymax_mm <= height),
          all(text_metrics$ymin_mm[text_metrics$region == "tree"] >= 125),
          all(text_metrics$ymin_mm[text_metrics$region == "legend"] >= 3),
          all(text_metrics$ymax_mm[text_metrics$region == "legend"] <= 23.5))
text_overlaps <- list()
for (i in seq_len(nrow(text_metrics) - 1L)) for (j in (i + 1L):nrow(text_metrics)) {
  a <- text_metrics[i, ]; b <- text_metrics[j, ]
  if (min(a$xmax_mm,b$xmax_mm) - max(a$xmin_mm,b$xmin_mm) > .02 &&
      min(a$ymax_mm,b$ymax_mm) - max(a$ymin_mm,b$ymin_mm) > .02) {
    text_overlaps[[length(text_overlaps) + 1L]] <- c(a$id,b$id)
  }
}
if (length(text_overlaps)) stop("Actual text-bbox collision: ", paste(vapply(text_overlaps,paste,character(1),collapse=" / "),collapse="; "))
count_gap <- min(text_metrics$ymin_mm[grepl("^chr_count_",text_metrics$id)]) - max(chr$ymax_mm)
stopifnot(count_gap > 1)
p <- ggplot2::ggplot() +
  ggplot2::geom_rect(data = chr, ggplot2::aes(xmin = xmin_mm,xmax = xmax_mm,ymin = ymin_mm,ymax = ymax_mm), fill = "white", colour = NA) +
  ggplot2::geom_rect(data = loci, ggplot2::aes(xmin = xmin_mm,xmax = xmax_mm,ymin = ymin_mm,ymax = ymax_mm,fill = fill_color), colour = NA) +
  ggplot2::geom_rect(data = chr, ggplot2::aes(xmin = xmin_mm,xmax = xmax_mm,ymin = ymin_mm,ymax = ymax_mm,colour = outline_color), fill = NA, linewidth = .12) +
  ggplot2::geom_segment(data = axes, ggplot2::aes(x = x,xend = xend,y = y,yend = yend), colour = palette[["tree"]], linewidth = .12) +
  ggplot2::geom_segment(data = ticks, ggplot2::aes(x = x,xend = x,y = 38,yend = 36.8), colour = palette[["tree"]], linewidth = .12) +
  ggplot2::geom_segment(data = branches, ggplot2::aes(x = x,xend = xend,y = y,yend = yend), colour = palette[["tree"]], linewidth = .12) +
  ggplot2::geom_point(data = dot, ggplot2::aes(x = x_mm,y = y_mm), shape = 21, size = 2,
    stroke = .12, fill = palette[["rearranged"]], colour = palette[["rearranged"]]) +
  ggplot2::geom_rect(data = keys, ggplot2::aes(xmin = xmin,xmax = xmax,ymin = ymin,ymax = ymax,fill = color), colour = NA) +
  ggplot2::geom_rect(data = status_keys, ggplot2::aes(xmin = xmin,xmax = xmax,ymin = ymin,ymax = ymax,colour = color), fill = "white", linewidth = .12) +
  ggplot2::geom_text(data = texts, ggplot2::aes(x = x,y = y,label = label,angle = angle,hjust = hjust,vjust = vjust,fontface = face,size = size_pt / ggplot2::.pt),
    family = font$family, colour = "#30343B", lineheight = .95) +
  ggplot2::scale_size_identity(guide = "none") + ggplot2::scale_fill_identity(guide = "none") +
  ggplot2::scale_colour_identity(guide = "none") +
  ggplot2::coord_fixed(xlim = c(0,width),ylim = c(0,height),expand = FALSE,clip = "off") +
  ggplot2::theme_void(base_family = font$family,base_size = 7.5) +
  ggplot2::theme(plot.margin = ggplot2::margin(0,0,0,0,"mm"),
    plot.background = ggplot2::element_rect(fill = "white",colour = NA),
    panel.background = ggplot2::element_rect(fill = "white",colour = NA))
macro <- data.frame(id = c("data","labels","legend"),x = c(7,0,7),y = c(38,24,3),
  w = c(167.2,180,167),h = c(87,145,20.5))
sources <- c(spec_path,file.path(root,"scripts/render.R"),file.path(skill,"scripts/figure_style.R"),paths)
prefix <- "fig4b_merian_recolored"
png <- file.path(root,"results/figures",paste0(prefix,".png"))
bf_render_png(p,png,font = font,allowed_text = spec$text_contract$allowed_text,width_mm = width,height_mm = height,
  target_width_mm = width,dpi = 600,min_text_pt = 7.5,source_files = sources,boxes = macro,
  allowed_pairs = "data:labels",authorization = authorization,skill_root = skill,publication_size_class = "double-column")
pdf <- file.path(root,"results/figures",paste0(prefix,".pdf"))
dir.create(dirname(pdf),recursive = TRUE,showWarnings = FALSE)
grDevices::quartz(type = "pdf",file = pdf,width = width/25.4,height = height/25.4,family = font$family,bg = "white")
print(p); grDevices::dev.off()
svg <- file.path(work,paste0(prefix,"-gate-qa.svg"))
svglite::svglite(svg,width = width/25.4,height = height/25.4,bg = "white",system_fonts = list(sans = font$family))
print(p); grDevices::dev.off()
bind <- function(path) list(path = normalizePath(path,mustWork = TRUE),sha256 = digest::digest(file = path,algo = "sha256"))
metrics <- list(schema_version = 1,scope = spec$scientific_message,
  counts = list(chromosomes = nrow(chr),loci = nrow(loci),dominant_neutral = sum(loci$paint_class == "self"),
    alternative_colored = sum(loci$paint_class != "self"),merian_identities = length(merians),
    original_marker_overhangs = sum(loci$marker_start_bp < 0 | loci$marker_end_bp > loci$chromosome_length_bp),
    tree_tips = 5L,tree_branches = nrow(child),tree_line_segments = nrow(branches),published_event_annotations = 5L),
  source_species_order = species,source_domains = domain_records,source_marker_width_bp = 40000,
  geometry = list(canvas_mm = c(width,height),data_bottom_top_mm = c(data_bottom,data_top),
    column_left_mm = column_left,column_width_mm = column_width,column_pitch_mm = column_pitch,
    chromosome_height_fraction = .8,outline_linewidth_mm = .12,
    tree_x_rule = "7+15.6+34*(saved source y-1)",tree_y_rule = "166-32*saved source x/max(saved source x)",
    topology_and_real_branch_lengths_preserved = TRUE,marker_intervals_clipped = FALSE,
    minimum_font_pt = 7.5,vertical_source_axis_tick_angle = 90,count_to_data_gap_mm = count_gap),
  palette = as.list(palette),actual_text_metrics_mm = text_metrics,text_bbox_collisions = text_overlaps,
  semantic_chromosome_mapping = chr,
  semantic_locus_mapping = loci[,c("species","busco_id","chromosome_id","paint_class","fill_color",
    "position_bp","marker_start_bp","marker_end_bp","xmin_mm","xmax_mm","ymin_mm","ymax_mm")],
  source_tree_mapping = tree,source_branch_geometry_mm = branches,axis_mapping = ticks,
  legend_mapping = keys,status_legend_mapping = status_keys,
  input_qc_audit_binding = bind(file.path(root,"data/metadata/data-qc.json")),
  source_files = lapply(sources,bind),artifacts = list(pdf = bind(pdf),png = bind(png),svg_qa = bind(svg)),
  render_receipt = bind(paste0(png,".render.json")),
  packages = list(R = R.version.string,ggplot2 = as.character(utils::packageVersion("ggplot2")),
    systemfonts = as.character(utils::packageVersion("systemfonts")),ragg = as.character(utils::packageVersion("ragg"))),
  scientific_boundary = "Author processed data and branch-event annotations only; no raw NGS or published inference recalculation",
  original_whole_fig4_fidelity = "NOT_VERIFIED",new_input_transfer = "NOT_VERIFIED",stress_qualification = "NOT_VERIFIED",
  CP4 = "PENDING_ACTUAL_SOURCE_AND_FINAL_SIZE_REVIEW")
dir.create(file.path(root,"results/tables"),recursive = TRUE,showWarnings = FALSE)
jsonlite::write_json(metrics,file.path(root,"results/tables/render-metrics.json"),pretty = TRUE,auto_unbox = TRUE,digits = 17)
