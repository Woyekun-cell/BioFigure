suppressPackageStartupMessages({library(ggplot2);library(grid);library(jsonlite)})
B<-normalizePath(commandArgs(TRUE)[1]);auth<-normalizePath(commandArgs(TRUE)[2]);S<-normalizePath(Sys.getenv('BIOFIGURE_ROOT'));source(file.path(S,'scripts/figure_style.R'));font<-bf_font('Arial');options(warn=2)
specpath<-file.path(B,'design-spec.yaml');spec<-yaml::read_yaml(specpath);ww<-spec$output_size$width_mm;hh<-spec$output_size$height_mm;pal<-unlist(spec$palette_semantics)
d<-read.csv(file.path(B,'input.csv'),check.names=FALSE,stringsAsFactors=FALSE)
sources<-c(specpath,file.path(B,'render.R'),file.path(S,'scripts/figure_style.R'),file.path(B,'input.csv'),file.path(B,'data-origin.json'))
if(file.exists(file.path(B,'published-statistics.json')))sources<-c(sources,file.path(B,'published-statistics.json'))
base_theme<-theme_classic(base_size=7,base_family='Arial')+theme(text=element_text(family='Arial',size=7,colour='#202020'),axis.text=element_text(size=7,colour='#202020'),axis.title=element_text(size=7),legend.text=element_text(size=7),legend.title=element_text(size=7),legend.key.size=unit(2.4,'mm'),legend.key=element_blank(),plot.background=element_rect(fill='white',colour=NA),panel.background=element_rect(fill='white',colour=NA),axis.line=element_line(linewidth=.22,colour='#30343B'),axis.ticks=element_line(linewidth=.20,colour='#30343B'),plot.margin=margin(5,4,4,4,'mm'))
measure_panels<-function(){grid.force();v<-grid.ls(viewports=TRUE,grobs=FALSE,print=FALSE)$name;v<-unique(v[grepl('^panel[.-]',v)]);out<-list();for(n in v){tryCatch({seekViewport(n);lo<-deviceLoc(unit(0,'npc'),unit(0,'npc'),valueOnly=TRUE);hi<-deviceLoc(unit(1,'npc'),unit(1,'npc'),valueOnly=TRUE);out[[n]]<-list(x=lo$x*25.4,y=hh-hi$y*25.4,w=(hi$x-lo$x)*25.4,h=(hi$y-lo$y)*25.4);upViewport(0)},error=function(e)NULL)};out}

kind<-basename(B);levels<-c('S','R','F','P','CG','CHG','CHH');rowlabels<-c('Seedling','Rosette','Flowers','Pollen','CG','CHG','CHH');pos<-setNames(c(8,7,6,5,3,2,1),levels)
stopifnot(nrow(d)==153,!any(d$accession=='6909'),!anyDuplicated(paste(d$group,d$sample,sep="::")),all(d$group%in%levels))
d$position<-unname(pos[d$group]);d$visual_modality<-factor(ifelse(d$group%in%c('CG','CHG','CHH'),'Methylation','Expression'),levels=c('Expression','Methylation'));stopifnot(!anyNA(d$visual_modality),all(d$modality[d$group%in%c('S','R','F','P')]=='Expression'),all(endsWith(d$modality[d$group%in%c('CG','CHG','CHH')],'.methylation')))
if(kind=='ath-cnv'){
 ld<-rbind(transform(d,value=percent_CNV_wrong,estimation='Wrongly',position=position+.16),transform(d,value=percent_CNV_good,estimation='Correctly',position=position-.16));ld$category<-factor(ld$estimation,levels=c('Wrongly','Correctly'));colors<-pal[c('Wrongly','Correctly')];axislabel<-'CNV genes (%)';limits<-c(0,54);breaks<-c(0,10,20,30,40)
}else{ld<-d;ld$value<-if(kind=='ath-correlation')d$correlation else d$percent_wrong;ld$category<-d$visual_modality;colors<-pal[c('Expression','Methylation')];axislabel<-if(kind=='ath-correlation')'Pearson correlation (r)\nOwn assembly vs TAIR10'else'Genes misestimated on TAIR10 (%)';limits<-if(kind=='ath-correlation')c(.6,1.025)else c(0,35);breaks<-if(kind=='ath-correlation')seq(.6,1,.1)else c(0,10,20,30)}
stopifnot(all(is.finite(ld$value)),!any(ld$value<limits[1]|ld$value>limits[2]))
write.csv(ld,file.path(B,'plot_data.csv'),row.names=FALSE)
p<-ggplot(ld,aes(x=value,y=position,group=interaction(group,category),fill=category))+
 geom_boxplot(orientation='y',width=.30,outlier.shape=NA,colour=pal['outline'],linewidth=.25,alpha=.28,staplewidth=.4)+
 geom_point(aes(fill=category),shape=21,colour=adjustcolor(pal['outline'],alpha.f=.6),stroke=.15,size=1.05,position=position_jitter(width=0,height=.07,seed=42),show.legend=FALSE)+
 scale_fill_manual(values=setNames(adjustcolor(colors,alpha.f=.56),names(colors)),name=NULL,breaks=names(colors),guide=guide_legend(nrow=1,override.aes=list(alpha=.65)))+
 scale_y_continuous(breaks=unname(pos),labels=rowlabels,limits=c(.45,8.55),expand=c(0,0))+
 scale_x_continuous(position='top',limits=limits,breaks=breaks,expand=expansion(mult=c(.02,.02)),labels=if(kind=='ath-correlation')scales::label_number(accuracy=.1)else waiver())+
 labs(x=axislabel,y=NULL)+base_theme+theme(legend.position='bottom',legend.justification='center',legend.box.margin=margin(1,0,0,0,'mm'),axis.line.y=element_blank(),axis.ticks.y=element_blank(),axis.title.x.top=element_text(margin=margin(b=2,unit='mm')),panel.grid.major.x=element_line(colour='#EEF0F1',linewidth=.16))
