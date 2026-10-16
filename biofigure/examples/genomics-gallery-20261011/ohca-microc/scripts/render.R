#!/usr/bin/env Rscript
# Selected original author-book Micro-C matrix + loops, native HiContacts.
# Written only after fresh preparation and validated CP2 (2026-10-11).
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==6L)
root<-normalizePath(args[1]);work<-normalizePath(args[2]);auth<-normalizePath(args[3]);tasklib<-normalizePath(args[4]);out<-normalizePath(args[5]);spec_path<-normalizePath(args[6])
.libPaths(c(tasklib,.libPaths()))
load_warnings<-character()
suppressPackageStartupMessages(withCallingHandlers({
 library(HiCExperiment);library(HiContacts);library(GenomeInfoDb);library(InteractionSet)
 library(ggplot2);library(yaml);library(jsonlite)
},warning=function(w){
 msg<-conditionMessage(w)
 if(grepl("^(multiple methods tables found for|replacing previous import)",msg)){
  load_warnings<<-c(load_warnings,msg);invokeRestart("muffleWarning")
 }
}))
skill<-normalizePath(Sys.getenv("BIOFIGURE_SKILL_ROOT"));source(file.path(skill,"scripts/figure_style.R"))
font<-bf_font("Arial");design<-read_yaml(spec_path);width<-design$output_size$width_mm;height<-design$output_size$height_mm
lock<-fromJSON(file.path(root,"data/metadata/source-lock.json"))
for(i in seq_len(nrow(lock$assets))){a<-lock$assets[i,];stopifnot(digest::digest(file=file.path(root,a$path),algo="sha256")==a$sha256)}
x<-readRDS(file.path(root,"data/raw/microC_with-loops.rds"));stopifnot(isTRUE(validObject(x,test=TRUE)))
gis<-interactions(x);all_loops<-topologicalFeatures(x,"loops")
stopifnot(length(gis)==19667L,length(regions(gis))==200L,sum(scores(x,"count"))==2103634L,identical(as.integer(HiCExperiment::resolution(x)),5000L))
ld<-as.data.frame(all_loops);keep<-ld$score>=.4 & ld$qvalue<=1e-6
overlap<-anchors(all_loops)[[1]] %over% gis & anchors(all_loops)[[2]] %over% gis
ld$source_row<-seq_len(nrow(ld));ld$keep_author_threshold<-keep;ld$visible_region<-overlap;ld$plotted<-keep&overlap
ld$x_center_bp<-ld$start1+(ld$end1-ld$start1)/2;ld$y_center_bp<-ld$start2+(ld$end2-ld$start2)/2
stopifnot(nrow(ld)==2419L,sum(keep)==1639L,sum(ld$plotted)==31L)
loops<-all_loops[keep]
d<-as.data.frame(gis);d$source_row<-seq_len(nrow(d));d$log10_balanced<-log10(d$balanced)
d$display_log10_balanced<-pmin(-1.2,pmax(-4,d$log10_balanced))
d$x_center_bp<-floor(d$end1-(d$end1-d$start1)/2);d$y_center_bp<-floor(d$end2-(d$end2-d$start2)/2)
for(folder in c("results/plot_data","results/figures","data/metadata","evidence"))dir.create(file.path(out,folder),recursive=TRUE,showWarnings=FALSE)
write_portable_csv<-function(data,path){
 connection<-file(path,open="wb");on.exit(close(connection))
 write.csv(data,connection,row.names=FALSE,eol="\n")
}
write_portable_csv(d,file.path(out,"results/plot_data/contact-bin-pairs.csv"))
write_portable_csv(ld,file.path(out,"results/plot_data/loop-annotations.csv"))
bins<-as.data.frame(regions(gis));bins$source_bin_index<-seq_len(nrow(bins))
write_portable_csv(bins,file.path(out,"results/plot_data/bin-axis.csv"))
palette<-strsplit(design$palette_semantics$balanced_log10,",",fixed=TRUE)[[1]]
options(warn=2)
p<-HiContacts::plotMatrix(x,loops=loops,limits=c(-4,-1.2),caption=FALSE,cmap=palette,rasterize=FALSE,dpi=600)
# Native geom_tile_rast defaults to unavailable system Cairo/X11 on this host.
# Rasterize the same native tile layer with the supported R/ragg device only.
stopifnot(inherits(p$layers[[1]]$geom,"GeomTile"))
native_tile_layer<-p$layers[[1]]
p$layers[[1]]<-ggrastr::rasterise(p$layers[[1]],dpi=600,dev="ragg")
# Keep the native point geometry/data/filter. Change only its outline's semantic mapping.
li<-which(vapply(p$layers,function(z)inherits(z$geom,"GeomPoint"),logical(1)))
stopifnot(length(li)==1L,nrow(p$layers[[li]]$data)==31L)
p$layers[[li]]$aes_params$colour<-NULL;p$layers[[li]]$aes_params$color<-NULL
p$layers[[li]]$mapping$colour<-aes(colour="Filtered loops")$colour
p<-p+scale_colour_manual(values=c("Filtered loops"=design$palette_semantics$filtered_loops),name=NULL)+
 labs(title="HFFc6 | Micro-C",x="chr17",y="Genomic position (Mb)",fill="Balanced frequency\n(log10)")+
 bf_theme(font,7)+theme(
  plot.title=element_text(size=8,hjust=0,margin=margin(b=1,unit="mm")),
  plot.margin=margin(2,3,2,2,unit="mm"),
  panel.border=element_rect(fill=NA,colour="#445562",linewidth=.22),
  panel.grid=element_blank(),axis.line=element_blank(),
  axis.ticks=element_line(colour="#445562",linewidth=.18),
  axis.title.y=element_text(size=7,margin=margin(r=1.2,unit="mm")),
  axis.title.x=element_text(size=7,margin=margin(b=.8,unit="mm")),
  legend.title=element_text(size=7,lineheight=1.05),legend.text=element_text(size=7),
  legend.key.height=grid::unit(3,"mm"),legend.key.width=grid::unit(3,"mm"),
  legend.spacing.y=grid::unit(3,"mm"),legend.box.spacing=grid::unit(3,"mm")
 )+
 guides(fill=guide_colourbar(order=1,title.position="top",theme=theme(legend.key.height=grid::unit(26,"mm"),legend.key.width=grid::unit(3,"mm"))),
        colour=guide_legend(order=2,override.aes=list(size=3,fill=NA)))
