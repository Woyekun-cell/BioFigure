#!/usr/bin/env Rscript
# Native R counterpart of author create_heatmap/tileplot, using official exported statistics only.
a <- commandArgs(TRUE); stopifnot(length(a)==3L)
root <- normalizePath(a[1]); out <- normalizePath(a[2]); auth <- normalizePath(a[3])
skill <- normalizePath(Sys.getenv('BIOFIGURE_SKILL_ROOT'))
source(file.path(skill,'scripts/figure_style.R'))
suppressPackageStartupMessages({library(ggplot2);library(grid);library(circlize)})
specfile <- file.path(root,'data/metadata/design-spec.yaml'); spec <- yaml::read_yaml(specfile)
font <- bf_font('Arial'); W <- 136; H <- 114; cell <- 5
pd <- file.path(root,'results/plot_data')
c <- read.csv(file.path(pd,'fig5c-source.csv'),check.names=FALSE,na.strings='NA')
d <- read.csv(file.path(pd,'fig5d-source.csv'),check.names=FALSE,na.strings='NA')
l <- read.csv(file.path(pd,'fig5l-display.csv'),check.names=FALSE,na.strings=c('','NA'))
l$label[is.na(l$label)] <- ''; c$label[is.na(c$label)] <- ''; d$label[is.na(d$label)] <- ''
stopifnot(nrow(c)==15L,nrow(d)==40L,nrow(l)==32L,sum(is.na(l$log2FoldChange))==1L,
          sum(c$label=='*')==6L,sum(d$label=='*')==18L,sum(l$label=='*')==20L)
factors <- paste0('Factor',5:1); conditions <- c('Fibrotic','Ischemic','Myogenic')
paths <- c('EGFR','Hypoxia','JAK-STAT','MAPK','NFkB','PI3K','TGFb','TNFa')
interactions <- sort(unique(l$interaction),decreasing=TRUE)
stopifnot(length(interactions)==8L,any(l$interaction=='TNC -> ITGA7'&l$type=='Receptor'&l$cell_type=='MY'&is.na(l$log2FoldChange)))
colors <- unlist(spec$palette_semantics)
colfun <- list(c=colorRamp2(c(-4,0,4),colors[c('c_low','c_zero','c_high')],space='LAB'),
              d=colorRamp2(c(-5,0,5),colors[c('d_low','d_zero','d_high')],space='LAB'),
              l=colorRamp2(c(-3.5,0,3.5),colors[c('l_low','l_zero','l_high')],space='LAB'))
c$x <- 26+(match(c$patient_group,conditions)-.5)*cell; c$y <- 104-(match(c$factor,factors)-.5)*cell; c$color <- colfun$c(c$display_value)
d$x <- 79+(match(d$pathway,paths)-.5)*cell;d$y <- 104-(match(d$factor,factors)-.5)*cell;d$color <- colfun$d(d$display_value)
l$x <- ifelse(l$type=='Ligand',70,81)+(match(l$cell_type,c('FB','MY'))-.5)*cell
l$y <- 49-(match(l$interaction,interactions)-.5)*cell
l$color <- '#FFFFFF';l$color[!is.na(l$log2FoldChange)] <- colfun$l(l$log2FoldChange[!is.na(l$log2FoldChange)])
l1 <- l[l$type=='Ligand',];l2 <- l[l$type=='Receptor',]
strip <- data.frame(x=26+(1:3-.5)*5,y=105.1,color=colors[conditions])
p <- ggplot()+theme_void(base_family=font$family)+theme(plot.margin=margin(0,0,0,0),plot.background=element_rect(fill='white',colour=NA))+coord_fixed(xlim=c(0,W),ylim=c(0,H),ratio=1,expand=FALSE,clip='on')
# Four matrix layers are separately measured by the authorized final-device cell audit.
p <- p+geom_tile(data=c,aes(x,y,fill=color),width=5,height=5)+geom_tile(data=d,aes(x,y,fill=color),width=5,height=5)+
  geom_tile(data=l1,aes(x,y,fill=color),width=5,height=5,colour='#D4D4D4',linewidth=.12)+
  geom_tile(data=l2,aes(x,y,fill=color),width=5,height=5,colour='#D4D4D4',linewidth=.12)+
  geom_tile(data=strip,aes(x,y,fill=color),width=5,height=1)+scale_fill_identity()
