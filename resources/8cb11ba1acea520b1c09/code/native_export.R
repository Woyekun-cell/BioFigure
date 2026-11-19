# Native R export follows the existing portable renderer's authorization/text audit.
suppressPackageStartupMessages({library(grid);library(jsonlite)})
B<-normalizePath(commandArgs(TRUE)[1]);auth_path<-normalizePath(commandArgs(TRUE)[2]);S<-normalizePath(Sys.getenv('BIOFIGURE_ROOT'));D<-dirname(B)
source(file.path(S,'scripts/figure_style.R'));font<-bf_font('Arial');bf_complexheatmap_font(font);spec_path<-file.path(B,'design-spec.yaml');spec<-yaml::read_yaml(spec_path);ww<-spec$output_size$width_mm;hh<-spec$output_size$height_mm
allowed<-unlist(spec$text_contract$allowed_text);sources<-c(spec_path,file.path(B,'render.R'),file.path(D,'native_export.R'),file.path(S,'scripts/figure_style.R'),file.path(B,'input.csv'),file.path(B,'data-origin.json'),file.path(B,'source-lock.json'),sort(enc2utf8(list.files(file.path(B,'source'),full.names=TRUE)),method='radix'),if(file.exists(file.path(B,'matrices.rds')))file.path(B,'matrices.rds'),if(file.exists(file.path(B,'statistics.csv')))file.path(B,'statistics.csv'),if(file.exists(file.path(B,'statistics.json')))file.path(B,'statistics.json'))
bound<-function(p)list(path=normalizePath(p,mustWork=TRUE),sha256=digest::digest(file=p,algo='sha256'))
gp<-function(...)gpar(fontfamily='Arial',fontsize=7,...)
metrics<-list();native_text<-character();native_sizes<-numeric()
collect_grid<-function(g,inherited=gp()){
 pg<-inherited;for(k in names(g$gp))pg[[k]]<-g$gp[[k]]
 if(inherits(g,'text')&&length(g$label)){
  if(is.expression(g$label))stop('unexpected mathematical font; declare scientific glyph contract')
  if(is.null(pg$fontfamily)||any(pg$fontfamily!='Arial'))stop('native font inheritance mismatch')
  native_text<<-c(native_text,as.character(g$label));native_sizes<<-c(native_sizes,pg$fontsize)
 }
 for(ch in c(g$grobs,as.list(g$children)))collect_grid(ch,pg)
}
audit_grid<-function(){grid.force(redraw=FALSE);for(n in grid.ls(print=FALSE,recursive=FALSE,viewports=FALSE)$name){g<-grid.get(n,strict=TRUE);bf_assert_scientific_grob_text(g);collect_grid(g)}}
export_native<-function(draw,renderer){
 args<-c(file.path(S,'scripts/authorize_render.py'),'--design-spec',spec_path,'--output',auth_path,'--consume',unlist(lapply(sources[sources!=spec_path],function(x)c('--source',x))))
 stopifnot(system2(Sys.getenv('PYTHON','python3'),shQuote(args))==0L)
 before<-lapply(sources,bound);bf_validate_publication_size(ww,hh,'custom',spec$output_size$size_rationale$override_basis);bf_assert_scientific_text(allowed)
 outputs<-list()
 for(type in c('png','pdf')){
  native_text<<-character();native_sizes<<-numeric();metrics<<-list();text_log<-new.env();text_log$labels<-character();text_log$sizes<-numeric()
  assign('.bf_current_native_text',text_log,envir=.GlobalEnv)
  trace('text.default',where=asNamespace('graphics'),print=FALSE,tracer=quote({.z<-get('.bf_current_native_text',envir=.GlobalEnv);if(length(labels)){.fam<-if(!exists('family',inherits=FALSE)||is.null(family))par('family')else family;if(any(.fam!='Arial'))stop('base font mismatch');.z$labels<-c(.z$labels,as.character(labels));.z$sizes<-c(.z$sizes,par('ps')*if(is.null(cex))par('cex')else cex)}}))
  path<-file.path(B,paste0('figure.',type));if(type=='png')ragg::agg_png(path,width=ww,height=hh,units='mm',res=450,background='white')else bf_pdf_open(path,ww,hh,font)
  if(renderer!='circlize')grid.newpage();draw();audit_grid();dev.off();untrace('text.default',where=asNamespace('graphics'));rm('.bf_current_native_text',envir=.GlobalEnv)
  native_text<-c(native_text,text_log$labels);native_sizes<-c(native_sizes,text_log$sizes);native_text<-unique(native_text[nzchar(native_text)])
  bf_assert_scientific_text(native_text,'actual native canvas');unexpected<-setdiff(native_text,allowed)
  write_json(list(text=native_text,sizes_pt=native_sizes,unexpected=unexpected),file.path(B,paste0(type,'-text-audit.json')),pretty=TRUE,auto_unbox=TRUE,digits=NA)
  if(length(unexpected))stop('unapproved text: ',paste(unexpected,collapse=' | '))
  stopifnot(length(native_sizes)>0,all(is.finite(native_sizes)),min(native_sizes)>=6.99)
  chars<-unique(unlist(strsplit(paste(native_text,collapse=''),'',fixed=TRUE)));chars<-setdiff(chars,c('\n','\r','\t'));stopifnot(all(systemfonts::glyph_info(chars,path=font$path,index=font$index)$index!=0))
  outputs[[type]]<-list(text=native_text,sizes_pt=native_sizes,heatmap_cells=metrics)
  if(type=='pdf')bf_pdf_finalize(path,font,ww,hh)
 }
 stopifnot(identical(before,lapply(sources,bound)));auth<-fromJSON(auth_path,simplifyVector=FALSE);marker<-paste0(auth_path,'.consumed');stopifnot(file.exists(marker),trimws(readLines(marker,warn=FALSE)[1])==auth$authorization_id)
 png<-file.path(B,'figure.png');receipt<-list(schema_version=1,status='PASS',backend='R',renderer=renderer,artifact=bound(png),sources=before,authorization_consumption=list(consumed=TRUE,authorization_id=auth$authorization_id,marker=bound(marker),authorization_file=bound(auth_path),preparation_receipt=auth$bound$receipt),font=c(bound(font$path),list(family='Arial')),checks=list(font=TRUE,text_allowlist=TRUE,scientific_text_only=TRUE,footer_free=TRUE,layout=TRUE,target_size=TRUE,cell_geometry=length(outputs$png$heatmap_cells)>0),heatmap_cells=outputs$png$heatmap_cells,heatmap_cell_policy_id='heatmap-cells-v1',rendered_text=as.list(outputs$png$text),text_policy_id='scientific-content-only-v1',footer_policy_id='no-canvas-footer-v1',target_min_text_pt=min(outputs$png$sizes_pt),min_text_pt=7,target_width_mm=ww,target_size=list(width_mm=ww,height_mm=hh,size_class='custom',size_basis='final_physical_output',override_basis=spec$output_size$size_rationale$override_basis),device=list(width_mm=ww,height_mm=hh,dpi=450),scope='Executed native authorization, font, text and geometry checks; not aesthetic acceptance or complete workflow certification')
 write_json(receipt,paste0(png,'.render.json'),auto_unbox=TRUE,pretty=TRUE,digits=NA)
 write_json(list(canvas_mm=c(ww,hh),font='Arial',by_device=outputs,footer_absent=TRUE,title_absent=TRUE),file.path(B,'geometry.json'),pretty=TRUE,auto_unbox=TRUE,digits=NA)
 writeLines(capture.output(sessionInfo()),file.path(B,'environment.txt'));cat('NATIVE_RENDERED_PENDING_VISUAL_REVIEW\n')
}
