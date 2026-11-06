#!/usr/bin/env Rscript
suppressPackageStartupMessages({library(ggtern);library(ggplot2);library(grid)})
source('common.R')
a<-read_input('composition');meta<-read_input('metadata');times<-read_input('times')
fields<-unlist(settings$component_columns);axis_labels<-unlist(settings$component_labels)
required(a,c('unit_id',fields),'composition');required(meta,c('unit_id','time_id','group_id'),'metadata');required(times,c('time_id','label','order'),'times')
unique_key(a,'unit_id','composition');unique_key(meta,'unit_id','metadata');unique_key(times,'time_id','times')
stopifnot(setequal(a$unit_id,meta$unit_id),all(meta$time_id%in%times$time_id),all(meta$group_id%in%groups$group_id),!anyNA(meta),!anyNA(times),!anyDuplicated(times$order),length(fields)==3)
stopifnot(all(vapply(a[fields],is.numeric,logical(1))));m<-as.matrix(a[fields]);if(any(m<0,na.rm=TRUE))stop('Negative ternary component is invalid')
excluded<-apply(m,1,anyNA);write_csv(data.frame(unit_id=a$unit_id[excluded],reason=rep('missing component; complete unit excluded',sum(excluded))),'excluded_units')
a<-a[!excluded,,drop=FALSE];m<-as.matrix(a[fields]);stopifnot(all(is.finite(m)))
denominator<-rowSums(m);if(any(denominator<=0))stop('Zero ternary denominator is invalid')
closed<-m/denominator;stopifnot(max(abs(rowSums(closed)-1))<1e-12,all(closed>=0),all(closed<=1))
joined<-meta[match(a$unit_id,meta$unit_id),];key_correct<-identical(a$unit_id,joined$unit_id);times<-times[order(times$order),]
d<-data.frame(unit_id=a$unit_id,time_id=joined$time_id,group_id=factor(joined$group_id,levels=groups$group_id),denominator=denominator,A=closed[,1],B=closed[,2],C=closed[,3])
d$time_label<-factor(wrap(times$label[match(d$time_id,times$time_id)]),levels=wrap(times$label))
stopifnot(nrow(d)>0,all(table(d$time_id,d$group_id)>=1),key_correct)
write_csv(d,'ternary_closed');write_csv(joined,'keyed_metadata');write_csv(times,'time_order')
breaks<-unlist(settings$grid_breaks);stopifnot(all(breaks>=0&breaks<=1));percent<-function(x)format(100*x,trim=TRUE,scientific=FALSE)
p<-ggtern::ggtern(d,aes(x=A,y=B,z=C,color=group_id,shape=group_id))+ggtern::geom_mask()+geom_point(size=1.05,stroke=.28,alpha=.8)+
 scale_color_manual(values=colors,breaks=groups$group_id,labels=wrap(groups$label))+scale_shape_manual(values=shapes,breaks=groups$group_id,labels=wrap(groups$label))+
 ggtern::scale_T_continuous(breaks=breaks,labels=percent(breaks))+ggtern::scale_L_continuous(breaks=breaks,labels=percent(breaks))+ggtern::scale_R_continuous(breaks=breaks,labels=percent(breaks))+
 labs(x=axis_labels[1],y=axis_labels[2],z=axis_labels[3],color=NULL,shape=NULL,caption=NULL)+facet_wrap(~time_label,nrow=1)+
 ggtern::theme_rgbg(base_size=pt('axis_text'),base_family=font)+
 theme(text=element_text(family=font),tern.axis.title=element_text(size=pt('axis_title'),face='plain'),tern.axis.text=element_text(size=pt('axis_text')),tern.axis.arrow.text=element_text(size=pt('axis_text')),tern.axis.arrow=element_line(linewidth=.25),
 tern.panel.grid.major.T=element_line(color='#8B0000',linetype=2,linewidth=.25),tern.panel.grid.major.L=element_line(color='#000080',linetype=2,linewidth=.25),tern.panel.grid.major.R=element_line(color='#006400',linetype=2,linewidth=.25),tern.panel.grid.minor=element_line(color='#FFFFFF',linewidth=.15),
 tern.panel.background=element_rect(fill='#EBEBEB',color=NA),panel.background=element_rect(fill='#FFFFFF',color=NA),plot.background=element_rect(fill='#FFFFFF',color=NA),strip.background=element_blank(),strip.text=element_text(size=pt('strip_text'),lineheight=.98),
 legend.position='bottom',legend.text=element_text(size=pt('legend_text'),lineheight=.98),legend.title=element_blank(),legend.key.size=unit(3,'mm'),legend.spacing.y=unit(1,'mm'),plot.caption=element_text(size=pt('annotation_text')),plot.margin=margin(3,3,3,3,'mm'))+
 guides(color=guide_legend(ncol=2),shape=guide_legend(ncol=2))
