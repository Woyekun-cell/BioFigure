#!/usr/bin/env Rscript
# First-party synthetic event example. Direct native draw on every final device.
# Three consecutive original cohorts preserve the full 12 by 144 matrix.
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==3L)
root<-normalizePath(args[1],mustWork=TRUE);work<-normalizePath(args[2],mustWork=TRUE)
authorization<-normalizePath(args[3],mustWork=TRUE)
skill<-normalizePath(Sys.getenv('BIOFIGURE_SKILL_ROOT'),mustWork=TRUE)
spec_path<-file.path(root,'data/metadata/design-spec.yaml')
bound<-function(p)list(path=normalizePath(p,mustWork=TRUE),sha256=digest::digest(file=p,algo='sha256'))
write_json<-function(x,p)jsonlite::write_json(x,p,pretty=TRUE,auto_unbox=TRUE,digits=NA)
generated_tables<-c('dpm_fig3e_recolored_layout.csv','sankey_native_strata.csv')
tables<-sort(list.files(file.path(root,'results/plot_data'),pattern='[.]csv$',full.names=TRUE))
sources<-c(spec_path,file.path(root,'scripts/public-render.R'),file.path(skill,'scripts/figure_style.R'),
 tables[!basename(tables)%in%generated_tables],sort(list.files(file.path(root,'data/raw'),pattern='[.]csv$',full.names=TRUE)),
 file.path(root,'data/metadata/source-learning.json'))
before<-lapply(sources,bound)
source(file.path(skill,'scripts','figure_style.R'))
options(warn=2)
suppressPackageStartupMessages(library(ComplexHeatmap))
font<-bf_font('Arial');bf_complexheatmap_font(font)
spec<-yaml::read_yaml(spec_path)
width<-spec$output_size$width_mm;height<-spec$output_size$height_mm
stopifnot(width==183,height<=170,identical(spec$heatmap_cell_contract$shape,'square'),
 spec$heatmap_cell_contract$rows==12,spec$heatmap_cell_contract$columns==144,
 setequal(unlist(spec$output_size$formats),c('png','pdf','svg')))
bf_validate_publication_size(width,height,'double-column')
gp<-function(...)grid::gpar(fontfamily=font$family,fontsize=6.5,...)
read<-function(name)read.csv(file.path(root,'results/plot_data',name),check.names=FALSE,
 stringsAsFactors=FALSE,na.strings=character(),colClasses='character')
matrix_data<-read('oncoprint_simulated_matrix.csv')
mat<-as.matrix(matrix_data[,-1,drop=FALSE]);rownames(mat)<-matrix_data$gene
metadata<-read('oncoprint_simulated_sample_order.csv')
frequency<-read('oncoprint_simulated_gene_frequency.csv');counts<-read('oncoprint_simulated_sample_counts.csv')
frequency$frequency_percent<-as.numeric(frequency$frequency_percent)
counts$altered_genes<-as.integer(counts$altered_genes)
stopifnot(identical(dim(mat),c(12L,144L)),!anyNA(mat),
 identical(colnames(mat),metadata$sample_id),identical(colnames(mat),counts$sample_id),
 identical(rownames(mat),frequency$gene),all(as.integer(frequency$assayed_tumours)==144),
 all(rowSums(mat!='')==as.integer(frequency$altered_tumours)),all(colSums(mat!='')==counts$altered_genes),
 identical(metadata$cohort,rep(c('A','B','C'),each=48)))
types<-c('Missense','Frameshift','Nonsense','Splice','In_frame')
pal<-unlist(spec$palette_semantics);colors<-pal[types]
raw<-read.csv(file.path(root,'data/raw/simulated_events.csv'),stringsAsFactors=FALSE,colClasses='character')
expected_type_counts<-setNames(vapply(types,function(t)sum(raw$event_type==t),integer(1)),types)
stopifnot(nrow(raw)==424)
if(!identical(before,lapply(sources,bound)))stop('bound input changed while reading; fresh CP2 and analysis required')
py<-Sys.getenv('PYTHON','python3')
auth_args<-c(file.path(skill,'scripts/authorize_render.py'),'--design-spec',spec_path,'--output',authorization,'--consume',
 unlist(lapply(sources[sources!=spec_path],function(x)c('--source',x))))
