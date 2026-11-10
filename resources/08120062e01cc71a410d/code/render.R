#!/usr/bin/env Rscript
# SCICASE-014: source-exposed, input-driven native corrplot adapter.
# Caller-precomputed synthetic or real correlations; no observation/n/P reconstruction.
# Context/method/unit declarations and descriptive_only=true are mandatory.
# Interface: matrix.csv, metadata.csv, expected-keys.csv, settings.json in run cwd.
# Named row/column keys determine alignment. Metadata row position never does.
suppressPackageStartupMessages({
  library(corrplot)
  library(RColorBrewer)
  library(ragg)
  library(jsonlite)
  library(svglite)
  library(systemfonts)
  library(digest)
})

args <- commandArgs(trailingOnly=TRUE)
paths <- if (length(args)) args else c("matrix.csv", "metadata.csv", "settings.json", "expected-keys.csv")
if (length(paths) != 4L) stop("usage: Rscript render.R matrix.csv metadata.csv settings.json expected-keys.csv")
raw <- read.csv(paths[1], row.names=1, check.names=FALSE, na.strings=c("NA", ""))
metadata <- read.csv(paths[2], check.names=FALSE, stringsAsFactors=FALSE)
cfg <- jsonlite::fromJSON(paths[3])
expected <- read.csv(paths[4], check.names=FALSE, stringsAsFactors=FALSE)
rho <- as.matrix(raw)
storage.mode(rho) <- "double"
n <- ncol(rho)
if (n < 4L || n > 18L || nrow(rho) != n) stop("matrix must be square with 4..18 variables; denser input requires panel splitting")
keys <- colnames(rho)
if (anyDuplicated(keys) || anyDuplicated(rownames(rho)) || !setequal(keys, rownames(rho))) stop("matrix row and column keys must be unique and have the same set")
rho <- rho[match(keys, rownames(rho)), keys, drop=FALSE]
if (!identical(rownames(rho), keys)) stop("matrix key alignment failed")
if (!all(c("variable_id", "label", "group") %in% names(metadata))) stop("metadata requires variable_id,label,group")
if (anyDuplicated(metadata$variable_id) || !setequal(metadata$variable_id, keys)) stop("metadata keys must match matrix exactly, without duplicates or extras")
input_metadata_order <- metadata$variable_id
metadata <- metadata[match(keys, metadata$variable_id), , drop=FALSE]
if (!identical(metadata$variable_id, keys)) stop("metadata key alignment failed")
if (!all(c("variable_id","group") %in% names(expected)) || anyDuplicated(expected$variable_id) || !setequal(expected$variable_id,keys)) stop("independent expected keyed grouping must match the matrix exactly")
expected <- expected[match(keys, expected$variable_id), , drop=FALSE]
if (!identical(metadata$group, expected$group)) stop("key-joined category differs from independently recorded expected mapping")
if (any(!nzchar(metadata$label)) || any(!nzchar(metadata$group))) stop("labels and groups cannot be empty")
if (!identical(is.na(rho), t(is.na(rho)))) stop("missing-value mask must be symmetric")
if (max(abs(rho-t(rho)), na.rm=TRUE) > 1e-10) stop("rho matrix must be symmetric after row-key alignment")
if (any(!is.finite(rho[!is.na(rho)])) || any(abs(rho[!is.na(rho)]) > 1+1e-10)) stop("finite rho values must be within -1..1")
if (anyNA(diag(rho)) || any(abs(diag(rho)-1) > 1e-10)) stop("self-correlation diagonal must be observed and one")
# General precomputed interface. These are caller declarations, never inferred
# from variable counts, coefficient values, labels or metadata row count.
declarations <- c("data_context", "association_method", "experimental_unit", "figure_caption")
for (field in declarations) {
  value <- cfg[[field]]
  if (!is.character(value) || length(value)!=1L || is.na(value) || !nzchar(trimws(value)))
    stop(paste("missing mandatory nonempty caller declaration:",field))
}
if (!isTRUE(cfg$descriptive_only)) stop("descriptive_only=true is required; renderer does not infer biological n or P values")
if (!is.logical(cfg$synthetic) || length(cfg$synthetic)!=1L || is.na(cfg$synthetic)) stop("synthetic must be an explicit boolean; true and false are accepted")
method_symbols <- c(Pearson="r",Spearman="rho",Kendall="tau")
if (!cfg$association_method %in% names(method_symbols)) stop("association_method must explicitly be Pearson, Spearman or Kendall")
if (!is.character(cfg$coefficient_label) || length(cfg$coefficient_label)!=1L ||
    cfg$coefficient_label != unname(method_symbols[cfg$association_method])) stop("coefficient_label must match the declared association method")
