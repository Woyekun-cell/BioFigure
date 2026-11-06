#!/usr/bin/env Rscript
# Native igraph layout and ComplexHeatmap; fixed formal author tables only.
args <- commandArgs(trailingOnly=TRUE);stopifnot(length(args)==3L)
root<-normalizePath(args[1],mustWork=TRUE);work<-normalizePath(args[2],mustWork=TRUE);authorization<-normalizePath(args[3],mustWork=TRUE)
skill<-Sys.getenv('BIOFIGURE_SKILL_ROOT',normalizePath(file.path(root,'../../../..'),mustWork=TRUE))
source(file.path(skill,'scripts/figure_style.R'));options(warn=2)
suppressPackageStartupMessages({library(igraph);library(ComplexHeatmap);library(circlize);library(ggplot2);library(grid);library(jsonlite);library(digest)})
font<-bf_font('Arial');bf_complexheatmap_font(font)
spec_path<-file.path(root,'data/metadata/design-spec.yaml');spec<-yaml::read_yaml(spec_path)
pal<-unlist(spec$palette_semantics,use.names=TRUE);width<-180;height<-170
stopifnot(spec$output_size$width_mm==width,spec$output_size$height_mm==height)
names_in<-c('all_metabolites','all_reactions','selected_nodes','selected_edges','paths','structure_jaccard','structure_order')
paths<-file.path(root,'data/plot_data',paste0(names_in,'.csv'));d<-setNames(lapply(paths,read.csv,stringsAsFactors=FALSE,check.names=FALSE),names_in)
n<-d$selected_nodes;e<-d$selected_edges;o<-d$structure_order;m<-d$structure_jaccard
stopifnot(nrow(n)==43L,nrow(e)==58L,nrow(o)==27L,nrow(m)==729L,!anyDuplicated(n$id))
g<-igraph::graph_from_data_frame(data.frame(from=as.character(e$reactant_id),to=as.character(e$product_id)),directed=TRUE,vertices=data.frame(name=as.character(n$id)))
lay<-igraph::layout_as_tree(g,root=which(V(g)$name=='1'),mode='out',circular=FALSE)
stopifnot(max(abs(lay[,1]-n$source_tree_x))<1e-12,max(abs(lay[,2]-n$source_tree_y))<1e-12,is_dag(g))
# The actual author igraph rooted layout determines every vertex position.
scale_mm<-function(v,lo,hi) lo+(v-min(v))/diff(range(v))*(hi-lo)
n$x_mm<-scale_mm(lay[,1],10,170);n$y_mm<-scale_mm(lay[,2],82,154)
e$x<-n$x_mm[match(e$reactant_id,n$id)];e$y<-n$y_mm[match(e$reactant_id,n$id)]
e$xend<-n$x_mm[match(e$product_id,n$id)];e$yend<-n$y_mm[match(e$product_id,n$id)]
e$color<-unname(pal[e$addition_class]);e$width_mm<-.10+.55*e[['weight.enrichment_scaled_proportion']]
stopifnot(!anyNA(e$color))
mat<-matrix(NA_real_,27,27,dimnames=list(o$structure_id,o$structure_id))
mat[cbind(match(m$row_id,o$structure_id),match(m$col_id,o$structure_id))]<-m$jaccard
stopifnot(!anyNA(mat),max(abs(mat-t(mat)))<1e-12,all(diag(mat)==0))
fam<-factor(o$family,levels=unique(o$family));famcols<-as.list(setNames(unname(pal[levels(fam)]),levels(fam)))
ht_color<-circlize::colorRamp2(c(0,.5,1),unname(pal[c('jaccard_low','jaccard_mid','jaccard_high')]))
ht_gp<-grid::gpar(fontfamily=font$family,fontsize=7.5,col=pal[['text']])
ht<-ComplexHeatmap::Heatmap(mat,name='Jaccard index',col=ht_color,use_raster=FALSE,
  cluster_rows=FALSE,cluster_columns=FALSE,row_order=seq_len(27),column_order=seq_len(27),
  show_row_dend=FALSE,show_column_dend=FALSE,show_heatmap_legend=FALSE,
  row_names_side='left',row_names_gp=ht_gp,column_names_gp=ht_gp,column_names_rot=90,
  column_names_centered=TRUE,row_names_max_width=grid::unit(15,'mm'),
  row_split=fam,column_split=fam,row_title=NULL,column_title=NULL,
  row_gap=grid::unit(.55,'mm'),column_gap=grid::unit(.55,'mm'),
  top_annotation=ComplexHeatmap::HeatmapAnnotation(Family=fam,col=list(Family=unlist(famcols)),
    show_annotation_name=FALSE,show_legend=FALSE,simple_anno_size=grid::unit(1.5,'mm')),
  left_annotation=ComplexHeatmap::rowAnnotation(Family=fam,col=list(Family=unlist(famcols)),
    show_annotation_name=FALSE,show_legend=FALSE,simple_anno_size=grid::unit(1.5,'mm')),
  border=FALSE,rect_gp=grid::gpar(col=NA),height=grid::unit(60,'mm'),width=grid::unit(60,'mm'))
