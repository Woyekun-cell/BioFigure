# Shared code is staged into each individual independent benchmark process.
suppressPackageStartupMessages({library(jsonlite); library(systemfonts)})
options(warn=2)
dir.create('results',showWarnings=FALSE);dir.create('results/plot_data',showWarnings=FALSE);dir.create('results/tables',showWarnings=FALSE)
settings <- jsonlite::fromJSON('data/settings.json',simplifyVector=FALSE)
contract <- jsonlite::fromJSON('contract.json',simplifyVector=FALSE)
font <- settings$font_family
stopifnot(identical(font,'Arial'),is.character(settings$experimental_unit),nzchar(settings$experimental_unit),
          is.logical(settings$synthetic),is.character(settings$data_context),nzchar(settings$data_context),
          is.character(settings$figure_caption),nzchar(settings$figure_caption))
pt <- function(name)as.numeric(settings$font_roles_pt[[name]])
stopifnot(min(unlist(settings$font_roles_pt))>=6)
font_path <- systemfonts::match_fonts(font)$path[1]
stopifnot(basename(font_path)=='Arial.ttf')
read_input <- function(name)read.csv(file.path('data',paste0(name,'.csv')),stringsAsFactors=FALSE,na.strings=c('','NA'),check.names=FALSE)
required <- function(d,keys,name){if(!all(keys %in% names(d)))stop(name,': missing required fields')}
unique_key <- function(d,key,name){if(anyNA(d[[key]])||any(!nzchar(d[[key]]))||anyDuplicated(d[[key]]))stop(name,': duplicate or missing primary key')}
wrap <- function(x,n=settings$label_wrap_chars)vapply(x,function(s)paste(strwrap(s,width=n),collapse='\n'),character(1),USE.NAMES=FALSE)
groups <- read_input('groups');required(groups,c('group_id','label','order','color','shape'),'groups');unique_key(groups,'group_id','groups')
stopifnot(!anyNA(groups),!anyDuplicated(groups$order),all(grepl('^#[0-9A-Fa-f]{6}$',groups$color)))
groups <- groups[order(groups$order),];colors <- setNames(groups$color,groups$group_id);shapes <- setNames(groups$shape,groups$group_id)
width_mm<-as.numeric(settings$width_mm);height_mm<-as.numeric(settings$height_mm)
stopifnot(width_mm>=180,width_mm<=183,height_mm<=170,height_mm>0)
root <- Sys.getenv('BIOFIGURE_SKILL_ROOT',unset=getwd());root<-normalizePath(root);while(!file.exists(file.path(root,'static/core/execution-contract.yaml'))){nextroot<-dirname(root);if(identical(root,nextroot))stop('Skill root unavailable');root<-nextroot}
# Native patchwork/ggtern/circlize rendering has no complete official CP3 adapter.
# Issue/consume current code+data authorization; do not forge bf_render_png receipt.
authorize_native <- function(){
sources <- c('render.R','common.R','data/settings.json',list.files('data',pattern='\\.csv$',full.names=TRUE))
python <- Sys.getenv('PYTHON','python3');authscript<-file.path(root,'scripts/authorize_render.py')
args<-c(authscript,'--receipt','data/preparation-receipt.json','--design-spec','data/design-spec.yaml',unlist(lapply(sources,function(s)c('--source',s))),'--output','results/render-authorization.json')
if(system2(python,shQuote(args))!=0L)stop('Native source authorization failed')
args<-c(authscript,'--design-spec','data/design-spec.yaml',unlist(lapply(sources,function(s)c('--source',s))),'--output','results/render-authorization.json','--consume')
if(system2(python,shQuote(args))!=0L)stop('Native source authorization consumption failed')
}
checks<-list();check<-function(name,cond,evidence){if(!isTRUE(cond))stop('Scientific check failed: ',name);checks[[name]]<<-list(status='pass',evidence=evidence)}
write_json <- function(value,path)jsonlite::write_json(value,path,pretty=TRUE,auto_unbox=TRUE,digits=12)
write_csv <- function(value,name)write.csv(value,paste0('results/plot_data/',name,'.csv'),row.names=FALSE)
export_plot <- function(draw){
 ragg::agg_png('results/figure.png',width=width_mm,height=height_mm,units='mm',res=300,background='white');draw();invisible(dev.off())
 grDevices::quartz(type='pdf',file='results/figure.pdf',width=width_mm/25.4,height=height_mm/25.4,family=font,bg='white');draw();invisible(dev.off())
 svglite::svglite('results/figure.svg',width=width_mm/25.4,height=height_mm/25.4,bg='white');draw();invisible(dev.off())
}
finish <- function(geometry){
 geometry$font_sizes_pt<-settings$font_roles_pt;geometry$width_mm<-width_mm;geometry$height_mm<-height_mm;geometry$font_path<-font_path;geometry$render_context<-settings[c('data_context','experimental_unit','synthetic','figure_caption')]
 write_json(geometry,'results/geometry.json');write_json(checks,'results/scientific_results.json');write_json(list(status='NOT_VERIFIED',reason='Dedicated native renderer issued/consumed exact input authorization and produced benchmark evidence; official bf_render_png CP3 adapter unavailable for native object. No CP3 PASS receipt generated.'),'results/cp3-boundary.json');capture.output(sessionInfo(),file='results/session-info.txt')
}
