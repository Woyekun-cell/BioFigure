suppressPackageStartupMessages({library(ComplexHeatmap);library(circlize);library(grid);library(jsonlite)})
B<-normalizePath(commandArgs(TRUE)[1]);S<-Sys.getenv('BIOFIGURE_ROOT');source(file.path(S,'scripts/figure_style.R'));font<-bf_font('Arial');bf_complexheatmap_font(font);options(warn=2)
spec<-yaml::read_yaml(file.path(B,'design-spec.yaml'));ww<-spec$output_size$width_mm;hh<-spec$output_size$height_mm
gp<-function(...)gpar(fontfamily='Arial',fontsize=7,...)
metrics<-list();device_id<-'unset';d<-read.csv(file.path(B,'input.csv'),check.names=FALSE,stringsAsFactors=FALSE,na.strings=character())
legend_gp<-list(title_gp=gp(),labels_gp=gp())
measure<-function(name,nr,nc,rs=1,cs=1){decorate_heatmap_body(name,{w<-convertWidth(unit(1,'npc'),'mm',TRUE);h<-convertHeight(unit(1,'npc'),'mm',TRUE);err<-abs((w/nc)/(h/nr)-1);stopifnot(err<=.01);metrics[[paste(device_id,name,rs,cs,sep='-')]]<<-list(rows=nr,columns=nc,width_mm=w,height_mm=h,cell_width_mm=w/nc,cell_height_mm=h/nr,relative_error=err)},row_slice=rs,column_slice=cs)}

traits<-c('BMI','TG','GeneralHealth','BristolType','HDL','LifelinesDietScore','Glucose','SmokerOneYearEver')
genes<-c('lacC','gatZ-kbaZ','nagA','agaS','agaF','gatY-kbaY','GH109','agaV','agaC','agaD')
stopifnot(!anyDuplicated(paste(d[['Microbial gene']],d$Phenotype)),all(c('Presence.Beta','Absence.Beta','Presence.bonferroni.p','Absence.bonferroni.p')%in%names(d)))
mk<-function(col){m<-matrix(NA_real_,8,10,dimnames=list(traits,genes));ii<-match(d$Phenotype,traits);jj<-match(d[['Microbial gene']],genes);keep<-!is.na(ii)&!is.na(jj);m[cbind(ii[keep],jj[keep])]<-as.numeric(d[[col]][keep]);m}
a<-mk('Presence.Beta');b<-mk('Absence.Beta');ap<-mk('Presence.bonferroni.p');bp<-mk('Absence.bonferroni.p')
stopifnot(identical(is.na(a),is.na(b)),!any(abs(c(a,b))>.2,na.rm=TRUE))
signs<-function(p,q){x<-matrix('',8,10);both<-!is.na(p)&!is.na(q)&p<.05&q<.05;only<-!is.na(p)&!is.na(q)&p<.05&q>=.05;x[both]<-'*';x[only]<-'#';x}
sa<-signs(ap,bp);sb<-signs(bp,ap)
long<-expand.grid(Phenotype=traits,Gene=genes,stringsAsFactors=FALSE);long$Present_beta<-as.vector(a);long$Absent_beta<-as.vector(b);long$Present_Bonferroni_P<-as.vector(ap);long$Absent_Bonferroni_P<-as.vector(bp);long$Present_mark<-as.vector(sa);long$Absent_mark<-as.vector(sb);write.csv(long,file.path(B,'plot_data.csv'),row.names=FALSE,na='NA')
cols<-colorRamp2(c(-.2,-.1,0,.1,.2),unlist(spec$palette_semantics[c('negative','negative_mid','zero','positive_mid','positive')]))
make<-function(m,s,name,label,showrow=FALSE){Heatmap(m,name=name,col=cols,na_col='#D9DDE0',width=unit(33,'mm'),height=unit(26.4,'mm'),cluster_rows=FALSE,cluster_columns=FALSE,show_row_names=showrow,row_names_side='left',row_names_gp=gp(),row_names_max_width=unit(27,'mm'),column_names_gp=gp(fontface='italic'),column_names_rot=90,column_names_side='bottom',column_title=label,column_title_gp=gp(),rect_gp=gpar(col='white',lwd=.25),border=TRUE,show_heatmap_legend=FALSE,cell_fun=function(j,i,x,y,w,h,fill){if(nzchar(s[i,j]))grid.text(s[i,j],x,y,gp=gp())})}
ht<-make(a,sa,'Present','With mucosal A antigens',TRUE)+make(b,sb,'Absent','Without mucosal A antigens')
lg<-list(Legend(title='Association beta',col_fun=cols,at=c(-.2,-.1,0,.1,.2),legend_height=unit(22,'mm'),title_gp=gp(),labels_gp=gp()),Legend(labels='Not reported',legend_gp=gpar(fill='#D9DDE0',col=NA),labels_gp=gp(),grid_width=unit(2.4,'mm'),grid_height=unit(2.4,'mm')),Legend(labels=c('Both strata','This stratum only'),type='points',pch=c('*','#'),size=unit(2,'mm'),legend_gp=gp(),labels_gp=gp(),title='Bonferroni P < 0.05',title_gp=gp()))
render<-function(){draw(ht,ht_gap=unit(4,'mm'),heatmap_legend_list=lg,heatmap_legend_side='right',merge_legends=TRUE,align_heatmap_legend='heatmap_top',padding=unit(c(5,4,5,4),'mm'));measure('Present',8,10);measure('Absent',8,10)}

for(device in c('png','pdf')){
 device_id<-device
 if(device=='png')ragg::agg_png(file.path(B,'figure.png'),width=ww,height=hh,units='mm',res=450,background='white') else grDevices::quartz(type='pdf',file=file.path(B,'figure.pdf'),width=ww/25.4,height=hh/25.4,family='Arial',bg='white')
 render();dev.off()
}
jsonlite::write_json(list(canvas_mm=c(ww,hh),font='Arial',cells_by_device=metrics,footer_absent=TRUE,title_absent=TRUE,scope=spec$scientific_message,CP3='Native grid export; actual PDF typography and visual inspection required; no ggplot CP3 certificate claimed'),file.path(B,'geometry.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
writeLines(capture.output(sessionInfo()),file.path(B,'environment.txt'));cat('RENDER_OK',basename(B),'\n')