heat_grob<-grid::grid.grabExpr(ComplexHeatmap::draw(ht,newpage=TRUE,padding=grid::unit(c(1,1,1,1),'mm')),
  width=90/25.4,height=76/25.4,warn=0)
# True heatmap rectangles remain vectors; no raster substitution.
raster_n<-0L;heat_rect_n<-0L;heat_text<-character()
walk<-function(x){if(inherits(x,'rastergrob'))raster_n<<-raster_n+1L
 if(inherits(x,'rect')&&any(grepl('heatmap_body_',as.character(x$vp))))heat_rect_n<<-heat_rect_n+length(x$gp$fill)
 if(inherits(x,'text'))heat_text<<-c(heat_text,as.character(x$label))
 if(length(x$children))for(ch in x$children)walk(ch);if(length(x$grobs))for(ch in x$grobs)walk(ch)}
walk(heat_grob);stopifnot(raster_n==0L,heat_rect_n==729L,all(o$structure_id %in% heat_text))
text<-data.frame(x=numeric(),y=numeric(),label=character(),size=numeric(),face=character(),hjust=numeric())
addtext<-function(x,y,label,size=7.5,face='plain',hjust=0){text<<-rbind(text,data.frame(x=x,y=y,label=label,size=size,face=face,hjust=hjust))}
addtext(5,166,'a',9,'bold');addtext(11,166,'Selected HMO reaction network',8,'bold');addtext(175,166,'43 metabolites | 58 reactions',7.5,hjust=1)
addtext(5,78,'b',9,'bold');addtext(11,78,'Structure co-occurrence',8,'bold')
# Reaction legend: color is monosaccharide addition; pattern is linkage.
keys<-data.frame(reaction=c('Ab3','Ab4','Fa2','Fa3','Fa4','GNb3','GNb6','NNa3','NNa6','out'),
  label=c('b1,3 Galactose','b1,4 Galactose','a1,2 Fucose','a1,3 Fucose','a1,4 Fucose','b1,3 GlcNAc','b1,6 GlcNAc','a2,3 Neu5Ac','a2,6 Neu5Ac','Isomer sink'))
keys$class<-c('Galactose','Galactose','Fucose','Fucose','Fucose','GlcNAc','GlcNAc','Neu5Ac','Neu5Ac','Isomer sink')
keys$col<-unname(pal[keys$class]);keys$lty<-c('solid','dashed','solid','dashed','dotted','solid','dashed','solid','dashed','solid')
keys$x<-rep(c(100,139),each=5);keys$y<-rep(seq(62,42,by=-5),2)
addtext(100,69,'Added monosaccharide',8,'bold')
for(i in seq_len(nrow(keys)))addtext(keys$x[i]+7,keys$y[i],keys$label[i])
addtext(100,35,'Reaction importance',8,'bold')
wtkeys<-data.frame(x=c(100,124,148),y=30,v=c(.2,.6,1))
for(i in 1:3)addtext(wtkeys$x[i]+8,30,format(wtkeys$v[i],nsmall=1))
addtext(100,23,'Jaccard index',8,'bold')
grad<-data.frame(xmin=seq(100,174,length.out=201)[1:200],xmax=seq(100,174,length.out=201)[2:201],ymin=16,ymax=18,
 fill=ht_color(seq(0,1,length.out=200)))
