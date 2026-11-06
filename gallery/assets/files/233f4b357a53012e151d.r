args<-commandArgs(TRUE);P<-normalizePath(args[1]);W<-file.path(P,'work/2026-10-29-lollipop-completion');S<-file.path(P,'biofigure');source(file.path(S,'scripts/figure_style.R'));library(ggplot2)
font<-bf_font('Arial')
for(mid in c('SCICASE-126','REPRO-021','REPRO-039','ASF-V12')){
 w<-file.path(W,mid);q<-jsonlite::fromJSON(file.path(w,'input-qc.json'));sp<-file.path(w,'design-spec.yaml');s<-yaml::read_yaml(sp);p<-readRDS(file.path(w,'render-object.rds'));F<-file.path(P,'results/figures',q$stem)
 sources<-unique(c(file.path(W,c('render.R','prepare_plots.R','prepare_grobs.R','prepare_specs.py','source-locators.json')),sp,file.path(w,c('input-qc.json','render-object.rds','composed-vector-grob.rds','text-manifest.json','source-review-receipt.json')),file.path(S,c('scripts/figure_style.R','palettes/bright-luts.csv','palettes/continuous-luts.csv')),file.path(P,'results/plot_data',q$plot_data_files),jsonlite::fromJSON(file.path(w,'source-review-receipt.json'))$source_files$path))
 auth<-file.path(w,paste0('authorization-',Sys.getpid(),'.json'));a<-c(file.path(S,'scripts/authorize_render.py'),'--receipt',file.path(w,'preparation-receipt.json'),'--design-spec',sp,'--output',auth,unlist(lapply(setdiff(sources,sp),function(f)c('--source',f))));stopifnot(system2('python3',shQuote(a))==0L)
 width<-q$width_mm;height<-q$height_mm;boxes<-data.frame(id=c('data','labels','legend'),x=c(1,1,1),y=c(1,1,1),w=c(width-2,width-2,width-2),h=c(height-2,height-2,height-2))
 bf_render_png(p,paste0(F,'.png'),font,unlist(s$text_contract$allowed_text),width,height,width,sources,boxes,allowed_pairs=c('data:labels','data:legend','labels:legend'),dpi=360,min_text_pt=7,authorization=auth,skill_root=S,publication_size_class='double-column',size_override_basis=s$output_size$size_rationale$override_basis)
 first<-file.path(w,'first-render.png');if(!file.exists(first))file.copy(paste0(F,'.png'),first)
 bf_pdf_open(paste0(F,'.pdf'),width,height,font);print(p);dev.off();audit<-bf_pdf_finalize(paste0(F,'.pdf'),font,width,height);jsonlite::write_json(audit,file.path(w,'pdf-technical-audit.json'),auto_unbox=TRUE,pretty=TRUE)
 capture.output(sessionInfo(),file=file.path(w,'render-sessionInfo.txt'));cat(mid,'RENDERED_PENDING_ACTUAL_REVIEW\n')
}
