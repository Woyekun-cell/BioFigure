# Lake et al., Nature Fig. 4a. Usage: Rscript draw_figure.R [output-directory]
args <- commandArgs(TRUE)
self <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))
case <- dirname(self)
out <- if (length(args)) args[1] else file.path(case, "figures")
dir.create(out, showWarnings = FALSE, recursive = TRUE)
library(ggplot2)

skill <- Sys.getenv("BIOFIGURE_ROOT", file.path(path.expand("~"), ".codex", "skills", "biofigure"))
helper <- file.path(skill, "scripts", "figure_style.R")
lut <- file.path(skill, "palettes", "continuous-luts.csv")
source(helper)
inputs <- file.path(case, "plot_data", paste0("mtdna-fig4a-", c("scores","genes","sites","structures"), ".csv"))
tables <- lapply(inputs, read.csv, fileEncoding = "UTF-8")
score <- tables[[1]]
gene <- tables[[2]]
sites <- tables[[3]]
structure <- tables[[4]]
stopifnot(identical(score$POS, setdiff(1:16569, 3107L)), all(is.finite(score$MLC_pos_score)),
          all(score$MLC_pos_score >= 0 & score$MLC_pos_score <= 1),
          all(gene$start >= 1L & gene$end <= 16569L & gene$start <= gene$end),
          sum(gene$class != "Control") == 37L, nrow(sites) == 8L,
          setequal(sites$gene, structure$gene),
          sum(structure$layer == "Cu") == 3L)

width <- 182
height <- 123
font_family <- "Arial"
ink <- "#273742"
hair <- "#A0ABB3"
classes <- c(Protein="#237778", rRNA="#85537A", tRNA="#D88D4D", Control="#E2DED4")
molecular <- c(Context="#AEBBC1", Site="#5D377A", rRNA="#85537A", tRNA="#B87A34",
               mRNA="#237778", Rotenone="#237778", Coordination="#AC6B38")
x_bp <- function(bp) 15 + (bp-1)*141/16568
y_score <- function(value) 40 + 38*value
map_color <- bf_colour_function(kind="sequential", palette_id="scico-batlow", limits=c(0,1),
                                direction=-1, skill_root=skill)

# Use the same ordering as geom_line in the source, including the single 3107 gap.
n <- nrow(score)
profile <- data.frame(x=x_bp(score$POS[-n]), xend=x_bp(score$POS[-1]),
                      y=y_score(score$MLC_pos_score[-n]), yend=y_score(score$MLC_pos_score[-1]),
                      color=map_color(score$MLC_pos_score[-n]))
score_ticks <- data.frame(y=y_score(seq(0,1,.25)), label=sprintf("%.2f",seq(0,1,.25)))
pos_ticks <- data.frame(x=x_bp(c(1,4000,8000,12000,16569)), label=c("1","4000","8000","12000","16569"))
scale_edge <- seq(0,1,length.out=257)
key <- data.frame(lo=y_score(head(scale_edge,-1)), hi=y_score(tail(scale_edge,-1))+.015,
                  color=map_color((head(scale_edge,-1)+tail(scale_edge,-1))/2))

insets <- data.frame(gene=c("MT-RNR2","MT-CO1","MT-CO2","MT-ND4"),
                     x=c(30,69,108,147), pdb=c("6ZSE","5Z62","5Z62","6ZKM · Sheep"))
cell_center <- setNames(insets$x, insets$gene)
sites_xlim <- function(g) {
  group <- sites[sites$gene==g,]
  if (g == "MT-CO1") return(c(mean(c(6621,6623)),mean(c(6771,6776))))
  mean(range(group$mt_start,group$mt_end))
}
callout <- do.call(rbind,lapply(insets$gene,function(g)
  data.frame(x=unname(cell_center[g]), end=x_bp(sites_xlim(g)))))
callout$knee <- callout$end + .13 * (callout$x-callout$end)

scene <- structure
scene$x <- scene$x + cell_center[scene$gene]
scene$xend <- scene$xend + cell_center[scene$gene]
scene$y <- scene$y + 104.5
scene$yend <- scene$yend + 104.5
wire <- scene[scene$layer %in% names(molecular),]
wire$color <- molecular[wire$layer]
wire$weight <- c(Context=.60, Site=.85, rRNA=.59, tRNA=.39, mRNA=.56, Rotenone=.70,
                 Coordination=.30)[wire$layer]
wire$line <- ifelse(wire$layer=="Coordination", "22", "solid")
wire <- wire[order(match(wire$layer,c("Context","tRNA","mRNA","rRNA","Coordination","Site","Rotenone"))),]
copper <- scene[scene$layer=="Cu",]
sitelabs <- scene[scene$layer=="Label",]
lab_pos <- data.frame(label=c("His240","His290","His291","Cys196","Cys200","His204","Trp215"),
                      dx=c(9,-12,12,8,-13,-1,-15), y=c(116.5,114,101.4,96.0,115.2,114.9,113.8))
