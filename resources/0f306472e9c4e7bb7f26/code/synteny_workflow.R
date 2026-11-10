# Reusable issue-102 layout for normalized, closed A–D–C–A triads.
# All intervals are in display units; the workflow performs no homology calling.
build_synteny <- function(seqs, links) {
  bins <- c("A_top", "D", "C", "A_bottom")
  gaps <- paste(head(bins,-1L),tail(bins,-1L),sep="/")
  seq_fields <- c("bin_id","chromosome","length","seq_id")
  link_fields <- c("triad_id","seq_id","start","end","seq_id2","start2","end2","gap")
  if (!all(seq_fields %in% names(seqs)) || !all(link_fields %in% names(links)))
    stop("Required sequence or link columns are missing.")
  if (anyNA(seqs[seq_fields]) || anyNA(links[link_fields]) || !nrow(links))
    stop("Required values must be present and the link table nonempty.")
  if (!is.numeric(seqs$chromosome) || !is.numeric(seqs$length) ||
      any(!is.finite(seqs$chromosome)) || any(seqs$chromosome != trunc(seqs$chromosome)))
    stop("Chromosome numbers and display lengths must be numeric.")
  n <- sum(seqs$bin_id == "A_top")
  if (n < 2L || n > 10L || nrow(seqs) != 4L * n ||
      any(seqs$length != 1000) || anyDuplicated(seqs$seq_id) ||
      !setequal(seqs$seq_id, as.vector(outer(bins, seq_len(n), paste, sep="_"))) ||
      !all(seqs$seq_id == paste(seqs$bin_id,seqs$chromosome,sep="_")))
    stop("Expected four matched A_top/D/C/A_bottom rows of 2–10 normalized chromosomes.")
  if (any(!nzchar(links$triad_id)) || anyDuplicated(links[c("gap","triad_id")]))
    stop("Each nonempty triad ID must occur at most once per gap.")
  for (k in c("start","end","start2","end2")) {
    v <- links[[k]]
    if (!is.numeric(v) || any(!is.finite(v) | v < 0 | v > 1000))
      stop("Link coordinates must be finite within 0–1000.")
  }
  if (any(links$start >= links$end | links$start2 >= links$end2))
    stop("Both link intervals must have positive width.")
  from <- match(links$seq_id, seqs$seq_id)
  to <- match(links$seq_id2, seqs$seq_id)
  if (anyNA(from) || anyNA(to) ||
      !all(paste(seqs$bin_id[from],seqs$bin_id[to],sep="/") == links$gap) ||
      !all(links$gap %in% gaps))
    stop("Links must connect known chromosomes in adjacent ordered rows.")
  keys <- sort(unique(links$triad_id))
  by_gap <- lapply(gaps, function(g) {
    l <- links[links$gap == g,]
    if (!setequal(l$triad_id, keys)) stop("Each triad must cover all three gaps.")
    l[match(keys,l$triad_id),]
  })
  expect_end <- function(x,y) all(x$seq_id2 == y$seq_id & x$start2 == y$start & x$end2 == y$end)
  top <- by_gap[[1]]
  mid <- by_gap[[2]]
  low <- by_gap[[3]]
  if (!expect_end(top,mid) || !expect_end(mid,low) ||
      !all(sub("^A_bottom_", "A_top_", low$seq_id2) == top$seq_id &
           low$start2 == top$start & low$end2 == top$end))
    stop("Triad endpoints must join exactly and the bottom A must return to the same top A interval.")
  links <- do.call(rbind, by_gap)
  seqs$bin_id <- factor(seqs$bin_id, levels=bins)
  seqs <- seqs[order(seqs$bin_id,seqs$chromosome),]
  seqs$color_id <- seqs$seq_id
  links$color_id <- links$seq_id
  palette <- c("#1F77B4","#FF7F0E","#2CA02C","#D62728","#9467BD",
               "#8C564B","#E377C2","#7F7F7F","#BCBD22","#17BECF")
  colors <- setNames(c(rep(palette,length.out=3*n),rep("#7F7F7F",n)),seqs$seq_id)
  p <- gggenomes::gggenomes(seqs=seqs,links=links,spacing=400) +
    gggenomes::geom_link_curved(ggplot2::aes(fill=color_id),offset=.01,curve=8,color=NA,alpha=1) +
    gggenomes::geom_seq(ggplot2::aes(color=color_id),linewidth=1.28,lineend="round") +
    gggenomes::geom_bin_label(ggplot2::aes(label=sub("_.*","",bin_id)),size=8.5/ggplot2::.pt,
                             family="Arial",nudge_left=.025,expand_left=.075) +
    ggplot2::scale_fill_manual(values=colors) + ggplot2::scale_color_manual(values=colors) +
    ggplot2::scale_x_continuous(guide="none",expand=ggplot2::expansion(mult=.02)) +
    ggplot2::scale_y_continuous(expand=ggplot2::expansion(add=c(.12,.18))) +
    ggplot2::theme_void(base_family="Arial",base_size=14) +
    ggplot2::theme(legend.position="none",plot.margin=ggplot2::margin(9,9,9,9))
  bars <- gggenomes::pull_seqs(p)
  placed <- gggenomes::pull_links(p)
  top_labels <- bars[bars$bin_id == "A_top",]
  p <- p + ggplot2::geom_text(data=top_labels,
    ggplot2::aes(x=(x+xend)/2,y=y+.22,label=chromosome),
    inherit.aes=FALSE,size=8.5/ggplot2::.pt,family="Arial")
  b <- bars[match(placed$seq_id,bars$seq_id),]
  b2 <- bars[match(placed$seq_id2,bars$seq_id),]
  between <- function(x, lower, upper) all(x >= lower - 1e-8 & x <= upper + 1e-8)
  stopifnot(nrow(bars)==nrow(seqs),nrow(placed)==nrow(links),
    identical(as.character(unique(bars$bin_id)),bins),
    all(abs(placed$y-placed$yend)==1),all(bars$xend-bars$x==1000),
    between(placed$x,b$x,b$xend),between(placed$xend,b$x,b$xend),
    between(placed$xmin,b2$x,b2$xend),between(placed$xmax,b2$x,b2$xend))
  cross <- tapply(seqs$chromosome[match(links$seq_id,seqs$seq_id)] !=
                  seqs$chromosome[match(links$seq_id2,seqs$seq_id)],links$gap,sum)
  list(plot=p,audit=list(status="PASS",track_rows=length(bins),display_chromosomes=nrow(bars),
    chromosomes_per_row=n,triads=length(keys),rendered_ribbons=nrow(placed),
    cross_chromosome_ribbons=as.list(cross),closed_triad_chain=TRUE,projected_endpoints_in_bounds=TRUE))
}
