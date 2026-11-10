# Source-exposed ggdist halfeye/box/raindrop adapter; external CSV/context inputs.
# 2..8 groups, >=3 observed independent units/group; no statistical inference.
library(ggplot2);library(ggdist);library(scales);library(ragg)
library(systemfonts);library(jsonlite);library(digest);library(yaml);library(grid)
source('figure_style.R')
contract<-fromJSON('contract.json',simplifyVector=FALSE)
context<-fromJSON('context.json');fonts<-fromJSON('font-contract.json')
stopifnot(is.logical(context$synthetic),length(context$synthetic)==1,
 is.character(context$experimental_unit),nzchar(context$experimental_unit),
 is.character(context$measurement_label),nzchar(context$measurement_label),
 isTRUE(context$descriptive_only),identical(context$reverse_axis,FALSE))
v<-read.csv('values.csv',stringsAsFactors=FALSE,na.strings=c('','NA'))
m<-read.csv('groups.csv',stringsAsFactors=FALSE)
stopifnot(all(c('unit_id','group_id','value')%in%names(v)),all(c('group_id','label','order','color')%in%names(m)),
 nrow(m)>=2,nrow(m)<=8,!anyNA(v[c('unit_id','group_id')]),!anyDuplicated(v$unit_id),
 !anyDuplicated(m$group_id),!anyDuplicated(m$order),!anyNA(m),is.numeric(v$value),
 !any(is.infinite(v$value)),all(v$group_id%in%m$group_id),all(nzchar(m$label)),
 all(grepl('^#[0-9A-Fa-f]{6}$',m$color)))
meta<-m[order(m$order,m$group_id),]
join<-function(v,m){d<-merge(v,m,by='group_id',all.x=TRUE,sort=FALSE);d<-d[order(d$order,d$unit_id),];rownames(d)<-NULL;d}
d<-join(v,m);same<-identical(d,join(v,m[nrow(m):1,]));stopifnot(same,nrow(d)==nrow(v))
missing<-d[is.na(d$value),];obs<-d[!is.na(d$value),]
stopifnot(all(is.finite(obs$value)),setequal(obs$group_id,m$group_id),all(table(obs$group_id)>=3))
obs$group<-factor(obs$group_id,levels=meta$group_id)
wrap<-function(s,n)vapply(s,function(t)paste(strwrap(t,width=n),collapse='\n'),character(1))
labels<-setNames(wrap(meta$label,18),meta$group_id);colors<-setNames(meta$color,meta$group_id)
pt<-function(k)as.numeric(fonts$size_roles_pt[[k]]);font<-bf_font('Arial');stopifnot(min(unlist(fonts$size_roles_pt))>=8)
pseudo<-diff(range(obs$value))>8*max(IQR(obs$value),1)
tr<-if(pseudo)pseudo_log_trans(sigma=max(IQR(obs$value)/2,1))else identity_trans()
axis_label<-paste0(context$measurement_label,if(pseudo)' (pseudo-log)'else'')
breaks<-if(pseudo)sort(unique(c(-40,0,40,80,160,max(obs$value))))else pretty(range(obs$value),n=5)
display<-tr$transform(obs$value);binwidth<-diff(range(display))/65
p<-ggplot(obs,aes(group,value,fill=group))+
 ggdist::stat_halfeye(adjust=.7,width=.65,.width=0,justification=-.20,point_colour=NA,
  slab_colour=NA,show.legend=FALSE)+
 geom_boxplot(width=.10,alpha=.48,linewidth=.25,colour='#30343B',outlier.shape=NA,show.legend=FALSE)+
 ggdist::stat_dots(side='left',justification=1.15,binwidth=binwidth,dotsize=.7,stroke=.1,
  scale=.55,show.legend=FALSE)+
 scale_fill_manual(values=colors,guide='none')+
 scale_x_discrete(labels=labels,expand=expansion(add=.65))+
 scale_y_continuous(transform=tr,breaks=breaks,expand=expansion(mult=c(.045,.045)))+
 labs(x=NULL,y=axis_label)+bf_theme(font,pt('axis_text'))+
 theme(axis.text=element_text(size=pt('axis_text'),colour='#202428'),axis.title.y=element_text(size=pt('axis_title')),
  legend.position='none',plot.margin=margin(3,3,3,3,'mm'))
built<-ggplot_build(p)
stopifnot(length(built$data)==3,nrow(built$data[[2]])==nrow(m),
 length(unique(built$data[[1]]$group))==nrow(m),length(unique(built$data[[3]]$group))==nrow(m))
