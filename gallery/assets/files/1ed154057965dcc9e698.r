draw_panels<-function(links,loci,metrics_path=NULL){
 library(grid);grid.newpage();texts<-character();sizes<-numeric();arcs<-list();rects<-list();gp<-function(sz=6.5,...)gpar(fontfamily='Arial',fontsize=sz,...)
 text<-function(label,x,y,sz=6.5,just='left',...){texts<<-c(texts,as.character(label));sizes<<-c(sizes,sz);grid.text(label,unit(x,'mm'),unit(y,'mm'),just=just,gp=gp(sz,...))}
 cf<-bf_colour_function('sequential','brewer-blues-9',limits=c(0,1),skill_root=S);peakcol<-bf_palette('npg-inspired-10',kind='categorical',n=10,skill_root=S)[1];left<-17;dw<-114
 for(k in 1:2){
  loc<-loci[k,];d<-links[links$gene==loc$gene,];top<-c(109,61)[k];x<-function(bp)left+dw*(bp-loc$start)/(loc$end-loc$start);tssx<-x(loc$tss)
  text(c('A','B')[k],2,top+1,8,fontface='bold');text(loc$gene,left,top+1,8,fontface='italic');text(paste0(loc$chromosome,' · hg19'),left+dw,top+1,7,'right');text(paste0('n = ',nrow(d),' links'),left,top-5,6.5)
  base<-top-10;grid.lines(unit(c(left,left+dw),'mm'),unit(c(base,base),'mm'),gp=gpar(col='#CBD0D6',lwd=.45))
  for(i in order(abs(d$distance_bp),decreasing=TRUE)){
   r<-d[i,];px<-x(r$peak_midpoint);height<-abs(px-tssx)*.40;theta<-seq(0,pi,length.out=101);xx<-(px+tssx)/2+(px-tssx)/2*cos(theta);yy<-base-height*sin(theta);color<-cf(r$Correlation)
   grid.lines(unit(xx,'mm'),unit(yy,'mm'),gp=gpar(col=color,lwd=.9,alpha=.9,lineend='round'));arcs[[length(arcs)+1]]<-list(source_excel_row=r$source_excel_row,gene=r$gene,peak_midpoint=r$peak_midpoint,tss=r$tss,correlation=r$Correlation,color=color,endpoint_x_mm=c(px,tssx),baseline_y_mm=base,drawn_points=length(theta))
  }
  grid.rect(unit(x(d$peak_start),'mm'),unit(rep(base,nrow(d)),'mm'),unit(dw*(d$peak_end-d$peak_start)/(loc$end-loc$start),'mm'),unit(rep(1.8,nrow(d)),'mm'),just=c('left','center'),gp=gpar(fill=peakcol,col=NA));rects[[k]]<-list(gene=loc$gene,source_rows=as.list(d$source_excel_row),source_width_bp=as.list(d$peak_end-d$peak_start),width_mm=as.list(dw*(d$peak_end-d$peak_start)/(loc$end-loc$start)))
  grid.points(unit(tssx,'mm'),unit(base,'mm'),pch=18,size=unit(2.5,'mm'),gp=gpar(col='#30343B'))
  ay<-top-35;grid.lines(unit(c(left,left+dw),'mm'),unit(c(ay,ay),'mm'),gp=gpar(col='#59616A',lwd=.45));ticks<-seq(ceiling(loc$start/100000)*100000,floor(loc$end/100000)*100000,100000)
  for(v in ticks){xx<-x(v);grid.lines(unit(c(xx,xx),'mm'),unit(c(ay,ay-1),'mm'),gp=gpar(col='#59616A',lwd=.45));text(sprintf('%.2f',v/1e6),xx,ay-3,6.5,'center')}
  text('Genomic position (Mb)',left+dw/2,ay-8,7,'center')
 }
 # Scientific legend stays outside both loci.
 text('Pearson correlation',17,13,7);val<-seq(0,1,length.out=151);for(i in 1:150)grid.rect(unit(17+(i-1)*.25,'mm'),unit(8,'mm'),unit(.252,'mm'),unit(2,'mm'),just=c('left','center'),gp=gpar(fill=cf(val[i]),col=NA))
 for(v in c(0,.5,1))text(sprintf('%.1f',v),17+37.5*v,4.5,6.5,'center')
 grid.rect(unit(72,'mm'),unit(9,'mm'),unit(2,'mm'),unit(2,'mm'),gp=gpar(fill=peakcol,col=NA));text('Linked peak',75,9)
 grid.points(unit(109,'mm'),unit(9,'mm'),pch=18,size=unit(2.5,'mm'),gp=gpar(col='#30343B'));text('Gene TSS',112,9)
 if(!is.null(metrics_path))jsonlite::write_json(list(rendered_text=unique(texts),point_sizes=unique(sizes),heatmap_cells=list(),rendered_size=list(width_mm=136,height_mm=116),arcs=arcs,peak_rectangles=rects,palette_id='brewer-blues-9',color_limits=c(0,1)),metrics_path,pretty=TRUE,auto_unbox=TRUE,digits=NA)
 invisible(NULL)
}
