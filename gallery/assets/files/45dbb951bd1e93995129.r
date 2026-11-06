# Native Numbat1.1.0 supplied processed ATC2 objects; no inference refit.
suppressPackageStartupMessages({library(dplyr);library(tidyr);library(ggplot2);library(ggraph);library(tidygraph);library(igraph);library(patchwork);library(stringr);library(purrr);library(data.table);library(ape)})
make_numbat_native<-function(C) {
 source(file.path(C,'sources/author/scistreer/R/scistreer.R'),local=environment())
 source(file.path(C,'sources/author/trees.R'),local=environment())
 source(file.path(C,'sources/author/utils.R'),local=environment())
 source(file.path(C,'sources/author/vis.R'),local=environment())
 for(n in c('joint_post_example','segs_example','bulk_example','phylogeny_example','mut_graph_example'))load(file.path(C,'data/raw',paste0(n,'.rda')),envir=environment())
 gtree<-upgrade_graph(phylogeny_example);class(gtree)<-c('tbl_graph','igraph');G<-upgrade_graph(mut_graph_example)
 leaf<-as_tibble(activate(gtree,nodes))%>%filter(leaf)
 stopifnot(nrow(leaf)==173,nrow(joint_post_example)==3806,nrow(bulk_example)==3935,nrow(segs_example)==27,all(leaf$name%in%joint_post_example$cell),n_distinct(joint_post_example$cell)==173,n_distinct(joint_post_example$CHROM)==22)
 clone_pal<-c('1'='#AEB8BD','2'='#D4A67E','3'='#B67E7F','4'='#895E7B','5'='#574166')
 common<-theme(text=element_text(family='Arial',size=7),legend.title=element_text(size=7),legend.text=element_text(size=6.5),strip.text=element_text(size=7),plot.margin=margin(1,1,1,1,'mm'))
 top<-plot_phylo_heatmap(gtree,joint_post_example,segs_example,clone_bar=TRUE,pal_clone=clone_pal,line_width=.30,branch_width=.10,tree_height=1.6,clone_bar_width=.35,bar_label_size=6.5)
 # Author1..N x limits remove the edge tiles in ggplot2 4.x. Preserve all173 cells
 # and align row centers between native phylogeny,genotype and genomic intervals.
 top[[1]]<-top[[1]]+scale_y_continuous(limits=c(.5,173.5),expand=expansion(0))
 top[[2]]<-top[[2]]+scale_x_continuous(limits=c(.5,173.5),expand=expansion(0))
 top[[3]]<-top[[3]]+scale_y_continuous(limits=c(.5,173.5),expand=expansion(0))+scale_color_manual(values=c(del='#3E6D88'),breaks='del',labels='Deletion',na.translate=FALSE)+theme(legend.key.height=unit(3,'mm'),legend.key.width=unit(4,'mm'),axis.title.x=element_text(size=7))
 top<-top & common & theme(legend.position='right',plot.margin=margin(1,3,1,1,'mm'))
 clones<-plot_mut_history(G,pal=clone_pal,show_distance=FALSE,horizontal=FALSE,edge_label_size=2.3,node_label_size=2.9,node_size=4.7,arrow_size=.7)
 clones$layers[[1]]$mapping$label<-aes(label=ifelse(nchar(to_label)>22,paste0(lengths(strsplit(to_label,',')),' CNVs'),gsub(',',', ',to_label)))$label
 clones<-clones+common+theme(plot.margin=margin(1,2,1,2,'mm'))
 bulk<-plot_psbulk(bulk_example,exclude_gap=FALSE,text_size=7,dot_size=.42,dot_alpha=.55)
 states<-sort(unique(bulk$data$state_post));cp<-setNames(rep('#BDC4C9',length(cnv_colors)),names(cnv_colors));cp[grepl('up',names(cp))]<-'#6EAAB3';cp[grepl('down',names(cp))]<-'#355E7A';cp['neu']<-'#C8CED2'
 bulk<-bulk+scale_color_manual(values=cp,breaks=states,labels=gsub('DEL1','DEL',cnv_labels[states]),na.translate=FALSE)+scale_x_continuous(breaks=c(0,50,100,150)*1e6,labels=c('0','50','100','150'),expand=expansion(mult=.01))+labs(x='Chromosome 5 position (Mb)')+common+theme(axis.text.x=element_text(size=6.5),axis.text.y=element_text(size=6.5),axis.title.x=element_text(size=7),axis.ticks.x=element_line(linewidth=.2),legend.key.height=unit(3,'mm'),legend.key.width=unit(3,'mm'),plot.margin=margin(2,1,1,3,'mm'),legend.position='bottom',legend.direction='horizontal',legend.box.margin=margin(0,0,0,0),legend.spacing.x=unit(1,'mm'),legend.margin=margin(0,0,0,0))+guides(color=guide_legend(title=NULL,nrow=1,override.aes=list(size=1.6)))
 for(i in seq_along(bulk$layers))if(inherits(bulk$layers[[i]]$geom,'GeomSegment')&&identical(bulk$layers[[i]]$aes_params$colour,'darkred'))bulk$layers[[i]]$aes_params$colour<-'#8C5473'
 list(top=top,clones=clones,bulk=bulk,cell_tree=gtree,clone_graph=G,leaf=leaf,joint=joint_post_example,segs=segs_example,pseudobulk=bulk_example)
}
collect_grob_text<-function(g,inherited=grid::gpar()) {
 gp<-inherited;for(k in names(g$gp))gp[[k]]<-g$gp[[k]]
 out<-list(labels=character(),families=character(),sizes=numeric())
 if(inherits(g,'text')&&length(g$label))out<-list(labels=as.character(g$label),families=gp$fontfamily,sizes=gp$fontsize)
 for(child in c(g$grobs,as.list(g$children))){x<-collect_grob_text(child,gp);for(k in names(out))out[[k]]<-c(out[[k]],x[[k]])};out
}
# Resolve all native text grobs to the same verified font; keep native sizes/faces.
font_grob<-function(g){if(is.null(g$gp))g$gp<-grid::gpar();g$gp$fontfamily<-'Arial';if(length(g$grobs))g$grobs<-lapply(g$grobs,font_grob);if(length(g$children))g$children<-do.call(grid::gList,lapply(as.list(g$children),font_grob));g}
make_native_grobs<-function(p)lapply(list(patchwork::patchworkGrob(p$top),ggplotGrob(p$clones),ggplotGrob(p$bulk)),font_grob)
draw_native<-function(gs){
 grid::grid.newpage();titles<-c('a  ATC2 copy-number landscape','b  Clonal mutation history','c  Chromosome 5 pseudobulk')
 for(i in 1:3)grid::grid.text(titles[i],x=unit(c(3,3,71)[i],'mm'),y=unit(c(143,68,68)[i],'mm'),just=c('left','top'),gp=grid::gpar(fontfamily='Arial',fontsize=8,fontface='bold',col='#27353E'))
 boxes<-data.frame(id=c('a','b','c'),x=c(1,2,70),y=c(73,5,5),w=c(181,64,111),h=c(66,57,57));metrics<-list()
 for(i in 1:3){b<-boxes[i,];grid::pushViewport(grid::viewport(name=paste0('native-',b$id),x=unit(b$x,'mm'),y=unit(b$y,'mm'),width=unit(b$w,'mm'),height=unit(b$h,'mm'),just=c('left','bottom')));grid::grid.draw(gs[[i]]);grid::grid.force();lo<-grid::deviceLoc(unit(0,'npc'),unit(0,'npc'),valueOnly=TRUE);hi<-grid::deviceLoc(unit(1,'npc'),unit(1,'npc'),valueOnly=TRUE);metrics[[i]]<-list(id=b$id,x=lo$x*25.4,y=lo$y*25.4,w=(hi$x-lo$x)*25.4,h=(hi$y-lo$y)*25.4);grid::popViewport()}
 texts<-lapply(gs,collect_grob_text);list(boxes=metrics,text=unique(c(titles,unlist(lapply(texts,`[[`,'labels')))),families=unique(unlist(lapply(texts,`[[`,'families'))),sizes=unique(c(8,unlist(lapply(texts,`[[`,'sizes')))))
}
