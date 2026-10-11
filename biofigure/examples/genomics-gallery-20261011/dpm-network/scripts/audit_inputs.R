#!/usr/bin/env Rscript
# New overlap graph from original full GMT and saved author enrichment results.
args <- commandArgs(trailingOnly=TRUE)
root <- normalizePath(args[1],mustWork=TRUE)
dir.create(file.path(root,'results','plot_data'),recursive=TRUE,showWarnings=FALSE)
dir.create(file.path(root,'results','tables'),recursive=TRUE,showWarnings=FALSE)
e <- new.env(parent=baseenv())
load(file.path(root,'data','raw','panelE_Rdata.Rdata'),envir=e)
b <- as.data.frame(e$res_brown); d <- as.data.frame(e$res_dpm)
ids <- sort(union(b$term_id,d$term_id))
lines <- strsplit(readLines(file.path(root,'data','raw','hsapiens.GO_BP_REACTOME.name.gmt')),'\t',fixed=TRUE)
sets <- setNames(lapply(lines,function(v)unique(v[-c(1,2)])),vapply(lines,`[`,character(1),1))
stopifnot(length(ids)==225,!anyDuplicated(names(sets)),all(ids%in%names(sets)))
nodes <- do.call(rbind,lapply(ids,function(id) {
  ib <- match(id,b$term_id); idp <- match(id,d$term_id)
  t <- if(!is.na(ib)) b[ib,,drop=FALSE] else d[idp,,drop=FALSE]
  evidence <- unlist(t$evidence)
  if(!is.na(ib)&&!is.na(idp))stopifnot(setequal(unlist(b$evidence[ib]),unlist(d$evidence[idp])))
  stopifnot(t$term_size==length(intersect(sets[[id]],e$ap_background)))
  data.frame(term_id=id,term_name=t$term_name,term_size=t$term_size,
    brown_FWER=if(!is.na(ib))b$adjusted_p_val[ib] else NA_real_,
    dpm_FWER=if(!is.na(idp))d$adjusted_p_val[idp] else NA_real_,
    directional_status=if(!is.na(ib)&&!is.na(idp))'Shared' else if(!is.na(ib))'Brown only' else 'DPM only',
    OE=as.integer('overexpression'%in%evidence),KD=as.integer('knockdown'%in%evidence),
    combined_only=as.integer('combined'%in%evidence),stringsAsFactors=FALSE)
}))
pair <- combn(ids,2)
intersection <- apply(pair,2,function(p)length(intersect(sets[[p[1]]],sets[[p[2]]])))
counts <- lengths(sets)
edges <- data.frame(from=pair[1,],to=pair[2,],intersection=intersection,
  n_from=unname(counts[pair[1,]]),n_to=unname(counts[pair[2,]]))
edges$overlap_coefficient <- edges$intersection/pmin(edges$n_from,edges$n_to)
edges <- edges[edges$overlap_coefficient>=0.5,,drop=FALSE]
g <- igraph::graph_from_data_frame(edges,directed=FALSE,vertices=nodes)
components <- igraph::components(g)
nodes$component <- unname(components$membership[nodes$term_id])
nodes$degree <- unname(igraph::degree(g)[nodes$term_id])
stopifnot(nrow(edges)==2183,components$no==25,sum(nodes$degree==0)==11,
  all(rowSums(nodes[,c('OE','KD','combined_only')])>0),
  sum(nodes$directional_status=='Shared')==132,
  sum(nodes$directional_status=='Brown only')==87,sum(nodes$directional_status=='DPM only')==6)
memberships <- do.call(rbind,lapply(ids,function(id)data.frame(term_id=id,gene=sets[[id]],
  in_author_background=sets[[id]]%in%e$ap_background)))
write_csv <- function(df,name) {
  for(n in names(df))if(is.double(df[[n]]))df[[n]] <- ifelse(is.na(df[[n]]),NA_character_,sprintf('%.17g',df[[n]]))
  write.csv(df,file.path(root,'results','plot_data',paste0('dpm_fig3e_recolored_',name,'.csv')),row.names=FALSE)
}
write_csv(nodes,'nodes');write_csv(edges,'edges');write_csv(memberships,'memberships')
jsonlite::write_json(list(scope='saved author results; NEW declared fullGMT overlap graph; no enrichment rerun',
  nodes=225,edges=2183,components=25,isolates=11,largest_component=max(components$csize),
  threshold=0.5,inclusive=TRUE,formula='|A intersection B|/min(|A|,|B|)',
  complete_GMT_memberships=nrow(memberships),status_counts=as.list(table(nodes$directional_status)),
  original_edges_coordinates_themes_and_size_mapping='NOT_VERIFIED',seed=3302024),
  file.path(root,'results','tables','input-QC.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
cat('INPUT_QC_PASS nodes225 edges2183 components25 isolates11 no new enrichment\n')