lab_pos <- lab_pos[match(sitelabs$label,lab_pos$label),]
sitelabs$tx <- cell_center[sitelabs$gene] + lab_pos$dx
sitelabs$ty <- lab_pos$y
sitelabs$line_x <- sitelabs$tx + 1.4 * sign(sitelabs$x-sitelabs$tx)
sitelabs$line_y <- sitelabs$ty + 1.15 * sign(sitelabs$y-sitelabs$ty)

# Split only the intersecting pieces, keeping non-overlapping genes full height.
edges <- sort(unique(c(gene$start-.5, gene$end+.5)))
blocks <- do.call(rbind,lapply(seq_len(length(edges)-1),function(i) {
  left <- edges[i]
  right <- edges[i+1]
  hits <- which(gene$start-.5 <= left & gene$end+.5 >= right)
  if (!length(hits)) return(NULL)
  y <- seq(22,26.4,length.out=length(hits)+1)
  data.frame(xmin=x_bp(max(1,left)),xmax=x_bp(min(16569,right)),
             ymin=head(y,-1), ymax=tail(y,-1), color=unname(classes[gene$class[hits]]))
}))
gene$ymin <- 22
gene$ymax <- 26.4
gene$center <- x_bp((gene$start+gene$end)/2)

pack <- function(df, rows) {
  widths <- systemfonts::string_width(df$gene, family=font_family,size=6,res=72) * 25.4/72
  right <- rep(-Inf, length(rows))
  for (i in seq_len(nrow(df))) {
    options <- pmax(df$center[i], right + widths[i]/2 + 1.45)
    lane <- which.min(options)
    df$label_x[i] <- options[lane]
    df$label_y[i] <- rows[lane]
    right[lane] <- df$label_x[i]+widths[i]/2
  }
  df
}
trna <- pack(gene[gene$class=="tRNA",], c(19.3,16.4,13.5,10.6))
other <- pack(gene[gene$class %in% c("Protein","rRNA"),], c(29,31.8))
locus_key <- data.frame(x=c(39,72,95,119),color=unname(classes[c("Protein","rRNA","tRNA","Control")]),
                        label=c("Protein-coding","rRNA","tRNA","Non-coding"))
txt <- function(x, y, label, size=6, hjust=.5, colour=ink, fontface="plain", angle=0)
  annotate("text", x=x, y=y, label=label, hjust=hjust, family=font_family, size=size, size.unit="pt",
           colour=colour, fontface=fontface, angle=angle)

