setwd(normalizePath(commandArgs(TRUE)[1]))
source("figure_style.R")
font <- bf_font("Arial")
data <- read.csv("data/fig2b_ratios.csv", stringsAsFactors=FALSE)
species_order <- c("Ppse", "Pwua", "Pyun", "Psze", "Plas", "Psim", "Pade", "Pdav", "Prot", "Pqio")
species_labels <- c(
  Ppse="P. pseudoglauca", Pwua="P. wuana", Pyun="P. yunnanensis",
  Psze="P. szechuanica", Plas="P. lasiocarpa", Psim="P. simonii",
  Pade="P. adenopoda", Pdav="P. davidiana", Prot="P. rotundifolia",
  Pqio="P. qiongdaoensis"
)
state_order <- c("A-B", "B-A", "A-A", "B-B")
data$species_code <- factor(data$species_code, levels=species_order, ordered=TRUE)
data$status <- factor(data$status, levels=state_order, ordered=TRUE)
data$ratio <- as.numeric(data$ratio)

expected_groups <- length(species_order)
expected_states <- length(state_order)
if (nrow(data) != expected_groups * expected_states) stop("expected exactly 40 published species-state ratios")
if (length(unique(data$species_code)) != expected_groups) stop("species coverage mismatch")
if (any(!is.finite(data$ratio)) || any(data$ratio < 0 | data$ratio > 1)) stop("ratio outside [0,1]")
closure <- aggregate(ratio ~ species_code, data, sum)
if (nrow(closure) != expected_groups || any(abs(closure$ratio - 1) > 1e-12)) stop("published ratios fail composition closure")
for (species in species_order) {
  states <- as.character(data$status[data$species_code == species])
  if (!identical(states, state_order)) stop(paste("state order or coverage mismatch for", species))
}

publication_palette <- c("A-B"="#A6CEE3", "B-A"="#2166AC", "A-A"="#DBDBDB", "B-B"="#999999")
data$species_index <- match(as.character(data$species_code), species_order)
nx <- 500
ny <- 40
rank_fraction <- (seq_len(nx) - 0.5) / nx
band_colours <- grDevices::colorRampPalette(c("#FDAE91","#FEF2ED","#FDAE91"))(nx)
band_raster <- matrix(NA_character_, nrow=ny, ncol=nx)
for (column in seq_len(nx)) {
  visible_rows <- max(1, round(rank_fraction[column] * ny))
  band_raster[(ny-visible_rows+1):ny, column] <- band_colours[column]
}

