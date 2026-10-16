#!/usr/bin/env Rscript
# Native matched-feature alluvial; independently simulated data, no inference.
args <- commandArgs(TRUE)
stopifnot(length(args)==3)
root <- normalizePath(args[1],mustWork=TRUE)
work <- normalizePath(args[2],mustWork=TRUE)
authorization <- normalizePath(args[3],mustWork=TRUE)
skill <- normalizePath(Sys.getenv('BIOFIGURE_SKILL_ROOT'),mustWork=TRUE)
source(file.path(skill,'scripts/figure_style.R'))
options(warn=2)
font <- bf_font('Arial'); bf_complexheatmap_font(font)
spec_path <- file.path(root,'data/metadata/design-spec.yaml')
spec <- yaml::read_yaml(spec_path)
paths_path <- file.path(root,'results/plot_data/sankey_paths.csv')
nodes_path <- file.path(root,'results/plot_data/sankey_nodes.csv')
raw_path <- file.path(root,'data/raw/sankey_features.csv')
paths <- read.csv(paths_path,stringsAsFactors=FALSE)
nodes <- read.csv(nodes_path,stringsAsFactors=FALSE)
raw <- read.csv(raw_path,stringsAsFactors=FALSE)
states <- c('Low','Neutral','High')
stages <- c('DNA_copy_number','RNA_expression','Protein_abundance')
stopifnot(nrow(paths)==27,nrow(raw)==1800,!anyDuplicated(raw$feature_id),
 sum(paths$n_features)==1800,all(paths$n_features>0))
for(s in stages) {
 paths[[s]] <- factor(paths[[s]],levels=states)
 stopifnot(identical(as.integer(table(factor(raw[[s]],levels=states))),
   nodes$n_features[nodes$stage==s]))
}
pal <- unlist(spec$palette_semantics[states])
lighten <- function(col)grDevices::rgb(t(grDevices::col2rgb(col)/255)*.30+.70)
light <- setNames(vapply(pal,lighten,''),states)
lodes <- do.call(rbind,lapply(seq_along(stages),function(i)data.frame(
 x=i,stratum=paths[[stages[i]]],alluvium=paths$path_id,
 n_features=paths$n_features,DNA_start=paths$DNA_copy_number)))
body <- ggplot2::ggplot(lodes,ggplot2::aes(x=x,y=n_features,stratum=stratum,alluvium=alluvium))+
 ggalluvial::geom_alluvium(ggplot2::aes(fill=DNA_start),width=.34,
   reverse=FALSE,alpha=.57,colour=NA,knot.pos=.38)+
 ggalluvial::geom_stratum(ggplot2::aes(fill=ggplot2::after_stat(stratum)),width=.34,
   reverse=FALSE,colour='#30343B',linewidth=.18)+
 ggplot2::scale_fill_manual(values=pal,guide='none')+
 ggplot2::scale_x_continuous(limits=c(.72,3.28),expand=c(0,0))+
 ggplot2::scale_y_continuous(limits=c(0,1800),expand=c(0,0))+
 ggplot2::coord_cartesian(clip='off')+
 ggplot2::theme_void(base_family=font$family,base_size=8)+
 ggplot2::theme(plot.margin=ggplot2::margin(0,0,0,0,'mm'),
   panel.background=ggplot2::element_rect(fill='white',colour=NA))
built <- ggplot2::ggplot_build(body)
flow <- built$data[[1]]; strata <- built$data[[2]]
stopifnot(nrow(flow)==81,nrow(strata)==9,
 all(tapply(flow$ymax-flow$ymin,flow$x,sum)==1800),
 all(tapply(strata$ymax-strata$ymin,strata$x,sum)==1800))
strata$stage <- stages[as.integer(strata$x)]
strata$state <- as.character(strata$stratum)
strata$count <- as.integer(strata$ymax-strata$ymin)
for(i in seq_len(nrow(strata)))stopifnot(strata$count[i]==nodes$n_features[
 nodes$stage==strata$stage[i]&nodes$state==strata$state[i]])
stopifnot(all(as.character(strata$stratum[order(strata$x,strata$y)])==rep(states,3)))
state_names <- rbind(c('Loss','Diploid','Gain'),c('Down','Stable','Up'),c('Down','Stable','Up'))
strata$label <- state_names[cbind(as.integer(strata$x),match(strata$state,states))]
strata$count_label <- paste('n =',strata$count)
# Only the stratum fill is lightened. Flow colour remains its DNA starting state.
body$layers[[2]]$aes_params$fill <- unname(light[strata$state])
body <- body+
 ggplot2::geom_text(data=strata,ggplot2::aes(x=x,y=y+40,label=label),
   inherit.aes=FALSE,family=font$family,size=8.000001/ggplot2::.pt,colour='#30343B')+
 ggplot2::geom_text(data=strata,ggplot2::aes(x=x,y=y-40,label=count_label),
   inherit.aes=FALSE,family=font$family,size=8.000001/ggplot2::.pt,colour='#30343B')
