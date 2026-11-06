#!/usr/bin/env Rscript
# Author processed Fig3F data; new semantic palette; no inferred star annotations.
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==3)
root <- normalizePath(args[1],mustWork=TRUE)
work <- normalizePath(args[2],mustWork=TRUE)
authorization <- normalizePath(args[3],mustWork=TRUE)
skill <- Sys.getenv('BIOFIGURE_SKILL_ROOT',normalizePath(file.path(root,'../../../../../..'),mustWork=FALSE))
source(file.path(skill,'scripts','figure_style.R'))
options(warn=2)
font <- bf_font('Arial')
bf_complexheatmap_font(font) # Register the exact ArialMT metrics for base-PDF measurement.
spec_path <- file.path(root,'data','metadata','design-spec.yaml')
spec <- yaml::read_yaml(spec_path)
input_path <- file.path(root,'results','plot_data','dpm_fig3f_recolored_plot_data.csv')
df <- read.csv(input_path,stringsAsFactors=FALSE,check.names=FALSE)
stopifnot(nrow(df)==120,all(df$raw_P>0),all(is.finite(df$log2FC)),
  length(unique(df$gene[df$cgc]))==5)
pal <- spec$palette_semantics
width <- 136; height <- 165; top <- 147; body_height <- 125
ids <- c('GO:0001667','GO:0070482')
orig <- new.env(parent=baseenv())
load(file.path(root,'data','raw','panelE_Rdata.Rdata'),envir=orig)
for(id in ids)stopifnot(identical(df$gene[df$pathway_id==id & df$OE_KD=='OE'],
  unlist(orig$res_brown$overlap[orig$res_brown$term_id==id])))
panel <- match(df$pathway_id,ids)
df$x_mm <- c(41,100)[panel]+ifelse(df$OE_KD=='KD',8,0)
df$y_mm <- top-(df$gene_order-0.5)*body_height/c(37,23)[panel]
df$r_mm <- df$bubble_diameter_mm/2
labels <- df[df$OE_KD=='OE',]
labels$x_mm <- c(35.4,94.4)[match(labels$pathway_id,ids)]
labels$label_color <- ifelse(labels$cgc,pal$CGC_text,'#30343B')
titles <- data.frame(x=c(45,104),y=156,
 label=c('Ameboidal-type\ncell migration','Response to\noxygen levels'))
qtext <- data.frame(x=c(45,104),y=149.8,label=c('FWER = 7.27e-4','FWER = 0.00124'))
frame <- data.frame(xmin=c(37,96),xmax=c(53,112),ymin=22,ymax=147)
plot <- ggplot2::ggplot()+
  ggplot2::geom_rect(data=frame,ggplot2::aes(xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax),
    fill=NA,colour='#30343B',linewidth=0.13)+
  ggforce::geom_circle(data=df,ggplot2::aes(x0=x_mm,y0=y_mm,r=r_mm,fill=plotted_log2FC),
    colour=pal$point_outline,linewidth=0.13,n=80)+
  ggplot2::scale_fill_gradient2(low=pal$negative_log2FC,mid=pal$zero_log2FC,
    high=pal$positive_log2FC,midpoint=0,limits=c(-2,2),guide='none')+
  ggplot2::geom_text(data=labels,ggplot2::aes(x=x_mm,y=y_mm,label=gene,colour=label_color),
    hjust=1,family=font$family,fontface='italic',size=7.5/ggplot2::.pt)+
  ggplot2::scale_colour_identity()+
  ggplot2::geom_text(data=titles,ggplot2::aes(x=x,y=y,label=label),
    family=font$family,size=8/ggplot2::.pt,lineheight=1.05)+
  ggplot2::geom_text(data=qtext,ggplot2::aes(x=x,y=y,label=label),
    family=font$family,size=7.5/ggplot2::.pt)+
  ggplot2::geom_text(data=labels[labels$cgc,],
    ggplot2::aes(x=ifelse(pathway_id==ids[1],59,118),y=y_mm,label='^'),
    family=font$family,colour=pal$CGC_text,size=7.5/ggplot2::.pt)+
  ggplot2::geom_text(data=data.frame(x=c(41,49,100,108),y=18.8,label=rep(c('OE','KD'),2)),
    ggplot2::aes(x=x,y=y,label=label),family=font$family,size=7.5/ggplot2::.pt)
# Both legends use exactly the same functions as the120 data circles.
gradient <- data.frame(value=seq(-2,2,length.out=200))
gradient$xmin <- 19+(gradient$value+2)*8
gradient$xmax <- gradient$xmin+32/199
plot <- plot+ggplot2::geom_rect(data=gradient,
  ggplot2::aes(xmin=xmin,xmax=xmax,ymin=6.7,ymax=9.2,fill=value),colour=NA)+
  ggplot2::annotate('text',x=35,y=13,label='log2FC',family=font$family,size=7.5/ggplot2::.pt)+
  ggplot2::geom_text(data=data.frame(x=seq(19,51,length.out=5),y=3.8,
    label=c('≤ -2','-1','0','1','≥ 2')),ggplot2::aes(x=x,y=y,label=label),
    family=font$family,size=7.5/ggplot2::.pt)
