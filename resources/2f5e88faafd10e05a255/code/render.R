suppressPackageStartupMessages({library(circlize);library(ComplexHeatmap);library(grid);library(jsonlite)})
source(file.path(dirname(normalizePath(commandArgs(TRUE)[1])),'native_export.R'));d<-read.csv(file.path(B,'input.csv'),check.names=FALSE,na.strings='');n<-nrow(d);stopifnot(n==158,!anyDuplicated(paste(d$subjectGuid,d$Flu_Year)))
seas<-factor(d$Flu_Year,levels=c('2020-2021','2021-2022'));seasoncol<-c('2020-2021'='#67B9A5','2021-2022'='#E78C6E');agecol<-c(BR1='#2E9691',BR2='#B78743');sexcol<-c(Female='#9274AC',Male='#65A775');cmvcol<-c(Negative='#438EAF',Positive='#D46D60');rescol<-c('low responder'='#BDDBE8','middle responder'='#76ACCB','high responder'='#1D5E91')
scorecol<-colorRamp2(c(-2,-1,0,1,2),c('#65518E','#88BCC1','#FFF7DE','#ECA66B','#B6335C'));scorefields<-c('Response_Score-Flu B/Phuket HA','Response_Score-Flu B/Washington HA','Response_Score-A/Guangdong','Response_Score-A/Cambodia');groupfields<-sub('Response_Score','Response_Group',scorefields)
# HAI scores are already centered in the author table; no second normalization.
anno<-function(v,colors,h,border='white'){m<-matrix(v,ncol=1);circos.heatmap(m,col=colors,na.col='#C6C8C7',cluster=FALSE,cell.border=border,cell.lwd=.12,track.height=h)}
lg<-function(t,c)Legend(title=t,labels=names(c),legend_gp=gpar(fill=c,col=NA),grid_width=unit(2,'mm'),grid_height=unit(2,'mm'),title_gp=gp(),labels_gp=gp())
draw_figure<-function(){
 par(family='Arial',ps=7,mar=c(0,0,0,0),bg='white',fig=c(.03,.97,.21,.99),xaxs='i',yaxs='i',xpd=FALSE)
 circos.clear();circos.par(start.degree=180,gap.after=c(3.5,180),track.margin=c(.002,.002),cell.padding=c(0,0,0,0),canvas.xlim=c(-1.025,1.025),canvas.ylim=c(-.10,1.03),points.overflow.warning=FALSE)
 circos.heatmap.initialize(matrix(d[[scorefields[1]]],ncol=1),split=seas,cluster=FALSE)
 anno(as.character(seas),seasoncol,.018,NA);anno(d$cohort.cohortGuid,agecol,.02);anno(d$subject.biologicalSex,sexcol,.02);anno(d$CMV,cmvcol,.02)
 bar<-d[['Plasma Cell Freq Changes']];yl<-range(c(0,bar),na.rm=TRUE)
 circos.trackPlotRegion(ylim=yl,track.height=.11,bg.border='#52575C',panel.fun=function(x,y){s<-get.cell.meta.data('sector.index');ids<-which(seas==s);xx<-seq_along(ids)-.5;vv<-bar[ids];good<-is.finite(vv);circos.segments(0,0,length(ids),0,col='#6F7478',lwd=.4);circos.rect(xx[good]-.4,pmin(vv[good],0),xx[good]+.4,pmax(vv[good],0),col='#353B42',border=NA);if(any(!good))circos.points(xx[!good],rep(0,sum(!good)),pch=15,cex=.4,col='#C6C8C7')})
 for(k in seq_len(4)){set_track_gap(.012);anno(d[[groupfields[k]]],rescol,.016);set_track_gap(.004);anno(d[[scorefields[k]]],scorecol,.074)}
 # Strain names label the inner track ends in the empty half, never the data.
 strain<-c('BYam','BVic','H1N1','H3N2');for(k in seq_len(4)){ti<-6+2*(k-1)+1;rr<-get.cell.meta.data('cell.bottom.radius',sector.index=levels(seas)[1],track.index=ti);text(-rr-.025,-.035,strain[k],srt=45,adj=c(1,1),cex=1)}
 circos.clear();par(fig=c(0,1,0,1),new=TRUE)
 legends<-list(Legend(title='Response score (HAI)',col_fun=scorecol,at=c(-2,-1,0,1,2),direction='horizontal',legend_width=unit(28,'mm'),title_gp=gp(),labels_gp=gp()),lg('Season',setNames(seasoncol,c('2020-2021','2021-2022'))),lg('Age group',setNames(agecol,c('Young','Older'))),lg('Sex',sexcol),lg('CMV',cmvcol),lg('Responder group',setNames(rescol,c('Low','Middle','High'))),lg('Missing',c(Missing='#C6C8C7')),Legend(labels='Plasma cell change',legend_gp=gpar(fill='#353B42',col=NA),grid_width=unit(2,'mm'),grid_height=unit(2,'mm'),labels_gp=gp()))
 draw(legends[[1]],x=unit(173,'mm'),y=unit(hh-6,'mm'),just=c('right','top'));pk<-packLegend(list=legends[-1],direction='horizontal',max_width=unit(172,'mm'),row_gap=unit(3,'mm'),column_gap=unit(4,'mm'));draw(pk,x=unit(6,'mm'),y=unit(5,'mm'),just=c('left','bottom'))
 write_json(list(subject_season_order=paste(d$subjectGuid,d$Flu_Year),score_fields=scorefields,bar_range=yl,negative_bar_values=sum(bar<0,na.rm=TRUE),score_limits=c(-2,2),out_of_scale_saturated=sapply(d[scorefields],function(v)sum(abs(v)>2,na.rm=TRUE)),missing_by_track=sapply(d[c(scorefields,groupfields)],function(v)sum(is.na(v))),geometry='Native semicircular sectors; polar tiles are annular sectors, not claimed as rectangular square cells'),file.path(B,'track-order.json'),pretty=TRUE,auto_unbox=TRUE,digits=NA)
}
export_native(draw_figure,'circlize')
