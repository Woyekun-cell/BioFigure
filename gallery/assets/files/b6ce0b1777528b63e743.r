# Case-guided original figure. Synthetic inputs; no biological finding is asserted.
# Reference: archived tutorial REPRO-069, inspected together with its seven code blocks.
# Run: Rscript --vanilla scripts/figures/complex_heatmap_case069_20261019.R <project-root>
args <- commandArgs(trailingOnly=TRUE)
if(length(args)!=1L) stop('Supply the existing BioFigure project root.')
project <- normalizePath(args[1],mustWork=TRUE)
skill <- normalizePath(file.path(project,'biofigure'),mustWork=TRUE)
work <- file.path(project,'work/2026-10-19-case069-complex-heatmap')
source(file.path(skill,'scripts/figure_style.R'))
suppressPackageStartupMessages(library(ComplexHeatmap))
suppressPackageStartupMessages(library(circlize))
library(grid)
font <- bf_font('Arial')
spec_path <- file.path(work,'design-spec.yaml')
spec <- yaml::read_yaml(spec_path)
style_path <- file.path(work,'project-style.yaml')
style <- yaml::read_yaml(style_path)
cols <- unlist(style$palette$semantic_colors)
prefix <- file.path(project,'results/plot_data/complex_heatmap_case069_20261019')
input_files <- paste0(prefix,c('_log2.csv','_zscore.csv','_samples.csv','_genes.csv'))
read_matrix <- function(path) {
 d <- read.csv(path,check.names=FALSE,stringsAsFactors=FALSE)
 stopifnot(!anyDuplicated(d$Gene));m <- as.matrix(d[,-1,drop=FALSE]);rownames(m)<-d$Gene;m
}
raw <- read_matrix(input_files[1]); z <- read_matrix(input_files[2])
meta <- read.csv(input_files[3],stringsAsFactors=FALSE)
genes <- read.csv(input_files[4],stringsAsFactors=FALSE)
stopifnot(identical(dim(raw),c(48L,24L)),identical(dim(raw),dim(z)),
 identical(dimnames(raw),dimnames(z)),!anyDuplicated(meta$Sample),!anyDuplicated(genes$Gene))
meta <- meta[match(colnames(z),meta$Sample),];genes<-genes[match(rownames(z),genes$Gene),]
stopifnot(identical(meta$Sample,colnames(z)),identical(genes$Gene,rownames(z)),
 all(is.finite(raw)),all(is.finite(z)),max(abs(z-t(scale(t(raw)))))<1e-12,
 max(abs(rowMeans(raw)-genes$Mean_log2))<1e-12)
group_order <- c('Control','Low stress','High stress','Recovery')
module_order <- paste('Module',1:4)
meta$Group <- factor(meta$Group,levels=group_order)
meta$Batch <- factor(meta$Batch,levels=c('Batch A','Batch B'))
genes$Module <- factor(genes$Module,levels=module_order)
stopifnot(all(table(meta$Group,meta$Batch)==3),all(table(genes$Module)==12))
layout <- jsonlite::fromJSON(file.path(work,'input-layout.json'))
W <- spec$output_size$width_mm;H<-spec$output_size$height_mm
font_gp <- function(size=7,...)gpar(fontfamily=font$family,fontsize=size,...)
colour_breaks <- seq(-3,3,length.out=9)
colour_keys <- c('z=-3','z=-2.25','z=-1.5','z=-0.75','z=0','z=0.75','z=1.5','z=2.25','z=3')
col_fun <- circlize::colorRamp2(colour_breaks,cols[colour_keys],space='LAB')
stopifnot(min(z)>-3,max(z)<3)
figure_prefix <- file.path(project,'results/figures/complex_heatmap_case069_20261019')
png <- paste0(figure_prefix,'.png');pdf<-paste0(figure_prefix,'.pdf')
script_path <- normalizePath(file.path(project,'scripts/figures/complex_heatmap_case069_20261019.R'))
sources <- c(script_path,file.path(skill,'scripts/figure_style.R'),spec_path,style_path,
             input_files,file.path(work,'input-layout.json'),file.path(work,'source-lock.json'))
