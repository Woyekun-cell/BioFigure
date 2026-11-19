#!/usr/bin/env Rscript
# Selected DPM Fig5D, real author-processed data and caption-guided Brown rows.
# Native ComplexHeatmap geometry retained in cowplot only to call BioFigure PNG gates.
# This is not the published FDR matrix or a reconstruction of its final leaf order.
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==3)
root <- normalizePath(args[1],mustWork=TRUE)
work <- normalizePath(args[2],mustWork=TRUE)
authorization <- normalizePath(args[3],mustWork=TRUE)
skill <- normalizePath(file.path(root,'../../../..'),mustWork=TRUE)
source(file.path(skill,'scripts','figure_style.R'))
options(warn=2)
font <- bf_font('Arial')
bf_complexheatmap_font(font)
spec_path <- file.path(root,'data','metadata','design-spec.yaml')
spec <- yaml::read_yaml(spec_path)
input_path <- file.path(root,'results','plot_data','figure5d_brown_caption_guided_signed_p.csv')
order_path <- file.path(root,'data','raw','author_hclust_row_order.csv')
df <- read.csv(input_path,stringsAsFactors=FALSE,check.names=FALSE)
source_order <- read.csv(order_path,stringsAsFactors=FALSE)
stopifnot(nrow(df)==645, !anyDuplicated(df$gene), all(is.finite(as.matrix(df[,c('rna','protein','methylation')]))))
mat <- as.matrix(df[,c('rna','protein','methylation')])
rownames(mat) <- df$gene
colnames(mat) <- c('R','P','M')
hc <- stats::hclust(stats::dist(mat,method='euclidean'),method='complete')
stopifnot(identical(rownames(mat)[hc$order],source_order$gene), all(abs(mat)<=10))
direction <- ifelse(df$direction=='darkcyan','Consistent','Conflicting')
stopifnot(all(df$direction %in% c('darkcyan','darkorange')),
          sum(direction=='Consistent')==375, sum(direction=='Conflicting')==270)
label_at <- which(!is.na(df$significant) & nzchar(df$significant))
stopifnot(length(label_at)==29)
pal <- spec$palette_semantics
direction_colors <- c(Consistent=pal$consistent,Conflicting=pal$conflicting)
direction_text_colors <- c(Consistent=pal$consistent_text,Conflicting=pal$conflicting_text)
color_function <- circlize::colorRamp2(c(-10,0,10),c(pal$negative,pal$zero,pal$positive),space='LAB')
gp <- function(...) grid::gpar(fontfamily=font$family,fontsize=7.5,...)
left <- ComplexHeatmap::rowAnnotation(
  Direction=direction,col=list(Direction=direction_colors),
  show_annotation_name=FALSE,show_legend=FALSE,
  simple_anno_size=grid::unit(2.5,'mm'),width=grid::unit(2.5,'mm'),
  gp=grid::gpar(col=NA))
right <- ComplexHeatmap::rowAnnotation(
  CGC=ComplexHeatmap::anno_mark(at=label_at,labels=df$gene[label_at],which='row',side='right',
    labels_gp=gp(col=unname(direction_text_colors[direction[label_at]]),fontface='italic'),
    padding=grid::unit(0.7,'mm'),link_width=grid::unit(3,'mm'),
    link_gp=grid::gpar(col=unname(direction_text_colors[direction[label_at]]),lwd=0.4)),
  show_annotation_name=FALSE,width=grid::unit(24,'mm'))
ht <- ComplexHeatmap::Heatmap(mat,name='score',col=color_function,
  rect_gp=grid::gpar(col=NA),border=FALSE,
  cluster_rows=as.dendrogram(hc),row_dend_reorder=FALSE,
  row_dend_width=grid::unit(18,'mm'),row_dend_gp=grid::gpar(col='#333333',lwd=0.4),
  cluster_columns=FALSE,show_column_dend=FALSE,
  show_row_names=FALSE,column_names_rot=0,column_names_gp=gp(),
  left_annotation=left,right_annotation=right,
  width=grid::unit(18,'mm'),height=grid::unit(124,'mm'),
  show_heatmap_legend=FALSE,use_raster=FALSE)
