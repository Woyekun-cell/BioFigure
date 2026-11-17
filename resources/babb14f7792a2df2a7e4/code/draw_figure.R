# Network layout adapted from Ma et al. (2021), doi:10.3389/fpls.2021.749871 Fig. 4A/B.
suppressPackageStartupMessages(library(ggplot2))
figure_palette <- c(
  Ascomycota="#61558D", Basidiomycota="#E8D886", "Unclassified fungi"="#BCB5CA",
  Mortierellomycota="#E68171", Rozellomycota="#86AFBD", Chytridiomycota="#E6AE64",
  Kickxellomycota="#A4C66B", Zoopagomycota="#DCB6CD", Olpidiomycota="#C1C1BF",
  Positive="#C96B60", Negative="#6A9D81"
)
build_network_figure <- function(nodes,edges,palette=figure_palette,group_order=unique(nodes$habitat),
                                 subtitle="Spearman edges") {
  fields_n <- c("habitat","node","degree","phylum","x","y")
  fields_e <- c("habitat","from","to","sign")
  stopifnot(all(fields_n %in% names(nodes)),all(fields_e %in% names(edges)),
    !anyNA(nodes[fields_n]),!anyNA(edges[fields_e]),length(group_order) %in% 1:2,
    !anyDuplicated(group_order),setequal(nodes$habitat,group_order),setequal(edges$habitat,group_order),
    all(is.finite(nodes$x)&is.finite(nodes$y)),all(is.finite(nodes$degree)&nodes$degree>0),
    all(edges$sign %in% c("Positive","Negative")))
  signs <- palette[c("Positive","Negative")]
  used <- sort(unique(nodes$phylum))
  known <- palette[intersect(setdiff(names(palette),names(signs)),used)]
  novel <- setdiff(used,names(known))
  colors <- c(known,setNames(grDevices::hcl.colors(length(novel),"Dark 3"),novel))
  max_degree <- max(nodes$degree)
  cowplot::set_null_device("agg")

  panels <- lapply(group_order,function(group) {
    n <- nodes[nodes$habitat==group,]
    e <- edges[edges$habitat==group,]
    from <- match(e$from,n$node)
    to <- match(e$to,n$node)
    stopifnot(!anyDuplicated(n$node),!anyNA(from),!anyNA(to),all(from!=to),
      !anyDuplicated(paste(pmin(from,to),pmax(from,to))),
      all(tabulate(c(from,to),nbins=nrow(n))==n$degree))
    i <- seq_len(nrow(e))
    t <- seq(0,1,length.out=8)
    dx <- n$x[to]-n$x[from]
    dy <- n$y[to]-n$y[from]
    bow <- ifelse(i %% 2L==0L,.12,-.12)
    curves <- data.frame(
      x=c(n$x[from]+outer(dx,t)-outer(dy*bow,4*t*(1-t))),
      y=c(n$y[from]+outer(dy,t)+outer(dx*bow,4*t*(1-t))),
      edge=rep(i,length(t)),sign=rep(e$sign,length(t)))
    n$phylum <- factor(n$phylum,levels=names(colors))
    ggplot(n,aes(x,y)) +
      geom_path(data=curves,aes(group=edge,colour=sign),linewidth=.10,alpha=.20,show.legend=c(colour=TRUE,fill=FALSE)) +
      geom_point(aes(size=degree,fill=phylum),shape=21,stroke=.075,colour="#45404B",alpha=.94,show.legend=c(fill=TRUE,colour=FALSE)) +
      scale_colour_manual("Edge sign",values=signs,limits=names(signs),drop=FALSE,
        guide=guide_legend(order=2,override.aes=list(alpha=1,linewidth=.5))) +
      scale_fill_manual("Phylum",values=colors,limits=names(colors),drop=FALSE,
        guide=guide_legend(order=1,override.aes=list(size=1.8,alpha=1))) +
      scale_size_area(max_size=2.1,limits=c(0,max_degree),guide="none") +
      coord_fixed(xlim=c(-1.05,1.05),ylim=c(-1.05,1.05),expand=FALSE) +
      labs(title=group,subtitle=subtitle) +
      theme_void(base_size=7,base_family="Arial") +
      theme(plot.title=element_text(hjust=.5,face="bold",size=8),
        plot.subtitle=element_text(hjust=.5,size=6.5,colour="#484848"),
        legend.title=element_text(size=7),legend.text=element_text(size=6.5),
        legend.key.size=grid::unit(3.15,"mm"),
        legend.spacing.y=grid::unit(1.1,"mm"),plot.margin=margin(2,1,1,1,unit="mm"))
  })
  guide <- cowplot::get_legend(panels[[1]]+theme(legend.position="right"))
  guide_cell <- cowplot::ggdraw()+cowplot::draw_grob(guide,x=.035,y=.055,width=.95,height=.90)
  widths <- if (length(panels)==1L) c(.73,.27) else c(.407,.407,.186)
  cowplot::plot_grid(plotlist=c(lapply(panels,function(x)x+theme(legend.position="none")),list(guide_cell)),
    nrow=1,rel_widths=widths,labels=c(LETTERS[seq_along(panels)],""),label_size=9,
    label_fontfamily="Arial",label_x=.03,label_y=.974)
}