p <- ggplot() +
  geom_segment(data=score_ticks,aes(x=15,xend=156,y=y,yend=y),colour="#E2E8E9",linewidth=.16) +
  geom_segment(data=profile,aes(x,xend=xend,y,yend=yend,colour=color),linewidth=.23,lineend="round") +
  annotate("segment",x=15,xend=156,y=y_score(.95),yend=y_score(.95),colour="#78878E",linewidth=.25,linetype="33") +
  annotate("segment",x=15,xend=15,y=40,yend=78,colour=ink,linewidth=.28) +
  annotate("segment",x=15,xend=156,y=40,yend=40,colour=ink,linewidth=.28) +
  geom_segment(data=score_ticks,aes(x=14.05,xend=15,y=y,yend=y),colour=ink,linewidth=.22) +
  geom_text(data=score_ticks,aes(x=12.9,y,label=label),colour=ink,family=font_family,
            size=6.4,size.unit="pt",hjust=1) +
  geom_segment(data=pos_ticks,aes(x,xend=x,y=40,yend=39.1),colour=ink,linewidth=.22) +
  geom_text(data=pos_ticks,aes(x,y=36.8,label=label),colour=ink,family=font_family,size=6.4,size.unit="pt") +
  txt(157.3,y_score(.95),"0.95",6,hjust=0,colour="#53656C") +
  txt(3.8,59,"MLC score",7.2,angle=90) +
  txt(85.5,34.55,"Position (bp)",7.2) +
  geom_rect(data=key,aes(xmin=164.8,xmax=167.55,ymin=lo,ymax=hi,fill=color),colour=NA) +
  geom_segment(data=score_ticks,aes(x=167.55,xend=168.3,y=y,yend=y),colour=ink,linewidth=.16) +
  geom_text(data=score_ticks,aes(x=169.2,y,label=label),colour=ink,family=font_family,size=6.2,size.unit="pt",hjust=0) +
  txt(164.8,81.8,"MLC score",6.2,hjust=0) +
  geom_segment(data=callout,aes(x=x,xend=knee,y=84.9,yend=81.2),colour=hair,linewidth=.22,lineend="round") +
  geom_segment(data=callout,aes(x=knee,xend=end,y=81.2,yend=79.3),colour=hair,linewidth=.22,lineend="round") +
  geom_point(data=callout,aes(x=end,y=79.3),size=.57,colour="#53656C") +
  geom_segment(data=wire,aes(x,y,xend=xend,yend=yend,colour=color,linewidth=weight,linetype=line),lineend="round") +
  geom_point(data=copper,aes(x,y),shape=21,fill="#C18649",colour="#78492B",size=1.88,stroke=.24) +
  geom_segment(data=sitelabs,aes(x,y,xend=line_x,yend=line_y),colour="#89929C",linewidth=.18) +
  geom_text(data=sitelabs,aes(tx,ty,label=label),family=font_family,colour=ink,size=6,size.unit="pt") +
  annotate("segment",x=c(38.6,21.5,34.6),xend=c(35.3,24.6,29.8),
           y=c(101.5,105.3,115.8),yend=c(98.4,103.8,113.9),colour=hair,linewidth=.18) +
  txt(38.9,102.9,"m.3032-3071",6,hjust=0,colour="#78446F") +
  txt(21.2,106.2,"tRNA",6,hjust=1,colour="#875521") +
  txt(35.0,116.4,"mRNA",6,hjust=0,colour="#237778") +
  annotate("segment",x=83.8,xend=71.1,y=110.2,yend=108.8,colour=hair,linewidth=.18) +
  txt(85.3,111.3,"Cu",6,colour="#844E28") +
  txt(111,104.4,"Cu",6,colour="#844E28") +
  annotate("segment",x=160,xend=153.9,y=105.8,yend=98.2,colour=hair,linewidth=.18) +
  txt(161.5,107,"Rotenone",6,colour="#237778") +
  geom_text(data=insets,aes(x,y=89.7,label=gene),colour=ink,family=font_family,fontface="bold",
            size=8.2,size.unit="pt") +
  geom_text(data=insets,aes(x,y=86.8,label=pdb),colour="#52666D",family=font_family,
            size=6,size.unit="pt") +
  annotate("rect",xmin=15,xmax=156,ymin=22,ymax=26.4,fill=classes["Control"],colour=NA) +
  geom_rect(data=blocks,aes(xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax,fill=color),
            colour="#FFFFFF",linewidth=.065) +
  annotate("rect",xmin=15,xmax=156,ymin=22,ymax=26.4,fill=NA,colour="#54616A",linewidth=.20) +
  geom_segment(data=other,aes(x=center,xend=label_x,y=ymax,yend=label_y-1.15),colour=hair,linewidth=.17) +
  geom_segment(data=trna,aes(x=center,xend=label_x,y=ymin,yend=label_y+1.15),colour=hair,linewidth=.17) +
  geom_text(data=rbind(other,trna),aes(x=label_x,y=label_y,label=gene),family=font_family,
            size=6,size.unit="pt",colour=ink) +
  geom_rect(data=locus_key,aes(xmin=x,xmax=x+2.7,ymin=4.5,ymax=6.7,fill=color),colour=NA) +
  geom_text(data=locus_key,aes(x=x+3.8,y=5.6,label=label),hjust=0,family=font_family,
            size=6.2,size.unit="pt",colour=ink) +
  txt(3.1,119.5,"a",9,fontface="bold") +
  scale_colour_identity() + scale_fill_identity() + scale_linewidth_identity() + scale_linetype_identity() +
  coord_fixed(xlim=c(0,width),ylim=c(0,height),expand=FALSE,clip="on") +
  cowplot::theme_nothing() +
  theme(plot.margin=margin(0,0,0,0),plot.background=element_rect(fill="white",colour=NA),
        panel.background=element_rect(fill="white",colour=NA))

paths <- file.path(out,paste0("mtdna-fig4a.",c("png","pdf")))
font <- bf_font(font_family)
auth <- Sys.getenv("BIOFIGURE_RENDER_AUTH")
if (nzchar(auth)) {
  spec_file <- Sys.getenv("BIOFIGURE_DESIGN_SPEC")
  spec <- yaml::read_yaml(spec_file)
  bounds <- data.frame(id=c("data","legend","labels"),x=c(14,163,3),y=c(39.2,39.5,84.5),
                       w=c(143,17,170),h=c(39,44.5,36))
  bf_render_png(p,paths[1],font,unlist(spec$text_contract$allowed_text),width,height,width,
                c(spec_file,self,helper,inputs,lut),bounds,dpi=420,authorization=auth,
                publication_size_class="double-column",skill_root=skill)
} else {
  ggsave(paths[1],p,device=ragg::agg_png,width=width,height=height,units="mm",dpi=420,bg="white")
}
bf_pdf_open(paths[2],width,height,font)
print(p)
invisible(dev.off())
pdf_audit <- bf_pdf_finalize(paths[2],font,width,height)
if (nzchar(auth)) jsonlite::write_json(pdf_audit,paste0(paths[2],".audit.json"),auto_unbox=TRUE,pretty=TRUE,digits=NA)
