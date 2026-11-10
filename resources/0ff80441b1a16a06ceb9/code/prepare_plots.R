args <- commandArgs(TRUE)
P <- normalizePath(args[1]); W <- file.path(P,'work/2026-10-29-ape-fig3-synteny')
library(ggplot2); library(patchwork); library(grid)
set.seed(20261029)
source(file.path(P,'biofigure/library/genomics/ape-t2t/sources/SVbyEye/R/helpers.R'))
source(file.path(P,'biofigure/library/genomics/ape-t2t/sources/SVbyEye/R/geom_miropeats.R'))
cfg <- jsonlite::fromJSON(file.path(W,'source-and-palette.json')); pal <- unlist(cfg$palette)
PD <- file.path(P,'results/plot_data'); dir.create(PD,showWarnings=FALSE,recursive=TRUE)
# All coordinates below are independently simulated; the paper supplies visual roles only.
block_names <- c('1','2','3','4','5A','5B','6')
len <- setNames(c(12,4,64,16,8,32,64),block_names)
layout_blocks <- function(order, lengths) {
  ends <- cumsum(lengths[order]); data.frame(block=order,start=c(0,head(ends,-1)),end=ends)
}
split_links <- function(source,target,reverse,kind,n=45) {
  ans <- list()
  for(i in seq_len(nrow(source))) {
    b <- source$block[i]; j <- match(b,target$block)
    # Variable subdivision widths and small gaps reproduce source-like ribbon density.
    z <- c(0,cumsum(runif(n,.65,1.35))); z <- z/max(z)
    a <- head(z,-1); e <- tail(z,-1); pad <- (e-a)*.04
    q0 <- source$start[i]+(a+pad)*(source$end[i]-source$start[i])
    q1 <- source$start[i]+(e-pad)*(source$end[i]-source$start[i])
    t0 <- target$start[j]+(a+pad)*(target$end[j]-target$start[j])
    t1 <- target$start[j]+(e-pad)*(target$end[j]-target$start[j])
    minus <- b %in% reverse
    if(minus) {t0 <- target$end[j]-(a+pad)*(target$end[j]-target$start[j]);t1 <- target$end[j]-(e-pad)*(target$end[j]-target$start[j])}
    ans[[i]] <- data.frame(block=b,q0=q0,q1=q1,t0=t0,t1=t1,strand=if(minus)'-'else'+',kind=kind[[b]])
  }
  d <- do.call(rbind,ans); d$link_id <- seq_len(nrow(d)); d
}
geometry <- function(d,top,bottom) do.call(rbind,lapply(seq_len(nrow(d)),function(i) {
  # Each native SVbyEye ribbon consists of two paired endpoints on each baseline.
  data.frame(x=c(d$q0[i],d$q1[i],d$t0[i],d$t1[i]),y=c(top,top,bottom,bottom),group=i,kind=d$kind[i])
}))
base_theme <- theme_void(base_size=7,base_family='Arial')+theme(plot.margin=margin(2,3,2,2),legend.position='none')
track <- function(p,label,y,limit,ticks) {
  p+annotate('segment',x=0,xend=limit,y=y,yend=y,linewidth=.25,color='#555B60')+
    annotate('segment',x=ticks,xend=ticks,y=y,yend=y+.027,linewidth=.22,color='#555B60')+
    annotate('text',x=ticks,y=y+.074,label=ticks,size=7/2.845,family='Arial')+
    annotate('text',x=-.65*limit/23,y=y,label=label,hjust=1,size=7/2.845,family='Arial',lineheight=1.05)+
    annotate('text',x=limit+limit*.04,y=y+.074,label='Mb',hjust=0,size=7/2.845,family='Arial')
}
a1 <- layout_blocks(as.character(1:7),setNames(c(2,4,2,2,4,5,4),as.character(1:7)))
a2 <- layout_blocks(c('1','3','4','5','6','2','7'),setNames(c(2,4,2,2,4,5,4),as.character(1:7)))
k <- setNames(rep('Collinear',7),as.character(1:7));k[c('3','5')] <- 'Inverted';k['2'] <- 'Transposed'
aa <- split_links(a1,a2,c('2','3','5'),k,75)
colors_a <- c(Collinear=pal['collinear'],Inverted=pal['inverted'],Transposed=pal['highlight_transposition']);names(colors_a)<-c('Collinear','Inverted','Transposed')
g <- geometry(aa,1,0)
p <- ggplot(g,aes(x,y,group=group,fill=kind))+geom_miropeats(stat=StatMiropeats,n=50,alpha=.46,color=NA)+scale_fill_manual(values=colors_a)+base_theme
p <- track(p,'HSA\nChr. 16p',1,23,c(5,10,15,20));p<-track(p,'GGO\nChr. 18p',0,23,c(5,10,15,20))
sd <- do.call(rbind,lapply(c(0,1),function(y){st<-sort(runif(42,0,22.8));data.frame(start=st,end=pmin(st+runif(42,.025,.26),23),y=y)}))
genes <- do.call(rbind,lapply(c(-.27,1.27),function(y)data.frame(x=runif(380,0,23),y=y)))
p <- p+geom_rect(data=sd,aes(xmin=start,xmax=end,ymin=y-.014,ymax=y+.014),inherit.aes=FALSE,fill=pal['segmental_duplication'])+
 geom_segment(data=genes,aes(x=x,xend=x,y=y-.025,yend=y+.025),inherit.aes=FALSE,linewidth=.11,color='#52585A')+
 annotate('text',x=-.65,y=c(-.27,1.27),label='Genes',hjust=1,family='Arial',size=7/2.845)+
 annotate('text',x=-3.2,y=1.45,label='a',hjust=0,family='Arial',fontface='bold',size=9/2.845)+
 coord_cartesian(xlim=c(-3.2,24.3),ylim=c(-.36,1.45),clip='off')
