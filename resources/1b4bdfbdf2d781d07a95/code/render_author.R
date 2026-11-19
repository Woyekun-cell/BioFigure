# Author-processed RPE-1 input; unchanged genomic intervals and SNP density.
suppressPackageStartupMessages({library(ggplot2);library(cowplot);library(yaml)})
args<-commandArgs(TRUE); root<-normalizePath(args[1]);work<-normalizePath(args[2]);auth<-args[3]
skill<-normalizePath(Sys.getenv('BIOFIGURE_ROOT'));source(file.path(skill,'scripts/figure_style.R'));font<-bf_font('Arial')
spec<-file.path(root,'data/metadata/design-spec-author.yaml');design<-read_yaml(spec)
options(warn=2)
cowplot::set_null_device('agg')
ragg::agg_png(file.path(work,'assembly-measure.png'),width=183,height=168,units='mm',res=300)
read<-function(n)read.csv(file.path(root,'results/plot_data',paste0(n,'.csv')))
theme_set(bf_theme(font,size=7)+theme(plot.margin=margin(1.5,1.5,1.5,1.5,'mm')))
blank<-theme_void(base_family='Arial',base_size=7)
label<-function(p,text,x=.02,y=.97,size=8) p+draw_label(text,x=x,y=y,hjust=0,vjust=1,fontfamily='Arial',size=size)
d<-read('author_snp_density');ch<-read('author_chromosomes');hdr<-read('author_hdr');hor<-read('author_hor');chrlevels<-ch$chr
# All chromosomes share the same 0-250Mb scale and 0-8% y scale; no rescaling by row.
tracks<-lapply(1:23,function(i){nm<-chrlevels[i];z<-d[d$chr==nm,];h<-hdr[hdr$chr==nm,];o<-hor[hor$chr==nm,]
 ggplot()+geom_rect(data=h,aes(xmin=start/1e6,xmax=end/1e6,ymin=0,ymax=.08),fill='#D9D9D9',colour=NA)+
 geom_line(data=z,aes((start+end)/2e6,density),colour='#5459AC',linewidth=.16)+
 annotate('rect',xmin=0,xmax=ch$length[i]/1e6,ymin=-.009,ymax=-.004,fill='white',colour='#404047',linewidth=.18)+
 geom_rect(data=o,aes(xmin=start/1e6,xmax=end/1e6,ymin=-.009,ymax=-.004),fill='#30343B',colour=NA)+
 scale_x_continuous(limits=c(0,250),breaks=seq(0,floor(ch$length[i]/2e7)*20,20),expand=c(0,0))+scale_y_continuous(limits=c(-.010,.08),breaks=c(0,.04,.08),expand=c(0,0))+
 labs(x=NULL,y=nm)+theme(axis.title.y=element_text(angle=0,vjust=.5,size=7,margin=margin(r=4)),axis.text=element_text(size=6),axis.text.x=element_text(size=6),axis.ticks.x=element_line(linewidth=.15),axis.line.x=element_blank(),axis.ticks.length=grid::unit(.6,'mm'),plot.margin=margin(0,1,0,0,'mm'))
})
tracks<-align_plots(plotlist=tracks,align='v',axis='lr');p<-ggdraw();for(i in 1:23)p<-p+draw_plot(tracks[[i]],x=.005,y=.97-i*.0405,width=.985,height=.0405)
p<-label(p,'RPE-1 Hap1 vs Hap2 SNP density',.015,.995,8)

lg<-data.frame(x=c(.05,.42,.69),label=c('SNP density','HDR','Live HOR'),fill=c('#5459AC','#D9D9D9','#30343B'));legend<-ggplot(lg)+geom_point(aes(x,0,fill=label),shape=22,size=2.5,colour='#666666',stroke=.15)+geom_text(aes(x=x+.04,y=0,label=label),hjust=0,family='Arial',size=7/.pt)+scale_fill_manual(values=setNames(lg$fill,lg$label),guide='none')+coord_cartesian(xlim=c(0,1),ylim=c(-1,1))+blank
p<-p+draw_plot(legend,x=.49,y=.008,width=.495,height=.026)
p<-p+draw_label('Genome position (Mb)',x=.37,y=.018,fontfamily='Arial',size=7)

width<-design$output_size$width_mm;height<-design$output_size$height_mm
sources<-c(spec,normalizePath(file.path(root,'scripts/render_author.R')),file.path(skill,'scripts/figure_style.R'),setdiff(list.files(file.path(root,'results/plot_data'),pattern='\\.csv$',full.names=TRUE),file.path(root,'results/plot_data/display_coordinates.csv')))
# Disjoint physical slots; detailed geometry is also audited visually on the assembled figure.
boxes<-data.frame(id=c('data','labels','legend'),x=c(1,1,width*.44),y=c(6,height-10,height-10),w=c(width-2,width*.40,width*.54),h=c(height-17,8,8))
out<-file.path(root,'evidence/author-final-inspected.png')
bf_render_png(p,out,font,design$text_contract$allowed_text,width,height,width,sources,boxes,authorization=auth,skill_root=skill,publication_size_class='custom',size_override_basis=design$output_size$size_rationale$override_basis,heading_authorization='User requests simulated source-structure reproduction; small panel headings and simulation disclosure are required')
grDevices::quartz(type='pdf',file=file.path(root,'results/figures/author-data-fig3.pdf'),width=width/25.4,height=height/25.4,family='Arial');print(p);invisible(dev.off())
ggsave(file.path(work,'author-figure.svg'),p,device=svglite::svglite,width=width,height=height,units='mm',bg='white')
writeLines(capture.output(sessionInfo()),file.path(root,'data/metadata/environment.txt'))
file.copy(out,file.path(work,'author-figure.png'),overwrite=TRUE)
cat('AUTHORIZED_R_RENDER_OK; AUTHOR_DATA; target_mm=',width,'x',height,'\n')

invisible(dev.off())