size_legend <- data.frame(x=c(76,86,96),y=8,score=c(2,4,6))
size_legend$r <- sqrt(0.55^2+(3^2-0.55^2)*size_legend$score/max(df$size_score))/2
plot <- plot+ggforce::geom_circle(data=size_legend,ggplot2::aes(x0=x,y0=y,r=r),
  fill='white',colour='#30343B',linewidth=0.13,n=80)+
  ggplot2::annotate('text',x=86,y=13,label='−log10(raw P)',family=font$family,size=7.5/ggplot2::.pt)+
  ggplot2::geom_text(data=size_legend,ggplot2::aes(x=x,y=3.8,label=as.character(score)),
    family=font$family,size=7.5/ggplot2::.pt)+
  ggplot2::annotate('text',x=116,y=8,label='^ CGC gene',colour=pal$CGC_text,
    family=font$family,size=7.5/ggplot2::.pt)+
  ggplot2::coord_fixed(xlim=c(0,width),ylim=c(0,height),expand=FALSE,clip='off')+
  ggplot2::theme_void(base_family=font$family,base_size=7.5)+
  ggplot2::theme(plot.margin=ggplot2::margin(0,0,0,0,'mm'),
    plot.background=ggplot2::element_rect(fill='white',colour=NA),
    panel.background=ggplot2::element_rect(fill='white',colour=NA))
# Validate target-device text extents separately from slot-box preflight.
grDevices::pdf(NULL,width=width/25.4,height=height/25.4,family=font$family)
measure <- function(text,size=7.5,face='plain') {
  g <- grid::textGrob(text,gp=grid::gpar(fontfamily=font$family,fontsize=size,fontface=face))
  c(width_mm=grid::convertWidth(grid::grobWidth(g),'mm',valueOnly=TRUE),
    height_mm=grid::convertHeight(grid::grobHeight(g),'mm',valueOnly=TRUE))
}
text_metrics <- lapply(labels$gene,measure,face='italic')
stopifnot(max(vapply(text_metrics,`[[`,numeric(1),'height_mm'))<125/37)
grDevices::dev.off()
boxes <- data.frame(id=c('left_matrix','right_matrix','left_gene_names','right_gene_names',
  'left_title','right_title','left_CGC','right_CGC','legend'),
  x=c(37,96,20,79,18,77,56,115,14),y=c(18,18,18,18,4,4,18,18,150),
  w=c(16,16,15.4,15.4,54,54,6,6,114),h=c(125,125,125,125,12,12,125,125,14))
bf_check_boxes(boxes,width,height)
# Canonical macro envelopes cross only because two separated panels interleave
# their name/data bands. Actual exclusive slots above are independently checked.
macro_boxes <- data.frame(id=c('data','labels','legend'),x=c(37,20,14),
  y=c(18,4,150),w=c(75,111,114),h=c(125,139,14))
sources <- c(spec_path,file.path(root,'scripts','render.R'),file.path(skill,'scripts','figure_style.R'),
  input_path,file.path(root,'data','raw','panelE_Rdata.Rdata'),
  file.path(root,'data','raw','cancer_gene_census_2023-01-18.tsv'))
png_path <- file.path(work,'dpm_fig3f_recolored.png')
receipt <- bf_render_png(plot,png_path,font=font,allowed_text=spec$text_contract$allowed_text,
  width_mm=width,height_mm=height,target_width_mm=width,dpi=600,min_text_pt=7.5,
  source_files=sources,boxes=macro_boxes,allowed_pairs='data:labels',
  authorization=authorization,skill_root=skill,
  publication_size_class='one-and-half-column',
  size_override_basis=spec$output_size$size_rationale$override_basis)
pdf_path <- file.path(root,'results','figures','dpm_fig3f_recolored.pdf')
dir.create(dirname(pdf_path),recursive=TRUE,showWarnings=FALSE)
grDevices::quartz(type='pdf',file=pdf_path,width=width/25.4,height=height/25.4,family=font$family,bg='white')
print(plot);grDevices::dev.off()
svg_path <- file.path(work,'dpm_fig3f_recolored-gate-qa.svg')
svglite::svglite(svg_path,width=width/25.4,height=height/25.4,bg='white',system_fonts=list(sans=font$family))
print(plot);grDevices::dev.off()
bind <- function(p)list(path=normalizePath(p,mustWork=TRUE),sha256=digest::digest(file=p,algo='sha256'))
metrics <- list(scope='selected Fig3F author-data replot; no original star or completefigure-fidelity claim',
  cells=120,rows=c(37,23),CGC_labels=5,original_gene_order_verified=TRUE,
  source_low_score_cells_retained=38,geometry=list(canvas_mm=c(width,height),body_mm=c(16,125),
    minimum_font_pt=7.5,exact_circle_diameter_mm=range(df$bubble_diameter_mm),
    minimum_row_pitch_mm=125/37,outline_mm=0.13),
  size_mapping='circle disk area affine in -log10(raw P), minimum diameter0.55mm',
  fill_mapping='original log2FC clipped±2, source raw effects preserved',palette=pal,
  package_adaptation=spec$renderer$function_adaptation,measured_gene_text_mm=text_metrics,
  gate_boxes_mm=macro_boxes,exclusive_slot_boxes_mm=boxes,
  allowed_envelope_overlap='data:labels: enclosing separated-panel envelopes; exclusive slots passed separately',
  source_files=lapply(sources,bind),
  artifacts=list(pdf=bind(pdf_path),png=bind(png_path),svg_qa=bind(svg_path)),
  render_receipt=bind(paste0(png_path,'.render.json')),CP4='PENDING_REVIEW')
jsonlite::write_json(metrics,file.path(root,'results','tables','render-metrics.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
writeLines(capture.output(sessionInfo()),file.path(root,'data','metadata','R-sessionInfo.txt'))
writeLines(capture.output(print(font)),file.path(root,'data','metadata','resolved-font.txt'))
cat('FIG3F_RENDER_OK\n',pdf_path,'\n',png_path,'\n')
