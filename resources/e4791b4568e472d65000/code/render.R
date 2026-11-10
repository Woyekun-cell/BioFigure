suppressPackageStartupMessages({library(ComplexHeatmap);library(circlize);library(grid);library(jsonlite)})
B<-normalizePath(commandArgs(TRUE)[1]);S<-Sys.getenv('BIOFIGURE_ROOT');source(file.path(S,'scripts/figure_style.R'));font<-bf_font('Arial');bf_complexheatmap_font(font);options(warn=2)
spec<-yaml::read_yaml(file.path(B,'design-spec.yaml'));ww<-spec$output_size$width_mm;hh<-spec$output_size$height_mm
gp<-function(...)gpar(fontfamily='Arial',fontsize=7,...)
metrics<-list();device_id<-'unset';d<-read.csv(file.path(B,'input.csv'),check.names=FALSE,stringsAsFactors=FALSE,na.strings=character())
legend_gp<-list(title_gp=gp(),labels_gp=gp())
measure<-function(name,nr,nc,rs=1,cs=1){decorate_heatmap_body(name,{w<-convertWidth(unit(1,'npc'),'mm',TRUE);h<-convertHeight(unit(1,'npc'),'mm',TRUE);err<-abs((w/nc)/(h/nr)-1);stopifnot(err<=.01);metrics[[paste(device_id,name,rs,cs,sep='-')]]<<-list(rows=nr,columns=nc,width_mm=w,height_mm=h,cell_width_mm=w/nc,cell_height_mm=h/nr,relative_error=err)},row_slice=rs,column_slice=cs)}

mat<-as.matrix(d[,-1,drop=FALSE]);rownames(mat)<-d[[1]];stopifnot(identical(dim(mat),c(16L,72L)),!anyNA(mat))
types<-c('Missense','Frameshift','Splice','Nonsense');stopifnot(all(mat%in%c('',types)))
# Order by mutation burden, ties by retained original sample index. No samples removed.
ord<-order(-colSums(mat!=''),seq_len(ncol(mat)));mat<-mat[,ord,drop=FALSE]
write.csv(mat,file.path(B,'plot_matrix.csv'));write.csv(data.frame(sample=colnames(mat),altered_genes=colSums(mat!='')),file.path(B,'sample_counts.csv'),row.names=FALSE)
freq<-rowSums(mat!='')/72*100;write.csv(data.frame(gene=rownames(mat),altered=rowSums(mat!=''),assayed=72,percent=freq),file.path(B,'gene_frequency.csv'),row.names=FALSE)
cols<-unlist(spec$palette_semantics[types])
alter<-c(list(background=function(x,y,w,h)grid.rect(x,y,w*.94,h*.88,gp=gpar(fill='#F3F4F5',col=NA))),lapply(cols,function(color){force(color);function(x,y,w,h)grid.rect(x,y,w*.94,h*.88,gp=gpar(fill=color,col=NA))}))
axis<-function(at,side)list(at=at,labels=as.character(at),side=side,labels_rot=0,gp=gp())
ha<-HeatmapAnnotation(`Altered genes`=anno_barplot(colSums(mat!=''),height=unit(10,'mm'),ylim=c(0,16),border=FALSE,gp=gpar(fill=cols['Missense'],col=NA),axis_param=axis(c(0,8,16),'left')),annotation_name_gp=gp(),annotation_name_side='left',annotation_name_rot=0)
ra<-rowAnnotation(`Tumours (%)`=anno_barplot(freq,width=unit(15,'mm'),ylim=c(0,100),border=FALSE,gp=gpar(fill='#7B9BAF',col=NA),axis_param=axis(c(0,50,100),'top')),annotation_name_gp=gp(),annotation_name_side='top',annotation_name_rot=0)
ht<-oncoPrint(mat,name='Alteration',get_type=function(x)if(nzchar(x))x else character(),alter_fun=alter,alter_fun_is_vectorized=FALSE,col=cols,width=unit(165.6,'mm'),height=unit(36.8,'mm'),row_order=seq_len(16),column_order=seq_len(72),remove_empty_rows=FALSE,remove_empty_columns=FALSE,show_row_names=TRUE,row_names_side='left',row_names_gp=gp(fontface='italic'),row_names_max_width=unit(16,'mm'),show_column_names=FALSE,show_pct=FALSE,top_annotation=ha,right_annotation=ra,bottom_annotation=NULL,show_heatmap_legend=FALSE,border=TRUE)
lg<-Legend(title='Alteration',labels=types,legend_gp=gpar(fill=cols,col=NA),nrow=1,title_gp=gp(),labels_gp=gp(),column_gap=unit(4,'mm'),grid_width=unit(2.5,'mm'),grid_height=unit(2.5,'mm'))
render<-function(){draw(ht,heatmap_legend_list=list(lg),heatmap_legend_side='bottom',merge_legends=TRUE,padding=unit(c(5,3,5,3),'mm'));measure('Alteration',16,72)}

for(device in c('png','pdf')){
 device_id<-device
 if(device=='png')ragg::agg_png(file.path(B,'figure.png'),width=ww,height=hh,units='mm',res=450,background='white') else grDevices::quartz(type='pdf',file=file.path(B,'figure.pdf'),width=ww/25.4,height=hh/25.4,family='Arial',bg='white')
 render();dev.off()
}
jsonlite::write_json(list(canvas_mm=c(ww,hh),font='Arial',cells_by_device=metrics,footer_absent=TRUE,title_absent=TRUE,scope=spec$scientific_message,CP3='Native grid export; actual PDF typography and visual inspection required; no ggplot CP3 certificate claimed'),file.path(B,'geometry.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
writeLines(capture.output(sessionInfo()),file.path(B,'environment.txt'));cat('RENDER_OK',basename(B),'\n')