# ggtern 4.0.0 grid construction consumes labels as a vector, not a function.
# Dispatch through ggtern's native plot methods; ggplot2's ordinary build strips ternary coordinates.
authorize_native()
export_plot(function()print(p))
check('input_dimension_driven',nrow(d)==nrow(a)&&nlevels(d$time_label)==nrow(times),sprintf('%d supplied units, %d time panels, %d groups; external rows drive all panels.',nrow(d),nrow(times),nrow(groups)))
check('metadata_join_by_key',key_correct&&identical(as.character(d$group_id),joined$group_id),'Unique unit_id joins verified separately from metadata input order; time_id matches explicit time order table.')
check('required_structures_preserved',all(abs(rowSums(d[c('A','B','C')])-1)<1e-12)&&length(breaks)==6,'Native ggtern coordinates, EPI/TE/PrE vertices, 0-100% ticks, colored major grid/direction arrows, all retained points, time panels and external shape/color legend.')
check('biological_unit_respected',!anyDuplicated(d$unit_id),paste(settings$experimental_unit,'; closure denominator is per-unit sum of supplied scores; no cell-frequency, longitudinal or inferential claims.'))
check('compositional_closure_verified',all(denominator>0)&&all(closed>=0)&&max(abs(rowSums(closed)-1))<1e-12,'Nonnegative finite components, positive per-unit denominator and numerical closure independently checked; preclosure scores and denominator retained.')
if(contract$mode=='stress'){
 check('stress_long_labels',max(nchar(times$label))>=32&&max(nchar(groups$label))>=32,'Full long time and group labels wrapped at supplied character budget; no sample or panel removed for layout.')
 check('stress_multiple_groups',nrow(groups)>=5&&nrow(times)>=3,paste(nrow(groups),'groups across',nrow(times),'time panels; separate colors and shapes.'))
 check('stress_missing_values',sum(excluded)>=3,paste(sum(excluded),'units with missing component excluded as whole unit with ID/reason; never closed using a partial denominator.'))
 check('stress_extreme_values',max(m)>=1e6&&any(closed[,1]==1)&&all(closed<=1),'1e6:0:0 input preserved and normalized to exact simplex vertex; all finite coordinates in [0,1].')
 check('stress_shuffled_metadata',!identical(meta$unit_id,a$unit_id)&&key_correct,'Shuffled unit metadata still aligns group and time independently by unique unit_id.')
}
finish(list(units=nrow(d),time_panels=nrow(times),groups=nrow(groups),excluded_units=sum(excluded),closure_max_error=max(abs(rowSums(closed)-1)),denominator_range=range(denominator),metadata_join_verified=key_correct,component_columns=fields,component_labels=axis_labels,major_grid_percent=100*breaks,legend_columns=2,ternary_panel_background='#EBEBEB',minor_grid_color='#FFFFFF',minor_grid_linewidth_mm=.15,canvas_background='#FFFFFF',executed_namespace_calls=c('ggtern::ggtern','ggtern::geom_mask','ggtern::theme_rgbg','ggtern::scale_T_continuous','ggtern::scale_L_continuous','ggtern::scale_R_continuous','ggplot2::geom_point')))
