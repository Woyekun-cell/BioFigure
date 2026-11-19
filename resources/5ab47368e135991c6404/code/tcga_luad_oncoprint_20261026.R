# Source-bound official TCGA LUAD tutorial reconstruction; no new clinical inference.
args<-commandArgs(TRUE)
if(length(args)!=1L)stop('Supply BioFigure project root.')
P<-normalizePath(args[1]);S<-file.path(P,'biofigure');W<-file.path(P,'work/2026-10-26-two-complex-biofigure-benchmark/tcga-oncoprint');D<-file.path(P,'data/raw/tcga_luad_oncoprint_20261026')
source(file.path(S,'scripts/figure_style.R'))
suppressPackageStartupMessages(library(ComplexHeatmap));library(grid)
font<-bf_font('Arial');spec_path<-file.path(W,'design-spec.yaml');spec<-yaml::read_yaml(spec_path)
gp<-function(size=6.5,...)gpar(fontfamily=font$family,fontsize=size,...)
O<-file.path(P,'results/plot_data/tcga_luad_oncoprint_20261026');F<-file.path(P,'results/figures/tcga_luad_oncoprint_20261026')
input_files<-paste0(O,c('_matrix.csv','_genes.csv','_samples.csv','_events.csv','_excluded.csv'))
d<-read.csv(input_files[1],check.names=FALSE,stringsAsFactors=FALSE);mat<-as.matrix(d[,-1]);rownames(mat)<-d$Gene
meta<-read.csv(input_files[3],stringsAsFactors=FALSE);genes<-read.csv(input_files[2],stringsAsFactors=FALSE);events<-read.csv(input_files[4],stringsAsFactors=FALSE)
get_type<-function(x){v<-trimws(strsplit(x,'[;:,|]')[[1]]);v[nzchar(v)]}
stopifnot(identical(dim(mat),c(22L,121L)),identical(rownames(mat),genes$Gene),identical(colnames(mat),meta$Sample),nrow(events)==237L,
 all(table(events$Event)[c('AMP','HOMDEL','MUT')]==c(80L,30L,127L)),all(genes$denominator==172L),
 genes$altered_samples[genes$Gene=='KRAS']==55L,genes$altered_samples[genes$Gene=='BRAF']==18L,
 max(abs(genes$pct-100*genes$altered_samples/172))<1e-12,
 identical(genes$pct_label,sprintf('%.0f%%',100*genes$altered_samples/172)))
for(i in seq_len(nrow(mat)))for(j in seq_len(ncol(mat))){v<-get_type(mat[i,j]);obs<-events$Event[events$Gene==rownames(mat)[i]&events$Sample==colnames(mat)[j]];stopifnot(setequal(v,obs))}
colour<-c(HOMDEL='#0000FF',AMP='#FF0000',MUT='#008000');cell<-2.3;BW<-183;BH<-164
style_path<-file.path(W,'project-style.yaml');source_lock<-file.path(W,'source-lock.json')
script<-normalizePath(file.path(P,'scripts/figures/tcga_luad_oncoprint_20261026.R'))
sources<-c(script,file.path(S,'scripts/figure_style.R'),spec_path,style_path,input_files,file.path(W,'input-qc.json'),source_lock,
 file.path(W,'prepare_inputs.R'),file.path(W,'prepare_spec.py'),file.path(D,c('tcga_lung_adenocarcinoma_provisional_ras_raf_mek_jnk_signalling.txt','sample_order.txt','07-oncoprint.Rmd','official-oncoprint-remove-empty.png')))