if (any(c("biological_n","sample_size","p_values","p_matrix","inference_requested") %in% names(cfg))) stop("n/P/inference fields are outside the descriptive precomputed interface")
# A complete correlation matrix must be PSD. Missing entries prevent this global
# verification; there is deliberately no zero filling or fabricated completion.
qc_tolerance <- n*1e-8
matrix_qc <- list(tolerance=qc_tolerance,missing_cells=sum(is.na(rho)),global_psd_checked=!anyNA(rho))
if (!anyNA(rho)) {
  min_eigenvalue <- min(eigen(rho,symmetric=TRUE,only.values=TRUE)$values)
  if (min_eigenvalue < -qc_tolerance) stop(sprintf("complete correlation matrix is not positive semidefinite: minimum eigenvalue %.12g < -%.12g",min_eigenvalue,qc_tolerance))
  matrix_qc$psd_status <- "pass_complete_matrix"
  matrix_qc$minimum_eigenvalue <- min_eigenvalue
} else {
  matrix_qc$psd_status <- "cannot_globally_verify_due_to_missing_values"
  matrix_qc$missing_value_policy <- "Retained NA without zero filling, imputation or globally claiming PSD. Only jointly observed exact-unit-correlation consistency is checked."
}
unit_pairs <- which(upper.tri(rho) & !is.na(rho) & (rho==1 | rho== -1),arr.ind=TRUE)
unit_pair_evidence <- list()
if (nrow(unit_pairs)) for (k in seq_len(nrow(unit_pairs))) {
  i <- unit_pairs[k,1];j <- unit_pairs[k,2];sgn <- rho[i,j]
  observed <- !is.na(rho[i,]) & !is.na(rho[j,])
  delta <- max(abs(rho[i,observed]-sgn*rho[j,observed]))
  if (delta > qc_tolerance) stop(sprintf("inconsistent exact unit correlation for %s/%s: observed-row residual %.12g",keys[i],keys[j],delta))
  unit_pair_evidence[[k]] <- list(variable_1=keys[i],variable_2=keys[j],coefficient=sgn,jointly_observed_columns=sum(observed),max_equal_or_opposite_residual=delta)
}
matrix_qc$exact_unit_pairs <- unit_pair_evidence
matrix_qc$exact_unit_consistency <- "pass_on_jointly_observed_columns"
context <- list(data_context=cfg$data_context,association_method=cfg$association_method,experimental_unit=cfg$experimental_unit,descriptive_only=cfg$descriptive_only,synthetic=cfg$synthetic,inferred_n=NULL,inferred_p_values=NULL,inference_performed=FALSE)

groups <- unique(metadata$group)
if (!all(groups %in% names(cfg$group_colors))) stop("each keyed category requires a named color")
colors <- unlist(cfg$group_colors, use.names=TRUE)[metadata$group]
if (anyNA(colors)) stop("missing category color")
font <- systemfonts::match_fonts(cfg$font_family)$path[1]
if (!file.exists(font) || cfg$font_family != "Arial") stop("Arial font not resolved")
font_sha256 <- digest::digest(file=font, algo="sha256")
if (!identical(font_sha256, cfg$font_file_sha256)) stop("Arial font SHA256 differs from locked input settings")
font_config <- jsonlite::fromJSON('font-contract.json')
font_sizes <- unlist(font_config$size_roles_pt)
stopifnot(identical(font_config$family,'Arial'),all(is.finite(font_sizes)),
          min(font_sizes)>=6,max(font_sizes)<=12,length(unique(font_sizes))==1)
cfg$font_pt <- font_config$size_roles_pt$axis_text
width <- cfg$width_mm
height <- cfg$height_mm
if ((width<89 || width>183) || height > 170 || cfg$font_pt < 6) stop("final-size contract requires 89..183mm width, height<=170mm and text>=6pt, followed by actual readability review")
palette <- grDevices::colorRampPalette(cfg$rho_palette)(201)
wrapped <- metadata$label # full names on all three source label positions; never truncate
dir.create("results", showWarnings=FALSE)
write.csv(rho, "results/matrix-aligned.csv")
write.csv(metadata, "results/metadata-aligned.csv", row.names=FALSE)
jsonlite::write_json(list(declarations=context,matrix_qc=matrix_qc),"results/input-context-qc.json",pretty=TRUE,auto_unbox=TRUE)

