# Fig. 4 target wheel, independently redrawn with the published layout and colors from Pun et al. (2023), Tables S3/S6.
# Source DOI: 10.1111/acel.14017. Tutorial reviewed: MsTt笔记 (2026-11-17).
# Standalone: Rscript draw_wheel.R input.csv output.pdf
wheel_hallmarks <- c("Epigenetic shift", "Impaired proteostasis", "Mitochondrial dysfunction",
  "Cellular senescence", "Stem cell exhaustion", "Genomic instability", "Telomere attrition",
  "Retrotranspositions", "Inflammation", "Extracellular matrix stiffness",
  "Altered intercellular communications", "Deregulated nutrient signaling")
wheel_palette <- setNames(c("#4CBB17","#A6EB99","#FC9272","#A5A4A4","#6BAED6","#FFFF99",
  "#9E0142","#D53E4F","#F46D43","#FDAE61","#FEE08B","#FFFFBF","#E6F598","#ABDDA4",
  "#66C2A5","#3288BD","#5E4FA2","#400077","#90EE90","#006400"),
  c(paste("Group", 1:4), "Clinical yes", "Clinical no", wheel_hallmarks, "Cancer low", "Cancer high"))

prepare_wheel <- function(x) {
  integers <- c("sector_order", "n_tissues", "group", "druggable", "TSG",
                wheel_hallmarks, "n_cancer_hallmarks")
  required <- c("gene", integers)
  stopifnot(is.data.frame(x), !anyDuplicated(names(x)), all(required %in% names(x)),
            nrow(x) >= 2L, nrow(x) <= 180L, !anyNA(x[required]), is.character(x$gene),
            all(grepl("^[A-Za-z][A-Za-z0-9-]{0,9}$", x$gene)), !anyDuplicated(toupper(x$gene)))
  bounds <- c(nrow(x),47,4,1,1,rep(1,12),10)
  mins <- c(1,0,1,rep(0,15))
  for (i in seq_along(integers)) {
    v <- x[[integers[i]]]
    stopifnot(is.numeric(v), all(is.finite(v) & v == trunc(v) & v >= mins[i] & v <= bounds[i]))
  }
  stopifnot(!anyDuplicated(x$sector_order))
  if ("n_aging_hallmarks" %in% names(x)) {
    stopifnot(!anyNA(x$n_aging_hallmarks), all(x$n_aging_hallmarks == rowSums(x[wheel_hallmarks])))
  }
  if ("fig4_label_gray" %in% names(x)) {
    stopifnot(!anyNA(x$fig4_label_gray), all(x$fig4_label_gray %in% 0:1))
  }
  x[order(x$sector_order), , drop=FALSE]
}

