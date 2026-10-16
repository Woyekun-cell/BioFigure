#!/usr/bin/env Rscript
# SPDX-License-Identifier: MIT
# Read-only by default. Explicit installs use only a selected non-system library.
args <- commandArgs(trailingOnly=TRUE)
install <- '--install' %in% args
value_after <- function(flag, default=NULL) {
  i <- match(flag,args)
  if(is.na(i))return(default)
  if(i==length(args) || startsWith(args[i+1L],'--'))stop(paste(flag,'requires a value'))
  args[i+1L]
}
profile <- value_after('--profile',value_after('--scope','portable'))
if(!profile %in% c('portable','all-public'))stop('--profile must be portable or all-public')
if(!is.null(value_after('--profile')) && !is.null(value_after('--scope')) &&
   value_after('--profile')!=value_after('--scope'))stop('--profile and --scope disagree')
target_library <- value_after('--library')
target_font <- value_after('--font','Arial')
formats <- strsplit(value_after('--formats','png,pdf'),',',fixed=TRUE)[[1]]
if(!length(formats) || !all(formats %in% c('png','pdf')))stop('--formats must be png, pdf or png,pdf')
if(!target_font %in% c('Arial','Helvetica'))stop('--font must be Arial or Helvetica')
if(install && is.null(target_library))stop('--install requires an explicit --library; no global library is modified')
if(install && '--check' %in% args)stop('choose --check or --install')
if(!is.null(target_library) && dir.exists(target_library))
  .libPaths(c(normalizePath(target_library,mustWork=TRUE),.libPaths()))
script_arg <- grep('^--file=',commandArgs(trailingOnly=FALSE),value=TRUE)
if(length(script_arg)!=1L)stop('invoke this saved script with Rscript')
skill <- dirname(dirname(normalizePath(sub('^--file=','',script_arg),mustWork=TRUE)))
runtime_lock <- utils::read.delim(file.path(skill,'static/core/public-runtime-versions.tsv'),
  colClasses='character',check.names=FALSE,stringsAsFactors=FALSE)
expected_R <- runtime_lock$version[runtime_lock$package=='R']
expected_bioc <- runtime_lock$version[runtime_lock$package=='Bioconductor']
package_lock <- runtime_lock[!runtime_lock$package %in% c('R','Bioconductor'),,drop=FALSE]
if(length(expected_R)!=1L||length(expected_bioc)!=1L||anyDuplicated(package_lock$package))stop('invalid runtime version lock')
R_version_matches <- identical(as.character(getRversion()),expected_R)
if(install && !R_version_matches)stop(paste('NEEDS_R_VERSION: expected',expected_R,'found',getRversion()))
cran <- c('ggplot2','ragg','systemfonts','jsonlite','yaml','digest','circlize',
          'ape','ggrepel','scales','stringi')