bound<-function(p)list(path=normalizePath(p,mustWork=TRUE),sha256=digest::digest(file=p,algo='sha256'))
write_json<-function(x,p)jsonlite::write_json(x,p,pretty=TRUE,auto_unbox=TRUE,digits=NA,null='null')
auth_path<-file.path(W,paste0('authorization-',format(Sys.time(),'%Y%m%d%H%M%S'),'-',Sys.getpid(),'.json'))
source_args<-unlist(lapply(sources[sources!=spec_path],function(p)c('--source',p)))
python<-Sys.getenv('PYTHON','python3');t<-proc.time()[['elapsed']]
a<-c(file.path(S,'scripts/authorize_render.py'),'--receipt',file.path(W,'preparation-receipt.json'),'--design-spec',spec_path,'--output',auth_path,source_args)
if(system2(python,shQuote(a))!=0L)stop('Fresh CP2 authorization failed.')
a<-c(file.path(S,'scripts/authorize_render.py'),'--design-spec',spec_path,'--output',auth_path,'--consume',source_args)
if(system2(python,shQuote(a))!=0L)stop('Single-use authorization consumption failed.')
auth_s<-proc.time()[['elapsed']]-t;before<-lapply(sources,bound);allowed<-unlist(spec$text_contract$allowed_text)
bf_validate_publication_size(BW,BH,'double-column')
boxes<-data.frame(id=c('block_a','block_b','legend'),x=c(1,1,4),y=c(90,16,2),w=c(181,181,175),h=c(72,72,10));bf_check_boxes(boxes,BW,BH)
alter_fun<-list(background=function(x,y,w,h)grid.rect(x,y,w-unit(2,'pt'),h-unit(2,'pt'),gp=gpar(fill='#CCCCCC',col=NA)),
 HOMDEL=function(x,y,w,h)grid.rect(x,y,w-unit(2,'pt'),h-unit(2,'pt'),gp=gpar(fill=colour['HOMDEL'],col=NA)),
 AMP=function(x,y,w,h)grid.rect(x,y,w-unit(2,'pt'),h-unit(2,'pt'),gp=gpar(fill=colour['AMP'],col=NA)),
 MUT=function(x,y,w,h)grid.rect(x,y,w-unit(2,'pt'),h*.33,gp=gpar(fill=colour['MUT'],col=NA)))
