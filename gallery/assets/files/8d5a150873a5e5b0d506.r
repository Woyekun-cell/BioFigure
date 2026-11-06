#!/usr/bin/env Rscript
# Extract immutable packaged Ensembl105 annotations and native ggtranscript transformations.
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==2L)
root <- normalizePath(args[1]); lib <- normalizePath(args[2]); .libPaths(c(lib,.libPaths()))
suppressPackageStartupMessages({library(ggtranscript);library(dplyr)})
options(warn=2)
out <- file.path(root,"results/plot_data"); dir.create(out,recursive=TRUE,showWarnings=FALSE)
metrics <- list()
for(gene in c("sod1","pknox1")){
 env <- new.env();load(file.path(root,"data/raw",paste0(gene,"_annotation.rda")),envir=env)
 annot <- get(paste0(gene,"_annotation"),env)
 exons <- filter(annot,type=="exon") |> arrange(transcript_name,start,end)
 introns <- to_intron(exons,"transcript_name") |> arrange(transcript_name,start,end)
 rescaled <- shorten_gaps(exons,introns,"transcript_name",target_gap_width=100L)
 exscaled <- filter(rescaled,type=="exon") |> arrange(transcript_name,start,end)
 stopifnot(nrow(exons)==nrow(exscaled),identical(exons$transcript_name,exscaled$transcript_name),isTRUE(all.equal(as.numeric(exons$end-exons$start),as.numeric(exscaled$end-exscaled$start))))
 stopifnot(nrow(introns)==nrow(exons)-n_distinct(exons$transcript_name),all(exons$strand=="+"),all(exons$seqnames=="21"),all(exons$end>=exons$start))
 # Plotting introns are joined at exon endpoints, rather than GTF actual intron intervals.
 for(tx in unique(exons$transcript_name)){e<-filter(exons,transcript_name==tx);i<-filter(introns,transcript_name==tx);stopifnot(identical(as.numeric(i$start),as.numeric(head(e$end,-1))),identical(as.numeric(i$end),as.numeric(tail(e$start,-1))))}
 # Common exonic bases preserve their alignment after common-gap compression.
 pairs<-merge(exons,exscaled,by=c("transcript_name","type","seqnames","strand","gene_name","transcript_biotype"),suffixes=c("_original","_scaled"))
 # Each exon matched by within-transcript genomic rank, retaining all original coordinates.
 mapping<-data.frame(transcript_name=exons$transcript_name,exon_index=ave(exons$start,exons$transcript_name,FUN=seq_along),original_start=exons$start,original_end=exons$end,scaled_start=exscaled$start,scaled_end=exscaled$end)
 ref<-paste0(toupper(gene),"-201")
 diffs<-to_diff(filter(exscaled,transcript_name!=ref),filter(exscaled,transcript_name==ref),"transcript_name")
 diff_orig<-to_diff(filter(exons,transcript_name!=ref),filter(exons,transcript_name==ref),"transcript_name")
 # Genomic differences must retain total base counts by transcript/type on the rescaled axis.
 bases<-function(d) aggregate(width~transcript_name+diff_type,d,sum)
 stopifnot(isTRUE(all.equal(bases(diffs),bases(diff_orig),check.attributes=FALSE)))
 tabs<-list(annotation=annot,exons=exons,introns=introns,compressed=rescaled,mapping=mapping,differences=diffs,differences_genomic=diff_orig)
 for(n in names(tabs))write.csv(tabs[[n]],file.path(out,paste0(gene,"_",n,".csv")),row.names=FALSE,na="")
 metrics[[gene]]<-list(annotation_rows=nrow(annot),transcripts=n_distinct(exons$transcript_name),exons=nrow(exons),introns=nrow(introns),differences=nrow(diffs),original_range=range(c(exons$start,exons$end)),compressed_range=range(c(exscaled$start,exscaled$end)),all_exon_lengths_preserved=TRUE,difference_base_counts_preserved=TRUE,source_strand="+",seqnames="21",biotypes=as.list(table(exons$transcript_biotype)),reference_transcript=ref)
}
fails<-list()
e<-read.csv(file.path(out,"sod1_exons.csv"),stringsAsFactors=FALSE)
i<-to_intron(e,"transcript_name")
bad<-e;bad$strand<-NULL
fails$missing_strand<-tryCatch({shorten_gaps(bad,i,"transcript_name");"UNEXPECTED_ACCEPT"},error=function(e)conditionMessage(e))
bad<-e;bad$seqnames<-as.character(bad$seqnames);bad$seqnames[1]<-"22"
fails$mixed_chromosome<-tryCatch({shorten_gaps(bad,i,"transcript_name");"UNEXPECTED_ACCEPT"},error=function(e)conditionMessage(e))
bad<-e;bad$strand[1]<-"-"
fails$mixed_strand<-tryCatch({shorten_gaps(bad,i,"transcript_name");"UNEXPECTED_ACCEPT"},error=function(e)conditionMessage(e))
stopifnot(!any(unlist(fails)=="UNEXPECTED_ACCEPT"))
jsonlite::write_json(list(schema_version=1,source="packaged Ensembl105 GRCh38/hg38 annotations",source_unchanged=TRUE,sampling=FALSE,seed=NULL,statistics="none; deterministic annotation interval operations",target_gap_width=100,metrics=metrics,negative_input_probes=fails,scope="fixed packaged examples plus SOD1 gap-shortening transfer; not arbitrary-input certification"),file.path(root,"data/metadata/data-qc.json"),auto_unbox=TRUE,pretty=TRUE)
capture.output(sessionInfo(),file=file.path(root,"data/metadata/preparation-session.txt"))
cat("NATIVE_DATA_QC_PASS\n")