if(system2(py,shQuote(auth_args))!=0L)stop('render authorization rejected or consumed')
axis<-function(at,side)list(at=at,labels=as.character(at),side=side,labels_rot=0,gp=gp())
legend<-function(labels,title,fill,nrow=1)Legend(labels=labels,title=title,
 legend_gp=grid::gpar(fill=unname(fill),col=NA),title_gp=gp(),labels_gp=gp(),nrow=nrow,
 grid_width=grid::unit(2.2,'mm'),grid_height=grid::unit(2.2,'mm'),title_gap=grid::unit(1,'mm'),column_gap=grid::unit(2,'mm'))
make_legends<-function()packLegend(legend(types,'Alteration',colors),
 legend(c('Female','Male','Unknown'),'Sex',pal[c('Female','Male','Unknown')]),
 legend(c('Ever','Never','Unknown'),'Smoking',pal[c('Ever','Never','Unknown')]),
 direction='horizontal',gap=grid::unit(5,'mm'),max_width=grid::unit(175,'mm'))
native_text<-character();native_sizes<-numeric()
collect_grid<-function(g,inherited=gp()) {
 inherited_gp<-inherited;for(k in names(g$gp))inherited_gp[[k]]<-g$gp[[k]]
 if(inherits(g,'text')&&length(g$label)) {
  if(is.expression(g$label))stop('unexpected expression requires a separate glyph audit')
  if(is.null(inherited_gp$fontfamily)||any(inherited_gp$fontfamily!=font$family))stop('native font inheritance mismatch')
  native_text<<-c(native_text,as.character(g$label));native_sizes<<-c(native_sizes,inherited_gp$fontsize)
 }
 for(child in c(g$grobs,as.list(g$children)))collect_grid(child,inherited_gp)
}
box<-function() {
 lo<-grid::deviceLoc(grid::unit(0,'npc'),grid::unit(0,'npc'),valueOnly=TRUE)
 hi<-grid::deviceLoc(grid::unit(1,'npc'),grid::unit(1,'npc'),valueOnly=TRUE)
 c(x=lo$x*25.4,y=height-hi$y*25.4,w=(hi$x-lo$x)*25.4,h=(hi$y-lo$y)*25.4)
}
merge_box<-function(values)c(x=min(vapply(values,`[[`,0,'x')),y=min(vapply(values,`[[`,0,'y')),
 w=max(vapply(values,function(x)x['x']+x['w'],0))-min(vapply(values,`[[`,0,'x')),
 h=max(vapply(values,function(x)x['y']+x['h'],0))-min(vapply(values,`[[`,0,'y')))
