# Explicit simulated matched-feature data. No inference or raw-omics processing.
args <- commandArgs(TRUE)
root <- normalizePath(args[1], mustWork=TRUE)
set.seed(20261011)
n <- 1800L
states <- c("Low", "Neutral", "High")
dna <- sample(states, n, replace=TRUE, prob=c(.28,.45,.27))
rna_prob <- rbind(Low=c(.58,.29,.13), Neutral=c(.19,.62,.19), High=c(.12,.30,.58))
protein_prob <- rbind(Low=c(.64,.26,.10), Neutral=c(.18,.65,.17), High=c(.11,.28,.61))
rna <- vapply(dna, function(s)sample(states,1,prob=rna_prob[s,]), "")
protein <- vapply(rna, function(s)sample(states,1,prob=protein_prob[s,]), "")
features <- data.frame(feature_id=sprintf("sim_feature_%04d",seq_len(n)),
  DNA_copy_number=dna,RNA_expression=rna,Protein_abundance=protein,
  stringsAsFactors=FALSE)
write.csv(features,file.path(root,"data/raw/sankey_features.csv"),row.names=FALSE)
paths <- as.data.frame(table(factor(dna,levels=states),factor(rna,levels=states),
  factor(protein,levels=states)),stringsAsFactors=FALSE)
names(paths) <- c("DNA_copy_number","RNA_expression","Protein_abundance","n_features")
paths$path_id <- sprintf("path_%02d",seq_len(nrow(paths)))
paths <- paths[,c("path_id","DNA_copy_number","RNA_expression","Protein_abundance","n_features")]
stopifnot(sum(paths$n_features)==n, nrow(paths)==27L,all(paths$n_features>0))
write.csv(paths,file.path(root,"results/plot_data/sankey_paths.csv"),row.names=FALSE)
nodes <- do.call(rbind,lapply(c("DNA_copy_number","RNA_expression","Protein_abundance"), function(stage){
  counts <- table(factor(features[[stage]],levels=states))
  data.frame(stage=stage,state=states,n_features=as.integer(counts),percent=100*as.integer(counts)/n)
}))
write.csv(nodes,file.path(root,"results/plot_data/sankey_nodes.csv"),row.names=FALSE)
qc <- list(status="PASS",source="SIMULATED",seed=20261011,feature_count=n,paths=nrow(paths),
  stage_count=3,duplicate_ids=sum(duplicated(features$feature_id)),missing=sum(is.na(features)),
  all_stage_totals=tapply(nodes$n_features,nodes$stage,sum),statistical_inference="NONE",
  rna_conditional_probabilities=rna_prob,protein_conditional_probabilities=protein_prob,
  boundary="Artificial matched-feature states; arbitrary conditional probabilities demonstrate layout, not biological associations, patient counts, pathway activity or causality.")
jsonlite::write_json(qc,file.path(root,"results/tables/data-QC.json"),pretty=TRUE,auto_unbox=TRUE)
writeLines(capture.output(sessionInfo()),file.path(root,"data/metadata/R-sessionInfo.txt"))
cat("PASS: 1800 distinct simulated features,27 paths,3 stage totals conserved\n")
