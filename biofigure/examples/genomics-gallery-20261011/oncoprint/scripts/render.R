#!/usr/bin/env Rscript
# Self-authored synthetic event example. No copied tutorial code or patient data.
# Rscript render.R package_root work_root authorization_json
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==3)
root <- normalizePath(args[1],mustWork=TRUE)
work <- normalizePath(args[2],mustWork=TRUE)
authorization <- normalizePath(args[3],mustWork=TRUE)
skill <- Sys.getenv('BIOFIGURE_SKILL_ROOT')
stopifnot(nzchar(skill))
source(file.path(skill,'scripts','figure_style.R'))
options(warn=2)
font <- bf_font('Arial')
bf_complexheatmap_font(font)
suppressPackageStartupMessages(library(ComplexHeatmap))
ht_opt(HEATMAP_LEGEND_PADDING=grid::unit(5,'mm'))
spec_path <- file.path(root,'data/metadata/design-spec.yaml')
spec <- yaml::read_yaml(spec_path)
size <- spec$output_size
width <- size$width_mm; height <- size$height_mm
native_height <- height-5
gp <- function(...)grid::gpar(fontfamily=font$family,fontsize=7.5,...)
read <- function(name)read.csv(file.path(root,'results/plot_data',name),check.names=FALSE,
 stringsAsFactors=FALSE,na.strings=character())
# Entirely event-free columns must stay empty strings, not inferred logical NA.
matrix_data <- read.csv(file.path(root,'results/plot_data/oncoprint_simulated_matrix.csv'),
 check.names=FALSE,stringsAsFactors=FALSE,na.strings=character(),colClasses='character')
mat <- as.matrix(matrix_data[,-1,drop=FALSE]); rownames(mat)<-matrix_data$gene
metadata <- read('oncoprint_simulated_sample_order.csv')
frequency <- read('oncoprint_simulated_gene_frequency.csv')
counts <- read('oncoprint_simulated_sample_counts.csv')
stopifnot(identical(dim(mat),c(12L,144L)),!anyNA(mat),
 identical(colnames(mat),metadata$sample_id),identical(colnames(mat),counts$sample_id),
 identical(rownames(mat),frequency$gene),all(frequency$assayed_tumours==144),
 all(rowSums(mat!='')==frequency$altered_tumours),all(colSums(mat!='')==counts$altered_genes))
types <- c('Missense','Frameshift','Nonsense','Splice','In_frame')
pal <- unlist(spec$palette_semantics)
colors <- pal[types]
glyph_counts <- new.env(parent=emptyenv())
glyph_counts$cells <- 0L; glyph_counts$events <- 0L
glyph_counts$event_types <- setNames(integer(length(types)),types)
# oncoPrint supplies one named presence vector per cell. Every positive class
# gets its own stripe; coexisting types are never overwritten or collapsed.
glyph <- function(x,y,w,h,v) {
 glyph_counts$cells <- glyph_counts$cells+1L
 grid::grid.rect(x,y,w*.94,h*.8,gp=grid::gpar(fill=pal['background'],col=NA))
 present <- types[as.logical(v[types])]
 if(!length(present))return(invisible(NULL))
 band_height <- h*.8/length(present)
 for(i in seq_along(present)) {
  center <- y+h*.4-band_height*(i-.5)
  grid::grid.rect(x,center,w*.94,band_height,gp=grid::gpar(fill=colors[present[i]],col=NA))
 }
 glyph_counts$events <- glyph_counts$events+length(present)
 glyph_counts$event_types[present] <- glyph_counts$event_types[present]+1L
}
axis <- function(at,side)list(at=at,labels=as.character(at),side=side,labels_rot=0,gp=gp())
annotation <- HeatmapAnnotation(
 `Altered genes`=anno_barplot(counts$altered_genes,height=grid::unit(10,'mm'),ylim=c(0,12),
  border=FALSE,gp=grid::gpar(fill=colors['Missense'],col=pal['outline'],lwd=.3),axis_param=axis(c(0,6,12),'left')),
 Sex=metadata$sex,Smoking=metadata$smoking,
 col=list(Sex=pal[c('Female','Male','Unknown')],Smoking=pal[c('Ever','Never','Unknown')]),
 simple_anno_size=grid::unit(3,'mm'),gap=grid::unit(1,'mm'),
 annotation_name_side='left',annotation_name_gp=gp(),show_legend=FALSE,
 gp=grid::gpar(col='white',lwd=.15))
right <- rowAnnotation(`Tumours (%)`=anno_barplot(frequency$frequency_percent,
 width=grid::unit(18,'mm'),ylim=c(0,60),border=FALSE,
 gp=grid::gpar(fill=colors['Missense'],col=pal['outline'],lwd=.35),axis_param=axis(c(0,20,40,60),'top')),
 annotation_name_side='top',annotation_name_rot=0,annotation_name_gp=gp())