h <- layout_blocks(block_names,len);b<-layout_blocks(c('5A','4','5B','2','1','3','6'),len);c<-layout_blocks(c('5A','4','3','2','1','5B','6'),len)
ka<-setNames(block_names,block_names);da<-split_links(h,b,c('5A','4','5B','1','3'),ka,65);db<-split_links(h,c,c('5A','3','1'),ka,65)
dg1<-geometry(da,1,2);dg2<-geometry(db,1,0);dg2$group<-dg2$group+max(dg1$group);dg<-rbind(dg1,dg2)
cb<-setNames(pal[paste0('block_',block_names)],block_names)
q<-ggplot(dg,aes(x,y,group=group,fill=kind))+geom_miropeats(stat=StatMiropeats,n=50,alpha=.50,color=NA)+scale_fill_manual(values=cb)+base_theme
q<-track(q,'PAB Chr. 2',2,200,c(50,100,150,200));q<-track(q,'PPY Chr. 2',0,200,c(50,100,150,200))
q<-q+annotate('segment',x=0,xend=200,y=1,yend=1,linewidth=.25,color='#555B60')+annotate('text',x=-5.6,y=1,label='HSA Chr. 3',hjust=1,family='Arial',size=7/2.845)+
 geom_rect(data=h,aes(xmin=start,xmax=end,ymin=.968,ymax=1.032,fill=block),inherit.aes=FALSE,color='white',linewidth=.12)+
 geom_text(data=h,aes(x=(start+end)/2,y=1,label=block),inherit.aes=FALSE,size=7/2.845,family='Arial')+
 annotate('text',x=-27.8,y=2.25,label='d',hjust=0,family='Arial',fontface='bold',size=9/2.845)+
 coord_cartesian(xlim=c(-27.8,218),ylim=c(-.13,2.25),clip='off')
# Keys explain semantic hues without adding a caption or simulation prose to the canvas.
key<-ggplot()+base_theme+geom_rect(data=data.frame(x=c(0,1.9,3.8,5.8),k=c('Collinear','Inverted','Transposed','SD')),
 aes(xmin=x,xmax=x+.25,ymin=0,ymax=.15,fill=k),inherit.aes=FALSE)+
 geom_text(data=data.frame(x=c(.35,2.25,4.15,6.15),label=c('Collinear','Inverted','Transposed','SD')),aes(x=x,y=.075,label=label),hjust=0,size=7/2.845,family='Arial')+
 scale_fill_manual(values=c(colors_a,SD=unname(pal['segmental_duplication'])))+coord_cartesian(xlim=c(0,7.1),ylim=c(-.05,.2),clip='off')
plot<-(p/key/q)+plot_layout(heights=c(1.05,.13,1.5))
write.csv(aa,file.path(PD,'ape_fig3_synteny_simulated_local_20261029.csv'),row.names=FALSE)
da$pair<-'HSA3_to_PAB2';db$pair<-'HSA3_to_PPY2';write.csv(rbind(da,db),file.path(PD,'ape_fig3_synteny_simulated_global_20261029.csv'),row.names=FALSE)
write.csv(sd,file.path(PD,'ape_fig3_synteny_simulated_sd_20261029.csv'),row.names=FALSE)
write.csv(genes,file.path(PD,'ape_fig3_synteny_simulated_gene_ticks_20261029.csv'),row.names=FALSE)
stopifnot(nrow(aa)==525,nrow(da)==455,nrow(db)==455,all(aa$q0<aa$q1),all(abs(aa$t1-aa$t0)>0),all(aa$q1<=23),all(da$q1<=200),all(db$q1<=200))
saveRDS(plot,file.path(W,'plot.rds'))
ragg::agg_png(file.path(W,'exploratory.png'),width=183,height=160,units='mm',res=200,background='white');print(plot);dev.off()
capture.output(sessionInfo(),file=file.path(W,'prepare-sessionInfo.txt'))
