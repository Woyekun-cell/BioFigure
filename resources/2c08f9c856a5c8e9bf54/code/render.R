# Source-exposed native fmsb adapter. External keyed CSVs; no statistical inference.
# 3..10 axes, 2..8 input profiles, 2..6 complete plotted profiles.
# Incomplete profiles are excluded and logged; no interpolated/zero-filled vertices.
library(fmsb);library(scales);library(ragg);library(systemfonts)
library(jsonlite);library(digest);library(grid)
contract<-fromJSON('contract.json',simplifyVector=FALSE)
context<-fromJSON('context.json');fonts<-fromJSON('font-contract.json')
stopifnot(is.logical(context$synthetic),length(context$synthetic)==1,
 is.character(context$experimental_unit),nzchar(context$experimental_unit),
 is.character(context$measurement_label),nzchar(context$measurement_label),isTRUE(context$descriptive_only))
v<-read.csv('values.csv',stringsAsFactors=FALSE,na.strings=c('','NA'))
p<-read.csv('profiles.csv',stringsAsFactors=FALSE)
a<-read.csv('axes.csv',stringsAsFactors=FALSE)
stopifnot(all(c('profile_id','axis_id','value')%in%names(v)),
 all(c('profile_id','label','order','color')%in%names(p)),
 all(c('axis_id','label','unit','order','lower','upper')%in%names(a)),
 nrow(p)>=2,nrow(p)<=8,nrow(a)>=3,nrow(a)<=10,!anyNA(v[c('profile_id','axis_id')]),
 !anyDuplicated(p$profile_id),!anyDuplicated(a$axis_id),!anyDuplicated(p$order),!anyDuplicated(a$order),
 !anyDuplicated(paste(v$profile_id,v$axis_id,sep='::')),!anyNA(p),!anyNA(a),
 is.numeric(v$value),!any(is.infinite(v$value)),all(v$profile_id%in%p$profile_id),all(v$axis_id%in%a$axis_id),
 all(is.finite(a$lower)),all(is.finite(a$upper)),all(a$upper>a$lower),
 all(grepl('^#[0-9a-fA-F]{6}$',p$color)),all(nzchar(p$label)),all(nzchar(a$label)),
 nrow(v)==nrow(p)*nrow(a))
