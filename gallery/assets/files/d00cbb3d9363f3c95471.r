#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(ggplot2)
  library(ggalluvial)
  library(dplyr)
})

project_root <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value=TRUE)[1])), ".."))
skill_root <- normalizePath(file.path(project_root, "..", "..", ".."))
Sys.setenv(BIOFIGURE_SKILL_ROOT=skill_root)
source(file.path(project_root, "scripts", "sankey_style.R"))

figure_dir <- file.path(project_root, "results", "figures")
data_dir <- file.path(project_root, "results", "plot_data")
dir.create(figure_dir, recursive=TRUE, showWarnings=FALSE)
dir.create(data_dir, recursive=TRUE, showWarnings=FALSE)

states <- c("Stem", "Cycling", "Differentiating", "Immune", "Stress")
palette <- c(
  Stem="#355F7D",
  Cycling="#7298BF",
  Differentiating="#4FA79D",
  Immune="#D0AD52",
  Stress="#C46F68"
)
label_colours <- c(Stem="white", Cycling="#17212B", Differentiating="#17212B",
                   Immune="#17212B", Stress="#17212B")

transition <- function(previous, matrix) {
  vapply(previous, function(state) {
    sample(states, 1, prob=matrix[state, states])
  }, character(1))
}

set.seed(20260927)
n_units <- 360L
baseline <- sample(states, n_units, replace=TRUE, prob=c(.30,.22,.20,.17,.11))
t1 <- rbind(
  Stem=c(.62,.22,.16,0,0),
  Cycling=c(.12,.58,.22,0,.08),
  Differentiating=c(0,.08,.72,.15,.05),
  Immune=c(0,0,.08,.87,.05),
  Stress=c(0,.04,.18,.12,.66))
t2 <- rbind(
  Stem=c(.42,.16,.42,0,0),
  Cycling=c(0,.38,.48,0,.14),
  Differentiating=c(0,0,.78,.18,.04),
  Immune=c(0,0,.08,.88,.04),
  Stress=c(0,0,.24,.12,.64))
t3 <- rbind(
  Stem=c(.30,.10,.60,0,0),
  Cycling=c(0,.24,.60,.06,.10),
  Differentiating=c(0,0,.78,.18,.04),
  Immune=c(0,0,.08,.89,.03),
  Stress=c(0,0,.28,.18,.54))
colnames(t1) <- colnames(t2) <- colnames(t3) <- states

lineages <- data.frame(
  lineage_id=sprintf("L%03d", seq_len(n_units)),
  Baseline=baseline,
  Day3=transition(baseline, t1),
  stringsAsFactors=FALSE)
lineages$Day7 <- transition(lineages$Day3, t2)
lineages$Day14 <- transition(lineages$Day7, t3)
lineages <- lineages |>
  mutate(across(Baseline:Day14, ~factor(.x, levels=states)))

paths <- lineages |>
  count(Baseline, Day3, Day7, Day14, name="tracked_cells", .drop=FALSE) |>
  filter(tracked_cells > 0) |>
  arrange(Baseline, Day3, Day7, Day14)

stopifnot(sum(paths$tracked_cells)==n_units)
write.csv(lineages, file.path(data_dir, "sankey_lineage_units.csv"), row.names=FALSE)
write.csv(paths, file.path(data_dir, "sankey_aggregated_paths.csv"), row.names=FALSE)

paths_plot <- paths |>
  mutate(
    Baseline=paste0("B|", Baseline),
    Day3=paste0("D3|", Day3),
    Day7=paste0("D7|", Day7),
    Day14=paste0("D14|", Day14))
node_keys <- unlist(lapply(c("B","D3","D7","D14"), function(stage) paste0(stage,"|",states)))
node_palette <- setNames(rep(unname(palette), times=4), node_keys)
node_text <- setNames(rep(unname(label_colours), times=4), node_keys)

font <- bf_font("Arial")
p <- ggplot(paths_plot,
  aes(y=tracked_cells, axis1=Baseline, axis2=Day3, axis3=Day7, axis4=Day14)) +
  geom_alluvium(aes(fill=Baseline),
    width=.13, knot.pos=.46, alpha=.50, colour=NA) +
  geom_stratum(aes(fill=after_stat(stratum)),
    width=.13, colour="white", linewidth=.38) +
  geom_text(stat="stratum",
    aes(label=sub("^[^|]+\\|", "", after_stat(stratum)), colour=after_stat(stratum)),
    family=font$family, size=2.46, fontface="plain", lineheight=.92) +
  scale_x_discrete(
    limits=c("Baseline","Day 3","Day 7","Day 14"),
    expand=c(.075,.075)) +
  scale_y_continuous(
    breaks=c(0,90,180,270,360),
    limits=c(0,360),
    expand=c(0,0)) +
  scale_fill_manual(values=node_palette, drop=FALSE, guide="none") +
  scale_colour_manual(values=node_text, drop=FALSE, guide="none") +
  labs(x=NULL, y="Tracked cells") +
  bf_theme(font, size=7) +
  theme(
    axis.text.x=element_text(size=7, face="plain", margin=margin(t=3)),
    axis.text.y=element_text(size=7),
    axis.title.y=element_text(size=7, margin=margin(r=5)),
    axis.line.x=element_blank(),
    axis.ticks.x=element_blank(),
    axis.line.y=element_line(linewidth=.32, colour="#333333"),
    axis.ticks.y=element_line(linewidth=.28, colour="#333333"),
    legend.position="none",
    plot.margin=margin(4,5,3,4,unit="mm"))

allowed_text <- c("Baseline","Day 3","Day 7","Day 14",states,"Tracked cells",
                  "0","90","180","270","360")
boxes <- data.frame(
  id=c("data","labels","legend"),
  x=c(18,18,180), y=c(8,8,0),
  w=c(160,160,1), h=c(100,100,1))
authorization <- Sys.getenv("BIOFIGURE_AUTHORIZATION", unset="")
if(!nzchar(authorization)) stop("BIOFIGURE_AUTHORIZATION is required")

bf_render_png(
  p,
  file.path(figure_dir, "simulated_cell_state_sankey.png"),
  font,
  allowed_text,
  width_mm=183,
  height_mm=112,
  target_width_mm=183,
  source_files=c(
    file.path(project_root, "scripts", "plot_sankey.R"),
    file.path(project_root, "scripts", "sankey_style.R"),
    file.path(project_root, "work", "sankey", "design-spec.yaml")),
  boxes=boxes,
  allowed_pairs=c("data:labels"),
  dpi=300,
  min_text_pt=6,
  authorization=authorization,
  publication_size_class="double-column")
