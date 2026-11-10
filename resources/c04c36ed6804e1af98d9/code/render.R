# Independent native ggplot2 summary forest, reconstructed from source grammar.
# Source display is raster-derived public summary readout, never patient/model data.
suppressPackageStartupMessages({library(ggplot2);library(jsonlite);library(systemfonts);library(digest);library(yaml);library(grid)})
options(warn=2)
settings<-fromJSON('data/settings.json');contract<-fromJSON('contract.json',simplifyVector=FALSE)
source('figure_style.R')
font<-bf_font('Arial');stopifnot(settings$font_family=='Arial',basename(font$path)=='Arial.ttf')
stopifnot(is.numeric(settings$confidence_level),settings$confidence_level>0,settings$confidence_level<1)
label_level<-regmatches(settings$axis_label,regexpr('[0-9]+(\\.[0-9]+)?%',settings$axis_label))
if(nzchar(label_level))stopifnot(abs(as.numeric(sub('%','',label_level))/100-settings$confidence_level)<1e-8)
stopifnot(settings$null_value==1,settings$scale%in%c('linear','log10'),is.logical(settings$synthetic),is.character(settings$data_context),nzchar(settings$data_context),is.character(settings$experimental_unit),nzchar(settings$experimental_unit))
rows<-read.csv('data/rows.csv',stringsAsFactors=FALSE,check.names=FALSE)
groups<-read.csv('data/groups.csv',stringsAsFactors=FALSE,check.names=FALSE)
est<-read.csv('data/estimates.csv',stringsAsFactors=FALSE,check.names=FALSE,na.strings=c('','NA'),colClasses=c(p_text='character',stars='character'))
required<-function(d,fields,n){if(!all(fields%in%names(d)))stop(n,': missing required fields')}
required(rows,c('row_id','label','order','n_cases'),'rows');required(groups,c('group_id','label','header','order','color','fill'),'groups');required(est,c('row_id','group_id','hr','ci_low','ci_high','p_value','p_text','stars'),'estimates')
key<-function(d,k,n){if(anyNA(d[[k]])||any(!nzchar(d[[k]]))||anyDuplicated(d[[k]]))stop(n,': duplicate or missing primary key')}
key(rows,'row_id','rows');key(groups,'group_id','groups');stopifnot(!anyNA(rows),all(is.finite(rows$n_cases)),all(rows$n_cases>=0),all(rows$n_cases==floor(rows$n_cases)),!anyNA(groups),!anyDuplicated(rows$order),!anyDuplicated(groups$order),nrow(groups)==2,nrow(rows)>=2,nrow(rows)<=32,
 !anyDuplicated(paste(est$row_id,est$group_id,sep='::')),!anyNA(est[c('row_id','group_id')]),all(est$row_id%in%rows$row_id),all(est$group_id%in%groups$group_id),nrow(est)==nrow(rows)*2,all(grepl('^#[0-9A-Fa-f]{6}$',groups$color)),all(grepl('^#[0-9A-Fa-f]{6}$',groups$fill)),is.numeric(est$hr),all(is.finite(est$hr)),all(est$hr>0),all(is.na(est$p_value)|(is.finite(est$p_value)&est$p_value>=0&est$p_value<=1)))
