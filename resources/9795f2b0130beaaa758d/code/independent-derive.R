args<-commandArgs(TRUE);P<-normalizePath(args[1]);W<-file.path(P,'work/2026-10-28-batch-six/fleck/independent');I<-file.path(P,'work/2026-10-28-batch-six/intake');C<-file.path(P,'work/2026-10-28-batch-six/fleck/independent')
suppressPackageStartupMessages({library(igraph);library(dplyr);library(tidygraph);library(ggraph);library(grid)})
m<-read.delim(file.path(I,'fleck-grn_modules.tsv'),check.names=FALSE);stopifnot(nrow(m)==74448,!anyDuplicated(m[c('tf','target')]),all(is.finite(m$estimate)),!anyNA(m$log_padj),all(m$log_padj>=0))
d<-as.data.frame(readxl::read_excel(file.path(I,'fleck-supplements/41586_2022_5279_MOESM11_ESM.xls')));d<-d[d$group=='telen',];stopifnot(!anyDuplicated(d$feature))
bio<-jsonlite::fromJSON(file.path(I,'fleck-ensembl-biotypes.json'),simplifyVector=FALSE);coding<-names(Filter(function(x)x$biotype=='protein_coding',bio));coding<-coding[!grepl('^MT-|^RP|^HIST',coding)]
# Historical author goodlist is unavailable. Current Ensembl coding status audits
# all113 candidate nodes before rendering; only MALAT1 is excluded. Not a claim
# that an unsaved historical goodlist is byte-identical.
d<-d[d$avg_exp>0 & d$padj<1e-4 & abs(d$fc)>.1,];deg<-d$feature;direction<-setNames(-sign(d$fc),d$feature)
g<-graph_from_data_frame(m[c('tf','target')],directed=TRUE);E(g)$estimate<-m$estimate;E(g)$log_padj<-m$log_padj
paths<-all_shortest_paths(g,'GLI3',intersect(deg,V(g)$name),mode='out')$res
pt<-lapply(paths,function(v){n<-as_ids(v);ep<-get_edge_ids(g,as.vector(rbind(head(n,-1),tail(n,-1))),directed=TRUE);data.frame(path=paste(n,collapse=';'),end=tail(n,1),dir=prod(sign(E(g)$estimate[ep])),order=length(n)-1,mean_padj=mean(E(g)$log_padj[ep]),all_early=all(n%in%deg),stringsAsFactors=FALSE)})
pt<-do.call(rbind,pt);a<-pt[pt$order<=3 & pt$all_early & pt$end%in%deg,];a<-a[direction[a$end]==a$dir,];o1<-a[a$order==1,];o2<-a[a$order==2 & vapply(strsplit(a$path,';',fixed=TRUE),function(x)length(x)>=2&&paste(x[1:2],collapse=';')%in%o1$path,logical(1)),];z<-bind_rows(o1,o2)%>%group_by(end)%>%filter(mean_padj==max(mean_padj))%>%ungroup()
# For the retained depth<=2 author pruning every intermediary is an accepted
# early first-order target, so the early list suffices for combined-DE path check.
stopifnot(all(vapply(strsplit(z$path,';',fixed=TRUE),function(x)all(x%in%deg),logical(1))))
z<-z[vapply(strsplit(z$path,';',fixed=TRUE),function(x)all(x%in%coding),logical(1)),]
pedges<-bind_rows(lapply(seq_len(nrow(z)),function(i){n<-strsplit(z$path[i],';',fixed=TRUE)[[1]];data.frame(tf=head(n,-1),target=tail(n,-1),end_node=z$end[i],comb_dir=z$dir[i])}))%>%distinct()
e<-inner_join(m,pedges,by=c('tf','target'),relationship='many-to-many')%>%arrange(comb_dir);n<-unique(c(e$tf,e$target));
# Annotation-only transcription of the 27 labelled TFs in source Fig4f.
labels<-c('GLI3','HES4','HES5','CREB5','DMRTA1','OTX2','PAX6','JARID2','MAF','PBX1','SIX6','SOX11','EMX2','TOX','ZIC2','SIX3','SMAD3','SOX4','SALL4','DACH1','RAX','SOX6','ZNF521','ZIC3','ZNF608','CUX1','HES1');stopifnot(all(labels%in%n));
nodes<-data.frame(name=n,is_tf=n%in%labels,root=n=='GLI3',fc=d$fc[match(n,d$feature)],padj=d$padj[match(n,d$feature)])
# Keep original table edge ordering and ggraph native circular tree; source
# manuscript label repulsion is unsaved and is adapted for current physical size.
tg<-tbl_graph(nodes=nodes,edges=data.frame(from=match(e$tf,n),to=match(e$target,n),estimate=e$estimate,log_padj=e$log_padj),directed=TRUE)
layout<-create_layout(tg,layout='tree',circular=TRUE);layout$depth<-as.numeric(distances(as.igraph(tg),v='GLI3',to=layout$name,mode='out'));stopifnot(nrow(layout)==length(n));
write.csv(nodes,file.path(C,'results/plot_data/fleck_gli3_nodes.csv'),row.names=FALSE);write.csv(e,file.path(C,'results/plot_data/fleck_gli3_edges.csv'),row.names=FALSE);write.csv(z,file.path(C,'results/plot_data/fleck_gli3_paths.csv'),row.names=FALSE);write.csv(as.data.frame(layout)[,c('name','x','y','depth','is_tf','root')],file.path(C,'results/plot_data/fleck_gli3_layout.csv'),row.names=FALSE)
q<-list(status='COMPUTED_NOT_RENDERED',source_modules=nrow(m),early_source_features=2848,early_DE=nrow(d),candidate_nodes=length(bio),excluded_candidate='MALAT1: current Ensembl lncRNA, source coding-gene rule',nodes=nrow(nodes),edges=nrow(e),labelled_TFs=length(labels),first_order_targets=length(unique(e$target[e$tf=='GLI3'])),unique_edges=nrow(unique(e[c('tf','target')])),parallel_path_edges=nrow(e),second_order_paths=sum(z$order==2),direction_agreement=all(direction[z$end]==z$dir),all_retained_nodes_current_Ensembl_protein_coding=all(n%in%coding),path_mean_logpadj_ties_retained=TRUE,labels=labels,scope='Exact public GRN and early sourceTable9 author-rule path pruning; historical local coding/TF lists unavailable. Current Ensembl biotypes and transcribed published TF annotations declared. Native ggraph layout version differs; no original node coordinate claim.')
jsonlite::write_json(q,file.path(W,'plot-qc.json'),auto_unbox=TRUE,pretty=TRUE);saveRDS(list(tg=tg,layout=layout,q=q),file.path(W,'computed.rds'));cat('DERIVED',nrow(nodes),nrow(e),'\n')
