library(circlize)

prepare_loci <- function(records, trait_map, cytobands) {
  required <- c("chromosome", "start", "end", "region", paste0("trait_", letters[1:3]))
  stopifnot(nrow(records) > 0L, all(required %in% names(records)),
            !anyNA(records[required]), all(nzchar(records$region)),
            all(c("system", "system_label", "trait", "category", "color", "category_order") %in% names(trait_map)),
            !anyNA(trait_map), setequal(trait_map$system, letters[1:3]),
            !anyDuplicated(trait_map[c("system", "trait")]))
  lengths <- tapply(cytobands[[3]], cytobands[[1]], max)
  stopifnot(all(records$chromosome %in% names(lengths)),
            is.numeric(records$start), is.numeric(records$end),
            all(is.finite(records$start)), all(is.finite(records$end)),
            all(records$start >= 0 & records$start <= records$end),
            all(records$end <= lengths[records$chromosome]))
  for (system in letters[1:3]) {
    mapping <- trait_map[trait_map$system == system, ]
    stopifnot(length(unique(mapping$system_label)) == 1L,
              all(records[[paste0("trait_", system)]] %in% mapping$trait),
              all(grepl("^#[0-9A-Fa-f]{6}$", mapping$color)))
    for (category in unique(mapping$category)) {
      stopifnot(length(unique(mapping$color[mapping$category == category])) == 1L)
    }
    index <- match(records[[paste0("trait_", system)]], mapping$trait)
    records[[paste0("category_", system)]] <- mapping$category[index]
    records[[paste0("color_", system)]] <- mapping$color[index]
    records[[paste0("order_", system)]] <- mapping$category_order[index]
  }
  chromosomes <- names(lengths)[order(as.integer(sub("chr", "", names(lengths))))]
  records <- records[order(match(records$chromosome, chromosomes), records$region,
                           records$start, records$end), ]
  locus_id <- integer(nrow(records))
  current <- 0L
  current_end <- -1
  previous_chr <- previous_region <- ""
  for (i in seq_len(nrow(records))) {
    same_region <- records$chromosome[i] == previous_chr && records$region[i] == previous_region
    if (!same_region || records$start[i] > current_end) {
      current <- current + 1L
      current_end <- records$end[i]
    }
    current_end <- max(current_end, records$end[i])
    locus_id[i] <- current
    previous_chr <- records$chromosome[i]
    previous_region <- records$region[i]
  }
  records$locus_id <- locus_id
  loci <- do.call(rbind, lapply(split(records, locus_id), function(x) {
    data.frame(locus_id = x$locus_id[1], chromosome = x$chromosome[1], region = x$region[1],
                start = min(x$start), end = max(x$end),
                n_cliques = nrow(unique(x[paste0("trait_", letters[1:3])])),
                n_combinations = nrow(unique(x[paste0("category_", letters[1:3])])),
                stringsAsFactors = FALSE)
  }))
  loci <- loci[order(loci$locus_id), ]
  loci$label <- paste0(loci$region, " (", loci$n_cliques, ")")
  combinations <- unique(records[c("locus_id", paste0("category_", letters[1:3]),
                                    paste0("color_", letters[1:3]), paste0("order_", letters[1:3]))])
  combinations <- combinations[order(combinations$locus_id, combinations$order_a,
                                     combinations$order_b, combinations$order_c), ]
  list(records = records, loci = loci, combinations = combinations,
        chromosomes = chromosomes, lengths = lengths, trait_map = trait_map)
}

pack_annotation_slots <- function(anchors, counts, pitch = 2.1, gap = 0.9) {
  stopifnot(length(anchors) == length(counts), length(anchors) > 0L,
            all(is.finite(anchors)), all(diff(anchors) >= 0), all(counts >= 1L))
  widths <- pmax(2.3, counts * pitch)
  offsets <- c(0, cumsum((head(widths, -1) + tail(widths, -1)) / 2 + gap))
  lower <- widths[1] / 2
  upper <- 360 - tail(widths, 1) / 2 - tail(offsets, 1)
  if (upper < lower) stop("Annotation capacity exceeded. Increase marker space or split the display.")
  fit <- stats::isoreg(anchors - offsets)$yf
  pmax(lower, pmin(upper, fit)) + offsets
}