bioc <- 'ComplexHeatmap'
if(profile=='all-public') {
  cran <- unique(c(cran,'ggalluvial','cowplot','svglite','magick','data.table','ggrastr',
                   'strawr','vroom','dplyr','tibble','tidyr','readr','stringr','RSpectra'))
  bioc <- unique(c(bioc,'InteractionSet','GenomeInfoDb','S4Vectors','rhdf5','Rhdf5lib',
                   'Seqinfo','GenomicRanges','IRanges','BiocGenerics','BiocIO',
                   'BiocParallel','SummarizedExperiment'))
}
native_names <- if(profile=='all-public')c('HiCExperiment','HiContacts')else character()
required <- unique(c(cran,bioc,native_names))
present <- function(package)requireNamespace(package,quietly=TRUE)
pin_file <- if(!is.null(target_library))file.path(target_library,'.biofigure-native-source-pins.json')else NULL
read_pins <- function() {
  if(is.null(pin_file)||!file.exists(pin_file)||!present('jsonlite'))return(list(packages=list()))
  result <- jsonlite::read_json(pin_file,simplifyVector=FALSE)
  if(!identical(result$schema_version,1L) || !identical(result$purpose,'BioFigure explicit native dependency installation'))
    stop('existing native source pin record has an unsupported owner/schema')
  result
}
package_files <- function(name) {
  directory <- find.package(name,quiet=TRUE)
  paths <- sort(list.files(directory,recursive=TRUE,all.files=TRUE,full.names=TRUE,no..=TRUE))
  paths <- paths[file.info(paths)$isdir %in% FALSE]
  lapply(paths,function(p)list(path=substring(p,nchar(directory)+2L),sha256=digest::digest(file=p,algo='sha256')))
}
pin_verified <- function(pin, records) {
  if(!present(pin$package)||!present('digest') || as.character(utils::packageVersion(pin$package))!=pin$version)return(FALSE)
  rows <- Filter(function(x)identical(x$package,pin$package),records$packages)
  if(length(rows)!=1L || !identical(rows[[1]]$source_sha256,pin$sha256) ||
     !identical(rows[[1]]$commit,pin$commit))return(FALSE)
  identical(rows[[1]]$installed_files,package_files(pin$package))
}
if(install) {
  normalized <- normalizePath(target_library,mustWork=FALSE)
  system_libraries <- normalizePath(unique(c(.Library,.Library.site)),mustWork=FALSE)
  if(normalized %in% system_libraries)stop('--library must not be a system R library')
  dir.create(target_library,recursive=TRUE,showWarnings=FALSE)
  target_library <- normalizePath(target_library,mustWork=TRUE)
  .libPaths(c(target_library,.libPaths()))
  Sys.setenv(R_LIBS_USER=target_library)
  pin_file <- file.path(target_library,'.biofigure-native-source-pins.json')
  version_matches <- function(name) {
    row <- package_lock[package_lock$package==name,,drop=FALSE]
    present(name) && (!nrow(row)||as.character(utils::packageVersion(name))==row$version)
  }
  missing_cran <- cran[!vapply(cran,version_matches,logical(1))]
  if(length(missing_cran)) {
    repository <- 'https://cloud.r-project.org'
    available <- utils::available.packages(repos=repository)
    source_available <- utils::available.packages(repos=repository,type='source')
    for(name in missing_cran) {
      row <- package_lock[package_lock$package==name,,drop=FALSE]
      current <- if(name %in% rownames(available))as.character(package_version(available[name,'Version']))else ''
      if(!nrow(row)||identical(current,row$version)) {
        utils::install.packages(name,lib=target_library,repos=repository)
      } else {
        current_source <- if(name %in% rownames(source_available))source_available[name,'Version']else ''
        source_url <- if(identical(current_source,row$source_version))
          paste0('https://cran.r-project.org/src/contrib/',name,'_',row$source_version,'.tar.gz')else
          paste0('https://cran.r-project.org/src/contrib/Archive/',name,'/',name,'_',row$source_version,'.tar.gz')
        archive <- tempfile(paste0(name,'-'),fileext='.tar.gz')
        utils::download.file(source_url,archive,mode='wb')
        utils::install.packages(archive,lib=target_library,repos=NULL,type='source')
        unlink(archive)
      }
      if(!version_matches(name))stop(paste('NEEDS_PACKAGE_VERSIONS: could not install locked official CRAN version for',name))
    }
  }
  missing_bioc <- bioc[!vapply(bioc,version_matches,logical(1))]
  if(length(missing_bioc)) {
    if(!present('BiocManager'))utils::install.packages('BiocManager',lib=target_library,repos='https://cloud.r-project.org')
    BiocManager::install(missing_bioc,lib=target_library,version=expected_bioc,ask=FALSE,update=FALSE,force=TRUE)
    for(name in missing_bioc)if(!version_matches(name))stop(paste('NEEDS_PACKAGE_VERSIONS: locked Bioconductor version unavailable or incompatible:',name))
  }
}
native_lock <- if(length(native_names) && present('jsonlite'))
  jsonlite::read_json(file.path(skill,'static/core/public-native-packages.json'),simplifyVector=FALSE)$packages else list()
records <- read_pins()
if(install && length(native_names)) {
  if(!present('jsonlite')||!present('digest'))stop('jsonlite and digest must install before pinned native packages')
  for(pin in native_lock) {
    if(pin_verified(pin,records))next
    archive <- tempfile(paste0(pin$package,'-'),fileext='.tar.gz')
    utils::download.file(pin$url,archive,mode='wb',quiet=FALSE)
    if(unname(file.info(archive)$size)!=pin$bytes || digest::digest(file=archive,algo='sha256')!=pin$sha256)
      stop(paste('pinned native source hash/size mismatch:',pin$package))
    utils::install.packages(archive,lib=target_library,repos=NULL,type='source')
    unlink(archive)
    if(!present(pin$package)||as.character(utils::packageVersion(pin$package))!=pin$version)
      stop(paste('pinned native package installation failed:',pin$package))
    records$packages <- Filter(function(x)!identical(x$package,pin$package),records$packages)
    records$packages[[length(records$packages)+1L]] <- list(package=pin$package,version=pin$version,
       commit=pin$commit,source_sha256=pin$sha256,installed_files=package_files(pin$package))
  }
  records$schema_version <- 1L
  records$purpose <- 'BioFigure explicit native dependency installation'
  records$R_version <- as.character(getRversion())
  jsonlite::write_json(records,pin_file,auto_unbox=TRUE,pretty=TRUE)
}
found <- vapply(required,present,logical(1))
version_mismatches <- Filter(function(row)present(row$package) &&
  as.character(utils::packageVersion(row$package))!=row$version,
  lapply(seq_len(nrow(package_lock)),function(i)as.list(package_lock[i,,drop=FALSE])))

