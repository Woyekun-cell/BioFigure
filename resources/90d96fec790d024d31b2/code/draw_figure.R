# Scheer, Landau et al., Nature Communications Fig. 2a.
# Run: Rscript draw_figure.R [output-directory]
args <- commandArgs(TRUE)
self <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value=TRUE)))
case <- dirname(self)
out <- if (length(args)) args[1] else file.path(case,"figures")
dir.create(out,recursive=TRUE,showWarnings=FALSE)
library(ggplot2)

skill <- Sys.getenv("BIOFIGURE_ROOT",file.path(path.expand("~"),".codex","skills","biofigure"))
helper <- file.path(skill,"scripts","figure_style.R")
lut <- file.path(skill,"palettes","continuous-luts.csv")
source(helper)
inputs <- file.path(case,"plot_data",paste0("amylase-fig2a-",c("points","guides","regions"),".csv"))
points <- read.csv(inputs[1],na.strings="")
guides <- read.csv(inputs[2])
regions <- read.csv(inputs[3])
x <- points$signed_neg_log10_kw_p
y <- points$directional_fst
score <- points$joint_product
stopifnot(nrow(points)==187078L,all(points$chrom=="chr1"),!anyDuplicated(points$position_grch38),
          all(is.finite(x) & is.finite(y) & is.finite(score)),!any(x==0 & y==0),
          max(abs(score-x*y))<1.5e-14,
          isTRUE(all.equal(guides$value,c(7.4267421730617755,.14933944),tolerance=1e-12)),
          identical(regions$cluster,1:3))

width <- 182
height <- 104
font_family <- "Arial"
ink <- "#203141"
axes <- "#536371"
guide_color <- "#997161"
circle_color <- "#2D3968"
xlim <- c(-18.8,18.8)
ylim <- c(-.42,.42)
left <- 18
right <- 146
low <- 18.5
high <- 86.5
xmap <- function(v) left + (v-xlim[1])/diff(xlim)*(right-left)
ymap <- function(v) low + (v-ylim[1])/diff(ylim)*(high-low)

jt_lims <- range(score)
joint_color <- bf_colour_function(kind="sequential",palette_id="scico-lapaz",
                                  limits=jt_lims,direction=-1,skill_root=skill)
pop_color <- bf_colour_function(kind="diverging",palette_id="scico-vik",limits=ylim,
                                center=0,skill_root=skill)
point_order <- order(score)
pt <- data.frame(x=xmap(x[point_order]),y=ymap(y[point_order]),
                 color=joint_color(score[point_order]))

# Geometry only: each highlight uses its own visually reconstructed ellipse.
t <- seq(0,2*pi,length.out=121)
fields <- do.call(rbind,lapply(seq_len(nrow(regions)),function(i) {
  g <- regions[i,]
  data.frame(cluster=g$cluster,
             x=xmap(g$center_x+g$radius_x*cos(t)),
             y=ymap(g$center_y+g$tilt_y*cos(t)+g$radius_y*sin(t)))
}))
region_tag <- transform(regions,x=xmap(label_x),y=ymap(label_y))

variants <- points[!is.na(points$rsid),]
stopifnot(identical(variants$position_grch38,c(103584693L,103614521L)),
          identical(variants$rsid,c("rs58677276","rs143597860")))
variants$x <- xmap(variants$signed_neg_log10_kw_p)
variants$y <- ymap(variants$directional_fst)
variants$anchor_x <- xmap(c(-5.2,12.65))
variants$anchor_y <- ymap(c(-.363,.289))
variants$text_x <- xmap(c(-4.88,12.35))
variants$text_y <- ymap(c(-.372,.295))
variants$just <- c(0,1)

threshold_x <- xmap(guides$value[1]*c(-1,1))
threshold_y <- ymap(guides$value[2]*c(-1,1))
xtick <- data.frame(x=xmap(-15:15),label=as.character(-15:15))
xtick <- xtick[as.integer(xtick$label)%%5==0,]
ybreak <- c(-.4,-.2,0,.2,.4)
ytick <- data.frame(y=ymap(ybreak),label=sprintf("%.2f",ybreak))

joint_x <- c(24.8,54.4)
jmap <- function(v) joint_x[1]+(v-jt_lims[1])/diff(jt_lims)*diff(joint_x)
jsteps <- seq(jt_lims[1],jt_lims[2],length.out=257)
jguide <- data.frame(xmin=jmap(head(jsteps,-1)),xmax=pmin(joint_x[2],jmap(tail(jsteps,-1))+.023),
                    fill=joint_color((head(jsteps,-1)+tail(jsteps,-1))/2))
jtick <- data.frame(x=jmap(0:3),label=as.character(0:3))
vsteps <- seq(ylim[1],ylim[2],length.out=258)
vguide <- data.frame(ymin=ymap(head(vsteps,-1)),ymax=pmin(high,ymap(tail(vsteps,-1))+.023),
                     fill=pop_color((head(vsteps,-1)+tail(vsteps,-1))/2))

txt <- function(x,y,label,size=6.4,hjust=.5,colour=ink,face="plain",angle=0)
  annotate("text",x=x,y=y,label=label,hjust=hjust,family=font_family,size=size,
           size.unit="pt",colour=colour,fontface=face,angle=angle)