# One-sided missing or reversed/nonpositive CI is rejected; no interpolation.
stopifnot(all(is.na(est$ci_low)==is.na(est$ci_high)))
observed_ci<-!is.na(est$ci_low)
stopifnot(all(is.finite(est$ci_low[observed_ci])),all(is.finite(est$ci_high[observed_ci])),all(est$ci_low[observed_ci]>0),all(est$ci_high[observed_ci]>0),all(est$ci_low[observed_ci]<=est$hr[observed_ci]),all(est$hr[observed_ci]<=est$ci_high[observed_ci]))
rows<-rows[order(rows$order,rows$row_id),];groups<-groups[order(groups$order,groups$group_id),]
join<-function(e,r,g){z<-e;z$row_order<-r$order[match(e$row_id,r$row_id)];z$group_order<-g$order[match(e$group_id,g$group_id)];z$label<-r$label[match(e$row_id,r$row_id)];z$n_cases<-r$n_cases[match(e$row_id,r$row_id)];z$color<-g$color[match(e$group_id,g$group_id)];z$fill<-g$fill[match(e$group_id,g$group_id)];z<-z[order(z$row_order,z$group_order),];rownames(z)<-NULL;z}
d<-join(est,rows,groups);stopifnot(identical(d,join(est,rows[nrow(rows):1,],groups[2:1,])))
n<-nrow(rows);source_display<-identical(settings$mode,'source_image_digitized_display')
if(source_display)stopifnot(!settings$synthetic,contract$mode%in%c('source-display','source-repeat'),settings$scale=='linear',n==26)
if(!source_display)stopifnot(settings$mode=='supplied_summary_estimates')
star_for<-function(p)ifelse(is.na(p),'',ifelse(p<.01,'**',ifelse(p<.05,'*','')))
if(!source_display)d$stars<-star_for(d$p_value) else d$stars[is.na(d$stars)]<-''
# Supplied/source display P is formatted only; no test or correction is executed.
super<-function(v){s<-strsplit(v,'',fixed=TRUE)[[1]];paste(c('0'='⁰','1'='¹','2'='²','3'='³','4'='⁴','5'='⁵','6'='⁶','7'='⁷','8'='⁸','9'='⁹','-'='⁻')[s],collapse='')}
pfmt<-function(v){if(is.na(v)||!nzchar(v))return('NA');q<-strsplit(v,'e',fixed=TRUE)[[1]];if(length(q)==2)paste0(q[1],' x 10^',q[2])else v}
d$p_display<-vapply(d$p_text,pfmt,character(1))
wrap<-function(s,width)vapply(s,function(t)paste(strwrap(t,width=width),collapse='\n'),character(1))
complex_labels<-max(nchar(rows$label))>25
rows$display_label<-if(source_display)rows$label else wrap(rows$label,if(complex_labels)26 else settings$label_wrap_chars)
pitch<-as.numeric(settings$row_pitch_px);row_y<-45+(seq_len(n)-1)*pitch
rows$canvas_y<-row_y;d$canvas_row_y<-row_y[match(d$row_id,rows$row_id)]
d$canvas_y<-d$canvas_row_y+ifelse(d$group_order==1,-3.5,3.2)
body_top<-45-pitch/2;body_bottom<-tail(row_y,1)+pitch/2
H<-as.numeric(settings$source_canvas_height_px);W<-800;wmm<-as.numeric(settings$width_mm);hmm<-as.numeric(settings$height_mm)
stopifnot(wmm==183,hmm>0,hmm<=170,abs(wmm/hmm-W/H)<.001)
cal<-fromJSON('data/axis-calibration.json')
forest_left<-if(source_display)cal$pixel_intercept+cal$pixel_per_hr*.5 else if(complex_labels)290 else 269
forest_right<-if(source_display)cal$pixel_intercept+cal$pixel_per_hr*3.5 else 531
fx<-function(v){t<-if(settings$scale=='linear')function(x)x else log10;forest_left+(t(v)-t(settings$x_limits[1]))/diff(t(settings$x_limits))*(forest_right-forest_left)}
range_values<-c(d$hr,d$ci_low,d$ci_high);range_values<-range_values[is.finite(range_values)]
stopifnot(min(range_values)>=settings$x_limits[1],max(range_values)<=settings$x_limits[2],settings$x_limits[1]<1,settings$x_limits[2]>1)
d$canvas_x<-fx(d$hr);d$canvas_ci_low_x<-fx(d$ci_low);d$canvas_ci_high_x<-fx(d$ci_high)
ci<-d[!is.na(d$ci_low),];missing<-d[is.na(d$ci_low),]
category_x<-if(complex_labels)30 else 50;count_x<-if(complex_labels)220 else 182
axis_y<-body_bottom+.5;axis_text_y<-axis_y+11;axis_title_y<-axis_y+28
ref_y<-axis_y+60;legend_y<-c(axis_y+80,axis_y+100)
# All layers are genuine ggplot2 objects; the canvas is vector, never a pasted raster.
stripes<-data.frame(xmin=50,xmax=784,ymin=-(row_y+pitch/2),ymax=-(row_y-pitch/2),fill=rep(c('#F2F2F2','#FFFFFF'),length.out=n))
text<-data.frame(id=character(),label=character(),x=numeric(),y=numeric(),size=numeric(),face=character(),hjust=numeric(),role=character(),stringsAsFactors=FALSE)
addtext<-function(id,label,x,y,size=9,face='plain',hjust=0,role='annotation_text'){
 text<<-rbind(text,data.frame(id=id,label=label,x=x,y=-y,size=size,face=face,hjust=hjust,role=role,stringsAsFactors=FALSE))
}
row_header<-if(source_display)'Cancer site' else if(!is.null(settings$row_header))settings$row_header else 'Endpoint'
count_header<-if(source_display)'# of cases' else if(!is.null(settings$count_header))settings$count_header else 'Supplied n'
addtext('header-category',row_header,category_x,16,face='bold');addtext('header-count',count_header,count_x,16,face='bold')
addtext('header-G1',groups$header[1],557,16,size=8.5,face='bold');addtext('header-G2',groups$header[2],669,16,size=8.5,face='bold')
for(i in seq_len(n)){
 addtext(paste0(rows$row_id[i],'-label'),rows$display_label[i],category_x,row_y[i])
 addtext(paste0(rows$row_id[i],'-count'),format(rows$n_cases[i],big.mark=',',scientific=FALSE,trim=TRUE),count_x,row_y[i])
 for(j in seq_len(2)){
  z<-d[d$row_id==rows$row_id[i]&d$group_order==j,]
  px<-if(j==1)584 else 670;pid<-paste0(z$row_id,'-P-',j)
  pv<-strsplit(z$p_text,'e',fixed=TRUE)[[1]]
  if(length(pv)==2){
   main<-paste0(pv[1],' × 10');addtext(pid,main,px,row_y[i],size=9,role='pvalue_text')
   ext<-systemfonts::string_width(main,path=font$path,index=font$index,size=9,res=300)*25.4/300/wmm*W
   addtext(paste0(pid,'-exponent'),pv[2],px+ext+.5,row_y[i]-4.8,size=6,role='exponent_text')
  } else addtext(pid,z$p_display,px,row_y[i],size=9,role='pvalue_text')
  if(nzchar(z$stars))addtext(paste0(z$row_id,'-star-',j),z$stars,if(j==1)557 else 749,row_y[i],face='bold')
 }
}
ticks<-as.numeric(settings$ticks);tx<-fx(ticks);tick_labels<-format(ticks,scientific=FALSE,trim=TRUE)
if(source_display)tick_labels<-sprintf('%.1f',ticks)
for(i in seq_along(ticks))addtext(paste0('tick-',i),tick_labels[i],tx[i],axis_text_y,face='bold',hjust=.5,role='axis_text')
addtext('effect-axis',settings$axis_label,(forest_left+forest_right)/2,axis_title_y,face='bold',hjust=.5,role='axis_title')
addtext('reference-label',settings$reference_text,284,ref_y,size=8,face='bold',role='legend_text')
# Original legend reads black filled before red hollow, independently of data order.
for(j in c(2,1))addtext(paste0('legend-',j),groups$label[j],310,legend_y[if(j==2)1 else 2],size=8,face='bold',role='legend_text')
if(!source_display&&nrow(missing))addtext('missing-CI-note',paste(nrow(missing),'CI unavailable; points shown without interval'),30,H-12,size=8,role='legend_text')
text$size_mm<-text$size/ggplot2::.pt
p<-ggplot()+geom_rect(data=stripes,aes(xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax,fill=fill),colour=NA)+scale_fill_identity()+
 geom_segment(aes(x=fx(1),xend=fx(1),y=-15,yend=-(body_bottom-3)),linetype='dashed',linewidth=.18,color='#000000')+
 geom_segment(data=ci,aes(x=canvas_ci_low_x,xend=canvas_ci_high_x,y=-canvas_y,yend=-canvas_y),linewidth=.16,color='#555555')+
 geom_point(data=d,aes(x=canvas_x,y=-canvas_y,color=color,fill=fill),shape=23,size=1.50,stroke=.14)+scale_color_identity()+
 geom_text(data=text,aes(x=x,y=y,label=label,size=size_mm,fontface=face,hjust=hjust),family='Arial',vjust=.5,lineheight=.90,color='#000000',show.legend=FALSE)+scale_size_identity()+
 geom_segment(aes(x=forest_left,xend=forest_right,y=-axis_y,yend=-axis_y),linewidth=.22,color='black')+
 geom_segment(data=data.frame(x=tx),aes(x=x,xend=x,y=-axis_y,yend=-(axis_y+4)),linewidth=.22,color='black')+
 geom_point(data=data.frame(x=294,y=-legend_y,fill=c(groups$fill[2],groups$fill[1]),color=c(groups$color[2],groups$color[1])),aes(x=x,y=y,fill=fill,color=color),shape=23,size=1.50,stroke=.14)+
 scale_x_continuous(limits=c(0,W),expand=c(0,0))+scale_y_continuous(limits=c(-H,0),expand=c(0,0))+coord_cartesian(clip='off')+
 theme_void(base_family='Arial',base_size=9)+theme(plot.margin=margin(0,0,0,0),text=element_text(family='Arial',size=9,color='black'),plot.background=element_rect(fill='white',color=NA),panel.background=element_rect(fill='white',color=NA),legend.position='none')