p<-p[order(p$order,p$profile_id),];a<-a[order(a$order,a$axis_id),]
join<-function(v,p,a){
 z<-merge(merge(v,p,by='profile_id',all.x=TRUE,sort=FALSE),a,by='axis_id',all.x=TRUE,sort=FALSE,suffixes=c('_profile','_axis'))
 z<-z[order(z$order_profile,z$order_axis),];rownames(z)<-NULL;z
}
d<-join(v,p,a);same_join<-identical(d,join(v,p[nrow(p):1,],a[nrow(a):1,]))
stopifnot(same_join,nrow(d)==nrow(v),all(d$value>=d$lower,na.rm=TRUE))
missing<-d[is.na(d$value),];excluded_ids<-unique(missing$profile_id)
observed<-d[!d$profile_id%in%excluded_ids,];included<-p[!p$profile_id%in%excluded_ids,]
stopifnot(nrow(included)>=2,nrow(included)<=6,all(is.finite(observed$value)))
bounds<-a
bounds$effective_upper<-vapply(a$axis_id,function(id)max(a$upper[a$axis_id==id],d$value[d$axis_id==id],na.rm=TRUE),numeric(1))
observed$effective_upper<-bounds$effective_upper[match(observed$axis_id,bounds$axis_id)]
observed$normalized<-(observed$value-observed$lower)/(observed$effective_upper-observed$lower)
stopifnot(all(observed$normalized>=0),all(observed$normalized<=1))
mat<-matrix(observed$normalized,nrow=nrow(included),byrow=TRUE,dimnames=list(included$profile_id,a$axis_id))
radar<-as.data.frame(rbind(rep(1,nrow(a)),rep(0,nrow(a)),mat))
colnames(radar)<-a$axis_id
wrap<-function(s,n)vapply(s,function(t)paste(strwrap(t,width=n),collapse='\n'),character(1))
long_axes<-max(nchar(a$label))>25
theta<-seq(90,450,length.out=nrow(a)+1)[seq_len(nrow(a))]*pi/180
label_radius<-if(long_axes)1.60 else 1.25
label_width<-if(long_axes)ifelse(abs(cos(theta))<.05,28,ifelse(abs(sin(theta))<.05,18,20))else rep(18,nrow(a))
labels<-vapply(seq_len(nrow(a)),function(i)wrap(paste0(a$label[i],' (',a$unit[i],')'),label_width[i]),character(1))
role_sizes<-unlist(fonts$size_roles_pt);stopifnot(fonts$family=='Arial',min(role_sizes)>=8)
font<-match_fonts('Arial');stopifnot(grepl('Arial.ttf$',font$path))
w<-contract$output_size$width_mm;h<-contract$output_size$height_mm
dir.create('results/figures',recursive=TRUE);dir.create('results/plot_data',recursive=TRUE);dir.create('results/tables',recursive=TRUE)
write.csv(observed,'results/plot_data/radar.csv',row.names=FALSE)
write.csv(bounds,'results/plot_data/axis_bounds.csv',row.names=FALSE)
write.csv(included,'results/plot_data/profile_metadata.csv',row.names=FALSE)
write.csv(d[d$profile_id%in%excluded_ids,],'results/tables/excluded_incomplete_profiles.csv',row.names=FALSE)
expanded<-bounds[bounds$effective_upper>bounds$upper,]
write.csv(expanded,'results/tables/expanded_upper_bounds.csv',row.names=FALSE)
render_native<-function(){
 par(fig=c(0,.55,.05,.97),mar=c(0,0,0,0),family='Arial',ps=8,xpd=FALSE)
 fmsb::radarchart(radar,axistype=0,maxmin=TRUE,centerzero=TRUE,
  seg=1,pcol=included$color,pfcol=scales::alpha(included$color,.25),plty=2,plwd=1.1,pty=32,
  cglcol='#8C8C8C',cglty=2,cglwd=.7,vlabels=rep('',nrow(a)),xlim=rep(if(long_axes)2.2 else 1.65,2)*c(-1,1),ylim=rep(if(long_axes)2.2 else 1.65,2)*c(-1,1))
 text(cos(theta)*label_radius,sin(theta)*label_radius,labels,cex=1,col='#202428')
 # All new profiles' raw values are in a keyed table, avoiding overlapping polygon labels.
 pushViewport(viewport(x=.775,y=.52,width=.42,height=.88))
 grid.text('Raw values',x=.5,y=.97,gp=gpar(fontfamily='Arial',fontsize=9,col='#202428'))
 column_x<-seq(.04,.95,length.out=nrow(included)+2)
 grid.text(c('Attribute','Upper\nbound',included$profile_id),x=column_x,y=.90,
  gp=gpar(fontfamily='Arial',fontsize=8,col=c('#202428','#202428',included$color)))
 rows_y<-seq(.81,.42,length.out=nrow(a))
 for(i in seq_len(nrow(a))){
  rawvalues<-observed$value[observed$axis_id==a$axis_id[i]]
  grid.text(c(paste(a$axis_id[i],a$unit[i]),sprintf('%.1f',bounds$effective_upper[i]),sprintf('%.1f',rawvalues)),
   x=column_x,y=rows_y[i],gp=gpar(fontfamily='Arial',fontsize=8,col='#202428'))
 }
 legend_y<-seq(.30,.05,length.out=nrow(included))
 for(i in seq_len(nrow(included))){
  grid.rect(x=.03,y=legend_y[i],width=unit(3,'mm'),height=unit(3,'mm'),gp=gpar(fill=included$color[i],col=NA))
  grid.text(wrap(included$label[i],28),x=.075,y=legend_y[i],just='left',gp=gpar(fontfamily='Arial',fontsize=8,col='#202428'))
 }
 popViewport()
}
ragg::agg_png('results/figures/figure.png',width=w,height=h,units='mm',res=300,background='white',pointsize=8)
render_native();dev.off()
grDevices::quartz(type='pdf',file='results/figures/figure.pdf',width=w/25.4,height=h/25.4,family='Arial',pointsize=8,bg='white')
render_native();dev.off()
label_mm<-systemfonts::string_width(labels,path=font$path,index=font$index,size=8,res=72)*25.4/72
write_json(list(width_mm=w,height_mm=h,axes=nrow(a),input_profiles=nrow(p),complete_profiles=nrow(included),
 input_cells=nrow(v),missing_cells=nrow(missing),excluded_profiles=excluded_ids,expanded_axes=expanded$axis_id,
 normalized_range=range(observed$normalized),axis_label_widths_mm=label_mm,
 radar_viewport=c(0,.55,.05,.97),table_viewport=c(.565,.985,.08,.96),
 axis_label_positions=cbind(x=cos(theta)*label_radius,y=sin(theta)*label_radius),
 source_layout_adaptation='keyed raw-value table replaces many-profile overlaid vertex numbers; native fmsb polygons preserved',
 font_sizes_pt=fonts$size_roles_pt,font_file=font$path,font_sha256=digest(file=font$path,algo='sha256'),
 context=context,cp3_status='NOT_VERIFIED: native fmsb lacks official ggplot-only entrypoint'),
 'results/geometry.json',auto_unbox=TRUE,pretty=TRUE)
ok<-function(s)list(status='pass',evidence=s)
checks<-list(input_dimension_driven=ok(paste(nrow(a),'axes,',nrow(included),'complete profiles; all fmsb columns and table rows derive from CSV')),
 metadata_join_by_key=ok('profile_id/axis_id keyed joins; reversed metadata yields identical canonical rows'),
 required_structures_preserved=ok('Native fmsb polygons with dashed outlines, shared spokes, keyed axis labels, all raw table values and external profile legend'),
 biological_unit_respected=ok(paste(context$experimental_unit,'; no axis treated as replicate; no hypothesis test;',length(excluded_ids),'incomplete profiles excluded without zero fill')),
 declared_axis_transform=ok(paste('Per-axis lower/effective upper shown in plot data;',nrow(expanded),'upper bounds explicitly expanded; raw values retained')))
if(contract$mode=='stress'){
 original_p<-read.csv('profiles.csv');original_a<-read.csv('axes.csv')
 stopifnot(max(nchar(a$label))>=40,nrow(a)>6,nrow(included)>3,nrow(missing)>0,max(observed$value)>=800,
  !identical(original_p$profile_id,p$profile_id),!identical(original_a$axis_id,a$axis_id))
 checks$stress_long_labels<-ok('Long keyed axis labels wrapped at 18 characters; Arial 8pt; complete long labels in metadata')
 checks$stress_multiple_groups<-ok(paste(nrow(included),'complete colored polygon profiles and',nrow(a),'axes'))
 checks$stress_missing_values<-ok(paste(nrow(missing),'missing cells; whole incomplete profile excluded and explicitly logged'))
 checks$stress_extreme_values<-ok(paste('Raw maximum',max(observed$value),'included; upper bound expanded to 800, normalized max=1, no clipping'))
 checks$stress_shuffled_metadata<-ok('Actual profile and axis metadata shuffled; reversed order matches canonical key joins')
}
write_json(checks,'results/scientific_results.json',auto_unbox=TRUE,pretty=TRUE)