for(i in 0:4)addtext(100+i*18.5,12,c('0','0.25','0.5','0.75','1')[i+1],hjust=.5)
addtext(100,8,'Structure family',8,'bold')
familykeys<-data.frame(x=c(125,136,147,160,174),y=4,label=levels(fam));familykeys$color<-unname(pal[familykeys$label])
for(i in 1:nrow(familykeys))addtext(familykeys$x[i],4,familykeys$label[i],hjust=.5)
all_text<-c(text$label,n$label,heat_text,keys$label)
stopifnot(all(all_text %in% spec$text_contract$allowed_text))
# Register actual figure text extents in mm before export.
metrics_text<-lapply(seq_len(nrow(text)),function(i){z<-text[i,];gp<-grid::gpar(fontfamily=font$family,fontsize=z$size,fontface=z$face)
 q<-grid::textGrob(z$label,gp=gp);ww<-grid::convertWidth(grid::grobWidth(q),'mm',valueOnly=TRUE);hh<-grid::convertHeight(grid::grobHeight(q),'mm',valueOnly=TRUE)
 data.frame(label=z$label,xmin=z$x-z$hjust*ww,xmax=z$x+(1-z$hjust)*ww,ymin=z$y-hh/2,ymax=z$y+hh/2,size_pt=z$size)})
text_bbox<-do.call(rbind,metrics_text)
node_bbox<-lapply(seq_len(nrow(n)),function(i){gp<-grid::gpar(fontfamily=font$family,fontsize=7.5);q<-grid::textGrob(n$label[i],gp=gp)
 ww<-grid::convertWidth(grid::grobWidth(q),'mm',valueOnly=TRUE)+1.2;hh<-grid::convertHeight(grid::grobHeight(q),'mm',valueOnly=TRUE)+.8
 data.frame(id=n$id[i],label=n$label[i],xmin=n$x_mm[i]-ww/2,xmax=n$x_mm[i]+ww/2,ymin=n$y_mm[i]-hh/2,ymax=n$y_mm[i]+hh/2,size_pt=7.5)})
node_bbox<-do.call(rbind,node_bbox)
overlap_pairs<-function(b){ans<-data.frame();if(nrow(b)>1)for(i in 1:(nrow(b)-1))for(j in (i+1):nrow(b)){
 if(min(b$xmax[i],b$xmax[j])>max(b$xmin[i],b$xmin[j]) && min(b$ymax[i],b$ymax[j])>max(b$ymin[i],b$ymin[j]))ans<-rbind(ans,data.frame(a=b$label[i],b=b$label[j]))};ans}
node_collisions<-overlap_pairs(node_bbox);legend_collisions<-overlap_pairs(text_bbox)
stopifnot(nrow(node_collisions)==0L,nrow(legend_collisions)==0L)
p<-ggplot2::ggplot()+
  ggplot2::geom_segment(data=e,ggplot2::aes(x=x,y=y,xend=xend,yend=yend,colour=color,linewidth=width_mm,linetype=linetype),lineend='round',alpha=.9)+
  ggplot2::geom_label(data=n,ggplot2::aes(x=x_mm,y=y_mm,label=label),family=font$family,size=7.5/ggplot2::.pt,
    colour=pal[['text']],fill='white',linewidth=0,label.padding=grid::unit(c(.12,.32,.12,.32),'mm'),label.r=grid::unit(.25,'mm'))+
  ggplot2::annotation_custom(heat_grob,xmin=3,xmax=93,ymin=0,ymax=76)+
  ggplot2::geom_segment(data=keys,ggplot2::aes(x=x,y=y,xend=x+5,yend=y,colour=col,linetype=lty),linewidth=.5)+
  ggplot2::geom_segment(data=wtkeys,ggplot2::aes(x=x,y=y,xend=x+6,yend=y,linewidth=.10+.55*v),colour=pal[['GlcNAc']])+ 
  ggplot2::geom_rect(data=grad,ggplot2::aes(xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax,fill=fill),colour=NA)+
  ggplot2::geom_segment(data=familykeys,ggplot2::aes(x=x-3,y=1.7,xend=x+3,yend=1.7,colour=color),linewidth=.8)+
  ggplot2::geom_text(data=text,ggplot2::aes(x=x,y=y,label=label,size=size/ggplot2::.pt,fontface=face,hjust=hjust),
    family=font$family,colour=pal[['text']])+ 
  ggplot2::scale_colour_identity()+ggplot2::scale_fill_identity()+ggplot2::scale_size_identity()+ggplot2::scale_linewidth_identity()+ggplot2::scale_linetype_identity()+
  ggplot2::coord_fixed(xlim=c(0,width),ylim=c(0,height),expand=FALSE,clip='off')+
  ggplot2::theme_void(base_family=font$family,base_size=7.5)+ggplot2::theme(plot.margin=ggplot2::margin(0,0,0,0,'mm'),plot.background=ggplot2::element_rect(fill='white',colour=NA))
