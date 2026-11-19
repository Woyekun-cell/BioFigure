# Join Fig. 1c publisher tables. Label style and classes are transcribed from
# the public issue-106 example. They are display metadata, not new measurements.
args <- commandArgs(TRUE)
stopifnot(length(args) == 4L)
xlsx <- args[1]
repo <- args[2]
out <- args[3]
audit <- args[4]
library(dplyr)
library(tidyr)

sheets <- paste0("Fig1c", 1:4)
read_sheet <- function(sheet) readxl::read_excel(xlsx, sheet, .name_repair = "minimal")
tables <- lapply(sheets, read_sheet)
csv_files <- paste0(sheets, c(".csv", ".csv", ".csv", "_GSEA.csv"))
for (i in seq_along(tables)) {
  paper_csv <- read.csv(file.path(repo, csv_files[i]), check.names = FALSE)
  if (names(paper_csv)[1] == "") paper_csv <- paper_csv[-1]
  stopifnot(identical(names(tables[[i]]), names(paper_csv)),
            isTRUE(all.equal(as.data.frame(tables[[i]]), paper_csv, tolerance = 1e-12)))
}
program <- tables[[1]]
tumor <- tables[[2]]
gene <- tables[[3]]
pathway <- tables[[4]]
names(program)[1] <- names(tumor)[1] <- names(gene)[1] <- "state"
states <- program$state
stopifnot(length(states) == 28L, !anyDuplicated(states), setequal(states, tumor$state),
          setequal(states, gene$state), setequal(states, pathway$state),
          ncol(program) == 7L, ncol(tumor) == 13L,
          nrow(gene) == 616L, n_distinct(gene$feature) == 22L,
          nrow(pathway) == 168L, n_distinct(pathway$source) == 6L,
          !anyDuplicated(gene[c("state", "feature")]),
          !anyDuplicated(pathway[c("state", "source")]),
          !anyNA(program), !anyNA(tumor), !anyNA(gene), !anyNA(pathway),
          all(as.matrix(program[-1]) >= 0 & as.matrix(program[-1]) <= 1),
          all(as.matrix(tumor[-1]) >= 0 & as.matrix(tumor[-1]) <= 1),
          max(abs(rowSums(program[-1]) - 1)) < 1e-12,
          max(abs(rowSums(tumor[-1]) - 1)) < 1e-12,
          all(gene$proportion >= 0 & gene$proportion <= 1),
          all(pathway$pval_plot > 0 & pathway$pval_plot <= 1),
          max(abs(-log(pathway$pval_plot) - pathway$ng_log_p)) < 1e-12)
expression <- pivot_wider(gene, names_from = feature, values_from = c(mean, proportion))
enrichment <- pathway |>
  select(state, source, norm, pval_plot) |>
  pivot_wider(names_from = source, values_from = c(norm, pval_plot))

# The published example visibly emphasizes these ten labels. The tumor
# composition table cannot independently recover the author's prevalence flags.
bold <- c("Gliosis-like", "Hypoxic 1", "Hypoxic 2", "AC progenitor-like 2",
          "AC-gliosis-like 1", "AC progenitor-like 1", "OPC-like 2",
          "OPC-NPC-like 1", "Proliferative AC-OPC-like", "OPC-like 1")
stopifnot(all(bold %in% states))
meta <- tibble(state = states) |>
  mutate(
    subclass = if_else(startsWith(state, "Proliferative "), "Proliferative",
                       sub(" [0-9]+$", "", state)),
    class = case_when(
      subclass == "Proliferative" ~ "Proliferative",
      subclass == "NPC-neuronal-like" ~ "NPC-neuronal-like",
      subclass %in% c("OPC-like", "OPC-NPC-like", "OPC-neuronal-like") ~ "NPC-OPC-like",
      subclass %in% c("AC-gliosis-like", "AC progenitor-like",
                      "Gliosis-like", "Hypoxic") ~ "AC-gliosis-hypoxia"
    ),
    label = sub("^Proliferative ", "Prolif. ", state),
    label = sub("^NPC-neuronal-like", "NPC-neuro.-like", label),
    label = sub("^OPC-neuronal-like", "OPC-neuro.-like", label),
    label = sub("^AC progenitor-like", "AC-prog.-like", label),
    label = sub("^(Prolif. (AC-OPC|NPC-OPC))(-like)$", "\\1", label),
    common = state %in% bold
  )
wide <- Reduce(function(x, y) left_join(x, y, by = "state", relationship = "one-to-one"),
               list(meta, program, tumor, expression, enrichment))
# The two proliferative sister leaves share a merge. Their starting order
# reproduces the orientation shown in the example without changing distances.
pair <- match(c("Proliferative AC-OPC-like", "Proliferative NPC-OPC-like"), wide$state)
wide[pair, ] <- wide[rev(pair), ]
stopifnot(identical(dim(wide), c(28L, 79L)), !anyNA(wide))
m <- as.matrix(select(wide, starts_with("mean_")))
rownames(m) <- wide$state
tree <- hclust(dist(m), method = "complete")
shown <- c(5,3,1,2,4)
expected <- c(paste("NPC-neuronal-like", shown),
  "Gliosis-like", "Hypoxic 1", "Hypoxic 2", "AC-gliosis-like 4",
  "AC-gliosis-like 2", "AC progenitor-like 2", "AC progenitor-like 4",
  "AC-gliosis-like 3", "AC-gliosis-like 1", "AC progenitor-like 3",
  "AC progenitor-like 1", "OPC-like 3", "OPC-like 5", "OPC-like 2",
  "OPC-NPC-like 3", "OPC-NPC-like 2", "OPC-like 4", "OPC-NPC-like 1",
  "Proliferative NPC-OPC-like", "Proliferative AC-OPC-like",
  "Proliferative nIPC-like", "OPC-like 1", "OPC-neuronal-like")
stopifnot(identical(tree$labels[tree$order], expected))
readr::write_csv(wide, out)
jsonlite::write_json(list(
  scope = "Publisher source values with tutorial display metadata and tutorial clustering",
  xlsx_csv_value_agreement = TRUE, numerical_fields_complete = TRUE,
  states = nrow(wide), program_rows = nrow(program) * (ncol(program) - 1L),
  tumor_rows = nrow(tumor) * (ncol(tumor) - 1L), marker_rows = nrow(gene),
  pathway_rows = nrow(pathway), bold_labels_transcribed = bold,
  program_max_sum_error = max(abs(rowSums(program[-1]) - 1)),
  tumor_max_sum_error = max(abs(rowSums(tumor[-1]) - 1)),
  pathway_p_min = min(pathway$pval_plot), pathway_p_max = max(pathway$pval_plot),
  pathway_neg_log_max_delta = max(abs(-log(pathway$pval_plot) - pathway$ng_log_p)),
  order_matches_tutorial = TRUE, displayed_state_order = tree$labels[tree$order],
  sizes = list(marker = "radius = expression proportion", pathway = "area = -ln(pval_plot)"),
  R = R.version.string, packages = sapply(c("readxl","dplyr","tidyr","readr","jsonlite"),
    function(x) as.character(packageVersion(x)))
), audit, auto_unbox = TRUE, pretty = TRUE)
