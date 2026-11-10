# Fixed-seed structural fixture for the A/D/C/A tutorial layout.
# Each synthetic triad follows A(top) -> D -> C -> A(bottom).
args <- commandArgs(TRUE)
stopifnot(length(args) == 1L, dir.exists(args[1]))
out <- args[1]
set.seed(102L, kind = "Mersenne-Twister", sample.kind = "Rejection")
n <- 30L
bins <- c("A_top", "D", "C", "A_bottom")
chromosomes <- seq_len(7L)
seqs <- data.frame(bin_id = rep(bins, each = 7L),
                   chromosome = rep(chromosomes, times = 4L),
                   length = 1000L)
seqs$seq_id <- paste(seqs$bin_id, seqs$chromosome, sep = "_")
a <- rep(chromosomes, each = n)
block <- rep(seq_len(n), times = 7L)
d <- a
c <- a
# Deliberate exchanges retain equal block counts and leave the diagonal dominant.
for (pair in list(c(1L, 5L), c(1L, 7L), c(2L, 7L), c(3L, 4L), c(1L, 6L))) {
  swap <- sample(2:(n - 1L), if (pair[1] == 1L) 1L else 2L)
  sel <- a %in% pair & block %in% swap
  d[sel] <- sum(pair) - a[sel]
}
c <- d
for (pair in list(c(2L, 4L), c(4L, 7L), c(5L, 7L), c(3L, 6L))) {
  first <- sample(which(d == pair[1] & c == d), if (identical(pair, c(4L,7L))) 5L else 2L)
  second <- sample(which(d == pair[2] & c == d), length(first))
  c[first] <- pair[2]
  c[second] <- pair[1]
}
# Keep the dominant order while allowing a local reversal of block order.
at <- block
dt <- block
ct <- block
sel <- which(a == 2L & d == 2L & block >= 8L & block <= 21L)
dt[sel] <- rev(dt[sel])
sel <- which(d == 3L & c == 3L & block >= 12L & block <= 23L)
ct[sel] <- rev(ct[sel])
positions <- function(bin, chr, priority) {
  t <- data.frame(seq_id = paste(bin, chr, sep = "_"), start = 0, end = 0)
  for (g in chromosomes) {
    ids <- which(chr == g)
    ids <- ids[order(priority[ids], a[ids])]
    stopifnot(length(ids) == n)
    weights <- runif(n, .8, 1.2)
    breaks <- 3 + c(0, cumsum(weights/sum(weights) * 994))
    gaps <- runif(n, .22, 1.25)
    t$start[ids] <- round(head(breaks, -1L) + gaps, 5L)
    t$end[ids] <- round(tail(breaks, -1L) - gaps, 5L)
  }
  t
}
top <- positions("A_top", a, at)
bottom <- top
bottom$seq_id <- paste("A_bottom", a, sep = "_")
nodes <- list(top, positions("D", d, dt), positions("C", c, ct), bottom)
links <- do.call(rbind, lapply(seq_len(3), function(i) {
  x <- nodes[[i]]
  y <- nodes[[i + 1L]]
  names(y) <- paste0(names(y), "2")
  data.frame(triad_id = sprintf("sim_%03d", seq_along(a)), x, y,
             gap = paste(bins[i], bins[i + 1L], sep = "/"))
}))
stopifnot(nrow(seqs) == 28L, nrow(links) == 630L, length(unique(links$triad_id)) == 210L,
          all(table(links$triad_id) == 3L), all(links$start >= 0 & links$end <= 1000),
          all(links$start2 >= 0 & links$end2 <= 1000),
          all(links$end > links$start & links$end2 > links$start2))
readr::write_csv(seqs, file.path(out, "synteny_sim_sequences.csv"))
readr::write_csv(links, file.path(out, "synteny_sim_links.csv"))
