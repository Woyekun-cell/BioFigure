script_arg <- grep('^--file=', commandArgs(FALSE), value = TRUE)
script_file <- normalizePath(sub('^--file=', '', script_arg[[1]]))
skill_root <- normalizePath(file.path(dirname(script_file), '..'))
source(file.path(skill_root, 'scripts', 'figure_style.R'))
library(ggplot2)
expect_error <- function(expr, pattern) {
  msg <- tryCatch({force(expr); ''}, error=function(e) conditionMessage(e))
  stopifnot(grepl(pattern, msg, fixed=TRUE))
}
font <- bf_font('Arial')
stopifnot(bf_validate_publication_size(90,75,'single-column'))
stopifnot(bf_validate_publication_size(128,100,'one-and-half-column'))
stopifnot(bf_validate_publication_size(183,120,'double-column'))
expect_error(bf_validate_publication_size(183,120,'single-column'),'single-column width')
expect_error(bf_validate_publication_size(183,175,'double-column'),'height exceeds 170 mm')
expect_error(bf_validate_publication_size(170,120,'custom'),'custom publication size requires')
p <- ggplot(data.frame(x=1:3,y=2:4),aes(x,y))+geom_point()+bf_theme(font)+labs(x='Dose',y='Response')
expect_error(bf_prepare(p+labs(title='Publication-ready result'),font,c('Dose','Response','1','2','3','4')),'unrequested')
expect_error(bf_font('DefinitelyMissingFont'),'font')
expect_error(bf_prepare(p+annotate('text',x=2,y=3,label='Gene1',family='serif'),font,c('Dose','Response','Gene1','1','2','3','4')),'font')
expect_error(bf_prepare(p+annotate('text',x=2,y=3,label='AI insight',family='Arial'),font,c('Dose','Response','1','2','3','4')),'unapproved')
expect_error(bf_check_boxes(data.frame(id=c('data','legend'),x=c(0,8),y=c(0,0),w=c(10,4),h=c(10,4)),20,20),'overlap')
stopifnot(bf_check_boxes(data.frame(id=c('data','legend'),x=c(0,12),y=c(0,0),w=c(10,4),h=c(10,4)),20,20))
body <- bf_square_body(18,8,2,row_gaps_mm=c(1,1),column_gaps_mm=3)
stopifnot(body$width_mm==19,body$height_mm==38)
stopifnot(bf_label_angle(c('C1','R5'),font,7,2.5)==90)
stopifnot(bf_label_angle('C1',font,7,10)==0)
bf_complexheatmap_font(font)
stopifnot(grDevices::pdfFonts()[['Arial']]$family=='ArialMT')
stopifnot(normalizePath(bf_resolve_skill_root(skill_root))==normalizePath(skill_root))
expect_error(bf_resolve_skill_root(tempdir()),'BIOFIGURE_SKILL_ROOT')
old_wd<-getwd(); old_root<-Sys.getenv('BIOFIGURE_SKILL_ROOT',unset=NA_character_)
Sys.setenv(BIOFIGURE_SKILL_ROOT=skill_root); setwd(tempdir())
stopifnot(normalizePath(bf_resolve_skill_root())==normalizePath(skill_root))
copy_root<-file.path(tempdir(),'biofigure-copied-helper'); dir.create(file.path(copy_root,'scripts'),recursive=TRUE,showWarnings=FALSE)
file.copy(file.path(skill_root,'scripts','figure_style.R'),file.path(copy_root,'scripts','figure_style.R'),overwrite=TRUE)
copied_env<-new.env(); sys.source(file.path(copy_root,'scripts','figure_style.R'),copied_env)
stopifnot(normalizePath(copied_env$bf_resolve_skill_root())==normalizePath(skill_root))
setwd(old_wd); if(is.na(old_root)) Sys.unsetenv('BIOFIGURE_SKILL_ROOT') else Sys.setenv(BIOFIGURE_SKILL_ROOT=old_root)
# A long legend must not consume the data panel silently.
long_label<-paste(rep('Treatment',14),collapse=' ')
long_plot<-p+aes(colour=factor(x))+scale_colour_discrete(labels=rep(long_label,3))+scale_x_continuous(breaks=1:3)+scale_y_continuous(breaks=2:4)
long_prepared<-bf_prepare(long_plot,font,c('Dose','Response','1','2','3','4','factor(x)',long_label),width_mm=90,height_mm=75)
f<-tempfile(fileext='.png')
expect_error(bf_export_png(long_prepared,f,90,75),'insufficient panel')
stopifnot(!file.exists(f))

output_dir<-Sys.getenv('BIOFIGURE_TEST_OUTPUT',tempdir())
dir.create(output_dir,recursive=TRUE,showWarnings=FALSE)
target<-file.path(output_dir,'receipt-test.png')
test_spec<-file.path(output_dir,'receipt-test-spec.yaml')
boxes<-data.frame(id=c('data','labels','legend'),x=c(15,0,77),y=c(0,0,0),w=c(60,14,10),h=c(60,60,60))
clean<-p+scale_x_continuous(breaks=1:3)+scale_y_continuous(breaks=2:4)
labels<-c('Dose','Response','1','2','3','4')
expect_error(bf_render_png(clean,target,font,labels,90,75,90,
  c(script_file,file.path(skill_root,'scripts/figure_style.R'),test_spec),boxes), 'authorization')
