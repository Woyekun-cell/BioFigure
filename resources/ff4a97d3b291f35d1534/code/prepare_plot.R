args<-commandArgs(TRUE);P<-normalizePath(args[1]);S<-file.path(P,'biofigure');W<-file.path(P,'work/2026-10-28-scib-table');A<-file.path(S,'benchmark/library/scidraw/scib-table-20261028');source(file.path(S,'scripts/figure_style.R'));library(funkyheatmap);library(dplyr);library(tibble)
raw<-readRDS(file.path(A,'data/raw/scib_summary.rds'));stopifnot(nrow(raw)==20,ncol(raw)==27)
# Evaluate the installed official vignette definitions, excluding its display and final render expressions.
expr<-parse(file.path(A,'sources/scIB.R'));keep<-vapply(expr,function(e)is.call(e)&&as.character(e[[1]])[1]%in%c('<-','library','data'),logical(1));env<-new.env(parent=globalenv());eval(expr[keep],env)
d<-env$scib_summary_plot;d$output_img<-unname(c(Features='F',Embedding='E',Graph='G')[raw$output]);ci<-env$column_info;ci$geom[ci$id=='output_img']<-'text';ci$options[[which(ci$id=='method')]]$width<-4.5;ci$options[[which(ci$id=='features')]]$width<-1.3
pal_ids<-c(blues='brewer-blues-9',greens='brewer-bugn-9',oranges='biofigure-light-apricot',greys='biofigure-light-lilac');pal<-lapply(pal_ids,function(id)bf_palette(id,kind='sequential',n=100,skill_root=S));pal$features<-c(FULL='#30343B',HVG=bf_palette('tol-bright-7',kind='categorical',n=7,skill_root=S)[3]);pal$black<-c('#30343B','#30343B')
p<-funky_heatmap(d,column_info=ci,column_groups=env$column_groups,row_info=env$row_info,palettes=pal,legends=lapply(names(pal),function(k)list(palette=k,enabled=FALSE)),position_args=position_arguments(row_height=.75,row_space=.1,col_annot_offset=3,col_annot_angle=40,expand_xmax=2),scale_column=FALSE,add_abc=FALSE)
for(i in seq_along(p$layers))if(inherits(p$layers[[i]]$geom,'GeomText')){
 z<-p$layers[[i]]$data;z$size<-ifelse(z$label_value%in%c('Method','RNA','Simulations','Usability','Scalability'),7.5,6.5)/ggplot2::.pt;p$layers[[i]]$data<-z;p$layers[[i]]$aes_params$family<-'Arial'
}
# Choose rank-label contrast against the actual native score-bar fill.
rect_data<-do.call(rbind,lapply(p$layers,function(z)if(inherits(z$geom,'GeomRect')&&'row_id'%in%names(z$data))z$data else NULL))
for(i in seq_along(p$layers))if(inherits(p$layers[[i]]$geom,'GeomText')){
 z<-p$layers[[i]]$data
 for(j in which(!is.na(z$overlay)&z$overlay&nzchar(z$label_value))){
  candidate<-rect_data[which(!is.na(rect_data$row_id)&rect_data$row_id==z$row_id[j]&rect_data$xmin<=z$x[j]&rect_data$xmax>=z$x[j]&rect_data$ymin<=z$y[j]&rect_data$ymax>=z$y[j]),]
  if(nrow(candidate)){rgb<-as.numeric(grDevices::col2rgb(tail(candidate$colour,1)))/255;lin<-ifelse(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)^2.4);lum<-sum(lin*c(.2126,.7152,.0722));z$colour[j]<-if(lum<.179)'white'else'#20242A'}
 }
 p$layers[[i]]$data<-z
}
for(i in seq_along(p$layers))if(inherits(p$layers[[i]]$geom,'GeomRect')){p$layers[[i]]$aes_params$linewidth<-.35;if('border_colour'%in%names(p$layers[[i]]$data))p$layers[[i]]$data$border_colour[!is.na(p$layers[[i]]$data$border_colour)]<-'#30343B'}
p<-p+ggplot2::theme(plot.margin=ggplot2::margin(1,1,1,1,'mm'),text=ggplot2::element_text(family='Arial',size=6.5))
x<-list(plot=p,raw=raw,transformed=d,column_info=ci,palette=pal,palette_ids=pal_ids)
saveRDS(x,file.path(W,'plot-inputs.rds'));write.csv(raw,file.path(P,'results/plot_data/scib_table_20261028_source.csv'),row.names=FALSE);write.csv(d,file.path(P,'results/plot_data/scib_table_20261028_display.csv'),row.names=FALSE)
metrics<-lapply(seq_len(nrow(raw)),function(i)list(row=i,method=raw$method[i],output=raw$output[i],features=raw$features[i],scaling=raw$scaling[i]));jsonlite::write_json(list(rows=20,source_columns=27,display_columns=nrow(ci),score_columns=11,missing_source_values=sum(is.na(raw)),source_row_identity=metrics,palette_ids=as.list(pal_ids)),file.path(W,'input-qc.json'),pretty=TRUE,auto_unbox=TRUE)
capture.output(sessionInfo(),file=file.path(W,'analysis-sessionInfo.txt'));cat('Native object',class(p),'\n');print(c(p$width,p$height))
