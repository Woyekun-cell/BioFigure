# Render the locked seed-102 fixture through the reusable layout and BioFigure gates.
args <- commandArgs(TRUE)
stopifnot(length(args) == 3L)
p <- normalizePath(args[1])
w <- normalizePath(args[2])
out <- normalizePath(args[3])
s <- file.path(p, "biofigure")
d <- file.path(s, "benchmark/library/topjournal/issue_102")
spec_file <- file.path(w, "design-spec.yaml")
spec <- yaml::read_yaml(spec_file)
width <- spec$output_size$width_mm
height <- spec$output_size$height_mm
helper <- file.path(s, "scripts/figure_style.R")
source(helper)
font <- bf_font("Arial")
code <- file.path(d, "scripts/article-code.txt")
seq_file <- file.path(d, "plot_data/synteny_sim_sequences.csv")
link_file <- file.path(d, "plot_data/synteny_sim_links.csv")
txt <- readLines(code, encoding = "UTF-8")
txt <- txt[!trimws(txt) %in% c("02", "—", "绘制共线性图")]
web <- gsub("\u00a0", " ", readLines(file.path(w, "code-from-article.txt"), encoding = "UTF-8"), fixed = TRUE)
local_expressions <- as.list(parse(text = txt, keep.source = FALSE))
web_expressions <- as.list(parse(text = web, keep.source = FALSE))
stopifnot(identical(local_expressions, web_expressions),
          identical(tail(local_expressions, 1L)[[1]][[1]], quote(ggsave)))
workflow <- file.path(d, "scripts/synteny_workflow.R")
source(workflow)
result <- build_synteny(readr::read_csv(seq_file, show_col_types = FALSE),
                        readr::read_csv(link_file, show_col_types = FALSE))
plot <- result$plot
aud <- c(result$audit, list(seed=102L, source_code_expressions_match=TRUE, simulation_disclosed=TRUE))
jsonlite::write_json(aud, file.path(out, "built-layer-audit.json"), auto_unbox=TRUE, pretty=TRUE)
files <- c(spec_file, helper, workflow, seq_file, link_file, code, file.path(w, "code-from-article.txt"),
           file.path(w, "source-review-receipt.json"), file.path(w, "simulation.json"),
           file.path(d, "scripts/simulate_synteny.R"), file.path(d, "scripts/render_synteny.R"))
auth <- tempfile("authorization-", tmpdir=out, fileext=".json")
cmd <- c(file.path(s,"scripts/authorize_render.py"),"--receipt",file.path(w,"preparation-receipt.json"),
         "--design-spec",spec_file,"--output",auth,unlist(lapply(files[-1L],function(f)c("--source",f))))
stopifnot(system2("python3", shQuote(cmd)) == 0L)
boxes <- data.frame(id = c("data","labels","legend"), x = c(12,0,0), y = c(8,0,82),
                    w = c(167,183,1), h = c(69,82,1))
png <- file.path(out, "issue102-synteny-sim.png")
pdf <- file.path(out, "issue102-synteny-sim.pdf")
bf_render_png(plot, png, font, unlist(spec$text_contract$allowed_text), width, height, width,
              files, boxes, allowed_pairs = "data:labels", dpi = 300, min_text_pt = 8.4,
              authorization = auth, skill_root = s, publication_size_class = "double-column")
bf_pdf_open(pdf,width,height,font)
print(plot)
invisible(dev.off())
jsonlite::write_json(bf_pdf_finalize(pdf,font,width,height),file.path(out,"pdf-technical-audit.json"),
                     auto_unbox=TRUE,pretty=TRUE)
capture.output(sessionInfo(),file=file.path(out,"render-sessionInfo.txt"))
