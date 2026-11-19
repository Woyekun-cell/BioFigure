# Run the retained tutorial plot code with the source-table adaptation.
# Geometry and annotation are audited separately from the export device.
args <- commandArgs(TRUE)
stopifnot(length(args) == 3L)
p <- normalizePath(args[1])
w <- normalizePath(args[2])
out <- normalizePath(args[3])
s <- file.path(p, "biofigure")
case <- file.path(s, "benchmark/library/topjournal/issue_106")
style <- file.path(s, "scripts/figure_style.R")
design <- file.path(w, "design-spec.yaml")
spec <- yaml::read_yaml(design)
width <- spec$output_size$width_mm
height <- spec$output_size$height_mm
scale <- width / (10.5 * 25.4)
input <- file.path(case, "plot_data/publisher_fig1c_adapted.csv")
code <- file.path(case, "scripts/article-code-extracted.txt")
source(style)
font <- bf_font("Arial")
txt <- gsub("\u00a0", " ", readLines(code, encoding = "UTF-8"), fixed = TRUE)
stopifnot(sum(grepl('"cell_state_data.csv"', txt, fixed = TRUE)) == 1L)
txt <- sub('"cell_state_data.csv"', deparse(input, width.cutoff = 500L), txt, fixed = TRUE)
txt <- sub('base_family = "sans"', 'base_family = "Arial"', txt, fixed = TRUE)
# Proportional physical sizing for the same source aspect ratio.
txt <- gsub("(?<![a-z_])((?:base_size|size|stroke|linewidth|max_size)\\s*=\\s*)([0-9.]+)",
            "\\1(\\2 * physical_scale)", txt, perl = TRUE)
txt <- sub("range = c(0, 5.8)", "range = c(0, 5.8 * physical_scale)", txt, fixed = TRUE)
txt <- gsub("(unit\\()([0-9.]+)(, \"mm\"\\))", "\\1(\\2 * physical_scale)\\3", txt, perl = TRUE)
txt <- sub("margin(4, 6, 4, 9)", "margin(4 * physical_scale, 6 * physical_scale, 4 * physical_scale, 9 * physical_scale)", txt, fixed = TRUE)
src <- parse(text = txt)
stopifnot(length(src) == 45L, identical(src[[length(src)]][[1]], quote(ggsave)))
env <- new.env()
env$physical_scale <- scale
env$geom_text <- function(...) ggplot2::geom_text(..., family = "Arial")
# get_legend measures on a temporary device. Use the installed Arial face there.
for (e in head(src, -1L)) {
  eval(e, env)
  if (identical(e, quote(library(cowplot)))) cowplot::set_null_device("agg")
}
stopifnot(nrow(env$cell_states) == 28L)
tips <- subset(env$p_tree$data, isTip)
stopifnot(nrow(tips) == 28L,
          identical(as.character(tips$label[order(tips$y)]), env$cell_states$state),
          isTRUE(all.equal(sort(as.numeric(tips$y)), seq_len(28), check.attributes = FALSE)))
counts <- c(program = 168L, tumor = 336L, expression = 616L, pathway = 168L)
for (track in names(counts)) {
  layer <- ggplot2::ggplot_build(env[[paste0("p_", track)]])$data[[2]]
  pos <- if (track %in% c("program", "tumor")) c("x", "ymin", "ymax", "fill") else c("x", "y", "size", "fill")
  stopifnot(nrow(layer) == counts[[track]], all(complete.cases(layer[pos])),
            identical(sort(unique(as.numeric(layer$x))), as.numeric(seq_len(28))))
}
# Preflight the full patchwork gtable inside the standard ggplot renderer.
ragg::agg_capture(width / 25.4, height / 25.4, units = "in", res = 300)
assembled <- patchwork::patchworkGrob(env$final_plot)
invisible(dev.off())
plot <- ggplot2::ggplot() + ggplot2::annotation_custom(assembled) +
  ggplot2::coord_cartesian(expand = FALSE) + ggplot2::theme_void(base_family = font$family)
files <- c(design, style, input, code, file.path(case, "scripts/prepare_publisher_input.R"),
           file.path(case, "scripts/render_publisher_adaptation.R"), file.path(w, "source-review-receipt.json"))
auth <- file.path(out, "authorization.json")
cmd <- c(file.path(s, "scripts/authorize_render.py"), "--receipt", file.path(w, "preparation-receipt.json"),
         "--design-spec", design, "--output", auth,
         unlist(lapply(files[-1], function(f) c("--source", f))))
stopifnot(system2("python3", shQuote(cmd)) == 0L)
boxes <- data.frame(id = c("data", "labels", "legend"), x = 0, y = 0, w = width, h = height)
png <- file.path(out, "fig1c-publisher-adaptation.png")
pdf <- file.path(out, "fig1c-publisher-adaptation.pdf")
receipt <- bf_render_png(plot, png, font, unlist(spec$text_contract$allowed_text),
  width, height, width, files, boxes, allowed_pairs = c("data:labels", "data:legend", "labels:legend"),
  dpi = 300, min_text_pt = 7.8, authorization = auth, skill_root = s,
  publication_size_class = "custom", size_override_basis = spec$output_size$size_rationale$override_basis)
bf_pdf_open(pdf, width, height, font)
grid::grid.newpage()
grid::grid.draw(assembled)
invisible(dev.off())
jsonlite::write_json(bf_pdf_finalize(pdf, font, width, height),
  file.path(out, "pdf-technical-audit.json"), auto_unbox = TRUE, pretty = TRUE)
jsonlite::write_json(list(tree_tip_count = nrow(tips), aligned_state_order = env$cell_states$state,
  rendered_mark_counts = as.list(counts), sizes_pt = receipt$target_min_text_pt),
  file.path(out, "built-layer-audit.json"), auto_unbox = TRUE, pretty = TRUE)
capture.output(sessionInfo(), file = file.path(out, "render-sessionInfo.txt"))