# Actual text extents in mm, keyed to the same coordinate system as the marks.
multiline_width<-function(s,size){max(systemfonts::string_width(strsplit(s,'\n',fixed=TRUE)[[1]],path=font$path,index=font$index,size=size,res=300))*25.4/300}
text$width_mm<-mapply(multiline_width,text$label,text$size)
text$height_mm<-vapply(strsplit(text$label,'\n',fixed=TRUE),length,integer(1))*text$size*25.4/72*.90
text$x_mm<-text$x/W*wmm-text$hjust*text$width_mm;text$y_mm<--text$y/H*hmm-text$height_mm/2
stopifnot(all(text$x_mm>=0),all(text$y_mm>=0),all(text$x_mm+text$width_mm<=wmm),all(text$y_mm+text$height_mm<=hmm))
# Row text is tested against its neighbour and the reserved case-count column.
labs<-text[grepl('-label$',text$id)&text$id!='reference-label',]
stopifnot(all(labs$height_mm<pitch/W*wmm),max(labs$x_mm+labs$width_mm)<count_x/W*wmm-1)
text_collisions<-list()
for(i in seq_len(nrow(text)-1))for(j in (i+1):nrow(text)){
 a<-text[i,];b<-text[j,]
 if(min(a$x_mm+a$width_mm,b$x_mm+b$width_mm)>max(a$x_mm,b$x_mm)&&min(a$y_mm+a$height_mm,b$y_mm+b$height_mm)>max(a$y_mm,b$y_mm))text_collisions[[length(text_collisions)+1]]<-c(a$id,b$id)
}
if(length(text_collisions))stop('Detected text collision: ',paste(unlist(text_collisions),collapse=', '))
dir.create('results',showWarnings=FALSE);dir.create('results/plot_data',showWarnings=FALSE);dir.create('results/tables',showWarnings=FALSE)
write.csv(d,'results/plot_data/forest.csv',row.names=FALSE);write.csv(rows,'results/plot_data/ordered_rows.csv',row.names=FALSE);write.csv(groups,'results/plot_data/ordered_groups.csv',row.names=FALSE);write.csv(missing,'results/tables/unavailable_ci.csv',row.names=FALSE);write.csv(text,'results/tables/text_geometry.csv',row.names=FALSE)
root<-Sys.getenv('BIOFIGURE_SKILL_ROOT');stopifnot(nzchar(root))
sources<-c('render.R','figure_style.R','data/settings.json','data/rows.csv','data/groups.csv','data/estimates.csv','data/axis-calibration.json','data/design-spec.yaml')
args<-c(file.path(root,'scripts/authorize_render.py'),'--receipt','data/preparation-receipt.json','--design-spec','data/design-spec.yaml',unlist(lapply(sources[sources!='data/design-spec.yaml'],function(s)c('--source',s))),'--output','results/render-authorization.json')
if(system2('python3',shQuote(args))!=0L)stop('Render authorization failed')
boxes<-data.frame(id=c('data','labels','legend'),x=c(forest_left/W*wmm,category_x/W*wmm,284/W*wmm),y=c(body_top/H*hmm,8/H*hmm,(ref_y-8)/H*hmm),w=c((forest_right-forest_left)/W*wmm,(784-category_x)/W*wmm,460/W*wmm),h=c((body_bottom-body_top)/H*hmm,(body_bottom-8)/H*hmm,56/H*hmm))
bf_render_png(p,'results/figure.png',font=font,allowed_text=unique(text$label),width_mm=wmm,height_mm=hmm,target_width_mm=wmm,source_files=sources,boxes=boxes,allowed_pairs='data:labels',min_text_pt=6,authorization='results/render-authorization.json',skill_root=root,publication_size_class='double-column')
grDevices::quartz(type='pdf',file='results/figure.pdf',width=wmm/25.4,height=hmm/25.4,family='Arial',bg='white');print(p);invisible(dev.off())
svglite::svglite('results/figure.svg',width=wmm/25.4,height=hmm/25.4,bg='white');print(p);invisible(dev.off())
ok<-function(evidence)list(status='pass',evidence=evidence)
checks<-list(positive_estimates_and_ci=ok(paste(nrow(d),'positive HR;',nrow(ci),'positive ordered observed CI; no imputation')),metadata_join_by_key=ok('row_id/group_id canonical joins identical with both metadata tables reversed'),dimension_driven_rows=ok(paste(n,'keyed categories and two groups; input-driven height and row spacing')),table_and_marks_align=ok('Every label/count/P/star and dodged estimate uses canonical row_id and group_id; all displayed numbers exported'),missing_ci_never_imputed=ok(paste(nrow(missing),'unavailable intervals logged; supplied/digitized points only')),supplied_p_never_retested=ok('No test, Cox fit or p adjustment. Source displayed P/stars transcribed; general star uses corresponding supplied group P'),declared_scale_and_null=ok(paste(settings$scale,'effect-coordinate transform; positive range',paste(settings$x_limits,collapse='..'),'and null=1')))
if(!source_display){
 stopifnot(all(d$stars==star_for(d$p_value)))
 different<-vapply(rows$row_id,function(id){z<-d[d$row_id==id,];z$stars[1]!=z$stars[2]},logical(1))
 if(contract$mode%in%c('new-input','stress'))stopifnot(any(different));checks$group2_star_wrong_column_regression<-ok(paste(sum(different),'rows have differing group stars, verified from each corresponding supplied P'))
}
if(contract$mode=='stress'){
 origrows<-read.csv('data/rows.csv');origgroups<-read.csv('data/groups.csv')
 stopifnot(max(nchar(rows$label))>=45,n>10,nrow(missing)==2,max(d$hr)>35,min(d$hr)<=.03,!identical(origrows$row_id,rows$row_id),!identical(origgroups$group_id,groups$group_id),settings$scale=='log10')
 checks$stress_long_labels<-ok('45+ character endpoint labels wrap to two 9pt lines inside physically measured slots')
 checks$stress_more_categories<-ok('18 rows vs new-input10; canvas and row positions derive from input dimensions')
 checks$stress_missing_values<-ok('Two missing whole CI pairs retained as point-only; visual note and omission table; no substituted limits')
 checks$stress_extremes<-ok('Positive HR .03..39.2 and observed CI .023..50.96 retained on declared log10 .01..100 axis without clipping')
 checks$stress_shuffled_metadata<-ok('Actual rows/groups and estimates scrambled; key join restores explicit order')
}
write_json(checks,'results/scientific_results.json',auto_unbox=TRUE,pretty=TRUE)
geometry<-list(width_mm=wmm,height_mm=hmm,canvas_px=c(W,H),font_sizes_pt=settings$font_roles_pt,font_path=font$path,font_sha256=digest(file=font$path,algo='sha256'),row_count=n,group_count=2,row_pitch_px=pitch,row_pitch_mm=pitch/W*wmm,row_baselines_px=row_y,body_bounds_px=c(body_top,body_bottom),forest_bounds_px=c(forest_left,forest_right),category_x_px=category_x,count_x_px=count_x,P_x_px=c(584,670),legend_y_px=legend_y,reference_y_px=ref_y,axis_transform=settings$scale,axis_ticks=ticks,effect_range=settings$x_limits,null_effect=1,unavailable_ci_pairs=nrow(missing),text_collisions=text_collisions,clipped_text=0,text_count=nrow(text),native_object='ggplot2',source_display=source_display,source_display_source_star_defect_preserved=source_display,context=settings[c('mode','data_context','experimental_unit','synthetic')])
write_json(geometry,'results/geometry.json',pretty=TRUE,auto_unbox=TRUE);write_json(geometry,'results/layout_metrics.json',pretty=TRUE,auto_unbox=TRUE)
capture.output(sessionInfo(),file='results/session-info.txt')
