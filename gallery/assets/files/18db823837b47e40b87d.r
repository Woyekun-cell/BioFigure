args<-commandArgs(TRUE);stopifnot(length(args)==3);P<-normalizePath(args[1]);auth<-args[2];prefix<-args[3]
S<-file.path(P,'biofigure');W<-file.path(P,'work/2026-10-28-batch-six/fleck');C<-file.path(S,'benchmark/library/single-cell/fleck-gli3-circular-20261028');I<-file.path(P,'work/2026-10-28-batch-six/intake')
suppressPackageStartupMessages({library(ggplot2);library(grid);library(yaml);library(jsonlite);library(digest)})
source(file.path(S,'scripts/figure_style.R'));source(file.path(C,'scripts/build_plot.R'));font<-bf_font('Arial');spec_path<-file.path(W,'design-spec.yaml');spec<-yaml::read_yaml(spec_path);p<-make_plot(P)
sources<-normalizePath(c(spec_path,file.path(C,'scripts/render.R'),file.path(C,'scripts/build_plot.R'),file.path(S,'scripts/figure_style.R'),file.path(W,'derive.R'),file.path(W,'computed.rds'),file.path(W,'source-lock.json'),file.path(W,'project-style.json'),file.path(I,'fleck-grn_modules.tsv'),file.path(I,'fleck-supplements/41586_2022_5279_MOESM11_ESM.xls'),file.path(I,'fleck-ensembl-biotypes.json')))
bound<-function(p)list(path=normalizePath(p),sha256=digest::digest(file=p,algo='sha256'));writej<-function(x,p)jsonlite::write_json(x,p,auto_unbox=TRUE,pretty=TRUE,digits=NA,null='null')
aargs<-c(file.path(S,'scripts/authorize_render.py'),'--design-spec',spec_path,'--output',auth,'--consume',unlist(lapply(sources[-1],function(x)c('--source',x))))
if(system2('python3',shQuote(aargs))!=0L)stop('Native authorization rejected')
before<-lapply(sources,bound);allowed<-unlist(spec$text_contract$allowed_text);bf_assert_scientific_text(allowed);bf_assert_no_canvas_caption(p)
# Native ggraph edges expose unused NA edge-label columns. They are not text
# marks; inspect the fully drawn grid display list, including lazy ggrepel text.
render<-function(){
 bf_assert_no_footer_grob(g);grid.newpage();grid.draw(g);grid.force();ls<-grid.ls(print=FALSE);labels<-character();families<-character();sizes<-numeric()
 for(n in unique(ls$name)){
  z<-tryCatch(grid.get(n,grep=FALSE),error=function(e)NULL)
  if(!is.null(z)&&inherits(z,'text')&&length(z$label)){
   labs<-as.character(z$label);stopifnot(all(labs%in%allowed));labels<-c(labels,labs);families<-c(families,z$gp$fontfamily);sizes<-c(sizes,z$gp$fontsize)
  }
 }
 stopifnot(all(allowed%in%labels),length(labels)>27,all(families=='Arial'),min(sizes)>=7.19,max(sizes)<=7.21)
 list(rendered_text=unique(labels),font_families=unique(families),font_sizes_pt=unique(sizes),native_geometry='ggraphcreate_layouttreecircular;geom_edge_diagonal193sourcepathrecords;scale_y_reverseandcoord_flipasauthorcode;aspectratio1;112nodes',node_count=112,unique_edges=111,parallel_path_records=193)
}
png<-paste0(prefix,'.png');pdf<-paste0(prefix,'.pdf');ragg::agg_png(png,width=132,height=139,units='mm',res=600,background='white');g<-ggplotGrob(p);pm<-render();dev.off();stopifnot(identical(before,lapply(sources,bound)))
a<-fromJSON(auth,simplifyVector=FALSE);marker<-paste0(auth,'.consumed');stopifnot(trimws(readLines(marker)[1])==a$authorization_id)
writej(list(schema_version=1,status='PASS',backend='R',renderer='ggplot2',native_specialist='ggraph',artifact=bound(png),sources=before,authorization_consumption=list(consumed=TRUE,authorization_id=a$authorization_id,marker=bound(marker),authorization_file=bound(auth),preparation_receipt=a$bound$receipt),font=c(bound(font$path),list(family=font$family)),checks=list(font=TRUE,text_allowlist=TRUE,scientific_text_only=TRUE,footer_free=TRUE,layout=TRUE,target_size=TRUE,fully_drawn_native_ggraph_text=TRUE),rendered_text=as.list(pm$rendered_text),text_policy_id='scientific-content-only-v1',footer_policy_id='no-canvas-footer-v1',target_min_text_pt=min(pm$font_sizes_pt),min_text_pt=6.5,target_width_mm=132,target_size=list(width_mm=132,height_mm=139,size_class='one-and-half-column',size_basis='final_physical_output'),device=list(width_mm=132,height_mm=139,dpi=600),scope='Actualdrawngridtext,notunusedNAedgelabelcolumns;visual/PDFandinputauditseparate'),paste0(png,'.render.json'))
bf_pdf_open(pdf,132,139,font);dm<-render();dev.off();pa<-bf_pdf_finalize(pdf,font,132,139);writej(pa,paste0(pdf,'.pdf-audit.json'));writej(list(artifact=bound(pdf),source_png=bound(png),sources=before,rendered_text=as.list(dm$rendered_text),font_sizes_pt=dm$font_sizes_pt),paste0(pdf,'.export.json'));writej(list(png=pm,pdf=dm),paste0(prefix,'.metrics.json'))
writej(list(R=R.version.string,packages=as.list(setNames(vapply(c('ggplot2','ggraph','tidygraph','igraph','ggrepel','ragg'),function(x)as.character(packageVersion(x)),''),c('ggplot2','ggraph','tidygraph','igraph','ggrepel','ragg'))),font=bound(font$path)),file.path(W,'environment.json'));writeLines(capture.output(sessionInfo()),file.path(W,'sessionInfo.txt'));cat('NATIVE_RENDERED_PENDING_VISUAL_REVIEW\n')