width <- 136; height <- 115
header <- data.frame(x=8+(c(1,2,3)-.72)/2.56*120,y=106,
 label=c('DNA copy number','RNA expression','Protein abundance'))
footer <- data.frame(x=68,y=c(11.2,7.2,3.2),label=c(
 'Simulated matched features (n = 1,800)',
 'Band width = number of matched features','Flows colored by DNA starting state'))
plot <- ggplot2::ggplot()+
 ggplot2::annotation_custom(ggplot2::ggplotGrob(body),xmin=8,xmax=128,ymin=17,ymax=100)+
 ggplot2::geom_text(data=header,ggplot2::aes(x=x,y=y,label=label),
   family=font$family,size=8.5/ggplot2::.pt,colour='#30343B')+
 ggplot2::geom_text(data=footer,ggplot2::aes(x=x,y=y,label=label),
   family=font$family,size=8.000001/ggplot2::.pt,colour='#30343B')+
 ggplot2::coord_fixed(xlim=c(0,width),ylim=c(0,height),expand=FALSE,clip='off')+
 ggplot2::theme_void(base_family=font$family,base_size=8)+
 ggplot2::theme(plot.margin=ggplot2::margin(0,0,0,0,'mm'),
   plot.background=ggplot2::element_rect(fill='white',colour=NA))
# Measure direct labels in the actual face; no ribbon-label approximations.
bf_pdf_open(NULL,width,height,font)
measure <- function(s,pt=8) {
 g <- grid::textGrob(s,gp=grid::gpar(fontfamily=font$family,fontsize=pt))
 c(w=grid::convertWidth(grid::grobWidth(g),'mm',valueOnly=TRUE),
 h=grid::convertHeight(grid::grobHeight(g),'mm',valueOnly=TRUE))
}
texts <- c(strata$label,strata$count_label)
metrics <- lapply(texts,measure)
stopifnot(max(vapply(metrics,`[[`,numeric(1),'w'))<.34/2.56*120-1,
 min(strata$count)/1800*83>2*max(vapply(metrics,`[[`,numeric(1),'h'))+4)
grDevices::dev.off()
boxes <- data.frame(id=c('data','labels','legend'),x=c(8,8,5),
 y=c(15,5,100),w=c(120,120,126),h=c(83,7,13.5))
bf_check_boxes(boxes,width,height)
sources <- c(spec_path,file.path(root,'scripts/render.R'),file.path(skill,'scripts/figure_style.R'),
 paths_path,nodes_path,raw_path)
png <- file.path(work,'sankey_simulated_repaired.png')
bf_render_png(plot,png,font=font,allowed_text=spec$text_contract$allowed_text,
 width_mm=width,height_mm=height,target_width_mm=width,dpi=600,min_text_pt=8,
 source_files=sources,boxes=boxes,authorization=authorization,skill_root=skill,
 publication_size_class='one-and-half-column',size_override_basis='none')
pdf <- file.path(root,'results/figures/sankey_simulated_repaired.pdf')
bf_pdf_open(pdf,width,height,font)
print(plot);grDevices::dev.off()
pdf_inspection<-bf_pdf_finalize(pdf,font,width,height)
svg <- file.path(work,'sankey-gate-qa.svg')
svglite::svglite(svg,width=width/25.4,height=height/25.4,bg='white',system_fonts=list(sans=font$family))
print(plot);grDevices::dev.off()
for(dpi in c(96,120))stopifnot(system2('pdftoppm',shQuote(c('-singlefile','-r',dpi,'-png',pdf,
 file.path(work,paste0('sankey-pdf-',dpi,'dpi')))))==0L)
bind <- function(p)list(path=normalizePath(p),sha256=digest::digest(file=p,algo='sha256'))
jsonlite::write_json(list(status='PASS',scope='independently simulated-input gallery correction',
 seed=20261011,features=1800,paths=27,strata=9,all_stage_count=1800,
 excluded=0,native_geometry='ggalluvial::geom_alluvium/geom_stratum, reverse=FALSE',
 direct_labels=18,label_metrics_mm=metrics,minimum_node_height_mm=min(strata$count)/1800*83,
 node_width_mm=.34/2.56*120,node_outline_mm=.18,canvas_mm=c(width,height),
 palette=pal,node_pastel=light,sources=lapply(sources,bind),
 artifacts=list(pdf=bind(pdf),png=bind(png),svg_qa=bind(svg)),
 render_receipt=bind(paste0(png,'.render.json')),CP4='PENDING_REVIEW'),
 file.path(root,'results/tables/render-metrics.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
write.csv(strata[,c('stage','state','x','y','ymin','ymax','count','label','count_label')],
 file.path(root,'results/plot_data/sankey_native_strata.csv'),row.names=FALSE)
cat('SANKEY_RENDER_OK\n',pdf,'\n',png,'\n')
