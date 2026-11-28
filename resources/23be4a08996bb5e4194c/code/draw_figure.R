#!/usr/bin/env Rscript
# SPDX-License-Identifier: MIT
# MIT License
# 
# Copyright (c) 2026 BioFigure contributors
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# 
# This is the BioFigure CSV renderer; the authors' original scripts are linked, not redistributed.
# Dace et al., Nature Genetics (2026), Fig. 1c.
# Paper: https://doi.org/10.1038/s41588-026-02832-3
# Source data: https://www.nature.com/articles/s41588-026-02832-3#Sec17
# Author code: https://github.com/phoebedace/BRCA1_SGE_HAP1_HMEC/blob/main/Produce_figures.R#L218-L262
# Published numeric input and the source article: CC BY 4.0.
# Data licence: https://creativecommons.org/licenses/by/4.0/
# Adaptation: CSV-only rendering, revised palette and typography; see the gallery description.
# Run: Rscript draw_figure.R brca1-fig1c-plot-data.csv output_prefix

bf_ghostscript_command <-
function () 
{
    configured <- trimws(Sys.getenv("R_GSCMD", unset = ""))
    if (nchar(configured) >= 2 && substr(configured, 1, 1) %in% 
        c("\"", "'") && substr(configured, nchar(configured), 
        nchar(configured)) == substr(configured, 1, 1)) 
        configured <- substr(configured, 2, nchar(configured) - 
            1)
    resolve <- function(value) {
        candidate <- if (file.exists(value)) 
            value
        else unname(Sys.which(value))[1]
        if (!length(candidate) || is.na(candidate) || !nzchar(candidate) || 
            !file.exists(candidate) || dir.exists(candidate)) 
            return(NULL)
        normalizePath(candidate, winslash = "/", mustWork = TRUE)
    }
    if (nzchar(configured)) {
        command <- resolve(configured)
        if (is.null(command)) 
            stop("NEEDS_PDF_DEVICE: R_GSCMD must identify an existing Ghostscript executable; no fallback is allowed")
        return(command)
    }
    for (name in c("gs", "gswin64c", "gswin32c")) {
        command <- resolve(name)
        if (!is.null(command)) 
            return(command)
    }
    stop("NEEDS_PDF_DEVICE: install Ghostscript (gs/gswin64c/gswin32c) or set R_GSCMD to its executable")
}
.bf_pdf_font_faces <-
function (font) 
{
    if (!is.list(font) || !font$family %in% c("Arial", "Helvetica") || 
        !is.character(font$path) || length(font$path) != 1 || 
        !file.exists(font$path)) 
        stop("NEEDS_PDF_FONT: resolved Arial/Helvetica font required")
    matched <- systemfonts::match_fonts(rep(font$family, 4), 
        italic = c(FALSE, FALSE, TRUE, TRUE), weight = c("normal", 
            "bold", "normal", "bold"))
    info <- systemfonts::font_info(path = matched$path, index = matched$index)
    if (nrow(info) != 4 || any(info$family != font$family) || 
        any(!file.exists(matched$path)) || normalizePath(font$path) != 
        normalizePath(matched$path[1]) || font$index != matched$index[1]) 
        stop("NEEDS_PDF_FONT: font file/faces differ from the exact resolved family; substitution is forbidden")
    names <- if (font$family == "Arial") 
        c("ArialMT", "ArialMT-Bold", "ArialMT-Italic", "ArialMT-BoldItalic")
    else c("Helvetica", "Helvetica-Bold", "Helvetica-Oblique", 
        "Helvetica-BoldOblique")
    afm_dir <- file.path(R.home("library"), "grDevices", "afm")
    afm <- vapply(c(names, "Symbol"), function(name) {
        files <- file.path(afm_dir, paste0(name, c(".afm", ".afm.gz")))
        found <- files[file.exists(files)]
        if (!length(found)) 
            stop(paste("NEEDS_PDF_FONT: exact AFM metrics missing for", 
                name))
        found[1]
    }, character(1))
    for (i in seq_len(4)) {
        connection <- if (endsWith(afm[i], ".gz")) 
            gzfile(afm[i], open = "rt", encoding = "latin1")
        else file(afm[i], open = "rt", encoding = "latin1")
        header <- tryCatch(readLines(connection, n = 32, warn = FALSE), 
            finally = close(connection))
        ps <- sub("^FontName[[:space:]]+", "", header[grepl("^FontName[[:space:]]+", 
            header)])
        if (length(ps) != 1 || ps != info$name[i] || !grepl("^[A-Za-z0-9_.-]+$", 
            ps)) 
            stop("NEEDS_PDF_FONT: AFM PostScript face differs from the actual installed font; substitution is forbidden")
    }
    metrics <- grDevices::Type1Font(family = info$name[1], metrics = unname(afm), 
        encoding = "default")
    registered <- grDevices::pdfFonts()[[font$family]]
    same_metrics <- !is.null(registered) && identical(registered$family, 
        metrics$family) && identical(sub("[.]gz$", "", basename(registered$metrics)), 
        sub("[.]gz$", "", basename(metrics$metrics)))
    if (!same_metrics) 
        do.call(grDevices::pdfFonts, setNames(list(metrics), 
            font$family))
    lapply(seq_len(4), function(i) list(style = c("regular", 
        "bold", "italic", "bold-italic")[i], family = font$family, 
        postscript_name = info$name[i], path = normalizePath(matched$path[i], 
            winslash = "/", mustWork = TRUE), index = matched$index[i], 
        sha256 = digest::digest(file = matched$path[i], algo = "sha256"), 
        afm_path = normalizePath(afm[i], winslash = "/", mustWork = TRUE), 
        afm_sha256 = digest::digest(file = afm[i], algo = "sha256")))
}
.bf_gs_run <-
function (command, args) 
{
    output <- suppressWarnings(system2(command, args = shQuote(args), 
        stdout = TRUE, stderr = TRUE))
    status <- attr(output, "status")
    if (is.null(status)) 
        status <- 0L
    if (status != 0L) 
        stop(paste("NEEDS_PDF_DEVICE: Ghostscript failed; close the PDF device and verify R_GSCMD/version:", 
            paste(output, collapse = "\n")))
    if (any(grepl("substitut|can't find|cannot find|not found|cannot load|can't load|invalidfont|unknown font|failed to load", 
        output, ignore.case = TRUE))) 
        stop(paste("NEEDS_PDF_FONT: Ghostscript reported font/resource substitution:", 
            paste(output, collapse = "\n")))
    output
}
.bf_pdf_info <-
function (path, command) 
{
    query <- paste("/BFCtx << >> .PDFInit def BFFile (r) file BFCtx .PDFStream", 
        "BFCtx .PDFInfo (BF_PAGES=) print /NumPages get =", "BFCtx 0 .PDFPageInfoExt dup /MediaBox get (BF_BOX=) print ==", 
        "dup /Fonts known { /Fonts get { (BF_FONT=) print dup /BaseFont get", 
        "256 string cvs print (|) print /Embedded get == } forall } { pop } ifelse", 
        "BFCtx .PDFClose quit")
    output <- .bf_gs_run(command, c("-q", "-dNODISPLAY", "-dNOSAFER", 
        paste0("-sBFFile=", path), "-c", query))
    pages <- output[startsWith(output, "BF_PAGES=")]
    box <- output[startsWith(output, "BF_BOX=")]
    if (length(pages) != 1 || length(box) != 1) 
        stop("NEEDS_PDF_DEVICE: Ghostscript cannot audit actual PDF pages and font resources")
    pages <- suppressWarnings(as.integer(sub("BF_PAGES=", "", 
        pages, fixed = TRUE)))
    values <- strsplit(chartr("[]", "  ", sub("BF_BOX=", "", 
        box, fixed = TRUE)), "[[:space:]]+")[[1]]
    values <- suppressWarnings(as.numeric(values[nzchar(values)]))
    if (length(values) != 4 || any(!is.finite(values)) || length(pages) != 
        1 || is.na(pages)) 
        stop("invalid actual PDF page metrics")
    fonts <- lapply(output[startsWith(output, "BF_FONT=")], function(line) {
        fields <- strsplit(sub("BF_FONT=", "", line, fixed = TRUE), 
            "|", fixed = TRUE)[[1]]
        if (length(fields) != 2 || !fields[2] %in% c("true", 
            "false")) 
            stop("invalid actual PDF font embedding audit")
        list(name = fields[1], embedded = fields[2] == "true")
    })
    list(page_count = pages, width_mm = (values[3] - values[1]) * 
        25.399999999999999/72, height_mm = (values[4] - values[2]) * 
        25.399999999999999/72, fonts = fonts, inspection_log = output)
}
bf_pdf_open <-
function (path, width_mm, height_mm, font, bg = "#FFFFFF") 
{
    if (!is.numeric(width_mm) || length(width_mm) != 1 || !is.finite(width_mm) || 
        width_mm <= 0 || !is.numeric(height_mm) || length(height_mm) != 
        1 || !is.finite(height_mm) || height_mm <= 0) 
        stop("PDF width_mm and height_mm must be positive finite millimetres")
    if (!is.character(bg) || length(bg) != 1 || !toupper(bg) %in% 
        c("WHITE", "#FFFFFF")) 
        stop("PDF background must be opaque white")
    if (!is.null(path) && (!is.character(path) || length(path) != 
        1 || !nzchar(path))) 
        stop("PDF path must be one filename or NULL for measurement")
    faces <- .bf_pdf_font_faces(font)
    if (!is.null(path)) 
        bf_ghostscript_command()
    grDevices::pdf(file = path, width = width_mm/25.399999999999999, 
        height = height_mm/25.399999999999999, family = font$family, 
        bg = "#FFFFFF", useDingbats = FALSE, paper = "special", 
        compress = TRUE)
    invisible(list(device = grDevices::dev.cur(), font_faces = faces, 
        width_mm = width_mm, height_mm = height_mm))
}
bf_pdf_finalize <-
function (path, font, width_mm, height_mm) 
{
    if (!is.character(path) || length(path) != 1 || !file.exists(path)) 
        stop("PDF file required; close its device before finalization")
    if (!is.numeric(width_mm) || length(width_mm) != 1 || !is.finite(width_mm) || 
        width_mm <= 0 || !is.numeric(height_mm) || length(height_mm) != 
        1 || !is.finite(height_mm) || height_mm <= 0) 
        stop("PDF width_mm and height_mm must be positive finite millimetres")
    path <- normalizePath(path, winslash = "/", mustWork = TRUE)
    command <- bf_ghostscript_command()
    faces <- .bf_pdf_font_faces(font)
    input_hash <- digest::digest(file = path, algo = "sha256")
    initial <- .bf_pdf_info(path, command)
    if (initial$page_count != 1) 
        stop("standalone figure PDF must contain exactly one page")
    initial_error_pt <- c(width = (initial$width_mm - width_mm) * 
        72/25.399999999999999, height = (initial$height_mm - 
        height_mm) * 72/25.399999999999999)
    if (any(abs(initial_error_pt) > 1.0001)) 
        stop("input PDF size differs from requested size beyond base-R whole-point quantization")
    embedded <- tempfile("bf-embedded-", tmpdir = dirname(path), 
        fileext = ".pdf")
    fontmap <- tempfile("bf-fontmap-", tmpdir = dirname(path))
    on.exit(unlink(c(embedded, fontmap)), add = TRUE)
    hex <- function(value) paste(sprintf("%02x", as.integer(charToRaw(enc2utf8(value)))), 
        collapse = "")
    writeLines(vapply(faces, function(face) paste0("/", face$postscript_name, 
        " <", hex(face$path), "> ;"), character(1)), fontmap, 
        useBytes = TRUE)
    execution <- .bf_gs_run(command, c("-q", "-dNOPAUSE", "-dBATCH", 
        "-dNOSAFER", "-dNOPLATFONTS", "-sDEVICE=pdfwrite", "-dAutoRotatePages=/None", 
        "-dEmbedAllFonts=true", "-dSubsetFonts=true", paste0("-sFONTMAP=", 
            normalizePath(fontmap, winslash = "/", mustWork = TRUE)), 
        paste0("-sFONTPATH=", paste(unique(vapply(faces, function(x) dirname(x$path), 
            character(1))), collapse = .Platform$path.sep)), 
        paste0("-dDEVICEWIDTHPOINTS=", format(width_mm * 72/25.399999999999999, 
            digits = 16, scientific = FALSE, trim = TRUE)), paste0("-dDEVICEHEIGHTPOINTS=", 
            format(height_mm * 72/25.399999999999999, digits = 16, 
                scientific = FALSE, trim = TRUE)), "-dFIXEDMEDIA", 
        paste0("-sOutputFile=", embedded), "-c", "<< /NeverEmbed [] >> setdistillerparams", 
        "-f", path))
    if (!file.exists(embedded) || file.info(embedded)$size <= 
        0) 
        stop("PDF font embedding produced no artifact")
    actual <- .bf_pdf_info(normalizePath(embedded, winslash = "/", 
        mustWork = TRUE), command)
    if (actual$page_count != 1) 
        stop("standalone figure PDF must contain exactly one page")
    error_pt <- c(width = (actual$width_mm - width_mm) * 72/25.399999999999999, 
        height = (actual$height_mm - height_mm) * 72/25.399999999999999)
    if (any(abs(error_pt) > 0.0051000000000000004)) 
        stop("actual PDF MediaBox differs beyond half of the0.01pt serialization unit")
    allowed <- vapply(faces, `[[`, "", "postscript_name")
    if (!length(actual$fonts) || any(!vapply(actual$fonts, function(x) isTRUE(x$embedded), 
        logical(1))) || any(!vapply(actual$fonts, function(x) sub("^[A-Z]{6}[+]", 
        "", x$name) %in% allowed, logical(1)))) 
        stop("NEEDS_PDF_FONT: every actual PDF font must be an embedded exact Arial/Helvetica face")
    if (digest::digest(file = path, algo = "sha256") != input_hash) 
        stop("PDF changed during finalization; original file retained")
    if (!file.copy(embedded, path, overwrite = TRUE)) 
        stop("cannot save verified embedded-font PDF")
    invisible(c(actual, list(path = path, sha256 = digest::digest(file = path, 
        algo = "sha256"), ghostscript = command, font_faces = faces, 
        mediabox_error_pt = as.list(error_pt), max_mediabox_error_pt = 0.0051000000000000004, 
        execution_log = execution, scope = "Actual PDF technical audit; separate final visual inspection required.")))
}

