suppressPackageStartupMessages({library(ComplexHeatmap);library(circlize);library(grid);library(jsonlite)})
B<-normalizePath(commandArgs(TRUE)[1]);S<-Sys.getenv('BIOFIGURE_ROOT');source(file.path(S,'scripts/figure_style.R'));font<-bf_font('Arial');bf_complexheatmap_font(font);options(warn=2)
spec<-yaml::read_yaml(file.path(B,'design-spec.yaml'));ww<-spec$output_size$width_mm;hh<-spec$output_size$height_mm
gp<-function(...)gpar(fontfamily='Arial',fontsize=7,...)
metrics<-list();device_id<-'unset';d<-read.csv(file.path(B,'input.csv'),check.names=FALSE,stringsAsFactors=FALSE,na.strings=character())
legend_gp<-list(title_gp=gp(),labels_gp=gp())
measure<-function(name,nr,nc,rs=1,cs=1){decorate_heatmap_body(name,{w<-convertWidth(unit(1,'npc'),'mm',TRUE);h<-convertHeight(unit(1,'npc'),'mm',TRUE);err<-abs((w/nc)/(h/nr)-1);stopifnot(err<=.01);metrics[[paste(device_id,name,rs,cs,sep='-')]]<<-list(rows=nr,columns=nc,width_mm=w,height_mm=h,cell_width_mm=w/nc,cell_height_mm=h/nr,relative_error=err)},row_slice=rs,column_slice=cs)}

facets<-FALSE
acids<-unique(d$acid);tf<-unique(d[[if(facets)'enzyme'else'tf']]);v<-if(facets)d$log10FC else d$fold
stopifnot(length(acids)==42,length(tf)==8,nrow(d)==336,!anyDuplicated(paste(d$acid,d[[if(facets)'enzyme'else'tf']])),all(is.finite(v)))
m<-matrix(NA_real_,42,8,dimnames=list(acids,tf));m[cbind(match(d$acid,acids),match(d[[if(facets)'enzyme'else'tf']],tf))]<-v;stopifnot(!anyNA(m),all(m[cbind(match(d$acid,acids),match(d[[if(facets)'enzyme'else'tf']],tf))]==v))
plot_data<-data.frame(acid=d$acid,transcription_factor=d[[if(facets)'enzyme'else'tf']],value=v,group=ifelse(match(d$acid,acids)<=7,'Conventional','BBAA'));write.csv(plot_data,file.path(B,'plot_data.csv'),row.names=FALSE)
colnames(m)<-c('FXR','VDR','CAR','PXR','AHR','PPARα','PPARδ','PPARγ')
groups<-factor(c(rep('Conventional',7),rep('BBAA',35)),levels=c('Conventional','BBAA'))
cols<-colorRamp2(c(0,.3,2),unlist(spec$palette_semantics[c('low','middle','high')]));groupcols<-unlist(spec$palette_semantics[c('Conventional','BBAA')])
ann<-rowAnnotation(Group=groups,col=list(Group=groupcols),simple_anno_size=unit(1.8,'mm'),annotation_name_gp=gp(),show_annotation_name=FALSE,show_legend=FALSE,gp=gpar(col=NA))
ht<-Heatmap(m,name='Response',col=cols,width=unit(24,'mm'),height=unit(129,'mm'),row_split=groups,row_gap=unit(3,'mm'),row_title=NULL,column_title=NULL,cluster_rows=FALSE,cluster_columns=FALSE,cluster_row_slices=FALSE,show_row_names=TRUE,row_names_side='left',row_names_gp=gp(),row_names_max_width=unit(24,'mm'),show_column_names=TRUE,column_names_side='top',column_names_rot=50,column_names_gp=gp(),left_annotation=ann,rect_gp=gpar(col='white',lwd=.25),border=facets,show_heatmap_legend=FALSE)
lg<-list(Legend(title=if(facets)'log10 fold change'else'Response score',col_fun=cols,at=c(0,.3,1,2),legend_height=unit(24,'mm'),title_gp=gp(),labels_gp=gp()),Legend(title='Bile acid class',labels=names(groupcols),legend_gp=gpar(fill=unname(groupcols),col=NA),grid_width=unit(2,'mm'),grid_height=unit(2,'mm'),title_gp=gp(),labels_gp=gp()))
render<-function(){draw(ht,heatmap_legend_list=lg,heatmap_legend_side='right',align_heatmap_legend='heatmap_top',merge_legends=TRUE,padding=unit(c(5,4,7,4),'mm'));measure('Response',7,8,rs=1);measure('Response',35,8,rs=2)
 if(!facets){seekViewport('Response_heatmap_body_wrap');grid.rect(gp=gpar(fill=NA,col='#30343B',lwd=.55));upViewport(0)}
}

for(device in c('png','pdf')){
 device_id<-device
 if(device=='png')ragg::agg_png(file.path(B,'figure.png'),width=ww,height=hh,units='mm',res=450,background='white') else grDevices::quartz(type='pdf',file=file.path(B,'figure.pdf'),width=ww/25.4,height=hh/25.4,family='Arial',bg='white')
 render();dev.off()
}
jsonlite::write_json(list(canvas_mm=c(ww,hh),font='Arial',cells_by_device=metrics,footer_absent=TRUE,title_absent=TRUE,scope=spec$scientific_message,CP3='Native grid export; actual PDF typography and visual inspection required; no ggplot CP3 certificate claimed'),file.path(B,'geometry.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
writeLines(capture.output(sessionInfo()),file.path(B,'environment.txt'));cat('RENDER_OK',basename(B),'\n')
