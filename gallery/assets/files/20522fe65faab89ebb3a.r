suppressPackageStartupMessages({library(ggplot2);library(igraph);library(scatterpie);library(ggrepel)})
base <- 'work/2026-10-29-bulk-omics-reproduction/motrpac'
out <- 'results/plot_data/motrpac_fig4c_pathway_network_20261029'
e <- new.env();load(file.path(base,'GRAPH_PW_ENRICH.rda'),e)
x <- e$GRAPH_PW_ENRICH
x <- x[x$tissue %in% c('HEART','SKM-GN','SKM-VL') & x$graphical_cluster=='8w_F1_M1' & !is.na(x$adj_p_value) & x$adj_p_value<.1,]
terms <- split(x,x$term_id)
terms <- Filter(function(z) length(unique(z$tissue))>=2,terms)
node <- do.call(rbind,lapply(terms,function(z){
  ss <- unique(z$tissue); ids <- unique(unlist(strsplit(paste(z$intersection[!is.na(z$intersection)],collapse=','),','),use.names=FALSE));ids<-ids[nzchar(ids)&ids!='NA']
  data.frame(id=z$term_id[1],name=z$term_name[1],HEART=as.integer('HEART'%in%ss),`SKM-GN`=as.integer('SKM-GN'%in%ss),`SKM-VL`=as.integer('SKM-VL'%in%ss),datasets=nrow(z),genes=paste(ids,collapse=','),check.names=FALSE)
}))
sets <- lapply(node$genes,function(z) unique(strsplit(z,',',fixed=TRUE)[[1]]));names(sets)<-node$id
pairs <- t(combn(node$id,2)); edge <- data.frame(from=character(),to=character(),similarity=numeric())
for(i in seq_len(nrow(pairs))){a<-sets[[pairs[i,1]]];b<-sets[[pairs[i,2]]];shared<-length(intersect(a,b));if(!shared)next;score<-(shared/length(union(a,b))+shared/min(length(a),length(b)))/2;if(score>=.3)edge<-rbind(edge,data.frame(from=pairs[i,1],to=pairs[i,2],similarity=score))}
g <- graph_from_data_frame(edge,directed=FALSE,vertices=node)
set.seed(123); xy <- layout_with_fr(g,weights=E(g)$similarity,niter=2000)
xy <- scale(xy);node$x<-xy[,1];node$y<-xy[,2];node$r<-0.055+0.017*sqrt(node$datasets)
edge$x<-node$x[match(edge$from,node$id)];edge$y<-node$y[match(edge$from,node$id)];edge$xend<-node$x[match(edge$to,node$id)];edge$yend<-node$y[match(edge$to,node$id)]
write.csv(node,paste0(out,'_nodes.csv'),row.names=FALSE);write.csv(edge,paste0(out,'_edges.csv'),row.names=FALSE)
labels <- c('Carbon metabolism','Amino acid synthesis and metabolism','Oxidative phosphorylation','Fatty acid metabolism','Mitochondrial translation','Cellular response to heat stress')
lab <- node[match(labels,node$name),];lab<-lab[!is.na(lab$id),]
p <- ggplot()+geom_segment(data=edge,aes(x=x,y=y,xend=xend,yend=yend,linewidth=similarity),color='#A4A9AE',alpha=.65)+scale_linewidth(range=c(.25,.8),guide='none')+geom_scatterpie(data=node,aes(x=x,y=y,r=r),cols=c('HEART','SKM-GN','SKM-VL'),color='#313B44',linewidth=.25)+scale_fill_manual(values=c(HEART='#E89A47',`SKM-GN`='#47A698',`SKM-VL`='#1D706B'),name='Tissue')+geom_label_repel(data=lab,aes(x=x,y=y,label=name),size=3.5,fontface='bold',fill='white',label.size=NA,box.padding=.7,max.overlaps=Inf,seed=123)+coord_equal(clip='off')+labs(title='Pathways shared across trained muscle tissues',subtitle='8-week female-and-male upregulated cluster · enriched in ≥2 tissues',caption='Node area: number of significant tissue × assay results  |  Edges: enrichment similarity ≥ 0.30')+theme_void(base_family='sans',base_size=10)+theme(plot.title=element_text(face='bold',size=14),plot.subtitle=element_text(color='#59636D'),plot.caption=element_text(color='#59636D'),legend.position='bottom',plot.margin=margin(12,25,10,25))
ggsave('results/figures/motrpac_fig4c_pathway_network_20261029.pdf',p,width=180,height=160,units='mm',device="pdf")
ggsave('results/figures/motrpac_fig4c_pathway_network_20261029.png',p,width=180,height=160,units='mm',dpi=300,bg='white')
cat('nodes',nrow(node),'edges',nrow(edge),'\n')
