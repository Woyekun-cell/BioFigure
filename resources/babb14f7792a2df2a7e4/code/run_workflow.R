# Usage: Rscript run_workflow.R OTU_COUNTS.csv SAMPLE_GROUPS.csv NEW_OUTPUT [OTU_TAXONOMY.csv]
args <- commandArgs(trailingOnly=TRUE)
if (!length(args) %in% 3:4)
  stop("Usage: Rscript run_workflow.R OTU_COUNTS.csv SAMPLE_GROUPS.csv NEW_OUTPUT [OTU_TAXONOMY.csv]")
script_arg <- grep("^--file=",commandArgs(),value=TRUE)
scripts <- dirname(normalizePath(sub("^--file=","",script_arg)))
source(file.path(scripts,"network_methods.R"))
source(file.path(scripts,"draw_figure.R"))

counts_csv <- read.csv(args[1],check.names=FALSE)
samples <- read.csv(args[2],check.names=FALSE,colClasses="character")
stopifnot("otu" %in% names(counts_csv), all(c("sample","group") %in% names(samples)),
          !anyNA(counts_csv$otu),!anyDuplicated(counts_csv$otu),!anyDuplicated(names(counts_csv)),
          !anyNA(samples[c("sample","group")]),!anyDuplicated(samples$sample),
          setequal(samples$sample,setdiff(names(counts_csv),"otu")),all(nzchar(samples$group)))
counts <- as.matrix(counts_csv[samples$sample])
rownames(counts) <- counts_csv$otu
groups <- unique(samples$group)
stopifnot(length(groups) %in% 1:2)
taxonomy <- if (length(args)==4L) read.csv(args[4],colClasses="character") else data.frame(otu=character(),phylum=character())
stopifnot(all(c("otu","phylum") %in% names(taxonomy)),!anyNA(taxonomy[c("otu","phylum")]),
          !anyDuplicated(taxonomy$otu),all(nzchar(taxonomy$phylum)))
out <- args[3]
if (file.exists(out) || !dir.exists(dirname(out))) stop("Choose a new output directory under an existing parent")
staging <- tempfile(".network-",tmpdir=dirname(out))
stopifnot(dir.create(staging))
tryCatch({
  set.seed(20261117)
  result <- lapply(groups,function(group) {
    x <- build_cooccurrence(counts[,samples$group==group,drop=FALSE],p_adjust="BH")
    coords <- network_layout(x$graph,abs(x$edges$rho))
    phyla <- taxonomy$phylum[match(x$nodes$otu,taxonomy$otu)]
    phyla[is.na(phyla)] <- "Unclassified fungi"
    nodes <- data.frame(habitat=group,node=x$nodes$otu,degree=x$nodes$degree,module=x$nodes$module,
                        phylum=phyla,x=coords[,1],y=coords[,2])
    edges <- cbind(habitat=group,x$edges)
    id <- match(group,groups)
    g <- igraph::graph_from_data_frame(x$edges,directed=FALSE,vertices=nodes[c("node","degree","module","phylum","x","y")])
    igraph::write_graph(g,file.path(staging,sprintf("group-%d.graphml",id)),format="graphml")
    list(nodes=nodes,edges=edges)
  })
  merge_table <- function(name) do.call(rbind,lapply(result,`[[`,name))
  nodes <- merge_table("nodes")
  edges <- merge_table("edges")
  p <- build_network_figure(nodes,edges,subtitle="Spearman edges",group_order=groups)
  for (name in c("nodes","edges")) write.csv(get(name),file.path(staging,paste0(name,".csv")),row.names=FALSE)
  ragg::agg_png(file.path(staging,"cooccurrence-network.png"),183,83,units="mm",res=300)
  tryCatch(print(p),finally=invisible(grDevices::dev.off()))
  pdf <- file.path(staging,"cooccurrence-network.pdf")
  previous <- grDevices::dev.cur()
  if (capabilities("aqua")) grDevices::quartz(type="pdf",file=pdf,width=183/25.4,height=83/25.4,family="Arial") else
    grDevices::cairo_pdf(pdf,width=183/25.4,height=83/25.4,family="Arial")
  if (grDevices::dev.cur()==previous) stop("Unable to open the PDF graphics device")
  tryCatch(print(p),finally=invisible(grDevices::dev.off()))
  stopifnot(file.exists(pdf),file.info(pdf)$size>0,!file.exists(out),file.rename(staging,out))
},finally=if (dir.exists(staging)) unlink(staging,recursive=TRUE))
