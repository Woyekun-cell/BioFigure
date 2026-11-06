suppressPackageStartupMessages({library(ggplot2);library(grid);library(jsonlite);library(patchwork)})
source(file.path(dirname(normalizePath(commandArgs(TRUE)[1])),'native_export.R'));d<-read.csv(file.path(B,'input.csv'),check.names=FALSE);st<-read.csv(file.path(B,'statistics.csv'),check.names=FALSE);ids<-st$ID;cols<-setNames(c('#1B9484','#5B9AC6','#D69A3C','#4A434F'),ids);nameset<-c('Nucleoside diphosphate\nmetabolic process','Regulation of neuron\nmigration','Regulation of\nossification','Tissue migration');d$ID<-factor(d$ID,levels=ids);N<-max(d$x)
# Separate viewports keep all four hit tracks, statistic trace and source table aligned.
base<-theme_classic(base_family='Arial',base_size=7)+theme(text=element_text(family='Arial',size=7,colour='#292F34'),axis.text=element_text(size=7,colour='#292F34'),axis.title=element_text(size=7),axis.line=element_line(linewidth=.2),axis.ticks=element_line(linewidth=.2),plot.margin=margin(1,1,1,1,'mm'),plot.background=element_rect(fill='white',colour=NA),legend.position='none')
cur<-ggplot(d,aes(x,runningScore,colour=ID))+geom_hline(yintercept=0,linetype=2,linewidth=.25,colour='#80868B')+geom_line(linewidth=.55)+scale_colour_manual(values=cols)+scale_x_continuous(limits=c(0,N),expand=c(0,0),breaks=seq(0,N,by=5000))+scale_y_continuous(breaks=c(-.4,-.2,0,.2,.4),expand=expansion(mult=c(.05,.05)))+labs(x=NULL,y='Enrichment score')+base+theme(axis.text.x=element_blank(),axis.ticks.x=element_blank())
hit<-ggplot(subset(d,position==1),aes(x,y=as.numeric(ID),colour=ID))+geom_segment(aes(xend=x,yend=as.numeric(ID)+.72),linewidth=.18)+scale_colour_manual(values=cols)+scale_x_continuous(limits=c(0,N),expand=c(0,0))+scale_y_reverse(limits=c(4.85,.8),expand=c(0,0))+theme_void(base_family='Arial')+theme(plot.margin=margin(0,1,0,1,'mm'),legend.position='none')
rankd<-d[d$ID==ids[1],];rank<-ggplot(rankd,aes(x,rank_statistic))+geom_area(fill='#D7DCDD',colour=NA)+geom_line(colour='#747E82',linewidth=.2)+scale_x_continuous(limits=c(0,N),breaks=seq(0,N,by=5000),labels=scales::label_number(big.mark=','),expand=c(0,0))+labs(x='Rank',y='Rank statistic')+base
p<-(cur/hit/rank)+plot_layout(heights=c(5.5,1.8,1.5))
draw_figure<-function(){
 pushViewport(viewport(x=unit(2,'mm'),y=unit(3,'mm'),width=unit(124,'mm'),height=unit(118,'mm'),just=c('left','bottom')));print(p,newpage=FALSE);popViewport()
 xs<-132;ys<-c(111,90,69,48)
 for(i in seq_along(ids)){
  grid.segments(unit(xs,'mm'),unit(ys[i]+1,'mm'),unit(xs+5,'mm'),unit(ys[i]+1,'mm'),gp=gpar(col=cols[i],lwd=1.5))
  grid.text(nameset[i],unit(xs+7,'mm'),unit(ys[i]+1,'mm'),just=c('left','top'),gp=gp())
  grid.text(sprintf('NES  %.2f',st$NES[i]),unit(xs+7,'mm'),unit(ys[i]-8,'mm'),just='left',gp=gp())
  grid.text(sprintf('P  %.3g',st$pvalue[i]),unit(xs+7,'mm'),unit(ys[i]-12,'mm'),just='left',gp=gp())
  grid.text(sprintf('BH q  %.3g',st$p.adjust[i]),unit(xs+7,'mm'),unit(ys[i]-16,'mm'),just='left',gp=gp())
 }
 write_json(list(sets=4,ranked_genes=N,hit_counts=as.list(table(subset(d,position==1)$ID)),curve_source='enrichit::gseaScores on exact GseaVis object',p_values='Existing object values; not new tests',first_set_mismatch='Current object membership yields124 hits/ES0.415857; stored setSize123/ES0.418072. Existing NES and P preserved and mismatch disclosed outside figure.'),file.path(B,'curve-audit.json'),pretty=TRUE,auto_unbox=TRUE)
}
export_native(draw_figure,'patchwork')