suppressPackageStartupMessages(library(ggplot2))
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) stop("Provide input and output prefix.")
input <- normalizePath(args[1L])
output <- file.path(normalizePath(dirname(args[2L]), mustWork = TRUE), basename(args[2L]))
font <- "Arial"
if (!grepl("Arial", basename(systemfonts::match_fonts(font)$path), fixed = TRUE)) {
  stop("Arial is required.")
}

regions <- c(promoter = "Promoter", "5' UTR" = "5′ UTR", "exon 6" = "Exon 6 (5′)",
  "exon 10 (5')" = "Exon 10 (5′)", "exon 10 (mid 1)" = "Exon 10 (mid 1)",
  "exon 10 (mid 2)" = "Exon 10 (mid 2)", "exon 10 (3')" = "Exon 10 (3′)",
  "exon 11" = "Exon 11", "intron 11" = "Intron 11",
  "exon 12 (5')" = "Exon 12 (5′)", "exon 12 (3')" = "Exon 12 (3′)")
# Eight semantic colors from BioFigure's installed Tol Muted palette.
colors <- c(Synonymous = "#88CCEE", Nonsense = "#CC6677", Missense = "#332288",
  "Canonical splice" = "#DDCC77", "Splice region" = "#44AA99", Intronic = "#AA4499",
  Promoter = "#999933", "5' UTR" = "#882255")

