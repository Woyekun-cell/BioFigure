build_plot <- function(x, pal) {
  library(ggplot2)
  required <- c("id","age","BMI","Gender","Ethnicity","IRIS")
  stopifnot(all(required%in%names(x)),nrow(x)>=2,!anyNA(x[c("id","age","BMI")]),
    all(nzchar(x$id)),!anyDuplicated(x$id),
    all(is.finite(x$age)&x$age>=21&x$age<=75),all(is.finite(x$BMI)&x$BMI>=15&x$BMI<=41))
  x <- x[order(x$age,x$id,method="radix"),]
  n <- nrow(x)
  cats <- list(IRIS=c("IS","IR","Unknown"),Ethnicity=c("Asian","Black","Caucasian","Hispanic","Unknown"),
               Gender=c("Female","Male","Unknown"))
  track <- data.frame(name=c("IRIS","Ethnicity","Gender","BMI","Age"),inner=c(1,1.53,2.06,2.63,3.52),
                      outer=c(1.45,1.98,2.51,3.45,4.34),lo=c(0,0,0,15,21),hi=c(0,0,0,41,75))
  ring <- list()
  bars <- list()
  points <- list()
  stems <- list()
  ticks <- list()
  step <- (1.5*pi)/n
  start <- pi/2-(seq_len(n)-1)*step
  angle <- start-step/2
  height <- 2.88
  for (v in seq_len(nrow(track))) {
    t <- track[v,]
    name <- t$name
    category <- name%in%names(cats)
    val <- x[[if(name=="Age") "age" else name]]
    if (category) {
      val[is.na(val)|val==""] <- "Unknown"
      stopifnot(all(val%in%cats[[name]]))
      count <- table(factor(val,levels=cats[[name]]))
      used <- count>0
      fraction <- as.numeric(count[used])/n
      bars[[name]] <- data.frame(track=name,key=names(count)[used],count=as.numeric(count[used]),
        fraction=fraction,xmin=-t$outer,xmax=-t$inner,ymax=cumsum(fraction)*height,
        ymin=c(0,head(cumsum(fraction),-1))*height)
    } else {
      scaled <- (val-t$lo)/(t$hi-t$lo)
      radius <- t$inner+scaled*(t$outer-t$inner)
      points[[name]] <- data.frame(track=name,x=-(t$inner+t$outer)/2,y=scaled*height)
      stems[[name]] <- data.frame(track=name,x=t$inner*cos(angle),y=t$inner*sin(angle),
        xend=radius*cos(angle),yend=radius*sin(angle))
      tick <- if(name=="Age") c(21,48,75) else c(15,28,41)
      ticks[[name]] <- data.frame(label=tick,track=name,x=if(name=="Age") -.09 else -.41,y=t$inner+(tick-t$lo)/(t$hi-t$lo)*(t$outer-t$inner))
    }
    ring[[name]] <- do.call(rbind,lapply(seq_len(n),function(i) {
      a <- seq(start[i],start[i]-step,length.out=8L)
      data.frame(track=name,sample=x$id[i],group=paste(name,x$id[i]),
        x=c(t$outer*cos(a),t$inner*cos(rev(a))),y=c(t$outer*sin(a),t$inner*sin(rev(a))),
        key=if(category) val[i] else "grid")
    }))
  }
  ribbon <- do.call(rbind,ring)
  bars <- do.call(rbind,bars)
  points <- do.call(rbind,points)
  stems <- do.call(rbind,stems)
  ticks <- do.call(rbind,ticks)
  stopifnot(nrow(stems)==2*n, all(table(ribbon$group)==16L),
    all(abs(tapply(bars$fraction,bars$track,sum)-1)<1e-12))
  labels <- data.frame(id=x$id,x=4.48*cos(angle),y=4.48*sin(angle),
    angle=ifelse(angle< -pi/2,angle+pi,angle)*180/pi,hjust=ifelse(angle< -pi/2,1,0))
  headings <- transform(track,x=-(inner+outer)/2,y=height+.30,
    label=c("Insulin\nresponse","Ethnicity","Gender","BMI","Age\n(years)"))
  continuous <- track[!track$name%in%names(cats),]
  pct <- bars[bars$fraction>=.12,]
  pct$label <- sprintf("%.1f%%",100*pct$fraction)
  pct$text_colour <- ifelse(pct$key %in% c("IS","Asian"),"white","#17253A")
  observed <- intersect(unlist(cats,use.names=FALSE),unique(bars$key))
  p <- ggplot()+
    geom_polygon(data=ribbon,aes(x,y,group=group,fill=key),linewidth=.10,colour="#A7A7B4",show.legend=FALSE)+
    geom_segment(data=stems,aes(x,y,xend=xend,yend=yend,colour=track),linewidth=.27,show.legend=FALSE)+
    geom_point(data=stems,aes(xend,yend,colour=track),size=.54,show.legend=FALSE)+
    geom_rect(data=continuous,aes(xmin=-outer,xmax=-inner,ymin=0,ymax=height),fill="#FAF9FC",colour="#90909C",linewidth=.25)+
    geom_boxplot(data=points,aes(x,y,group=track),width=.53,outlier.shape=NA,colour="#636575",fill="white",linewidth=.3)+
    ggbeeswarm::geom_beeswarm(data=points,aes(x,y,group=track,colour=track),size=.8,cex=.54,alpha=.82,show.legend=FALSE)+
    geom_rect(data=bars,aes(xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax,fill=key),
       colour="white",linewidth=.22,show.legend=TRUE)+
    geom_text(data=pct,aes((xmin+xmax)/2,(ymin+ymax)/2,label=label,colour=text_colour),family="Arial",size=6/.pt,show.legend=FALSE)+
    geom_text(data=headings,aes(x,y,label=label),family="Arial",lineheight=.86,size=6/.pt)+
    geom_text(data=ticks,aes(x,y,label=label,colour=track),hjust=1,family="Arial",size=6/.pt,show.legend=FALSE)+
    geom_text(data=labels,aes(x,y,label=id,angle=angle,hjust=hjust),family="Arial",size=6/.pt,colour="#414352")+
    scale_fill_manual(values=c(pal,grid="#F2F0F6"),breaks=unique(observed),name=NULL)+
    scale_colour_manual(values=c(pal,white="white","#17253A"="#17253A"),guide="none")+
    guides(fill=guide_legend(nrow=2,byrow=TRUE,override.aes=list(colour=NA,linewidth=0)))+
    coord_fixed(xlim=c(-5.10,5.10),ylim=c(-5.03,5.0),expand=FALSE,clip="off")+
    theme_void(base_family="Arial",base_size=8)+
    theme(plot.margin=margin(5,9,5,9),legend.position="top",legend.text=element_text(size=6.5),
      legend.key.size=unit(3,"mm"),legend.spacing.x=unit(1.3,"mm"))
  list(plot=p,ordered=x$id,stems=stems,bars=bars,polygons=n*5L)
}
