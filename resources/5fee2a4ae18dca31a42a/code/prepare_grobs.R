args<-commandArgs(TRUE);P<-normalizePath(args[1]);W<-file.path(P,'work/2026-10-29-complex-four');.libPaths(c(file.path(W,'Rlib'),file.path(P,'work/2026-10-29-other-four/Rlib'),.libPaths()));library(ggplot2);library(grid)
for(mid in c('HILBERT','WAVELET','RECURRENCE','HIVE')) {
 w<-file.path(W,mid);q<-jsonlite::fromJSON(file.path(w,'input-qc.json'));p<-readRDS(file.path(w,'plot.rds'))
 ragg::agg_png(file.path(w,'grob-measurement.png'),width=q$width_mm,height=q$height_mm,units='mm',res=200,background='white')
 g<-if(inherits(p,'patchwork'))patchwork::patchworkGrob(p)else ggplotGrob(p)
 labels<-character();sizes<-numeric()
 fix<-function(x){
  if(inherits(x,'text')){if(is.expression(x$label))x$label<-vapply(x$label,function(y)gsub('*degree*','°',gsub('["[:space:]]','',paste(deparse(y),collapse='')),fixed=TRUE),character(1));x$label<-gsub('–','-',x$label,fixed=TRUE);x$label[!nzchar(trimws(x$label))]<-'';x$gp$fontfamily<-'Arial';if(is.null(x$gp$fontsize))x$gp$fontsize<-7;x$gp$cex<-1;if(!is.null(x$gp$fontsize)){x$gp$fontsize<-ifelse(abs(x$gp$fontsize-9)<.01,9,7);sizes<<-c(sizes,x$gp$fontsize)};if(!is.expression(x$label))labels<<-c(labels,as.character(x$label))}
  if(length(x$grobs))x$grobs<-lapply(x$grobs,fix)
  if(length(x$children))x$children<-do.call(gList,lapply(x$children,fix))
  x
 }
 g<-fix(g);grid.newpage();grid.draw(g);grid.force()
 metrics<-list();vps<-grid.ls(viewports=TRUE,grobs=FALSE,print=FALSE)$name
 panel_names<-unique(vps[grepl('^panel;',vps)|grepl('^panel-[0-9]+\\.',vps)])
 chosen<-switch(mid,HILBERT=1:4,WAVELET=c(3,7),RECURRENCE=7:9,integer())
 for(n in panel_names){
  id<-as.integer(sub('.*-([0-9]+)\\..*','\\1',n));if(!id%in%chosen)next
  seekViewport(n);if(grepl('^panel;',n))downViewport('panel.1-1-1-1')
  bw<-convertWidth(unit(1,'npc'),'mm',TRUE);bh<-convertHeight(unit(1,'npc'),'mm',TRUE);upViewport(0)
  nr<-switch(mid,HILBERT=64L,WAVELET=49L,RECURRENCE=352L);nc<-switch(mid,HILBERT=64L,WAVELET=256L,RECURRENCE=352L)
  metrics[[length(metrics)+1]]<-list(panel_id=paste0(mid,'-',id),matrix_id=paste0(mid,'-',id),rows=nr,columns=nc,matrix_rows=nr,matrix_columns=nc,body_width_mm=bw,body_height_mm=bh,cell_width_mm=bw/nc,cell_height_mm=bh/nr,measurement_method='final_body_viewports_mm')
 }
 jsonlite::write_json(metrics,file.path(w,'native-cell-metrics.json'),auto_unbox=TRUE,pretty=TRUE,digits=NA)
 g<-grid.grab(wrap=TRUE);g<-fix(g);dev.off();saveRDS(g,file.path(w,'composed-vector-grob.rds'))
 # Resolve draw-time ggrepel labels and ggforce envelopes in their complete native viewport tree before wrapping the vector grob.
 wrapped<-ggplotify::as.ggplot(g)+theme(text=element_text(family='Arial',size=7),plot.margin=margin(0,0,0,0))
 saveRDS(wrapped,file.path(w,'render-object.rds'))
 
 jsonlite::write_json(list(labels=unique(c(labels[!is.na(labels)&nzchar(trimws(labels))],unlist(q$extra_labels))),point_sizes=sort(unique(sizes)),normalization='All actual text grobs explicitly Arial; preserve role sizes with minimum7pt.'),file.path(w,'text-manifest.json'),auto_unbox=TRUE,pretty=TRUE)
}