bound <- function(path)list(path=normalizePath(path,mustWork=TRUE),sha256=digest::digest(file=path,algo='sha256'))
write_json <- function(x,path)jsonlite::write_json(x,path,pretty=TRUE,auto_unbox=TRUE,digits=NA,null='null')
auth_path <- file.path(work,paste0('authorization-',format(Sys.time(),'%Y%m%d%H%M%S'),'-',Sys.getpid(),'.json'))
python <- Sys.getenv('PYTHON','python3')
source_args <- unlist(lapply(sources[sources!=spec_path],function(x)c('--source',x)))
issue_args <- c(file.path(skill,'scripts/authorize_render.py'),'--receipt',file.path(work,'preparation-receipt.json'),
 '--design-spec',spec_path,'--output',auth_path,source_args)
if(system2(python,shQuote(issue_args))!=0L)stop('Current CP2/renderer authorization failed.')
consume_args <- c(file.path(skill,'scripts/authorize_render.py'),'--design-spec',spec_path,'--output',auth_path,'--consume',source_args)
if(system2(python,shQuote(consume_args))!=0L)stop('Single-use authorization was not consumed.')
before <- lapply(sources,bound)
allowed <- unlist(spec$text_contract$allowed_text)
bf_validate_publication_size(W,H,'one-and-half-column')
boxes <- data.frame(id=c('heatmap_and_annotations','legend_lane'),x=c(0,112),y=c(0,3),w=c(110,22),h=c(H,H-6))
bf_check_boxes(boxes,W,H)

# Native package geometry is retained: no bitmap stretching or generic tile redraw.
make_heatmap <- function() {
 bf_complexheatmap_font(font)
 top <- HeatmapAnnotation(
  `Library (M)`=anno_barplot(meta$Library_M,baseline=0,ylim=c(0,50),border=FALSE,bar_width=.76,
    gp=gpar(fill=cols['library_bar'],col=NA),height=unit(7.5,'mm'),
    axis_param=list(side='left',at=c(0,25,50),labels=c('0','25','50'),gp=font_gp(7))),
  Batch=meta$Batch,Group=meta$Group,
  col=list(Batch=cols[c('Batch A','Batch B')],Group=cols[group_order]),
  annotation_height=unit(c(7.5,1.4,2),'mm'),gap=unit(c(1.2,.7),'mm'),
  show_annotation_name=c(TRUE,FALSE,FALSE),annotation_name_side='right',annotation_name_rot=0,
  annotation_name_gp=font_gp(7),annotation_name_offset=unit(1.5,'mm'),
  show_legend=FALSE,gp=gpar(col=NA))
 left <- rowAnnotation(Module=genes$Module,col=list(Module=cols[module_order]),
   simple_anno_size=unit(1.5,'mm'),show_annotation_name=FALSE,show_legend=FALSE,gp=gpar(col=NA))
 right <- rowAnnotation(`Mean log2`=anno_barplot(genes$Mean_log2,baseline=0,ylim=c(0,12),border=FALSE,bar_width=.72,
   gp=gpar(fill=cols['mean_expression_bar'],col=NA),width=unit(9,'mm'),
   axis_param=list(side='bottom',labels_rot=0,at=c(0,6,12),labels=c('0','6','12'),gp=font_gp(7))),
   annotation_name_side='top',annotation_name_rot=0,annotation_name_gp=font_gp(7),annotation_name_offset=unit(2,'mm'))
 Heatmap(z,name='expression',col=col_fun,width=unit(layout$body_width_mm,'mm'),height=unit(layout$body_height_mm,'mm'),
  row_split=genes$Module,column_split=meta$Group,cluster_rows=TRUE,cluster_columns=TRUE,
  cluster_row_slices=FALSE,cluster_column_slices=FALSE,
  clustering_distance_rows='euclidean',clustering_method_rows='complete',
  clustering_distance_columns='euclidean',clustering_method_columns='complete',
  row_dend_reorder=FALSE,column_dend_reorder=FALSE,
  row_dend_width=unit(8,'mm'),column_dend_height=unit(6,'mm'),
  row_dend_gp=gpar(col='#59636C',lwd=.55),column_dend_gp=gpar(col='#59636C',lwd=.55),
  row_gap=unit(layout$row_gap_mm,'mm'),column_gap=unit(layout$column_gap_mm,'mm'),
  row_title=NULL,column_title=NULL,top_annotation=top,left_annotation=left,right_annotation=right,
  row_names_side='right',row_names_gp=font_gp(),row_names_max_width=unit(layout$max_gene_label_mm+1,'mm'),
  show_row_names=TRUE,show_column_names=TRUE,column_names_rot=90,column_names_gp=font_gp(),
  rect_gp=gpar(col='#FFFFFF',lwd=.25),border=FALSE,use_raster=FALSE,show_heatmap_legend=FALSE)
}
make_legends <- function() {
 legend_gp <- font_gp(7)
 lg1 <- Legend(title='Row Z-score',col_fun=col_fun,at=c(-3,0,3),labels=c('-3','0','3'),
  legend_height=unit(25,'mm'),grid_width=unit(2.7,'mm'),title_position='topleft',title_gp=legend_gp,labels_gp=legend_gp)
 categorical <- function(title,keys)Legend(title=title,labels=keys,legend_gp=gpar(fill=unname(cols[keys]),col=NA),
   title_gp=legend_gp,labels_gp=legend_gp,grid_width=unit(2.7,'mm'),grid_height=unit(2.7,'mm'),gap=unit(1.4,'mm'),row_gap=unit(.8,'mm'))
 packLegend(lg1,categorical('Group',group_order),categorical('Batch',c('Batch A','Batch B')),
   categorical('Module',module_order),direction='vertical',gap=unit(4.5,'mm'),max_height=unit(126,'mm'))
}

