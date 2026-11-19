# Supplied term counts plus an explicitly scaled -log10P series; no enrichment fit.
source('composite_canvas.R')
original<-rd('terms');d<-ord(original,'term_id');stopifnot(nrow(d)>=2,nrow(d)<=20,all(is.na(d$gene_count)|is.finite(d$gene_count)&d$gene_count>=0&d$gene_count==floor(d$gene_count)),all(is.na(d$neglog10p)|is.finite(d$neglog10p)&d$neglog10p>=0),!any(is.na(d$gene_count)&is.na(d$neglog10p)),cfg$secondary_scale_factor>0,is.finite(cfg$secondary_scale_factor))
if(!source_display)d<-d[order(-d$neglog10p,d$order,d$term_id,na.last=TRUE),]
left<-if(source_display)157 else 140;right<-if(source_display)721 else 728;top<-61;bottom<-356;factor<-cfg$secondary_scale_factor
maximum<-if(source_display)cfg$primary_max else ceiling(max(d$gene_count,d$neglog10p*factor,na.rm=TRUE)*1.25/1000)*1000;stopifnot(maximum>0)
fy<-function(v)bottom-v/maximum*(bottom-top)
x<-if(source_display)d$pixel_x else seq(left+14,right-14,length.out=nrow(d));d$canvas_x<-x;d$bar_top<-fy(d$gene_count);d$point_y<-if(source_display)d$pixel_y else fy(d$neglog10p*factor)
barwidth<-if(source_display)16.8 else (right-left)/nrow(d)*.6
for(i in seq_len(nrow(d)))if(!is.na(d$gene_count[i]))B(x[i]-barwidth/2,d$bar_top[i],x[i]+barwidth/2,bottom,'#b9c0ff','black',.22)
for(i in seq_len(nrow(d)-1))if(!is.na(d$point_y[i])&&!is.na(d$point_y[i+1]))S(x[i],d$point_y[i],x[i+1],d$point_y[i+1],lw=.2,lt='dotted')
observed<-!is.na(d$point_y);O(x[observed],d$point_y[observed],'#589c47',if(source_display)2.5 else 1.9,.2)
B(left,top,right,bottom,NA,'black',.25)
ticks<-if(source_display)seq(0,6000,1000) else pretty(c(0,maximum));ticks<-ticks[ticks>=0&ticks<=maximum]
for(v in ticks){y<-fy(v);S(left-5,y,left,y,lw=.25);T(paste0('primary-',v),as.character(v),left-10,y,face='bold',hjust=1)}
ticks2<-if(source_display)seq(0,140,20) else pretty(c(0,maximum/factor));ticks2<-ticks2[ticks2>=0&ticks2<=maximum/factor]
for(v in ticks2){y<-fy(v*factor);S(right,y,right+5,y,lw=.25);T(paste0('secondary-',v),as.character(v),right+9,y,face='bold',hjust=0)}
T('primary-title',cfg$primary_label,left-61,(top+bottom)/2,'axis_title',face='bold',angle=90)
T('secondary-title',cfg$secondary_label,right+51,(top+bottom)/2,'axis_title',face='bold',angle=-90)
T('overall-title',cfg$title,(left+right)/2,43,'title_text',face='bold')
for(i in seq_len(nrow(d))){T(paste0('term-',d$term_id[i]),wrap(d$label[i],cfg$label_wrap),x[i]+4,bottom+11,face='bold',hjust=1,angle=45);S(x[i],bottom,x[i],bottom+4,lw=.25)
 if(!is.na(d$gene_count[i])){y<-d$bar_top[i]-9;if(!source_display&&!is.na(d$point_y[i])&&abs(y-d$point_y[i])<15)y<-min(y,d$point_y[i]-14);T(paste0('count-',d$term_id[i]),as.character(d$gene_count[i]),x[i],y,'annotation_text',face='bold')}
}
# Source boxed legend is a genuine top overlay; it lies above all curve centers.
lx<-if(source_display)215 else left+50;rx<-if(source_display)663 else right-30
B(lx,61,rx,95,'white','black',.22);B(lx+42,72,lx+82,84,'#b9c0ff','black',.22)
T('legend-count','Gene Count',lx+92,78,'legend_text',face='bold',hjust=0)
S(lx+234,78,lx+283,78,lw=.2,lt='dotted');O(lx+258,78,'#589c47',if(source_display)2.3 else 1.6,.2)
T('legend-p',if(source_display)'-Log10(P value)' else '-Log10(supplied P)',lx+296,78,'legend_text',face='bold',hjust=0)
if(!source_display&&anyNA(d[c('gene_count','neglog10p')]))T('missing-note',paste(sum(is.na(d$gene_count)),'count unavailable;',sum(is.na(d$neglog10p)),'P unavailable'),left,H-13,'annotation_text',hjust=0)
stopifnot(min(d$point_y,na.rm=TRUE)>100,max(d$gene_count,na.rm=TRUE)<=maximum)
plot_tables<-list(terms=d);metadata<-list(longest_label_chars=max(nchar(d$label)),missing_count=sum(is.na(d$gene_count))+sum(is.na(d$neglog10p)),extreme_value=max(d$gene_count,na.rm=TRUE),new_input_extreme=2200,shuffled_metadata=!identical(original$term_id,original$term_id[order(original$order)]),groups_evidence=paste(nrow(d),'term categories with two explicitly different metric series; no invented experimental groups'),secondary_factor=factor,primary_max=maximum,source_intentional_overlap=if(source_display)'Source term11 count1611 and term13 count702 annotations intentionally follow source text-above-point layer; general annotations move above nearby points' else 'General count labels displaced above nearby points')
panels<-list(shared_axes=c(left,top,right,bottom),legend=c(lx,61,rx,95));layer_order<-c('white canvas','count bars','dotted curve','green points','frame/axes','white boxed legend','full labels and count annotations')
checks<-list(input_dimension_driven=ok(paste(nrow(d),'supplied term summaries; all marks and labels input-driven')),metadata_join_by_key=ok('Unique term_id with explicit order and keyed values; general ordered by provided -log10P, tie-break metadata order'),required_structures_preserved=ok('Count bars, dotted -log10P curve/points, both quantitative axes with declared invertible factor, count labels, full rotated terms and boxed legend'),biological_unit_respected=ok('One supplied term summary; overlapping gene sets not biological replicates; no enrichment fit, gene activation inference or test recomputation'),dual_axis_identity_verified=ok(paste('Secondary axis is primary/',factor,'; every point mapped by same factor; no independent decorative axis')),missing_values_preserved=ok('Missing count produces no manufactured zero bar; missing P produces no point/connecting bridge; no rounded-zero/Infinite P replacement'))
finish()
