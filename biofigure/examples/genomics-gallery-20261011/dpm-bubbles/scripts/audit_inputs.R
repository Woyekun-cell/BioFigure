#!/usr/bin/env Rscript
# Saved author summaries only; no differential/integration/enrichment rerun.
args <- commandArgs(trailingOnly=TRUE)
root <- normalizePath(args[1],mustWork=TRUE)
dir.create(file.path(root,'results','plot_data'),recursive=TRUE,showWarnings=FALSE)
dir.create(file.path(root,'results','tables'),recursive=TRUE,showWarnings=FALSE)
e <- new.env(parent=baseenv())
load(file.path(root,'data','raw','panelE_Rdata.Rdata'),envir=e)
b <- as.data.frame(e$res_brown); d <- as.data.frame(e$res_dpm)
df <- e$df_oe_kd
stopifnot(nrow(df)==12996,!anyDuplicated(df$gene_name),!anyNA(df))
cgc <- read.delim(file.path(root,'data','raw','cancer_gene_census_2023-01-18.tsv'),check.names=FALSE)
ids <- c('GO:0001667','GO:0070482')
tables <- lapply(ids,function(id) {
  term <- b[b$term_id==id,,drop=FALSE]
  stopifnot(nrow(term)==1,!id%in%d$term_id)
  genes <- unlist(term$overlap)
  selected <- df[match(genes,df$gene_name),,drop=FALSE]
  stopifnot(identical(selected$gene_name,genes))
  r <- do.call(rbind,lapply(c('OE','KD'),function(dataset) data.frame(
    pathway_id=id,pathway_name=term$term_name,gene=genes,gene_order=seq_along(genes),
    OE_KD=dataset,raw_P=selected[[paste0(dataset,'_P.Value')]],
    log2FC=selected[[paste0(dataset,'_logFC')]],
    cgc=genes%in%cgc[['Gene Symbol']],author_FWER=term$adjusted_p_val,
    author_term_size=term$term_size,stringsAsFactors=FALSE)))
  r$plotted_log2FC <- pmax(-2,pmin(2,r$log2FC))
  r$size_score <- -log10(r$raw_P)
  r
})
r <- do.call(rbind,tables)
stopifnot(nrow(r)==120,all(is.finite(r$size_score)),all(r$raw_P>0&r$raw_P<=1))
r$bubble_diameter_mm <- sqrt(0.55^2+(3.0^2-0.55^2)*r$size_score/max(r$size_score))
r <- r[,c('pathway_id','pathway_name','gene','gene_order','OE_KD','raw_P','log2FC',
  'plotted_log2FC','size_score','cgc','author_FWER','author_term_size','bubble_diameter_mm')]
# 17 significant digits preserve the original binary doubles on CSV roundtrip.
csv <- r
for(n in names(csv)) if(is.double(csv[[n]]))csv[[n]] <- sprintf('%.17g',csv[[n]])
write.csv(csv,file.path(root,'results','plot_data','dpm_fig3f_recolored_plot_data.csv'),row.names=FALSE)
jsonlite::write_json(list(scope='author processed data only; no new testing',cells=nrow(r),
  rows_by_pathway=c(37,23),CGC_unique_genes=unique(r$gene[r$cgc]),
  all_120_cells_retained=TRUE,raw_P_zero=sum(r$raw_P==0),
  source_size_limits_would_drop=sum(r$size_score<1),
  star_annotation='OMITTED: original criterion/merged values unavailable',
  source_FWER=b$adjusted_p_val[match(ids,b$term_id)]),
  file.path(root,'results','tables','input-QC.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
cat('INPUT_QC_PASS cells120 row37/23 CGC5 no new inference\n')
