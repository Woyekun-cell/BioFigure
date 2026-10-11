#!/usr/bin/env Rscript
# Self-authored synthetic gallery example; no patient data or biological inference.
# Rscript scripts/prepare_inputs.R /absolute/path/to/oncoprint
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==1)
root <- normalizePath(args[1],mustWork=TRUE)
set.seed(2026101108)
samples <- sprintf('SIM_T%03d',seq_len(144))
genes <- c('TP53','KRAS','KEAP1','STK11','EGFR','NF1','RBM10','BRAF','SETD2','MGA','PIK3CA','ARID1A')
types <- c('Missense','Frameshift','Nonsense','Splice','In_frame')
baseline <- c(.56,.39,.31,.27,.23,.19,.17,.15,.13,.11,.10,.08)
metadata <- data.frame(sample_id=samples,
  cohort=rep(c('A','B','C'),each=48),
  sex=sample(c('Female','Male','Unknown'),144,TRUE,c(.48,.48,.04)),
  smoking=sample(c('Ever','Never','Unknown'),144,TRUE,c(.57,.36,.07)),
  simulation=TRUE,stringsAsFactors=FALSE)
events <- list(); k <- 0L
for(i in seq_along(samples)) for(j in seq_along(genes)) {
  # Last nine synthetic tumours intentionally have zero events, yet are retained.
  if(i>135 || runif(1)>=baseline[j]) next
  ntypes <- if(runif(1)<.16)2L else 1L
  selected <- sample(types,ntypes,replace=FALSE,prob=c(.52,.19,.12,.12,.05))
  for(type in selected) {
    k <- k+1L
    events[[k]] <- data.frame(sample_id=samples[i],gene=genes[j],event_type=type,
      simulated=TRUE,stringsAsFactors=FALSE)
  }
}
events <- do.call(rbind,events)
stopifnot(!anyDuplicated(events[c('sample_id','gene','event_type')]))
matrix <- matrix('',length(genes),length(samples),dimnames=list(genes,samples))
for(i in seq_len(nrow(events))) {
  g <- events$gene[i]; s <- events$sample_id[i]
  matrix[g,s] <- paste(c(strsplit(matrix[g,s],';',fixed=TRUE)[[1]],events$event_type[i]),collapse=';')
}
matrix[] <- vapply(matrix,function(x)paste(types[types %in% strsplit(x,';',fixed=TRUE)[[1]]],collapse=';'),'')
binary <- matrix!=''
frequency <- data.frame(gene=genes,altered_tumours=rowSums(binary),assayed_tumours=144L,
  frequency_percent=rowSums(binary)/144*100,stringsAsFactors=FALSE)
row_ids <- order(-frequency$altered_tumours,frequency$gene)
gene_order <- genes[row_ids]
frequency <- frequency[row_ids,]
frequency$row_index <- seq_len(nrow(frequency))
matrix <- matrix[gene_order,,drop=FALSE]
binary <- matrix!=''
# Cohorts retain A/B/C. Within each cohort use a declared binary lexicographic
# order: gene-presence in descending-frequency row order, then sample ID.
column_ids <- unlist(lapply(c('A','B','C'),function(group) {
  ids <- which(metadata$cohort==group)
  sorting <- c(lapply(seq_len(nrow(binary)),function(j)-as.integer(binary[j,ids])),
    list(metadata$sample_id[ids],method='radix'))
  ids[do.call(order,sorting)]
}),use.names=FALSE)
sample_order <- samples[column_ids]
ordered_metadata <- metadata[match(sample_order,metadata$sample_id),]
ordered_metadata$column_index <- seq_len(nrow(ordered_metadata))
matrix <- matrix[,sample_order,drop=FALSE]
table <- data.frame(gene=rownames(matrix),matrix,check.names=FALSE)
write.csv(events,file.path(root,'data/raw/simulated_events.csv'),row.names=FALSE)
write.csv(metadata,file.path(root,'data/raw/simulated_sample_metadata.csv'),row.names=FALSE)
write.csv(table,file.path(root,'results/plot_data/oncoprint_simulated_matrix.csv'),row.names=FALSE,na='')
write.csv(ordered_metadata,file.path(root,'results/plot_data/oncoprint_simulated_sample_order.csv'),row.names=FALSE)
write.csv(frequency,file.path(root,'results/plot_data/oncoprint_simulated_gene_frequency.csv'),row.names=FALSE)
per_sample <- data.frame(sample_id=sample_order,
  altered_genes=colSums(matrix!=''),
  distinct_events=vapply(sample_order,function(s)sum(events$sample_id==s),0L))
write.csv(per_sample,file.path(root,'results/plot_data/oncoprint_simulated_sample_counts.csv'),row.names=FALSE)
qc <- list(status='INPUT_PREPARED_NOT_VISUAL_PASS',scope='Self-authored simulated 144-tumour x12-gene gallery example; not original-paper reproduction',
  seed=2026101108L,tumours=144L,genes=12L,all_cells=length(matrix),assayed_cells=length(matrix),
  event_classes=types,events=nrow(events),altered_cells=sum(matrix!=''),
  multi_event_cells=sum(grepl(';',matrix,fixed=TRUE)),empty_tumours=sum(colSums(matrix!='')==0),
  denominator='144 synthetic tumours; every gene is assayed, no missing assay values',
  gene_order=gene_order,sample_order=sample_order,
  sorting='Genes: distinct altered tumours descending, ties gene alphabetic. Samples: A/B/C then binary-presence lexicographic order by ranked genes, ties sample_id.',
  warning='Frequencies and metadata are simulated; no significance tests or clinical associations are inferred.')
jsonlite::write_json(qc,file.path(root,'evidence/input-qc.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
writeLines(capture.output(sessionInfo()),file.path(root,'data/metadata/preparation-sessionInfo.txt'))
cat('SIMULATED_INPUT_PREPARED:',nrow(events),'events;',sum(grepl(';',matrix,fixed=TRUE)),'multi-event cells;',sum(colSums(matrix!='')==0),'zero-event tumours retained\n')
