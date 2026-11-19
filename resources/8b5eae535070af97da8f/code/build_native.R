# Source C-G, native Sushi functions retained, local absolute typography/palette adaptation.
load_case<-function(P){W<-file.path(P,'work/2026-10-28-batch-five/sushi');.libPaths(c(file.path(W,'Rlib'),.libPaths()));suppressPackageStartupMessages(library(Sushi));invisible(W)}
make_native<-function(P){
 W<-file.path(P,'work/2026-10-28-batch-five/sushi');e<-new.env(parent=asNamespace('Sushi'));for(f in list.files(file.path(W,'data/raw'),pattern='rda$',full.names=TRUE))load(f,e)
 # Three category positions sampled from one coordinated muted gradient. Samples remain categorical.
 e$SushiColors<-function(i){if(i==3)return(grDevices::colorRampPalette(c('#526F8A','#77B5AA','#C5A16D'),space='Lab'));if(i==2)return(grDevices::colorRampPalette(c('#56758C','#B18B65'),space='Lab'));grDevices::colorRampPalette(c('#E5EFEB','#82B3AE','#405D7B'),space='Lab')}
 # Keep native function bodies unchanged; bind their lexical lookup to this audit environment.
 for(n in c('plotBedpe','plotBed','plotBedgraph','labelgenome','addlegend','zoomsregion','zoombox','opaque','maptocolors','maptolwd','convertstrandinfo')){f<-getFromNamespace(n,'Sushi');environment(f)<-e;e[[n]]<-f}
 # Match the source continuous key without PDF tile-stitching seams. Data marks are untouched.
 native_addlegend<-e$addlegend
 e$rect<-graphics::rect
 e$addlegend<-function(...){old<-e$rect;e$rect<-function(...){z<-list(...);if(length(z$col)==1&&!is.na(z$col)&&length(z$border)==1&&is.na(z$border)){z$border<-z$col;z$lwd<-.15};do.call(graphics::rect,z)};on.exit(e$rect<-old);native_addlegend(...)}
 e$rendered_text<-character();e$rendered_sizes<-numeric()
 record<-function(text,cex=1){v<-as.character(text);v<-v[nzchar(trimws(v))];e$rendered_text<-c(e$rendered_text,v);e$rendered_sizes<-c(e$rendered_sizes,rep(par('ps')*cex,length(v)))}
 e$mtext<-function(text,...){z<-list(...);record(text,if(is.null(z$cex))1 else z$cex);graphics::mtext(text,...)}
 e$text<-function(...){z<-list(...);if(!is.null(z$labels))record(z$labels,if(is.null(z$cex))1 else z$cex);graphics::text(...)}
 e$axis<-function(side,at=NULL,labels=TRUE,...){v<-graphics::axis(side=side,at=at,labels=labels,...);if(isTRUE(labels))record(format(v,trim=TRUE,scientific=FALSE),par('cex.axis'))else if(!isFALSE(labels))record(labels,par('cex.axis'));invisible(v)}
 e$legend<-function(...){z<-list(...);record(z$legend,if(is.null(z$cex))1 else z$cex);graphics::legend(...)}
 lp<-getFromNamespace('labelplot','Sushi');environment(lp)<-e
 e$panel_metrics<-list();e$labelplot<-function(letter,title,...){lp(letter,title,...);e$panel_metrics[[letter]]<-list(fig=par('fig'),plt=par('plt'),pin_in=par('pin'),usr=par('usr'),font_family=par('family'),pointsize=par('ps'),cex=par('cex'))}
 # paper source layout C-G cutout; inherited B-to-C passthrough borders omitted, E-to-F/G zooms retained.
 layout(matrix(c(1,1,2,2,3,3,4,5),4,2,byrow=TRUE),heights=c(1,1,1,1.15));par(family='Arial',ps=8,cex=1,cex.axis=1,cex.lab=1,cex.main=1,mgp=c(3,.3,0),col.axis='#323B40',col.lab='#323B40',fg='#323B40',xpd=FALSE)
 code<-paste(readLines(file.path(W,'sources/author-panels-C-G.R')),collapse='\n')
 code<-gsub('par(mar=c(3,4,2,2))','par(mar=c(3,4,2,2),cex=1)',code,fixed=TRUE)
 code<-gsub('zoombox(passthrough=TRUE)','invisible(NULL)',code,fixed=TRUE)
 code<-gsub('zoombox(zoomregion=zoomregion)','invisible(NULL)',code,fixed=TRUE)
 code<-gsub('cex=.75','cex=.9',code,fixed=TRUE);code<-gsub('cex=0.75','cex=.9',code,fixed=TRUE)
 code<-gsub('labels.digits=0)','labels.digits=0,txt.cex=.9,title.cex=1)',code,fixed=TRUE)
 code<-gsub('line=1.75, cex=.9','line=1.75, cex=1',code,fixed=TRUE)
 code<-gsub('title="distance (bp)"','title=""',code,fixed=TRUE)
 code<-gsub('labels.digits=0,txt.cex=.9,title.cex=1)','labels.digits=0,txt.cex=.9,title.cex=1)\n text(x=chromend,y=-3.8,labels="Distance (bp)",adj=c(1,.5),cex=.9,font=2)',code,fixed=TRUE)
 # Dense true strand pile-up is deterministic with the original wiggle setting and fixed seed.
 set.seed(20261028L);eval(parse(text=code),e)
 list(text=unique(e$rendered_text),sizes_pt=unique(e$rendered_sizes),panels=e$panel_metrics,source_function_calls=c('plotBedpe:loops','plotBedpe:lines:flip','plotBedgraph:signal-gradient','plotBedgraph:overlay-rescale','plotBed:strand-pileup','zoomsregion','zoombox','labelgenome','addlegend'))
}
