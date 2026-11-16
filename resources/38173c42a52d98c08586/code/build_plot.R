build_plot <- function(x, pal) {
  library(ggplot2)
  stopifnot(all(c("term","NES","size","p_adj","label")%in%names(x)),nrow(x)>1,
    !anyNA(x),!anyDuplicated(x$term),all(nzchar(x$term)),
    all(is.finite(x$NES)),all(is.finite(x$size)&x$size>0),all(is.finite(x$p_adj)&x$p_adj>0&x$p_adj<=1),
    is.logical(x$label))
  x <- x[order(-x$NES,x$term,method="radix"),]
  x$rank <- seq_len(nrow(x))
  x$significance <- -log10(x$p_adj)
  x$text <- ifelse(x$label,x$term,"")
  upper <- x[x$NES>=0,]
  lower <- x[x$NES<0,]
  p <- ggplot(x,aes(rank,NES))+
    geom_hline(yintercept=0,colour="#AAB2BF",linetype=2,linewidth=.33)+
    geom_point(aes(size=size,fill=significance),shape=21,colour=pal[["outline"]],stroke=.32)+
    ggrepel::geom_text_repel(data=upper,aes(label=text),family="Arial",size=6.5/.pt,colour="#49375C",
      nudge_x=6,nudge_y=.64,hjust=0,seed=87,direction="y",box.padding=.30,min.segment.length=0,max.overlaps=Inf,segment.size=.22,max.time=Inf,max.iter=3000)+
    ggrepel::geom_text_repel(data=lower,aes(label=text),family="Arial",size=6.5/.pt,colour="#365477",
      nudge_x=-3,nudge_y=-.62,hjust=1,seed=87,direction="y",box.padding=.35,min.segment.length=0,max.overlaps=Inf,segment.size=.22,max.time=Inf,max.iter=3000)+
    scale_size_area(max_size=4.2,breaks=c(50,100,150),name="Gene set size")+
    scale_fill_gradientn(colours=pal[c("low","mid","high")],breaks=c(0,4,8,12),name="-log10 adjusted P")+
    scale_x_continuous(breaks=c(1,10,20,30,40,50),expand=expansion(add=c(3.5,7.5)))+
    scale_y_continuous(breaks=-2:2,expand=expansion(add=c(.78,.89)))+
    guides(size=guide_legend(order=1,override.aes=list(fill="#A9A3D3")),
           fill=guide_colourbar(order=2,display="rectangles",barheight=unit(17,"mm"),barwidth=unit(3,"mm")))+
    labs(x="Hallmark gene sets (NES rank)",y="Normalized enrichment score (NES)")+
    theme_classic(base_size=8,base_family="Arial")+
    theme(axis.text=element_text(size=7,colour="#30343B"),
      legend.title=element_text(size=8),legend.text=element_text(size=7),
      plot.margin=margin(6,5,5,5),panel.grid.major.y=element_line(colour="#EFF0F3",linewidth=.2))
  list(plot=p,rows=nrow(x),ordered=x)
}
