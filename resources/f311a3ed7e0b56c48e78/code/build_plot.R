build_plot <- function(x, pal) {
  library(ggplot2)
  categories <- list(SBS=c("C>A","C>G","C>T","T>A","T>C","T>G"),
                     DBS=c("AC","AT","CC","CG","CT","GC","TA","TC","TG","TT"))
  n_channel <- c(SBS=96L,DBS=78L)
  stopifnot(all(c("signature","channel","label","group","rank","fraction") %in% names(x)),
    all(grepl("^(SBS|DBS)[0-9]+[a-z]?$",x$signature)), !anyNA(x), all(is.finite(x$fraction) & x$fraction>=0),
    !anyDuplicated(x[c("signature","channel")]))
  by_kind <- split(unique(x$signature),substr(unique(x$signature),1,3))
  stopifnot(setequal(names(by_kind),c("SBS","DBS")),all(lengths(by_kind)==1L))
  profiles <- unlist(by_kind[c("SBS","DBS")],use.names=FALSE)
  panels <- lapply(profiles,function(id) {
    kind <- substr(id,1,3)
    z <- x[x$signature==id,]
    groups <- categories[[kind]]
    n <- n_channel[[kind]]
    stopifnot(nrow(z)==n, setequal(z$rank,seq_len(n)), setequal(z$group,groups),
      abs(sum(z$fraction)-1)<1e-6, all(groups %in% names(pal)))
    z <- z[order(z$rank),]
    key <- do.call(rbind,lapply(groups,function(g) {
      ix <- z$rank[z$group==g]
      stopifnot(all(sort(ix)==seq.int(min(ix),max(ix))))
      data.frame(group=g,start=min(ix)-.43,end=max(ix)+.43,x=mean(range(ix)))
    }))
    max_pct <- max(z$fraction)*100
    y_breaks <- pretty(c(0,max_pct),n=5)
    cap <- max(y_breaks)
    stopifnot(max_pct<=cap)
    ggplot(z,aes(rank,100*fraction,fill=group))+
      geom_col(width=.74,colour="#30343B",linewidth=.35)+
      geom_rect(data=key,aes(xmin=start,xmax=end,ymin=cap*1.04,ymax=cap*1.17,fill=group),inherit.aes=FALSE)+
      geom_text(data=key,aes(x,cap*1.105,label=if(kind=="SBS") group else paste0(group,">NN")),
        inherit.aes=FALSE,family="Arial",fontface="bold",size=6.6/.pt,colour="white")+
      annotate("text",x=n*.9,y=cap*.87,label=id,family="Arial",fontface="bold",size=8.5/.pt)+
      scale_fill_manual(values=pal,guide="none")+
      scale_x_continuous(breaks=z$rank,labels=z$label,limits=c(.5,n+.5),expand=c(0,0))+
      scale_y_continuous(breaks=y_breaks,labels=paste0(y_breaks,"%"),limits=c(0,cap*1.19),expand=c(0,0))+
      labs(x=if(kind=="DBS") "Channel" else NULL,y="Proportion of mutations")+
      theme_classic(base_size=8,base_family="Arial")+
      theme(axis.text.x=element_text(angle=90,hjust=1,vjust=.5,size=6,colour="#30343B",margin=margin(t=1)),
        axis.ticks.x=element_blank(),axis.text.y=element_text(size=6,colour="#30343B"),
        plot.margin=margin(4,5,3,5),panel.grid.major.y=element_line(colour="#EFF0F3",linewidth=.2))
  })
  list(plots=panels,counts=as.list(setNames(n_channel,profiles)),sums=as.list(tapply(x$fraction,x$signature,sum)))
}
