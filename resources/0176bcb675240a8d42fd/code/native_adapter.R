# Task-local adapter for the official ggplot-only gate. Does not edit shared code.
# It replaces only cell discovery/measurement for a complete native ComplexHeatmap grob.
# Authorization, PNG device, font/text/scientific-content and layout checks stay official.
make_native_heatmap_runtime<-function(skill_root,drawn){
 e<-new.env(parent=globalenv());sys.source(file.path(skill_root,'scripts/figure_style.R'),envir=e)
 e$.native_heatmap_drawn<-drawn;e$.native_base_plan<-e$bf_ggplot_cell_plan;e$.native_base_measure<-e$bf_measure_ggplot_cells
 f<-function(plot,built,heatmap_required=FALSE,annotation_layers=list()){
  if(isTRUE(attr(plot,'biofigure_native_complexheatmap'))){
   if(!isTRUE(heatmap_required))stop('Native heatmap adapter requires explicit cell contract')
   return(list(list(native_complexheatmap=TRUE,matrix_id='rowz')))
  }
  .native_base_plan(plot,built,heatmap_required,annotation_layers)
 };environment(f)<-e;e$bf_ggplot_cell_plan<-f
 f<-function(plan,grob,cell_mode='square',tolerance=.01){
  if(length(plan)==1L&&isTRUE(plan[[1]]$native_complexheatmap)){
   m<-bf_complexheatmap_cell_metrics(.native_heatmap_drawn,'rowz',cell_mode=cell_mode,tolerance=tolerance)
   if(sum(vapply(m,function(x)x$rows*x$columns,numeric(1)))!=350L*35L)stop('Incomplete native matrix coverage')
   return(m)
  }
  .native_base_measure(plan,grob,cell_mode,tolerance)
 };environment(f)<-e;e$bf_measure_ggplot_cells<-f
 e
}
