# Three keyed panels: BCR composition, SHM composition, median SHM.
source('composite_canvas.R')
rows0<-rd('rows');rows<-ord(rows0,'row_id');comps<-ord(rd('components'),'component_id');d<-rd('counts');n<-nrow(rows)
stopifnot(n>=2,n<=24,!anyDuplicated(paste(d$row_id,d$component_id)),nrow(d)==n*nrow(comps),all(d$row_id%in%rows$row_id),all(d$component_id%in%comps$component_id),all(is.na(d$value)|is.finite(d$value)&d$value>=0),all(grepl('^#[A-Fa-f0-9]{6}$',comps$color)))
d<-d[order(match(d$row_id,rows$row_id),match(d$component_id,comps$component_id)),];d$proportion<-NA_real_;missing_profiles<-character()
for(id in rows$row_id){ii<-which(d$row_id==id);if(anyNA(d$value[ii]))missing_profiles<-c(missing_profiles,id) else {stopifnot(sum(d$value[ii])>0);d$proportion[ii]<-d$value[ii]/sum(d$value[ii])}}
if(source_display){shm<-rd('shm-summary');key(shm,'row_id');stopifnot(setequal(shm$row_id,rows$row_id),max(abs(shm$high+shm$median_level+shm$low-1))<1e-8);missing_units<-data.frame();unit_count<-NA_integer_} else {
 units<-rd('shm-units');key(units,'unit_id');stopifnot(all(units$row_id%in%rows$row_id),all(is.na(units$rate)|is.finite(units$rate)&units$rate>=0));missing_units<-units[is.na(units$rate),];u<-units[!is.na(units$rate),];unit_count<-nrow(u)
 shm<-do.call(rbind,lapply(rows$row_id,function(id){v<-u$rate[u$row_id==id];if(!length(v))stop('No observed SHM measurements for row ',id);data.frame(row_id=id,high=mean(v>5),median_level=mean(v>=1&v<=5),low=mean(v<1),median_rate=median(v))}))
}
shm<-shm[match(rows$row_id,shm$row_id),];stopifnot(all(shm$median_rate>=0),all(shm$median_rate<=cfg$rate_max),max(abs(shm$high+shm$median_level+shm$low-1))<1e-8)
pitch<-if(source_display)22.11 else cfg$row_pitch;top<-14;bottom<-if(source_display)459 else top+n*pitch;cy<-if(source_display)27+(seq_len(n)-1)*pitch else top+(seq_len(n)-.5)*pitch
for(z in list(c(215,369),c(393,536),c(558,653))){for(y in cy)S(z[1],y,z[2],y,'#E9E9E9',.15);for(x in seq(z[1],z[2],length.out=9))S(x,top,x,bottom,'#EBEBEB',.15);B(z[1],top,z[2],bottom,NA,'#666666',.17)}
for(i in seq_len(n)){
 id<-rows$row_id[i];z<-d[d$row_id==id,];z<-z[rev(seq_len(nrow(z))),];x<-222
 if(id%in%missing_profiles)T(paste0('missing-bcr-',id),'NA',292,cy[i]) else for(j in seq_len(nrow(z))){x1<-x+141*z$proportion[j];if(x1>x)B(x,cy[i]-pitch*.455,x1,cy[i]+pitch*.455,comps$color[match(z$component_id[j],comps$component_id)]);x<-x1}
 x<-399;for(j in seq_len(3)){v<-c(shm$high[i],shm$median_level[i],shm$low[i])[j];x1<-x+131*v;if(x1>x)B(x,cy[i]-pitch*.455,x1,cy[i]+pitch*.455,c('#869560','#b1d068','#ecf5cf')[j]);x<-x1}
 px<-if(source_display)shm$median_pixel_x[i] else 560+shm$median_rate[i]/cfg$rate_max*90
 O(px,cy[i],size=1.6)
 T(paste0('row-',id),wrap(rows$label[i],cfg$label_wrap),206,cy[i],hjust=1,color='#444444');S(210,cy[i],215,cy[i],lw=.2)
}
for(j in seq_len(5))for(z in list(c(222,363),c(399,530))){x<-z[1]+(j-1)/4*diff(z);S(x,bottom,x,bottom+4,lw=.2);T(paste0('prop-',z[1],'-',j),sprintf('%.2f',(j-1)/4),x,bottom+9,hjust=1,angle=90,color='#444444')}
rticks<-if(source_display)1:5 else pretty(c(0,cfg$rate_max));rticks<-rticks[rticks>=0&rticks<=cfg$rate_max]
for(j in seq_along(rticks)){x<-if(source_display)553.6+17.8*rticks[j] else 560+90*rticks[j]/cfg$rate_max;S(x,bottom,x,bottom+4,lw=.2);T(paste0('rate-tick-',j),as.character(rticks[j]),x,bottom+9,hjust=1,angle=90,color='#444444')}
for(z in list(c(292.5,'Proportion'),c(464.5,'Proportion'),c(606,'SHM rate (%)')))T(paste0('title-',z[1]),z[2],as.numeric(z[1]),bottom+50,'axis_title')
# Original source legend has exactly eight visible isotypes; optional IGHE absent.
ltop<-if(source_display)45 else 30;lbot<-ltop+45+nrow(comps)*16
T('bcr-legend-title',if(source_display)'BCR isotype' else 'Class',682,ltop+20,'legend_title',hjust=0)
for(j in seq_len(nrow(comps))){y<-ltop+46+(j-1)*16;B(683,y-7,698,y+7,comps$color[j]);T(paste0('bcr-legend-',j),comps$label[j],705,y,'legend_text',hjust=0)}
shm_top<-if(source_display)352 else max(lbot+25,bottom-110);T('shm-legend-title','SHM level',693,shm_top+20,'legend_title',hjust=0)
for(j in seq_len(3)){y<-shm_top+46+(j-1)*16;B(693,y-7,708,y+7,c('#ecf5cf','#b1d068','#869560')[j]);T(paste0('shm-legend-',j),c('Low','Median','High')[j],714,y,'legend_text',hjust=0)}
plot_tables<-list(bcr=d,shm=shm,ordered_rows=rows,components=comps);write.csv(missing_units,'results/tables/excluded-shm-units.csv',row.names=FALSE)
metadata<-list(longest_label_chars=max(nchar(rows$label)),missing_count=length(missing_profiles)+nrow(missing_units),extreme_value=max(d$value,na.rm=TRUE),new_input_extreme=80,shuffled_metadata=!identical(rows0$row_id,rows$row_id),groups_evidence=paste(n,'subtypes,',nrow(comps),'BCR classes and3SHM levels'),source_panel_bounds=list(c(215,14,369,459),c(393,14,536,459),c(558,14,653,459)),missing_profiles=missing_profiles,unit_count=unit_count)
panels<-list(bcr=c(215,top,369,bottom),shm=c(393,top,536,bottom),median=c(558,top,653,bottom));layer_order<-c('white canvas','gray grids/frame','keyed stacks','median points','full labels/legends')
checks<-list(input_dimension_driven=ok(paste(n,'subtypes,',nrow(comps),'classes; all three panels input-driven')),metadata_join_by_key=ok('Same ordered row_id across all three panels; unique component_id order; no independent subtype sorting'),required_structures_preserved=ok('Two horizontal composition panels, aligned median points, full keyed row labels, quantitative scales, two complete external legends'),biological_unit_respected=ok('Cell/profile summary and SHM measurement records; no inferential biological n or invented raw source cells'),compositional_closure_verified=ok('Each observed complete BCR row closes1; SHM level fractions from same retained measurement records; missing profile remainsNA'),shared_shm_data_verified=ok('SHM composition and median both derived from identical retained row_id measurement units; source uses separately labelled pixel-read summaries'))
finish()
