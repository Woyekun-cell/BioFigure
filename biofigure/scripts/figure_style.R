# BioFigure reusable safeguards. Source into the analysis script; no global theme changes.
bf_font <- function(family='Arial') {
  if (!family %in% c('Arial','Helvetica')) stop('font must be Arial or Helvetica; document scientific glyph exceptions separately')
  fonts <- systemfonts::system_fonts()
  if (!family %in% fonts$family) stop('requested font is not installed')
  resolved <- systemfonts::match_fonts(family)
  info <- systemfonts::font_info(path=resolved$path, index=resolved$index)
  if (info$family[1] != family || !file.exists(resolved$path[1])) stop('font fallback detected')
  systemfonts::string_width('Ag012',path=resolved$path[1],index=resolved$index[1],size=7)
  list(family=family,path=resolved$path[1],index=resolved$index[1])
}
bf_theme <- function(font, size=7) {
  ggplot2::theme_classic(base_size=size,base_family=font$family) +
    ggplot2::theme(text=ggplot2::element_text(family=font$family,colour='black',face='plain'),
      axis.text=ggplot2::element_text(size=size,colour='black'),
      axis.title=ggplot2::element_text(size=size),
      axis.line=ggplot2::element_line(linewidth=.3),
      axis.ticks=ggplot2::element_line(linewidth=.3),
      axis.ticks.length=grid::unit(1,'mm'),
      panel.background=ggplot2::element_rect(fill='white',colour=NA),
      plot.background=ggplot2::element_rect(fill='white',colour=NA),
      legend.background=ggplot2::element_rect(fill='white',colour=NA),
      legend.key=ggplot2::element_rect(fill='white',colour=NA),
      legend.position='right',legend.text=ggplot2::element_text(size=size),
      legend.title=ggplot2::element_text(size=size,face='plain'),
      legend.key.size=grid::unit(3,'mm'),
      strip.background=ggplot2::element_blank(),
      strip.text=ggplot2::element_text(size=size,face='plain'),
      plot.margin=ggplot2::margin(3,3,3,3,unit='mm'))
}
bf_square_body <- function(nrow,ncol,cell_mm,row_gaps_mm=0,column_gaps_mm=0) {
  stopifnot(nrow>0,ncol>0,cell_mm>0,all(row_gaps_mm>=0),all(column_gaps_mm>=0))
  # Supply one gap for each actual boundary, not a single gap for all boundaries.
  list(width_mm=ncol*cell_mm+sum(column_gaps_mm),height_mm=nrow*cell_mm+sum(row_gaps_mm))
}
bf_check_boxes <- function(boxes,width_mm,height_mm,allowed_pairs=character()) {
  stopifnot(all(c('id','x','y','w','h') %in% names(boxes)),!anyDuplicated(boxes$id))
  if (any(!is.finite(as.matrix(boxes[c('x','y','w','h')])))) stop('nonfinite layout')
  if (any(boxes$x<0|boxes$y<0|boxes$w<=0|boxes$h<=0|boxes$x+boxes$w>width_mm|boxes$y+boxes$h>height_mm)) stop('layout outside canvas')
  if(nrow(boxes)>1) for(i in seq_len(nrow(boxes)-1)) for(j in (i+1):nrow(boxes)) {
    a<-boxes[i,]; b<-boxes[j,]; key<-paste(sort(c(a$id,b$id)),collapse=':')
    if(min(a$x+a$w,b$x+b$w)>max(a$x,b$x) && min(a$y+a$h,b$y+b$h)>max(a$y,b$y) && !key %in% allowed_pairs) stop(paste('layout overlap',key))
  }
  TRUE
}
bf_prepare <- function(plot,font,allowed_text,allow_headings=FALSE,width_mm=90,height_mm=75,dpi=300) {
  measurement_file <- tempfile(fileext='.png')
  ragg::agg_png(measurement_file,width=width_mm,height=height_mm,units='mm',res=dpi,background='white')
  on.exit({grDevices::dev.off(); unlink(measurement_file)},add=TRUE)
  # Inspect the assembled object; theme(text=...) alone does not police geom_text.
  if(!allow_headings && any(vapply(c('title','subtitle','caption','tag'),function(k)
      !is.null(plot$labels[[k]]) && length(plot$labels[[k]])>0,logical(1)))) stop('unrequested title/subtitle/caption/tag')
  built<-withCallingHandlers(ggplot2::ggplot_build(plot),warning=function(w) stop(conditionMessage(w),call.=FALSE))
  for(d in built$data) if('label' %in% names(d) && nrow(d)>0) {
    if(!'family' %in% names(d) || any(is.na(d$family)|d$family!=font$family)) stop('text layer font must be explicit')
  }
  g<-withCallingHandlers(ggplot2::ggplot_gtable(built),warning=function(w) stop(conditionMessage(w),call.=FALSE))
  labels<-character(); families<-character(); sizes<-numeric()
  visit<-function(x,inherited=grid::gpar()) {
    gp<-inherited
    for(k in names(x$gp)) gp[[k]]<-x$gp[[k]]
    if(inherits(x,'text') && length(x$label)) {
      if(is.expression(x$label)) stop('math expression requires separate documented glyph audit')
      labels<<-c(labels,as.character(x$label))
      if(is.null(gp$fontfamily)||any(gp$fontfamily!=font$family)) stop('grob font mismatch or unresolved inheritance')
      families<<-c(families,gp$fontfamily); sizes<<-c(sizes,gp$fontsize)
    }
    if(length(x$grobs)) for(child in x$grobs) visit(child,gp)
    if(length(x$children)) for(child in x$children) visit(child,gp)
  }
  visit(g)
  unexpected<-setdiff(labels[nzchar(labels)],allowed_text)
  if(length(unexpected)) stop(paste('unapproved figure text:',paste(unexpected,collapse=' | ')))
  chars<-unique(unlist(strsplit(paste(labels,collapse=''),'',fixed=TRUE)))
  chars<-setdiff(chars,c('\n','\t','\r'))
  if(length(chars) && any(systemfonts::glyph_info(chars,path=font$path,index=font$index)$index==0)) stop('missing glyph in selected font')
  list(grob=g,text=unique(labels),font=font,sizes_pt=unique(sizes),device=list(width_mm=width_mm,height_mm=height_mm,dpi=dpi))
}
bf_export_png <- function(prepared,path,width_mm,height_mm,dpi=300,min_panel_mm=c(20,20)) {
  if(!identical(prepared$device,list(width_mm=width_mm,height_mm=height_mm,dpi=dpi))) stop('device changed after preflight; prepare again')
  completed <- FALSE
  ragg::agg_png(path,width=width_mm,height=height_mm,units='mm',res=dpi,background='white')
  on.exit({grDevices::dev.off(); if(!completed) unlink(path)},add=TRUE)
  g<-prepared$grob
  # Gtable null units are the available panel space; absolute units include real text/guide widths.
  used_w<-grid::convertWidth(sum(g$widths),'mm',valueOnly=TRUE)
  used_h<-grid::convertHeight(sum(g$heights),'mm',valueOnly=TRUE)
  if(width_mm-used_w<min_panel_mm[1] || height_mm-used_h<min_panel_mm[2]) stop('layout leaves insufficient panel space; reflow legend/labels or resize')
  withCallingHandlers(grid::grid.draw(g),warning=function(w) stop(conditionMessage(w),call.=FALSE))
  completed <- TRUE
  invisible(list(text=prepared$text,font=prepared$font,sizes_pt=prepared$sizes_pt,
      width_mm=width_mm,height_mm=height_mm,remaining_panel_mm=c(width_mm-used_w,height_mm-used_h)))
}
bf_label_angle <- function(labels,font,size_pt,pitch_mm,gap_mm=.5) {
  widths<-systemfonts::string_width(labels,path=font$path,index=font$index,size=size_pt,res=72)*25.4/72
  if(max(widths)+gap_mm<=pitch_mm) 0 else 90
}
bf_complexheatmap_font <- function(font) {
  # Some ComplexHeatmap versions measure anno_text on a temporary PDF device.
  # Register only the same face's bundled metrics; never alias Arial to Helvetica.
  ps_name<-systemfonts::font_info(path=font$path,index=font$index)$name[1]
  registered<-grDevices::pdfFonts()
  if(!font$family %in% names(registered)) {
    if(!ps_name %in% names(registered) || registered[[ps_name]]$family!=ps_name)
      stop('ComplexHeatmap PDF measurement metrics unavailable for exact font')
    do.call(grDevices::pdfFonts,setNames(list(registered[[ps_name]]),font$family))
  }
  if(grDevices::pdfFonts()[[font$family]]$family!=ps_name)
    stop('PDF measurement family differs from resolved PostScript font')
  invisible(font)
}
