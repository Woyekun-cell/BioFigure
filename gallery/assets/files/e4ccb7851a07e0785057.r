suppressPackageStartupMessages({library(ggplot2);library(ggtext);library(grid);library(jsonlite)})
source(file.path(dirname(normalizePath(commandArgs(TRUE)[1])),'native_export.R'));d<-read.csv(file.path(B,'input.csv'),check.names=FALSE);st<-fromJSON(file.path(B,'statistics.json'));d$group<-factor(d[['mucosal_A-antigen_presence']],levels=c('without_mucosal_A-antigen','with_mucosal_A-antigen'),labels=c('Without','With'));stopifnot(nrow(d)==3532,!anyNA(d$group));gene<-unique(d$gene_name);colors<-c(Without='#2C8CC4',With='#D36B69');v<-d$corrected_gene_abundance;bracket<-ceiling(max(v)*2)/2+.35;ymax<-bracket+.6;ymin<-floor(min(v)*2)/2-.2
p<-ggplot(d,aes(group,corrected_gene_abundance,colour=group,fill=group))+
 geom_violin(trim=TRUE,width=.82,linewidth=.35)+
 geom_boxplot(width=.32,fill='white',linewidth=.35,outlier.shape=21,outlier.size=.65,outlier.stroke=.15,outlier.alpha=.6,staplewidth=.35)+
 scale_colour_manual(values=colors)+scale_fill_manual(values=setNames(adjustcolor(colors,alpha.f=.12),names(colors)))+
 geom_segment(aes(x=1,xend=2,y=bracket,yend=bracket),inherit.aes=FALSE,data=data.frame(z=1),linewidth=.25,colour='#30343B')+
 geom_segment(aes(x=c(1,2),xend=c(1,2),y=bracket-.12,yend=bracket),inherit.aes=FALSE,data=data.frame(z=1:2),linewidth=.25,colour='#30343B')+
 annotate('text',x=1.5,y=bracket+.28,label=paste('P =',st$P_string),family='Arial',size=7/ggplot2::.pt,colour='#30343B')+
 coord_cartesian(ylim=c(ymin,ymax),clip='off')+
 scale_y_continuous(breaks=seq(ceiling(ymin),floor(ymax)),expand=c(0,0))+
 labs(x='Mucosal A-antigen',y=paste0('ln[<i>',gene,'</i> RPKM]'))+
 theme_classic(base_family='Arial',base_size=7)+theme(text=element_text(family='Arial',size=7,colour='#30343B'),axis.text=element_text(size=7,colour='#30343B'),axis.title=element_text(size=7),axis.title.y=ggtext::element_markdown(size=7,family='Arial'),axis.line=element_line(linewidth=.22,colour='#30343B'),axis.ticks=element_line(linewidth=.22,colour='#30343B'),axis.ticks.length=unit(1,'mm'),legend.position='none',plot.background=element_rect(fill='white',colour=NA),panel.background=element_rect(fill='white',colour=NA),plot.margin=margin(6,6,5,5,'mm'))
built<-ggplot_build(p);boxes<-built$data[[2]];write.csv(boxes[,!vapply(boxes,is.list,logical(1)),drop=FALSE],file.path(B,'box-statistics.csv'),row.names=FALSE)
draw_figure<-function(){print(p,newpage=FALSE);write_json(list(gene=gene,rows=nrow(d),counts=as.list(table(d$group)),test='Published original linear mixed model; not recomputed',P=st$P_string,P_raw=st$P_value,plot_values='Original3532 display rows, not reconstructed full5734-analysis cohort',outline_mm=.35,fill_alpha=.12,known_difference='Separate one-gene canvas with explicit Arial and light transparent fill; all source display values retained'),file.path(B,'distribution-audit.json'),pretty=TRUE,auto_unbox=TRUE,digits=NA)}
export_native(draw_figure,'ggplot2')
