draw_panels<-function(x,metrics_path=NULL){
 library(grid);grid.newpage();texts<-character();sizes<-numeric();boxes<-list();gp<-function(sz=6.5,...)gpar(fontfamily='Arial',fontsize=sz,col='#20242A',...)
 text<-function(label,x,y,sz=6.5,just='left',...){g<-textGrob(label,unit(x,'mm'),unit(y,'mm'),just=just,gp=gp(sz,...));grid.draw(g);texts<<-c(texts,label);sizes<<-c(sizes,sz);boxes[[length(boxes)+1]]<<-list(label=label,x_mm=x,y_mm=y,width_mm=convertWidth(grobWidth(g),'mm',valueOnly=TRUE),height_mm=convertHeight(grobHeight(g),'mm',valueOnly=TRUE),just=just)}
 positions<-c(1,47,93,139);titles<-c('Human male','Human female','Mouse male','Mouse female');polygons<-list()
 for(i in 1:4){
  pushViewport(viewport(x=unit(positions[i],'mm'),y=unit(24,'mm'),width=unit(43,'mm'),height=unit(96,'mm'),just=c('left','bottom')));grid.draw(ggplot2::ggplotGrob(x$plots[[i]]));upViewport()
  pushViewport(viewport(clip='off'));text(LETTERS[i],positions[i],124,8,fontface='bold');text(titles[i],positions[i]+21.5,124,7.5,'center');upViewport()
  b<-ggplot2::ggplot_build(x$plots[[i]])$data
  polygons[[i]]<-lapply(seq_along(x$renderkeys[[i]]$organ),function(j){d<-b[[j+2]];list(panel=x$panels[[i]]$panel,organ=x$renderkeys[[i]]$organ[j],source_order=j,fill=unique(d$fill),x=d$x,y=d$y,groups=length(unique(d$group)))})
 }
 pushViewport(viewport(clip='off'))
 for(i in 1:6){xx<-c(18,76,134)[(i-1)%%3+1];yy<-if(i<=3)14 else 7;grid.rect(unit(xx,'mm'),unit(yy,'mm'),unit(3,'mm'),unit(2.2,'mm'),just=c('left','center'),gp=gpar(fill=x$palette[i],col='#687480',lwd=.3));text(x$type_labels[i],xx+4.2,yy,6.5)}
 upViewport()
 if(!is.null(metrics_path))jsonlite::write_json(list(rendered_text=unique(texts),point_sizes=unique(sizes),heatmap_cells=list(),rendered_size=list(width_mm=183,height_mm=128),text_boxes=boxes,body_viewports=list(width_mm=43,height_mm=96,aspect_ratio_policy='Native coord_fixed1 inside each body panel;not a common physical species scale.'),native_polygons=polygons,geometry_audit=x$geometry_audit,palette=as.list(x$palette)),metrics_path,pretty=FALSE,auto_unbox=TRUE,digits=NA)
 invisible(NULL)
}
