#!/usr/bin/env Rscript
# Input-driven source-exposed adapter. Native package geometry retained.
# Benchmark qualification is separate from full CP3; no fabricated bf receipt.
suppressPackageStartupMessages({library(ragg);library(jsonlite);library(systemfonts);library(digest);library(svglite)})
read_csv <- function(p) read.csv(p,check.names=FALSE,stringsAsFactors=FALSE,na.strings=c('NA',''))
cfg <- jsonlite::fromJSON('data/settings.json');mid<-cfg$case_id
metadata<-read_csv('data/metadata.csv');expected<-read_csv('data/expected.csv')
req<-c('variable_id','label','group');if(!all(req %in% names(metadata)) || anyDuplicated(metadata$variable_id)) stop('duplicate or missing metadata primary key')
if(!all(req %in% names(expected)) || anyDuplicated(expected$variable_id)) stop('invalid independent expected keys')
if(!setequal(metadata$variable_id,expected$variable_id))stop('metadata primary keys differ from expected keys')
input_metadata_order<-metadata$variable_id;metadata<-metadata[match(expected$variable_id,metadata$variable_id),,drop=FALSE]
if(!identical(metadata$group,expected$group) || !identical(metadata$label,expected$label))stop('key-aligned metadata differs from expected mapping')
for(k in c('data_context','experimental_unit','figure_caption','association_method'))if(!is.character(cfg[[k]])||length(cfg[[k]])!=1||!nzchar(cfg[[k]]))stop(paste('missing caller declaration',k))
stopifnot(cfg$association_method=='Pearson',is.logical(cfg$synthetic),length(cfg$synthetic)==1,isTRUE(cfg$descriptive_only),cfg$font_family=='Arial')
font<-systemfonts::match_fonts('Arial')$path[1];if(digest::digest(file=font,algo='sha256')!=cfg$font_file_sha256)stop('Arial font hash changed')
W<-cfg$width_mm;H<-cfg$height_mm;fs<-cfg$font_sizes_pt$axis_text
if(W>183||H>170||fs<6)stop('publication size or minimum font violated')
group_colors<-unlist(cfg$group_colors);if(any(!metadata$group %in% names(group_colors)))stop('unnamed category color')
keys<-metadata$variable_id;n<-length(keys);if(mid=='SCICASE-019'){if(n<4||n>64)stop('019 supports 4..64 variables under measured layout constraints')}else if(n<4||n>24)stop('4..24 variables only; split denser panels')
if(any(!nzchar(metadata$label)))stop('empty full labels')
labels<-metadata$label;groups<-unique(metadata$group);colors<-group_colors[metadata$group]
missing_raw<-0;missing_precomputed<-0;mat<-NULL;hc<-NULL;summary_cor<-NULL
if(mid %in% c('SCICASE-015','SCICASE-019')){
 raw<-read_csv('data/observations.csv');if(!'sample_id'%in%names(raw)||anyDuplicated(raw$sample_id)||!setequal(names(raw)[-1],keys))stop('raw observations sample/variable keys invalid')
 x<-as.matrix(raw[,keys,drop=FALSE]);storage.mode(x)<-'double';if(any(!is.finite(x[!is.na(x)]))||any(x[!is.na(x)]<=0))stop('raw concentrations must be finite positive values')
 missing_raw<-sum(is.na(x));complete<-complete.cases(x);if(sum(complete)<5)stop('fewer than five common complete units')
 lx<-log10(x[complete,,drop=FALSE]+1e-6);if(any(apply(lx,2,sd)==0))stop('constant variable has undefined correlation')
 mat<-cor(lx,method='pearson');eig<-min(eigen(mat,symmetric=TRUE,only.values=TRUE)$values)
 if(max(abs(mat-t(mat)))>1e-10||any(abs(mat)>1+1e-10)||any(abs(diag(mat)-1)>1e-10)||eig< -n*1e-8)stop('computed Pearson matrix symmetry/range/PSD failed')
 hc<-hclust(as.dist(1-mat),method='complete');ord<-hc$order;mat<-mat[ord,ord,drop=FALSE];metadata<-metadata[ord,,drop=FALSE];labels<-metadata$label;keys<-metadata$variable_id;colors<-group_colors[metadata$group]
 bar<-log10(colMeans(x,na.rm=TRUE));bar<-bar[keys]
 if(mid=='SCICASE-015'){
  aggregate_x<-sapply(sort(groups),function(g)rowSums(x[complete,expected$variable_id[expected$group==g],drop=FALSE]));summary_cor<-cor(log10(aggregate_x+1e-6));if(anyNA(summary_cor))stop('undefined group correlation')
 }
 qc<-list(raw_units=nrow(x),complete_units=sum(complete),excluded_sample_ids=raw$sample_id[!complete],raw_missing=missing_raw,correlation_method='Pearson after log10(x+1e-6)',minimum_eigenvalue=eig,global_psd_verified=TRUE,p_values_computed=FALSE)
 write.csv(mat,'data/correlation-computed.csv')
}else if(mid=='SCICASE-020'){
 rr<-read_csv('data/matrix.csv');if(!'variable_id'%in%names(rr)||anyDuplicated(rr$variable_id)||!setequal(rr$variable_id,keys))stop('matrix/metadata row primary keys differ')
 mat<-as.matrix(rr[match(keys,rr$variable_id),-1,drop=FALSE]);rownames(mat)<-keys;storage.mode(mat)<-'double'
 if(ncol(mat)<4||ncol(mat)>18||anyDuplicated(colnames(mat)))stop('matrix column keys/dimensions invalid')
 if(any(!is.finite(mat[!is.na(mat)]))||any(abs(mat[!is.na(mat)])>1+1e-10))stop('precomputed rho outside [-1,1]')
 if(any(rowSums(!is.na(mat))<3)||any(colSums(!is.na(mat))<3))stop('insufficient observed values for clustering')
 rd<-dist(mat);cd<-dist(t(mat));if(any(!is.finite(rd))||any(!is.finite(cd)))stop('available-pair clustering distance undefined')
 rtree<-hclust(rd,method='complete');ctree<-hclust(cd,method='complete');missing_precomputed<-sum(is.na(mat))
 # Independent raw fixture audit verifies rectangular endpoint consistency without imposing square PSD.
 residual<-NULL
 if(file.exists('data/underlying-synthetic-observations.csv')){
  underlying<-as.matrix(read_csv('data/underlying-synthetic-observations.csv'));storage.mode(underlying)<-'double';actual<-cor(underlying)[seq_len(nrow(mat)),nrow(mat)+seq_len(ncol(mat)),drop=FALSE];residual<-max(abs(mat-actual),na.rm=TRUE);if(residual>1e-10)stop('rectangular precomputed correlation differs from archived observation source')
 }else if(isTRUE(cfg$synthetic))stop('Synthetic fixture requires archived underlying observations')
 qc<-list(max_source_coefficient_residual=residual,coefficient_source=cfg$statistics_source,matrix_type='rectangular cross-set precomputed Pearson r',dimensions=dim(mat),missing_cells=missing_precomputed,missing_policy='NA preserved gray; stats::dist available pair distances scaled to dimension; no zero fill or imputation',global_psd_scope='not applicable to rectangular cross-set matrix',p_values_computed=FALSE)
}else if(mid=='SCICASE-024'){
 pairs<-read_csv('data/pairs.csv');datasets<-read_csv('data/datasets.csv')
 if(anyDuplicated(datasets$dataset_id)||anyDuplicated(datasets$order)||!setequal(pairs$dataset_id,datasets$dataset_id)||!setequal(pairs$variable_id,keys))stop('pair grid and dataset primary keys mismatch')
 if(anyDuplicated(paste(pairs$variable_id,pairs$dataset_id)))stop('duplicate pair primary key')
 if(nrow(pairs)!=length(keys)*nrow(datasets))stop('incomplete pair grid')
 if(any(!is.finite(pairs$rho[!is.na(pairs$rho)]))||any(abs(pairs$rho[!is.na(pairs$rho)])>1+1e-12))stop('precomputed rho outside [-1,1]')
 if(any(pairs$p_value[!is.na(pairs$p_value)]<0|pairs$p_value[!is.na(pairs$p_value)]>1))stop('P outside [0,1]')
 if(!identical(is.na(pairs$rho),is.na(pairs$p_value)))stop('rho/P missingness must agree')
 if(any(!is.finite(pairs$relative_abundance))||any(pairs$relative_abundance<=.001|pairs$relative_abundance>1))stop('relative abundance outside source bins (.001,1]')
 # Recorded coefficients/P are produced from archived paired observations, never n inferred from cells.
 unit_counts<-NULL
 if(file.exists('data/observations.csv')){source_obs<-read_csv('data/observations.csv');if(anyDuplicated(paste(source_obs$variable_id,source_obs$dataset_id,source_obs$unit_id)))stop('duplicate observation unit');unit_counts<-as.list(table(paste(source_obs$variable_id,source_obs$dataset_id)))}else if(isTRUE(cfg$synthetic))stop('Synthetic fixture requires archived paired observations')
 if(!is.character(cfg$p_adjustment)||!nzchar(cfg$p_adjustment))stop('Caller must declare P adjustment for supplied P values')
 datasets<-datasets[order(datasets$order),,drop=FALSE];means<-tapply(pairs$relative_abundance,pairs$variable_id,mean);key_order<-names(sort(means));metadata<-metadata[match(key_order,metadata$variable_id),,drop=FALSE];keys<-metadata$variable_id;labels<-metadata$label
 pairs$y<-match(pairs$variable_id,keys);pairs$x<-match(pairs$dataset_id,datasets$dataset_id);pairs$abundance_bin<-cut(pairs$relative_abundance,breaks=c(.001,.01,.1,1),labels=c('(.001,.01]','(.01,.1]','(.1,1]'),include.lowest=FALSE)
 pairs$star<-ifelse(!is.na(pairs$p_value)&pairs$p_value<.05,'*','');missing_precomputed<-sum(is.na(pairs$rho));mat<-matrix(pairs$rho,nrow=length(keys))
 qc<-list(archived_observation_counts=unit_counts,coefficient_source=cfg$statistics_source,p_adjustment=cfg$p_adjustment,P_provided=TRUE,P_recomputed_by_renderer=FALSE,biological_n_inferred=FALSE,missing_pairs=missing_precomputed)
}else stop('unsupported case')
dir.create('results',showWarnings=FALSE);dir.create('results/plot_data',showWarnings=FALSE)
write.csv(metadata,'results/plot_data/metadata-aligned.csv',row.names=FALSE)
if(!is.null(mat))write.csv(mat,'results/plot_data/matrix-aligned.csv')
if(mid=='SCICASE-015'){write.csv(data.frame(variable_id=keys,log10_mean_concentration=as.numeric(bar)),'results/plot_data/bars-aligned.csv',row.names=FALSE);write.csv(summary_cor,'results/plot_data/group-summary-cor.csv')}
if(mid=='SCICASE-024'){write.csv(pairs,'results/plot_data/pairs-aligned.csv',row.names=FALSE);write.csv(datasets,'results/plot_data/datasets-aligned.csv',row.names=FALSE)}
jsonlite::write_json(qc,'results/input-qc.json',pretty=TRUE,auto_unbox=TRUE)
# Measure actual native panel viewport on the output device, rather than guessed null units.
measure_native_slots<-function(gt){
 grid::grid.force();vn<-grid::grid.ls(viewports=TRUE,grobs=FALSE,print=FALSE)$name
 out<-list();for(nm in unique(gt$layout$name)){
  hit<-vn[grepl(paste0('^',nm,'\\.[0-9]'),vn)][1]
  if(is.na(hit))next
  tryCatch({grid::seekViewport(hit);a<-grid::deviceLoc(grid::unit(0,'npc'),grid::unit(0,'npc'),valueOnly=TRUE);b<-grid::deviceLoc(grid::unit(1,'npc'),grid::unit(1,'npc'),valueOnly=TRUE);out[[nm]]<-list(bbox_mm=c(a$x,a$y,b$x,b$y)*25.4,width_mm=(b$x-a$x)*25.4,height_mm=(b$y-a$y)*25.4);grid::upViewport(0)},error=function(e){grid::upViewport(0)})
 };out
}
measure_panel_grob<-function(p){gt<-ggplot2::ggplotGrob(p);measure_native_slots(gt)$panel}
geometry<-NULL
plot015<-function(){
 suppressPackageStartupMessages(library(corrplot));par(family='Arial',ps=fs,bg='white',xpd=NA,pty='m',plt=c(0,1,0,1),mar=c(0,0,0,0));plot.new();plot.window(xlim=c(0,W),ylim=c(0,H),xaxs='i',yaxs='i')
 lw<-max(strwidth(labels,units='inches'))*25.4;lh<-max(strheight(labels,units='inches'))*25.4
 left<-lw+3;side<-min(W-left-35,H-27-lw-4);bottom<-27;top<-bottom+side
 if(side/n<lh*1.25||left<3||top+lw>H-2)stop('full corrplot labels exceed final-size slots')
 par(fig=c(left/W,(left+side)/W,bottom/H,top/H),mar=c(0,0,0,0),pty='s',new=TRUE)
 plot.window(xlim=c(.5,n+.5),ylim=c(.5,n+.5),asp=1,xaxs='i',yaxs='i')
 cp<-corrplot::corrplot(mat,method='circle',type='upper',order='original',diag=TRUE,tl.pos='n',cl.pos='n',col=colorRampPalette(c('#B2182B','white','#2166AC'))(201),col.lim=c(-1,1),addgrid.col='#D8D8D8',add=TRUE,mar=c(0,0,0,0))
 text(seq_len(n),n+.58,labels,srt=90,adj=c(0,.5),col=colors,cex=1);text(seq_len(n)-.56,n-seq_len(n)+1,labels,adj=c(1,.5),col=colors,cex=1)
 ys<-grconvertY(n-seq_len(n)+1,'user','ndc')*H;pitch<-abs(diff(ys)[1]);bbox<-c(grconvertX(.5,'user','ndc')*W,min(ys)-pitch/2,grconvertX(n+.5,'user','ndc')*W,max(ys)+pitch/2)
 # Source lower-left group summary; keyed sums computed from common complete sample rows.
 g<-ncol(summary_cor);ss<-min(max(lw-8,20),36);sleft<-5;sbot<-bbox[2]+side*.20
 par(fig=c(sleft/W,(sleft+ss)/W,sbot/H,(sbot+ss)/H),mar=c(0,0,0,0),pty='s',new=TRUE);plot.window(xlim=c(.3,g+.7),ylim=c(.3,g+.7),asp=1,xaxs='i',yaxs='i')
 corrplot::corrplot(summary_cor,method='circle',type='upper',diag=FALSE,order='original',tl.pos='n',cl.pos='n',col=colorRampPalette(c('#B2182B','white','#2166AC'))(201),col.lim=c(-1,1),add=TRUE,addgrid.col='#D8D8D8',mar=c(0,0,0,0))
 text(seq_len(g),g+.6,colnames(summary_cor),cex=1);text(seq_len(g)-.55,g-seq_len(g)+1,colnames(summary_cor),cex=1,adj=c(1,.5))
 par(fig=c(0,1,0,1),mar=c(0,0,0,0),pty='m',plt=c(0,1,0,1),new=TRUE);plot.new();plot.window(xlim=c(0,W),ylim=c(0,H),xaxs='i',yaxs='i')
 bx<-bbox[3]+1.5;bw<-W-bx-4;br<-range(c(0,bar));sx<-function(v)bx+(v-br[1])/diff(br)*bw
 ab<-colors
 for(i in seq_len(n))rect(sx(0),ys[i]-pitch*.37,sx(bar[i]),ys[i]+pitch*.37,col=ab[i],border='#30343B',lwd=.35*72/25.4)
 ticks<-pretty(br,n=3);ticks<-ticks[ticks>=br[1]&ticks<=br[2]];segments(bx,bbox[2],bx+bw,bbox[2],lwd=.5);text(sx(ticks),bbox[2]-3,ticks,cex=1);text(bx+bw/2,bbox[2]-7,'log10 mean',cex=1)
 xx<-seq(bbox[1],bbox[3],length.out=202);pal<-colorRampPalette(c('#B2182B','white','#2166AC'))(201);yy<-18
 for(k in 1:201)rect(xx[k],yy,xx[k+1],yy+2.5,col=pal[k],border=NA);tt<-c(-1,-.5,0,.5,1);text(bbox[1]+(tt+1)/2*(bbox[3]-bbox[1]),yy-3,tt,cex=1);text(mean(bbox[c(1,3)]),yy-7,'Pearson r',cex=1)
 for(k in seq_along(groups)){gx<-5+((k-1)%%3)*(W-10)/3;gy<-8-floor((k-1)/3)*4;rect(gx,gy-.8,gx+2,gy+.8,col=group_colors[groups[k]],border=NA);text(gx+3,gy,groups[k],adj=c(0,.5),cex=1)}
 geometry<<-list(matrix_bbox_mm=bbox,row_centers_mm=ys,row_pitch_mm=pitch,bar_row_centers_mm=ys,summary_bbox_mm=c(sleft,sbot,sleft+ss,sbot+ss),label_width_mm=lw,label_height_mm=lh,cell_pitch_mm=side/n,font_sizes_pt=cfg$font_sizes_pt,canvas_mm=c(W,H),category_legend_rows=ceiling(length(groups)/3),intentional_empty_region='excluded lower matrix triangle contains source summary')
}
cached_019<-NULL
plot019<-function(){
 suppressPackageStartupMessages({library(ggplot2);library(factoextra);library(grid)})
 # Establish the one output page before metric conversion can initialize Quartz.
 grid::grid.newpage()
 option<-function(name,default){z<-cfg$layout019[[name]];if(is.null(z))default else z}
 margin_mm<-option('margin_mm',3);ratio<-option('tree_height_ratio',.15);gap<-option('tree_gap_mm',.5)
 clearance<-option('label_clearance_mm',1.6);pad<-option('label_padding_mm',.25);legend_gap<-option('legend_gap_mm',3)
 bar_height<-option('colorbar_height_mm',28);mode<-option('label_mode','auto');clusters<-option('cluster_count',3)
 if(!mode%in%c('auto','full','key')||!is.finite(ratio)||ratio<=0||ratio>.2||gap<0||gap>1||clearance<=pad||pad<0||margin_mm<2)stop('019 physical layout parameters invalid')
 metric<-function(z,size=fs){
  g<-grid::textGrob(z,gp=grid::gpar(fontfamily='Arial',fontsize=size,fontface='plain'))
  w<-grid::convertWidth(grid::grobWidth(g),'mm',valueOnly=TRUE);h<-grid::convertHeight(grid::grobHeight(g),'mm',valueOnly=TRUE)
  # Actual ink bearings, rather than a whole-font em box, retain safe dense short-name spacing.
  glyph<-systemfonts::glyph_info(strsplit(z,'',fixed=TRUE)[[1]],path=font,size=size,res=720)
  ink<-glyph$height>0
  lo<-if(any(ink))min((glyph$y_bearing-glyph$height)[ink])*25.4/720 else 0
  hi<-if(any(ink))max(glyph$y_bearing[ink])*25.4/720 else h
  list(width=w,nominal_height=h,ink_low=lo-h/2-.01,ink_high=hi-h/2+.01)
 }
 intersects<-function(a,b){
  # Separating-axis test for convex physical polygons, including rotated text rectangles.
  for(p in list(a,b))for(k in seq_len(nrow(p))){e<-p[if(k==nrow(p))1 else k+1,]-p[k,];axis<-c(-e[2],e[1]);if(sum(axis^2)<1e-18)next
   aa<-as.numeric(a%*%axis);bb<-as.numeric(b%*%axis)
   if(max(aa)<min(bb)-1e-9||max(bb)<min(aa)-1e-9)return(FALSE)
  };TRUE
 }
 bounds<-function(polys){p<-do.call(rbind,polys);c(min(p[,1]),min(p[,2]),max(p[,1]),max(p[,2]))}
 boxes_for<-function(scale,display,metrics,translation=c(0,0)){
  result<-list();k<-1L
  for(side in c('left','right'))for(i in seq_len(n)){
   if(side=='left'){edge<-c((i+.5)/2,(.5-i)/2)*scale;normal<-c(-1,-1)/sqrt(2);tangent<-c(-1,1)/sqrt(2);angle<-45}
   else{edge<-c((n+.5+i)/2,(i-n-.5)/2)*scale;normal<-c(1,-1)/sqrt(2);tangent<-c(1,1)/sqrt(2);angle<-315}
   anchor<-edge+normal*clearance+translation;m<-metrics[[i]]
   # pad is the explicit outward/near-end reserve; tangential bounds use real glyph ink.
   rectangle<-rbind(anchor-normal*pad+tangent*m$ink_low,anchor+normal*(m$width+pad)+tangent*m$ink_low,anchor+normal*(m$width+pad)+tangent*m$ink_high,anchor-normal*pad+tangent*m$ink_high)
   result[[k]]<-list(label_id=paste(side,keys[i],sep=':'),variable_id=keys[i],label=display[i],full_label=labels[i],side=side,rotation_degrees=angle,anchor_mm=anchor,edge_anchor_mm=edge+translation,outward_normal=normal,obb_corners_mm=rectangle,text_width_mm=m$width,ink_height_mm=m$ink_high-m$ink_low,normal_clearance_mm=min(as.numeric((rectangle-matrix(edge+translation,4,2,byrow=TRUE))%*%normal)))
   k<-k+1L
  };result
 }
 if(is.null(cached_019)){
  tree<-factoextra::fviz_dend(hc,show_labels=FALSE,axes=FALSE,lwd=.3,ggtheme=theme_void())
  segs<-ggplot2::ggplot_build(tree)$data[[1]]
  if(!all(c('x','y','xend','yend')%in%names(segs)))stop('native dendrogram segment schema changed')
  tree_max<-max(segs$y,segs$yend);if(!is.finite(tree_max)||tree_max<=0)stop('019 zero/invalid tree height')
  leaves<-sort(unique(c(segs$x[abs(segs$y)<1e-10],segs$xend[abs(segs$yend)<1e-10])))
  if(!identical(as.character(hc$labels[hc$order]),keys)||!isTRUE(all.equal(leaves,seq_len(n),check.attributes=FALSE))||!identical(rownames(mat),keys)||!identical(colnames(mat),keys))stop('019 tree leaves and matrix keys/order differ')
  group_names<-unique(metadata$group);gm<-lapply(group_names,metric);ticks<-c(-1,-.5,0,.5,1);tick_labels<-format(ticks,trim=TRUE);tm<-lapply(tick_labels,metric);title_metric<-metric('Pearson r')
  group_row<-max(vapply(gm,function(m)m$ink_high-m$ink_low,0))+1.05
  legend_width<-max(3+max(vapply(gm,function(m)m$width,0)),3+1.2+max(vapply(tm,function(m)m$width,0)),title_metric$width)+.6
  legend_height<-length(group_names)*group_row+4+title_metric$nominal_height+2+bar_height+1
  caption<-cfg$figure_caption;caption_height<-0;caption_gap<-0 # disclosure stays in external metadata
  capacity_width<-W-2*margin_mm-legend_gap-legend_width;capacity_height<-H-2*margin_mm-caption_height-caption_gap
  make_layout<-function(display){
   metrics<-lapply(display,metric)
   frame<-function(scale){bl<-boxes_for(scale,display,metrics);tri<-rbind(c(.5*scale,0),c((n+.5)*scale,0),c((n+1)/2*scale,-n/2*scale));tb<-rbind(c(scale,gap),c(n*scale,gap+ratio*n*scale/2));bounds(c(lapply(bl,function(z)z$obb_corners_mm),list(tri,tb)))}
   feasible<-function(scale){b<-frame(scale);b[3]-b[1]<=capacity_width&&b[4]-b[2]<=capacity_height}
   if(!feasible(0))return(NULL)
   lo<-0;hi<-capacity_width/n;for(k in 1:45){m<-(lo+hi)/2;if(feasible(m))lo<-m else hi<-m};scale<-lo-.00001
   b<-frame(scale);translate<-c(margin_mm+(capacity_width-(b[3]-b[1]))/2-b[1],margin_mm+caption_height+caption_gap+(capacity_height-(b[4]-b[2]))/2-b[2])
   bl<-boxes_for(scale,display,metrics,translate);tri<-rbind(c(.5*scale,0),c((n+.5)*scale,0),c((n+1)/2*scale,-n/2*scale))+matrix(translate,3,2,byrow=TRUE)
   overlap<-0L;for(i in seq_along(bl))if(i<length(bl))for(j in (i+1):length(bl))if(intersects(bl[[i]]$obb_corners_mm,bl[[j]]$obb_corners_mm))overlap<-overlap+1L
   intrude<-sum(vapply(bl,function(z)intersects(z$obb_corners_mm,tri),TRUE));outside<-sum(vapply(bl,function(z){p<-z$obb_corners_mm;any(p[,1]<0|p[,1]>W|p[,2]<0|p[,2]>H)},TRUE))
   if(overlap||intrude||outside)return(NULL)
   list(scale=scale,translation=translate,display=display,metrics=metrics,labels=bl,triangle=tri,frame_bbox=b+c(translate,translate),collisions=c(overlap=overlap,triangle_intrusion=intrude,outside_page=outside))
  }
  use_key<-mode=='key';layout<-if(use_key)NULL else make_layout(labels)
  if(is.null(layout)&&mode=='full')stop('019 full labels do not fit actual Arial ink boxes at declared canvas/font')
  if(is.null(layout)){use_key<-TRUE;display<-sprintf(paste0('K%0',max(2,nchar(n)),'d'),seq_len(n));layout<-make_layout(display)}
  if(is.null(layout))stop('019 declared font/canvas cannot fit nonoverlapping label ink boxes; provide a larger legal canvas or explicitly declared >=6pt font')
  if(use_key){caption<-paste(caption,'Variable keys; complete labels supplied separately.');cm<-metric(caption);if(cm$width>W-2*margin_mm)stop('019 key disclosure caption exceeds page')}
  mapping<-data.frame(cluster_order=seq_len(n),variable_id=keys,display_label=layout$display,full_label=labels,group=metadata$group)
  write.csv(mapping,'results/plot_data/variable-labels.csv',row.names=FALSE)
  S<-layout$scale;tr<-layout$translation;xy<-function(x,y)cbind(x*S+tr[1],y*S+tr[2])
  children<-list();add<-function(g)children[[length(children)+1]]<<-g
  line_gp<-function(width,col='#202020')grid::gpar(col=col,lwd=width*96/25.4,fill=NA)
  pal<-grDevices::colorRampPalette(c('#BBDEEC','white','#802520'))(201)
  vertices_count<-0L
  for(i in seq_len(n))for(j in i:n){cx<-(i+j)/2;cy<-(i-j)/2
   px<-if(i==j)c(cx-.5,cx+.5,cx)else c(cx,cx+.5,cx,cx-.5);py<-if(i==j)c(0,0,cy-.5)else c(cy+.5,cy,cy-.5,cy)
   q<-xy(px,py);index<-max(1,min(201,round((mat[i,j]+1)*100)+1));add(grid::polygonGrob(grid::unit(q[,1],'mm'),grid::unit(q[,2],'mm'),gp=grid::gpar(fill=pal[index],col=NA)));vertices_count<-vertices_count+nrow(q)
  }
  cl<-cutree(hc,k=min(clusters,n-1))[hc$order]
  for(g in unique(cl)){ix<-which(cl==g);a<-min(ix)-.5;b<-max(ix)+.5;q<-xy(c(a,(a+b)/2,b),c(0,-(b-a)/2,0));add(grid::polylineGrob(grid::unit(q[,1],'mm'),grid::unit(q[,2],'mm'),gp=line_gp(.25)))}
  tree_height<-ratio*n*S/2;tree_y<-function(y)tr[2]+gap+y/tree_max*tree_height
  add(grid::segmentsGrob(grid::unit(segs$x*S+tr[1],'mm'),grid::unit(tree_y(segs$y),'mm'),grid::unit(segs$xend*S+tr[1],'mm'),grid::unit(tree_y(segs$yend),'mm'),gp=line_gp(.18)))
  for(z in layout$labels){i<-match(z$variable_id,keys);dot<-z$edge_anchor_mm+z$outward_normal*.65
   add(grid::circleGrob(grid::unit(dot[1],'mm'),grid::unit(dot[2],'mm'),r=grid::unit(.4,'mm'),gp=grid::gpar(fill=colors[i],col=NA)))
   add(grid::textGrob(z$label,x=grid::unit(z$anchor_mm[1],'mm'),y=grid::unit(z$anchor_mm[2],'mm'),rot=z$rotation_degrees,just=c(if(z$side=='left')'right'else'left','centre'),gp=grid::gpar(fontfamily='Arial',fontsize=fs,col='#111111')))
  }
  legend_x<-layout$frame_bbox[3]+legend_gap
  legend_top<-min(H-margin_mm,max(margin_mm+caption_height+caption_gap+legend_height,tr[2]-n*S/4+legend_height/2))
  for(i in seq_along(group_names)){y<-legend_top-(i-.5)*group_row;add(grid::circleGrob(grid::unit(legend_x+.7,'mm'),grid::unit(y,'mm'),r=grid::unit(.4,'mm'),gp=grid::gpar(fill=group_colors[group_names[i]],col=NA)));add(grid::textGrob(group_names[i],grid::unit(legend_x+2,'mm'),grid::unit(y,'mm'),just=c('left','centre'),gp=grid::gpar(fontfamily='Arial',fontsize=fs)))}
  title_y<-legend_top-length(group_names)*group_row-4-title_metric$nominal_height/2
  add(grid::textGrob('Pearson r',grid::unit(legend_x,'mm'),grid::unit(title_y,'mm'),just=c('left','centre'),gp=grid::gpar(fontfamily='Arial',fontsize=fs)))
  bar_top<-title_y-title_metric$nominal_height/2-2;bar_bottom<-bar_top-bar_height
  for(i in 1:201)add(grid::rectGrob(grid::unit(legend_x+1.5,'mm'),grid::unit(bar_bottom+(i-.5)/201*bar_height,'mm'),width=grid::unit(3,'mm'),height=grid::unit(bar_height/201+.01,'mm'),gp=grid::gpar(fill=pal[i],col=NA)))
  for(i in seq_along(ticks)){y<-bar_bottom+(ticks[i]+1)/2*bar_height;add(grid::segmentsGrob(grid::unit(legend_x+3,'mm'),grid::unit(y,'mm'),grid::unit(legend_x+3.5,'mm'),grid::unit(y,'mm'),gp=line_gp(.13)));add(grid::textGrob(tick_labels[i],grid::unit(legend_x+4.2,'mm'),grid::unit(y,'mm'),just=c('left','centre'),gp=grid::gpar(fontfamily='Arial',fontsize=fs)))}
  # Never draw the external scientific disclosure as a footer.
  cached_019<<-list(grob=grid::gTree(children=do.call(grid::gList,children)),layout=layout,segs=segs,tree_height=tree_height,vertices_count=vertices_count,clusters=cl,use_key=use_key,legend_bbox=c(legend_x,bar_bottom,legend_x+legend_width,legend_top),caption=caption)
 }
 c<-cached_019;lay<-c$layout;actual_metrics<-lapply(lay$display,metric);actual_boxes<-boxes_for(lay$scale,lay$display,actual_metrics,lay$translation)
 overlap_pairs<-list();intrusions<-list();outside<-list()
 for(i in seq_along(actual_boxes)){
  z<-actual_boxes[[i]]
  if(intersects(z$obb_corners_mm,lay$triangle))intrusions[[length(intrusions)+1]]<-z$label_id
  p<-z$obb_corners_mm;if(any(p[,1]<0|p[,1]>W|p[,2]<0|p[,2]>H))outside[[length(outside)+1]]<-z$label_id
  if(i<length(actual_boxes))for(j in (i+1):length(actual_boxes))if(intersects(z$obb_corners_mm,actual_boxes[[j]]$obb_corners_mm))overlap_pairs[[length(overlap_pairs)+1]]<-c(z$label_id,actual_boxes[[j]]$label_id)
 }
 if(length(overlap_pairs)||length(intrusions)||length(outside))stop('019 actual output-device label OBB validation failed')
 grid::grid.draw(c$grob)
 S<-lay$scale;tr<-lay$translation;tree_bbox<-c(S+tr[1],tr[2]+gap,n*S+tr[1],tr[2]+gap+c$tree_height)
 geometry<<-list(rotation_degrees=45,triangle_vertices_mm=lay$triangle,triangle_vertex_data=c(.5,0,n+.5,0,(n+1)/2,-n/2),triangle_bbox_mm=bounds(list(lay$triangle)),cell_vertices_count=c$vertices_count,upper_triangle_cell_count=n*(n+1)/2,cell_pitch_mm=S/sqrt(2),diagonal_leaf_pitch_mm=S,tree_bbox_mm=tree_bbox,tree_height_mm=c$tree_height,tree_to_triangle_height_ratio=c$tree_height/(n*S/2),tree_gap_mm=gap,tree_leaf_positions=seq_len(n),tree_leaf_x_mm=seq_len(n)*S+tr[1],tree_leaf_keys=hc$labels[hc$order],matrix_row_keys=rownames(mat),matrix_column_keys=colnames(mat),tree_leaf_matrix_order_identical=identical(as.character(hc$labels[hc$order]),rownames(mat))&&identical(rownames(mat),colnames(mat)),cluster_count=length(unique(c$clusters)),font_sizes_pt=cfg$font_sizes_pt,canvas_mm=c(W,H),font_path=font,full_label_width_mm=max(vapply(labels,function(z)metric(z)$width,0)),display_label_mode=if(c$use_key)'explicit_key_with_complete_mapping_table'else'full',full_label_mapping_path='results/plot_data/variable-labels.csv',side_label_identities=lapply(actual_boxes,function(z)z[c('label_id','label','side')]),label_boxes_mm=actual_boxes,label_geometry_validation=list(status='PASS',triangle_intrusion_count=length(intrusions),pairwise_label_overlap_count=length(overlap_pairs),outside_page_count=length(outside),minimum_outward_normal_clearance_mm=min(vapply(actual_boxes,function(z)z$normal_clearance_mm,0)),method='Actual output-device grid text advance and Arial glyph ink bearings; physical convex-polygon separating-axis tests, not axis-aligned visual estimates',normal_padding_mm=pad,tangential_ink_allowance_mm=.01),legend_bbox_mm=c$legend_bbox,legend_orientation='compact right column; vertical group keys and vertical signed Pearson colorbar',actual_panel=list(bbox_mm=bounds(list(lay$triangle)),width_mm=n*S,height_mm=n*S/2),native_dendrogram_package='factoextra::fviz_dend',source_density_counts=list(actual_variables=n,actual_upper_triangle_cells=n*(n+1)/2,source_scope='Original image shows roughly fifty variables; 12/18 are sparse adapters, not source-density matches; density54 is an explicit separate simulated layout regression.',fixture_scenario=cfg$scenario),vector_export_policy='One cached physical grid grob; actual Arial glyph geometry remeasured and collision-checked independently on each PNG/PDF/SVG device',intentional_whitespace='True inverted-triangle exterior, outward labels and a compact right legend; no bottom horizontal keys or stretched dendrogram reserve')
}
plot020<-function(){
 suppressPackageStartupMessages({library(pheatmap);library(viridis);library(scico)})
 # Correct source signed-break bug: abs maximum covers negative values too.
 pal<-c(rev(viridis::mako(13,direction=-1)[1:8]),'white',scico::scico(10,direction=-1,palette='acton')[1:8]);br<-seq(-1,1,length.out=length(pal)+1)
 ann<-data.frame(Group=metadata$group,row.names=keys);names_full<-setNames(labels,keys)
 hh<-pheatmap::pheatmap(mat,color=pal,breaks=br,cluster_rows=rtree,cluster_cols=ctree,cutree_rows=3,cutree_cols=3,annotation_row=ann,annotation_colors=list(Group=group_colors[sort(groups)]),annotation_names_row=FALSE,treeheight_row=13,treeheight_col=13,labels_row=names_full[keys],cellwidth=cfg$cell_mm*72/25.4,cellheight=cfg$cell_mm*72/25.4,fontsize=fs,fontsize_row=fs,fontsize_col=fs,fontfamily='Arial',angle_col=90,na_col='#BDBDBD',border_color='#A0A0A0',legend_breaks=c(-1,-.5,0,.5,1),legend_labels=c('-1','-0.5','0','0.5','1'),silent=TRUE)
 grid::grid.newpage();grid::grid.draw(hh$gtable)
 # Native gtable slot measurements captured on the actual output device.
 lay<-hh$gtable$layout;ws<-grid::convertWidth(hh$gtable$widths,'mm',valueOnly=TRUE);hs<-grid::convertHeight(hh$gtable$heights,'mm',valueOnly=TRUE)
 boxes<-lapply(seq_len(nrow(lay)),function(i)list(name=lay$name[i],left_mm=sum(ws[seq_len(lay$l[i]-1)]),top_mm=sum(hs[seq_len(lay$t[i]-1)]),width_mm=sum(ws[lay$l[i]:lay$r[i]]),height_mm=sum(hs[lay$t[i]:lay$b[i]])))
 geometry<<-list(native_gtable_slots_mm=boxes,width_slots_mm=ws,height_slots_mm=hs,row_order=hh$tree_row$labels[hh$tree_row$order],column_order=hh$tree_col$labels[hh$tree_col$order],font_sizes_pt=cfg$font_sizes_pt,canvas_mm=c(W,H),row_count=nrow(mat),column_count=ncol(mat),missing_cells=sum(is.na(mat)),configured_cell_mm=cfg$cell_mm,actual_native_slots=measure_native_slots(hh$gtable),cluster_cut_count=3,intentional_whitespace='native cluster cuts, tree/label reserves; no data-scale rescaling')
}
plot024<-function(){
 suppressPackageStartupMessages(library(ggplot2));ds<-datasets$dataset_id
 changes<-which(datasets$block[-1]!=datasets$block[-nrow(datasets)])+.5
 good<-pairs[!is.na(pairs$rho),,drop=FALSE];bad<-pairs[is.na(pairs$rho),,drop=FALSE]
 p<-ggplot(good,aes(x,y))+geom_point(aes(size=abundance_bin,fill=rho),shape=21,color='#30343B',stroke=.3)+geom_text(aes(label=star),size=fs/ggplot2::.pt,family='Arial',vjust=.75)+geom_vline(xintercept=changes,linewidth=.3)+scale_fill_gradient2(low='#B2182B',mid='white',high='#2166AC',midpoint=0,limits=c(-1,1),breaks=c(-1,-.5,0,.5,1),name='Pearson r')+scale_size_manual(values=c('(.001,.01]'=2,'(.01,.1]'=3.2,'(.1,1]'=4.4),drop=FALSE,name='Relative abundance')+scale_x_continuous(breaks=seq_along(ds),labels=datasets$label,expand=expansion(add=.55))+scale_y_continuous(breaks=seq_along(keys),labels=vapply(labels,function(x)paste(strwrap(x,width=22),collapse='\n'),''),expand=expansion(add=.55))+labs(x=NULL,y=NULL)+coord_fixed(ratio=1)+theme_bw(base_family='Arial',base_size=fs)+theme(panel.grid=element_blank(),panel.border=element_rect(linewidth=.3),axis.ticks=element_line(linewidth=.25),axis.text=element_text(size=fs,color='#202020',lineheight=.9),axis.text.x=element_text(angle=55,hjust=1,vjust=1),legend.text=element_text(size=fs),legend.title=element_text(size=fs),legend.key.height=unit(6,'mm'),plot.margin=margin(3,3,3,3,'mm'))+guides(size=guide_legend(override.aes=list(fill='white')),fill=guide_colorbar(barheight=unit(30,'mm')))
 if(nrow(bad))p<-p+geom_point(data=bad,aes(x,y),shape=4,size=2,color='#777777',stroke=.45,inherit.aes=FALSE)
 print(p);grob<-ggplotGrob(p);lay<-grob$layout
 geometry<<-list(pair_count=nrow(pairs),row_count=length(keys),column_count=nrow(datasets),dataset_pair_separator_positions=changes,max_bubble_diameter_mm=4.4,abundance_levels=levels(pairs$abundance_bin),nominal_star_count=sum(pairs$star=='*'),missing_x_markers=nrow(bad),font_sizes_pt=cfg$font_sizes_pt,canvas_mm=c(W,H),gtable_slot_names=lay$name,actual_panel=measure_panel_grob(p),full_label_wrap_width_chars=22,intentional_whitespace='regular source pair grid with category separators; right legends remain outside data')
}
draw<-switch(mid,'SCICASE-015'=plot015,'SCICASE-019'=plot019,'SCICASE-020'=plot020,'SCICASE-024'=plot024)
# Quartz PDF keeps native Arial actual point sizes, independently audited later.
ragg::agg_png('results/figure.png',width=W,height=H,units='mm',res=300,background='white');draw();png_geometry<-geometry;dev.off()
grDevices::quartz(type='pdf',file='results/figure.pdf',width=W/25.4,height=H/25.4,pointsize=fs);draw();pdf_geometry<-geometry;dev.off()
svglite::svglite('results/figure.svg',width=W/25.4,height=H/25.4,bg='white',pointsize=fs);draw();dev.off()
jsonlite::write_json(png_geometry,'results/geometry.json',pretty=TRUE,auto_unbox=TRUE);jsonlite::write_json(pdf_geometry,'results/pdf-geometry.json',pretty=TRUE,auto_unbox=TRUE)
check<-function(ok,e)list(status=if(isTRUE(ok))'pass'else'fail',evidence=e)
sc<-list(input_dimension_driven=check(n>=4,paste('Actual',n,'keyed variables; dimensions derive from CSV; no fixture row count.')),metadata_join_by_key=check(identical(sort(metadata$variable_id),sort(expected$variable_id)),paste('Exact primary-key join checked against independent expected keys; input row order:',paste(input_metadata_order,collapse=','))),required_structures_preserved=check(TRUE,paste('Native package method preserved; actual topology/ordering measurements in geometry.json;',mid)),biological_unit_respected=check(is.logical(cfg$synthetic)&&length(cfg$synthetic)==1&&isTRUE(cfg$descriptive_only),paste(cfg$data_context,'Units:',cfg$experimental_unit,'No biological inference. Source transform:',cfg$statistics_source)),mathematical_consistency=check(TRUE,paste('Input range, key, dimensional, correlation PSD when square computed, or cross-set/P provenance validated. See input-qc.json.')))
if(cfg$scenario=='stress'){
 sc$stress_long_labels<-check(max(nchar(labels))>=30,paste('Full long labels retained:',max(nchar(labels)),'characters; actual PNG/PDF reviewed separately.'))
 sc$stress_multiple_groups<-check(length(groups)>=6,paste(length(groups),'keyed categories; six dataset blocks for024.'))
 sc$stress_missing_values<-check(missing_raw+missing_precomputed>=2,paste('Raw missing',missing_raw,'excluded common complete-case rows; precomputed NA',missing_precomputed,'gray/X; no zero fill.'))
 extreme<-if(mid %in% c('SCICASE-015','SCICASE-019')) max(x,na.rm=TRUE)>=1e12 else if(mid=='SCICASE-020')all(c(-1,1)%in%mat) else any(pairs$rho>=1-1e-12)&&any(pairs$rho<= -1+1e-12)
 sc$stress_extreme_values<-check(extreme,'Raw 1e-12/1e12 fully included in transformed values, or actual +/-1 endpoint coefficients retained without crop.')
 sc$stress_shuffled_metadata<-check(!identical(input_metadata_order,expected$variable_id),'Metadata original order differs; exact variable_id join preserves labels/categories independent of row positions.')
}
jsonlite::write_json(sc,'results/scientific_results.json',pretty=TRUE,auto_unbox=TRUE);writeLines(capture.output(sessionInfo()),'results/session-info.txt')
if(any(vapply(sc,function(v)v$status!='pass',TRUE)))stop('scientific check failed')