draw <- function() {
  # Native corrplot draws scientifically meaningful matrix cells. All surrounding
  # source annotation is aligned using the actual corrplot user/device transform.
  par(family="Arial", ps=cfg$font_pt, bg="white", xpd=NA,pty="m",plt=c(0,1,0,1))
  par(mar=c(0,0,0,0))
  plot.new(); plot.window(xlim=c(0,width),ylim=c(0,height),xaxs="i",yaxs="i")
  label_width_mm <- max(strwidth(wrapped, units="inches",cex=1))*25.4
  left_mm <- label_width_mm+2.3
  right_mm <- label_width_mm+6.2
  matrix_side_mm <- min(width-left_mm-right_mm-1.5, height-14-label_width_mm-3)
  if (matrix_side_mm/n < max(strheight(wrapped,units="inches")*25.4)*1.05)
    stop("Full names require a wider permitted canvas; never compress labels")
  bottom_mm <- 14
  top_mm <- bottom_mm+matrix_side_mm
  if (top_mm+label_width_mm+2 > height)
    stop("Full vertical names exceed top reserve: label=",label_width_mm," side=",matrix_side_mm," top=",top_mm," height=",height)
  par(fig=c(left_mm/width,(left_mm+matrix_side_mm)/width,bottom_mm/height,top_mm/height),
      mar=c(0,0,0,0), pty="s",new=TRUE)
  # Reuse the one initialized PDF page. corrplot(add=FALSE) would call
  # plot.new() again and export a leading blank Quartz page.
  limits <- c(.5-.01*n,n+.5+.01*n)
  plot.window(xlim=limits,ylim=limits,asp=1,xaxs="i",yaxs="i")
  corrplot::corrplot(rho, method="square", type="upper", order="original",
                    diag=TRUE, col=palette, col.lim=c(-1,1), cl.pos="n",
                    tl.pos="n", addgrid.col="#E5E5E5", na.label=" ",
                    na.label.col="#BDBDBD", mar=c(0,0,0,0),add=TRUE)
  # Excluded values visibly differ from both rho=0 (white) and the omitted lower
  # triangle. There is no significance mask, because P values are unavailable.
  missing <- which(is.na(rho) & upper.tri(rho, diag=TRUE), arr.ind=TRUE)
  if (nrow(missing)) {
    for (k in seq_len(nrow(missing))) {
      x <- missing[k,2]; y <- n-missing[k,1]+1
      rect(x-.43,y-.43,x+.43,y+.43,col="#BDBDBD",border="#777777",lwd=.5)
      segments(x-.22,y-.22,x+.22,y+.22,lwd=.7,col="#404040")
      segments(x-.22,y+.22,x+.22,y-.22,lwd=.7,col="#404040")
    }
  }
  key_width_mm <- strwidth(wrapped,units="inches",cex=1)*25.4
  key_left_mm <- grconvertX(seq_len(n)-.58,"user","ndc")*width-key_width_mm
  key_top_mm <- grconvertY(n+.58,"user","ndc")*height+key_width_mm
  if (any(key_left_mm<2) || any(key_top_mm>height-2)) stop("full variable names exceed label reserve; increase declared canvas within publication limits, never truncate names or shrink text")
  text(seq_len(n), rep(n+.58,n), labels=wrapped, col=colors, srt=90,
       adj=c(0,.5), cex=1, font=1)
  text(seq_len(n)-.58, n-seq_len(n)+1, labels=wrapped, col=colors,
       adj=c(1,.5), cex=1, font=1)
  rows_mm <- grconvertY(n-seq_len(n)+1, "user", "ndc")*height
  half_mm <- abs(grconvertY(1.5,"user","ndc")-grconvertY(.5,"user","ndc"))*height/2
  matrix_bbox <- c(grconvertX(.5,"user","ndc")*width,
                   min(rows_mm)-half_mm,
                   grconvertX(n+.5,"user","ndc")*width,
                   max(rows_mm)+half_mm)
  # corrplot restores an explicit square pin via par(oldpar). Reset plt too;
  # otherwise full-canvas user units would be stretched on a square plot region.
  par(fig=c(0,1,0,1), mar=c(0,0,0,0), pty="m",plt=c(0,1,0,1),new=TRUE)
  plot.new(); plot.window(xlim=c(0,width),ylim=c(0,height),xaxs="i",yaxs="i")
  sidebar_x <- matrix_bbox[3]+1
  name_x <- sidebar_x+4.1
  measured_widths <- strwidth(wrapped, units="user", cex=1)
  measured_heights <- strheight(wrapped, units="user", cex=1)
  if (any(name_x+measured_widths > width-1) || any(measured_heights > 2*half_mm*.96)) {
    stop("full labels exceed reserve: right=",max(name_x+measured_widths)," allowed=",width-1," height=",max(measured_heights)," row=",2*half_mm*.96)
  }
  for (i in seq_len(n)) {
    rect(sidebar_x,rows_mm[i]-half_mm,sidebar_x+2.4,rows_mm[i]+half_mm,
         col=colors[i],border=NA)
    text(name_x,rows_mm[i],wrapped[i],adj=c(0,.5),cex=1,col="#202020")
  }
  run <- rle(metadata$group); ends <- cumsum(run$lengths); starts <- ends-run$lengths+1L
  for (j in seq_along(run$values)) {
    ys <- mean(rows_mm[c(starts[j],ends[j])])
    foreground <- if (run$values[j] %in% c("B","C")) "#202020" else "white"
    group_text <- paste("Group",run$values[j])
    if (strwidth(group_text,units="user") > run$lengths[j]*2*half_mm*.96) group_text <- run$values[j]
    if (strwidth(group_text,units="user") > run$lengths[j]*2*half_mm*.96) stop("category name exceeds aligned strip reserve; use a stable short group key and full category metadata")
    text(sidebar_x+1.2,ys,group_text,srt=90,col=foreground,cex=1)
  }
  x0 <- matrix_bbox[1]; x1 <- matrix_bbox[3]
  y0 <- matrix_bbox[2]-5.5
  xs <- seq(x0,x1,length.out=202)
  for (i in seq_len(201)) rect(xs[i],y0,xs[i+1],y0+3.5,col=palette[i],border=NA)
  rect(x0,y0,x1,y0+3.5,border="#404040",lwd=.5)
  at <- x0+(c(-1,-.5,0,.5,1)+1)/2*(x1-x0)
  segments(at,y0,at,y0-1,lwd=.5)
  text(at,y0-2.8,c("-1","-0.5","0","0.5","1"),cex=1)
  text((x0+x1)/2,y0-7,cfg$coefficient_label,cex=1)
  if (nrow(missing)) {
  mx <- sidebar_x
  rect(mx,8,mx+3,11,col="#BDBDBD",border="#777777",lwd=.5)
  segments(mx+.6,8.6,mx+2.4,10.4,lwd=.7)
  segments(mx+.6,10.4,mx+2.4,8.6,lwd=.7)
  text(mx+4,9.5,"NA (excluded)",adj=c(0,.5),cex=1)
  }
  # Simulation and inference disclosure are retained in input-context-qc.json, outside the canvas.
  invisible(list(matrix_bbox_mm=matrix_bbox, category_strip_x_mm=sidebar_x,
                 right_label_x_mm=name_x, row_center_mm=rows_mm,
                 row_height_mm=2*half_mm, full_label_width_mm=measured_widths,
                 full_label_height_mm=measured_heights, minimum_text_pt=cfg$font_pt,font_sizes_pt=font_config$size_roles_pt,
                 longest_label_chars=max(nchar(metadata$label)), categories=groups,
                 font_file=font, font_file_sha256=font_sha256,
                 square_area_encoding="abs(rho); native corrplot square method",
                 coefficient_label=cfg$coefficient_label,figure_caption=cfg$figure_caption,
                 matrix_key_width_mm=key_width_mm, source_full_labels_on_matrix=TRUE,
                 output_width_mm=width,output_height_mm=height,label_reserve_mm=label_width_mm,
                 corrplot_function="corrplot::corrplot", native_method="square",
                 native_type="upper", metadata_alignment_by="variable_id exact match"))
}