# 1,728 audited cell calls are inexpensive here. Muffle only this documented
# performance advisory; scientific/layout warnings still fail under warn=2.
ht <- withCallingHandlers(oncoPrint(mat,name='Alteration',
 get_type=function(x)if(nzchar(x))strsplit(x,';',fixed=TRUE)[[1]] else character(),
 alter_fun=glyph,alter_fun_is_vectorized=FALSE,col=colors,
 row_order=seq_len(nrow(mat)),column_order=seq_len(ncol(mat)),
 column_split=factor(metadata$cohort,levels=c('A','B','C')),
 column_title=c('A (48)','B (48)','C (48)'),column_title_gp=gp(),
 column_gap=grid::unit(2,'mm'),cluster_column_slices=FALSE,
 width=grid::unit(124,'mm'),height=grid::unit(66,'mm'),
 show_column_names=FALSE,show_row_names=TRUE,row_names_side='left',row_names_gp=gp(fontface='italic'),
 row_names_max_width=grid::unit(15,'mm'),show_pct=TRUE,pct_side='right',pct_digits=0,pct_gp=gp(),
 remove_empty_rows=FALSE,remove_empty_columns=FALSE,
 top_annotation=annotation,right_annotation=right,bottom_annotation=NULL,
 show_heatmap_legend=FALSE,border=TRUE),warning=function(w) {
 if(startsWith(conditionMessage(w),'You defined `cell_fun` for a heatmap with more than 100 rows or'))
  invokeRestart('muffleWarning')
})
legend <- function(labels,title,fill,nrow=1)Legend(labels=labels,title=title,
 legend_gp=grid::gpar(fill=unname(fill),col=NA),title_gp=gp(),labels_gp=gp(),
 nrow=nrow,grid_width=grid::unit(2.5,'mm'),grid_height=grid::unit(2.5,'mm'),
 title_gap=grid::unit(1,'mm'),column_gap=grid::unit(2,'mm'))
legends <- list(legend(types,'Alteration',colors),
 legend(c('Female','Male','Unknown'),'Sex',pal[c('Female','Male','Unknown')],3),
 legend(c('Ever','Never','Unknown'),'Smoking',pal[c('Ever','Never','Unknown')],3))
native_boxes <- new.env(parent=emptyenv())
gene_name_annotation <- names(ht@left_annotation@anno_list)
gene_name_annotation <- gene_name_annotation[startsWith(gene_name_annotation,'rownames_')]
stopifnot(length(gene_name_annotation)==1)
measure_viewport <- function() {
 lo<-grid::deviceLoc(grid::unit(0,'npc'),grid::unit(0,'npc'),valueOnly=TRUE)
 hi<-grid::deviceLoc(grid::unit(1,'npc'),grid::unit(1,'npc'),valueOnly=TRUE)
 c(x=lo$x*25.4,y=native_height-hi$y*25.4,w=(hi$x-lo$x)*25.4,h=(hi$y-lo$y)*25.4)
}
drawn <- NULL
native <- grid::grid.grabExpr({
 drawn <<- draw(ht,newpage=FALSE,heatmap_legend_side='bottom',
  heatmap_legend_list=legends,merge_legends=TRUE,legend_gap=grid::unit(5,'mm'),
  padding=grid::unit(c(4,4,4,4),'mm'))
 writeLines(capture.output(grid::grid.ls(viewports=TRUE,grobs=FALSE)),file.path(work,'native-viewports.txt'))
 for(slice in seq_len(3))decorate_heatmap_body('Alteration',{
  assign(paste0('matrix_',slice),measure_viewport(),envir=native_boxes)
 },row_slice=1,column_slice=slice)
 decorate_annotation(gene_name_annotation,{assign('gene_names',measure_viewport(),envir=native_boxes)})
 decorate_annotation('Altered genes',{assign('burden',measure_viewport(),envir=native_boxes)})
 decorate_annotation('Sex',{assign('sex',measure_viewport(),envir=native_boxes)})
 decorate_annotation('Smoking',{assign('smoking',measure_viewport(),envir=native_boxes)})
 decorate_annotation('Tumours (%)',{assign('frequency',measure_viewport(),envir=native_boxes)})
 grid::seekViewport('heatmap_legend');assign('legend',measure_viewport(),envir=native_boxes);grid::upViewport(0)
},width=width/25.4,height=native_height/25.4,wrap=TRUE,wrap.grobs=TRUE,
 device=function(width,height)grDevices::pdf(NULL,width=width,height=height,family=font$family))
actual_column_order <- unname(unlist(column_order(drawn),use.names=FALSE))
actual_row_order <- unname(unlist(row_order(drawn),use.names=FALSE))
stopifnot(identical(as.integer(actual_column_order),seq_len(144)),
 identical(as.integer(actual_row_order),seq_len(12)),glyph_counts$cells==1728,glyph_counts$events==424)
