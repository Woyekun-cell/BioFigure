# Mighell & Lehner, NSMB Fig. 4c. https://doi.org/10.1038/s41594-026-01907-3
# Preserve the published pair scores, LOWESS fit and x/y SEM. R plot-only edition.
args <- commandArgs(TRUE)
self <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
case <- dirname(self)
if (length(args) > 1L) stop("Usage: Rscript --vanilla draw_figure.R [output_directory]")
out <- if (length(args)) args[1] else file.path(case, "figures")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
if (!"Arial" %in% systemfonts::system_fonts()$family) stop("Install Arial before drawing.")
suppressPackageStartupMessages(library(ggplot2))
suppressPackageStartupMessages(library(cowplot))
cowplot::set_null_device("agg")
pts <- read.csv(file.path(case,"plot_data/gpcr-maps-fig4c-points.csv"),stringsAsFactors=FALSE)
marks <- read.csv(file.path(case,"plot_data/gpcr-maps-fig4c-highlights.csv"),stringsAsFactors=FALSE)
stopifnot(nrow(pts)==6791L,!anyDuplicated(pts$variant),all(is.finite(as.matrix(pts[-1]))),
          nrow(marks)==3L,identical(marks$variant,c('F193A','Y219A','Y199A')),
          all(is.finite(as.matrix(marks[-1]))),all(marks$x_sem>0),all(marks$y_sem>0))
mi <- match(marks$variant,pts$variant)
stopifnot(max(abs(marks$x-pts$x[mi]))<1e-14,max(abs(marks$y-pts$y[mi]))<1e-14,
          max(abs(pts$y-pts$fitted_lowess-pts$residual))<1e-14)
fit <- pts[order(pts$x),c('variant','x','fitted_lowess')]
palette_file <- file.path(case,'source/biofigure-light-teal-rose.csv')
cols <- read.csv(palette_file,stringsAsFactors=FALSE)$colour
stopifnot(length(cols)==257L,identical(cols[c(1,129,257)],c('#31A69F','#F9F9F9','#C082B2')))
width<-89;height<-92
# Means/SEM are never displaced. Distinct shapes aid identification of vertically close means.
marks$shape <- c(21L,24L,22L)
labels <- data.frame(variant=c('F193A','Y219A','Y199A'),x=c(1.13,-.47,.55),y=c(.19,-.12,-.36),
                     xstart=c(.93,-.20,.45),ystart=c(.21,-.10,-.25),xend=marks$x,yend=marks$y)
guides <- data.frame(x=c(-1,-1,0,1),y=c(0,1,-1,-1),xend=c(2,2,0,1),yend=c(0,1,2,2))
p <- ggplot()+
  geom_segment(data=guides,aes(x=x,y=y,xend=xend,yend=yend),colour='#B3B5B8',linewidth=.25,linetype='dashed')+
  geom_point(data=pts,aes(x=x,y=y,colour=residual),shape=16,size=.48,alpha=1)+
  geom_path(data=fit,aes(x=x,y=fitted_lowess),colour='#24282D',linewidth=.32,alpha=1)+
  geom_errorbar(data=marks,aes(x=x,ymin=y-y_sem,ymax=y+y_sem),width=.055,colour='#24282D',linewidth=.30)+
  geom_errorbar(data=marks,aes(y=y,xmin=x-x_sem,xmax=x+x_sem),orientation='y',width=.055,colour='#24282D',linewidth=.30)+
  geom_point(data=marks,aes(x=x,y=y,shape=shape),fill='#FFF5D6',colour='#24282D',size=1.85,stroke=.32,alpha=1)+
  geom_segment(data=labels,aes(x=xstart,y=ystart,xend=xend,yend=yend),colour='#30343B',linewidth=.19)+
  geom_text(data=labels,aes(x=x,y=y,label=variant),family='Arial',size=7,size.unit='pt',colour='#24282D')+
  scale_colour_gradientn(colours=cols,limits=c(-.8,.8),oob=scales::squish,guide='none')+
  scale_shape_identity(guide='none')+
  scale_x_continuous(breaks=-1:2,labels=c('−1','0','1','2'),expand=expansion(0))+
  scale_y_continuous(breaks=-1:2,labels=c('−1','0','1','2'),expand=expansion(0))+
  coord_fixed(xlim=c(-1,2),ylim=c(-1,2),expand=FALSE,clip='on')+
  labs(x='Nb80 recruitment',y='β-Arr recruitment',tag='c')+
  cowplot::theme_cowplot(font_family='Arial',font_size=7.5)+
  theme(axis.text=element_text(size=7.5,colour='#24282D'),axis.title=element_text(size=9,colour='#24282D'),
    axis.title.x=element_text(margin=margin(t=5)),axis.title.y=element_text(margin=margin(r=5)),
    axis.line=element_blank(),panel.border=element_rect(colour='#30343B',fill=NA,linewidth=.24),
    axis.ticks=element_line(colour='#30343B',linewidth=.20),axis.ticks.length=grid::unit(1.1,'mm'),
    plot.margin=margin(7,5,4,3),plot.background=element_rect(fill='white',colour=NA),
    panel.background=element_rect(fill='white',colour=NA),
    plot.tag=element_text(family='Arial',face='bold',size=10,colour='#24282D'),plot.tag.position=c(.014,.978))
png <- file.path(out, "gpcr-maps-fig4c.png")
pdf <- file.path(out, "gpcr-maps-fig4c.pdf")
ggsave(png, p, device=ragg::agg_png, width=89, height=92, units="mm", dpi=450, bg="white")
if (capabilities("aqua")) {
  grDevices::quartz(type="pdf", file=pdf, width=89/25.4, height=92/25.4, family="Arial", bg="white")
} else {
  grDevices::cairo_pdf(pdf, width=89/25.4, height=92/25.4, family="Arial", bg="white")
}
print(p)
invisible(grDevices::dev.off())