if (length(args) != 2L) stop("Use: Rscript draw_figure.R points.csv output_prefix")
points <- read.csv(input, stringsAsFactors = FALSE)
stopifnot(nrow(points) > 0L, !anyDuplicated(points$source_row),
  all(is.finite(points$functional_score)), all(is.finite(points$position_hg38)),
  all(is.finite(points$upper_threshold)), all(points$region %in% names(regions)),
  all(points$consequence %in% names(colors)))
points$region <- factor(points$region, levels = names(regions))
points$consequence <- factor(points$consequence, levels = names(colors))
thresholds <- unique(points[c("region", "upper_threshold", "lower_threshold")])
stopifnot(!anyDuplicated(thresholds$region))
lower_thresholds <- thresholds[is.finite(thresholds$lower_threshold), ]

width <- 183
height <- 119
axis_color <- "#303238"
p <- ggplot(points, aes(position_hg38, functional_score, colour = consequence)) +
  geom_hline(data = thresholds, aes(yintercept = upper_threshold),
    color = "#43454B", linewidth = .24, linetype = "22") +
  geom_hline(data = lower_thresholds, aes(yintercept = lower_threshold),
    color = "#8C8F95", linewidth = .22, linetype = "22") +
  geom_point(size = 0.83, alpha = .87) +
  scale_color_manual(values = colors, breaks = names(colors),
    labels = c(names(colors)[1:7], "5′ UTR"), drop = FALSE) +
  scale_x_reverse(expand = expansion(mult = .035),
    breaks = function(limits) {
      interior <- diff(limits) * .18
      round(seq(limits[1L] + interior, limits[2L] - interior, length.out = 2L), -1)
    }, labels = scales::label_comma(accuracy = 1)) +
  scale_y_continuous(breaks = seq(-4, 1), labels = scales::label_number(style_negative = "minus"),
    limits = c(-4.45, 1.22), expand = expansion(mult = 0)) +
  facet_wrap(~region, ncol = 4L, scales = "free_x",
    labeller = labeller(region = as_labeller(regions))) +
  labs(x = "Chr17 position (hg38)", y = "Function score", colour = NULL) +
  guides(colour = guide_legend(ncol = 2L, override.aes = list(size = 1.6, alpha = 1))) +
  theme_minimal(base_family = font, base_size = 8) +
  theme(
    text = element_text(colour = axis_color),
    panel.grid = element_blank(),
    panel.spacing.x = grid::unit(3.0, "mm"),
    panel.spacing.y = grid::unit(4.0, "mm"),
    axis.text = element_text(size = 7.5, colour = axis_color),
    axis.title = element_text(size = 9, colour = axis_color),
    axis.title.x = element_text(margin = margin(t = 6)),
    axis.title.y = element_text(margin = margin(r = 6)),
    axis.ticks = element_line(colour = "#55585E", linewidth = .19),
    axis.ticks.length = grid::unit(.85, "mm"),
    strip.text = element_text(size = 8.5, margin = margin(b = 4)),
    plot.margin = margin(5, 6, 5, 5),
    legend.position = "inside",
    legend.position.inside = c(.876, .135),
    legend.justification.inside = c(.5, .5),
    legend.key.width = grid::unit(3.0, "mm"),
    legend.key.height = grid::unit(4.2, "mm"),
    legend.text = element_text(size = 7.1),
    legend.margin = margin(0, 0, 0, 0),
    legend.spacing.x = grid::unit(.4, "mm"),
    legend.background = element_blank(),
    legend.key = element_blank()
  )

cowplot::set_null_device("agg")
p <- cowplot::ggdraw(p) + cowplot::draw_plot_label("c", x = .0105, y = .982,
  hjust = 0, vjust = 1, size = 10, family = font, fontface = "bold", colour = axis_color)

ggsave(paste0(output, ".png"), p, device = ragg::agg_png, width = width, height = height,
  units = "mm", dpi = 360, bg = "white")
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
resolved <- systemfonts::match_fonts(font)
invisible(bf_pdf_finalize(pdf, list(family = font, path = resolved$path, index = resolved$index), width, height))
