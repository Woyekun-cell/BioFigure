#!/usr/bin/env Rscript
# Figure 1E; derived from Kay, ggdist paper, CC BY 4.0. See sources/LICENSE.md.
args <- commandArgs(TRUE);stopifnot(length(args)==4)
root<-normalizePath(args[1]);case<-args[2];out<-normalizePath(args[3]);auth<-normalizePath(args[4])
skill<-normalizePath(Sys.getenv('BIOFIGURE_SKILL_ROOT'));source(file.path(skill,'scripts/figure_style.R'))
library(ggplot2);library(ggdist)
font<-bf_font('Arial');spec_path<-Sys.getenv('BIOFIGURE_DESIGN_SPEC',file.path(root,'data/metadata',case,'design-spec.yaml'));spec<-yaml::read_yaml(spec_path)
input<-file.path(root,'results/plot_data',paste0(case,'.csv'));d<-read.csv(input);d$abc<-factor(d$abc,levels=c('a','b','c'))
stopifnot(nrow(d)==600,all(table(d$abc)==200),all(is.finite(d$value)))
pal<-unlist(spec$palette_semantics)
p<-ggplot(d,aes(y=abc,x=value,fill=abc))+
 stat_slab(density='unbounded')+
 stat_dotsinterval(side='bottom',slab_linewidth=NA,slab_colour=NA,layout='bin',point_size=1.8,linewidth=.7,show.legend=FALSE)+
 scale_fill_manual(values=pal)+scale_x_continuous(breaks=c(0,4,8,12))+
 theme_light(base_family=font$family,base_size=8)+
 theme(panel.grid=element_blank(),panel.border=element_blank(),axis.line=element_line(colour='grey70',linewidth=.18),
 axis.ticks=element_line(colour='grey70',linewidth=.18),axis.text=element_text(size=8),axis.title=element_text(size=9),
 legend.text=element_text(size=8),legend.title=element_text(size=9),legend.key.size=grid::unit(4,'mm'),
 axis.title.x=element_text(margin=margin(t=5)),axis.title.y=element_text(margin=margin(r=5)),
 plot.margin=margin(2,2,2,2,'mm'))
b<-ggplot_build(p)
stopifnot(length(b$data)==2,all(vapply(b$data,nrow,integer(1))>0))
write.csv(d,file.path(out,'rendered-input.csv'),row.names=FALSE)
write.csv(b$data[[1]][, !vapply(b$data[[1]],is.list,logical(1)), drop=FALSE],file.path(out,'native-density.csv'),row.names=FALSE)
source_files<-c(spec_path,file.path(root,'scripts/render.R'),file.path(skill,'scripts/figure_style.R'),input)
width<-spec$output_size$width_mm;height<-spec$output_size$height_mm
boxes<-data.frame(id=c('data','labels','legend'),x=c(14,2,120),y=c(2,height-10,20),w=c(103,114,14),h=c(height-14,8,40))
bf_render_png(p,file.path(out,paste0(case,'.png')),font=font,allowed_text=unlist(spec$text_contract$allowed_text),width_mm=width,height_mm=height,target_width_mm=width,dpi=300,min_text_pt=8,source_files=source_files,boxes=boxes,authorization=auth,skill_root=skill,publication_size_class='one-and-half-column')
pdf<-file.path(out,paste0(case,'.pdf'));bf_pdf_open(pdf,width,height,font);print(p);dev.off();bf_pdf_finalize(pdf,font,width,height)
jsonlite::write_json(list(case=case,n=nrow(d),counts=as.list(table(d$abc)),packages=as.list(vapply(c('ggplot2','ggdist','ragg','systemfonts'),function(x)as.character(packageVersion(x)),'')),R=R.version.string,seed=12345,density='unbounded',source='author seeded demonstration, no biological data'),file.path(out,'render-metrics.json'),auto_unbox=TRUE,pretty=TRUE)
writeLines(capture.output(sessionInfo()),file.path(out,'session-info.txt'))