if(kind=='ath-cnv'){
 st<-jsonlite::fromJSON(file.path(B,'published-statistics.json'));st$y<-unname(pos[st$group]);st$label<-sprintf('P = %.2e',st$author_unpaired_Wilcoxon_P)
 p<-p+coord_cartesian(xlim=c(0,40),clip='off',expand=FALSE)+theme(plot.margin=margin(5,30,4,4,'mm'))+geom_text(data=st,aes(x=45,y=y,label=label),inherit.aes=FALSE,family='Arial',size=7/ggplot2::.pt,colour='#30343B',hjust=0)
 write.csv(st,file.path(B,'displayed_source_P.csv'),row.names=FALSE)
}
# Independent fill and outline opacity: keep a readable edge on dense raw points.
p$layers[[2]]$aes_params$alpha<-NULL
p$layers[[2]]$aes_params$fill<-NULL
built<-ggplot_build(p);stopifnot(nrow(built$data[[1]])==if(kind=='ath-cnv')14L else 7L,nrow(built$data[[2]])==nrow(ld),!anyNA(built$data[[2]]$fill));bs<-built$data[[1]];bs<-bs[,!vapply(bs,is.list,logical(1)),drop=FALSE];write.csv(bs,file.path(B,'box-statistics.csv'),row.names=FALSE)
boxes<-data.frame(id=c('data','labels','legend'),x=c(19,2,18),y=c(19,19,96),w=c(ww-24,16,ww-23),h=c(72,72,6))
receipt<-bf_render_png(p,file.path(B,'figure.png'),font,spec$text_contract$allowed_text,ww,hh,ww,sources,boxes,authorization=auth,skill_root=S,dpi=450,min_text_pt=7,publication_size_class='custom',size_override_basis=spec$output_size$size_rationale$override_basis)
bf_pdf_open(file.path(B,'figure.pdf'),ww,hh,font);print(p);panels<-measure_panels();dev.off();pdf_info<-bf_pdf_finalize(file.path(B,'figure.pdf'),font,ww,hh)
write_json(list(canvas_mm=c(ww,hh),font='Arial',source_rows=153,plotted_points=nrow(ld),group_counts=as.list(table(d$group)),native_panels_mm=panels,footer_absent=TRUE,title_absent=TRUE,pdf_export=pdf_info),file.path(B,'geometry.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
writeLines(capture.output(sessionInfo()),file.path(B,'environment.txt'));cat('SOURCE_BOXPLOT_RENDER_OK\n')