# White stars preserve the original formatted/source BH labels. Missing cell has no star.
stars <- rbind(c[,c('x','y','label')],d[,c('x','y','label')],l[,c('x','y','label')]);stars<-stars[stars$label=='*',]
p <- p+geom_text(data=stars,aes(x,y,label=label),family=font$family,size=8/ggplot2::.pt,colour='white',fontface='bold',vjust=.5)
text <- function(x,y,label,size=6.5,hjust=0.5,vjust=.5,angle=0,face='plain') {
 p <<- p+geom_text(data=data.frame(x=x,y=y,label=label),aes(x,y,label=label),family=font$family,size=size/ggplot2::.pt,hjust=hjust,vjust=vjust,angle=angle,fontface=face,lineheight=1)
}
text(c(5,64,30),c(110,110,54),c('c','d','l'),9,hjust=0,face='bold')
text(rep(24.8,5),104-(1:5-.5)*5,paste('Factor',5:1),hjust=1)
text(rep(77.8,5),104-(1:5-.5)*5,paste('Factor',5:1),hjust=1)
text(26+(1:3-.5)*5,77.5,conditions,hjust=1,angle=90)
text(79+(1:8-.5)*5,77.5,paths,hjust=1,angle=90)
text(rep(68.7,8),49-(1:8-.5)*5,interactions,hjust=1)
# Native vector facet header polygons are separate from scalar matrix geometry.
headers <- rbind(data.frame(x=c(70,80,80,70),y=c(49.8,49.8,54,54),id=1),data.frame(x=c(81,91,91,81),y=c(49.8,49.8,54,54),id=2))
p <- p+geom_polygon(data=headers,aes(x,y,group=id),fill='#FDFFF4',colour='#777777',linewidth=.15)
text(c(75,86),51.9,c('Ligand','Receptor'),7)
text(c(72.5,77.5,83.5,88.5),7,c('FB','MY','FB','MY'),6.5,hjust=1,angle=90)
# Native grid linearGradient objects form three smooth source-specific colorbars; no shared numeric scale.
pdf_bar_layers <- list()
bar <- function(x,y0,y1,lim,fun,ticks,label) {
 ramp<-grid::linearGradient(colours=fun(seq(-lim,lim,length.out=257)),stops=seq(0,1,length.out=257),x1=0,y1=0,x2=0,y2=1)
 grob<-grid::rectGrob(gp=grid::gpar(fill=ramp,col=NA))
 index<-length(p$layers)+1L
 p <<- p+annotation_custom(grob,xmin=x,xmax=x+2,ymin=y0,ymax=y1)
 # Base-R PDF/GS does not retain grid gradient patterns in this nested viewport.
 # Equivalent contiguous vector fills preserve exactly the same colors/axis in PDF.
 yy<-seq(y0,y1,length.out=257);vv<-seq(-lim,lim,length.out=256)
 z<-do.call(rbind,lapply(seq_len(256),function(i)data.frame(x=c(x,x+2,x+2,x),y=c(yy[i],yy[i],min(y1,yy[i+1]+.04),min(y1,yy[i+1]+.04)),id=i,col=fun(vv[i]))))
 pdf_bar_layers[[as.character(index)]] <<- geom_polygon(data=z,aes(x=x,y=y,group=id,fill=col),colour=NA)
 text(x+3.3,y0+(ticks+lim)/(2*lim)*(y1-y0),as.character(ticks),6.5,hjust=0)
 text(x+10.2,(y0+y1)/2,label,7,angle=270)
}
bar(47,79,104,4,colfun$c,c(-4,-2,0,2,4),'log2 odds ratio')
bar(124,79,104,5,colfun$d,c(-5,0,5),'Enrichment score')
bar(101,18,45,3.5,colfun$l,c(-3.5,0,3.5),'log2 fold change')
p <- p+scale_colour_identity()
inputs <- file.path(pd,c('fig5c-source.csv','fig5d-source.csv','fig5l-display.csv'))
sources <- c(specfile,file.path(root,'scripts/render.R'),file.path(skill,'scripts/figure_style.R'),inputs,
 file.path(root,'sources/1.Pre_x_NMF.selected-cells.py'),file.path(root,'sources/5.LRdea.selected-cells.py'),file.path(root,'sources/tileplot-paper-1.0.5.py'))
boxes <- data.frame(id=c('data','labels','legend'),x=c(26,3,46),y=c(9,3,18),w=c(93,117,90),h=c(95,109,89))
# Bounding unions overlap because labels/legends surround several separated data panels; exact text/panel bboxes are audited in PDF.
bf_render_png(p,file.path(out,'liana-fig5cdl.png'),font,unlist(spec$text_contract$allowed_text),W,H,W,sources,boxes,
 allowed_pairs=c('data:labels','data:legend','labels:legend'),dpi=300,min_text_pt=6.5,authorization=auth,skill_root=skill,publication_size_class='one-and-half-column')
p_pdf<-p;for(i in names(pdf_bar_layers))p_pdf$layers[[as.integer(i)]]<-pdf_bar_layers[[i]]
pdf<-file.path(out,'liana-fig5cdl.pdf');bf_pdf_open(pdf,W,H,font);print(p_pdf);dev.off();pdf_audit<-bf_pdf_finalize(pdf,font,W,H);jsonlite::write_json(pdf_audit,file.path(out,'pdf-audit.json'),auto_unbox=TRUE,pretty=TRUE)
jsonlite::write_json(list(status='NATIVE_R_SOURCE_TABLE_RENDERED',canvas_mm=c(W,H),cell_mm=5,
 c=list(rows=5,columns=3,stars=6,limits=c(-4,4),low=colors['c_low'],mid=colors['c_zero'],high=colors['c_high']),
 d=list(rows=5,columns=8,stars=18,limits=c(-5,5),low=colors['d_low'],mid=colors['d_zero'],high=colors['d_high']),
 l=list(rows=8,columns_per_facet=2,facets=c('Ligand','Receptor'),observed=31,missing=1,stars=20,limits=c(-3.5,3.5)),
 factors_top_to_bottom=factors,pathways_left_to_right=paths,lr_top_to_bottom=interactions,cell_types_left_to_right=c('FB','MY'),
 raw_analysis_rerun=FALSE,p_values_reestimated=FALSE),file.path(out,'render-metrics.json'),pretty=TRUE,auto_unbox=TRUE)
writeLines(capture.output(sessionInfo()),file.path(out,'session-info.txt'))
