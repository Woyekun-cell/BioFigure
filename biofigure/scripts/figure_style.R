# BioFigure reusable safeguards. Source into the analysis script; no global theme changes.
bf_skill_root <- local({
  source_file <- tryCatch(sys.frame(1)$ofile, error=function(e) NULL)
  if(is.null(source_file)) normalizePath(getwd()) else normalizePath(file.path(dirname(source_file),'..'))
})
bf_resolve_skill_root <- function(skill_root=NULL) {
  valid<-function(path) is.character(path)&&length(path)==1&&nzchar(path)&&
    file.exists(file.path(path,'static','core','execution-contract.yaml'))&&
    file.exists(file.path(path,'scripts','authorize_render.py'))&&
    file.exists(file.path(path,'scripts','figure_style.R'))
  if(!is.null(skill_root)) {
    if(valid(skill_root)) return(normalizePath(skill_root,mustWork=TRUE))
    stop('BIOFIGURE_SKILL_ROOT must point to an installed BioFigure Skill root')
  }
  configured<-Sys.getenv('BIOFIGURE_SKILL_ROOT',unset='')
  if(nzchar(configured)) {
    if(valid(configured)) return(normalizePath(configured,mustWork=TRUE))
    stop('BIOFIGURE_SKILL_ROOT must point to an installed BioFigure Skill root')
  }
  if(valid(bf_skill_root)) return(normalizePath(bf_skill_root,mustWork=TRUE))
  stop('set BIOFIGURE_SKILL_ROOT or pass skill_root to the installed BioFigure Skill root')
}
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
bf_validate_publication_size <- function(width_mm,height_mm,size_class='single-column',size_override_basis=NULL) {
  if(!is.numeric(width_mm)||length(width_mm)!=1||!is.finite(width_mm)||width_mm<=0||
     !is.numeric(height_mm)||length(height_mm)!=1||!is.finite(height_mm)||height_mm<=0)
    stop('final publication width and height must be positive finite millimetres')
  ranges<-list(
    'single-column'=c(89,90,170),
    'one-and-half-column'=c(120,136,170),
    'double-column'=c(180,183,170),
    'custom'=c(50,210,247))
  if(!size_class %in% names(ranges)) stop('unsupported publication size class')
  rule<-ranges[[size_class]]
  if(width_mm<rule[1]||width_mm>rule[2])
    stop(sprintf('%s width must be %g..%g mm',size_class,rule[1],rule[2]))
  if(height_mm>rule[3]) stop(sprintf('%s height exceeds %g mm',size_class,rule[3]))
  if(size_class=='custom' && (is.null(size_override_basis)||!is.character(size_override_basis)||
      length(size_override_basis)!=1||!nzchar(trimws(size_override_basis))))
    stop('custom publication size requires a documented journal or user basis')
  TRUE
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
# Role-specific starting values, not journal mandates or global geom defaults.
bf_mark_style <- function(role) {
  styles <- list(
    'replicate-point'=list(shape=21,fill_alpha=.70,edge_alpha=1,colour='#30343B',stroke=.25,size=2),
    'hollow-point'=list(shape=21,fill_alpha=0,edge_alpha=1,colour='#30343B',stroke=.25,size=2),
    'dense-point'=list(shape=16,alpha=.30,size=.65,stroke=0),
    'individual-line'=list(alpha=.25,linewidth=.25),
    'summary-line'=list(alpha=1,linewidth=.60),
    'uncertainty-band'=list(alpha=.18,colour=NA_character_),
    'distribution-fill'=list(fill_alpha=.32,edge_alpha=1,linewidth=.30),
    'continuous-bubble'=list(shape=21,fill_alpha=1,edge_alpha=1,colour='#1A1A1A',stroke=.25),
    'bar-fill'=list(fill_alpha=.82,edge_alpha=1,colour='#30343B',linewidth=.35))
  if(!is.character(role)||length(role)!=1||is.na(role)||!role %in% names(styles))
    stop('unknown mark role')
  styles[[role]]
}
bf_fill_alpha <- function(colour,alpha) {
  if(!is.numeric(alpha)||length(alpha)!=1||!is.finite(alpha)||alpha<0||alpha>1)
    stop('alpha must be one finite number in [0,1]')
  # Apply to fill only; leave geom alpha=NA so edges retain their own alpha.
  scales::alpha(colour,alpha)
}
bf_check_mark_layers <- function(plot,contracts) {
  if(!is.list(contracts)||!length(contracts)) stop('mark contracts must be a non-empty list')
  built <- ggplot2::ggplot_build(plot)
  unsupported <- c('GeomSmooth','GeomPointrange','GeomCrossbar','GeomPolygon','GeomSf','GeomHex')
  for(layer in plot$layers) if(any(vapply(unsupported,function(type) inherits(layer$geom,type),logical(1))))
    stop('unsupported compound mark geometry; split point/line/band layers or use a specialist renderer audit')
  indexes <- vapply(contracts,function(x) {
    allowed <- c('layer','role','fill_alpha','edge_alpha','alpha','override_reason')
    if(is.list(x)&&length(setdiff(names(x),allowed))) stop('unknown mark field')
    if(!is.list(x)||!is.numeric(x$layer)||length(x$layer)!=1||!is.finite(x$layer)||
       x$layer<1||x$layer!=as.integer(x$layer)||x$layer>length(plot$layers))
      stop('invalid mark layer index')
    as.integer(x$layer)
  },integer(1))
  if(anyDuplicated(indexes)) stop('duplicate mark layer index')
  mark_geoms <- c('GeomPoint','GeomLine','GeomPath','GeomSegment','GeomCurve','GeomRibbon','GeomViolin','GeomBoxplot','GeomDensity','GeomBar','GeomCol')
  eligible <- which(vapply(plot$layers,function(layer)
    any(vapply(mark_geoms,function(type) inherits(layer$geom,type),logical(1))),logical(1)))
  if(length(setdiff(eligible,indexes))) stop('mark contract must cover all point, line and fill data layers')
  opacity <- function(colour,alpha) {
    result <- ifelse(is.na(colour),0,as.numeric(grDevices::col2rgb(colour,alpha=TRUE)[4,])/255)
    # ggplot2 replaces color alpha when layer alpha is explicit; NA preserves it.
    if(length(alpha)) result[!is.na(alpha)] <- alpha[!is.na(alpha)]
    result[is.na(colour)] <- 0
    result
  }
  for(i in seq_along(contracts)) {
    entry <- contracts[[i]]; role <- entry$role; bf_mark_style(role)
    geom <- plot$layers[[indexes[i]]]$geom; d <- built$data[[indexes[i]]]
    point_roles <- c('replicate-point','hollow-point','dense-point','continuous-bubble')
    geometry_ok <- if(role %in% point_roles) inherits(geom,'GeomPoint') else
      if(role %in% c('individual-line','summary-line')) inherits(geom,'GeomLine')||inherits(geom,'GeomPath')||inherits(geom,'GeomSegment')||inherits(geom,'GeomCurve') else
      if(role=='uncertainty-band') inherits(geom,'GeomRibbon') else
      if(role=='bar-fill') inherits(geom,'GeomBar')||inherits(geom,'GeomCol') else
      inherits(geom,'GeomViolin')||inherits(geom,'GeomBoxplot')||inherits(geom,'GeomDensity')
    if(!geometry_ok) stop(paste('mark role geometry mismatch:',role))
    if(inherits(geom,'GeomBoxplot')) {
      params <- plot$layers[[indexes[i]]]$geom_params
      for(part in c('box_gp','median_gp','whisker_gp','staple_gp')) {
        gp <- params[[part]]
        if(!is.null(gp$colour)||!is.null(gp$alpha)||(!is.null(gp$linewidth)&&any(gp$linewidth<=0)))
          stop('boxplot sub-mark overrides require a specialist grob audit')
      }
    }
    if(!nrow(d)) next
    override <- is.character(entry$override_reason)&&length(entry$override_reason)==1&&
      !is.na(entry$override_reason)&&nzchar(trimws(entry$override_reason))
    if(any(!is.na(d$alpha)&(!is.finite(d$alpha)|d$alpha<0|d$alpha>1))) stop('invalid rendered alpha')
    fill <- if('fill' %in% names(d)) opacity(d$fill,d$alpha) else rep(0,nrow(d))
    edge <- if('colour' %in% names(d)) opacity(d$colour,d$alpha) else rep(0,nrow(d))
    visible <- if(role %in% point_roles) ifelse(d$shape %in% 21:25,pmax(fill,edge),edge) else
      if(role %in% c('individual-line','summary-line')) edge else pmax(fill,edge)
    if(any(visible<=0)) stop('invisible data marks cannot be authorized by an aesthetic override')
    for(key in c('fill_alpha','edge_alpha','alpha')) if(!is.null(entry[[key]])) {
      expected <- entry[[key]]
      if(!is.numeric(expected)||length(expected)!=1||!is.finite(expected)||expected<0||expected>1)
        stop('declared mark alpha must be finite and in [0,1]')
      observed <- if(key=='fill_alpha') fill else if(key=='edge_alpha') edge else d$alpha
      if(!length(observed)||anyNA(observed)||any(abs(observed-expected)>.004))
        stop(paste('rendered mark alpha differs from contract:',key))
    }
    fail <- function(message) if(!override) stop(paste0(role,': ',message),call.=FALSE)
    if(role %in% c('replicate-point','hollow-point','continuous-bubble')) {
      if(any(!d$shape %in% 21:25)) fail('use a fillable outlined point')
      if(any(edge<.9)) fail('edge opacity must remain >=0.9')
      if(any(d$stroke<.15|d$stroke>.35)) fail('thin outline stroke must be 0.15..0.35')
    }
    if(role=='replicate-point'&&any(fill<.55|fill>.85)) fail('fill opacity must be 0.55..0.85')
    if(role=='hollow-point'&&any(fill>.004)) fail('hollow fill must remain absent')
    if(role=='dense-point') {
      point_alpha <- ifelse(d$shape %in% 21:25,fill,edge)
      if(any(point_alpha<.12|point_alpha>.55)) fail('point opacity must be 0.12..0.55')
      if(any(d$shape %in% 21:25 & d$stroke>0)) fail('dense points need no outline or a documented exception')
    }
    if(role=='continuous-bubble'&&any(abs(fill-1)>.004))
      stop('continuous fill opacity must remain 1; a boolean declaration cannot certify the actual colorbar',call.=FALSE)
    if(role=='individual-line'&&any(edge<.15|edge>.45)) fail('line opacity must be 0.15..0.45')
    if(role=='summary-line'&&any(edge<.9)) fail('line opacity must remain >=0.9')
    if(role=='uncertainty-band'&&any(fill<.10|fill>.25)) fail('band opacity must be 0.10..0.25')
    if(role=='distribution-fill'&&any(fill<.20|fill>.50)) fail('fill opacity must be 0.20..0.50')
    if(role=='bar-fill'&&any(fill<.65|fill>.90)) fail('fill opacity must be 0.65..0.90')
    if(role %in% c('distribution-fill','bar-fill')&&any(edge<.9)) fail('edge opacity must remain >=0.9')
  }
  TRUE
}
bf_square_body <- function(nrow,ncol,cell_mm,row_gaps_mm=0,column_gaps_mm=0) {
  stopifnot(nrow>0,ncol>0,cell_mm>0,all(row_gaps_mm>=0),all(column_gaps_mm>=0))
  # Supply one gap for each actual boundary, not a single gap for all boundaries.
  list(width_mm=ncol*cell_mm+sum(column_gaps_mm),height_mm=nrow*cell_mm+sum(row_gaps_mm))
}
bf_assert_cell_metrics <- function(metrics,cell_mode='square',tolerance=.01) {
  if(!cell_mode %in% c('square','dense-overview')) stop('unknown heatmap cell geometry mode')
  if(!is.numeric(tolerance)||length(tolerance)!=1||!is.finite(tolerance)||tolerance<=0||tolerance>.01)
    stop('square cell tolerance must be positive and <=0.01')
  if(!length(metrics)) stop('heatmap needs actual square/dense cell measurements')
  for(x in metrics) {
    sizes<-unlist(x[c('body_width_mm','body_height_mm','cell_width_mm','cell_height_mm')])
    if(length(sizes)!=4||any(!is.finite(sizes)|sizes<=0)) stop('invalid physical heatmap cell sizes')
    if(cell_mode=='dense-overview') {
      if(max(x$matrix_rows,x$matrix_columns)<=200)
        stop('small displayed heatmap requires square cells; dense-overview cannot exempt it')
    } else if(abs(x$cell_width_mm/x$cell_height_mm-1)>tolerance+1e-9)
      stop(sprintf('heatmap cells are not physically square: %.5f x %.5f mm in %s',
        x$cell_width_mm,x$cell_height_mm,x$panel_id))
  }
  invisible(TRUE)
}
bf_ggplot_cell_plan <- function(plot,built,heatmap_required=FALSE,annotation_layers=list()) {
  types<-c('GeomTile','GeomRaster',if(heatmap_required)'GeomRect')
  indexes<-which(vapply(plot$layers,function(l)any(vapply(types,function(z)inherits(l$geom,z),logical(1))),logical(1)))
  if(!length(indexes)) {
    if(heatmap_required) stop('heatmap square-cell audit needs a supported tile/raster/rect layer or native adapter')
    return(list())
  }
  if(!isTRUE(built$layout$coord$is_linear())) stop('square-cell heatmap audit requires rectangular coordinates; use a specialist geometry contract')
  annotation_ids<-vapply(annotation_layers,function(x) {
    if(!is.list(x)||!identical(x$role,'categorical-strip')||!is.numeric(x$layer)||
       length(x$layer)!=1||!is.finite(x$layer)||x$layer!=as.integer(x$layer)||!x$layer %in% indexes)
      stop('annotation tile exemption requires an explicit categorical-strip layer')
    as.integer(x$layer)
  },integer(1))
  if(anyDuplicated(annotation_ids)||!length(setdiff(indexes,annotation_ids)))
    stop('annotation strip declarations cannot remove the heatmap matrix')
  plan<-list()
  for(i in indexes) {
    all_data<-built$data[[i]]
    if(!nrow(all_data)) next
    center<-function(d,axis) if(axis %in% names(d)) d[[axis]] else (d[[paste0(axis,'min')]]+d[[paste0(axis,'max')]])/2
    for(panel in unique(all_data$PANEL)) {
      d<-all_data[all_data$PANEL==panel,,drop=FALSE]
      j<-match(as.character(panel),as.character(built$layout$layout$PANEL))
      z<-built$layout$coord$transform(d,built$layout$panel_params[[j]])
      if(!all(c('xmin','xmax','ymin','ymax') %in% names(z))) stop('square-cell audit lacks transformed cell bounds')
      if(!i %in% annotation_ids && any(z$xmin< -1e-7|z$xmax>1+1e-7|z$ymin< -1e-7|z$ymax>1+1e-7,na.rm=TRUE))
        stop('clipped heatmap cells cannot establish displayed counts; subset data explicitly and redesign the matrix')
      layout<-built$layout$layout[j,,drop=FALSE]
      # Facet gtable names encode column then row, not the panel sequence.
      name<-if(inherits(plot$facet,'FacetNull'))'panel' else paste0('panel-',layout$COL,'-',layout$ROW)
      flip<-inherits(built$layout$coord,'CoordFlip')
      plan[[length(plan)+1L]]<-list(panel_name=name,panel_id=paste0('layer-',i,'-panel-',panel),
        annotation=i %in% annotation_ids,
        rows=length(unique(center(d,if(flip)'x' else 'y'))),
        columns=length(unique(center(d,if(flip)'y' else 'x'))),
        matrix_rows=length(unique(center(d,if(flip)'x' else 'y'))),
        matrix_columns=length(unique(center(d,if(flip)'y' else 'x'))),
        widths=abs(z$xmax-z$xmin),heights=abs(z$ymax-z$ymin))
    }
  }
  plan
}
bf_measure_ggplot_cells <- function(plan,grob,cell_mode='square',tolerance=.01) {
  if(!length(plan)) return(list())
  grid::grid.force()
  result<-lapply(plan,function(x) {
    slot<-which(grob$layout$name==x$panel_name)
    if(length(slot)!=1) stop('square-cell audit cannot locate the final panel viewport')
    s<-grob$layout[slot,,drop=FALSE]
    vp<-paste0(s$name,'.',s$t,'-',s$l,'-',s$b,'-',s$r)
    grid::seekViewport(vp)
    w<-grid::convertWidth(grid::unit(1,'npc'),'mm',valueOnly=TRUE)
    h<-grid::convertHeight(grid::unit(1,'npc'),'mm',valueOnly=TRUE)
    grid::upViewport(0)
    cw<-x$widths*w; ch<-x$heights*h
    if(!length(cw)||length(cw)!=length(ch)||any(!is.finite(c(cw,ch)))||any(c(cw,ch)<=0))
      stop('invalid physical square-cell bounds')
    if(isTRUE(x$annotation)) {
      if(!x$rows %in% 1L&&!x$columns %in% 1L) stop('annotation exemption cannot cover a two-dimensional matrix')
      thickness<-if(x$rows==1L)max(ch) else max(cw)
      if(thickness>3) stop('categorical annotation strip exceeds 3 mm; cannot bypass square matrix cells')
      return(NULL)
    }
    if(cell_mode=='square'&&any(abs(cw/ch-1)>tolerance+1e-9))
      stop(sprintf('heatmap cells are not physically square in %s (first %.5f x %.5f mm)',x$panel_id,cw[1],ch[1]))
    # Uniform cells within a matrix slice; expansions and outer plot margins
    # never enter cell measurements. Native split gaps are handled per slice.
    if(any(abs(cw/cw[1]-1)>1e-6)||any(abs(ch/ch[1]-1)>1e-6))
      stop('nonuniform heatmap cell geometry needs a specialist adapter')
    list(panel_id=x$panel_id,matrix_id=x$panel_id,rows=x$rows,columns=x$columns,
      matrix_rows=x$matrix_rows,matrix_columns=x$matrix_columns,
      body_width_mm=cw[1]*x$columns,body_height_mm=ch[1]*x$rows,
      cell_width_mm=cw[1],cell_height_mm=ch[1],measurement_method='final_body_viewports_mm')
  })
  result<-Filter(Negate(is.null),result)
  bf_assert_cell_metrics(result,cell_mode,tolerance)
  result
}
bf_complexheatmap_cell_metrics <- function(drawn,heatmap_name,cell_mode='square',tolerance=.01) {
  if(grDevices::dev.cur()==1) stop('heatmap cell measurement requires the actual open final export device')
  # row_order()/column_order() are read from the drawn object, never raw data.
  ro<-ComplexHeatmap::row_order(drawn,name=heatmap_name)
  co<-ComplexHeatmap::column_order(drawn,name=heatmap_name)
  if(!is.list(ro)) ro<-list(ro)
  if(!is.list(co)) co<-list(co)
  result<-list()
  for(i in seq_along(ro)) for(j in seq_along(co)) {
    box<-new.env(parent=emptyenv())
    ComplexHeatmap::decorate_heatmap_body(heatmap_name,{
      box$w<-grid::convertWidth(grid::unit(1,'npc'),'mm',valueOnly=TRUE)
      box$h<-grid::convertHeight(grid::unit(1,'npc'),'mm',valueOnly=TRUE)
    },row_slice=i,column_slice=j,envir=environment())
    nr<-length(ro[[i]]); nc<-length(co[[j]])
    result[[length(result)+1L]]<-list(panel_id=paste0(heatmap_name,'-',i,'-',j),matrix_id=heatmap_name,rows=nr,columns=nc,
      matrix_rows=sum(lengths(ro)),matrix_columns=sum(lengths(co)),
      body_width_mm=box$w,body_height_mm=box$h,cell_width_mm=box$w/nc,cell_height_mm=box$h/nr,
      measurement_method='final_body_viewports_mm')
  }
  bf_assert_cell_metrics(result,cell_mode,tolerance)
  result
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
bf_assert_scientific_text <- function(text,location='figure text') {
  # This semantic guard is independent of the caller's text allowlist. Keep it
  # narrow: AI can be a gene/group ID, and synthetic/simulation can be study data.
  if(!length(text)) return(invisible(TRUE))
  if(!requireNamespace('stringi',quietly=TRUE)) stop('scientific text normalization requires stringi')
  original<-as.character(text)
  if(anyNA(original)) stop('non-scientific figure text: unresolved NA label')
  normalized<-stringi::stri_trans_nfkc(original)
  normalized<-gsub('[\u200B\u200C\u200D\uFEFF]','',normalized,perl=TRUE)
  normalized<-trimws(stringi::stri_replace_all_regex(normalized,'\\s+',' '))
  patterns<-c(
    '\\bn[[:space:]]*=[[:space:]]*[0-9]+\\b[^;\\n]{0,60}\\bper[[:space:]]+(?:group|condition|treatment)\\b',
    '\\bn[[:space:]]*=[[:space:]]*[0-9]+\\b[[:space:]]*[;,].*\\b(?:day|time|infection|treatment|replicates?)\\b',
    '^[[:space:]]*(?:notes?|footnotes?|caption|footer|备注|注释说明|图注|脚注)[[:space:]]*[:：]',
    '\\b(?:AI|ChatGPT|Codex)[[:space:]]+(?:insights?|notes?|remarks?|comments?)\\b',
    '\\b(?:generated|created|rendered|prepared)[[:space:]]+by[[:space:]]+(?:ChatGPT|OpenAI|Codex|(?:an?[[:space:]]+)?(?:AI|artificial[[:space:]]+intelligence))\\b',
    '\\b(?:generated[[:space:]]+(?:figure|plot|chart)|(?:AI|ChatGPT|Codex)[[:space:]]*[-–—]?[[:space:]]*generated[[:space:]]+(?:figure|plot|chart))\\b',
    '\\bCP[0-4][[:space:]]*[_:=–—-]?[[:space:]]*(?:PASS|FAIL|PENDING|BLOCKED|NOT[_[:space:]-]+VERIFIED)\\b',
    '\\bNOT[_[:space:]-]+VERIFIED\\b',
    '\\b(?:for[[:space:]]+(?:illustration|demonstration)[[:space:]]+only|descriptive[[:space:]]+only)\\b',
    '(?:AI|ChatGPT|Codex|人工智能)[[:space:]]*(?:的[[:space:]]*)?(?:备注|注释|点评|说明|提示|评语|见解)',
    '(?:自动|AI|人工智能)[[:space:]]*生成(?:的)?[[:space:]]*(?:科研)?[[:space:]]*(?:图表|图形|绘图|图(?!像))',
    '(?:科研|研究|生物学)?结论[[:space:]]*未验证',
    '(?:仅|只)[[:space:]]*(?:作|做|供|用于|用作)[[:space:]]*(?:演示|示意|说明)',
    '配对[[:space:]]*(?:尚)?未(?:核(?:验|实)?|验证|确认)')
  rejected<-rep(FALSE,length(normalized))
  for(pattern in patterns) rejected<-rejected|grepl(pattern,normalized,perl=TRUE,ignore.case=TRUE)
  criteria <- gregexpr('\\b(?:FDR|padj|VIP|(?:log2)?FC|fold[ -]?change)[[:space:]]*(?:<=|>=|<|>|=|≤|≥)',
    normalized,perl=TRUE,ignore.case=TRUE)
  rejected <- rejected|vapply(criteria,function(x)sum(x>0)>=2,logical(1))
  if(any(rejected)) stop(paste0('non-scientific figure text or prohibited footer in ',location,': ',
    paste(unique(original[rejected]),collapse=' | ')),call.=FALSE)
  invisible(TRUE)
}
bf_assert_no_canvas_caption <- function(plot) {
  has_text <- function(x) !is.null(x)&&length(x)>0&&!inherits(x,'waiver')&&
    any(is.na(as.character(x))|nzchar(trimws(as.character(x))))
  if(has_text(plot$labels$caption)) stop('canvas caption/footer is forbidden; place the figure legend outside the exported figure')
  if(inherits(plot,'patchwork')) {
    if(has_text(plot$patches$annotation$caption)) stop('canvas caption/footer is forbidden, including patchwork plot_annotation')
    for(child in plot$patches$plots) bf_assert_no_canvas_caption(child)
  }
  invisible(TRUE)
}
bf_assert_no_footer_grob <- function(grob) {
  has_text <- function(x) {
    if(inherits(x,'text')&&length(x$label)&&any(nzchar(as.character(x$label)))) return(TRUE)
    any(vapply(c(x$grobs,as.list(x$children)),has_text,logical(1)))
  }
  footer_name <- function(x) length(x)&&!is.na(x)&&grepl('(^|[-_.])(caption|footer|footnote)([-_.]|$)',x,ignore.case=TRUE)
  visit <- function(x) {
    if(footer_name(x$name)&&has_text(x)) stop('canvas caption/footer grob is forbidden')
    if(inherits(x,'gtable')) for(i in seq_along(x$grobs)) {
      if(footer_name(x$layout$name[i])&&has_text(x$grobs[[i]])) stop('canvas caption/footer layout slot is forbidden')
    }
    if(length(x$grobs)) for(child in x$grobs) visit(child)
    if(length(x$children)) for(child in x$children) visit(child)
  }
  visit(grob)
  invisible(TRUE)
}
bf_assert_scientific_grob_text <- function(grob) {
  bf_assert_no_footer_grob(grob)
  visit<-function(x) {
    if(inherits(x,'text') && length(x$label)) {
      if(is.expression(x$label)) stop('math expression requires separate documented glyph audit')
      bf_assert_scientific_text(x$label,'actual grob text')
    }
    if(length(x$grobs)) for(child in x$grobs) visit(child)
    if(length(x$children)) for(child in x$children) visit(child)
  }
  visit(grob)
  invisible(TRUE)
}
bf_prepare <- function(plot,font,allowed_text,allow_headings=FALSE,width_mm=90,height_mm=75,dpi=300,
                       heatmap_required=FALSE,cell_mode='square',cell_tolerance=.01,annotation_layers=list()) {
  bf_assert_scientific_text(allowed_text,'allowed_text')
  bf_assert_no_canvas_caption(plot)
  if(inherits(plot,'patchwork')) stop('patchwork requires composed-grob preflight; the ggplot-only renderer cannot certify a partial assembly')
  measurement_file <- tempfile(fileext='.png')
  ragg::agg_png(measurement_file,width=width_mm,height=height_mm,units='mm',res=dpi,background='white')
  on.exit({grDevices::dev.off(); unlink(measurement_file)},add=TRUE)
  # Inspect the assembled object; theme(text=...) alone does not police geom_text.
  if(!allow_headings && any(vapply(c('title','subtitle','tag'),function(k)
      !is.null(plot$labels[[k]]) && length(plot$labels[[k]])>0,logical(1)))) stop('unrequested title/subtitle/tag')
  built<-withCallingHandlers(ggplot2::ggplot_build(plot),warning=function(w) stop(conditionMessage(w),call.=FALSE))
  cell_plan<-bf_ggplot_cell_plan(plot,built,heatmap_required,annotation_layers)
  for(d in built$data) if('label' %in% names(d) && nrow(d)>0) {
    if(!'family' %in% names(d) || any(is.na(d$family)|d$family!=font$family)) stop('text layer font must be explicit')
  }
  g<-withCallingHandlers(ggplot2::ggplot_gtable(built),warning=function(w) stop(conditionMessage(w),call.=FALSE))
  bf_assert_no_footer_grob(g)
  labels<-character(); families<-character(); sizes<-numeric()
  visit<-function(x,inherited=grid::gpar()) {
    gp<-inherited
    for(k in names(x$gp)) gp[[k]]<-x$gp[[k]]
    if(inherits(x,'text') && length(x$label)) {
      if(is.expression(x$label)) stop('math expression requires separate documented glyph audit')
      bf_assert_scientific_text(x$label,'actual grob text')
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
  cells<-list()
  if(length(cell_plan)) {
    withCallingHandlers(grid::grid.draw(g),warning=function(w)stop(conditionMessage(w),call.=FALSE))
    cells<-bf_measure_ggplot_cells(cell_plan,g,cell_mode,cell_tolerance)
  }
  list(grob=g,text=unique(labels),font=font,sizes_pt=unique(sizes),
    cell_plan=cell_plan,cell_mode=cell_mode,cell_tolerance=cell_tolerance,heatmap_cells=cells,
    device=list(width_mm=width_mm,height_mm=height_mm,dpi=dpi))
}
bf_export_png <- function(prepared,path,width_mm,height_mm,dpi=300,min_panel_mm=c(20,20)) {
  bf_assert_scientific_text(prepared$text,'prepared text')
  bf_assert_scientific_grob_text(prepared$grob)
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
  cells<-bf_measure_ggplot_cells(prepared$cell_plan,g,prepared$cell_mode,prepared$cell_tolerance)
  completed <- TRUE
  invisible(list(text=prepared$text,font=prepared$font,sizes_pt=prepared$sizes_pt,
      heatmap_cells=cells,width_mm=width_mm,height_mm=height_mm,remaining_panel_mm=c(width_mm-used_w,height_mm-used_h)))
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

# One call prepares and exports the same object, then binds the result to its inputs.
# Receipts are technical evidence; they do not certify aesthetics or actual viewing.
bf_render_png <- function(plot,path,font,allowed_text,width_mm,height_mm,target_width_mm,
                          source_files,boxes,allowed_pairs=character(),dpi=300,
                          heading_authorization=NULL,min_text_pt=6,text_size_authorization=NULL,
                          authorization=NULL,skill_root=NULL,
                          publication_size_class='single-column',size_override_basis=NULL) {
  if(is.null(authorization)||!is.character(authorization)||length(authorization)!=1||!file.exists(authorization))
    stop('current single-use render authorization is required')
  resolved_skill_root<-bf_resolve_skill_root(skill_root)
  spec_files<-source_files[grepl('\\.ya?ml$',source_files,ignore.case=TRUE)]
  if(length(spec_files)!=1) stop('bind exactly one current Design Spec for render authorization')
  auth_script<-file.path(resolved_skill_root,'scripts','authorize_render.py')
  py<-Sys.getenv('PYTHON','python3')
  auth_args<-c(auth_script,'--design-spec',spec_files,'--output',authorization,'--consume',
    unlist(lapply(source_files[source_files!=spec_files],function(x)c('--source',x))))
  auth_status<-suppressWarnings(system2(py,shQuote(auth_args),stdout=FALSE,stderr=FALSE))
  if(!identical(auth_status,0L)) stop('render authorization rejected or already consumed')
  receipt_path<-paste0(path,'.render.json')
  if(file.exists(receipt_path)) unlink(receipt_path)
  design<-yaml::read_yaml(spec_files[[1]])
  if(!is.null(design$text_contract$footer_policy)&&!identical(design$text_contract$footer_policy,'outside-only'))
    stop('canvas caption/footer policy must be outside-only')
  for(key in c('allow_caption','allow_footer','allow_footnotes'))
    if(!is.null(design$text_contract[[key]])&&!identical(design$text_contract[[key]],FALSE))
      stop('canvas caption/footer cannot be enabled by the text contract')
  # New mark contracts are opt-in for archived specs; new point/line tasks
  # declare them during design. Historical exports keep their original scope.
  if(!is.null(design$mark_style_contract$layers))
    bf_check_mark_layers(plot,design$mark_style_contract$layers)
  declared_text<-unlist(design$text_contract$allowed_text,use.names=FALSE)
  if(!setequal(allowed_text,declared_text))
    stop('allowed_text differs from authorized Design Spec text_contract')
  stopifnot(length(source_files)>0,all(file.exists(source_files)),
            is.finite(target_width_mm),target_width_mm>0,min_text_pt>=5,
            all(c('data','labels','legend') %in% boxes$id))
  if(!any(basename(source_files)=='figure_style.R') ||
     !any(grepl('\\.[Rr]$',source_files) & basename(source_files)!='figure_style.R') ||
     !any(grepl('\\.ya?ml$',source_files))) stop('bind plot.R, figure_style.R and design-spec.yaml in source_files')
  if(min_text_pt<6 && (is.null(text_size_authorization)||!is.character(text_size_authorization)||
      length(text_size_authorization)!=1||!nzchar(trimws(text_size_authorization)))) stop('text below 6 pt requires documented journal/user basis')
  bf_check_boxes(boxes,width_mm,height_mm,allowed_pairs)
  allow_headings<-!is.null(heading_authorization) && is.character(heading_authorization) &&
    length(heading_authorization)==1 && nzchar(trimws(heading_authorization))
  cells_contract<-design$heatmap_cell_contract
  cell_mode<-if(is.null(cells_contract))'square' else cells_contract$shape
  cell_tolerance<-if(is.null(cells_contract)) .01 else cells_contract$max_relative_error
  prepared<-bf_prepare(plot,font,allowed_text,allow_headings,width_mm,height_mm,dpi,
    heatmap_required=!is.null(cells_contract),cell_mode=cell_mode,cell_tolerance=cell_tolerance,
    annotation_layers=if(is.null(cells_contract$annotation_layers))list() else cells_contract$annotation_layers)
  target_height_mm<-height_mm*target_width_mm/width_mm
  bf_validate_publication_size(target_width_mm,target_height_mm,publication_size_class,size_override_basis)
  minimum<-min(prepared$sizes_pt)*target_width_mm/width_mm
  if(!is.finite(minimum)||minimum<min_text_pt) stop('text too small at final target width; redesign canvas and cells')
  declared<-design$output_size
  if(!is.list(declared)||!isTRUE(all.equal(as.numeric(declared$width_mm),as.numeric(target_width_mm)))||
     !isTRUE(all.equal(as.numeric(declared$height_mm),as.numeric(target_height_mm)))||
     !identical(declared$size_class,publication_size_class)||
     !identical(declared$size_basis,'final_physical_output'))
    stop('final target size differs from the authorized Design Spec')
  bound<-function(p) list(path=normalizePath(p,mustWork=TRUE),sha256=digest::digest(file=p,algo='sha256'))
  sources<-lapply(source_files,bound)
  exported<-bf_export_png(prepared,path,width_mm,height_mm,dpi)
  if(length(exported$heatmap_cells)) exported$heatmap_cells<-lapply(exported$heatmap_cells,function(x) {
    for(k in c('body_width_mm','body_height_mm','cell_width_mm','cell_height_mm'))
      x[[k]]<-x[[k]]*target_width_mm/width_mm
    x
  })
  if(!identical(sources,lapply(source_files,bound))) stop('source changed during rendering')
  auth_doc<-jsonlite::fromJSON(authorization,simplifyVector=FALSE)
  consumed_marker<-paste0(authorization,'.consumed')
  if(!file.exists(consumed_marker)||trimws(readLines(consumed_marker,warn=FALSE)[1])!=auth_doc$authorization_id)
    stop('render authorization consumption record missing')
  receipt<-list(schema_version=1,status='PASS',backend='R',renderer='ggplot2',artifact=bound(path),sources=sources,
    authorization_consumption=list(consumed=TRUE,authorization_id=auth_doc$authorization_id,
      marker=bound(consumed_marker),authorization_file=bound(authorization),
      preparation_receipt=auth_doc$bound$receipt),
    font=c(bound(font$path),list(family=font$family)),
    checks=list(font=TRUE,text_allowlist=TRUE,scientific_text_only=TRUE,footer_free=TRUE,layout=TRUE,target_size=TRUE,
      cell_geometry=length(exported$heatmap_cells)>0),
    heatmap_cells=exported$heatmap_cells,heatmap_cell_policy_id='heatmap-cells-v1',
    rendered_text=unname(as.list(prepared$text)),text_policy_id='scientific-content-only-v1',
    footer_policy_id='no-canvas-footer-v1',
    target_min_text_pt=minimum,min_text_pt=min_text_pt,text_size_authorization=text_size_authorization,target_width_mm=target_width_mm,
    target_size=list(width_mm=target_width_mm,height_mm=target_height_mm,
      size_class=publication_size_class,size_basis='final_physical_output',
      override_basis=size_override_basis),
    device=list(width_mm=width_mm,height_mm=height_mm,dpi=dpi),
    boxes=boxes,heading_authorization=heading_authorization,
    scope='technical preflight only; separate actual inspection and critics required')
  jsonlite::write_json(receipt,receipt_path,auto_unbox=TRUE,pretty=TRUE,digits=NA)
  invisible(receipt)
}