qc_path<-file.path(root,'data/metadata/data-qc.json');sources<-c(spec_path,file.path(root,'scripts/render.R'),file.path(skill,'scripts/figure_style.R'),paths,qc_path)
png<-file.path(work,'hmo_reaction_network_jaccard_recolored.png')
boxes<-data.frame(id=c('data','labels','legend'),x=c(3,3,97),y=c(0,0,2),w=c(174,174,80),h=c(168,168,71))
bf_render_png(p,png,font=font,allowed_text=spec$text_contract$allowed_text,width_mm=width,height_mm=height,target_width_mm=width,
 source_files=sources,boxes=boxes,allowed_pairs=c('data:labels','data:legend','labels:legend'),dpi=600,min_text_pt=7.5,authorization=authorization,skill_root=skill,publication_size_class='double-column')
pdf<-file.path(root,'results/figures/hmo_reaction_network_jaccard_recolored.pdf')
grDevices::quartz(type='pdf',file=pdf,width=width/25.4,height=height/25.4,family=font$family,bg='white');print(p);grDevices::dev.off()
svg<-file.path(work,'hmo_reaction_network_jaccard_recolored-gate-qa.svg')
svglite::svglite(svg,width=width/25.4,height=height/25.4,bg='white',system_fonts=list(sans=font$family));print(p);grDevices::dev.off()
bind<-function(f)list(path=normalizePath(f,mustWork=TRUE),sha256=digest::digest(file=f,algo='sha256'))
packages<-c('igraph','ComplexHeatmap','circlize','ggplot2','ragg','ggplotify','yaml','jsonlite','digest','svglite','systemfonts')
metrics<-list(schema_version=1,scope=spec$scientific_message,counts=list(source_nodes=nrow(d$all_metabolites),source_edges=nrow(d$all_reactions),nodes=nrow(n),edges=nrow(e),heatmap_rows=27L,heatmap_columns=27L,heatmap_vector_cells=heat_rect_n,structure_families=length(levels(fam)),raster_grobs=raster_n),
 geometry=list(canvas_mm=c(width,height),native_layout='igraph::layout_as_tree(root=Lactose,mode=out)',source_tree_exact=TRUE,node_positions=n[,c('id','label','x_mm','y_mm')],edge_mapping=e,heatmap_source_order=o$structure_id,matrix_source_diagonal=diag(mat),heatmap_body_mm=c(60,60),heatmap_outer_viewport_mm=c(3,93,0,76)),
 palette=as.list(pal),actual_text_metrics_mm=text_bbox,actual_node_label_boxes_mm=node_bbox,node_label_collisions=node_collisions,legend_text_collisions=legend_collisions,
 source_files=lapply(sources,bind),artifacts=list(pdf=bind(pdf),png=bind(png),svg_qa=bind(svg)),render_receipt=bind(paste0(png,'.render.json')),
 environment=list(R=R.version.string,platform=R.version$platform,packages=as.list(setNames(vapply(packages,function(z)as.character(packageVersion(z)),character(1)),packages)),font=list(family=font$family,path=font$path,sha256=digest::digest(file=font$path,algo='sha256'))),
 scientific_boundary='formalprovided weights and Jaccard values retained; zero diagonal is sourceimplementation caveat; percentile paths rank importance, not CI; fixedsource exposedmethod transfer; no new statistical tests',whole_original_figure='NOT_VERIFIED',new_input_transfer='NOT_VERIFIED',stress_qualification='NOT_VERIFIED',CP4='PENDING_ACTUAL_SOURCE_AND_FINAL_SIZE_REVIEW')
write_json(metrics,file.path(root,'results/tables/render-metrics.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
cat('Native colored43node58edge graph and27x27 fullJaccard rendered\n')
