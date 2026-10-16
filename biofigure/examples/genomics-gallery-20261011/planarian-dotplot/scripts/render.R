#!/usr/bin/env Rscript
# Native R endpoint dotplot, author processed coordinates, explicit new identity colour.
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==3)
root<-normalizePath(args[1],mustWork=TRUE);work<-normalizePath(args[2],mustWork=TRUE);authorization<-normalizePath(args[3],mustWork=TRUE)
skill<-Sys.getenv('BIOFIGURE_SKILL_ROOT',normalizePath(file.path(root,'../../../..'),mustWork=FALSE))
source(file.path(skill,'scripts/figure_style.R'));options(warn=2)
font<-bf_font('Arial');bf_complexheatmap_font(font)
spec_path<-file.path(root,'data/metadata/design-spec.yaml');spec<-yaml::read_yaml(spec_path)
prefix<-'planarian_haplotype_recolored'
paths<-file.path(root,'results/plot_data',paste0(prefix,'_',c('alignments','endpoints','boundaries'),'.csv'))
d<-data.table::fread(paths[1],data.table=FALSE);points<-data.table::fread(paths[2],data.table=FALSE);bound<-data.table::fread(paths[3],data.table=FALSE)
stopifnot(nrow(d)==19637,nrow(points)==39274,nrow(bound)==8,all(points$percentID>.5),all(d$mapQ==60),all(d$lenAln>1000))
width<-180;height<-180;left<-27;bottom<-35;side<-140
xmax<-max(points$x_bp);ymax<-max(points$y_bp)
points$x_mm<-left+side*points$x_bp/xmax;points$y_mm<-bottom+side*points$y_bp/ymax
ref<-bound[bound$axis=='reference',];query<-bound[bound$axis=='query',]
ref$x_mm<-left+side*ref$boundary_bp/xmax;query$y_mm<-bottom+side*query$boundary_bp/ymax
pal<-spec$palette_semantics
# Same independent linear normalization as a square native panel, no flips or ID joins.
p<-ggplot2::ggplot()+
 ggplot2::geom_point(data=points[points$endpoint=='start',],ggplot2::aes(x=x_mm,y=y_mm,colour=percentID),shape=16,size=.35,stroke=0)+
 ggplot2::geom_point(data=points[points$endpoint=='end',],ggplot2::aes(x=x_mm,y=y_mm,colour=percentID),shape=16,size=.35,stroke=0)+
 ggplot2::scale_colour_gradientn(colours=c(pal$identity_50,pal$identity_75,pal$identity_100),values=c(0,.5,1),limits=c(.5,1),space='Lab',guide='none')+
 ggplot2::geom_segment(data=ref,ggplot2::aes(x=x_mm,xend=x_mm,y=bottom,yend=bottom+side),colour=pal$boundary,linewidth=.1)+
 ggplot2::geom_segment(data=query,ggplot2::aes(x=left,xend=left+side,y=y_mm,yend=y_mm),colour=pal$boundary,linewidth=.1)+
 ggplot2::annotate('rect',xmin=left,xmax=left+side,ymin=bottom,ymax=bottom+side,fill=NA,colour=pal$boundary,linewidth=.13)+
 ggplot2::geom_text(data=ref,ggplot2::aes(x=x_mm,y=30.5,label=chromosome),angle=40,hjust=1,vjust=.5,family=font$family,size=7.5/ggplot2::.pt,colour='#30343B')+
 ggplot2::geom_text(data=query,ggplot2::aes(x=24,y=y_mm,label=chromosome),hjust=1,family=font$family,size=7.5/ggplot2::.pt,colour='#30343B')+
 ggplot2::annotate('text',x=97,y=19,label='Target',family=font$family,size=8/ggplot2::.pt,colour='#30343B')+
 ggplot2::annotate('text',x=5,y=105,label='Query',angle=90,family=font$family,size=8/ggplot2::.pt,colour='#30343B')
# Rasterize only the continuous manual legend to avoid PDF tile-edge seams.
# The endpoint points retain the same Lab palette and remain vector objects.
identity_colours<-scales::gradient_n_pal(c(pal$identity_50,pal$identity_75,pal$identity_100),values=c(0,.5,1),space='Lab')
identity_bar<-as.raster(matrix(identity_colours(seq(0,1,length.out=1024)),nrow=1))
p<-p+ggplot2::annotation_raster(identity_bar,xmin=47,xmax=147,ymin=7.5,ymax=10,interpolate=TRUE)+
 ggplot2::annotate('text',x=97,y=13.5,label='Per-alignment identity (%)',family=font$family,size=7.5/ggplot2::.pt,colour='#30343B')+
 ggplot2::geom_text(data=data.frame(x=seq(47,147,length.out=6),label=as.character(seq(50,100,10))),ggplot2::aes(x=x,y=4.3,label=label),family=font$family,size=7.5/ggplot2::.pt,colour='#30343B')+
 ggplot2::coord_fixed(xlim=c(0,width),ylim=c(0,height),expand=FALSE,clip='off')+
 ggplot2::theme_void(base_family=font$family,base_size=7.5)+
 ggplot2::theme(plot.margin=ggplot2::margin(0,0,0,0,'mm'),plot.background=ggplot2::element_rect(fill='white',colour=NA),panel.background=ggplot2::element_rect(fill='white',colour=NA))
