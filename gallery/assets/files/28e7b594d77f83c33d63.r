draw_panels<-function(x,metrics_path=NULL){
 library(grid);gp<-function(sz=6.5,...)gpar(fontfamily='Arial',fontsize=sz,...);grid.newpage();pushViewport(viewport(gp=gp()))
 # Panel slots use mm, so the native heatmap cells retain physical square geometry.
 pushViewport(viewport(x=unit(1,'mm'),y=unit(61,'mm'),width=unit(68,'mm'),height=unit(44,'mm'),just=c('left','bottom')));grid.draw(ggplot2::ggplotGrob(x$a));upViewport()
 pushViewport(viewport(x=unit(1,'mm'),y=unit(2,'mm'),width=unit(68,'mm'),height=unit(53,'mm'),just=c('left','bottom')));grid.draw(ggplot2::ggplotGrob(x$b));upViewport()
 cf<-bf_colour_function('diverging','biofigure-light-blue-coral',limits=c(-x$limit,x$limit),center=0,skill_root=S)
 pushViewport(viewport(x=unit(73,'mm'),y=unit(24,'mm'),width=unit(61,'mm'),height=unit(79,'mm'),just=c('left','bottom')))
 ht<-ComplexHeatmap::Heatmap(x$importance,name='importance',col=cf,na_col='#E5E8E8',width=unit(ncol(x$importance)*4,'mm'),height=unit(nrow(x$importance)*4,'mm'),cluster_rows=FALSE,cluster_columns=FALSE,row_names_side='right',row_names_gp=gp(),column_names_gp=gp(6.5,col=unname(x$palette[colnames(x$importance)])),column_names_rot=90,column_names_side='top',show_heatmap_legend=FALSE,rect_gp=gpar(col='white',lwd=.35),use_raster=FALSE)
 bf_complexheatmap_font(bf_font('Arial'));h<-ComplexHeatmap::draw(ht,newpage=FALSE,padding=unit(c(1,1,1,1),'mm'));cells<-bf_complexheatmap_cell_metrics(h,'importance');upViewport()
 lg<-ComplexHeatmap::Legend(title='Permutation importance',col_fun=cf,direction='horizontal',legend_width=unit(36,'mm'),at=c(-x$limit,0,x$limit),title_gp=gp(7),labels_gp=gp(),grid_height=unit(2.5,'mm'));lgna<-ComplexHeatmap::Legend(labels='Not selected',legend_gp=gpar(fill='#E5E8E8',col=NA),labels_gp=gp(),grid_height=unit(2.5,'mm'),grid_width=unit(2.5,'mm'));combined<-ComplexHeatmap::packLegend(lg,lgna,direction='vertical',gap=unit(2,'mm'));ComplexHeatmap::draw(combined,x=unit(103,'mm'),y=unit(12,'mm'))
 for(i in 1:3)grid.text(c('A','B','C')[i],x=unit(c(1,1,73)[i],'mm'),y=unit(c(108,58,108)[i],'mm'),just=c('left','top'),gp=gp(8,fontface='bold'))
 grid.force(redraw=FALSE);texts<-character();sizes<-numeric()
 collect<-function(g,inherited=gp()){z<-inherited;for(k in names(g$gp))z[[k]]<-g$gp[[k]];if(inherits(g,'text')&&length(g$label)){stopifnot(!is.expression(g$label));texts<<-c(texts,as.character(g$label));sizes<<-c(sizes,z$fontsize)};for(child in c(g$grobs,as.list(g$children)))collect(child,z)}
 for(n in grid.ls(print=FALSE,recursive=FALSE,viewports=FALSE)$name)collect(grid.get(n,strict=TRUE))
 upViewport();if(!is.null(metrics_path))jsonlite::write_json(list(heatmap_cells=cells,rendered_text=unique(texts),point_sizes=unique(sizes),rendered_size=list(width_mm=136,height_mm=110)),metrics_path,auto_unbox=TRUE,pretty=TRUE);invisible(cells)
}