draw_wheel <- function(x, palette=wheel_palette) {
  stopifnot(identical(names(palette), names(wheel_palette)))
  x <- prepare_wheel(x)
  n <- nrow(x)
  gap <- 10
  # The published 180-sector panel has 0.5 degree gaps; the given limit leaves
  # enough angular pitch when the same canvas is used for another input.
  small_gap <- .5
  stopifnot(requireNamespace("circlize", quietly=TRUE))
  circlize::circos.clear()
  on.exit(circlize::circos.clear(), add=TRUE)
  par(family="Arial", ps=7, cex=1, mar=rep(0,4), bg="white", xaxs="i", yaxs="i")
  circlize::circos.par(start.degree=90-gap/2, gap.after=c(rep(small_gap,n-1),gap),
    cell.padding=rep(0,4), track.margin=c(.002,.002), points.overflow.warning=FALSE,
    canvas.xlim=c(-1.04,1.04), canvas.ylim=c(-1.468,1.033))
  circlize::circos.initialize(factor(x$gene, levels=x$gene), xlim=c(0,1))
  fields <- c("n_tissues","gene","druggable",wheel_hallmarks,"n_cancer_hallmarks")
  track_no <- c(1,NA,2,3:14,15)
  seen <- matrix(0L,n,length(fields),dimnames=list(x$gene, fields))
  colors <- grDevices::colorRampPalette(unname(palette[c("Cancer low","Cancer high")]))(10)
  text_color <- c("#111111","#A5A4A4")
  gray <- if ("fig4_label_gray" %in% names(x)) x$fig4_label_gray else x$TSG
  tissue_max <- max(1,x$n_tissues)
  group_counts <- tabulate(x$group,nbins=4)
  group_color <- palette[paste("Group", x$group)]
  clinical_color <- unname(palette[ifelse(x$druggable==1,"Clinical yes","Clinical no")])
  current <- function(track) {
    j <- match(circlize::get.cell.meta.data("sector.index"), x$gene)
    seen[j, track] <<- seen[j, track]+1L
    j
  }
  track <- function(h, f, ylim=c(0,1)) {
    circlize::circos.trackPlotRegion(ylim=ylim, track.height=h, bg.border=NA, panel.fun=f)
  }
  rect <- function(color, left=.05, right=.95, low=0, high=1, line=NA) {
    circlize::circos.rect(left,low,right,high,col=color,border=line,lwd=.25)
  }
  track(.099,function(a,b) {
    j <- current(1)
    if (x$n_tissues[j] > 0)
      rect(group_color[j],.07,.93,high=x$n_tissues[j])
  }, ylim=c(0,tissue_max))
  track(.170,function(a,b) {
    j <- current(2)
    circlize::circos.text(.5,.043,x$gene[j],facing="clockwise",niceFacing=TRUE,
                         adj=c(0,.5),col=text_color[gray[j]+1])
  })
  track(.023,function(a,b) {
    j <- current(3)
    rect(clinical_color[j],0,1)
  })
  for (k in seq_along(wheel_hallmarks)) {
    field <- wheel_hallmarks[k]
    circlize::circos.par(track.margin=c(.002,if (k==1L) .023 else .002))
    track(.021,function(a,b) {
      j <- current(3+k)
      if (x[[field]][j]==1L)
        rect(palette[field],0,1)
    })
  }
  circlize::circos.par(track.margin=c(.001,.015))
  track(.028,function(a,b) {
    j <- current(16)
    v <- x$n_cancer_hallmarks[j]
    if (v>0L) rect(colors[v],left=.14,right=.86,low=.16,high=.84)
  })
  if (any(seen!=1L) || !identical(circlize::get.all.sector.index(),x$gene)) stop("inconsistent rendered keys")
  bounds <- vapply(seq_along(fields), function(i) {
    c(bottom=circlize::get.cell.meta.data("cell.bottom.radius",x$gene[1],i),
      top=circlize::get.cell.meta.data("cell.top.radius",x$gene[1],i))
  }, numeric(2))
  label_room <- (bounds["top", 2] - bounds["bottom", 2])*.957
  label_pitch <- 2*pi*bounds["bottom", 2]*(360-gap+small_gap)/(360*n)
  stopifnot(max(strwidth(x$gene))+.004 < label_room, max(strheight(x$gene)) < label_pitch)
  radii <- colMeans(bounds)[!is.na(track_no)]
  radii[1] <- bounds["bottom", 1] + .006
  boxed <- function(x,y,number) {
    graphics::rect(x-.022,y-.0107,x+.022,y+.0107,col="white",border="#222222",lwd=.46)
    text(x,y,number,col="#111111")
  }
  for (i in seq_along(radii)) boxed(0,radii[i],i)
  text(0,.029,"Age-associated",font=2,cex=1.43,col="#111111")
  text(0,-.027,"Cancer Targets",font=2,cex=1.43,col="#111111")

  label <- function(x,y,s,...) text(x,y,s,adj=c(0,.5),...)
  swatch <- function(x,y,fill,s) {
    graphics::rect(x,y-.007,x+.022,y+.007,col=fill,border=NA)
    label(x+.032,y,s)
  }
  gx <- -.987
  gy <- -1.080
  boxed(gx,gy,1)
  label(gx+.032,gy,"No. of tissues with age-associated expression changes")
  label(gx+.027,gy-.047,"Target groups")
  gtext <- c("Evidence in extending lifespan, dual-purpose","Evidence in extending lifespan, not dual-purpose",
             "Evidence in shortening lifespan only","Unexplored role in regulating lifespan")
  for (i in 1:4) {
    description <- sprintf("Group %d - %s (n = %d)",i,gtext[i],group_counts[i])
    swatch(gx+.011,gy-.060-i*.032,palette[paste("Group",i)],description)
  }
  boxed(gx,gy-.273,2)
  label(gx+.032,gy-.273,"With approved / clinical investigational drugs")
  swatch(-.374,gy-.273,palette["Clinical yes"],"Yes")
  swatch(-.260,gy-.273,palette["Clinical no"],"No")

  segments(.020,gy+.011,.020,gy-.205,col="#222222",lwd=.5)
  text(-.049,gy-.079,"Hallmarks")
  text(-.049,gy-.113,"of")
  text(-.049,gy-.147,"Aging")
  for (i in seq_along(wheel_hallmarks)) {
    lx <- if (i%%2L==1L) .054 else .584
    ly <- gy-((i-1)%/%2L)*.034
    boxed(lx,ly,i+2L)
    label(lx+.032,ly,wheel_hallmarks[i])
  }
  cy <- gy-.273
  boxed(.054,cy,15)
  label(.086,cy,"No. of cancer hallmarks implicated")
  scale_x <- .535+seq(0,.30,length.out=11)
  graphics::rect(scale_x[-11],cy-.009,scale_x[-1],cy+.009,col=colors,border=NA)
  text(scale_x[c(1,5,11)]+c(.014,.014,-.013),cy-.029,c(1,5,10))

  out <- list(order=x$gene, sector_width_deg=(360-gap-(n-1)*small_gap)/n,
    track_order=fields, numbering=track_no, radii=bounds, actual_visits=colSums(seen),
    tissue_scale=c(0,tissue_max), bar_heights=x$n_tissues, suppressor_labels=x$gene[x$TSG==1L],
    gray_labels=x$gene[gray==1L],
    group_counts=group_counts, clinical_cells=tabulate(x$druggable+1L,nbins=2),
    aging_positive=colSums(x[wheel_hallmarks]), cancer_bins=tabulate(x$n_cancer_hallmarks+1L,nbins=11))
  invisible(out)
}

if (sys.nframe()==0L) {
  args <- commandArgs(trailingOnly=TRUE)
  if (length(args)!=2L) stop("Usage: Rscript draw_wheel.R INPUT.csv NEW_OUTPUT.pdf")
  if (file.exists(args[2]) || !grepl("[.]pdf$",args[2],ignore.case=TRUE)) stop("Use a new PDF path")
  data <- prepare_wheel(read.csv(args[1],check.names=FALSE))
  grDevices::cairo_pdf(args[2],width=183/25.4,height=220/25.4,family="Arial",pointsize=7)
  tryCatch(draw_wheel(data),finally=grDevices::dev.off())
}