make_ht<-function(block) {
 idx<-which(meta$block==block);m<-mat[,idx,drop=FALSE];nm<-paste0('onco_',block)
 pct<-rowAnnotation(`% altered`=anno_text(genes$pct_label,gp=gp(),just='right',location=unit(.95,'npc'),width=unit(7.5,'mm')),
  show_annotation_name=TRUE,annotation_name_side='top',annotation_name_rot=0,annotation_name_gp=gp(),annotation_name_offset=unit(1.5,'mm'))
 top<-HeatmapAnnotation(Events=anno_oncoprint_barplot(border=FALSE,height=unit(9,'mm'),ylim=c(0,15),
  axis_param=list(side='left',at=c(0,5,10,15),labels=c('0','5','10','15'),gp=gp())),show_annotation_name=FALSE)
 right<-rowAnnotation(Events=anno_oncoprint_barplot(border=FALSE,width=unit(11,'mm'),ylim=c(0,80),
  axis_param=list(side='top',at=c(0,40,80),labels=c('0','40','80'),gp=gp())),
  annotation_name_side='bottom',annotation_name_rot=0,annotation_name_gp=gp(),annotation_name_offset=unit(1.2,'mm'))
 oncoPrint(m,name=nm,get_type=get_type,alter_fun=alter_fun,alter_fun_is_vectorized=TRUE,col=colour,
  width=unit(ncol(m)*cell,'mm'),height=unit(nrow(m)*cell,'mm'),row_order=seq_len(nrow(m)),column_order=seq_len(ncol(m)),
  remove_empty_columns=FALSE,remove_empty_rows=FALSE,
  show_pct=FALSE,show_row_names=TRUE,row_names_side='left',row_names_gp=gp(),row_names_max_width=unit(13,'mm'),
  show_column_names=FALSE,top_annotation=top,left_annotation=pct,right_annotation=right,
  column_title=if(block=='a')'Cases 1-61'else'Cases 62-121',column_title_gp=gp(7.5),
  show_heatmap_legend=FALSE,use_raster=FALSE)
}
run_device<-function(path,kind) {
 if(kind=='png')ragg::agg_png(path,width=BW,height=BH,units='mm',res=400,background='white')else bf_pdf_open(path,BW,BH,font)
 ok<-FALSE;on.exit({dev.off();if(!ok)unlink(path)},add=TRUE)
 grid.newpage();pushViewport(viewport(name='source_figure',gp=gp()))
 cells<-list();body_boxes<-list();orders<-list()
 for(b in c('a','b')) {
  pushViewport(viewport(x=unit(1,'mm'),y=unit(if(b=='a') 90 else 16,'mm'),width=unit(181-ifelse(b=='b',cell,0),'mm'),height=unit(72,'mm'),just=c('left','bottom'),name=paste0('block_',b)))
  bf_complexheatmap_font(font);h<-draw(make_ht(b),newpage=FALSE,padding=unit(c(1,0,1,0),'mm'),show_heatmap_legend=FALSE,show_annotation_legend=FALSE)
  nm<-paste0('onco_',b);cells<-c(cells,bf_complexheatmap_cell_metrics(h,nm))
  store<-new.env();decorate_heatmap_body(nm,{lo<-deviceLoc(unit(0,'npc'),unit(0,'npc'),valueOnly=TRUE);hi<-deviceLoc(unit(1,'npc'),unit(1,'npc'),valueOnly=TRUE);store$box<-list(x=lo$x*25.4,y=lo$y*25.4,w=(hi$x-lo$x)*25.4,h=(hi$y-lo$y)*25.4)},envir=environment());body_boxes[[nm]]<-store$box
  orders[[nm]]<-list(genes=genes$Gene[unlist(row_order(h))],samples=colnames(mat)[meta$block==b][unlist(column_order(h))]);upViewport()
 }
 lg<-Legend(title='Alterations',labels=c('Deep deletion','Amplification','Mutation'),type='grid',legend_gp=gpar(fill=unname(colour),col=NA),nrow=1,
  title_gp=gp(7),labels_gp=gp(7),grid_width=unit(3,'mm'),grid_height=unit(3,'mm'),gap=unit(4,'mm'),title_position='leftcenter')
 lw<-convertWidth(ComplexHeatmap:::width(lg),'mm',valueOnly=TRUE);lh<-convertHeight(ComplexHeatmap:::height(lg),'mm',valueOnly=TRUE)
 stopifnot(lw<175,lh<10);draw(lg,x=unit(BW/2,'mm'),y=unit(7,'mm'),just=c('center','center'))
 grid.force(redraw=FALSE);texts<-character();sizes<-numeric()
 collect<-function(g,inherited=gp()) {
  gpar<-inherited;for(k in names(g$gp))gpar[[k]]<-g$gp[[k]]
  if(inherits(g,'text')&&length(g$label)) {
   if(is.expression(g$label))stop('Math text requires separate review.')
   if(is.null(gpar$fontfamily)||any(gpar$fontfamily!=font$family))stop('Native text font fallback.')
   texts<<-c(texts,as.character(g$label));sizes<<-c(sizes,gpar$fontsize)
  }
  for(child in c(g$grobs,as.list(g$children)))collect(child,gpar)
 }
 for(n in grid.ls(print=FALSE,recursive=FALSE,viewports=FALSE)$name){g<-grid.get(n,strict=TRUE);bf_assert_scientific_grob_text(g);collect(g)}
 bf_assert_scientific_text(texts);unexpected<-setdiff(texts[nzchar(texts)],allowed)
 if(length(unexpected))stop(paste('Actual unapproved text:',paste(unexpected,collapse=' | ')))
 if(!length(sizes)||min(sizes)<6.5||max(sizes)>6.5*1.6)stop('Actual typography violates the bound font range.')
 chars<-unique(unlist(strsplit(paste(texts,collapse=''),'',fixed=TRUE)));if(any(systemfonts::glyph_info(chars,path=font$path,index=font$index)$index==0))stop('Missing Arial glyph.')
 stopifnot(all(vapply(cells,function(x)abs(x$cell_width_mm-x$cell_height_mm)/x$cell_width_mm<.01,logical(1))))
 ok<-TRUE;list(text=unique(texts),sizes=sizes,cells=cells,body_boxes=body_boxes,legend_box=list(x=(BW-lw)/2,y=7-lh/2,w=lw,h=lh),orders=orders)
}
t<-proc.time()[['elapsed']];png_result<-run_device(paste0(F,'.png'),'png');png_s<-proc.time()[['elapsed']]-t
if(!identical(before,lapply(sources,bound)))stop('Source changed during rendering.')
auth<-jsonlite::fromJSON(auth_path,simplifyVector=FALSE);marker<-paste0(auth_path,'.consumed');stopifnot(trimws(readLines(marker)[1])==auth$authorization_id)
receipt<-list(schema_version=1,status='PASS',backend='R',renderer='ComplexHeatmap',artifact=bound(paste0(F,'.png')),sources=before,
 authorization_consumption=list(consumed=TRUE,authorization_id=auth$authorization_id,marker=bound(marker),authorization_file=bound(auth_path),preparation_receipt=auth$bound$receipt),
 font=c(bound(font$path),list(family=font$family)),checks=list(font=TRUE,text_allowlist=TRUE,scientific_text_only=TRUE,footer_free=TRUE,layout=TRUE,target_size=TRUE,cell_geometry=TRUE),
 rendered_text=as.list(png_result$text),text_policy_id='scientific-content-only-v1',footer_policy_id='no-canvas-footer-v1',heatmap_cells=png_result$cells,heatmap_cell_policy_id='heatmap-cells-v1',target_min_text_pt=min(png_result$sizes),min_text_pt=6.5,target_width_mm=BW,
 target_size=list(width_mm=BW,height_mm=BH,size_class='double-column',size_basis='final_physical_output'),device=list(width_mm=BW,height_mm=BH,dpi=400),boxes=boxes,scope='Current technical checks executed; source/layout adaptation and actual PNG/PDF visual review still required.')
