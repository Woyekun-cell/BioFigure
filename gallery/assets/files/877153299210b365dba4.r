# Usage: Rscript render.R WORK_DIRECTORY AUTHORIZATION
# Synthetic visual reconstruction; original panel data and paper unidentified.
suppressPackageStartupMessages({library(ggplot2);library(yaml);library(jsonlite)})
args <- commandArgs(TRUE);stopifnot(length(args)==2)
work <- normalizePath(args[1]);authorization <- args[2]
script <- normalizePath(sub('^--file=','',grep('^--file=',commandArgs(),value=TRUE)))
root <- dirname(dirname(script));skill <- normalizePath(Sys.getenv('BIOFIGURE_ROOT'))
source(file.path(skill,'scripts/figure_style.R'));font <- bf_font('Arial')
spec <- file.path(root,'data/metadata/design-spec.yaml');design <- read_yaml(spec)
input <- file.path(root,'results/plot_data/window_pair_identity.csv')
track_file <- file.path(root,'results/plot_data/context_track.csv')
scale_file <- file.path(root,'data/metadata/scale.json')
upstream <- file.path(root,'evidence/source/aln_plot.R')
d <- read.csv(input);track <- read.csv(track_file);scale <- fromJSON(scale_file)
# Execute only the pinned StainedGlass diamond assignment, not its CLI/pipeline.
expressions <- as.list(parse(upstream))
selected <- Filter(function(e) is.call(e) && identical(e[[1]],as.name('<-')) &&
                        identical(e[[2]],as.name('diamond')),expressions)
stopifnot(length(selected)==1)
method_env <- new.env(parent=baseenv());eval(selected[[1]],envir=method_env)
diamond <- method_env$diamond
step <- unique(round(d$query_end-d$query_start,12));stopifnot(length(step)==1)
obs <- d[is.finite(d$identity_percent),]
obs$w <- (obs$query_start+obs$reference_start+step)/2
obs$z <- -(obs$reference_start-obs$query_start)/2
obs$window <- step/sqrt(2);obs$group <- seq_len(nrow(obs))
obs$discrete <- as.integer(cut(obs$identity_percent,breaks=scale$breaks,
                               include.lowest=TRUE,right=TRUE))
stopifnot(!anyNA(obs$discrete),nrow(obs)==4396)
polygons <- do.call(rbind,lapply(seq_len(nrow(obs)),function(i)
   diamond(unlist(obs[i,c('window','w','z','discrete','group')]))))
polygons$bin <- factor(sprintf('bin%02d',polygons$discrete),levels=names(design$palette_semantics))
# Geometry verification: inverse centers recover the input window midpoints;
# rotated diagonals are equal, so cells are squares rather than stretched tiles.
first <- polygons[polygons$group==1,];stopifnot(nrow(first)==4,
 abs(diff(range(first$w))-step)<1e-10,abs(diff(range(first$z))-step)<1e-10,
 abs(mean(first$w)+mean(first$z)-(obs$query_start[1]+step/2))<1e-10,
 abs(mean(first$w)-mean(first$z)-(obs$reference_start[1]+step/2))<1e-10)
key_x <- 11.67;key_w <- 4.40
key <- data.frame(xmin=key_x+head(scale$positions,-1)*key_w,
 xmax=key_x+tail(scale$positions,-1)*key_w,ymin=-2.05,ymax=-1.48,
 bin=factor(names(design$palette_semantics),levels=names(design$palette_semantics)))
ticks <- data.frame(x=key_x+c(0,.32,.64,1)*key_w,label=c('75.00','80.00','99.75','100.00'))
blocks <- data.frame(xmin=c(3.7,5.0,5.65,6.15),xmax=c(4.88,5.55,6.08,9.52),ymin=.10,ymax=.57)
boundaries <- data.frame(x=sort(unique(c(blocks$xmin,blocks$xmax))))
p <- ggplot(polygons,aes(w,z,group=group,fill=bin))+
 geom_polygon(colour=NA)+
 geom_rect(data=blocks,aes(xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax),
            inherit.aes=FALSE,fill='#BFBFBF',colour=NA)+
 geom_linerange(data=track,aes(x=position_mb,ymin=.08,ymax=.08+value),
                inherit.aes=FALSE,colour='#202020',linewidth=.18)+
 geom_segment(data=boundaries,aes(x=x,xend=x,y=.10,yend=.57),
               inherit.aes=FALSE,colour='#303030',linewidth=.25)+
 annotate('segment',x=0,xend=10.95,y=.08,yend=.08,linewidth=.40)+
 annotate('segment',x=c(0,10.95),xend=c(0,10.95),y=.08,yend=-.08,linewidth=.35)+
 annotate('text',x=0,y=-.34,label='0.00 Mb',hjust=0,family=font$family,size=7/.pt)+
 annotate('text',x=11.05,y=-.34,label='10.95 Mb',hjust=0,family=font$family,size=7/.pt)+
 geom_rect(data=key,aes(xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax,fill=bin),inherit.aes=FALSE,colour=NA)+
 annotate('rect',xmin=key_x,xmax=key_x+key_w,ymin=-2.05,ymax=-1.48,
           fill=NA,colour='black',linewidth=.35)+
 geom_segment(data=ticks,aes(x=x,xend=x,y=-2.05,yend=-2.17),inherit.aes=FALSE,linewidth=.30)+
 geom_text(data=ticks,aes(x=x,y=-2.28,label=label),inherit.aes=FALSE,
           angle=45,hjust=1,vjust=1,family=font$family,size=7/.pt)+
 annotate('text',x=key_x+key_w/2,y=-1.06,label='Sequence identity (%)',family=font$family,size=7/.pt)+
 annotate('text',x=key_x+key_w*c(.17,.49),y=-2.29,label='...',family=font$family,size=7/.pt)+
 scale_fill_manual(values=unlist(design$palette_semantics),guide='none',drop=FALSE)+
 coord_fixed(ratio=1,xlim=c(-.10,16.8),ylim=c(-5.35,.90),expand=FALSE)+
 labs(x=NULL,y=NULL)+bf_theme(font)+theme(axis.line=element_blank(),axis.ticks=element_blank(),
    axis.text=element_blank(),axis.title=element_blank(),legend.position='none',plot.margin=margin(2,2,2,2,'mm'))
sources <- c(spec,script,file.path(skill,'scripts/figure_style.R'),input,track_file,scale_file,upstream)
boxes <- data.frame(id=c('data','labels','legend'),x=c(3,3,128),y=c(11,1,23),w=c(119,119,52),h=c(57,8,23))
out <- file.path(work,'triangular_sequence_identity.png')
bf_render_png(p,out,font,design$text_contract$allowed_text,183,72,183,sources,boxes,
  authorization=authorization,skill_root=skill,publication_size_class='double-column',dpi=600)
quartz(type='pdf',file=file.path(root,'results/figures/triangular_sequence_identity.pdf'),
       width=183/25.4,height=72/25.4,family='Arial');print(p);invisible(dev.off())
ggsave(file.path(work,'triangular_sequence_identity.svg'),p,device=svglite::svglite,width=183,height=72,units='mm',bg='white')
capture.output(sessionInfo(),file=file.path(root,'evidence/sessionInfo.txt'))
cat('UPSTREAM_DIAMOND_EXECUTED; ROTATION_AND_SQUARE_GEOMETRY_VERIFIED; RENDER_OK\n')
