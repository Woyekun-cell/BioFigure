#!/usr/bin/env Rscript
# FigureYa module data replay. Source examples and metadata are bound in work/2026-10-30-figureya-gap.
suppressPackageStartupMessages(library(ggplot2))
project <- normalizePath(getwd(), mustWork = TRUE)
work <- file.path(project, 'work', '2026-10-30-figureya-gap')
out_data <- file.path(project, 'results', 'plot_data')
dir.create(out_data, recursive = TRUE, showWarnings = FALSE)
font <- 'Arial'

shade <- function(hex, amount) {
  rgb <- grDevices::col2rgb(hex)[, 1] / 255
  if (amount > 0) rgb <- rgb + (1 - rgb) * amount else rgb <- rgb * (1 + amount)
  grDevices::rgb(rgb[1], rgb[2], rgb[3])
}

make_lego <- function() {
  raw <- read.csv(file.path(work, 'FigureYa168legoplot', 'very_easy_input.csv'))
  classes <- c('C>T', 'C>A', 'C>G', 'T>G', 'T>C', 'T>A')
  contexts <- c('T_T','C_T','A_T','G_T','T_C','C_C','A_C','G_C',
                'T_A','C_A','A_A','G_A','T_G','C_G','A_G','G_G')
  stopifnot(nrow(raw) == 40681L, all(raw$mut_type %in% classes), all(raw$mut_context %in% contexts))
  grid <- expand.grid(context = contexts, class = classes, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  tab <- as.data.frame(table(raw$mut_type, raw$mut_context), stringsAsFactors = FALSE)
  names(tab) <- c('class', 'context', 'count')
  grid <- merge(grid, tab, by = c('class', 'context'), sort = FALSE)
  grid$gx <- match(grid$context, contexts)
  grid$gy <- match(grid$class, classes)
  grid <- grid[order(-grid$gx - grid$gy, -grid$gy), ]
  stopifnot(nrow(grid) == 96L, sum(grid$count) == nrow(raw), !anyNA(grid$count))
  write.csv(grid[, c('class','context','count','gx','gy')], file.path(out_data, 'figureya_lego3d_20261030.csv'), row.names = FALSE)
  colors <- c('C>T'='#CF715D', 'C>A'='#4E84BA', 'C>G'='#67A88C',
              'T>G'='#E2B44F', 'T>C'='#8F7AB8', 'T>A'='#52AEB7')
  iso <- function(x,y,z) c(x * .72 - y * .68, x * .28 + y * .39 + z)
  faces <- vector('list', nrow(grid) * 3L); idx <- 1L
  for (i in seq_len(nrow(grid))) {
    row <- grid[i, ]; x0 <- row$gx - .47; x1 <- row$gx + .34
    y0 <- row$gy - .42; y1 <- row$gy + .36
    z <- row$count / 1446 * 2.55
    q <- function(x,y,h) iso(x,y,h)
    polys <- list(
      front = rbind(q(x0,y0,0), q(x1,y0,0), q(x1,y0,z), q(x0,y0,z)),
      side = rbind(q(x1,y0,0), q(x1,y1,0), q(x1,y1,z), q(x1,y0,z)),
      top = rbind(q(x0,y0,z), q(x1,y0,z), q(x1,y1,z), q(x0,y1,z)))
    for (f in names(polys)) {
      p <- as.data.frame(polys[[f]]); names(p) <- c('x','y')
      p$piece <- idx; p$fill <- shade(colors[[row$class]], switch(f, front=0, side=-.22, top=.32))
      faces[[idx]] <- p; idx <- idx + 1L
    }
  }
  poly <- do.call(rbind, faces)
  class_pos <- do.call(rbind, lapply(seq_along(classes), function(i) {
    p <- iso(.05, i, 0); data.frame(x=p[1]-1.1, y=p[2], label=classes[i], color=colors[i])
  }))
  context_pos <- do.call(rbind, lapply(seq_along(contexts), function(i) {
    p <- iso(i, .05, 0); data.frame(x=p[1], y=p[2]-.64, label=contexts[i])
  }))
  # Count ticks are anchored at a fixed front corner; their heights use raw counts.
  ticks <- data.frame(count=c(0,500,1000,1500))
  base <- c(12.1, -.3); ticks$x <- base[1] + .38; ticks$y <- base[2] + ticks$count / 1446 * 2.55
  p <- ggplot(poly, aes(x, y, group=piece, fill=fill)) +
    geom_polygon(color='#334155', linewidth=.09) + scale_fill_identity() +
    geom_text(data=class_pos, aes(x,y,label=label), inherit.aes=FALSE, hjust=1,
              size=2.7, family=font, color='#263643') +
    geom_text(data=context_pos, aes(x,y,label=label), inherit.aes=FALSE,
              size=2.0, angle=25, family=font, color='#465967') +
    geom_segment(data=data.frame(x=base[1], y=base[2], xend=base[1],
                                 yend=base[2]+1500/1446*2.55),
                 aes(x=x,y=y,xend=xend,yend=yend), inherit.aes=FALSE,
                 linewidth=.35, color='#64748B') +
    geom_text(data=ticks, aes(x=x,y=y,label=count), inherit.aes=FALSE,
              hjust=0, size=2.4, family=font, color='#475569') +
    annotate('text', x=base[1]-.55, y=base[2]+2.95, label='Mutation count',
             family=font, size=2.7, color='#263643', hjust=0) +
    coord_equal(clip='off') + theme_void(base_family=font, base_size=8) +
    theme(plot.margin=margin(10,18,10,35,'pt'))
  list(plot=p, data=grid, classes=classes, contexts=contexts)
}

make_ternary <- function() {
  stopifnot(requireNamespace('ggtern', quietly=TRUE))
  d <- read.csv(file.path(work,'FigureYa64triangle','easy_input.csv'), check.names=FALSE)
  stopifnot(nrow(d)==17L, all(d[,2:4] >= 0), !anyNA(d))
  d$dominant <- c('Secondary GBM','Primary GBM','Low-grade glioma')[max.col(d[,2:4], ties.method='first')]
  write.csv(d, file.path(out_data,'figureya_ternary_20261030.csv'), row.names=FALSE)
  cols <- c('Secondary GBM'='#CF715D','Primary GBM'='#8F65AD','Low-grade glioma'='#3F79B5')
  keep <- d$Gene %in% c('IDH1','TP53','ATRX','PTEN','MET Amplified')
  labels <- d[keep,]
  labels$h <- c('MET Amplified'=-.12, 'ATRX'=-.15, 'TP53'=-.15,
                'IDH1'=1.12, 'PTEN'=1.55)[labels$Gene]
  labels$v <- c('MET Amplified'=-.6, 'ATRX'=1.45, 'TP53'=-.65,
                'IDH1'=-.55, 'PTEN'=1.3)[labels$Gene]
  p <- ggtern::ggtern(d, aes(x=Frequency.in.pGBM, y=Frequency.in.LGG, z=Frequency.in.sGBM)) +
    geom_point(aes(size=allfrequency, fill=dominant), shape=21, color='#243548', stroke=.28, alpha=.88) +
    geom_text(data=labels, aes(label=Gene, hjust=h, vjust=v), position='identity', size=2.1,
              family=font, color='#263643', check_overlap=TRUE) +
    scale_fill_manual(values=cols, name='Highest frequency') +
    scale_size_continuous(range=c(2.2,7), breaks=c(2,5,8), name='FigureYa size score') +
    ggtern::theme_rgbw() +
    labs(x='pGBM', y='LGG', z='sGBM') +
    theme(text=element_text(family=font, size=8, color='#243548'),
          tern.panel.grid.major=element_line(color='#D6DFE7', linewidth=.35),
          legend.position='bottom', legend.box='vertical',
          plot.margin=margin(11,25,8,25,'pt'))
  list(plot=p, data=d)
}

make_circvenn <- function() {
  raw <- read.csv(file.path(work,'FigureYa237circVenn','easy_input.csv'), check.names=FALSE,
                  na.strings=c('','NA'))
  counts <- colSums(!is.na(raw))
  d <- data.frame(region=names(counts), count=as.integer(counts), stringsAsFactors=FALSE)
  d$ring <- nchar(d$region)
  d <- d[order(-d$ring, match(d$region, names(counts))),]
  stopifnot(nrow(d)==63L, d$count[d$region=='ABCDEF']==32030L,
            sum(d$count)==52348L)
  d$display_fill <- pmin(d$count,1000)
  d$label <- paste0(d$region,'\n',d$count)
  d$ring <- factor(d$ring, levels=6:1)
  d$region <- factor(d$region, levels=d$region)
  write.csv(d[,c('region','count','ring','display_fill')],
            file.path(out_data,'figureya_circvenn_20261030.csv'), row.names=FALSE)
  p <- ggplot(d, aes(x=ring,y=1,fill=display_fill)) +
    geom_col(width=1,position='fill',color='#30434B',linewidth=.24) +
    geom_text(aes(label=label), position=position_fill(vjust=.5),
              family=font, size=2.25, lineheight=.88, color='#14313A') +
    coord_polar(theta='y', direction=-1, clip='off') +
    scale_x_discrete(expand=c(0,0)) +
    scale_fill_gradient(low='#F3FAF7', high='#0A867A', guide='none') +
    theme_void(base_family=font,base_size=8) +
    theme(plot.margin=margin(7,7,7,7,'pt'))
  list(plot=p,data=d)
}

case <- commandArgs(trailingOnly=TRUE)[1]
mode <- commandArgs(trailingOnly=TRUE)[2]
if (is.na(case) || !case %in% c('lego','ternary','circvenn')) stop('case must be lego, ternary, circvenn')
if (is.na(mode)) mode <- 'explore'
obj <- switch(case, lego=make_lego(), ternary=make_ternary(), circvenn=make_circvenn())
if (mode == 'grobtest') {
  captured <- grid::grid.grabExpr(print(obj$plot))
  wrapped <- ggplotify::as.ggplot(captured)
  ggsave(file.path(work,case,'grobtest.png'),wrapped,width=183,height=155,units='mm',dpi=220,bg='white')
} else if (mode == 'labels') {
  seen <- character()
  visit <- function(g) {
    if (inherits(g,'text') && length(g$label)) seen <<- c(seen,as.character(g$label))
    if (length(g$grobs)) for (child in g$grobs) visit(child)
    if (length(g$children)) for (child in g$children) visit(child)
  }
  visit(ggplotGrob(obj$plot))
  writeLines(jsonlite::toJSON(unique(seen[nzchar(seen)]),auto_unbox=FALSE,pretty=TRUE),
             file.path(work,case,'allowed-text.json'))
} else if (mode == 'explore') {
  sizes <- list(lego=c(183,95), ternary=c(183,155), circvenn=c(183,183))
  size <- sizes[[case]]
  ggsave(file.path(work,case,'exploratory.png'), obj$plot,
         width=size[1],height=size[2],units='mm',dpi=220,bg='white')
} else if (mode == 'formal') {
  skill <- file.path(project,'biofigure')
  source(file.path(skill,'scripts','figure_style.R'))
  face <- bf_font(font)
  .bf_pdf_font_faces(face)
  # ggtern's print method adds the ternary grid; capture it as vector grobs so
  # BioFigure's ggplot2 preflight and the PDF device inspect the same object.
  if (case == 'ternary') obj$plot <- ggplotify::as.ggplot(grid::grid.grabExpr(print(obj$plot)))
  spec_path <- file.path(work,case,'design-spec.yaml')
  spec <- yaml::read_yaml(spec_path)
  source_dir <- switch(case,lego='FigureYa168legoplot',
                       ternary='FigureYa64triangle',circvenn='FigureYa237circVenn')
  input_name <- switch(case,lego='very_easy_input.csv',ternary='easy_input.csv',circvenn='easy_input.csv')
  pdf_name <- switch(case,lego='test_legoplot.pdf',ternary='triangle_directlabels.pdf',
                     circvenn='Circled_Venn_diagram_ori.pdf')
  sources <- c(file.path(project,'scripts','figureya_gap_20261030.R'),
               file.path(skill,'scripts','figure_style.R'),spec_path,
               file.path(work,source_dir,input_name),
               file.path(work,source_dir,pdf_name),
               file.path(work,source_dir,paste0(source_dir,'.Rmd')))
  width <- spec$output_size$width_mm; height <- spec$output_size$height_mm
  boxes <- data.frame(id=c('data','labels','legend'),
                      x=c(5,0,width-25),y=c(5,0,0),
                      w=c(width-30,width,25),h=c(height-10,height,height))
  file_stem <- switch(case,lego='figureya_lego3d_20261030',
                      ternary='figureya_ternary_20261030',
                      circvenn='figureya_circvenn_20261030')
  dir.create(file.path(project,'results','figures'),recursive=TRUE,showWarnings=FALSE)
  out <- file.path(project,'results','figures',file_stem)
  auth <- commandArgs(trailingOnly=TRUE)[3]
  if (is.na(auth) || !file.exists(auth)) stop('current render authorization path required')
  bf_render_png(obj$plot,paste0(out,'.png'),face,unlist(spec$text_contract$allowed_text),
                width,height,width,sources,boxes,
                allowed_pairs=c('data:labels','data:legend','labels:legend'),
                dpi=360,min_text_pt=5.5,
                text_size_authorization='Dense source labels and user-requested complex chart; final PDF text is reviewed at 183 mm width.',
                authorization=auth,skill_root=skill,
                publication_size_class=spec$output_size$size_class,
                size_override_basis=spec$output_size$size_rationale$override_basis)
  bf_pdf_open(paste0(out,'.pdf'),width,height,face)
  print(obj$plot)
  grDevices::dev.off()
  audit <- bf_pdf_finalize(paste0(out,'.pdf'),face,width,height)
  jsonlite::write_json(audit,file.path(work,case,'pdf-technical-audit.json'),
                       auto_unbox=TRUE,pretty=TRUE,digits=NA)
  capture.output(sessionInfo(),file=file.path(work,case,'render-sessionInfo.txt'))
  cat(case,'formal render completed; visual inspection pending\n')
} else stop('unknown mode')