bf_pdf_open(NULL,width,height,font)
measure<-function(text,size=7.5){g<-grid::textGrob(text,gp=grid::gpar(fontfamily=font$family,fontsize=size));c(width_mm=grid::convertWidth(grid::grobWidth(g),'mm',valueOnly=TRUE),height_mm=grid::convertHeight(grid::grobHeight(g),'mm',valueOnly=TRUE))}
text_metrics<-lapply(spec$text_contract$allowed_text,measure);names(text_metrics)<-spec$text_contract$allowed_text
# On x-axis IDs, perpendicular separation of parallel40-degree labels exceeds text height.
label_width<-max(vapply(text_metrics[ref$chromosome],`[[`,numeric(1),'width_mm'));label_height<-max(vapply(text_metrics[ref$chromosome],`[[`,numeric(1),'height_mm'))
perpendicular_pitch<-min(diff(ref$x_mm))*sin(40*pi/180)
stopifnot(perpendicular_pitch>label_height,24-max(vapply(text_metrics[query$chromosome],`[[`,numeric(1),'width_mm'))>7,
 30.5-label_width*sin(40*pi/180)-label_height*cos(40*pi/180)/2>21)
grDevices::dev.off()
boxes<-data.frame(id=c('data','query_names','reference_names','query_axis','target_axis','legend'),x=c(27,8,17,2,87,42),y=c(5,3,145,69,159,164),w=c(140,16,152,6,20,110),h=c(140,140,13.5,12,4,15))
bf_check_boxes(boxes,width,height)
macro<-data.frame(id=c('data','labels','legend'),x=c(27,2,42),y=c(5,3,164),w=c(140,168,110),h=c(140,160,15))
sources<-c(spec_path,file.path(root,'scripts/render.R'),file.path(skill,'scripts/figure_style.R'),paths)
png<-file.path(work,paste0(prefix,'.png'))
bf_render_png(p,png,font=font,allowed_text=spec$text_contract$allowed_text,width_mm=width,height_mm=height,target_width_mm=width,
 dpi=600,min_text_pt=7.5,source_files=sources,boxes=macro,allowed_pairs='data:labels',authorization=authorization,skill_root=skill,
 publication_size_class='custom',size_override_basis=spec$output_size$size_rationale$override_basis)
pdf<-file.path(root,'results/figures',paste0(prefix,'.pdf'));dir.create(dirname(pdf),recursive=TRUE,showWarnings=FALSE)
bf_pdf_open(pdf,width,height,font);print(p);grDevices::dev.off()
pdf_inspection<-bf_pdf_finalize(pdf,font,width,height)
svg<-file.path(work,paste0(prefix,'-gate-qa.svg'));svglite::svglite(svg,width=width/25.4,height=height/25.4,bg='white',system_fonts=list(sans=font$family));print(p);grDevices::dev.off()
bind<-function(z)list(path=normalizePath(z,mustWork=TRUE),sha256=digest::digest(file=z,algo='sha256'))
metrics<-list(scope=spec$scientific_message,alignments=nrow(d),endpoints=nrow(points),chromosome_blocks=c(4,4),reference_order=ref$chromosome,query_order=query$chromosome,
 source_maxEnd_boundaries=bound,identity=range(points$percentID),palette=pal,geometry=list(canvas_mm=c(180,180),data_mm=c(140,140),point_size_mm=.35,point_shape=16,point_stroke_mm=0,boundary_linewidth_mm=.1,
 minimum_font_pt=7.5,x_ID_angle_deg=40,x_perpendicular_text_pitch_mm=perpendicular_pitch),coordinates='saved bp consumed unchanged; linear physical normalization only',
 final_panel_mapping='NOT_VERIFIED',source_mean_identity_not_used=TRUE,all_endpoints_retained=TRUE,statistics='No inference, no biological replicate reconstruction',
 source_density='Source4x4whole-chromosome matrix retained; all source-selected points; diagnostic title removed, IDs enlarged, explicit identity legend added',
 text_metrics_mm=text_metrics,exclusive_slots_mm=boxes,macro_slots_mm=macro,source_files=lapply(sources,bind),
 artifacts=list(pdf=bind(pdf),png=bind(png),svg_qa=bind(svg)),render_receipt=bind(paste0(png,'.render.json')),CP4='PENDING_ACTUAL_SOURCE_AND_FINAL_SIZE_REVIEW')
jsonlite::write_json(metrics,file.path(root,'results/tables/render-metrics.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
