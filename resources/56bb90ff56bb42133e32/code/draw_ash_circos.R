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
# Wood et al., Nature Communications 17, 9693 (2026), Fig. 2d.
# Paper: https://doi.org/10.1038/s41467-026-77194-9
# Source data: https://zenodo.org/records/21991529
# Author code: https://github.com/danielwood1992/Ash_pangenome/blob/60374b16e4512fb68a29f0ef14fda5dafc30b71d/5_CharacteriseSVs/NC_5_5.1_CircosPlot.R
# Published numeric input and the source article: CC BY 4.0.
# Data licence: https://creativecommons.org/licenses/by/4.0/
# Adaptation: CSV-only rendering, revised palette and typography; see the gallery description.
# Run: Rscript draw_ash_circos.R plot_data output_directory

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

argv <- commandArgs(trailingOnly = TRUE)
self <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)))
root <- dirname(self)
track_names <- c("inversions", "deletions", "insertions", "genes")

stopifnot(length(argv) <= 2)
data_dir <- if (length(argv) >= 1) argv[1] else file.path(root, "plot_data")
out <- if (length(argv) == 2) argv[2] else root
dir.create(out, recursive = TRUE, showWarnings = FALSE)
inputs <- file.path(data_dir, c("ash-fig2d-windows.csv", "ash-fig2d-scaffolds.csv"))
w <- read.csv(inputs[1], stringsAsFactors = FALSE)
chrom <- read.csv(inputs[2], stringsAsFactors = FALSE)
idx <- match(w$scaffold, chrom$scaffold)
stopifnot(!anyNA(idx), !anyDuplicated(chrom$scaffold), all(diff(chrom$length_bp) < 0),
          all(w$start_bp >= 0 & w$end_bp <= chrom$length_bp[idx]), all(w$start_bp < w$end_bp))
track_max <- vapply(w[track_names], max, numeric(1))
stopifnot(all(is.finite(track_max) & track_max > 0), all(as.matrix(w[track_names]) >= 0))

library(ggplot2)
font_family <- "Arial"
width <- 182
height <- 166
dpi <- 420
palette <- c(inversions = "#332288", deletions = "#CC6677", insertions = "#DDCC77", genes = "#44AA99")
# Author uses a gap of 0.3% of summed scaffold size, after every sector.
gap <- sum(chrom$length_bp) * .003
chrom$offset <- c(0, head(cumsum(chrom$length_bp + gap), -1))
circumference <- sum(chrom$length_bp) + nrow(chrom)*gap
radians <- function(bp) 2*pi*bp/circumference
chrom$theta1 <- radians(chrom$offset)
chrom$theta2 <- radians(chrom$offset + chrom$length_bp)
w$theta1 <- radians(chrom$offset[idx] + w$start_bp)
w$theta2 <- radians(chrom$offset[idx] + w$end_bp)

# Original ggplot2 radii -30 ... 82 become physical radii 0 ... 112.
rings <- data.frame(feature = track_names, base = c(30, 48, 66, 84), height = c(15, 15, 15, 20))
xy <- function(a, r) data.frame(x = r*sin(a), y = r*cos(a))
arc_band <- function(a1, a2, r1, r2, n, id) {
  a <- seq(a1, a2, length.out = n)
  data.frame(rbind(xy(a, r1), xy(rev(a), r2)), id)
}
sectors <- do.call(rbind, lapply(seq_len(nrow(rings)), function(j) {
  do.call(rbind, lapply(seq_len(nrow(chrom)), function(i)
    arc_band(chrom$theta1[i], chrom$theta2[i], rings$base[j],
             rings$base[j] + rings$height[j], 60, paste(j, i, sep = "-"))))
}))
bars <- do.call(rbind, lapply(seq_len(nrow(rings)), function(j) {
  key <- rings$feature[j]
  values <- w[[key]]
  base <- rings$base[j]
  heights <- base + rings$height[j] * values / track_max[key]
  do.call(rbind, lapply(seq_len(nrow(chrom)), function(k) {
    rows <- which(idx == k & values > 0)
    if (!length(rows)) return(NULL)
    # Join adjacent positive bins into one stepped fill to avoid PDF seams at
    # shared edges. Each step keeps the exact angular interval and height.
    run_ids <- cumsum(c(TRUE, diff(rows) != 1L))
    do.call(rbind, lapply(split(rows, run_ids), function(i) {
      top <- do.call(rbind, lapply(i, function(b)
        xy(seq(w$theta1[b], w$theta2[b], length.out = 3), heights[b])))
      bottom <- xy(seq(w$theta2[tail(i, 1)], w$theta1[i[1]], length.out = 2*length(i)+1), base)
      data.frame(rbind(top, bottom), id = paste(j, k, i[1], sep = "-"), color = unname(palette[key]))
    }))
  }))
}))
middle <- (chrom$theta1 + chrom$theta2)/2
labels <- data.frame(xy(middle, 111), label = as.character(chrom$rank),
                     angle = (90-middle*180/pi+90) %% 180 - 90)

p <- ggplot() +
  geom_polygon(data = bars, aes(x, y, group = id, fill = color), colour = NA) +
  geom_polygon(data = sectors, aes(x, y, group = id), fill = NA,
               colour = "#3B424A", linewidth = .18) +
  geom_text(data = labels, aes(x, y, angle = angle, label = label),
            colour = "#26313A", family = font_family, size = 7, size.unit = "pt") +
  annotate("text", x = -132, y = 118, label = "d", colour = "#26313A", family = font_family,
           fontface = "bold", size = 10, size.unit = "pt") +
  scale_fill_identity() +
  coord_fixed(xlim = c(-138, 138), ylim = c(-125.87, 125.87), expand = FALSE, clip = "on") +
  cowplot::theme_nothing() +
  theme(plot.margin = margin(0, 0, 0, 0), plot.background = element_rect(fill = "white", colour = NA))

png <- file.path(out, "ash-fig2d-circos.png")
pdf <- file.path(out, "ash-fig2d-circos.pdf")
resolved <- systemfonts::match_fonts(font_family)
stopifnot(identical(systemfonts::font_info(path = resolved$path, index = resolved$index)$family, font_family))
ggsave(png, p, device = ragg::agg_png, width = width, height = height, units = "mm", dpi = dpi, bg = "white")
font <- list(family = font_family, path = resolved$path, index = resolved$index)
bf_pdf_open(pdf, width, height, font)
print(p)
invisible(dev.off())
invisible(bf_pdf_finalize(pdf, font, width, height))
