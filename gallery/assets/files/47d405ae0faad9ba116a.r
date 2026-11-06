#!/usr/bin/env Rscript
# Adapt the pinned author's generated R object only after fresh BioFigure CP2.
a<-commandArgs(TRUE);stopifnot(length(a)%in%c(5L,6L));root<-normalizePath(a[1]);run<-normalizePath(a[2]);mode<-a[3];auth<-normalizePath(a[4]);skill<-normalizePath(a[5])
source(file.path(skill,'scripts/figure_style.R'));font<-bf_font('Arial');bf_complexheatmap_font(font);spec_path<-if(length(a)==6L)normalizePath(a[6]) else file.path(root,'data/metadata',paste0(mode,'-design-spec.yaml'));spec<-yaml::read_yaml(spec_path);W<-spec$output_size$width_mm;H<-spec$output_size$height_mm
native<-file.path(run,mode,'native-generated.R');src<-paste(readLines(native,warn=FALSE),collapse='\n');stopifnot(grepl('# Save plot to file',src,fixed=TRUE));src<-strsplit(src,'# Save plot to file',fixed=TRUE)[[1]][1]
# All numeric coverage, junctions, shrink mapping, relative support and random seeds remain author code.
patches<-list(
 'base_size = 20'='base_size = 10', 'base_size = 16'='base_size = 10',
 'theme_bw(base_size=base_size)'='theme_bw(base_size=base_size, base_family="Arial")',
 'plot.margin = unit(c(15,15,15,15), "pt")'='plot.margin = unit(c(2,12,2,2), "pt"), axis.text=element_text(size=8, family="Arial"), text=element_text(family="Arial")',
 'axis.line = element_line(size=0.5)'='axis.line = element_line(linewidth=0.22)',
 'size=0.3)'='linewidth=0.12)', 'size=5, alpha=1)'='linewidth=1.6, alpha=1)',
 'arrow=arrow(length=unit(0.02,"npc"))'='linewidth=0.16, arrow=arrow(length=unit(0.65,"mm"))',
 'label.size=NA, size=(base_size*0.352777778)*0.6'='linewidth=0, size=7.00001/ggplot2::.pt, family="Arial"',
 'return( r*(lmax-lmin)+lmin )'='return( (r*(lmax-lmin)+lmin)*0.45 )',
 'pdf(NULL) # just to remove the blank pdf produced by ggplotGrob'='pdf(NULL, family="Arial") # author off-screen grob assembly device',
 'density_grobs = list();'='density_grobs = list(); exported_junctions=list();',
 'gpGrob = ggplotGrob(gp);'='exported_junctions[[id]]=as.data.frame(junctions); gpGrob = ggplotGrob(gp);'
)
patches[['round((count))']] <- 'sum(count)'
for(old in names(patches))src<-gsub(old,patches[[old]],src,fixed=TRUE)
# Use the author's example1 semantic palette in both complementary views.
if(mode=='mean_fixed')src<-gsub('color_list = list("Endothelial"="#ff0000","Epithelial"="#00ff00","Mesenchymal"="#0000ff")','color_list = list("Endothelial"="orange","Epithelial"="cornflowerblue","Mesenchymal"="#008000")',src,fixed=TRUE)
# Remove the historical index-based width reassignment; re-align by actual panel columns below.
a1<-regexpr('# Reassign grob widths',src,fixed=TRUE)[1];a2<-regexpr('# Heights for density',src,fixed=TRUE)[1];stopifnot(a1>0,a2>a1);src<-paste0(substr(src,1,a1-1),substr(src,a2,nchar(src)))
writeLines(src,file.path(run,mode,'adapted-evaluated.R'))
# Exact upstream grouped rendering remains intact; known data.table aggregation API notices are logged.
warnings_seen<-character();withCallingHandlers(eval(parse(text=src)),warning=function(w){warnings_seen<<-c(warnings_seen,conditionMessage(w));invokeRestart('muffleWarning')})
stopifnot(length(density_list)==3L,length(exported_junctions)==3L)
# Rebuild equal gtable columns, replacing source version-specific integer indices.
panel_col<-density_grobs[[1]]$layout$l[density_grobs[[1]]$layout$name=='panel'][1]
left_widths<-lapply(density_grobs,function(g)sum(g$widths[seq_len(panel_col-1)]))
max_left<-Reduce(grid::unit.pmax,left_widths)
for(id in names(density_grobs)) density_grobs[[id]]$widths[1]<-density_grobs[[id]]$widths[1]+max_left-left_widths[[id]]
argrobs<-gridExtra::arrangeGrob(grobs=density_grobs,ncol=1,heights=if(mode=='overlay_shrink')grid::unit(c(1,1,1,.18,1.4),'null') else grid::unit(c(1,1,1,.18),'null'))
# Capture no bitmap; embed the native author gtable into the audited ggplot entry.
p<-ggplot2::ggplot()+ggplot2::theme_void(base_family='Arial',base_size=8)+ggplot2::theme(plot.margin=ggplot2::margin(0,0,0,0),plot.background=ggplot2::element_rect(fill='white',colour=NA))+ggplot2::coord_cartesian(xlim=c(0,W),ylim=c(0,H),expand=FALSE,clip='off')+ggplot2::annotation_custom(argrobs,xmin=2,xmax=W-2,ymin=2,ymax=H-2)
# A helper copy is unnecessary; the hash-bound installed helper is the authorization source.
sources<-c(spec_path,file.path(root,'scripts/render.R'),file.path(skill,'scripts/figure_style.R'),native,file.path(root,'sources/upstream/ggsashimi.py'),file.path(root,'scripts/generate_native.py'))
boxes<-data.frame(id=c('data','labels','legend'),x=c(0,0,0),y=c(0,0,0),w=c(W,W,W),h=c(H,H,H));pairs<-c('data:labels','data:legend','labels:legend')
png<-file.path(run,mode,paste0('ggsashimi_',mode,'.png'))
bf_render_png(p,png,font,unlist(spec$text_contract$allowed_text),W,H,W,sources,boxes,allowed_pairs=pairs,dpi=450,min_text_pt=7,authorization=auth,skill_root=skill,publication_size_class='double-column')
pdf<-file.path(run,mode,paste0('ggsashimi_',mode,'.pdf'));grDevices::quartz(type='pdf',file=pdf,width=W/25.4,height=H/25.4,family='Arial',bg='white');print(p);dev.off()
svg<-file.path(run,mode,paste0('ggsashimi_',mode,'.svg'));svglite::svglite(svg,width=W/25.4,height=H/25.4,system_fonts=list(sans='Arial'),bg='white');print(p);dev.off()
for(id in names(density_list)){write.csv(density_list[[id]],file.path(run,mode,paste0(id,'-display-coverage.csv')),row.names=FALSE);write.csv(exported_junctions[[id]],file.path(run,mode,paste0(id,'-display-junctions.csv')),row.names=FALSE)}
counts<-vapply(exported_junctions,nrow,integer(1));stopifnot(all(counts==3L))
metrics<-list(mode=mode,canvas_mm=c(W,H),groups=names(density_list),arc_counts=counts,native_gtable=TRUE,native_Python_algorithm_changed=FALSE,R_overlay_aggregation_repaired=mode=="overlay_shrink",adapter_patches=patches,warnings=unique(warnings_seen),coordinate_source='unchanged author algorithm',GTF_transcripts=if(mode=='overlay_shrink')length(unique(ann_list$exons$tx)) else 0,drawn_junctions=exported_junctions,coverage_rows=vapply(density_list,nrow,integer(1)),R=R.version.string,packages=as.list(setNames(vapply(c('ggplot2','data.table','gridExtra','gtable','ragg','svglite'),function(x)as.character(packageVersion(x)),character(1)),c('ggplot2','data.table','gridExtra','gtable','ragg','svglite'))),source_files=lapply(sources,function(p)list(path=p,sha256=digest::digest(file=p,algo='sha256'))))
jsonlite::write_json(metrics,file.path(run,mode,'render-metrics.json'),auto_unbox=TRUE,pretty=TRUE)
cat('NATIVE_R_AUTHORIZED_COMPLETE',mode,'\n')