run_device <- function(path,kind) {
 if(kind=='png')ragg::agg_png(path,width=W,height=H,units='mm',res=400,background='#FFFFFF')
 else bf_pdf_open(path,W,H,font)
 ok<-FALSE;on.exit({dev.off();if(!ok)unlink(path)},add=TRUE)
 grid.newpage();pushViewport(viewport(gp=font_gp(),name='figure_root'))
 pushViewport(viewport(x=unit(0,'mm'),y=unit(0,'mm'),width=unit(110,'mm'),height=unit(H,'mm'),just=c('left','bottom'),name='heatmap_lane'))
 ht <- make_heatmap()
 drawn <- draw(ht,newpage=FALSE,padding=unit(c(5,3,4,4),'mm'),show_heatmap_legend=FALSE,
   show_annotation_legend=FALSE,heatmap_legend_side='right',annotation_legend_side='right')
 cells <- bf_complexheatmap_cell_metrics(drawn,'expression')
 # Read final device coordinates of the real heatmap body, not canvas arithmetic.
 all_body <- list()
 for(i in 1:4)for(j in 1:4) {
   b<-new.env()
   decorate_heatmap_body('expression',{
     lo<-deviceLoc(unit(0,'npc'),unit(0,'npc'),valueOnly=TRUE)
     hi<-deviceLoc(unit(1,'npc'),unit(1,'npc'),valueOnly=TRUE)
     b$box<-c(x=lo$x*25.4,y=lo$y*25.4,w=(hi$x-lo$x)*25.4,h=(hi$y-lo$y)*25.4)
   },row_slice=i,column_slice=j,envir=environment())
   all_body[[paste(i,j,sep='-')]]<-as.list(b$box)
 }
 upViewport()
 lg <- make_legends()
 lw<-convertWidth(ComplexHeatmap:::width(lg),'mm',valueOnly=TRUE)
 lh<-convertHeight(ComplexHeatmap:::height(lg),'mm',valueOnly=TRUE)
 stopifnot(lw<=22,lh<=126)
 y_top <- max(vapply(all_body,function(b)b$y+b$h,numeric(1)))
 if(y_top-lh<3)stop('Legends exceed the reserved physical lane.')
 draw(lg,x=unit(113,'mm'),y=unit(y_top,'mm'),just=c('left','top'))
 grid.force(redraw=FALSE)
 text<-character();sizes<-numeric()
 collect <- function(g,inherited=font_gp()) {
   gp<-inherited;for(key in names(g$gp))gp[[key]]<-g$gp[[key]]
   if(inherits(g,'text')&&length(g$label)) {
     if(is.expression(g$label))stop('Unexpected math expression requires separate glyph review.')
     if(is.null(gp$fontfamily)||any(gp$fontfamily!=font$family))stop('Non-Arial native grob font.')
     text<<-c(text,as.character(g$label));sizes<<-c(sizes,gp$fontsize)
   }
   for(child in c(g$grobs,as.list(g$children)))collect(child,gp)
 }
 for(name in grid.ls(print=FALSE,recursive=FALSE,viewports=FALSE)$name) {
   grob<-grid.get(name,strict=TRUE);bf_assert_scientific_grob_text(grob);collect(grob)
 }
 bf_assert_scientific_text(text)
 unexpected<-setdiff(text[nzchar(text)],allowed)
 if(length(unexpected))stop(paste('Unapproved actual text:',paste(unexpected,collapse=' | ')))
 if(!length(sizes)||min(sizes)<7)stop('Actual native text below7pt.')
 chars<-unique(unlist(strsplit(paste(text,collapse=''),'',fixed=TRUE)))
 if(any(systemfonts::glyph_info(chars,path=font$path,index=font$index)$index==0))stop('Missing Arial glyph.')
 row_order <- lapply(ComplexHeatmap::row_order(drawn),function(i)rownames(z)[i])
 column_order <- lapply(ComplexHeatmap::column_order(drawn),function(i)colnames(z)[i])
 ok<-TRUE
 list(text=unique(text),sizes=sizes,cells=cells,body_boxes=all_body,legend_box=list(x=113,y=y_top-lh,w=lw,h=lh),
      row_order=row_order,column_order=column_order)
}