p <- ggplot() +
  geom_polygon(data=fields,aes(x,y,group=cluster),fill="#E8EEF5",colour="#D7E1EE",linewidth=.22) +
  annotate("segment",x=threshold_x,xend=threshold_x,y=low,yend=high,
           linewidth=.24,colour=guide_color,linetype="32") +
  annotate("segment",x=left,xend=right,y=threshold_y,yend=threshold_y,
           linewidth=.25,colour="#7D778C",linetype="13") +
  geom_point(data=pt,aes(x,y,colour=color),shape=16,size=.49,stroke=0,alpha=.91) +
  annotate("segment",x=xmap(0),xend=xmap(0),y=low,yend=high,linewidth=.22,
           colour="#647280",linetype="54",alpha=.75) +
  annotate("segment",x=left,xend=right,y=ymap(0),yend=ymap(0),linewidth=.22,
           colour="#647280",linetype="54",alpha=.75) +
  annotate("segment",x=left,xend=left,y=low,yend=high,linewidth=.28,colour=axes) +
  annotate("segment",x=left,xend=right,y=low,yend=low,linewidth=.28,colour=axes) +
  geom_segment(data=xtick,aes(x,xend=x),y=low,yend=low-1,linewidth=.23,colour=axes) +
  geom_text(data=xtick,aes(x,y=low-2.8,label=label),family=font_family,colour=ink,size=6.8,size.unit="pt") +
  geom_segment(data=ytick,aes(x=left-1,xend=left,y=y,yend=y),linewidth=.23,colour=axes) +
  geom_text(data=ytick,aes(x=left-1.75,y,label=label),hjust=1,family=font_family,
            colour=ink,size=6.8,size.unit="pt") +
  txt(4.1,mean(c(low,high)),"Directional FST",7.8,angle=90) +
  txt(mean(c(left,right)),5.45,"AMY1 copy number · Signed -log10(Kruskal-Wallis P)",7.8) +
  txt(left,10.55,"Negative association",6.6,hjust=0,colour="#344963") +
  txt(right,10.55,"Positive association",6.6,hjust=1,colour="#344963") +
  geom_text(data=region_tag,aes(x,y,label=cluster),family=font_family,fontface="bold",
            size=8,size.unit="pt",colour="#365475") +
  geom_segment(data=variants,aes(x=x,y=y,xend=anchor_x,yend=anchor_y),linewidth=.26,colour=circle_color) +
  geom_point(data=variants,aes(x,y),shape=21,size=2,stroke=.38,fill=NA,colour=circle_color) +
  geom_text(data=variants,aes(text_x,text_y,label=rsid,hjust=just),
            family=font_family,fontface="bold",size=7,size.unit="pt",colour=ink) +
  txt(24.4,80.7,"Joint product (x × y)",6.65,hjust=0) +
  geom_rect(data=jguide,aes(xmin=xmin,xmax=xmax,ymin=75.8,ymax=78.4,fill=fill),colour=NA) +
  geom_segment(data=jtick,aes(x=x,xend=x),y=75.82,yend=75.03,colour=axes,linewidth=.15) +
  geom_text(data=jtick,aes(x,y=73.3,label=label),family=font_family,colour=ink,size=6.4,size.unit="pt") +
  geom_rect(data=vguide,aes(xmin=153,xmax=155.2,ymin=ymin,ymax=ymax,fill=fill),colour=NA) +
  annotate("segment",x=152.4,xend=155.8,y=ymap(0),yend=ymap(0),linewidth=.2,colour="#B6AA9F") +
  txt(152,93.3,"ALT more frequent in",6.55,hjust=0) +
  txt(157.1,84.3,"Quechua",7.7,hjust=0,colour="#A14B27",face="bold") +
  txt(157.1,20.65,"Maya",7.7,hjust=0,colour="#275984",face="bold") +
  annotate("segment",x=c(75.5,109),xend=c(80,113.5),y=94,yend=94,linewidth=.32,
           colour=c(guide_color,"#7D778C"),linetype=c("32","13")) +
  txt(81.7,94,"Bonferroni P = 0.01",6.55,hjust=0) +
  txt(115,94,"99th percentile of |FST|",6.55,hjust=0) +
  txt(4.15,96.8,"a",9.4,face="bold") +
  txt(left,94,"Chromosome 1 SNVs",9,hjust=0,face="bold") +
  scale_fill_identity() + scale_colour_identity() +
  coord_fixed(xlim=c(0,width),ylim=c(0,height),expand=FALSE,clip="on") +
  cowplot::theme_nothing() +
  theme(plot.margin=margin(0,0,0,0),plot.background=element_rect(fill="white",colour=NA),
        panel.background=element_rect(fill="white",colour=NA))

paths <- file.path(out,paste0("amylase-fig2a.",c("png","pdf")))
font <- bf_font(font_family)
auth <- Sys.getenv("BIOFIGURE_RENDER_AUTH")
if (nzchar(auth)) {
  spec_file <- Sys.getenv("BIOFIGURE_DESIGN_SPEC")
  spec <- yaml::read_yaml(spec_file)
  boxes <- data.frame(id=c("data","legend","labels"),x=c(18,151,18),y=c(18.5,18.5,3.5),
                      w=c(128,28,128),h=c(68,76,13.5))
  bf_render_png(p,paths[1],font,unlist(spec$text_contract$allowed_text),width,height,width,
                c(spec_file,self,helper,inputs,lut),boxes,
                dpi=360,authorization=auth,min_text_pt=6.35,publication_size_class="double-column",skill_root=skill)
} else {
  ggsave(paths[1],p,device=ragg::agg_png,width=width,height=height,units="mm",dpi=360,bg="white")
}
bf_pdf_open(paths[2],width,height,font)
print(p)
invisible(dev.off())
audit <- bf_pdf_finalize(paths[2],font,width,height)
if (nzchar(auth)) jsonlite::write_json(audit,paste0(paths[2],".audit.json"),auto_unbox=TRUE,pretty=TRUE,digits=NA)
