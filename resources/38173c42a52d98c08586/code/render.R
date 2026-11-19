args <- commandArgs(TRUE)
stopifnot(length(args)==3L)
w <- normalizePath(args[1])
out <- normalizePath(args[2])
input <- normalizePath(args[3])
base <- dirname(w)
project <- dirname(dirname(base))
skill <- file.path(project,"biofigure")
case <- file.path(skill,"benchmark/library/topjournal",basename(w))
c <- jsonlite::fromJSON(file.path(w,"case.json"))
spec_file <- file.path(w,"design-spec.yaml")
spec <- yaml::read_yaml(spec_file)
helper <- file.path(skill,"scripts/figure_style.R")
source(helper)
builder <- file.path(case,"scripts/build_plot.R")
source(builder)
font <- bf_font("Arial")
size <- spec$output_size
width <- size$width_mm
height <- size$height_mm
result <- build_plot(readr::read_csv(input,show_col_types=FALSE),unlist(spec$palette_semantics))
dpi <- 300
if (!is.null(result$plots)) {
  cowplot::set_null_device("agg")
  p <- cowplot::plot_grid(plotlist=result$plots,ncol=1,align="v",axis="lr")
} else {
  p <- result$plot
}
files <- c(spec_file,helper,builder,input,file.path(base,"render.R"),file.path(base,"prepare_inputs.R"),
           file.path(w,"case.json"),file.path(w,"source-review-receipt.json"))
auth <- tempfile("authorization-",tmpdir=out,fileext=".json")
auth_args <- c(file.path(skill,"scripts/authorize_render.py"),"--receipt",file.path(w,"preparation-receipt.json"),
  "--design-spec",spec_file,"--output",auth,unlist(lapply(files[-1L],function(f)c("--source",f))))
stopifnot(system2("python3",shQuote(auth_args))==0L)
check <- data.frame(id=c("data","labels","legend"),x=0,y=0,w=width,h=height)
stem <- file.path(out,paste0(c$fname,"-recolor"))
bf_render_png(p,paste0(stem,".png"),font,unlist(spec$text_contract$allowed_text),width,height,width,files,check,
  allowed_pairs=c("data:labels","data:legend","labels:legend"),dpi=dpi,min_text_pt=6,
  authorization=auth,skill_root=skill,publication_size_class=size$size_class)
bf_pdf_open(paste0(stem,".pdf"),width,height,font)
print(p)
invisible(dev.off())
pdf <- bf_pdf_finalize(paste0(stem,".pdf"),font,width,height)
jsonlite::write_json(pdf,file.path(out,"pdf-technical-audit.json"),auto_unbox=TRUE,pretty=TRUE)
result[c("plot","plots")] <- NULL
jsonlite::write_json(result,file.path(out,"structure.json"),auto_unbox=TRUE,pretty=TRUE,digits=NA)
capture.output(sessionInfo(),file=file.path(out,"render-sessionInfo.txt"))
