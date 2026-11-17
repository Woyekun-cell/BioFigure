# Signed, undirected co-occurrence networks with explicit abundance filters.
build_cooccurrence <- function(counts, min_abundance=.00005, prevalence=.05,
                               min_abs_rho=.6, p_cutoff=.05, p_adjust="none") {
  stopifnot(is.matrix(counts), is.numeric(counts), ncol(counts)>=6L, nrow(counts)>=2L,
    all(is.finite(counts) & counts>=0 & counts==trunc(counts)),
    !is.null(rownames(counts)), all(nzchar(rownames(counts))), !anyDuplicated(rownames(counts)),
    all(colSums(counts)>0), p_adjust %in% c("none","BH"),
    all(is.finite(c(min_abundance,prevalence,min_abs_rho,p_cutoff))),
    all(c(min_abundance,prevalence,min_abs_rho,p_cutoff)>=0),
    all(c(min_abundance,prevalence,min_abs_rho,p_cutoff)<=1))
  counts <- counts[order(rownames(counts), method="radix"), , drop=FALSE]
  fractions <- sweep(counts,2,colSums(counts),"/")
  keep <- rowMeans(fractions)>min_abundance &
    rowSums(counts>0)>=ceiling(prevalence*ncol(counts)) &
    apply(fractions,1,stats::sd)>0
  fractions <- fractions[keep,,drop=FALSE]
  if (nrow(fractions)<2L) stop("Fewer than two variable OTUs survive filtering")
  # Spearman ranks are invariant to the tutorial's monotone square-root step.
  res <- Hmisc::rcorr(t(fractions),type="spearman")
  pairs <- which(upper.tri(res$r),arr.ind=TRUE)
  p <- stats::p.adjust(res$P[pairs],method=p_adjust)
  rho <- res$r[pairs]
  pass <- is.finite(rho) & is.finite(p) & abs(rho)>=min_abs_rho & p<=p_cutoff & rho!=0
  if (!any(pass)) stop("No edges survive the correlation and p-value thresholds")
  edges <- data.frame(from=rownames(fractions)[pairs[pass,1]],to=rownames(fractions)[pairs[pass,2]],
                      rho=rho[pass],p=p[pass],sign=ifelse(rho[pass]>0,"Positive","Negative"))
  graph <- igraph::graph_from_data_frame(edges,directed=FALSE)
  module <- igraph::membership(igraph::cluster_fast_greedy(graph,weights=abs(igraph::E(graph)$rho)))
  nodes <- data.frame(otu=igraph::V(graph)$name,degree=as.integer(igraph::degree(graph)),module=unname(module))
  list(graph=graph,nodes=nodes,edges=edges)
}


network_layout <- function(graph, weights, iterations=550L) {
  xy <- igraph::layout_with_fr(graph,niter=iterations,weights=weights,grid="nogrid")
  xy <- scale(xy,center=TRUE,scale=FALSE)
  radius <- sqrt(rowSums(xy^2))
  # A monotone radial remapping keeps outliers from shrinking the entire graph.
  xy <- xy/(radius+max(1e-10,.85*stats::median(radius)))
  xy/max(sqrt(rowSums(xy^2)))
}