png_result <- run_device(png,'png')
if(!identical(before,lapply(sources,bound)))stop('Input or renderer changed while rendering.')
auth <- jsonlite::fromJSON(auth_path,simplifyVector=FALSE)
marker <- paste0(auth_path,'.consumed')
stopifnot(file.exists(marker),trimws(readLines(marker,warn=FALSE)[1])==auth$authorization_id)
receipt <- list(schema_version=1,status='PASS',backend='R',renderer='ComplexHeatmap',artifact=bound(png),sources=before,
 authorization_consumption=list(consumed=TRUE,authorization_id=auth$authorization_id,marker=bound(marker),authorization_file=bound(auth_path),preparation_receipt=auth$bound$receipt),
 font=c(bound(font$path),list(family=font$family)),checks=list(font=TRUE,text_allowlist=TRUE,scientific_text_only=TRUE,footer_free=TRUE,layout=TRUE,target_size=TRUE,cell_geometry=TRUE),
 heatmap_cells=png_result$cells,heatmap_cell_policy_id='heatmap-cells-v1',rendered_text=as.list(png_result$text),text_policy_id='scientific-content-only-v1',footer_policy_id='no-canvas-footer-v1',
 target_min_text_pt=min(png_result$sizes),min_text_pt=7,target_width_mm=W,
 target_size=list(width_mm=W,height_mm=H,size_class='one-and-half-column',size_basis='final_physical_output'),device=list(width_mm=W,height_mm=H,dpi=400),
 boxes=boxes,scope='Executed technical checks only; actual PNG/PDF inspection required.')
write_json(receipt,paste0(png,'.render.json'))
write_json(png_result,file.path(work,'png-layout-metrics.json'))
pdf_result<-run_device(pdf,'pdf')
pdf_audit<-bf_pdf_finalize(pdf,font,W,H)
write_json(pdf_audit,paste0(pdf,'.pdf-audit.json'))
write_json(c(list(artifact=bound(pdf),source_png=bound(png),backend='R'),pdf_result),paste0(pdf,'.export.json'))
write_json(pdf_result,file.path(work,'pdf-layout-metrics.json'))
write_json(list(status='RENDERED_PENDING_VISUAL_REVIEW',png=bound(png),pdf=bound(pdf),reference='REPRO-069 tutorial',
  synthetic=TRUE,seed=layout$seed,authorization=auth_path),file.path(work,'run.json'))
cat('COMPLEX_HEATMAP_RENDERED_PENDING_VISUAL_REVIEW\n')
