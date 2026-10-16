#!/usr/bin/env Rscript
# SPDX-License-Identifier: MIT
# Read-only by default. Install only into an explicitly selected library.
args <- commandArgs(trailingOnly=TRUE)
install <- '--install' %in% args
value_after <- function(flag, default=NULL) {
  i <- match(flag,args)
  if(is.na(i))return(default)
  if(i==length(args) || startsWith(args[i+1L],'--'))stop(paste(flag,'requires a value'))
  args[i+1L]
}
target_library <- value_after('--library')
target_font <- value_after('--font','Arial')
formats <- strsplit(value_after('--formats','png,pdf'),',',fixed=TRUE)[[1]]
if(!length(formats) || !all(formats %in% c('png','pdf')))stop('--formats must be png, pdf or png,pdf')
if(!target_font %in% c('Arial','Helvetica'))stop('--font must be Arial or Helvetica')
if(install && is.null(target_library))stop('--install requires an explicit --library directory; no global library is modified')
if(!is.null(target_library) && dir.exists(target_library))
  .libPaths(c(normalizePath(target_library,mustWork=TRUE),.libPaths()))
cran <- c('ggplot2','ragg','systemfonts','jsonlite','yaml','digest','circlize',
          'ape','ggrepel','scales','stringi')
bioc <- 'ComplexHeatmap'
required <- c(cran,bioc)
present <- function(package)requireNamespace(package,quietly=TRUE)
if(install) {
  dir.create(target_library,recursive=TRUE,showWarnings=FALSE)
  target_library <- normalizePath(target_library,mustWork=TRUE)
  .libPaths(c(target_library,.libPaths()))
  missing_cran <- cran[!vapply(cran,present,logical(1))]
  if(length(missing_cran))utils::install.packages(missing_cran,lib=target_library,repos='https://cloud.r-project.org')
  if(!present(bioc)) {
    if(!present('BiocManager'))utils::install.packages('BiocManager',lib=target_library,repos='https://cloud.r-project.org')
    BiocManager::install(bioc,lib=target_library,ask=FALSE,update=FALSE)
  }
}
found <- vapply(required,present,logical(1))
font_found <- NA
if(present('systemfonts')) {
  fonts <- systemfonts::system_fonts()
  font_found <- any(tolower(fonts$family)==tolower(target_font))
}
gs <- Sys.which('gs')
needs_gs <- 'pdf' %in% formats
status <- if(!all(found))'NEEDS_DEPENDENCIES' else if(!isTRUE(font_found))'NEEDS_FONT' else if(needs_gs && !nzchar(gs))'NEEDS_GHOSTSCRIPT' else 'READY'
report <- list(schema_version=1,status=status,operation=if(install)'explicit-install' else 'read-only-check',
               R_version=as.character(getRversion()),target_font=target_font,target_font_present=font_found,
               formats=formats,ghostscript=list(required=needs_gs,available=nzchar(gs),
                   path=if(nzchar(gs))unname(gs)else NULL,
                   purpose='Embed the exact Arial/Helvetica fonts in PDF; PNG-only does not require Ghostscript. It is never installed by this script.'),
               missing_packages=unname(required[!found]),
               packages=lapply(required,function(p)list(name=p,present=present(p),
                   version=if(present(p))as.character(utils::packageVersion(p))else NULL)),
               library_paths=.libPaths(),
               scope='Dependencies and exact font family only; no scientific analysis, renderer execution or visual PASS.')
if(present('jsonlite')) {
  cat(jsonlite::toJSON(report,auto_unbox=TRUE,pretty=TRUE,null='null'), '\n')
} else {
  # Keep the missing-dependency result machine readable before jsonlite exists.
  cat('{"schema_version":1,"status":"NEEDS_DEPENDENCIES","operation":"read-only-check","missing_packages":[',
      paste(paste0('"',required[!found],'"'),collapse=','),'],"target_font":"',target_font,
      '","scope":"No renderer execution; install dependencies explicitly."}\n',sep='')
}
quit(status=if(status=='READY')0L else 2L)