write_json(receipt,paste0(F,'.png.render.json'));write_json(png_result,file.path(W,'png-layout-metrics.json'));cat('PNG_READY ',paste0(F,'.png'),'\n');flush.console()
t<-proc.time()[['elapsed']];pdf_result<-run_device(paste0(F,'.pdf'),'pdf');pdf_s<-proc.time()[['elapsed']]-t
t<-proc.time()[['elapsed']];pdf_audit<-bf_pdf_finalize(paste0(F,'.pdf'),font,BW,BH);pdf_audit_s<-proc.time()[['elapsed']]-t
write_json(pdf_audit,paste0(F,'.pdf.pdf-audit.json'));write_json(c(list(artifact=bound(paste0(F,'.pdf')),source_png=bound(paste0(F,'.png')),backend='R'),pdf_result),paste0(F,'.pdf.export.json'));write_json(pdf_result,file.path(W,'pdf-layout-metrics.json'))
write_json(list(status='RENDERED_PENDING_VISUAL_REVIEW',png=bound(paste0(F,'.png')),pdf=bound(paste0(F,'.pdf')),authorization=auth_path,global_denominator=172,source='Official TCGA LUAD ComplexHeatmap §7.2.1',layout_adaptation='two consecutive source-order blocks61/60',timing=list(authorization_R_seconds=auth_s,png_render_R_seconds=png_s,pdf_export_R_seconds=pdf_s,pdf_audit_R_seconds=pdf_audit_s)),file.path(W,'run.json'))
capture.output(sessionInfo(),file=file.path(W,'render-sessionInfo.txt'));cat('TCGA_RENDERED_PENDING_VISUAL_REVIEW\n')
