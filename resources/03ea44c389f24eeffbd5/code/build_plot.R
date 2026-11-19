make_source_plot <- function(P) {
  W <- file.path(P, 'work/2026-10-28-batch-five/gghic')
  L <- file.path(P, 'biofigure/benchmark/library/epigenomics/gghic-multichromosome-20261028')
  .libPaths(c(file.path(W, 'Rlib'), .libPaths()))
  suppressPackageStartupMessages(library(GenomicRanges))
  suppressPackageStartupMessages(library(gghic))
  suppressPackageStartupMessages(library(ggplot2))
  D <- file.path(L, 'data/raw'); out <- file.path(L, 'results/plot_data')
  cache <- file.path(L, 'data/cache')
  dir.create(cache, recursive=TRUE, showWarnings=FALSE)
  # Native cache access only: make repeated rendering independent of UCSC availability.
  assignInNamespace('.getCacheDir', function() cache, ns='gghic')
  bands <- read.delim(gzfile(file.path(D, 'cytoBandIdeo.hg19.txt.gz')), header=FALSE,
    col.names=c('chrom','chromStart','chromEnd','name','gieStain'))
  saveRDS(bands, file.path(cache,'cytoBand.hg19.rds'))
  focus <- 'chr11:10000001-11000000 | chr4:10000001-11000000'
  cc <- gghic::ChromatinContacts(cooler_path=file.path(D,'chr4_11-5kb.cool'), focus=focus)
  cc <- gghic::import(cc)
  contacts <- as.data.frame(gghic::as_tibble(cc))
  stopifnot(all(contacts$start1>10000000),all(contacts$start1<11000000),
    all(contacts$start2>10000000),all(contacts$start2<11000000),
    all(contacts$end1-contacts$start1+1==5000),
    all(contacts$end2-contacts$start2+1==5000))
  write.csv(contacts,file.path(out,'gghic_multichromosome_20261028_contacts.csv'),row.names=FALSE)
  loop_tab <- read.delim(file.path(D,'loops-chr4_11.txt'),header=FALSE)
  stopifnot(ncol(loop_tab)==6)
  l1 <- GenomicRanges::GRanges(loop_tab[[1]],IRanges::IRanges(loop_tab[[2]]+1,loop_tab[[3]]))
  l2 <- GenomicRanges::GRanges(loop_tab[[4]],IRanges::IRanges(loop_tab[[5]]+1,loop_tab[[6]]))
  gghic::features(cc,'loops') <- InteractionSet::GInteractions(l1,l2)
  loci <- GenomicRanges::GRanges(c('chr11','chr4'),IRanges::IRanges(10000001,11000000))
  tracks <- lapply(1:2,function(i)rtracklayer::import(file.path(D,paste0('track',i,'.bigWig')),which=loci))
  names(tracks) <- c('Signal 1','Signal 2')
  gghic::features(cc,'tracks') <- GenomicRanges::GRangesList(tracks)
  for(i in seq_along(tracks))write.csv(as.data.frame(tracks[[i]]),file.path(out,paste0('gghic_multichromosome_20261028_signal',i,'.csv')),row.names=FALSE)
  loop_df <- as.data.frame(gghic::features(cc,'loops'))
  write.csv(loop_df,file.path(out,'gghic_multichromosome_20261028_loops.csv'),row.names=FALSE)
  p <- gghic::gghic(cc, draw_boundary=TRUE, rasterize=TRUE,
    ideogram=TRUE, genome='hg19', highlight=TRUE, ideogram_fontsize=7,
    ideogram_colour='#95576B', ideogram_fill='#F2E1E8', ideogram_width_ratio=.07,
    annotation=TRUE, include_ncrna=FALSE, gtf_path=file.path(D,'gencode-chr4_11.gtf.gz'),
    annotation_style='arrow', maxgap=100000, annotation_fontsize=6.5,
    annotation_colour='#8A687B', annotation_fill='#B39AA8', annotation_width_ratio=.06,
    track=TRUE, track_width_ratio=.28, track_fill=c('#BD8864','#776080'),
    track_fontsize=6.5, data_range='maximum',
    loop=TRUE,loop_style='arc',loop_colour='#48364B',stroke=.3,
    expand_xaxis=TRUE,expand_left=300000,expand_right=150000)
  p$scales$scales <- Filter(function(s)!'fill'%in%s$aesthetics,p$scales$scales)
  p <- p + scale_fill_gradientn(colours=c('#FFFBF3','#E5C39D','#B78583','#78516E','#402C49'),
    name='Balanced Hi-C\n(log10)',guide=guide_colourbar(barheight=grid::unit(24,'mm'),barwidth=grid::unit(3,'mm'))) +
    theme(text=element_text(family='Arial',size=7),
      axis.text=element_text(size=6.5,colour='#30343B'),
      legend.text=element_text(size=6.5),legend.title=element_text(size=7),
      plot.margin=margin(4,4,4,4,'mm'),legend.key.height=grid::unit(24,'mm'),
      legend.key.width=grid::unit(3,'mm'),plot.background=element_rect(fill='white',colour=NA))
  # Omit the source's duplicated boundary tick; chromosome identity stays explicit.
  xs <- p$scales$get_scales('x')
  if(is.character(xs$labels))xs$labels[grepl('^\\n',xs$labels)] <- ''
  p$layers[[3]]$geom_params$draw_boundary <- FALSE
  attr(p,'source_contacts') <- contacts
  attr(p,'source_loop_table') <- loop_df
  p
}

final_font_grob <- function(g) {
  if(inherits(g,'text')) {
    g$gp$fontfamily <- 'Arial'
    for(i in seq_along(g$label)) {
      if(g$label[i]=='ZNF518B')g$x[i] <- g$x[i]-grid::unit(1.5,'mm')
      if(g$label[i]=='CLNK')g$x[i] <- g$x[i]+grid::unit(1,'mm')
    }
  }
  if(!is.null(g$children))g$children <- do.call(grid::gList,lapply(g$children,final_font_grob))
  if(!is.null(g$grobs))g$grobs <- lapply(g$grobs,final_font_grob)
  g
}

collect_grob_text <- function(g,inherited=grid::gpar()) {
  gp<-inherited;for(k in names(g$gp))gp[[k]]<-g$gp[[k]]
  out<-list(labels=character(),families=character(),sizes=numeric())
  if(inherits(g,'text')&&length(g$label))out<-list(labels=as.character(g$label),families=gp$fontfamily,sizes=gp$fontsize)
  for(child in c(g$grobs,as.list(g$children))) {
    x<-collect_grob_text(child,gp);for(k in names(out))out[[k]]<-c(out[[k]],x[[k]])
  }
  out
}
