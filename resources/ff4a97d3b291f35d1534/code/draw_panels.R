draw_panels<-function(x,metrics_path=NULL){
 library(grid);grid.newpage();pushViewport(viewport(x=unit(1,'mm'),y=unit(23,'mm'),width=unit(181,'mm'),height=unit(139,'mm'),just=c('left','bottom')));grid.draw(ggplot2::ggplotGrob(x$plot));upViewport();pushViewport(viewport(clip='off',gp=gpar(col='#20242A')))
 texts<-character();sizes<-numeric();legend_boxes<-list();gp<-function(sz=6.5,...)gpar(fontfamily='Arial',fontsize=sz,col='#20242A',...)
 text<-function(label,x,y,sz=6.5,...){g<-textGrob(label,unit(x,'mm'),unit(y,'mm'),just='left',gp=gp(sz,...));grid.draw(g);legend_boxes[[length(legend_boxes)+1]]<<-list(label=label,x_mm=x,y_mm=y,width_mm=convertWidth(grobWidth(g),'mm',valueOnly=TRUE),height_mm=convertHeight(grobHeight(g),'mm',valueOnly=TRUE))}
 for(i in 1:4){xx<-c(5,48,91,134)[i];name<-c('RNA rank score','Simulation rank score','Usability rank score','Scalability rank score')[i];colors<-x$palette[[c('blues','greens','oranges','greys')[i]]];text(name,xx,19,7)
 for(j in 1:100)grid.rect(unit(xx+(j-1)*.33,'mm'),unit(15,'mm'),unit(.332,'mm'),unit(2,'mm'),just=c('left','center'),gp=gpar(fill=colors[j],col=NA))
 text('0',xx,11.5);text('1',xx+32,11.5)
 }
 text('E: Embedding',5,5);text('F: Features',43,5);text('G: Graph',78,5);text('+: Scaled',109,5);text('-: Unscaled',139,5)
 grid.force(redraw=FALSE)
 collect<-function(g,inherited=gp()){z<-inherited;for(k in names(g$gp))z[[k]]<-g$gp[[k]];if(inherits(g,'text')&&length(g$label)){stopifnot(!is.expression(g$label));texts<<-c(texts,as.character(g$label));sizes<<-c(sizes,z$fontsize)};for(child in c(g$grobs,as.list(g$children)))collect(child,z)}
 for(n in grid.ls(print=FALSE,recursive=FALSE,viewports=FALSE)$name)collect(grid.get(n,strict=TRUE))
 if(!is.null(metrics_path))jsonlite::write_json(list(rendered_text=unique(texts),point_sizes=unique(sizes),heatmap_cells=list(),rendered_size=list(width_mm=183,height_mm=163),legend_text_boxes=legend_boxes,native_layer_data=lapply(x$plot$layers,function(z)list(geom=class(z$geom)[1],data=z$data))),metrics_path,pretty=TRUE,auto_unbox=TRUE,digits=NA,na='null')
 upViewport();invisible(NULL)
}
