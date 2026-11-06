#!/usr/bin/env Rscript
# SCICASE-099 grouped stacked-bar adapter. Input-only renderer; no random generation.
suppressPackageStartupMessages({library(ggplot2);library(ragg);library(systemfonts);library(jsonlite);library(digest);library(yaml);library(grid)})
source('figure_style.R')
cfg<-fromJSON('data/settings.json');contract<-fromJSON('contract.json',simplifyVector=FALSE)
spec<-read_yaml('data/design-spec.yaml');font<-bf_font(cfg$font_family)
pt<-function(k)as.numeric(cfg$font_roles_pt[[k]])
required<-function(d,f,n){if(!all(f%in%names(d)))stop('Missing required columns in ',n)}
unique_key<-function(d,k,n){if(anyNA(d[k])||any(!nzchar(d[[k]]))||anyDuplicated(d[[k]]))stop('Invalid unique key in ',n)}
readin<-function(n)read.csv(paste0('data/',n,'.csv'),stringsAsFactors=FALSE,na.strings=c('','NA'))
wrap<-function(x,n=cfg$label_wrap_chars)vapply(x,function(s)paste(strwrap(s,width=n),collapse='\n'),character(1),USE.NAMES=FALSE)
order_table<-function(d,key,n){required(d,c(key,'label','order'),n);unique_key(d,key,n);if(anyNA(d)||anyDuplicated(d$order)||!is.numeric(d$order)||any(!is.finite(d$order))||any(!nzchar(d$label)))stop('Invalid ordering metadata in ',n);d[order(d$order,d[[key]]),,drop=FALSE]}
blocks_raw<-readin('blocks');treat_raw<-readin('treatments');comp_raw<-readin('components')
blocks<-order_table(blocks_raw,'block_id','blocks');treat<-order_table(treat_raw,'treatment_id','treatments');comp<-order_table(comp_raw,'component_id','components')
required(comp,c('color'),'components');if(any(!grepl('^#[0-9A-Fa-f]{6}$',comp$color)))stop('Invalid component color')
nb<-nrow(blocks);nt<-nrow(treat);nc<-nrow(comp)
if(nb<2||nt<2||nc<2||nb*nt>36||nc>10)stop('Supported dimensions: >=2 blocks/treatments/components, <=36bars and <=10components')
if(!isTRUE(cfg$descriptive_only)||!is.logical(cfg$synthetic)||length(cfg$synthetic)!=1||!nzchar(cfg$experimental_unit))stop('Explicit scientific context required')
is_display<-identical(cfg$input_mode,'source_image_digitized_display')
dir.create('results/figures',recursive=TRUE);dir.create('results/plot_data',recursive=TRUE);dir.create('results/tables',recursive=TRUE)
csvout<-function(v,n)write.csv(v,paste0('results/plot_data/',n,'.csv'),row.names=FALSE)
checks<-list();check<-function(n,ok,s){if(!isTRUE(ok))stop('Scientific check failed: ',n);checks[[n]]<<-list(status='pass',evidence=s)}
if(is_display){
 s<-readin('summaries');strokes<-readin('strokes')
 required(s,c('bar_id','block_id','treatment_id','component_id','x','mean','bottom','top','reading_error_px'),'source summaries');required(strokes,c('bar_id','kind','x','xend','y','yend'),'source strokes')
 if(anyNA(s)||anyNA(strokes)||anyDuplicated(paste(s$block_id,s$treatment_id,s$component_id))||any(!s$block_id%in%blocks$block_id)||any(!s$treatment_id%in%treat$treatment_id)||any(!s$component_id%in%comp$component_id))stop('Source display keys invalid')
 nums<-c('x','mean','bottom','top','reading_error_px');if(any(!is.finite(as.matrix(s[nums])))||any(s$mean<0)||any(s$top<s$bottom)||max(abs(s$top-s$bottom-s$mean))>1e-8)stop('Source display bounds invalid')
 if(!identical(cfg$value_mode,'source_display_percent')||!identical(cfg$uncertainty_mode,'observed_display_strokes'))stop('Source display semantics require explicit mode')
 if(any(!is.finite(as.matrix(strokes[c('x','xend','y','yend')]))))stop('Source error-stroke geometry invalid')
 s<-s[order(match(s$block_id,blocks$block_id),match(s$treatment_id,treat$treatment_id),match(s$component_id,comp$component_id)),]
 if(nrow(s)!=nb*nt*nc)stop('Source display complete strata grid required')
 expected_x<-(match(s$block_id,blocks$block_id)-1)*nt+match(s$treatment_id,treat$treatment_id)
 if(max(abs(s$x-expected_x))>1e-10)stop('Source displayed bar order disagrees with keys')
 for(b in unique(s$bar_id)){q<-s[s$bar_id==b,];if(max(abs(q$bottom-c(0,head(q$top,-1))))>1e-8)stop('Source strata continuity failed')}
 s$n<-NA_integer_;s$sd_segment<-NA_real_;s$sd_boundary<-NA_real_;s$error<-NA_real_
 excluded<-data.frame(sample_id=character(),reason=character());input_samples<-NA_integer_;observed_samples<-NA_integer_;closure_error<-NA_real_;denominator_range<-c(NA_real_,NA_real_)
 csvout(s,'source_display_summaries');csvout(strokes,'source_display_strokes')
 check('digitized_display_calibration_verified',max(abs(s$mean-(s$lower_boundary_px-s$upper_boundary_px)/2.15))<1e-8,'Linear source calibration0%=284px,100%=69px,2.15px/percentage point; boundaries +/-1.5px (~0.698 percentage point). Approximate displayed geometry only, never author raw values.')
 check('biological_unit_respected',all(is.na(s$n)),'No original sample unit/n or replicate data inferred; source display summaries and visible strokes only; no statistical re-analysis.')
 check('uncertainty_semantics_verified',identical(cfg$uncertainty_mode,'observed_display_strokes'),'Displayed source error stems/caps preserved as approximate visible union; overlapping marks not assigned biological SD/CI or reconstructed sample statistics.')
}else{
 if(!identical(cfg$value_mode,'composition_percent')||!cfg$uncertainty_mode%in%c('segment_sd_at_boundary','cumulative_boundary_sd'))stop('Explicit complete-vector percentage and SD mode required')
 a<-readin('observations');meta<-readin('metadata');required(a,c('sample_id','component_id','value'),'observations');required(meta,c('sample_id','block_id','treatment_id'),'metadata');unique_key(meta,'sample_id','metadata')
 if(anyNA(a[c('sample_id','component_id')])||anyNA(meta)||any(!nzchar(a$sample_id))||any(!nzchar(a$component_id))||anyDuplicated(paste(a$sample_id,a$component_id)))stop('Observation keys missing or duplicated')
 if(!is.numeric(a$value)||any(is.infinite(a$value))||any(a$value<0,na.rm=TRUE))stop('Nonnegative finite numeric counts required')
 if(!setequal(a$sample_id,meta$sample_id)||any(!a$component_id%in%comp$component_id)||any(!meta$block_id%in%blocks$block_id)||any(!meta$treatment_id%in%treat$treatment_id))stop('Unknown or mismatched observation/metadata IDs')
 if(any(table(a$sample_id)!=nc))stop('Every sample must contain one row per declared component; absent category row is not zero')
 meta2<-meta[order(match(meta$block_id,blocks$block_id),match(meta$treatment_id,treat$treatment_id),meta$sample_id),,drop=FALSE]
 obs2<-a[order(match(a$sample_id,meta2$sample_id),match(a$component_id,comp$component_id)),,drop=FALSE]
 m<-matrix(obs2$value,ncol=nc,byrow=TRUE,dimnames=list(meta2$sample_id,comp$component_id));if(!identical(obs2$sample_id,rep(meta2$sample_id,each=nc)))stop('Key join failed')
 miss<-apply(m,1,anyNA);excluded<-data.frame(sample_id=meta2$sample_id[miss],reason=rep('missing component; whole sample excluded',sum(miss)))
 csvout(excluded,'excluded_samples');input_samples<-nrow(meta2);meta2<-meta2[!miss,,drop=FALSE];m<-m[!miss,,drop=FALSE]
 if(!nrow(m)||any(!is.finite(m)))stop('No valid complete sample vectors or nonfinite values')
 den<-rowSums(m);if(any(den<=0)||any(!is.finite(den)))stop('Zero or nonfinite per-sample denominator invalid')
 percent<-100*m/den;boundary<-t(apply(percent,1,cumsum));closure_error<-max(abs(rowSums(percent)-100));if(closure_error>1e-8)stop('Complete-vector closure failed')
 observed_samples<-nrow(m);denominator_range<-range(den)
 obs<-data.frame(sample_id=rep(meta2$sample_id,each=nc),block_id=rep(meta2$block_id,each=nc),treatment_id=rep(meta2$treatment_id,each=nc),component_id=rep(comp$component_id,nrow(m)),input_count=as.vector(t(m)),denominator=rep(den,each=nc),percent=as.vector(t(percent)),boundary_percent=as.vector(t(boundary)))
 csvout(obs,'complete_sample_composition');csvout(meta2,'keyed_metadata')
 sums<-list();k<-0
 for(b in blocks$block_id)for(ti in treat$treatment_id){
   ids<-which(meta2$block_id==b&meta2$treatment_id==ti);if(length(ids)<3)stop('At least3complete samples per block/treatment required for descriptive SD')
   means<-colMeans(percent[ids,,drop=FALSE]);tops<-cumsum(means)
   for(ci in seq_len(nc)){k<-k+1;sums[[k]]<-data.frame(bar_id=paste(b,ti,sep=':'),block_id=b,treatment_id=ti,component_id=comp$component_id[ci],x=(match(b,blocks$block_id)-1)*nt+match(ti,treat$treatment_id),mean=means[ci],bottom=if(ci==1)0 else tops[ci-1],top=tops[ci],n=length(ids),sd_segment=sd(percent[ids,ci]),sd_boundary=sd(boundary[ids,ci]))}
 }
 s<-do.call(rbind,sums);s$error<-if(cfg$uncertainty_mode=='segment_sd_at_boundary')s$sd_segment else s$sd_boundary;s$ymin<-s$top-s$error;s$ymax<-s$top+s$error
 check('compositional_closure_verified',closure_error<1e-8&&max(abs(tapply(s$mean,s$bar_id,sum)-100))<1e-8,sprintf('%d complete independent sample vectors; all components sum100before group averaging; max error%.3g; positive per-sample denominator retained.',observed_samples,closure_error))
 check('biological_unit_respected',!anyDuplicated(meta2$sample_id),paste(cfg$experimental_unit,'; ncounts sample vectors, not components or technical pseudoreplicates; no generated values inside renderer; exclusions',nrow(excluded)))
 check('uncertainty_semantics_verified',all(is.finite(s$error)),paste(cfg$uncertainty_mode,'; sample SD (not SE/CI);',if(cfg$uncertainty_mode=='segment_sd_at_boundary')'Individual component SD anchored at cumulative component mean per source code; explicitly not cumulative boundary uncertainty.'else'SD computed from cumulative composition within each independent sample before group summaries; complete top boundary has zero SD.'))
 if(contract$mode=='stress'){
  check('stress_long_labels',max(nchar(treat$label))>=30&&max(nchar(blocks$label))>=32&&max(nchar(comp$label))>=28,'Full supplied long block/component labels wrapped; treatment IDs on repeated x positions with full key below data; no labels discarded')
  check('stress_multiple_groups',nb>=5&&nt>=5&&nc>=8,paste(nb,'blocks x',nt,'treatments x',nc,'components; every bar and full category legend retained'))
  check('stress_missing_values',nrow(excluded)==3,'Three incomplete sample vectors excluded with IDs/reasons; no partial denominator or imputed zeros')
  check('stress_extreme_values',max(m)>=1e12&&any(percent==100)&&all(percent>=0&percent<=100+1e-10),'Extreme1e12:0:... preserved; denominator and exact100% singleton composition checked; no axis clipping')
  check('stress_shuffled_metadata',!identical(meta$sample_id,meta2$sample_id)&&!identical(comp_raw$component_id,comp$component_id),'Actual input sample/block/treatment/component tables shuffled; canonical keys+order independent of row position')
 }
}
csvout(s,'grouped_stacked_summary');csvout(comp,'component_order');csvout(blocks,'block_order');csvout(treat,'treatment_order')
s$component<-factor(s$component_id,levels=comp$component_id)
palette<-setNames(comp$color,comp$component_id)
if(!is_display&&cfg$scenario=='stress'){
 ticklabels<-rep(treat$treatment_id,nb);ticksize<-pt('axis_text');xangle<-0
 treatment_key<-data.frame(x=seq((nb*nt)/nt/2+.5,nb*nt,by=(nb*nt)/nt),y=-12,label=paste0(treat$treatment_id,': ',wrap(treat$label,18)))
 lower_y<- -24;upper_y<-133;header_y<-123
}else{
 ticklabels<-rep(wrap(treat$label),nb);xangle<-cfg$axis_label_angle;lower_y<-0;upper_y<-125;header_y<-122
}
block_labels<-data.frame(x=(seq_len(nb)-1)*nt+(nt+1)/2,y=header_y,label=wrap(blocks$label))
legendlabels<-if(is_display)comp$label else wrap(comp$label)
p<-ggplot(s,aes(x,mean,fill=component))+
 geom_col(position=position_stack(reverse=TRUE),width=cfg$bar_width,colour='#30343B',linewidth=cfg$bar_outline_mm)+
 scale_fill_manual(values=palette,breaks=rev(comp$component_id),labels=rev(legendlabels),drop=FALSE)+
 scale_x_continuous(breaks=seq_len(nb*nt),labels=ticklabels,expand=expansion(add=.55))+
 scale_y_continuous(breaks=seq(0,100,20),expand=c(0,0))+
 coord_cartesian(ylim=c(lower_y,upper_y),clip='on')+labs(x=NULL,y=cfg$y_axis_label,fill=NULL)+
 bf_theme(font,pt('axis_text'))+
 theme(axis.text=element_text(size=pt('axis_text'),colour='#000000'),axis.text.x=element_text(angle=xangle,hjust=if(xangle==0).5 else 1,vjust=if(xangle==0).5 else 1,lineheight=.95),axis.title.y=element_text(size=pt('axis_title'),margin=margin(r=1.5,unit='mm')),axis.line=element_line(linewidth=cfg$axis_linewidth_mm),axis.ticks=element_line(linewidth=cfg$axis_linewidth_mm),axis.ticks.length=unit(1.25,'mm'),legend.position=cfg$legend_position,legend.text=element_text(size=pt('legend_text'),lineheight=.98),legend.title=element_blank(),legend.key.height=unit(3.25,'mm'),legend.key.width=unit(6.4,'mm'),legend.key.spacing.y=unit(2.5,'mm'),legend.spacing.x=unit(1.5,'mm'),legend.margin=margin(0,0,0,0,'mm'),plot.margin=margin(1.5,1.0,1.0,1.0,'mm'))