font_found <- NA
if(present('systemfonts')) {
  fonts <- systemfonts::system_fonts()
  font_found <- any(tolower(fonts$family)==tolower(target_font))
}
style <- new.env(parent=globalenv())
source(file.path(skill,'scripts/figure_style.R'),local=style,encoding='UTF-8')
gs <- if(exists('bf_ghostscript_command',envir=style,inherits=FALSE))
  tryCatch(style$bf_ghostscript_command(),error=function(e)'') else unname(Sys.which('gs'))
if(is.null(gs))gs <- ''
needs_gs <- 'pdf' %in% formats || profile=='all-public'
extra_tools <- if(profile=='all-public')c(pdftoppm=unname(Sys.which('pdftoppm')))else character()
native_verified <- if(length(native_lock))vapply(native_lock,pin_verified,logical(1),records=records)else logical()
missing_native_pins <- if(length(native_names) && !length(native_lock))native_names else
  vapply(native_lock[!native_verified],function(x)x$package,character(1))
status <- if(!R_version_matches)'NEEDS_R_VERSION' else if(length(version_mismatches))'NEEDS_PACKAGE_VERSIONS' else if(!all(found))'NEEDS_DEPENDENCIES' else if(length(missing_native_pins))'NEEDS_PINNED_NATIVE_PACKAGES' else
  if(!isTRUE(font_found))'NEEDS_FONT' else if(needs_gs && !nzchar(gs))'NEEDS_GHOSTSCRIPT' else
  if(any(!nzchar(extra_tools)))'NEEDS_TOOLS' else 'READY'
all_installed <- utils::installed.packages()
report <- list(schema_version=1,status=status,profile=profile,operation=if(install)'explicit-install' else 'read-only-check',
               R_version=as.character(getRversion()),expected_R_version=expected_R,expected_Bioconductor=expected_bioc,version_mismatches=version_mismatches,locked_top_level_versions=lapply(seq_len(nrow(package_lock)),function(i)as.list(package_lock[i,,drop=FALSE])),target_font=target_font,target_font_present=font_found,
               formats=formats,ghostscript=list(required=needs_gs,available=nzchar(gs),
                   path=if(nzchar(gs))unname(gs)else NULL,
                   purpose='Embed exact Arial/Helvetica fonts. No system software is installed by this script.'),
               external_tools=as.list(extra_tools),missing_packages=unname(required[!found]),
               missing_native_source_pins=unname(missing_native_pins),
               native_sources=lapply(native_lock,function(p)list(package=p$package,version=p$version,commit=p$commit,
                   source_sha256=p$sha256,verified_installation=pin_verified(p,records))),
               packages=lapply(required,function(p)list(name=p,present=present(p),
                   version=if(present(p))as.character(utils::packageVersion(p))else NULL)),
               library_paths=.libPaths(),complete_installed_versions=lapply(seq_len(nrow(all_installed)),function(i){p<-all_installed[i,];list(package=unname(p[['Package']]),version=unname(p[['Version']]),built=unname(p[['Built']]))}),
               scope='Dependency/font/tool check only. Portable covers the seven new examples and OncoPrint dependencies; all-public adds retained adapters. Legacy adapters always render PDF. No execution, scientific or visual PASS is inferred.')
if(present('jsonlite')) {
  cat(jsonlite::toJSON(report,auto_unbox=TRUE,pretty=TRUE,null='null'), '\n')
} else {
  cat('{"schema_version":1,"status":"',status,'","profile":"',profile,
      '","operation":"read-only-check","missing_packages":[',
      paste(paste0('"',required[!found],'"'),collapse=','),
      '],"scope":"Install explicitly; no renderer execution."}\n',sep='')
}
quit(status=if(status=='READY')0L else 2L)
