#!/usr/bin/env Rscript
# Native editable SNFG molecules, original Fig4A/B source layout, formal edge weights.
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==3L)
root<-normalizePath(args[1],mustWork=TRUE);work<-normalizePath(args[2],mustWork=TRUE);authorization<-normalizePath(args[3],mustWork=TRUE)
skill<-Sys.getenv('BIOFIGURE_SKILL_ROOT',normalizePath(file.path(root,'../../../../../..'),mustWork=TRUE));source(file.path(skill,'scripts/figure_style.R'));options(warn=2)
suppressPackageStartupMessages({library(grid);library(ggplot2);library(jsonlite);library(digest)})
font<-bf_font('Arial');spec_path<-file.path(root,'data/metadata/design-spec.yaml');spec<-yaml::read_yaml(spec_path);pal<-unlist(spec$palette_semantics);roles<-unlist(spec$font_contract$size_roles_pt)
width<-180;height<-112;k<-180/1999;top<-3;stopifnot(spec$output_size$width_mm==width,spec$output_size$height_mm==height,roles[['panel_label']]==18)
fns<-c('glyph_atoms_mm.csv','glyph_bonds_mm.csv','original_node_labels_mm.csv','reaction_edges_mm.csv','source90-91-raster-atom-mapping.csv','original_fig4a_atoms.csv','original_fig4b_nodes.csv','original_fig4b_edges.csv','figure4_glycan_residues.csv','figure4_glycan_bonds.csv')
input_paths<-file.path(root,'data/plot_data',fns);atoms<-read.csv(input_paths[1],check.names=FALSE);bonds<-read.csv(input_paths[2],check.names=FALSE);labels<-read.csv(input_paths[3]);edges<-read.csv(input_paths[4],check.names=FALSE)
ann_path<-file.path(root,'data/metadata/layout-annotations.json');ann<-jsonlite::fromJSON(ann_path,simplifyVector=FALSE);qc_path<-file.path(root,'data/metadata/physical-glyph-QC.json');qc<-jsonlite::fromJSON(qc_path)
stopifnot(nrow(atoms)==196,nrow(bonds)==163,nrow(labels)==31,nrow(edges)==40,sum(atoms$panel=='A')==18,sum(atoms$panel=='B')==178,!any(atoms$panel=='B' & atoms$metabolite_id==1))
xy<-function(p)c(as.numeric(p[[1]])*k,height-top-as.numeric(p[[2]])*k)
grobs<-list();text_record<-list();edge_record<-list();glyph_record<-list();nn<-0L
add<-function(g){nn<<-nn+1L;if(is.null(g$name))g$name<-paste0('element_',nn);grobs[[length(grobs)+1L]]<<-g}
gp<-function(...)grid::gpar(...)
segment<-function(a,b,col=pal[['bond']],lwd=.20,name=NULL){add(grid::segmentsGrob(a[1],a[2],b[1],b[2],default.units='mm',gp=gp(col=col,lwd=lwd*72/25.4,lineend='round'),name=name))}
polygon<-function(x,y,fill,col=NA,lwd=.1,name=NULL){add(grid::polygonGrob(x,y,default.units='mm',gp=gp(fill=fill,col=col,lwd=lwd*72/25.4,linejoin='round'),name=name))}
text<-function(label,p,role='annotation_text',just='centre',face='plain',name=NULL){size<-roles[[role]];stopifnot(is.finite(size));g<-grid::textGrob(label,x=p[1],y=p[2],default.units='mm',just=just,gp=gp(fontfamily=font$family,fontsize=size,col=pal[['text']],fontface=face),name=name);add(g);text_record[[length(text_record)+1L]]<<-data.frame(label=label,x_mm=p[1],y_mm=p[2],role=role,size_pt=size,just=just,fontfamily=font$family,fontface=face)}
symbol<-function(x,y,r,shape,fill,name,outline=.10){
 if(shape=='circle')add(grid::circleGrob(x,y,r,default.units='mm',gp=gp(fill=fill,col=pal[['bond']],lwd=outline*72/25.4),name=name))
 else if(shape=='square')add(grid::rectGrob(x,y,width=2*r,height=2*r,default.units='mm',gp=gp(fill=fill,col=pal[['bond']],lwd=outline*72/25.4),name=name))
 else if(shape=='triangle')polygon(x+c(0,-r,r),y+c(r,-r,-r),fill,pal[['bond']],outline,name)
 else if(shape=='diamond')polygon(x+c(0,-r,0,r),y+c(r,0,-r,0),fill,pal[['bond']],outline,name)
 else stop('Unknown SNFG shape')
}
# Nonquantitative source zoom wedge; editable vector gradient is relative to its own bbox.
wedge_left<-rbind(c(784,7),c(776,135),c(760,177),c(664,175));u<-seq(0,1,length.out=80);wl<-sapply(1:2,function(j)(1-u)^3*wedge_left[1,j]+3*(1-u)^2*u*wedge_left[2,j]+3*(1-u)*u^2*wedge_left[3,j]+u^3*wedge_left[4,j]);wedge<-rbind(c(784,7),c(1442,70),c(524,356),wl[nrow(wl):1,]);wmm<-cbind(wedge[,1]*k,height-top-wedge[,2]*k)
gradient<-grid::linearGradient(colours=c('#C1C6C9','white'),stops=c(0,1),x1=grid::unit(0,'npc'),x2=grid::unit(1,'npc'),y1=grid::unit(.5,'npc'),y2=grid::unit(.5,'npc'))
add(grid::polygonGrob(wmm[,1],wmm[,2],default.units='mm',gp=gp(fill=gradient,col=NA),name='SOURCE_ZOOM_VECTOR_GRADIENT'))
# Original reaction geometry: smoothly tapered strokes, never ordinary graph arrows.
taper<-function(a,b,peak,col,pattern,id){v<-b-a;len<-sqrt(sum(v*v));stopifnot(len>0);perp<-c(-v[2],v[1])/len
 ranges<-if(pattern=='solid')list(c(0,1)) else if(pattern=='dashed')lapply(seq(0,len,by=2.2),function(s)c(s/len,min((s+1.0)/len,1))) else lapply(seq(.25,len,by=1.1),function(s)c(s/len,s/len))
 nobj<-0L
 for(rr in ranges){if(rr[1]>=1)next;nobj<-nobj+1L
  if(pattern=='dotted'){t<-rr[1];r<-(peak/2)*sin(pi*t)^.8;add(grid::circleGrob(a[1]+t*v[1],a[2]+t*v[2],r,default.units='mm',gp=gp(fill=col,col=NA),name=paste0('REACTION_',id,'_dot_',nobj)))}
  else{t<-seq(rr[1],rr[2],length.out=if(pattern=='solid')60 else 10);halfw<-(peak/2)*sin(pi*t)^.8;cx<-a[1]+t*v[1];cy<-a[2]+t*v[2];polygon(c(cx+perp[1]*halfw,rev(cx-perp[1]*halfw)),c(cy+perp[2]*halfw,rev(cy-perp[2]*halfw)),col,name=paste0('REACTION_',id,'_stroke_',nobj))}}
 edge_record[[length(edge_record)+1L]]<<-data.frame(edge_id=id,pattern=pattern,peak_width_mm=peak,component_count=nobj)
}
edgecolor<-function(res)pal[[c(Gal='edge_Gal',Fuc='edge_Fuc',GlcNAc='edge_GlcNAc',Neu5Ac='edge_Neu5Ac')[[res]]]]
for(i in 1:nrow(edges)){r<-edges[i,];taper(c(r$x_mm,r$y_mm),c(r$xend_mm,r$yend_mm),r$peak_width_mm,edgecolor(r$source_added_residue),r$source_line_pattern,r$edge_id)}
# Source A and B chemical parent bonds; foreground residues hide bond endpoints.
for(i in 1:nrow(bonds)){r<-bonds[i,];segment(c(r$x_mm,r$y_mm),c(r$xend_mm,r$yend_mm),lwd=if(r$panel=='A').25 else .11,name=paste0('GLYCAN_BOND_',r$panel,'_',r$metabolite_id,'_',r$child_id))}
for(i in 1:nrow(atoms)){r<-atoms[i,];stopifnot(r$fill==pal[[r$residue_name]]);symbol(r$x_mm,r$y_mm,r$radius_mm,r$shape,r$fill,paste0('SNFG_ATOM_',r$panel,'_',r$metabolite_id,'_',r$residue_id),if(r$panel=='A').16 else .095);glyph_record[[i]]<-r}
# Actual source panel annotations and source label/star positions.
for(p in ann$panel_letters)text(p$text,xy(p$center_px),'panel_label')
text(ann$panel_A$title$text,xy(ann$panel_A$title$center_px),'axis_title')
annotation_overrides<-list();for(g in ann$panel_A$glyphs){text(if(is.null(g$label_text))g$label else g$label_text,xy(g$label_center_px),'isomer_label');for(l in g$linkage_labels){p0<-l$center_px;if(g$metabolite_id==39){if(l$text=='β 4'&&identical(as.numeric(unlist(p0)),c(101,919)))l$center_px<-list(80,919);if(l$text=='α 3'&&identical(as.numeric(unlist(p0)),c(81,998)))l$center_px<-list(92,1012);if(l$text=='β 3'&&identical(as.numeric(unlist(p0)),c(181,893)))l$center_px<-list(181,885);if(!identical(l$center_px,p0))annotation_overrides[[length(annotation_overrides)+1L]]<-list(id=39,label=l$text,original_source_px=p0,actual_draw_px=l$center_px,reason='actual ink bbox avoids square/glycosidic bond; source identity unchanged')};text(l$text,xy(l$center_px),'axis_text')}}
for(i in 1:nrow(labels)){r<-labels[i,];text(if(r$label %in% c('2FL','3FL','3SL'))c('2FL'='2′FL','3FL'='3′FL','3SL'='3′SL')[[r$label]] else r$label,c(r$x_mm,r$y_mm),'annotation_text',name=paste0('B_NODE_LABEL_',r$id))}
a<-ann$panel_A$DFLNT2_to_B_arrow;ps<-do.call(rbind,lapply(a$polyline_px,xy));add(grid::polylineGrob(ps[,1],ps[,2],default.units='mm',gp=gp(col=pal[['text']],lwd=.55*72/25.4,linejoin='mitre')));tip<-xy(a$arrow_tip_px);base<-do.call(rbind,lapply(a$arrow_base_points_px,xy));polygon(c(tip[1],base[,1]),c(tip[2],base[,2]),pal[['text']])
dv<-ann$panel_B$type_divider;ps<-do.call(rbind,lapply(dv$polyline_px,xy));segment(ps[1,],ps[2,],lwd=.55);text(dv$text_type_I$text,xy(dv$text_type_I$center_px),'type_label');text(dv$text_type_II$text,xy(dv$text_type_II$center_px),'type_label')
# Small source network sketch and circled zoom marker.
z<-ann$panel_B$top_left_source_sketch;ps<-do.call(rbind,lapply(z$black_axes_px[[1]],xy));add(grid::polylineGrob(ps[,1],ps[,2],default.units='mm',gp=gp(col=pal[['bond']],lwd=.55*72/25.4)))
bez<-do.call(rbind,lapply(z$sketch_curve_control_px,xy));t<-seq(0,1,length.out=60);curve<-sapply(1:2,function(j)(1-t)^3*bez[1,j]+3*(1-t)^2*t*bez[2,j]+3*(1-t)*t^2*bez[3,j]+t^3*bez[4,j]);add(grid::linesGrob(curve[,1],curve[,2],default.units='mm',gp=gp(col=pal[['bond']],lwd=.55*72/25.4)))
cp<-xy(z$circled_node$center_px);add(grid::circleGrob(cp[1],cp[2],z$circled_node$radius_px*k,default.units='mm',gp=gp(fill='white',col=pal[['bond']],lwd=.28*72/25.4)))
rb<-unlist(z$circled_node$red_rectangle_bounds_px);p1<-xy(as.list(rb[1:2]));p2<-xy(as.list(rb[3:4]));add(grid::rectGrob((p1[1]+p2[1])/2,(p1[2]+p2[2])/2,width=abs(p2[1]-p1[1]),height=abs(p2[2]-p1[2]),default.units='mm',gp=gp(fill=NA,col=pal[['edge_Fuc']],lwd=.28*72/25.4)))
for(ray in z$zoom_rays_px)segment(xy(ray[[1]]),xy(ray[[2]]),lwd=.25)
# Carbon-position reference inset is nonquantitative; preserve its original labels.
inset<-ann$panel_B$carbon_position_key;b<-unlist(inset$bounds_px);p1<-xy(as.list(b[1:2]));p2<-xy(as.list(b[3:4]));add(grid::rectGrob(mean(c(p1[1],p2[1])),mean(c(p1[2],p2[2])),width=abs(p2[1]-p1[1]),height=abs(p2[2]-p1[2]),default.units='mm',gp=gp(fill=pal[['inset_background']],col=pal[['bond']],lwd=.25*72/25.4)))
for(b in inset$bond_segments_px)segment(xy(b[[1]]),xy(b[[2]]),lwd=.20)
bb<-unlist(inset$central_square$bounds_px);p1<-xy(as.list(bb[1:2]));p2<-xy(as.list(bb[3:4]));add(grid::rectGrob(mean(c(p1[1],p2[1])),mean(c(p1[2],p2[2])),width=abs(p2[1]-p1[1]),height=abs(p2[2]-p1[2]),default.units='mm',gp=gp(fill=pal[['inset_square']],col=NA)))
for(n in inset$number_labels)text(n$text,xy(n$center_px),'axis_text')
leg<-ann$panel_B$reaction_key
for(i in seq_along(leg$entries)){r<-leg$entries[[i]];a<-xy(list(leg$segments_x_px[[1]],r$baseline_y_px));b<-xy(list(leg$segments_x_px[[2]],r$baseline_y_px));taper(a,b,.55,edgecolor(r$residue),r$linetype,paste0('key_',i));text(r$text_scientific,xy(list(leg$text_left_x_px,r$baseline_y_px)),'legend_text','left')}
sc<-leg$star_caption;text('*',xy(sc$star_center_px),'star_symbol');for(i in seq_along(sc$text_lines))text(sc$text_lines[[i]],xy(list(sc$text_left_x_px,sc$text_baselines_y_px[[i]])),'legend_text','left')
bl<-ann$bottom_residue_legend
for(i in seq_along(bl$entries)){r<-bl$entries[[i]];name<-c('Gal','Glc','GlcNAc','Fuc','Neu5Ac')[i];cc<-xy(r$symbol_center_px);symbol(cc[1],cc[2],20*k,r$shape,pal[[name]],paste0('SNFG_LEGEND_',name),.12);text(r$text,xy(list(r$text_left_x_px,bl$baseline_y_px)),'legend_text','left')}
full<-grid::gTree(children=do.call(grid::gList,grobs),gp=gp(fontfamily=font$family,fontsize=7,col=pal[['text']]))
texts<-do.call(rbind,text_record);stopifnot(all(texts$label %in% spec$text_contract$allowed_text),all(texts$size_pt==roles[texts$role]))
actual_symbols<-sum(grepl('^SNFG_ATOM_',vapply(grobs,function(g)g$name,character(1))));actual_bonds<-sum(grepl('^GLYCAN_BOND_',vapply(grobs,function(g)g$name,character(1))));stopifnot(actual_symbols==196,actual_bonds==163)
# Native text-size/role measurements cover every plotted text object.
measurement<-file.path(work,'text-measurement.png');ragg::agg_png(measurement,width=width,height=height,units='mm',res=150,background='white')
text_boxes<-lapply(seq_len(nrow(texts)),function(i){r<-texts[i,];g<-grid::textGrob(r$label,gp=gp(fontfamily=r$fontfamily,fontsize=r$size_pt,fontface=r$fontface));ww<-grid::convertWidth(grid::grobWidth(g),'mm',valueOnly=TRUE);hh<-grid::convertHeight(grid::grobHeight(g),'mm',valueOnly=TRUE);hj<-if(r$just=='left')0 else .5;cbind(r,data.frame(xmin=r$x_mm-hj*ww,xmax=r$x_mm+(1-hj)*ww,ymin=r$y_mm-hh/2,ymax=r$y_mm+hh/2))});grDevices::dev.off();unlink(measurement)
text_boxes<-do.call(rbind,text_boxes);outside<-text_boxes[text_boxes$xmin < -0.1|text_boxes$xmax>width+.1|text_boxes$ymin < -0.1|text_boxes$ymax>height+.1,];stopifnot(nrow(outside)==0)
collisions<-data.frame();if(nrow(text_boxes)>1)for(i in 1:(nrow(text_boxes)-1))for(j in (i+1):nrow(text_boxes)){a<-text_boxes[i,];b<-text_boxes[j,];if(min(a$xmax,b$xmax)>max(a$xmin,b$xmin)&&min(a$ymax,b$ymax)>max(a$ymin,b$ymin))collisions<-rbind(collisions,data.frame(a=a$label,b=b$label,role_a=a$role,role_b=b$role))}
p<-ggplot2::ggplot()+ggplot2::annotation_custom(full,xmin=0,xmax=width,ymin=0,ymax=height)+ggplot2::coord_fixed(xlim=c(0,width),ylim=c(0,height),expand=FALSE,clip='off')+ggplot2::theme_void(base_family=font$family,base_size=7)+ggplot2::theme(plot.margin=ggplot2::margin(0,0,0,0,'mm'),plot.background=ggplot2::element_rect(fill='white',colour=NA))
sources<-c(spec_path,file.path(root,'scripts/render.R'),file.path(skill,'scripts/figure_style.R'),input_paths,ann_path,qc_path)
png<-file.path(work,'hmo_fig4_ab_snfg_recolored.png');boxes<-data.frame(id=c('data','labels','legend'),x=c(0,0,0),y=c(0,0,0),w=c(width,width,width),h=c(height,height,height))
bf_render_png(p,png,font=font,allowed_text=spec$text_contract$allowed_text,width_mm=width,height_mm=height,target_width_mm=width,source_files=sources,boxes=boxes,allowed_pairs=c('data:labels','data:legend','labels:legend'),dpi=600,min_text_pt=6.5,authorization=authorization,skill_root=skill,publication_size_class='double-column')
pdf<-file.path(root,'results/figures/hmo_fig4_ab_snfg_recolored.pdf');grDevices::quartz(type='pdf',file=pdf,width=width/25.4,height=height/25.4,family=font$family,bg='white');print(p);grDevices::dev.off()
svg<-file.path(work,'hmo_fig4_ab_snfg_recolored-gate-qa.svg');svglite::svglite(svg,width=width/25.4,height=height/25.4,bg='white',system_fonts=list(sans=font$family));print(p);grDevices::dev.off()
bind<-function(f)list(path=normalizePath(f,mustWork=TRUE),sha256=digest::digest(file=f,algo='sha256'));packages<-c('grid','ggplot2','ragg','systemfonts','yaml','jsonlite','digest','svglite')
metrics<-list(schema_version=1,scope=spec$scientific_message,counts=list(panel_A_isomers=3,panel_B_nodes=31,reaction_edges=40,visible_data_SNFG_symbols=actual_symbols,panel_A_atoms=18,panel_B_atoms=178,glycosidic_parent_bonds=actual_bonds,SNFG_legend_symbols=5,reaction_keys=9,source_stars=7,raster_grobs=sum(vapply(grobs,function(g)inherits(g,'rastergrob'),logical(1)))),geometry=list(canvas_mm=c(width,height),source_scale_mm_per_px=k,source_top_offset_mm=top,glyph_atoms=atoms,glycosidic_bonds=bonds,source_label_mapping=labels,reaction_mapping=edges,taper_components=do.call(rbind,edge_record),source_coordinate_boundary='manualtraceapprox3-6px;90/91actualcomponentsoverride;formalimportancewidth'),annotation_overrides=annotation_overrides,zoom_wedge='native editable object-bbox gridlinearGradient over smoothBezierboundary; no raster orstrips',actual_text_role_sizes_pt=as.list(tapply(texts$size_pt,texts$role,unique)),all_actual_text_roles_checked=all(texts$size_pt==roles[texts$role]),actual_text_metrics_mm=text_boxes,text_bbox_collisions=collisions,source_files=lapply(sources,bind),artifacts=list(pdf=bind(pdf),png=bind(png),svg=bind(svg)),render_receipt=bind(paste0(png,'.render.json')),environment=list(R=R.version.string,packages=as.list(setNames(vapply(packages,function(z)as.character(packageVersion(z)),character(1)),packages))),source_linewidth_conflicts='fourrootedgesformalidenticalbutsourcepixelwidthsdiffer;2to8formalhigherbutsourcevisuallythinner;25to53sourcevisuallythickerbutformalnearzero;preservedformalvalues',CP4='PENDING_ACTUAL_ORIGINAL_SOURCE_AND_FINAL_SIZE_REVIEW',new_input_transfer='NOT_VERIFIED',whole_exact_pixels='NOT_VERIFIED')
write_json(metrics,file.path(root,'results/tables/render-metrics.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
cat('FullFig4A/B:196nativeSNFGsymbols163bonds31labels40taperededges rendered; reviewpending\n')