if(is_display){
 p<-p+geom_segment(data=strokes,aes(x=x,y=y,xend=xend,yend=yend),inherit.aes=FALSE,colour='#1A1A1A',linewidth=cfg$error_linewidth_mm)
}else p<-p+geom_errorbar(aes(ymin=ymin,ymax=ymax),width=cfg$error_width,linewidth=cfg$error_linewidth_mm,colour='#1A1A1A')
p<-p+geom_vline(xintercept=(seq_len(nb-1))*nt+.5,linetype='dashed',colour='#000000',linewidth=cfg$separator_linewidth_mm)+geom_text(data=block_labels,aes(x=x,y=y,label=label),inherit.aes=FALSE,family=font$family,size=pt('strip_text')/ggplot2::.pt,lineheight=.95,vjust=.5)
if(!is_display&&cfg$scenario=='stress')p<-p+geom_text(data=treatment_key,aes(x=x,y=y,label=label),inherit.aes=FALSE,family=font$family,size=pt('annotation_text')/ggplot2::.pt,lineheight=.95,vjust=.5)+guides(fill=guide_legend(ncol=4,byrow=TRUE))
if(is_display){
 # Physical plot margins derived from actual source axes: x67..583,
 # y26..284 on800x376. Top block labels occupy explicit exterior lane.
 p<-p+coord_cartesian(ylim=c(0,120),clip='off')+
   theme(legend.key.height=unit(3,'mm'),legend.key.spacing.y=unit(3,'mm'),legend.box.spacing=unit(3,'mm'),legend.margin=margin(t=11.4,r=0,b=0,l=0,unit='mm'))
 ragg::agg_png('source-layout-measure.png',width=cfg$width_mm,height=cfg$height_mm,units='mm',res=300,background='white')
 mg<-ggplotGrob(p);mp<-mg$layout[mg$layout$name=='panel',][1,]
 mx<-convertWidth(sum(mg$widths[seq_len(mp$l-1)]),'mm',valueOnly=TRUE);mt<-convertHeight(sum(mg$heights[seq_len(mp$t-1)]),'mm',valueOnly=TRUE)
 mw<-cfg$width_mm-convertWidth(sum(mg$widths),'mm',valueOnly=TRUE);mh<-cfg$height_mm-convertHeight(sum(mg$heights),'mm',valueOnly=TRUE);mb<-cfg$height_mm-mt-mh;mr<-cfg$width_mm-mx-mw
 dev.off();unlink('source-layout-measure.png')
 targets<-c(left=67/800*cfg$width_mm,right=(800-583)/800*cfg$width_mm,top=26/376*cfg$height_mm,bottom=(376-284)/376*cfg$height_mm)
 margins<-c(t=targets['top']-(mt-1.5),r=targets['right']-(mr-1),b=targets['bottom']-(mb-1),l=targets['left']-(mx-1))
 if(any(margins<0))stop('Source typography cannot fit source physical panel; revise font/legend contract')
 p<-p+theme(plot.margin=margin(t=margins[1],r=margins[2],b=margins[3],l=margins[4],unit='mm'))
}
built<-ggplot_build(p);stack<-built$data[[1]]
check('input_dimension_driven',nrow(stack)==nb*nt*nc&&length(unique(stack$x))==nb*nt,sprintf('%d blocks x%d treatments =%d bars x%d components; all rows drive geom_col and metadata labels.',nb,nt,nb*nt,nc))
check('metadata_join_by_key',identical(sort(unique(s$block_id)),sort(blocks$block_id))&&identical(sort(unique(s$treatment_id)),sort(treat$treatment_id))&&identical(sort(unique(s$component_id)),sort(comp$component_id)),'Explicit complete block_id/treatment_id/component_id keys; metadata order columns define canonical x, stack and legend ordering')
check('required_structures_preserved',all(abs(stack$ymax-s$top)<1e-8)&&all(abs(stack$ymin-s$bottom)<1e-8)&&nrow(block_labels)==nb&&length(palette)==nc,'Actual ggplot2 geom_col position_stack(reverse=TRUE); correct lower/top boundary per component; full reverse-stack legend; centered block headings; nb-1 dashed separators; declared SD or observed source strokes')
w<-cfg$width_mm;h<-cfg$height_mm
# Measure on final device, retaining physical panel/legend extents for independent review.
ragg::agg_png('measure.png',width=w,height=h,units='mm',res=300,background='white')
g<-ggplotGrob(p);pan<-g$layout[g$layout$name=='panel',][1,];usedw<-convertWidth(sum(g$widths),'mm',valueOnly=TRUE);usedh<-convertHeight(sum(g$heights),'mm',valueOnly=TRUE)
px<-convertWidth(sum(g$widths[seq_len(pan$l-1)]),'mm',valueOnly=TRUE);ptop<-convertHeight(sum(g$heights[seq_len(pan$t-1)]),'mm',valueOnly=TRUE);pw<-w-usedw;ph<-h-usedh;py<-h-ptop-ph
guide_name<-paste0('guide-box-',cfg$legend_position);gi<-which(g$layout$name==guide_name);gr<-g$layout[gi,][1,]
gx<-convertWidth(sum(g$widths[seq_len(gr$l-1)]),'mm',valueOnly=TRUE);gtop<-convertHeight(sum(g$heights[seq_len(gr$t-1)]),'mm',valueOnly=TRUE)
if(gr$l>pan$l)gx<-gx+pw;if(gr$t>pan$t)gtop<-gtop+ph
gw<-convertWidth(grobWidth(g$grobs[[gi]]),'mm',valueOnly=TRUE);gh<-convertHeight(grobHeight(g$grobs[[gi]]),'mm',valueOnly=TRUE)
if(cfg$legend_position=='right')gy<-py+(ph-gh)/2 else {gx<-px+(pw-gw)/2;gy<-h-gtop-gh}
labelwidth<-vapply(ticklabels,function(t)convertWidth(grobWidth(textGrob(t,gp=gpar(fontfamily=font$family,fontsize=pt('axis_text')))),'mm',valueOnly=TRUE),numeric(1))
legendwidths<-vapply(legendlabels,function(t)convertWidth(grobWidth(textGrob(t,gp=gpar(fontfamily=font$family,fontsize=pt('legend_text')))),'mm',valueOnly=TRUE),numeric(1))
dev.off();unlink('measure.png')
if(pw<20||ph<20)stop('Measured panel insufficient')
boxes<-data.frame(id=c('data','labels','legend'),x=c(px,.01,max(gx,px+pw)),y=c(py,.01,max(gy,.01)),w=c(pw,max(px-.02,.01),max(gw,.01)),h=c(ph,max(py-.02,.01),max(gh,.01)))
if(cfg$legend_position=='bottom')boxes<-data.frame(id=c('data','labels','legend'),x=c(px,.01,max(gx,.01)),y=c(py,py,max(gy,.01)),w=c(pw,max(px-.02,.01),min(gw,w-max(gx,.01)-.01)),h=c(ph,ph,max(min(gh,py-max(gy,.01)-.01),.01)))
# Slot geometry is physical disjoint layout, not a declaration of text collision PASS.
sources<-normalizePath(c('render.R','figure_style.R','data/design-spec.yaml','data/settings.json',list.files('data',pattern='\\.csv$',full.names=TRUE)))
root<-Sys.getenv('BIOFIGURE_SKILL_ROOT');args<-c(file.path(root,'scripts/authorize_render.py'),'--receipt',normalizePath('data/preparation-receipt.json'),'--design-spec',normalizePath('data/design-spec.yaml'),unlist(lapply(sources[!grepl('\\.yaml$',sources)],function(s)c('--source',s))),'--output',normalizePath('.',mustWork=TRUE)|>file.path('authorization.json'))
if(system2('python3',shQuote(args))!=0)stop('Source authorization failed')
bf_render_png(p,'results/figures/figure.png',font,spec$text_contract$allowed_text,w,h,w,sources,boxes,authorization='authorization.json',skill_root=root,publication_size_class='double-column',min_text_pt=min(unlist(cfg$font_roles_pt)))
pdf_device<-function(filename,width,height,...)grDevices::quartz(type='pdf',file=filename,width=width,height=height,...)
ggsave('results/figures/figure.pdf',p,device=pdf_device,family=font$family,width=w,height=h,units='mm',bg='white')
write_json(checks,'results/scientific_results.json',auto_unbox=TRUE,pretty=TRUE,digits=12)
metrics<-list(method_id='SCICASE-099',scenario=cfg$scenario,width_mm=w,height_mm=h,blocks=nb,treatments=nt,components=nc,bars=nb*nt,input_samples=input_samples,observed_samples=observed_samples,excluded_samples=nrow(excluded),closure_max_error=closure_error,denominator_range=denominator_range,uncertainty_mode=cfg$uncertainty_mode,input_mode=if(is_display)'source_image_digitized_display'else'replicate_component_counts',data_bbox_mm=c(x=px,y=py,w=pw,h=ph),legend_bbox_mm=c(x=gx,y=gy,w=gw,h=gh),bar_pitch_mm=pw/(nb*nt+.1),bar_width_mm=pw/(nb*nt+.1)*cfg$bar_width,bar_outline_mm=cfg$bar_outline_mm,error_linewidth_mm=cfg$error_linewidth_mm,separator_linewidth_mm=cfg$separator_linewidth_mm,axis_text_angle=xangle,legend_position=cfg$legend_position,legend_rows=if(cfg$legend_position=='bottom')ceiling(nc/4)else nc,full_legend_components=as.character(rev(comp$component_id)),label_widths_mm=labelwidth,legend_label_widths_mm=legendwidths,font_sizes_pt=cfg$font_roles_pt,font_file=font$path,font_sha256=digest(file=font$path,algo='sha256'),source_geometry_boundary=if(is_display)'Approximate displayed source geometry +/-1.5px; not original raw data or inferred replicates'else'Synthetic complete-vector adapter test; not source study observations')
write_json(metrics,'results/layout_metrics.json',auto_unbox=TRUE,pretty=TRUE,digits=12);write_json(metrics,'results/geometry.json',auto_unbox=TRUE,pretty=TRUE,digits=12);capture.output(sessionInfo(),file='results/session-info.txt')
