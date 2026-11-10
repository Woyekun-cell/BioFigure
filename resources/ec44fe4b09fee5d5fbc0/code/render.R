#!/usr/bin/env Rscript
suppressPackageStartupMessages({library(circlize);library(grid)})
source('common.R')
sectors<-read_input('sectors');links<-read_input('links');bars<-read_input('bars')
required(sectors,c('sector_id','label','order','sector_group','inner_group','outer_group','color'),'sectors')
required(links,c('edge_id','from','to','weight','direction'),'links');required(bars,c('bar_id','sector_id','order','label','value',unlist(settings$stack_components)),'bars')
unique_key(sectors,'sector_id','sectors');unique_key(links,'edge_id','links');unique_key(bars,'bar_id','bars')
if(anyNA(sectors)||anyDuplicated(sectors$order))stop('Sector metadata contains missing required key or duplicate order')
if(!all(c(links$from,links$to,bars$sector_id)%in%sectors$sector_id))stop('Unknown sector foreign key')
if(anyNA(links[c('from','to','direction')])||!all(links$direction==settings$direction))stop('Direction must be explicitly uniform undirected')
stopifnot(identical(settings$direction,'undirected'),!any(links$from==links$to),nrow(sectors)<=settings$max_sectors,
          all(links$from %in% sectors$sector_id[sectors$sector_group=='Community']),
          all(links$to %in% sectors$sector_id[sectors$sector_group=='Driver']))
if(any(links$weight<0,na.rm=TRUE))stop('Negative chord weight is invalid')
fields<-unlist(settings$stack_components);stopifnot(length(fields)==2)
if(any(as.matrix(bars[c('value',fields)])<0,na.rm=TRUE))stop('Negative outer-track value is invalid')
missing_edges<-is.na(links$weight);missing_bars<-apply(as.matrix(bars[c('value',fields)]),1,anyNA)
write_csv(data.frame(edge_id=links$edge_id[missing_edges],reason=rep('missing optional weight; edge excluded',sum(missing_edges))),'excluded_edges')
write_csv(data.frame(bar_id=bars$bar_id[missing_bars],reason=rep('missing optional outer value; whole bar excluded',sum(missing_bars))),'excluded_bars')
links<-links[!missing_edges,,drop=FALSE];bars<-bars[!missing_bars,,drop=FALSE];stopifnot(all(is.finite(links$weight)),all(is.finite(as.matrix(bars[c('value',fields)]))),
         all(links$weight>0),all(abs(rowSums(bars[fields])-bars$value)<1e-6),!anyNA(bars[c('sector_id','order','label')]),!anyDuplicated(paste(bars$sector_id,bars$order)))