draw_native<-function() {
 native_text<<-character();native_sizes<<-numeric()
 audit<-new.env(parent=emptyenv());audit$cells<-0L;audit$events<-0L
 audit$event_types<-setNames(integer(length(types)),types)
 glyph<-function(x,y,w,h,v) {
  audit$cells<-audit$cells+1L
  grid::grid.rect(x,y,w*.94,h*.94,gp=grid::gpar(fill=pal['background'],col=NA))
  present<-types[as.logical(v[types])];if(!length(present))return(invisible(NULL))
  band_height<-h*.94/length(present)
  for(i in seq_along(present))grid::grid.rect(x,y+h*.47-band_height*(i-.5),w*.94,band_height,
   gp=grid::gpar(fill=colors[present[i]],col=NA))
  audit$events<-audit$events+length(present);audit$event_types[present]<-audit$event_types[present]+1L
 }
 cells<-list();data_boxes<-list();label_boxes<-list();orders<-integer();row_orders<-list()
 for(block in seq_len(3)) {
  index<-((block-1L)*48L+1L):(block*48L);name<-paste0('Alteration_',block)
  top<-HeatmapAnnotation(`Altered genes`=anno_barplot(counts$altered_genes[index],height=grid::unit(7,'mm'),ylim=c(0,12),
   border=FALSE,gp=grid::gpar(fill=colors['Missense'],col=pal['outline'],lwd=.25),axis_param=axis(c(0,6,12),'left')),
   Sex=metadata$sex[index],Smoking=metadata$smoking[index],
   col=list(Sex=pal[c('Female','Male','Unknown')],Smoking=pal[c('Ever','Never','Unknown')]),
   simple_anno_size=grid::unit(2.3,'mm'),gap=grid::unit(.7,'mm'),annotation_name_side='left',annotation_name_gp=gp(),
   show_legend=FALSE,gp=grid::gpar(col='white',lwd=.15))
  # This is the same whole-matrix frequency on each block, never a cohort frequency.
  right<-rowAnnotation(`All tumours (%)`=anno_barplot(frequency$frequency_percent,width=grid::unit(22,'mm'),ylim=c(0,60),
   border=FALSE,gp=grid::gpar(fill=colors['Missense'],col=pal['outline'],lwd=.25),axis_param=axis(c(0,20,40,60),'top')),
   annotation_name_side='top',annotation_name_rot=0,annotation_name_gp=gp())
  ht<-withCallingHandlers(oncoPrint(mat[,index,drop=FALSE],name=name,
   get_type=function(x)if(nzchar(x))strsplit(x,';',fixed=TRUE)[[1]] else character(),
   alter_fun=glyph,alter_fun_is_vectorized=FALSE,col=colors,row_order=seq_len(12),column_order=seq_len(48),
   column_title=paste0(c('A','B','C')[block],' (48)'),column_title_gp=gp(),
   width=grid::unit(100.8,'mm'),height=grid::unit(25.2,'mm'),
   show_column_names=FALSE,show_row_names=TRUE,row_names_side='left',row_names_gp=gp(fontface='italic'),
   row_names_max_width=grid::unit(15,'mm'),show_pct=FALSE,
   remove_empty_rows=FALSE,remove_empty_columns=FALSE,top_annotation=top,right_annotation=right,bottom_annotation=NULL,
   show_heatmap_legend=FALSE,border=TRUE),warning=function(w) {
    if(startsWith(conditionMessage(w),'You defined `cell_fun` for a heatmap with more than 100 rows or'))invokeRestart('muffleWarning')
   })
  grid::pushViewport(grid::viewport(x=grid::unit(0,'mm'),y=grid::unit(height-2-(block-1)*49,'mm'),
   width=grid::unit(width,'mm'),height=grid::unit(47,'mm'),just=c('left','top'),name=paste0('block_',block)))
  drawn<-draw(ht,newpage=FALSE,padding=grid::unit(c(1,3,1,3),'mm'))
  block_cells<-bf_complexheatmap_cell_metrics(drawn,name)
  stopifnot(length(block_cells)==1)
  block_cells[[1]]$matrix_id<-'Alteration';block_cells[[1]]$matrix_rows<-12L;block_cells[[1]]$matrix_columns<-144L
  cells<-c(cells,block_cells)
  orders<-c(orders,index[unlist(column_order(drawn),use.names=FALSE)])
  row_orders[[block]]<-as.integer(unlist(row_order(drawn),use.names=FALSE))
  for(ann in c('Altered genes','Sex','Smoking','All tumours (%)')) {
   measured<-new.env()
   decorate_annotation(ann,{measured$value<-box()},envir=environment())
   data_boxes[[paste(block,ann)]]<-measured$value
  }
  measured<-new.env();decorate_heatmap_body(name,{measured$value<-box()},envir=environment())
  data_boxes[[paste0('body_',block)]]<-measured$value
  rn<-names(ht@left_annotation@anno_list);rn<-rn[startsWith(rn,'rownames_')];stopifnot(length(rn)==1)
  measured<-new.env();decorate_annotation(rn,{measured$value<-box()},envir=environment())
  label_boxes[[block]]<-measured$value
  grid::upViewport(0)
 }
 legends<-make_legends()
 draw(legends,x=grid::unit(width/2,'mm'),y=grid::unit(8,'mm'),just=c('center','center'))
 legend_box<-c(x=(width-grid::convertWidth(ComplexHeatmap:::width(legends),'mm',valueOnly=TRUE))/2,
  y=height-8-grid::convertHeight(ComplexHeatmap:::height(legends),'mm',valueOnly=TRUE)/2,
  w=grid::convertWidth(ComplexHeatmap:::width(legends),'mm',valueOnly=TRUE),
  h=grid::convertHeight(ComplexHeatmap:::height(legends),'mm',valueOnly=TRUE))
 grid::grid.force(redraw=FALSE)
 for(nm in grid::grid.ls(print=FALSE,recursive=FALSE,viewports=FALSE)$name) {
  g<-grid::grid.get(nm,strict=TRUE);bf_assert_scientific_grob_text(g);collect_grid(g)
 }
 bf_assert_scientific_text(native_text,'actual native canvas text')
 unexpected<-setdiff(native_text[nzchar(native_text)],unlist(spec$text_contract$allowed_text))
 if(length(unexpected))stop(paste('unapproved native text:',paste(unexpected,collapse=' | ')))
 if(!length(native_sizes)||any(!is.finite(native_sizes))||min(native_sizes)<6.5)stop('native text below final size minimum')
 chars<-unique(unlist(strsplit(paste(native_text,collapse=''),'',fixed=TRUE)))
 if(any(systemfonts::glyph_info(chars,path=font$path,index=font$index)$index==0))stop('missing native font glyph')
 stopifnot(identical(as.integer(orders),seq_len(144)),all(vapply(row_orders,identical,logical(1),seq_len(12))),
  audit$cells==1728L,audit$events==424L,identical(as.integer(audit$event_types),as.integer(expected_type_counts)))
 boxes<-as.data.frame(do.call(rbind,list(data=merge_box(data_boxes),labels=merge_box(label_boxes),legend=legend_box)))
 boxes$id<-rownames(boxes);boxes<-boxes[,c('id','x','y','w','h')];bf_check_boxes(boxes,width,height)
 list(text=unique(native_text),sizes=native_sizes,heatmap_cells=cells,boxes=boxes,native_viewports_mm=data_boxes,
  native_sample_order=colnames(mat)[orders],native_gene_order=rownames(mat),native_cells_drawn=audit$cells,
  native_event_count=audit$events,native_event_type_counts=audit$event_types)
}
pdf_begin<-function(path) {
 if(!nzchar(Sys.which('gs')))stop('Ghostscript is required for embedded Arial PDF')
 grDevices::pdf(path,width=width/25.4,height=height/25.4,family=font$family,bg='white',useDingbats=FALSE,paper='special')
}
run_device<-function(path,type) {
 if(type=='png')ragg::agg_png(path,width=width,height=height,units='mm',res=600,background='white')
 else if(type=='pdf')pdf_begin(path)
 else svglite::svglite(path,width=width/25.4,height=height/25.4,bg='white',system_fonts=list(sans=font$family))
 ok<-FALSE;on.exit({grDevices::dev.off();if(!ok)unlink(path)},add=TRUE)
 value<-draw_native();ok<-TRUE;value
}
png_path<-file.path(work,'oncoprint-simulated.png')
pdf_path<-file.path(root,'results/figures/oncoprint-simulated.pdf')
svg_path<-file.path(work,'oncoprint-simulated-qa.svg')
exported<-run_device(png_path,'png');pdf_export<-run_device(pdf_path,'pdf');svg_export<-run_device(svg_path,'svg')
embedded<-tempfile(tmpdir=dirname(pdf_path),fileext='.pdf')
grDevices::embedFonts(pdf_path,outfile=embedded,fontpaths=dirname(font$path),
 options=c(paste0('-dDEVICEWIDTHPOINTS=',width*72/25.4),
  paste0('-dDEVICEHEIGHTPOINTS=',height*72/25.4),'-dFIXEDMEDIA'))