actual_counts <- setNames(integer(length(types)),types)
raw <- read.csv(file.path(root,'data/raw/simulated_events.csv'),stringsAsFactors=FALSE)
for(type in types)actual_counts[type]<-sum(raw$event_type==type)
stopifnot(identical(as.integer(glyph_counts$event_types),as.integer(actual_counts)))
native_boxes <- as.list(native_boxes)
jsonlite::write_json(native_boxes,file.path(work,'native-boxes-debug.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
merge_box <- function(values)c(x=min(vapply(values,`[[`,0,'x')),y=min(vapply(values,`[[`,0,'y')),
 w=max(vapply(values,function(x)x['x']+x['w'],0))-min(vapply(values,`[[`,0,'x')),
 h=max(vapply(values,function(x)x['y']+x['h'],0))-min(vapply(values,`[[`,0,'y')))
data_box <- merge_box(native_boxes[c('matrix_1','matrix_2','matrix_3','burden','sex','smoking','frequency')])
boxes <- as.data.frame(do.call(rbind,list(data=data_box,labels=native_boxes$gene_names,legend=native_boxes$legend)))
boxes$id<-rownames(boxes);boxes<-boxes[,c('id','x','y','w','h')]
stopifnot(native_boxes$legend['y']+1e-8>=max(vapply(native_boxes[paste0('matrix_',1:3)],function(x)x['y']+x['h'],0)))
bf_check_boxes(boxes,width,height)
footer <- 'Simulated data | 144 tumours, 12 genes | all genes assayed'
plot <- cowplot::ggdraw()+cowplot::draw_grob(native,x=0,y=5/height,width=1,height=native_height/height)+
 cowplot::draw_label(footer,x=.5,y=2.5/height,fontfamily=font$family,size=7.5,fontface='plain',colour='#30343B')+
 ggplot2::theme(text=ggplot2::element_text(family=font$family,size=7.5),
  plot.background=ggplot2::element_rect(fill='white',colour=NA),plot.margin=ggplot2::margin(0,0,0,0,'mm'))
inputs<-file.path(root,'results/plot_data',c('oncoprint_simulated_matrix.csv','oncoprint_simulated_sample_order.csv',
 'oncoprint_simulated_gene_frequency.csv','oncoprint_simulated_sample_counts.csv'))
sources<-c(spec_path,file.path(root,'scripts/render.R'),file.path(skill,'scripts/figure_style.R'),
 inputs,file.path(root,'data/raw/simulated_events.csv'),file.path(root,'data/raw/simulated_sample_metadata.csv'),
 file.path(root,'data/metadata/source-learning.json'))
png_path <- file.path(work,'oncoprint-simulated.png')
receipt <- bf_render_png(plot,png_path,font=font,allowed_text=spec$text_contract$allowed_text,
 width_mm=width,height_mm=height,target_width_mm=width,dpi=600,min_text_pt=7.5,
 source_files=sources,boxes=boxes,authorization=authorization,skill_root=skill,
 publication_size_class='double-column',size_override_basis='')
pdf_path <- file.path(root,'results/figures/oncoprint-simulated.pdf')
grDevices::quartz(type='pdf',file=pdf_path,width=width/25.4,height=height/25.4,family=font$family,bg='white')
print(plot);grDevices::dev.off()
svglite::svglite(file.path(work,'oncoprint-simulated-qa.svg'),width=width/25.4,height=height/25.4,
 bg='white',system_fonts=list(sans=font$family));print(plot);grDevices::dev.off()
bind<-function(p)list(path=normalizePath(p),sha256=digest::digest(file=p,algo='sha256'))
metrics <- list(scope='Explicitly simulated event-table teaching example; not original-paper reproduction',
 counts=list(tumours=144,genes=12,all_cells=1728,events=glyph_counts$events,multi_event_cells=56,zero_event_tumours=13),
 native_event_type_counts=glyph_counts$event_types,native_cells_drawn=glyph_counts$cells,
 native_gene_order=rownames(mat)[actual_row_order],native_sample_order=colnames(mat)[actual_column_order],
 geometry=list(canvas_mm=c(width,height),minimum_font_pt=7.5,native_viewports_mm=native_boxes,
 matrix_height_mm=66,declared_total_matrix_width_mm=124,three_group_gaps_mm=2),
 palette=as.list(pal),frequency_denominator=144,
 native_functions=c('ComplexHeatmap::oncoPrint','ComplexHeatmap::HeatmapAnnotation','ComplexHeatmap::rowAnnotation','ComplexHeatmap::anno_barplot','ComplexHeatmap::Legend','ComplexHeatmap::draw'),
 capture_adapter='native grid grob assembled by cowplot solely for authorized R export; no rasterized event layer',
 source_files=lapply(sources,bind),artifacts=list(pdf=bind(pdf_path),png=bind(png_path)),
 render_receipt=bind(paste0(png_path,'.render.json')),CP4='PENDING_INDEPENDENT_REVIEW')
jsonlite::write_json(metrics,file.path(root,'evidence/render-metrics.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
writeLines(capture.output(sessionInfo()),file.path(root,'data/metadata/render-sessionInfo.txt'))
writeLines(capture.output(font),file.path(root,'data/metadata/resolved-font.txt'))
cat('ONCOPRINT_RENDER_OK\n',pdf_path,'\n',png_path,'\n')
