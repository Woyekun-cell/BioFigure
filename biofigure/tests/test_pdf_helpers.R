# Dedicated native PDF tests. Windows resolution is simulated; rendering is local.
script_file<-normalizePath(sub('^--file=','',grep('^--file=',commandArgs(FALSE),value=TRUE)[1]))
style<-normalizePath(file.path(dirname(script_file),'../scripts/figure_style.R'))
source(style)
expect_error<-function(expr,pattern) {
 message<-tryCatch({force(expr);''},error=function(e)conditionMessage(e))
 if(!grepl(pattern,message,fixed=TRUE))stop(paste('expected',pattern,'but got',message))
}
stopifnot(exists('bf_ghostscript_command'),exists('bf_pdf_open'),exists('bf_pdf_finalize'))
# Lexical mocks exercise Windows names without claiming Windows execution.
mock<-new.env(parent=baseenv());sys.source(style,mock)
mock$Sys.getenv<-function(x,unset='')''
mock$Sys.which<-function(x)setNames(ifelse(x=='gswin64c','C:/Program Files/gs/bin/gswin64c.exe',''),x)
mock$file.exists<-function(x)x=='C:/Program Files/gs/bin/gswin64c.exe'
mock$normalizePath<-function(path,...)path
stopifnot(mock$bf_ghostscript_command()=='C:/Program Files/gs/bin/gswin64c.exe')
mock$Sys.which<-function(x)setNames(ifelse(x=='gswin32c','C:/Program Files/gs/bin/gswin32c.exe',''),x)
mock$file.exists<-function(x)x=='C:/Program Files/gs/bin/gswin32c.exe'
stopifnot(mock$bf_ghostscript_command()=='C:/Program Files/gs/bin/gswin32c.exe')
mock$Sys.getenv<-function(x,unset='')'"C:/Chosen GS/gswin64c.exe"'
mock$file.exists<-function(x)x=='C:/Chosen GS/gswin64c.exe'
stopifnot(mock$bf_ghostscript_command()=='C:/Chosen GS/gswin64c.exe')
mock$Sys.getenv<-function(x,unset='')'C:/Missing GS/gswin64c.exe'
expect_error(mock$bf_ghostscript_command(),'R_GSCMD')
mock$Sys.getenv<-function(x,unset='')''
mock$Sys.which<-function(x)setNames(rep('',length(x)),x)
mock$file.exists<-function(x)FALSE
expect_error(mock$bf_ghostscript_command(),'NEEDS_PDF_DEVICE')

font<-bf_font('Arial')
expect_error(bf_pdf_open(NULL,90,75,font,bg='black'),'white')
expect_error(bf_pdf_open(NULL,0,75,font),'positive')
# The measurement device and real exports must share the exact AFM family.
bf_pdf_open(NULL,90,75,font)
grid::grid.text('Gene01',gp=grid::gpar(fontfamily='Arial',fontsize=7))
measured<-grid::convertWidth(grid::stringWidth('Gene01'),'inches',valueOnly=TRUE)
stopifnot(is.finite(measured),measured>0,grDevices::pdfFonts()[['Arial']]$family=='ArialMT')
grDevices::dev.off()
out<-Sys.getenv('BIOFIGURE_TEST_OUTPUT',tempdir());dir.create(out,recursive=TRUE,showWarnings=FALSE)
out<-file.path(out,'PDF path with spaces');dir.create(out,showWarnings=FALSE)
target<-file.path(out,'Arial figure.pdf')
bf_pdf_open(target,183,166,font)
grid::grid.text('Gene01',gp=grid::gpar(fontfamily='Arial',fontsize=7))
grid::grid.text('Gene02',y=.4,gp=grid::gpar(fontfamily='Arial',fontface='italic',fontsize=7))
grDevices::dev.off()
result<-bf_pdf_finalize(target,font,183,166)
stopifnot(result$page_count==1,abs(result$width_mm-183)<.001,abs(result$height_mm-166)<.001,
 length(result$fonts)==2,all(vapply(result$fonts,function(x)isTRUE(x$embedded),logical(1))),
 all(grepl('Arial',vapply(result$fonts,`[[`,'','name'))))