stopifnot(file.exists(embedded),file.info(embedded)$size>0,file.copy(embedded,pdf_path,overwrite=TRUE));unlink(embedded)
pages<-system2(Sys.which('gs'),shQuote(c('-q','-dNODISPLAY','-dNOSAFER',paste0('-sBFFile=',normalizePath(pdf_path)),
 '-c','BFFile (r) file runpdfbegin pdfpagecount = quit')),stdout=TRUE,stderr=TRUE)
if(!identical(tail(trimws(pages),1),'1'))stop('standalone figure PDF must contain exactly one page')
if(!identical(before,lapply(sources,bound)))stop('bound input changed during native render')
auth<-jsonlite::fromJSON(authorization,simplifyVector=FALSE);marker<-paste0(authorization,'.consumed')
if(!file.exists(marker)||trimws(readLines(marker,warn=FALSE)[1])!=auth$authorization_id)stop('missing authorization consumption')
receipt<-list(schema_version=1,status='PASS',backend='R',renderer='ComplexHeatmap',artifact=bound(png_path),sources=before,
 authorization_consumption=list(consumed=TRUE,authorization_id=auth$authorization_id,marker=bound(marker),
  authorization_file=bound(authorization),preparation_receipt=auth$bound$receipt),font=c(bound(font$path),list(family=font$family)),
 checks=list(font=TRUE,text_allowlist=TRUE,scientific_text_only=TRUE,footer_free=TRUE,layout=TRUE,target_size=TRUE,cell_geometry=TRUE),
 heatmap_cells=exported$heatmap_cells,heatmap_cell_policy_id='heatmap-cells-v1',rendered_text=as.list(exported$text),
 text_policy_id='scientific-content-only-v1',footer_policy_id='no-canvas-footer-v1',
 target_min_text_pt=min(exported$sizes),min_text_pt=6.5,target_width_mm=width,
 target_size=list(width_mm=width,height_mm=height,size_class='double-column',size_basis='final_physical_output'),
 device=list(width_mm=width,height_mm=height,dpi=600),boxes=exported$boxes,
 scope='Actual native final-device text/font/size/body measurements; separate final PNG/PDF review required.')