make_authorization<-function(source_files) {
  receipt<-file.path(output_dir,'authorization-receipt.json')
  auth<-file.path(output_dir,paste0('authorization-',tempfile()))
  request_path<-file.path(output_dir,'authorization-request.yaml')
  writeLines(c('figure_task: marker-expression-across-cell-types',
    'figure_family: single-cell','data_shape: genes by cells with pct and average expression',
    'primary_domain: single-cell-spatial','primary_role: discovery','backend: R','deliverable: quick-png'),request_path)
  prep_args<-c(file.path(skill_root,'scripts/prepare_figure.py'),request_path,'--output',receipt)
  prep_status<-system2(Sys.getenv('PYTHON','python3'),shQuote(prep_args),stdout=FALSE,stderr=FALSE)
  stopifnot(identical(prep_status,0L))
  prep<-jsonlite::fromJSON(receipt,simplifyVector=FALSE)
  spec_doc<-yaml::read_yaml(file.path(skill_root,'schemas/examples/marker-dotplot.yaml'))
  spec_doc$deliverable_contract$target<-'quick-png'
  spec_doc$deliverable_contract$required_formats<-list('png')
  spec_doc$output_size$formats<-list('png')
  spec_doc$output_size$width_mm<-90
  spec_doc$output_size$height_mm<-75
  spec_doc$output_size$size_class<-'single-column'
  spec_doc$output_size$size_basis<-'final_physical_output'
  spec_doc$output_size$size_rationale<-list(panel_count=1L,density='low',longest_label_chars=9L,
    recommended_class='single-column',selection_reason='single compact panel',override_basis='')
  spec_doc$figure_task<-prep$request$figure_task
  spec_doc$reference_evidence$preparation_id<-prep$preparation_id
  spec_doc$reference_evidence$preparation_request<-prep$request
  spec_doc$reference_evidence$selected_method_case_id<-prep$selected_reference_candidates$planner_selected
  spec_doc$reference_evidence$retrieval_query$task<-'marker-expression-across-cell-types'
  spec_doc$reference_evidence$selected_atlas_ids<-list('ATLAS-TJ-HCL-F2')
  spec_doc$reference_analysis<-list(figure_family='single-cell',semantic_purpose='display marker specificity',
    panels=list(list(id='main',role='primary evidence',position='full canvas')),
    elements=list(list(id='bubbles',role='marker expression',geometry='points',position='matrix cells',data_mapping='gene by cell type',required=TRUE),
      list(id='labels',role='gene labels',geometry='text',position='left',data_mapping='gene labels',required=TRUE)),
    relationships=list(list(from='bubbles',to='labels',type='aligns-with',shared_key='gene')),
    spatial_topology=list(coordinate_system='cartesian',reading_order=list('main'),alignment_keys=list('gene','cell_type'),layer_order=list('bubbles','labels')),
    required_structures=list('gene by cell type matrix'),forbidden_substitutions=list('bar chart'))
  spec_doc$design_target<-list(reference='ATLAS-TJ-HCL-F2',reference_opened=TRUE)
  for(k in c('hierarchy','geometry','palette','typography','marks','annotation'))
    spec_doc$design_target[[k]]<-list(observation='visible',implementation='task-specific',difference_reason='adapted')
  spec_doc$text_contract<-list(allowed_text=list('Gene','Cell type'),allow_headings=FALSE)
  yaml::write_yaml(spec_doc,test_spec)
  sources<-source_files[source_files!=test_spec]
  args<-c(file.path(skill_root,'scripts/authorize_render.py'),'--receipt',receipt,'--design-spec',test_spec,
    '--output',auth,unlist(lapply(sources,function(x)c('--source',x))))
  output<-system2(Sys.getenv('PYTHON','python3'),shQuote(args),stdout=TRUE,stderr=TRUE)
  status<-attr(output,'status'); if(is.null(status)) status<-0L
  if(as.integer(status)!=0L) stop(paste(output,collapse='\n'))
  auth
}
render<-function(p=clean,width=90,target_width=90) {
  sources<-c(script_file,file.path(skill_root,'scripts/figure_style.R'),test_spec)
  auth<-make_authorization(sources)
  bf_render_png(p,target,font,labels,width,75,target_width,sources,boxes,authorization=auth)
}
render()
stopifnot(file.exists(paste0(target,'.render.json')))
expect_error(render(clean+labs(title='Unexpected')),'unrequested')
stopifnot(!file.exists(paste0(target,'.render.json')))
expect_error(render(clean+annotate('text',x=2,y=3,label='Gene',family='sans')),'font')
expect_error(render(width=215.9,target_width=90),'text too small')
tiles<-ggplot(expand.grid(x=letters[1:4],y=LETTERS[1:16]),aes(x,y))+geom_tile()+bf_theme(font)
expect_error(bf_prepare(tiles,font,c(letters[1:4],LETTERS[1:16],'x','y')),'coord_fixed')
render()
cat('STYLE_TESTS_OK\n')
