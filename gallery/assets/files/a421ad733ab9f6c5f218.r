suppressPackageStartupMessages({library(ggplot2);library(grid);library(jsonlite)})
B<-normalizePath(commandArgs(TRUE)[1]);auth<-normalizePath(commandArgs(TRUE)[2]);S<-normalizePath(Sys.getenv('BIOFIGURE_ROOT'));source(file.path(S,'scripts/figure_style.R'));font<-bf_font('Arial');options(warn=2)
specpath<-file.path(B,'design-spec.yaml');spec<-yaml::read_yaml(specpath);ww<-spec$output_size$width_mm;hh<-spec$output_size$height_mm;pal<-unlist(spec$palette_semantics)
d<-read.csv(file.path(B,'input.csv'),check.names=FALSE,stringsAsFactors=FALSE)
sources<-c(specpath,file.path(B,'render.R'),file.path(S,'scripts/figure_style.R'),file.path(B,'input.csv'),file.path(B,'data-origin.json'))
if(file.exists(file.path(B,'published-statistics.json')))sources<-c(sources,file.path(B,'published-statistics.json'))
base_theme<-theme_classic(base_size=7,base_family='Arial')+theme(text=element_text(family='Arial',size=7,colour='#202020'),axis.text=element_text(size=7,colour='#202020'),axis.title=element_text(size=7),legend.text=element_text(size=7),legend.title=element_text(size=7),legend.key.size=unit(2.4,'mm'),legend.key=element_blank(),plot.background=element_rect(fill='white',colour=NA),panel.background=element_rect(fill='white',colour=NA),axis.line=element_line(linewidth=.22,colour='#30343B'),axis.ticks=element_line(linewidth=.20,colour='#30343B'),plot.margin=margin(5,4,4,4,'mm'))
measure_panels<-function(){grid.force();v<-grid.ls(viewports=TRUE,grobs=FALSE,print=FALSE)$name;v<-unique(v[grepl('^panel[.-]',v)]);out<-list();for(n in v){tryCatch({seekViewport(n);lo<-deviceLoc(unit(0,'npc'),unit(0,'npc'),valueOnly=TRUE);hi<-deviceLoc(unit(1,'npc'),unit(1,'npc'),valueOnly=TRUE);out[[n]]<-list(x=lo$x*25.4,y=hh-hi$y*25.4,w=(hi$x-lo$x)*25.4,h=(hi$y-lo$y)*25.4);upViewport(0)},error=function(e)NULL)};out}

suppressPackageStartupMessages({library(ComplexUpset);library(patchwork)})
stopifnot(sum(d$orthogroup_count)==13561,length(unique(d$community_combination))==62,all(d$largest_community_accession_count%in%4:20))
# Unroll a frequency table for native ComplexUpset, without inventing gene identities.
idx<-rep(seq_len(nrow(d)),d$orthogroup_count);u<-data.frame(major=factor(d$largest_community_accession_count[idx],levels=4:20));sets<-paste0('C',6:1)
for(s in sets)u[[s]]<-vapply(strsplit(d$community_combination[idx],'|',fixed=TRUE),function(z)s%in%z,logical(1))
stopifnot(nrow(u)==13561,all(rowSums(u[sets])>=1))
cc<-grDevices::colorRampPalette(unname(pal[c('count_low','count_mid','count_high')]),space='Lab')(17);names(cc)<-as.character(4:20)
th<-base_theme+theme(legend.position='right',panel.grid.major=element_blank(),axis.text.x=element_blank(),axis.ticks.x=element_blank(),plot.margin=margin(3,2,3,2,'mm'),legend.title=element_text(size=7,family='Arial'),legend.text=element_text(size=7,family='Arial'))
# Package internals still emit one ggplot2 size-aesthetic deprecation. Log that
# exact compatibility message; every other warning remains fatal.
compat<-character()
p<-withCallingHandlers(upset(u,intersect=sets,name=NULL,mode='distinct',sort_sets=FALSE,sort_intersections='ascending',sort_intersections_by=c('degree','cardinality'),n_intersections=62,intersections='observed',set_sizes=FALSE,width_ratio=.07,height_ratio=.26,
 matrix=intersection_matrix(geom=geom_point(shape=16,size=1.05),segment=geom_segment(linewidth=.3)),
 stripes=upset_stripes(geom=geom_segment(linewidth=3.1),colors=unname(pal[sets])),
 base_annotations=list('Orthogroups'=intersection_size(mapping=aes(fill=major),counts=FALSE,width=.8)+scale_fill_manual(values=cc,drop=FALSE,name='Accessions in\nlargest community',guide=guide_legend(ncol=1,keyheight=unit(2.4,'mm'),keywidth=unit(2.2,'mm')))+scale_y_continuous(breaks=c(0,200,400,600,800),expand=expansion(mult=c(0,.04)))+labs(y='Orthogroups',x=NULL)),
 themes=upset_modify_themes(list(default=th))),warning=function(w){if(grepl('`size` aesthetic for lines was deprecated|The `size` argument of `element_line',conditionMessage(w))){compat<<-c(compat,conditionMessage(w));invokeRestart('muffleWarning')}})
p<-p&theme(text=element_text(family='Arial',size=7),axis.text=element_text(family='Arial',size=7),axis.title=element_text(family='Arial',size=7),legend.text=element_text(family='Arial',size=7),legend.title=element_text(family='Arial',size=7),plot.background=element_rect(fill='white',colour=NA))
# Native patchwork assembly cannot use the ggplot-only CP3 text collector.
args<-c(file.path(S,'scripts/authorize_render.py'),'--consume','--design-spec',specpath,'--output',auth,unlist(lapply(sources[sources!=specpath],function(z)c('--source',z))));stopifnot(system2('python3',shQuote(args))==0)
ragg::agg_png(file.path(B,'figure.png'),width=ww,height=hh,units='mm',res=450,background='white');print(p);png_panels<-measure_panels();dev.off()
bf_pdf_open(file.path(B,'figure.pdf'),ww,hh,font);print(p);pdf_panels<-measure_panels();dev.off();pdf_info<-bf_pdf_finalize(file.path(B,'figure.pdf'),font,ww,hh)
a<-ComplexUpset::upset_data(u,sets,sort_sets=FALSE,mode='distinct',n_intersections=62,intersections='observed',sort_intersections='ascending',sort_intersections_by=c('degree','cardinality'))
saveRDS(a,file.path(B,'native-upset-audit.rds'))
write.csv(d,file.path(B,'plot_data.csv'),row.names=FALSE)
write_json(list(canvas_mm=c(ww,hh),font='Arial',orthogroups=13561,intersections=62,communities=6,minimum_accessions=4,maximum_accessions=20,png_panels=png_panels,pdf_panels=pdf_panels,compatibility_messages=unique(compat),footer_absent=TRUE,title_absent=TRUE,pdf_export=pdf_info,CP3='Native patchwork assembly; actual PDF/PNG audit required; no ggplot CP3 certificate claimed'),file.path(B,'geometry.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
writeLines(capture.output(sessionInfo()),file.path(B,'environment.txt'));cat('NATIVE_UPSET_RENDER_OK\n')