draw_organ_loci <- function(prepared, cytobands, chromosome_colors) {
  par(mar = c(0.3, 0.3, 0.3, 0.3), family = "Arial", ps = 10, cex = 1)
  circos.clear()
  on.exit(circos.clear(), add = TRUE)
  circos.par(start.degree = 90, gap.after = rep(1.5, length(prepared$chromosomes)),
             track.margin = c(0, 0), cell.padding = c(0, 0, 0, 0),
             canvas.xlim = c(-1.07, 1.07), canvas.ylim = c(-1.07, 1.07))
  circos.initializeWithIdeogram(cytoband = cytobands, chromosome.index = prepared$chromosomes,
                               plotType = "ideogram", ideogram.height = mm_h(3.5))
  polar <- function(radius, angle) {
    theta <- (90 - angle) * pi / 180
    cbind(x = radius * cos(theta), y = radius * sin(theta))
  }
  for (chromosome in prepared$chromosomes) {
    start <- get.cell.meta.data("cell.start.degree", sector.index = chromosome, track.index = 1)
    end <- get.cell.meta.data("cell.end.degree", sector.index = chromosome, track.index = 1)
    angles <- seq(90 - start, 90 - end, length.out = 50)
    lines(polar(1.018, angles), col = chromosome_colors[chromosome], lwd = 1.6)
    text(polar(1.072, mean(angles)), sub("chr", "", chromosome), cex = 0.75)
  }
  loci <- prepared$loci
  loci$anchor <- vapply(seq_len(nrow(loci)), function(i) {
    theta <- circlize((loci$start[i] + loci$end[i]) / 2, 0.5,
                      sector.index = loci$chromosome[i], track.index = 1)[1, 1]
    (90 - theta) %% 360
  }, numeric(1))
  loci <- loci[order(loci$anchor), ]
  loci$display <- pack_annotation_slots(loci$anchor, loci$n_combinations)
  point_trace <- list()
  for (i in seq_len(nrow(loci))) {
    locus <- loci[i, ]
    combinations <- prepared$combinations[prepared$combinations$locus_id == locus$locus_id, ]
    slots <- locus$display + (seq_len(nrow(combinations)) - (nrow(combinations) + 1) / 2) * 2.1
    label_half_width <- strwidth(locus$label, cex = 0.65) / 2
    outer <- 0.83 + label_half_width + 0.008
    inner <- 0.83 - label_half_width - 0.008
    stopifnot(inner > 0.715, outer < 0.945)
    leader <- rbind(polar(0.945, locus$anchor),
                     polar(0.938, seq(locus$anchor, locus$display, length.out = 30)),
                     polar(outer, locus$display))
    lines(leader, lwd = 0.6, col = "#30343B")
    rotation <- (90 - locus$display) %% 360
    if (rotation > 90 && rotation < 270) rotation <- rotation + 180
    text(polar(0.83, locus$display), locus$label, cex = 0.65, srt = rotation)
    for (j in seq_along(slots)) {
      branch <- rbind(polar(inner, locus$display), polar(0.724, slots[j]), polar(0.711, slots[j]))
      lines(branch, lwd = 0.55, col = "#30343B")
      for (system in seq_len(3)) {
        radius <- c(0.69, 0.65, 0.61)[system]
        color <- combinations[[paste0("color_", letters[system])]][j]
        xy <- polar(radius, slots[j])
        points(xy, pch = c(16, 15, 17)[system], col = color, cex = 0.68)
        point_trace[[length(point_trace) + 1L]] <- data.frame(locus_id = locus$locus_id,
          combination = j, system = letters[system], category = combinations[[paste0("category_", letters[system])]][j],
          angle = slots[j], x = xy[1, 1], y = xy[1, 2], radius = radius)
      }
    }
  }
  key_trace <- list()
  for (system in seq_len(3)) {
    mapping <- unique(prepared$trait_map[prepared$trait_map$system == letters[system],
                                        c("system_label", "category", "color", "category_order")])
    mapping <- mapping[order(mapping$category_order), ]
    x <- c(-0.49, -0.18, 0.14)[system]
    points(x - 0.021, 0.23, pch = c(16, 15, 17)[system], cex = 0.68)
    text(x, 0.23, unique(mapping$system_label), adj = c(0, 0.5), cex = 0.7)
    y <- 0.17
    for (j in seq_len(nrow(mapping))) {
      label <- strwrap(mapping$category[j], width = c(17, 18, 23)[system])
      points(x - 0.021, y, pch = c(16, 15, 17)[system], col = mapping$color[j], cex = 0.7)
      for (line in label) {
        text(x, y, line, adj = c(0, 0.5), cex = 0.65)
        key_trace[[length(key_trace) + 1L]] <- data.frame(system = letters[system],
          text = line, x = x, y = y, width = strwidth(line, cex = 0.65))
        y <- y - 0.033
      }
      y <- y - 0.006
    }
  }
  list(loci = loci, points = do.call(rbind, point_trace), legend = do.call(rbind, key_trace))
}
