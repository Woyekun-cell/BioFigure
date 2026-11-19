args<-commandArgs(TRUE);P<-normalizePath(args[1]);mid<-args[2];S<-file.path(P,'biofigure');B<-file.path(P,'work/2026-10-29-awesome-map-replacements');W<-file.path(B,mid)
source(file.path(S,'scripts/figure_style.R'));library(ggplot2);font<-bf_font('Arial');sp<-file.path(W,'design-spec.yaml');spec<-yaml::read_yaml(sp);qc<-jsonlite::fromJSON(file.path(W,'input-qc.json'));p<-readRDS(file.path(W,'render-object.rds'));F<-file.path(P,'results/figures',qc$stem)
sources<-c(file.path(P,'scripts/figures/render_asf_map_replacements_20261029.R'),sp,file.path(B,c('prepare_plots.R','prepare_grobs.R','prepare_specs.py')),file.path(W,c('render-object.rds','composed-vector-grob.rds','text-manifest.json','input-qc.json')),file.path(S,c('scripts/figure_style.R','palettes/palette-library.yaml','palettes/bright-luts.csv','palettes/continuous-luts.csv')),file.path(P,'results/plot_data',if(mid=='ASF-V03')'asf03_neon_plots_20261029.csv'else'asf13_pv_production_ratios_20261029.csv'))
# palette-library.yaml is hash-bound by the authorization but excluded from the renderer's single-Spec YAML list.
# Bind the palette metadata through a JSON byte-hash manifest instead.
sources<-sources[basename(sources)!='palette-library.yaml']
lock<-jsonlite::fromJSON(file.path(W,'source-review-receipt.json'));sources<-c(sources,file.path(W,'source-review-receipt.json'),lock$source_files$path)
if(mid=='ASF-V03')sources<-c(sources,file.path(W,c('NEON d15N data.csv','wc2.1_10m_prec.zip')),file.path(P,'results/plot_data',c('asf03_neon_plots_20261029.csv','asf03_neon_site_labels_20261029.csv','asf03_worldclim_annual_precip_20261029.tif')))
if(mid=='ASF-V03')sources<-c(sources,list.files(file.path(P,'work/2026-10-29-maps-and-umap/sources/REPRO-058/data/us_shapefile'),pattern='cb_2016_us_state_20m\\.(shp|dbf|shx|prj)$',full.names=TRUE))
if(mid=='ASF-V13')sources<-c(sources,file.path(W,c('Data_Figures.RData','Code_Figures.R')),file.path(P,'results/plot_data',c('asf13_pv_production_ratios_20261029.csv','asf13_world_production_polygons_20261029.csv')))
bound<-function(x)list(path=normalizePath(x,mustWork=TRUE),sha256=digest::digest(file=x,algo='sha256'));wr<-function(x,f)jsonlite::write_json(x,f,auto_unbox=TRUE,pretty=TRUE,digits=NA,null='null');before<-lapply(sources,bound)
auth<-file.path(W,paste0('authorization-',Sys.getpid(),'-',format(Sys.time(),'%H%M%S'),'.json'));a<-c(file.path(S,'scripts/authorize_render.py'),'--receipt',file.path(W,'preparation-receipt.json'),'--design-spec',sp,'--output',auth,unlist(lapply(sources[sources!=sp],function(x)c('--source',x))))
if(system2('python3',shQuote(a))!=0L)stop('CP2 authorization failed')
width<-qc$width_mm;height<-qc$height_mm
legend_h<-if(mid=='ASF-V03')27 else 20;boxes<-data.frame(id=c('data','labels','legend'),x=c(1,1,1),y=c(legend_h+1,legend_h+1,1),w=c(width-2,width-2,if(mid=='ASF-V03')124 else width-2),h=c(height-legend_h-2,height-legend_h-2,legend_h-1))
t<-proc.time()[['elapsed']];bf_render_png(p,paste0(F,'.png'),font,unlist(spec$text_contract$allowed_text),width,height,width,sources,boxes,allowed_pairs='data:labels',dpi=360,min_text_pt=6.5,authorization=auth,skill_root=S,publication_size_class='double-column',size_override_basis=spec$output_size$size_rationale$override_basis);png_s<-proc.time()[['elapsed']]-t
if(!file.exists(file.path(W,'first-render.png')))file.copy(paste0(F,'.png'),file.path(W,'first-render.png'))
t<-proc.time()[['elapsed']];bf_pdf_open(paste0(F,'.pdf'),width,height,font);print(p);dev.off();pdf_s<-proc.time()[['elapsed']]-t
pa<-bf_pdf_finalize(paste0(F,'.pdf'),font,width,height);wr(pa,paste0(F,'.pdf.pdf-audit.json'));stopifnot(identical(before,lapply(sources,bound)))
wr(list(status='RENDERED_PENDING_VISUAL_REVIEW',method_id=mid,png=bound(paste0(F,'.png')),pdf=bound(paste0(F,'.pdf')),authorization=auth,timing=list(png_render_R_seconds=png_s,pdf_export_R_seconds=pdf_s),scope=qc$data_origin),file.path(W,'run.json'));capture.output(sessionInfo(),file=file.path(W,'render-sessionInfo.txt'));cat(mid,'RENDERED\n')