fs<-p$scales$get_scales("fill")
fs$breaks<-c(-4,-3,-2,-1.2)
fs$labels<-c("-4","-3","-2","-1.2")
for(axis in c("x","y")){
 axis_scale<-p$scales$get_scales(axis)
 axis_scale$breaks<-seq(62.5e6,63.5e6,.25e6)
 axis_scale$labels<-c("62.50 M","62.75 M","63.00 M","63.25 M","63.50 M")
}
built<-ggplot_build(p)
stopifnot(nrow(built$data[[1]])==39334L,nrow(built$data[[li]])==31L)
stopifnot(all(is.finite(built$data[[1]]$x)),all(is.finite(built$data[[1]]$y)))
sourcefiles<-c(spec_path,file.path(root,"scripts/render.R"),file.path(skill,"scripts/figure_style.R"),file.path(root,"data/metadata/source-lock.json"),file.path(root,lock$assets$path[!grepl("\\.ya?ml$",lock$assets$path)]))
name<-"author-book-microc-loops-recolored";png<-file.path(work,paste0(name,".png"))
boxes<-data.frame(id=c("data","labels","legend"),x=c(15,15,155),y=c(6,149,20),w=c(138,138,24),h=c(138,6,112))
receipt<-bf_render_png(p,png,font,design$text_contract$allowed_text,width,height,width,sourcefiles,boxes,
 authorization=auth,skill_root=skill,publication_size_class="double-column",min_text_pt=7,
 heading_authorization="Selected author-book HFFc6 Micro-C panel identity; user authorized recolor")
