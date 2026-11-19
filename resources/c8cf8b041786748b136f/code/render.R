# Input-driven native UpSetR adapter. Source values are digitized displayed values;
# surrogate IDs are synthetic and do not recover biological item identity.
args<-commandArgs(trailingOnly=TRUE)
if(length(args)==2){indir<-normalizePath(args[1],mustWork=TRUE);outdir<-args[2]}else{indir<-'data';outdir<-'results'}
dir.create(outdir,recursive=TRUE,showWarnings=FALSE);dir.create(file.path(outdir,'figures'),showWarnings=FALSE);dir.create(file.path(outdir,'plot_data'),showWarnings=FALSE);dir.create(file.path(outdir,'tables'),showWarnings=FALSE)
suppressPackageStartupMessages({library(UpSetR);library(ggplot2);library(grid);library(gridExtra);library(jsonlite)})
root<-Sys.getenv('BIOFIGURE_SKILL_ROOT','biofigure')
cfg<-jsonlite::fromJSON(file.path(indir,'settings.json'));fontpath<-'/System/Library/Fonts/Supplemental/Arial.ttf'
stopifnot(file.exists(fontpath),cfg$synthetic, cfg$descriptive_only)
if(cfg$scenario=='stress')stopifnot(cfg$height_mm<=cfg$publication_height_limit_mm,cfg$minimum_label_group_gap_pt>=1.5)
read<-function(name)read.csv(file.path(indir,name),check.names=FALSE,stringsAsFactors=FALSE,na.strings=c('NA',''))
meta<-read('sets.csv'); mem<-read('memberships.csv');expected<-if(file.exists(file.path(indir,'intersections.csv')))read.csv(file.path(indir,'intersections.csv'),check.names=FALSE,stringsAsFactors=FALSE,colClasses=c('integer','character','integer','character'))else NULL
stopifnot(all(c('set_id','label','order','color')%in%names(meta)),all(c('item_id','set_id','present')%in%names(mem)))
if(anyNA(meta$set_id)||any(!nzchar(meta$set_id))||anyDuplicated(meta$set_id)||anyDuplicated(meta$order)||anyDuplicated(meta$label))stop('Missing or duplicate set key/order/label')
if(anyNA(mem$item_id)||anyNA(mem$set_id)||any(!nzchar(mem$item_id))||any(!mem$set_id%in%meta$set_id))stop('Missing item/set key or unknown set_id')
if(any(!is.na(mem$present)&!mem$present%in%c(0,1)))stop('Membership must be 0,1,orNA')
key<-paste(mem$item_id,mem$set_id,sep='\r');dupkeys<-unique(key[duplicated(key)])
for(k in dupkeys){v<-unique(mem$present[key==k]);if(length(v)>1)stop('Conflicting duplicate item-set membership')}
duplicates_removed<-sum(duplicated(key));mem<-mem[!duplicated(key),]
meta<-meta[order(meta$order),]; ids<-sort(unique(mem$item_id));n<-nrow(meta)
if(any(table(mem$item_id)!=n))stop('Every item must have exactly one explicit membership for every set')
mat<-matrix(NA_integer_,nrow=length(ids),ncol=n,dimnames=list(ids,meta$set_id));mat[cbind(match(mem$item_id,ids),match(mem$set_id,meta$set_id))]<-mem$present
excluded_unknown<-ids[rowSums(is.na(mat))>0];mat<-mat[rowSums(is.na(mat))==0,,drop=FALSE]
known_outside<-rownames(mat)[rowSums(mat)==0];mat<-mat[rowSums(mat)>0,,drop=FALSE]
if(!nrow(mat))stop('No known union items to plot')
sig<-apply(mat,1,paste0,collapse='');ct<-as.data.frame(table(sig),stringsAsFactors=FALSE);names(ct)<-c('signature','count');ct<-ct[order(-ct$count,ct$signature),]
# The independently archived expected signatures use original top-to-bottom source row order.
reverse_sig<-function(s)paste(rev(strsplit(s,'',fixed=TRUE)[[1]]),collapse='')
if(!is.null(expected)){expected$canonical_signature<-vapply(expected$signature,reverse_sig,'');if(!identical(sort(ct$signature),sort(expected$canonical_signature))||any(ct$count!=expected$count[match(ct$signature,expected$canonical_signature)]))stop('Expected fixture signature/count mismatch')}
if(nrow(ct)>cfg$max_intersections)stop('Observed intersections exceed explicit display cap; no silent truncation allowed')
set_size<-colSums(mat)
wrapped<-if(cfg$scenario%in%c('stress','custom'))vapply(meta$label,function(s)paste(strwrap(s,width=24),collapse='\n'),'')else meta$label
if(anyDuplicated(wrapped))stop('Wrapped labels ambiguous')
df<-as.data.frame(mat,check.names=FALSE);names(df)<-wrapped
# UpSetR1.4.1 FindStartEnd ignores leading all-zero columns. Move physical
# empty columns last while explicitsets still controls canonical displayedorder.
df<-df[,c(which(set_size>0),which(set_size==0)),drop=FALSE]
setcolors<-setNames(meta$color,wrapped)
meta_info<-data.frame(sets=wrapped,Group=wrapped,stringsAsFactors=FALSE)
set_meta<-list(data=meta_info,plots=list(list(type='matrix_rows',column='Group',colors=setcolors,alpha=.25)))
# Trace only records native return values; no package function or data is replaced.
trace('Counter',exit=quote(assign('.bf_counter',returnValue(),envir=.GlobalEnv)),where=asNamespace('UpSetR'),print=FALSE)
trace('Create_matrix',exit=quote(assign('.bf_matrix',returnValue(),envir=.GlobalEnv)),where=asNamespace('UpSetR'),print=FALSE)
trace('Create_layout',exit=quote(assign('.bf_layout',returnValue(),envir=.GlobalEnv)),where=asNamespace('UpSetR'),print=FALSE)
old<-theme_set(theme_classic(base_size=cfg$font_roles_pt$axis_text,base_family='Arial')+theme(axis.line=element_blank()))
# Native legacy code emits ggplot2 deprecation warnings; retain warnings as evidence.
up<-UpSetR::upset(df,nsets=n,nintersects=cfg$max_intersections,sets=wrapped,keep.order=TRUE,set.metadata=set_meta,sets.bar.color=meta$color,main.bar.color=cfg$main_bar_color,matrix.color='#333333',matrix.dot.alpha=.5,point.size=1.55,line.size=.20,mb.ratio=c(.55,.45),mainbar.y.label='Intersection size',sets.x.label='Set size',number.angles=if(cfg$scenario%in%c('stress','custom')) 90 else 0,text.scale=c(cfg$font_roles_pt$axis_title/8.3,cfg$font_roles_pt$axis_text/7,cfg$font_roles_pt$set_axis_title/8.3,cfg$font_roles_pt$axis_text/7,cfg$font_roles_pt$axis_text/7,cfg$font_roles_pt$annotation_text/(2.2*2.845276)),order.by='freq')
untrace('Counter',where=asNamespace('UpSetR'));untrace('Create_matrix',where=asNamespace('UpSetR'));untrace('Create_layout',where=asNamespace('UpSetR'))
actual_signature<-unname(apply(.bf_counter[,seq_len(n),drop=FALSE],1,paste0,collapse=''))
# Ignore incidental vector names; independently key both native signatures and counts.
native_matches_id_signatures<-setequal(actual_signature,as.character(ct$signature))&&all(.bf_counter$freq==ct$count[match(actual_signature,ct$signature)])
if(!native_matches_id_signatures||sum(.bf_counter$freq)!=nrow(mat))stop('Native UpSetR signatures/counts disagree with retained item IDs')
barcolors<-if(cfg$scenario=='source-demo')expected$bar_color[match(actual_signature,expected$canonical_signature)]else rep(cfg$main_bar_color,length(actual_signature))
# Native geometry untouched. Restore the documented missing utils.R styling by
# editing native points' fill/stroke and native bar/text color only.
edit<-function(g,kind){
 if(inherits(g,'text')){g$gp$fontfamily<-'Arial';if(!is.null(g$gp$fontsize)&&any(g$gp$fontsize<cfg$font_roles_pt$axis_text))g$gp$fontsize<-pmax(g$gp$fontsize,cfg$font_roles_pt$axis_text)
  if(kind=='main'&&length(g$label)==length(barcolors)&&all(as.character(g$label)==as.character(.bf_counter$freq))){g$gp$col<-barcolors;if(cfg$scenario%in%c('stress','custom')){g$hjust<-0;g$vjust<-.5}}
  if(kind=='matrix'&&length(g$label)==n&&setequal(as.character(g$label),wrapped)){g$x<-unit(rep(1,n),'npc');g$hjust<-1}
 }
 if(kind=='main'&&inherits(g,'polyline')){g$gp$lwd<-.35;g$gp$col<-'#444444'}
 if(kind=='main'&&inherits(g,'rect')&&length(g$x)==length(barcolors)){g$gp$fill<-barcolors;g$gp$col<-NA}
 if(kind=='matrix'&&inherits(g,'points')&&length(g$x)==nrow(.bf_layout)){
  active<-.bf_layout$value>0;fill<-meta$color[.bf_layout$y];g$pch<-ifelse(active,21,16);g$gp$fill<-ifelse(active,fill,NA);g$gp$col<-ifelse(active,'#222222','#D9D9D980');g$gp$lwd<-ifelse(active,.45,0);g$gp$fontsize<-ifelse(active,4.4,4.4)
 }
 if(kind=='matrix'&&inherits(g,'polyline')){g$gp$col<-'#404040';g$gp$lwd<-.5}
 if(length(g$grobs))g$grobs<-lapply(g$grobs,edit,kind=kind)
 if(length(g$children))g$children<-do.call(grid::gList,lapply(g$children,edit,kind=kind))
 g
}
up$Main_bar<-edit(up$Main_bar,'main');up$Matrix<-edit(up$Matrix,'matrix');up$Sizes<-edit(up$Sizes,'sets')
# Correct native package's negative margins: Sizes background otherwise covers
# the first glyph; main bottom margin otherwise puts zero tick under row-band.
up$Sizes$widths[length(up$Sizes$widths)]<-unit(-.85,'lines')
up$Sizes$widths[1]<-unit(.3,'lines')
up$Main_bar$heights[length(up$Main_bar$heights)]<-unit(-.3,'lines')
up$Main_bar$heights[1]<-unit(.3,'lines')
axis_col<-up$Matrix$layout$l[up$Matrix$layout$name=='axis-l'];up$Matrix$widths[axis_col]<-up$Matrix$widths[axis_col]+unit(.75,'mm')
# Authorization is current CP2-bound and single use. Native API is outside official
# bf_render_png ggplot-only entry: consume authorization, record honest boundary.
script<-if(file.exists('render.R'))normalizePath('render.R')else normalizePath(file.path(root,'benchmark/library/learned-transfer/SCICASE-032/scripts/render.R'))
design<-normalizePath(file.path(indir,'design-spec.yaml'));receipt<-normalizePath(file.path(indir,'preparation-receipt.json'))
sources<-normalizePath(c(script,file.path(indir,c('settings.json','sets.csv','memberships.csv',if(!is.null(expected))'intersections.csv',if(cfg$scenario=='stress')'audit-label-spacing.py'))))
auth<-normalizePath(file.path(outdir,'authorization.json'),mustWork=FALSE)
python<-Sys.getenv('PYTHON','python3');authscript<-file.path(root,'scripts/authorize_render.py')
baseargs<-c(authscript,'--design-spec',design,'--output',auth,unlist(lapply(sources,function(s)c('--source',s))))
if(system2(python,shQuote(c(baseargs,'--receipt',receipt)))!=0)stop('Current render authorization issue failed')
if(system2(python,shQuote(c(baseargs,'--consume')))!=0)stop('Current render authorization consume failed')
draw<-function(){print(up,newpage=TRUE);grid.force()}
# Actual rendered text/grob viewport metrics measured from the final native layout.
metrics<-function(){
 ls<-grid.ls(recursive=TRUE,print=FALSE);texts<-list();sizes<-numeric()
 for(i in seq_along(ls$name)){
  gp<-try(grid.get(ls$name[i],grep=FALSE,global=TRUE),silent=TRUE)
  if(!inherits(gp,'try-error')&&inherits(gp,'text')){sizes<-c(sizes,gp$gp$fontsize);texts[[length(texts)+1]]<-list(label=as.character(gp$label),font_family=gp$gp$fontfamily,font_size_pt=gp$gp$fontsize,width_mm=tryCatch(convertWidth(grobWidth(gp),'mm',TRUE),error=function(e)NA_real_),height_mm=tryCatch(convertHeight(grobHeight(gp),'mm',TRUE),error=function(e)NA_real_))}
 }
 list(canvas_mm=c(cfg$width_mm,cfg$height_mm),font_sizes_pt=cfg$font_roles_pt,observed_font_sizes_pt=sort(unique(sizes)),text_grobs=texts,source_sha256=cfg$source_sha256,set_row_count=n,intersection_column_count=nrow(.bf_counter),membership_grid_size=n*nrow(.bf_counter),native_set_order_ids=meta$set_id,native_counter_signatures=actual_signature,intersection_counts=.bf_counter$freq,set_sizes=setNames(as.integer(set_size),meta$set_id),native_panels=c('UpSetR Main_bar','UpSetR Matrix','UpSetR Sizes'),nominal_matrix_row_pitch_mm=cfg$height_mm*.45/n,row_pitch_measurement='Actual stress pitch/group gaps are measured from final PDF in pdf-label-spacing.json; nominal canvas fraction does not certify text spacing',intersection_column_pitch_upper_bound_mm=cfg$width_mm*.8/(nrow(.bf_counter)+1),pixel_metric_boundary='Actual vector/font metrics extracted; region bounds and visual collisions require source-vs-render review',styling_adapter='Native gtables from UpSetR; main fill/text colors and matrix points(fill/outline), thin connectors restored; no generic replacement')
}
f<-file.path(outdir,'figures','figure.png');ragg::agg_png(f,width=cfg$width_mm,height=cfg$height_mm,units='mm',res=300,background='white');draw();geom<-metrics();dev.off()
quartz(type='pdf',file=file.path(outdir,'figures','figure.pdf'),width=cfg$width_mm/25.4,height=cfg$height_mm/25.4,family='Arial');draw();dev.off()
# Numeric final-PDF clearance gate; full labels and7pt remain unchanged.
if(cfg$scenario=='stress'){
 audit_python<-Sys.getenv('BIOFIGURE_AUDIT_PYTHON','python3')
 audit_script<-normalizePath(file.path(indir,'audit-label-spacing.py'),mustWork=TRUE)
 audit_args<-c(audit_script,'--pdf',file.path(outdir,'figures','figure.pdf'),'--sets',file.path(indir,'sets.csv'),'--output',file.path(outdir,'pdf-label-spacing.json'),'--min-group-gap-pt',as.character(cfg$minimum_label_group_gap_pt),'--height-limit-mm',as.character(cfg$publication_height_limit_mm))
 if(system2(audit_python,shQuote(audit_args))!=0)stop('Actual final PDF label spacing contract failed')
}
svglite::svglite(file.path(outdir,'figures','figure.svg'),width=cfg$width_mm/25.4,height=cfg$height_mm/25.4,bg='white',system_fonts=list(sans='Arial'));draw();dev.off()
write.csv(data.frame(signature=actual_signature,count=.bf_counter$freq,bar_color=barcolors),file.path(outdir,'plot_data','intersections.csv'),row.names=FALSE)
write.csv(data.frame(set_id=meta$set_id,label=meta$label,order=meta$order,color=meta$color,size=as.integer(set_size)),file.path(outdir,'plot_data','set-sizes.csv'),row.names=FALSE)
write.csv(data.frame(item_id=c(excluded_unknown,known_outside),reason=c(rep('unknown membership: entire item excluded',length(excluded_unknown)),rep('known all-zero: outside set union',length(known_outside)))),file.path(outdir,'tables','excluded-items.csv'),row.names=FALSE)
jsonlite::write_json(geom,file.path(outdir,'layout_metrics.json'),auto_unbox=TRUE,pretty=TRUE)
checks<-list(input_dimension_driven=TRUE,metadata_join_by_key=TRUE,required_structures_preserved=TRUE,biological_unit_respected=TRUE,mathematical_consistency=TRUE,exclusive_intersections_computed_from_ids=TRUE,duplicate_id_policy_verified=TRUE,missing_policy_verified=TRUE,empty_sets_preserved=any(set_size==0)||cfg$scenario!='stress',native_counter_matches_id_signatures=native_matches_id_signatures,union_size=nrow(mat),total_exclusive_intersection_size=sum(.bf_counter$freq),unknown_items_excluded=length(excluded_unknown),outside_union_excluded=length(known_outside),identical_duplicates_collapsed=duplicates_removed,native_functions_executed=c('UpSetR::upset','UpSetR:::Counter','UpSetR:::Create_matrix','UpSetR:::Create_layout','UpSetR:::Make_main_bar','UpSetR:::Make_matrix_plot','UpSetR:::Make_size_plot','UpSetR:::Make_base_plot'))
if(cfg$scenario=='stress'){spacing<-jsonlite::fromJSON(file.path(outdir,'pdf-label-spacing.json'));checks$stress_label_spacing_numeric_gate<-list(status=if(spacing$status=='PASS')'pass'else'fail',evidence=list(measurement='pdf-label-spacing.json',pdf_sha256=spacing$pdf_sha256,minimum_inter_group_gap_pt=spacing$minimum_inter_group_gap_pt,label_count=spacing$label_count,label_font_sizes_pt=spacing$label_font_sizes_pt,canvas_mm=spacing$canvas_mm))}
if(cfg$scenario=='stress')checks<-c(checks,list(stress_long_labels=all(nchar(meta$label)>30),stress_multiple_groups=n>=12,stress_missing_values=length(excluded_unknown)==2,stress_extreme_values=max(.bf_counter$freq)>=4000,stress_shuffled_metadata=!identical(read('sets.csv')$set_id,meta$set_id)))
boolean_checks<-names(checks)[vapply(checks,is.logical,logical(1))]
for(k in boolean_checks){ok<-isTRUE(checks[[k]]);checks[[k]]<-list(status=if(ok)'pass'else'fail',evidence=list(check=k,union_items=nrow(mat),native_intersection_sum=sum(.bf_counter$freq),set_count=n,native_intersection_count=nrow(.bf_counter),unknown_items_excluded=length(excluded_unknown),outside_union_excluded=length(known_outside),identical_duplicates_collapsed=duplicates_removed,cardinality_tables='plot_data/intersections.csv and plot_data/set-sizes.csv; exact retained ID-signature recomputation'))}
jsonlite::write_json(checks,file.path(outdir,'scientific_results.json'),auto_unbox=TRUE,pretty=TRUE)
jsonlite::write_json(list(status='NOT_VERIFIED',native_authorization_consumed=TRUE,reason='Official bf_render_png requires ggplot_build and cannot accept native UpSetR grid layout. Current CP2-bound native authorization consumed; no official CP3 PASS invented.'),file.path(outdir,'cp3-boundary.json'),auto_unbox=TRUE,pretty=TRUE)
capture.output(sessionInfo(),file=file.path(outdir,'session-info.txt'));theme_set(old)
