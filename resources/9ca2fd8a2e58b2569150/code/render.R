suppressPackageStartupMessages({library(ggplot2);library(grid);library(jsonlite)})
B<-normalizePath(commandArgs(TRUE)[1]);auth<-normalizePath(commandArgs(TRUE)[2]);S<-normalizePath(Sys.getenv('BIOFIGURE_ROOT'));source(file.path(S,'scripts/figure_style.R'));font<-bf_font('Arial');options(warn=2)
specpath<-file.path(B,'design-spec.yaml');spec<-yaml::read_yaml(specpath);ww<-spec$output_size$width_mm;hh<-spec$output_size$height_mm;pal<-unlist(spec$palette_semantics)
d<-read.csv(file.path(B,'input.csv'),check.names=FALSE,stringsAsFactors=FALSE)
sources<-c(specpath,file.path(B,'render.R'),file.path(S,'scripts/figure_style.R'),file.path(B,'input.csv'),file.path(B,'data-origin.json'))
if(file.exists(file.path(B,'published-statistics.json')))sources<-c(sources,file.path(B,'published-statistics.json'))
base_theme<-theme_classic(base_size=7,base_family='Arial')+theme(text=element_text(family='Arial',size=7,colour='#202020'),axis.text=element_text(size=7,colour='#202020'),axis.title=element_text(size=7),legend.text=element_text(size=7),legend.title=element_text(size=7),legend.key.size=unit(2.4,'mm'),legend.key=element_blank(),plot.background=element_rect(fill='white',colour=NA),panel.background=element_rect(fill='white',colour=NA),axis.line=element_line(linewidth=.22,colour='#30343B'),axis.ticks=element_line(linewidth=.20,colour='#30343B'),plot.margin=margin(5,4,4,4,'mm'))
measure_panels<-function(){grid.force();v<-grid.ls(viewports=TRUE,grobs=FALSE,print=FALSE)$name;v<-unique(v[grepl('^panel[.-]',v)]);out<-list();for(n in v){tryCatch({seekViewport(n);lo<-deviceLoc(unit(0,'npc'),unit(0,'npc'),valueOnly=TRUE);hi<-deviceLoc(unit(1,'npc'),unit(1,'npc'),valueOnly=TRUE);out[[n]]<-list(x=lo$x*25.4,y=hh-hi$y*25.4,w=(hi$x-lo$x)*25.4,h=(hi$y-lo$y)*25.4);upViewport(0)},error=function(e)NULL)};out}

stopifnot(nrow(d)>40000,all(d$bin_j>=d$bin_i),!anyDuplicated(paste(d$bin_i,d$bin_j)),all(is.finite(d$zscore)),all(d$anchor1_start_bp==20000000+10000*d$bin_i),all(d$anchor2_start_bp==20000000+10000*d$bin_j))
# Native vector polygons translate the author's pcolormesh lattice, not a rotated bitmap.
n<-nrow(d);x1<-d$anchor1_start_bp/1e6;x2<-d$anchor2_start_bp/1e6;step<-.01
v<-data.frame(id=rep(seq_len(n),each=4),x=as.vector(t(cbind((x1+x2)/2,(x1+step+x2)/2,(x1+step+x2+step)/2,(x1+x2+step)/2))),y=as.vector(t(cbind(x2-x1,x2-x1-step,x2-x1,x2-x1+step))),z=rep(d$zscore,each=4))
stopifnot(nrow(v)==4*n,all(abs(tapply(v$x,v$id,diff)[[1]])>=0))
colors<-pal[c('low','negative_mid','middle','positive_mid','high')]
p<-ggplot(v,aes(x=x,y=y,group=id,fill=z))+geom_polygon(colour=NA)+
 scale_fill_gradientn(colours=unname(colors),limits=c(-1,7),oob=scales::squish,breaks=c(-1,0,3,7),name='HiC-DC+\nz score',guide=guide_colourbar(display='rectangles',nbin=128,barheight=unit(28,'mm'),barwidth=unit(2.5,'mm'),title.position='top'))+
 scale_x_continuous(breaks=seq(21,23,.5),labels=scales::label_number(accuracy=.1),expand=c(0,0))+
 scale_y_continuous(breaks=seq(0,2,.5),labels=scales::label_number(accuracy=.1),expand=c(0,0))+
 coord_fixed(ratio=.5,xlim=c(21,23),ylim=c(0,2),expand=FALSE)+labs(x='chr19 midpoint (Mb)',y='Genomic distance (Mb)')+base_theme+
 theme(legend.position='right',legend.box.spacing=unit(4,'mm'),panel.border=element_rect(colour='#30343B',fill=NA,linewidth=.25))
boxes<-data.frame(id=c('data','labels','legend'),x=c(17,17,165),y=c(5,90,15),w=c(143,143,15),h=c(80,12,65))
receipt<-bf_render_png(p,file.path(B,'figure.png'),font,spec$text_contract$allowed_text,ww,hh,ww,sources,boxes,authorization=auth,skill_root=S,dpi=450,min_text_pt=7,publication_size_class='custom',size_override_basis=spec$output_size$size_rationale$override_basis)
bf_pdf_open(file.path(B,'figure.pdf'),ww,hh,font);print(p);panels<-measure_panels();dev.off();pdf_info<-bf_pdf_finalize(file.path(B,'figure.pdf'),font,ww,hh)
stopifnot(length(panels)==1);panel<-panels[[1]];ratio<-panel$w/panel$h;stopifnot(abs(ratio-2)<.001)
# One bin's horizontal diagonal and vertically projected diagonal must match.
diagx<-panel$w*.01/2;diagy<-panel$h*.02/2;stopifnot(abs(diagx/diagy-1)<.001)
write_json(list(canvas_mm=c(ww,hh),font='Arial',source_cells=n,vector_polygons=n,source_z_unchanged=TRUE,bin_pair_diagonal_mm=c(horizontal=diagx,vertical=diagy),native_panels_mm=panels,color_limits=c(-1,7),white_value=3,below_lower=sum(d$zscore< -1),above_upper=sum(d$zscore>7),footer_absent=TRUE,title_absent=TRUE,pdf_export=pdf_info),file.path(B,'geometry.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
writeLines(capture.output(sessionInfo()),file.path(B,'environment.txt'));cat('OBSERVED_HIC_RENDER_OK\n')