# stat_dots yields one row per observed unit; bind that count to the original keys.
stopifnot(nrow(built$data[[3]])==nrow(obs))
dir.create('results/figures',recursive=TRUE);dir.create('results/plot_data',recursive=TRUE);dir.create('results/tables',recursive=TRUE)
write.csv(obs,'results/plot_data/distribution.csv',row.names=FALSE);write.csv(meta,'results/plot_data/group_metadata.csv',row.names=FALSE)
write.csv(missing,'results/tables/missing_exclusions.csv',row.names=FALSE)
w<-contract$output_size$width_mm;h<-contract$output_size$height_mm
ragg::agg_png('measure.png',width=w,height=h,units='mm',res=300)
g<-ggplotGrob(p);panel<-g$layout[g$layout$name=='panel',][1,]
datax<-sum(convertWidth(g$widths[seq_len(panel$l-1)],'mm',valueOnly=TRUE))
datatop<-sum(convertHeight(g$heights[seq_len(panel$t-1)],'mm',valueOnly=TRUE))
dataw<-w-sum(convertWidth(g$widths,'mm',valueOnly=TRUE));datah<-h-sum(convertHeight(g$heights,'mm',valueOnly=TRUE))
datay<-h-datatop-datah
label_mm<-vapply(labels,function(s)convertWidth(grobWidth(textGrob(s,gp=gpar(fontfamily='Arial',fontsize=8))),'mm',valueOnly=TRUE),numeric(1))
pitch_mm<-dataw/diff(built$layout$panel_params[[1]]$x.range)
stopifnot(max(label_mm)+1<pitch_mm)
dev.off();unlink('measure.png')
boxes<-data.frame(id=c('data','labels','legend'),x=c(datax,datax,w-.15),y=c(datay,.1,h-.15),w=c(dataw,dataw,.05),h=c(datah,max(datay-.2,.1),.05))
sources<-normalizePath(c('render.R','figure_style.R','design-spec.yaml','values.csv','groups.csv','context.json','font-contract.json'))
script<-file.path(Sys.getenv('BIOFIGURE_SKILL_ROOT'),'scripts','authorize_render.py')
args<-c(script,'--receipt',normalizePath('preparation-receipt.json'),'--design-spec',normalizePath('design-spec.yaml'),
 unlist(lapply(sources[!grepl('\\.yaml$',sources)],function(x)c('--source',x))),'--output',file.path(normalizePath('.'),'authorization.json'))
stopifnot(system2('python3',shQuote(args))==0)
spec<-read_yaml('design-spec.yaml')
bf_render_png(p,'results/figures/figure.png',font,spec$text_contract$allowed_text,w,h,w,sources,boxes,
 authorization='authorization.json',skill_root=Sys.getenv('BIOFIGURE_SKILL_ROOT'),publication_size_class='double-column',min_text_pt=8)
pdf_device<-function(filename,width,height,...)grDevices::quartz(type='pdf',file=filename,width=width,height=height,...)
ggsave('results/figures/figure.pdf',p,device=pdf_device,family='Arial',width=w,height=h,units='mm',bg='white')
ok<-function(s)list(status='pass',evidence=s)
checks<-list(input_dimension_driven=ok(paste(nrow(v),'units,',nrow(m),'groups; three ggdist/box layers dynamically match external inputs')),
 metadata_join_by_key=ok('group_id keyed merge; reversed metadata gives identical rows; canonical order from metadata'),
 required_structures_preserved=ok('ggdist stat_halfeye, narrow quartile box, one left stat_dots mark per observed input unit; direct group labels and shared derived scale'),
 biological_unit_respected=ok(paste(context$experimental_unit,'; unique unit_id; no copied P bracket, t-test or percent conversion;',nrow(missing),'missing values excluded')),
 declared_axis_transform=ok(paste(tr$name,'explicit axis label; raw scores unchanged; display-coordinate densities and dot bins when pseudo-log')))
if(contract$mode=='stress'){
 stopifnot(max(nchar(m$label))>=40,nrow(m)>3,nrow(missing)>0,max(obs$value)>=160,!identical(m$group_id,meta$group_id))
 checks$stress_long_labels<-ok(paste('Labels >=40 chars wrapped at 18 chars; actual max width',max(label_mm),'mm, category pitch',pitch_mm,'mm; Arial 8pt'))
 checks$stress_multiple_groups<-ok(paste(nrow(m),'distinct halfeye densities, boxes and dots groups'))
 checks$stress_missing_values<-ok(paste(nrow(missing),'missing unit explicitly excluded and logged; not filled zero'))
 checks$stress_extreme_values<-ok(paste('Raw maximum',max(obs$value),'included; axis derived from all values, no source fixed-range clipping'))
 checks$stress_shuffled_metadata<-ok('Actual metadata shuffled; reversed metadata yields identical canonical keyed rows')
}
write_json(checks,'results/scientific_results.json',auto_unbox=TRUE,pretty=TRUE)
write_json(list(width_mm=w,height_mm=h,input_units=nrow(v),observed_units=nrow(obs),groups=nrow(m),missing_units=nrow(missing),
 data_bbox_mm=c(datax,datay,dataw,datah),category_pitch_mm=pitch_mm,label_widths_mm=label_mm,
 built_dot_count=nrow(built$data[[3]]),box_count=nrow(built$data[[2]]),layer_count=length(built$data),
 displayed_range=range(display),raw_range=range(obs$value),axis_transform=tr$name,density_coordinate_system=if(pseudo)'transformed display coordinates'else'raw score coordinates',
 font_sizes_pt=fonts$size_roles_pt,font_file=font$path,font_sha256=digest(file=font$path,algo='sha256'),context=context),
 'results/geometry.json',auto_unbox=TRUE,pretty=TRUE)