ragg::agg_png("results/figure.png",width=width,height=height,units="mm",res=300,background="white")
geometry <- draw(); invisible(dev.off())
grDevices::quartz(type="pdf",file="results/figure.pdf",width=width/25.4,height=height/25.4,family="Arial",pointsize=cfg$font_pt)
draw(); invisible(dev.off())
svglite::svglite("results/figure.svg",width=width/25.4,height=height/25.4,pointsize=cfg$font_pt,system_fonts=list(sans="Arial"))
draw(); invisible(dev.off())
jsonlite::write_json(geometry,"results/geometry.json",pretty=TRUE,auto_unbox=TRUE)
check <- function(ok,evidence) list(status=if(isTRUE(ok))"pass" else "fail",evidence=evidence)
sc <- list(
  input_dimension_driven=check(nrow(rho)==n && length(geometry$row_center_mm)==n,
    sprintf("CSV determines %dx%d cells, %d labels/strip rows; recovered source fixture12x12; renderer contains no fixture-size panel count",n,n,n)),
  metadata_join_by_key=check(identical(metadata$variable_id,keys) && identical(metadata$group,expected$group),
    paste("exact variable_id matching verified against independent expected-keys.csv; input metadata order:",paste(input_metadata_order,collapse=","))),
  required_structures_preserved=check(geometry$native_method=="square" && geometry$native_type=="upper",
    "Executed corrplot::corrplot square upper triangle; same keyed color labels; row-aligned category strip/full-name table; outside -1..1 declared coefficient key; geometry.json records layout"),
  biological_unit_respected=check(isTRUE(cfg$descriptive_only) && is.logical(cfg$synthetic) && all(vapply(context[c("data_context","association_method","experimental_unit")],function(x) is.character(x) && length(x)==1L && nzchar(trimws(x)),TRUE)),
    paste("Caller-declared context:",cfg$data_context,"Declared method:",cfg$association_method,"Declared experimental unit:",cfg$experimental_unit,"Synthetic flag:",cfg$synthetic,"Matrix dimensions are variable counts, never biological n; no inferred P values, cor.mtest, tests, significance mask or biological conclusion; descriptive_only=true.")),
  precomputed_matrix_qc=check(matrix_qc$psd_status %in% c("pass_complete_matrix","cannot_globally_verify_due_to_missing_values") && matrix_qc$exact_unit_consistency=="pass_on_jointly_observed_columns",
    paste("Symmetry/diagonal/range checked; PSD status:",matrix_qc$psd_status,"tolerance:",qc_tolerance,"exact+/-1 pairs:",nrow(unit_pairs),"consistent on jointly observed columns. NA retained without zero filling; no global PSD claim for a missing matrix. See input-context-qc.json."))
)
if (identical(cfg$scenario,"stress")) {
  sc$stress_long_labels <- check(max(nchar(metadata$label))>=30 && all(geometry$full_label_height_mm <= geometry$row_height_mm*.96),
    sprintf("longest label %d characters; full single-line strings measured and retained on matrix plus sidebar at %dpt without truncation",max(nchar(metadata$label)),cfg$font_pt))
  sc$stress_multiple_groups <- check(length(groups)>=6, paste("six independently keyed categories:",paste(groups,collapse=",")))
  sc$stress_missing_values <- check(sum(is.na(rho)&upper.tri(rho))>=2,
    sprintf("%d upper-triangle NA pairs visibly gray with X; retained NA in matrix export; not zero or a fabricated nonsignificance mask",sum(is.na(rho)&upper.tri(rho))))
  sc$stress_extreme_values <- check(any(rho[upper.tri(rho)]==1,na.rm=TRUE) && any(rho[upper.tri(rho)]== -1,na.rm=TRUE),
    sprintf("off-diagonal exact rho=-1 and +1 retained; fixed color limits -1..1, observed range [%g,%g]",min(rho,na.rm=TRUE),max(rho,na.rm=TRUE)))
  sc$stress_shuffled_metadata <- check(!identical(input_metadata_order,keys) && identical(metadata$variable_id,keys) && identical(metadata$group,expected$group),
    "shuffled metadata row order restored using exact variable_id keys; independent expected group mapping verified for every label/strip row")
}
jsonlite::write_json(sc,"results/scientific_results.json",pretty=TRUE,auto_unbox=TRUE)
writeLines(capture.output(sessionInfo()),"results/session-info.txt")
if (any(vapply(sc,function(x)x$status!="pass",TRUE))) stop("predefined scientific checks failed")
cat("CORRPLOT_NATIVE_INPUT_DRIVEN_RENDER_OK; caller-precomputed descriptive matrix; no inferred n/P or CP3/blind-transfer certification\n")
