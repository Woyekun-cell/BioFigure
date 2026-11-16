build_plot <- function(input, palette) {
  library(ggplot2)
  groups <- c("Exc. neurons","Oligodend.","Inh. neurons","Astrocytes","Microglia","OPCs","Vascular niche")
  display <- c("Exc.\nneurons","Oligodend.","Inh.\nneurons","Astrocytes","Microglia","OPCs","Vascular\nniche")
  patterns <- c("^Exc\\.","^Oli\\.","^Inh\\.","^Ast\\.","^Mic\\.|^(Macrophages|Monocytes)$",
                "^OPC\\.|^(MFOL|COP)$","^(End\\.|Peri\\.|SMC\\.|Fib\\.|Arteriole$|Venule$)")
  stopifnot("individualID"%in%names(input),nrow(input)>=2L,!anyDuplicated(names(input)),
            all(groups%in%names(palette)))
  ids <- as.character(input$individualID)
  abundances <- input[setdiff(names(input),"individualID")]
  stopifnot(!anyNA(ids),all(nzchar(ids)),!anyDuplicated(ids),all(vapply(abundances,is.numeric,logical(1))))
  m <- as.matrix(abundances)
  rownames(m) <- ids
  stopifnot(all(is.finite(m)&m>=0&m<=1))
  membership <- vapply(patterns,function(p)grepl(p,colnames(m)),logical(ncol(m)))
  stopifnot(all(rowSums(membership)==1L),all(colSums(membership)>0L))
  h <- hclust(dist(m)^2,method="complete")
  n <- nrow(m)
  row_y <- match(seq_len(n),h$order)
  compiled_height <- numeric(n-1L)
  branch_y <- numeric(n-1L)
  branches <- vector("list",n-1L)
  for (i in seq_len(n-1L)) {
    children <- h$merge[i,]
    ypos <- vapply(children,function(j) if(j<0) row_y[-j] else branch_y[j],numeric(1))
    height <- vapply(children,function(j) if(j<0) 0 else compiled_height[j],numeric(1))
    branches[[i]] <- data.frame(from=c(height,h$height[i]),to=rep(h$height[i],3L),
                                y=c(ypos,ypos[1]),yend=c(ypos,ypos[2]))
    branch_y[i] <- mean(ypos)
    compiled_height[i] <- h$height[i]
  }
  tree <- do.call(rbind,branches)
  tree_scale <- if(max(h$height)>0) 1.55/max(h$height) else 0
  tree$x <- -.10-tree$from*tree_scale
  tree$xend <- -.10-tree$to*tree_scale
  blank <- setNames(integer(length(groups)),groups)
  residual <- setNames(numeric(length(groups)),groups)
  colors <- character()
  rectangles <- lapply(seq_along(groups),function(g) {
    ids_in_group <- which(membership[,g])
    st <- colnames(m)[ids_in_group]
    index <- suppressWarnings(as.integer(sub(".*\\.","",st)))
    cols <- ids_in_group[order(index,seq_along(index),na.last=TRUE)]
    z <- m[,cols,drop=FALSE]
    totals <- rowSums(z)
    positive <- totals>0
    stopifnot(any(positive),all(abs(totals[positive]-1)<1e-6))
    blank[g] <<- sum(!positive)
    residual[g] <<- max(abs(totals[positive]-1))
    # Snap only the last nonzero segment edge to 1 for source floating-point noise.
    start <- matrix(0,nrow=n,ncol=ncol(z))
    end <- start
    for (j in seq_len(ncol(z))) {
      if(j>1) start[,j] <- end[,j-1L]
      end[,j] <- start[,j]+z[,j]
    }
    for (j in which(positive)) {
      last <- max(which(z[j,]>0))
      end[j,last] <- 1
    }
    keys <- colnames(z)
    hues <- grDevices::colorRampPalette(c("#FFFFFF",palette[[groups[g]]]))(length(keys)+2L)[-c(1L,2L)]
    colors <<- c(colors,setNames(hues,keys))
    frame <- data.frame(lo=c(start)+(g-1),hi=c(end)+(g-1),row=rep(row_y,times=ncol(z)),
                       state=rep(keys,each=n),fraction=c(z))
    frame[frame$fraction>0,]
  })
  bars <- do.call(rbind,rectangles)
  p <- ggplot() +
    geom_segment(data=tree,aes(x,y,xend=xend,yend=yend),linewidth=.13,colour="#54596D",lineend="round")+
    geom_rect(data=bars,aes(xmin=lo,xmax=hi,ymin=row-.5,ymax=row+.5,fill=state),colour=NA)+
    geom_vline(xintercept=seq(0,7),linewidth=.18,colour="#F6F4F7")+
    annotate("rect",xmin=0,xmax=7,ymin=.5,ymax=n+.5,fill=NA,colour="#777A87",linewidth=.26)+
    scale_fill_manual(values=colors,guide="none")+
    scale_x_continuous(breaks=seq(.5,6.5),labels=display,limits=c(-1.71,7.04),expand=c(0,0))+
    scale_y_continuous(limits=c(.5,n+.5),expand=c(0,0))+
    labs(x=NULL,y="Participants")+
    theme_classic(base_family="Arial",base_size=8)+
    theme(axis.line=element_blank(),axis.ticks=element_blank(),
          axis.text.x=element_text(colour="#30343B",size=7,lineheight=.92,margin=margin(t=4)),
          axis.text.y=element_blank(),axis.title.y=element_text(size=8,margin=margin(r=7)),
          plot.margin=margin(5,5,5,5))
  tips <- data.frame(id=ids,row=row_y)
  tip_mark_y <- unlist(lapply(seq_len(n-1L),function(i) branches[[i]]$y[which(h$merge[i,]<0)]),use.names=FALSE)
  stopifnot(identical(sort(as.integer(tip_mark_y)),seq_len(n)),
            identical(tips$id[order(tips$row)],ids[h$order]),
            all(bars$lo<=bars$hi),all(bars$lo>=0 & bars$hi<=7+1e-12))
  list(plot=p,participants=n,subpopulations=ncol(m),class_state_counts=as.list(setNames(colSums(membership),groups)),
       blank_class_slots=as.list(blank),max_nonzero_closure_error=as.list(residual),tip_coordinates=tips,
       cluster_order=ids[h$order],cluster_height=unname(h$height),tree_segments=nrow(tree),stack_segments=nrow(bars))
}