# GS serializes page coordinates to0.01pt; test dimensions on both sides of
# the half-unit rounding boundary, rather than broadening a millimetre limit.
for(target_height in c(100,135)) {
 quantized<-file.path(out,paste0('quantized-',target_height,'.pdf'))
 bf_pdf_open(quantized,90,target_height,font)
 grid::grid.text('Gene01',gp=grid::gpar(fontfamily='Arial',fontsize=7));grDevices::dev.off()
 quantized_result<-bf_pdf_finalize(quantized,font,90,target_height)
 stopifnot(max(abs(unlist(quantized_result$mediabox_error_pt)))<=.0051)
}
wrong_size<-file.path(out,'wrong target size.pdf');bf_pdf_open(wrong_size,90,75,font)
grid::grid.text('Gene01',gp=grid::gpar(fontfamily='Arial',fontsize=7));grDevices::dev.off()
before_size<-digest::digest(file=wrong_size,algo='sha256')
expect_error(bf_pdf_finalize(wrong_size,font,90,76),'input PDF size differs')
stopifnot(digest::digest(file=wrong_size,algo='sha256')==before_size)
if('Helvetica'%in%systemfonts::system_fonts()$family) {
 # Test the PDF engine's exact TTC face independently of PNG/FreeType support.
 # bf_pdf_open still validates this resolved file/index/family against all AFMs.
 resolved<-systemfonts::match_fonts('Helvetica')
 helvetica<-list(family='Helvetica',path=resolved$path[1],index=resolved$index[1])
 helvetica_path<-file.path(out,'Helvetica figure.pdf')
 bf_pdf_open(helvetica_path,90,75,helvetica)
 grid::grid.text('Gene03',gp=grid::gpar(fontfamily='Helvetica',fontsize=7))
 grid::grid.text('Gene04',y=.4,gp=grid::gpar(fontfamily='Helvetica',fontface='italic',fontsize=7))
 grDevices::dev.off();helvetica_result<-bf_pdf_finalize(helvetica_path,helvetica,90,75)
 stopifnot(length(helvetica_result$fonts)==2,
  all(vapply(helvetica_result$fonts,function(x)isTRUE(x$embedded),logical(1))),
  all(grepl('Helvetica',vapply(helvetica_result$fonts,`[[`,'','name'))))
 cat('HELVETICA_LOCAL_RENDER=PASS\n')
} else cat('HELVETICA_LOCAL_RENDER=NOT_INSTALLED\n')
# R_GSCMD containing spaces is actually invoked on this POSIX test host.
if(.Platform$OS.type!='windows') {
 gs<-bf_ghostscript_command();wrapper<-file.path(out,'Ghostscript wrapper with spaces')
 writeLines(c('#!/bin/sh',paste('exec',shQuote(gs),'"$@"')),wrapper);Sys.chmod(wrapper,'0755')
 previous<-Sys.getenv('R_GSCMD',unset=NA_character_);Sys.setenv(R_GSCMD=wrapper)
 stopifnot(bf_ghostscript_command()==normalizePath(wrapper))
 space_result<-bf_pdf_finalize(target,font,183,166)
 stopifnot(space_result$page_count==1)
 if(is.na(previous))Sys.unsetenv('R_GSCMD') else Sys.setenv(R_GSCMD=previous)
}
multiple<-file.path(out,'two pages.pdf');bf_pdf_open(multiple,90,75,font)
grid::grid.text('First',gp=grid::gpar(fontfamily='Arial',fontsize=7));grid::grid.newpage()
grid::grid.text('Second',gp=grid::gpar(fontfamily='Arial',fontsize=7));grDevices::dev.off()
before<-digest::digest(file=multiple,algo='sha256')
expect_error(bf_pdf_finalize(multiple,font,90,75),'exactly one page')
stopifnot(digest::digest(file=multiple,algo='sha256')==before)
wrong<-font;wrong$family<-'Helvetica'
expect_error(bf_pdf_open(NULL,90,75,wrong),'font')
cat('PDF_HELPER_TESTS_OK\nLOCAL_RENDER_PLATFORM=',Sys.info()[['sysname']],
 '\nWINDOWS_EXECUTION=NOT_VERIFIED\n',sep='')
