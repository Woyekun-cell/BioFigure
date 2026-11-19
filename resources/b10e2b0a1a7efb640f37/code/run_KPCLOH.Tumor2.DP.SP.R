library(futile.logger)

library(SCclust)

flog.threshold(DEBUG)



base_dir <- file.path("/data")
work_dir <- file.path("/wd/work")

source_data <- file.path(base_dir, "KPCLOH.Tumor2.DP.SP")

#############################################
#############################################
keepboundaries <- T
result_dir <- file.path(
    work_dir, "KPCLOH.Tumor2.DP.SP.results")
#############################################
#############################################

# load gc
gc_filename <- file.path(
    base_dir, "mm9.varbin.gc.content.5k.bowtie.k50.from.uber.txt.gz")

gc_df <-load_table(gc_filename)
gc_df$chrom.numeric <- chrom_numeric(gc_df$bin.chrom)
flog.debug("gc columns: %s", colnames(gc_df))


uber_seg <- file.path(
    source_data, "KPCLOH.Tumor2.DP.SP.5k.seg.quantal.primary.txt.gz")

uber_seg <- load_table(uber_seg)

cells <- uber_cells(uber_seg, skip=3)$cells
flog.debug("cells: %s", length(cells))

pins <- calc_pinmat(gc_df, uber_seg, keepboundaries=keepboundaries)
pinmat_df <- pins$pinmat
pins_df <- pins$pins

flog.debug("pinmat: %s", nrow(pinmat_df))
flog.debug("pins: %s", nrow(pins_df))

flog.debug("pinmat calc cells: %s", length(uber_cells(pinmat_df, skip=0)$cells))

nsim <- 150
flog.debug("nsim=%s",nsim)

flog.debug("starting sim fisher calculation...")
fisher <- sim_fisher_wrapper(
    pinmat_df, pins_df, njobs=30, nsim=nsim, nsweep=10)
true_pv <- fisher$true
sim_pv <- fisher$sim
flog.debug("sim fisher calculation DONE...")

lmmax = 0.001

mfdr <- fisher_fdr(true_pv, sim_pv, cells)
mdist <- fisher_dist(true_pv, cells)

flog.debug("fisher FDR calculation DONE...")


hc <- hclust_tree(pinmat_df, mfdr, mdist)
tree_df <- tree_py(mdist, method='average')

flog.debug("hclust calculation DONE...")

sharemin <- 0.85
fdrthres <- -3
nshare <- 4
climbtoshare <- 3


hc <- find_clones(hc,
    climbtoshare=climbtoshare,
    nshare=nshare,
    fdrthres=fdrthres,
    sharemin=sharemin
)
flog.debug("find clones calculation DONE...")

subclones <- find_subclones(
    hc, pinmat_df, pins_df,
    nsim=nsim, lmmax=lmmax, 
    baseshare=nshare,
    climbtoshare=climbtoshare,
    fdrthres=fdrthres,
    sharemin=sharemin
)

flog.debug("find subclones calculation DONE...")

filenames <- case_filenames(result_dir, "KPCLOH.Tumor2.DP.SP.result")

save_table(filenames$cells, data.frame(cell=cells))
save_table(filenames$seg, uber_seg)
save_table(filenames$featuremat, pinmat_df)
save_table(filenames$features, pins_df)

save_mat(filenames$true_pv, true_pv)
save_mat(filenames$sim_pv, sim_pv)

save_table(filenames$tree, tree_df)
save_table(filenames$clone, subclones)