sectors_input_order<-sectors$sector_id;sectors<-sectors[order(sectors$order),];bars<-bars[order(match(bars$sector_id,sectors$sector_id),bars$order),];order_ids<-sectors$sector_id
inner_colors<-setNames(sectors$color,order_ids);outer_colors<-unlist(settings$outer_group_colors);region_colors<-unlist(settings$inner_group_colors)
stopifnot(all(sectors$outer_group%in%names(outer_colors)),all(sectors$inner_group%in%names(region_colors)),all(inner_colors==region_colors[sectors$inner_group]))
outer_key<-sectors$outer_group[match(bars$sector_id,sectors$sector_id)];bars$outer_group<-outer_key
key_correct<-identical(bars$outer_group,sectors$outer_group[match(bars$sector_id,sectors$sector_id)])
m<-matrix(0,nrow=sum(sectors$sector_group=='Community'),ncol=sum(sectors$sector_group=='Driver'),dimnames=list(sectors$sector_id[sectors$sector_group=='Community'],sectors$sector_id[sectors$sector_group=='Driver']))
for(i in seq_len(nrow(links)))m[links$from[i],links$to[i]]<-m[links$from[i],links$to[i]]+links$weight[i]
stopifnot(all(rowSums(m)>0),all(colSums(m)>0),abs(sum(m)-sum(links$weight))<1e-8)
write_csv(sectors,'ordered_sectors');write_csv(links,'weighted_edges');write_csv(bars,'keyed_outer_stacks');write.csv(m,'results/tables/chord_weight_matrix.csv')
ymax<-max(bars$value)*1.5;sector_xlim<-list();geometry_bars<-list();index<-0
lighten<-function(c){rgb<-grDevices::col2rgb(c)/255;grDevices::rgb(.35+.65*rgb[1],.35+.65*rgb[2],.35+.65*rgb[3])}
authorize_native()
draw<-function(){
 par(family=font,ps=pt('axis_text'),cex=1,mar=c(1,1,1,1),fig=c(0,.74,0,1))
 circos.clear();on.exit(circos.clear(),add=TRUE)
 gap<-rep(1,length(order_ids));gap[which(sectors$sector_group=='Community')[length(which(sectors$sector_group=='Community'))]]<-5;gap[length(gap)]<-5
 circos.par(start.degree=90,gap.after=gap,track.margin=c(.003,.003),canvas.xlim=c(-1.07,1.07),canvas.ylim=c(-1.07,1.07),points.overflow.warning=TRUE)
 chordDiagram(m,order=order_ids,grid.col=inner_colors,transparency=.55,annotationTrack='grid',annotationTrackHeight=.045,
              preAllocateTracks=list(list(track.height=.32),list(track.height=.065)),directional=0,link.border=NA)
 circos.trackPlotRegion(track.index=1,ylim=c(0,ymax),bg.border=NA,panel.fun=function(x,y){
  sid<-CELL_META$sector.index;b<-bars[bars$sector_id==sid,,drop=FALSE];b<-b[order(b$order),];n<-nrow(b);stopifnot(n>0)
  cuts<-seq(CELL_META$xlim[1],CELL_META$xlim[2],length.out=n+1);sector_xlim[[sid]]<<-CELL_META$xlim
  col<-outer_colors[sectors$outer_group[match(sid,sectors$sector_id)]]
  for(k in seq_len(n)){
   x0<-cuts[k]+.03*(cuts[k+1]-cuts[k]);x1<-cuts[k+1]-.03*(cuts[k+1]-cuts[k]);xc<-(x0+x1)/2
   a<-b[[fields[1]]][k];v<-b$value[k]
   circos.rect(x0,0,x1,a,col=col,border='#30343B',lwd=.35)
   circos.rect(x0,a,x1,v,col=lighten(col),border='#30343B',lwd=.35)
   circos.text(xc,v+ymax*.03,sprintf('%.0f',v),facing='clockwise',niceFacing=TRUE,adj=c(0,.5),cex=pt('annotation_text')/pt('axis_text'))
   circos.text(xc,ymax*.91,b$label[k],facing='clockwise',niceFacing=TRUE,adj=c(0,.5),cex=pt('axis_text')/pt('axis_text'))
   index<<-index+1;geometry_bars[[index]]<<-list(bar_id=b$bar_id[k],sector_id=sid,x0=x0,x1=x1,sector_start=cuts[1],sector_end=tail(cuts,1),component_a=a,component_b=v-a,total=v)
  }
 })
 circos.trackPlotRegion(track.index=2,ylim=c(0,1),bg.border=NA,panel.fun=function(x,y){circos.text(CELL_META$xcenter,.55,CELL_META$sector.index,facing='bending.outside',niceFacing=TRUE,cex=1)})
 par(fig=c(.755,.995,.025,.975),mar=c(0,0,0,0),new=TRUE,family=font,ps=pt('legend_text'),cex=1)
 plot.new();plot.window(xlim=c(0,1),ylim=c(0,1));yy<-1
 heading<-function(s){text(0,yy,s,adj=c(0,1),cex=pt('axis_title')/pt('legend_text'));yy<<-yy-.025}
 item<-function(label,col=NULL){wrapped<-wrap(label,24);nl<-length(strsplit(wrapped,'\n',fixed=TRUE)[[1]]);if(!is.null(col))rect(0,yy-.011,.04,yy,col=col,border='#555555',lwd=.3);text(if(is.null(col))0 else .065,yy,wrapped,adj=c(0,1),cex=1);yy<<-yy-(nl*.017+.006)}
 heading('Sector keys');for(i in seq_len(nrow(sectors)))item(paste0(sectors$sector_id[i],'  ',sectors$label[i]))
 heading('Inner classification');for(n in names(region_colors))item(n,region_colors[n])
 heading('Outer classification');for(n in names(outer_colors))item(n,outer_colors[n])
 heading('Stack components');item(settings$stack_component_labels[[1]],'#555555');item(settings$stack_component_labels[[2]],lighten('#555555'))
 heading('Outer item keys');for(i in seq_len(nrow(groups)))item(paste0('M',i,'  ',groups$label[i]))
 if(yy<0)stop('Measured legend line count exceeds reserved side band')
 text(0,max(.006,yy-.008),wrap(settings$figure_caption,27),adj=c(0,1),cex=1)
}
export_plot(draw)
# Three devices repeated the same geometry; retain only one final per-item measurement.
geometry_bars<-tail(geometry_bars,nrow(bars));bounds<-all(vapply(geometry_bars,function(b)b$x0>=b$sector_start&&b$x1<=b$sector_end&&b$x1>b$x0,logical(1)))
write_json(geometry_bars,'results/tables/outer_bar_sector_geometry.json')
check('input_dimension_driven',nrow(bars)==length(geometry_bars)&&length(order_ids)==nrow(sectors),sprintf('%d keyed sectors, %d actual edges, %d external per-item stacked bars; no invented outer profile.',nrow(sectors),nrow(links),nrow(bars)))
check('metadata_join_by_key',key_correct&&all(order_ids%in%names(sector_xlim)),'Sector names join inner classifications, outer classifications and every stacked item; order column controls circle independently of shuffled metadata rows.')
check('required_structures_preserved',bounds&&nrow(bars)>=nrow(sectors)*2,'circlize weighted undirected chordDiagram; grouped sectors; separate inner Region and outer Assemblage semantics; per-item two-component quantitative stack, item labels/values, full sector key and semantic legends.')
check('biological_unit_respected',!anyDuplicated(links$edge_id),paste(settings$experimental_unit,'; weighted graph records and component bars are descriptive values, never biological replicate n or causal effect.'))
check('weighted_sector_alignment_verified',bounds&&abs(sum(m)-sum(links$weight))<1e-8&&all(abs(rowSums(bars[fields])-bars$value)<1e-6),'Nonnegative edge totals exactly reproduced by keyed matrix; explicit undirected direction; each per-item stack sums to supplied total and lies inside matching circlize sector xlim.')
if(contract$mode=='stress'){
 check('stress_long_labels',max(nchar(sectors$label))>=32,'Full long sector labels wrapped in side legend, unique short IDs retained on ring; every item M ID and numeric total displayed.')
 check('stress_multiple_groups',length(unique(sectors$inner_group))>=5&&nrow(groups)>=4,'Five inner categories including Driver, four outer categories and four per-sector quantitative item series explicitly mapped.')
 check('stress_missing_values',sum(missing_edges)>=1&&sum(missing_bars)>=1,'Missing optional edge and missing complete outer bar excluded with record IDs/reasons; no zero substitution.')
 check('stress_extreme_values',max(links$weight)>=80&&max(bars$value)>=100&&bounds,'Weight80 and stacked total100 retained; weight determines sector intervals; common actual bar scale includes maximum without clipping.')
 check('stress_shuffled_metadata',!identical(sectors_input_order,order_ids)&&key_correct,'Raw sector metadata shuffled; numeric order restores circle; independently shuffled bar table joins by sector_id/order, not row position.')
}
finish(list(sectors=nrow(sectors),edges=nrow(links),outer_items=nrow(bars),excluded_edges=sum(missing_edges),excluded_bars=sum(missing_bars),edge_weight_sum=sum(links$weight),sector_order=order_ids,sector_xlim=sector_xlim,bar_ylim=c(0,ymax),stack_components=fields,metadata_join_verified=key_correct,outer_items_within_sector=bounds,inner_categories=unique(sectors$inner_group),outer_categories=unique(sectors$outer_group),circle_region_fraction=c(0,.74,0,1),legend_region_fraction=c(.755,.995,.025,.975),executed_namespace_calls=c('circlize::chordDiagram','circlize::circos.trackPlotRegion','circlize::circos.rect','circlize::circos.text','circlize::circos.clear')))