score_legend <- ComplexHeatmap::Legend(col_fun=color_function,at=c(-10,-5,0,5,10),
  labels=c('≤ -10','-5','0','5','≥ 10'),direction='horizontal',
  title='Signed score\nsign(log2FC) × -log10(raw P)',title_position='topleft',
  title_gp=gp(),labels_gp=gp(),legend_width=grid::unit(52,'mm'),
  grid_height=grid::unit(3.5,'mm'),title_gap=grid::unit(1,'mm'))
direction_legend <- ComplexHeatmap::Legend(labels=names(direction_colors),
  legend_gp=grid::gpar(fill=unname(direction_colors),col=NA),
  title='Direction',title_gp=gp(),labels_gp=gp(),
  grid_width=grid::unit(2.5,'mm'),grid_height=grid::unit(2.5,'mm'),
  nrow=2,title_gap=grid::unit(1,'mm'))
native_draw <- NULL
native_boxes <- new.env(parent=emptyenv())
measure_current_viewport <- function() {
  lower <- grid::deviceLoc(grid::unit(0,'npc'),grid::unit(0,'npc'),valueOnly=TRUE)
  upper <- grid::deviceLoc(grid::unit(1,'npc'),grid::unit(1,'npc'),valueOnly=TRUE)
  c(x=lower$x*25.4,y=160-upper$y*25.4,w=(upper$x-lower$x)*25.4,h=(upper$y-lower$y)*25.4)
}
native <- grid::grid.grabExpr({
  native_draw <<- ComplexHeatmap::draw(ht,newpage=FALSE,
    heatmap_legend_side='bottom',annotation_legend_side='bottom',
    heatmap_legend_list=list(score_legend,direction_legend),
    merge_legends=TRUE,legend_gap=grid::unit(8,'mm'),
    padding=grid::unit(c(3,3,3,3),'mm'))
  ComplexHeatmap::decorate_heatmap_body('score',{assign('matrix',measure_current_viewport(),envir=native_boxes)})
  ComplexHeatmap::decorate_row_dend('score',{assign('tree',measure_current_viewport(),envir=native_boxes)})
  ComplexHeatmap::decorate_annotation('Direction',{assign('direction',measure_current_viewport(),envir=native_boxes)})
  ComplexHeatmap::decorate_annotation('CGC',{assign('CGC',measure_current_viewport(),envir=native_boxes)})
  ComplexHeatmap::decorate_column_names('score',{assign('column_names',measure_current_viewport(),envir=native_boxes)})
  # Measure packed legend content, not its narrower heatmap-width container.
  if('heatmap_legend' %in% ComplexHeatmap::list_components()) {
    grid::seekViewport('heatmap_legend')
    assign('legend',measure_current_viewport(),envir=native_boxes)
    grid::upViewport(0)
  }
},width=120/25.4,height=160/25.4,wrap=FALSE,
device=function(width,height) grDevices::pdf(NULL,width=width,height=height,family=font$family))
native_boxes <- as.list(native_boxes)
actual_order <- ComplexHeatmap::row_order(native_draw)
stopifnot(identical(as.integer(actual_order),as.integer(hc$order)))
write.csv(data.frame(top_to_bottom=seq_along(actual_order),gene=rownames(mat)[actual_order]),
          file.path(root,'results','plot_data','dpm_fig5d_recolored_row_order.csv'),row.names=FALSE)
plot <- cowplot::ggdraw(native) + ggplot2::theme(
  text=ggplot2::element_text(family=font$family,size=7.5),
  plot.background=ggplot2::element_rect(fill='white',colour=NA),
  plot.margin=ggplot2::margin(0,0,0,0,'mm'))