# Quartz misorients embedded rasters on this host; PDF uses author-supported
# native vector tiles and a vector colorbar. Identical native data/scale/geometry.
pdf<-file.path(out,"results/figures",paste0(name,".pdf"))
p_pdf<-p;p_pdf$layers[[1]]<-native_tile_layer
p_pdf<-p_pdf+guides(fill=guide_colourbar(display="rectangles",order=1,title.position="top",theme=theme(legend.key.height=grid::unit(26,"mm"),legend.key.width=grid::unit(3,"mm"))))
pdf_built<-ggplot_build(p_pdf)
stopifnot(identical(built$data[[1]][c("x","y","fill")],pdf_built$data[[1]][c("x","y","fill")]),identical(built$data[[li]],pdf_built$data[[li]]))
bf_pdf_open(pdf,width,height,font);print(p_pdf);invisible(dev.off())
pdf_inspection<-bf_pdf_finalize(pdf,font,width,height)
ggsave(file.path(work,paste0(name,".svg")),p,device=svglite::svglite,width=width,height=height,units="mm",bg="white")
# Inspect the actual drawn panel viewport after authorized PNG; this is a QA-only colored redraw.
ragg::agg_png(file.path(work,"layout-measurement.png"),width=width,height=height,units="mm",res=300)
grid::grid.newpage();grid::grid.draw(ggplotGrob(p));grid::grid.force()
vps<-grid::grid.ls(viewports=TRUE,grobs=FALSE,print=FALSE)$name
pv<-vps[grepl("^panel\\.[0-9]+-[0-9]+-[0-9]+-[0-9]+$",vps)]
stopifnot(length(pv)==1L);grid::seekViewport(pv[[1]])
panelw<-grid::convertWidth(grid::unit(1,"npc"),"mm",valueOnly=TRUE);panelh<-grid::convertHeight(grid::unit(1,"npc"),"mm",valueOnly=TRUE)
pos<-grid::deviceLoc(grid::unit(0,"npc"),grid::unit(0,"npc"),valueOnly=TRUE)
bbox<-list(x=pos$x*25.4,y=pos$y*25.4,w=panelw,h=panelh);invisible(dev.off())
ratio<-panelw/panelh;stopifnot(abs(ratio-1)<.05)
write_json(list(schema_version=1,units="mm",final_canvas=list(width=width,height=height),actual_data_bbox=bbox,
 source_data_bbox_pixels=c(231,73,1103,945),source_data_aspect=1,actual_inner_aspect=ratio,relative_aspect_error=abs(ratio-1),
 actual_cell_pitch_mm=panelw/200,loop_native_size_mm=3,font_sizes_pt=c(7,8),source_density_reason="Exact200bin squaregrid,31sourcefiltered circles, native 1:1 coordinate aspect; no density reduction"),
 file.path(out,"evidence/layout-metrics.json"),pretty=TRUE,auto_unbox=TRUE)
write_json(list(schema_version=1,status="AUTHOR_PROCESSED_DATA_REPLOT_QC_PASS",native_function="HiContacts::plotMatrix",
 method_id=lock$method_id,simulated_data=FALSE,raw_pipeline_run=FALSE,loop_calling_recomputed=FALSE,
 original_rds_valid=TRUE,original_object_not_updated_or_resaved=TRUE,bins=200,source_interaction_records=nrow(d),native_mirrored_tile_rows=nrow(built$data[[1]]),
 raw_count_sum=sum(d$count),all_loop_annotations=nrow(ld),author_filtered_loops=sum(keep),visible_native_loop_circles=nrow(built$data[[li]]),
 balanced_log10_limits=c(-4,-1.2),clamped_low=sum(d$log10_balanced< -4),clamped_high=sum(d$log10_balanced> -1.2),
 layer_mapping_preserved=TRUE,raster_device_adaptation="PNG native HiContacts tile layer rasterized with ggrastr dev=ragg; coordinates/scores/loops unchanged",pdf_device="Quartz with author-supported native vector tiles and vector colorbar; bad embedded-raster orientation and unavailable Cairo/X11 devices rejected",pdf_png_native_data_identical=TRUE,pdf_matrix_fully_vector=TRUE,known_startup_namespace_warnings=unique(load_warnings),source_input_rds_sha256="b20fc02f9dcd5fcd027d02b4108d08650407a7de80553e2171f87bc7f296750d",
 scope="Selected2026author-book processed fragment of2024NatureCommun companion; formalpaperpanel NOT_VERIFIED; no transfer/stableclaim"),
 file.path(out,"evidence/scientific-checks.json"),pretty=TRUE,auto_unbox=TRUE)
file.copy(paste0(png,".render.json"),file.path(out,"evidence/render-receipt.json"),overwrite=TRUE)
file.copy(png,file.path(work,"first-color-render.png"),overwrite=FALSE)
packages<-c("HiContacts","HiCExperiment","InteractionSet","GenomeInfoDb","rhdf5","Rhdf5lib","ggplot2","ggrastr","ragg","yaml","jsonlite","svglite","systemfonts","digest")
writeLines(capture.output(sessionInfo()),file.path(out,"data/metadata/environment.txt"))
write_json(list(R=R.version.string,packages=as.list(setNames(vapply(packages,function(n)as.character(packageVersion(n)),character(1)),packages)),
 native_commits=lock$native_packages,font=font,random_seed=NULL,seed_basis="No stochastic operation; saved author coordinates/scores only",isolated_library=tasklib,
 source_package_load_warnings=unique(load_warnings)),file.path(out,"data/metadata/environment.json"),pretty=TRUE,auto_unbox=TRUE)
cat("AUTHORIZED_NATIVE_HICONTACTS_RENDER_OK",png,"dataaspect",ratio,"tiles",nrow(built$data[[1]]),"loops",nrow(built$data[[li]]),"\n")