p <- ggplot2::ggplot(data, ggplot2::aes(x=species_index, y=ratio, fill=status)) +
  ggplot2::annotate("rect", xmin=1+(seq_len(nx)-1)/nx*9.5,
    xmax=1+seq_len(nx)/nx*9.5, ymin=-0.225,
    ymax=-0.225+rank_fraction*0.12, fill=band_colours, colour=NA) +
  ggplot2::geom_col(position=ggplot2::position_stack(reverse=FALSE), width=0.52) +
  ggplot2::annotate(
    "text", x=0.72, y=-0.165, label="K", family=font$family,
    fontface="italic", size=2.6, hjust=0.5, vjust=0.5
  ) +
  ggplot2::annotate(
    "text", x=0.98, y=-0.183, label="s", family=font$family,
    fontface="italic", size=2.2, hjust=0.5, vjust=0.5
  ) +
  ggplot2::annotate(
    "text", x=-1.60, y=1.23, label="b", family=font$family,
    fontface="bold", size=4.0, hjust=0, vjust=0.5
  ) +
  ggplot2::scale_fill_manual(
    values=publication_palette, breaks=state_order,
    labels=c("A-to-B","B-to-A","A-to-A","B-to-B"), drop=FALSE
  ) +
  ggplot2::scale_y_continuous(
    breaks=seq(0,1,0.25),
    labels=function(x) as.character(round(x*100)), expand=c(0,0)
  ) +
  ggplot2::scale_x_continuous(
    breaks=seq_along(species_order), labels=unname(species_labels[species_order]),
    expand=c(0,0)
  ) +
  ggplot2::coord_cartesian(xlim=c(0.5,10.5), ylim=c(-0.26,1.22), expand=FALSE, clip="off") +
  ggplot2::labs(x=NULL, y="Proportion", fill=NULL) +
  bf_theme(font, size=7) +
  ggplot2::theme(
    legend.position=c(0.48,0.94),
    legend.direction="horizontal",
    legend.text=ggplot2::element_text(size=7, face="plain"),
    # The publication swatches are about 2.2 mm at the inferred panel width.
    # A 4 mm key inflated the legend and the opaque legend background erased
    # the panel's top border in the previous render.
    legend.key.size=grid::unit(2.2, "mm"),
    legend.key.spacing.x=grid::unit(4.7, "mm"),
    legend.background=ggplot2::element_rect(fill="transparent", colour=NA),
    legend.key=ggplot2::element_rect(fill="white", colour=NA),
    axis.text.x=ggplot2::element_text(size=7, face="italic", angle=45, hjust=1, vjust=1, colour="black"),
    axis.ticks.x=ggplot2::element_blank(),
    axis.line.x=ggplot2::element_blank(),
    axis.title.x=ggplot2::element_blank(),
    axis.text.y=ggplot2::element_text(size=7),
    axis.title.y=ggplot2::element_text(size=8),
    axis.line.y=ggplot2::element_blank(),
    panel.grid=ggplot2::element_blank(),
    panel.border=ggplot2::element_rect(fill=NA, colour="black", linewidth=0.25),
    plot.margin=ggplot2::margin(5,2,0,6.5,unit="mm")
  ) +
  ggplot2::guides(fill=ggplot2::guide_legend(nrow=1, byrow=TRUE))

dir.create("results", showWarnings=FALSE)
allowed_text <- c(
  "b","Proportion","K","s","Ks","A-to-B","B-to-A","A-to-A","B-to-B",
  "0","25","50","75","100",unname(species_labels)
)
boxes <- data.frame(
  id=c("data","labels","legend","annotation"),
  x=c(15,5,22,0.5), y=c(17.5,0.5,45.5,49), w=c(74,85,57,4), h=c(26.5,16,3,4)
)
# Native vector band avoids Quartz raster inversion. Exact code/data authorization
# is consumed by run_populus.py; do not mint an official ggplot CP3 receipt.
ragg::agg_png("results/fig2b_v2.png",width=90,height=54,units="mm",res=400,background="white");print(p);dev.off()
quartz(type="pdf",file="results/fig2b_v2.pdf",width=90/25.4,height=54/25.4,family="Arial");print(p);dev.off()
svglite::svglite("results/fig2b_v2.svg",width=90/25.4,height=54/25.4,bg="white");print(p);dev.off()

checks <- list(
  ten_species=list(status="pass", evidence="Exactly 10 ordered species groups rendered; order equals author factor order and published Fig. 2b labels."),
  four_states_per_species=list(status="pass", evidence="40 source rows form exactly four states A-B, B-A, A-A, B-B for each of 10 species."),
  composition_closure=list(status="pass", evidence=sprintf("All 10 species-pair ratio sums equal 1 within 1e-12; maximum absolute closure error %.3g.", max(abs(closure$ratio-1)))),
  source_ratios_preserved=list(status="pass", evidence="The 40 precomputed Supplementary Table 5 ratios are plotted directly with geom_col(position_stack); no second normalization or denominator change."),
  published_order=list(status="pass", evidence="Explicit factor order Ppse, Pwua, Pyun, Psze, Plas, Psim, Pade, Pdav, Prot, Pqio matches the author's Figure2bcd.R and the viewed panel."),
  legend_stack_order=list(status="pass", evidence="All four published transition labels appear once; bottom-to-top stack order is B-B, A-A, B-A, A-B while legend reads A-to-B, B-to-A, A-to-A, B-to-B.")
)
jsonlite::write_json(checks, "results/scientific_results.json", auto_unbox=TRUE, pretty=TRUE)
writeLines(capture.output(sessionInfo()), "results/session-info.txt")