plot_path <- file.path(work,'dpm_fig5d_recolored.png')
sources <- c(spec_path,file.path(root,'scripts','render.R'),file.path(skill,'scripts','figure_style.R'),input_path,order_path)
merged_box <- function(values) c(x=min(vapply(values,`[[`,numeric(1),'x')),
  y=min(vapply(values,`[[`,numeric(1),'y')),
  w=max(vapply(values,function(b)b['x']+b['w'],numeric(1)))-min(vapply(values,`[[`,numeric(1),'x')),
  h=max(vapply(values,function(b)b['y']+b['h'],numeric(1)))-min(vapply(values,`[[`,numeric(1),'y')))
data_box <- merged_box(native_boxes[c('matrix','tree','direction','column_names')])
stopifnot(!is.null(native_boxes$legend))
boxes <- as.data.frame(do.call(rbind,list(data=data_box,labels=native_boxes$CGC,legend=native_boxes$legend)))
boxes$id <- rownames(boxes)
boxes <- boxes[,c('id','x','y','w','h')]
receipt <- bf_render_png(plot,plot_path,font=font,allowed_text=spec$text_contract$allowed_text,
  width_mm=120,height_mm=160,target_width_mm=120,source_files=sources,boxes=boxes,
  dpi=600,min_text_pt=7.5,authorization=authorization,skill_root=skill,
  publication_size_class='one-and-half-column',
  size_override_basis=spec$output_size$size_rationale$override_basis)
pdf_path <- file.path(root,'results','figures','dpm_fig5d_recolored.pdf')
grDevices::quartz(type='pdf',file=pdf_path,width=120/25.4,height=160/25.4,family=font$family,bg='white')
print(plot)
grDevices::dev.off()
# SVG required by current paper-composite gate, kept only as work/QA output.
svg_path <- file.path(work,'dpm_fig5d_recolored-gate-qa.svg')
svglite::svglite(svg_path,width=120/25.4,height=160/25.4,bg='white',system_fonts=list(sans=font$family))
print(plot)
grDevices::dev.off()
bound <- function(path) list(path=normalizePath(path,mustWork=TRUE),sha256=digest::digest(file=path,algo='sha256'))
metrics <- list(schema_version=1,scope='Selected panel real author-processed data, caption-guided Brown rows and source raw-P code score, new palette; not whole original figure, final published matrix, or original leaf order.',
  rows=645,cells=length(mat),columns=colnames(mat),labels=29,
  direction_counts=list(Consistent=375,Conflicting=270),
  scientific_mapping=list(selection='Brown BH < 0.001 over 9209 author genes',
    score='clip(-log10(raw P), 0, 10) * (1 if FC > 0 else -1)',
    zero_center=0,limits=c(-10,10),source_legend_discrepancy='Official Fig5D legend says FDR; pinned plotting code uses original P. Final published matrix and final assembly order not acquired. Visible leaf order differs, cause unverified.'),
  geometry=list(final_mm=c(width=120,height=160),matrix_body_mm=c(width=18,height=124),
    tree_mm=18,direction_strip_mm=2.5,CGC_label_slot_mm=24,legend_placement='bottom',
    minimum_text_pt=7.5,leaf_order_matches_source_hclust=TRUE,
    row_dend_reorder=FALSE,cluster_columns=FALSE),
  measured_native_component_boxes_mm=native_boxes,
  measured_gate_boxes_mm=boxes,
  palette=pal,
  package_adaptation='ComplexHeatmap native full row dendrogram, matrix and anno_mark replaces gplots heatmap.2 physical layout; cowplot draws the captured native grid object for BioFigure authorization/font/text preflight only.',
  source_files=lapply(sources,bound),artifacts=list(pdf=bound(pdf_path),png=bound(plot_path),gate_qa_svg=bound(svg_path)),
  render_receipt=bound(paste0(plot_path,'.render.json')),
  final_review_status='PENDING_INDEPENDENT_REVIEW')
jsonlite::write_json(metrics,file.path(root,'results','tables','render-metrics.json'),auto_unbox=TRUE,pretty=TRUE)
writeLines(capture.output(sessionInfo()),file.path(root,'data','metadata','R-sessionInfo.txt'))
writeLines(capture.output(print(font)),file.path(root,'data','metadata','resolved-font.txt'))
cat('DPM_RENDER_OK\n',pdf_path,'\n',plot_path,'\n')
