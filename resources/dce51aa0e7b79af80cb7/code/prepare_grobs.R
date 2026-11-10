args<-commandArgs(TRUE);P<-normalizePath(args[1]);W<-file.path(P,'work/2026-10-29-grouped-upset');library(ggplot2);library(grid)
{
 w<-W;q<-jsonlite::fromJSON(file.path(w,'input-qc.json'));p<-readRDS(file.path(w,'plot.rds'))
 ragg::agg_png(file.path(w,'grob-measurement.png'),width=q$width_mm,height=q$height_mm,units='mm',res=200,background='white')
 g<-if(inherits(p,'patchwork'))patchwork::patchworkGrob(p)else ggplotGrob(p)
 labels<-character();sizes<-numeric()
 fix<-function(x){
  if(inherits(x,'text')){if(is.expression(x$label))x$label<-vapply(x$label,function(y)gsub('*degree*','°',gsub('["[:space:]]','',paste(deparse(y),collapse='')),fixed=TRUE),character(1));x$label<-gsub('–','-',x$label,fixed=TRUE);x$label[!nzchar(trimws(x$label))]<-'';x$gp$fontfamily<-'Arial';if(is.null(x$gp$fontsize))x$gp$fontsize<-7;x$gp$cex<-1;if(!is.null(x$gp$fontsize)){x$gp$fontsize<-pmax(7,x$gp$fontsize);sizes<<-c(sizes,x$gp$fontsize)};if(!is.expression(x$label))labels<<-c(labels,as.character(x$label))}
  if(length(x$grobs))x$grobs<-lapply(x$grobs,fix)
  if(length(x$children))x$children<-do.call(gList,lapply(x$children,fix))
  x
 }
 g<-fix(g);dev.off();saveRDS(g,file.path(w,'composed-vector-grob.rds'));wrapped<-ggplotify::as.ggplot(g)+theme(text=element_text(family='Arial',size=7),plot.margin=margin(0,0,0,0));saveRDS(wrapped,file.path(w,'render-object.rds'))
 # Province labels include deferred ggrepel text objects, so bind the input label set too.
 
 jsonlite::write_json(list(labels=unique(labels[!is.na(labels)&nzchar(trimws(labels))]),point_sizes=sort(unique(sizes)),normalization='All actual text grobs explicitly Arial; preserve role sizes with minimum7pt.'),file.path(w,'text-manifest.json'),auto_unbox=TRUE,pretty=TRUE)
}