write_json(receipt,paste0(png_path,'.render.json'))
for(type in c('pdf','svg')) {
 path<-if(type=='pdf')pdf_path else svg_path;value<-if(type=='pdf')pdf_export else svg_export
 write_json(list(artifact=bound(path),source_png=bound(png_path),backend='R',rendered_text=as.list(value$text),
  minimum_text_pt=min(value$sizes),heatmap_cells=value$heatmap_cells,
  scope='Fresh native redraw and actual body measurements; separate final visual review required.'),paste0(path,'.export.json'))
}
metrics<-c(exported,list(scope='Explicitly simulated fixed-table teaching replay; not original study reproduction',
 counts=list(tumours=144,genes=12,all_cells=1728,events=424,multi_event_cells=56,zero_event_tumours=13),
 frequency_denominator=144,frequency_label='All tumours (%)',frequency_repeated_identically_per_block=TRUE,
 geometry=list(canvas_mm=c(width,height),minimum_font_pt=min(exported$sizes),cell_mode='square',block_count=3),
 source_files=before,artifacts=list(png=bound(png_path),pdf=bound(pdf_path),svg=bound(svg_path)),
 render_receipt=bound(paste0(png_path,'.render.json')),CP4='PENDING_INDEPENDENT_REVIEW'))
write_json(metrics,file.path(root,'evidence/render-metrics.json'))
writeLines(capture.output(sessionInfo()),file.path(root,'data/metadata/render-sessionInfo.txt'))
writeLines(capture.output(font),file.path(root,'data/metadata/resolved-font.txt'))
cat('ONCOPRINT_RENDERED_PENDING_VISUAL_REVIEW\n',png_path,'\n',pdf_path,'\n',svg_path,'\n')
