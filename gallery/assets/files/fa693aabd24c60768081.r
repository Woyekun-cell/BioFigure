#!/usr/bin/env Rscript
# All author nodes/evidence; explicit new full-GMT OC graph and component layout.
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==3)
root <- normalizePath(args[1],mustWork=TRUE); work <- normalizePath(args[2],mustWork=TRUE)
authorization <- normalizePath(args[3],mustWork=TRUE)
skill <- Sys.getenv('BIOFIGURE_SKILL_ROOT',normalizePath(file.path(root,'../../../../../..'),mustWork=FALSE))
source(file.path(skill,'scripts','figure_style.R'))
options(warn=2)
font <- bf_font('Arial'); bf_complexheatmap_font(font)
spec_path <- file.path(root,'data','metadata','design-spec.yaml')
spec <- yaml::read_yaml(spec_path); pal <- spec$palette_semantics
prefix <- file.path(root,'results','plot_data','dpm_fig3e_recolored_')
nodes <- read.csv(paste0(prefix,'nodes.csv'),stringsAsFactors=FALSE)
edges <- read.csv(paste0(prefix,'edges.csv'),stringsAsFactors=FALSE)
plan_path <- file.path(root,'data','metadata','label-plan.json')
plans <- jsonlite::fromJSON(plan_path,simplifyVector=FALSE)
graph <- igraph::graph_from_data_frame(edges[,c('from','to')],directed=FALSE,vertices=nodes$term_id)
stopifnot(nrow(nodes)==225,nrow(edges)==2183,igraph::components(graph)$no==25,
 sum(igraph::degree(graph)==0)==11,identical(nodes$term_id,sort(nodes$term_id)))
width <- 180; height <- 165; seed <- 3302024
nodes$disk_diameter_mm <- 4.2*sqrt(nodes$term_size/max(nodes$term_size))
nodes$x_mm <- nodes$y_mm <- NA_real_
nodes$is_representative <- nodes$term_id %in% vapply(plans,`[[`,character(1),'term_id')
nodes$representative_label <- ''
grDevices::pdf(NULL,width=width/25.4,height=height/25.4,family=font$family)
measure <- function(s){g<-grid::textGrob(s,gp=grid::gpar(fontfamily=font$family,fontsize=7.5,lineheight=1.05));
 c(w=grid::convertWidth(grid::grobWidth(g),'mm',TRUE),h=grid::convertHeight(grid::grobHeight(g),'mm',TRUE))}
label_list <- list(); box_list <- list(); regions <- list(); component_metrics <- list()
for(p in plans){
 b<-p$box; idx<-which(nodes$component==p$component); n<-length(idx); tm<-measure(p$text)
 stopifnot(tm['w']<=p$max_text_width_mm+0.1)
 if(n==1){
   nodes$x_mm[idx]<-b$x+2.5;nodes$y_mm[idx]<-b$y+b$h/2
   lx<-b$x+5;ly<-b$y+b$h/2;ha<-0
   stopifnot(tm['h']<b$h)
 }else{
   lx<-b$x+b$w/2;ly<-b$y+b$h-1.5-tm['h']/2;ha<-.5
   bounds<-c(b$x+1.5,b$x+b$w-1.5,b$y+1.5,b$y+b$h-tm['h']-3.5)
   rad<-nodes$disk_diameter_mm[idx]/2+0.38
   stopifnot(diff(bounds[1:2])>2*max(rad),diff(bounds[3:4])>2*max(rad))
   sub<-igraph::induced_subgraph(graph,nodes$term_id[idx]);set.seed(seed+p$component)
   pos<-igraph::layout_with_fr(sub,niter=1500,grid='nogrid')
   pos<-pos[match(nodes$term_id[idx],igraph::V(sub)$name),,drop=FALSE]
   for(k in 1:2){rng<-range(pos[,k]); if(diff(rng)==0)pos[,k]<-mean(bounds[(2*k-1):(2*k)]) else
     pos[,k]<-bounds[2*k-1]+max(rad)+(pos[,k]-rng[1])/diff(rng)*(diff(bounds[(2*k-1):(2*k)])-2*max(rad))}
   # Relax circle collisions without removing, changing or weighting graph edges.
   for(iter in seq_len(4000)){
     moved<-FALSE
     for(i in seq_len(n-1))for(j in (i+1):n){
       delta<-pos[j,]-pos[i,]; distance<-sqrt(sum(delta^2)); required<-rad[i]+rad[j]+0.06
       if(distance<required-0.00001){
         if(distance<1e-10){delta<-c(cos(i+j),sin(i+j));distance<-1}
         shift<-delta/distance*(required-distance)/2;pos[i,]<-pos[i,]-shift;pos[j,]<-pos[j,]+shift;moved<-TRUE
       }
     }
     pos[,1]<-pmin(pmax(pos[,1],bounds[1]+rad),bounds[2]-rad)
     pos[,2]<-pmin(pmax(pos[,2],bounds[3]+rad),bounds[4]-rad)
     if(!moved)break
   }
   distances<-as.matrix(dist(pos));required<-outer(rad,rad,'+')
   bad<-sum(distances[upper.tri(distances)]<required[upper.tri(required)]-0.005)
   stopifnot(bad==0)
   nodes$x_mm[idx]<-pos[,1];nodes$y_mm[idx]<-pos[,2]
   component_metrics[[length(component_metrics)+1]]<-list(component=p$component,n=n,iterations=iter,circle_overlap_count=bad,bounds_mm=bounds)
 }
 nodes$representative_label[nodes$term_id==p$term_id]<-p$text
 label_list[[length(label_list)+1]]<-data.frame(x=lx,y=ly,label=p$text,hjust=ha,component=p$component,
  measured_w=tm['w'],measured_h=tm['h'])
 box_list[[length(box_list)+1]]<-data.frame(id=paste0('component',p$component),x=b$x,y=height-b$y-b$h,w=b$w,h=b$h)
 sts<-unique(nodes$directional_status[idx])
 if(length(sts)==1 && sts!='Shared')regions[[length(regions)+1]]<-data.frame(xmin=b$x+.3,xmax=b$x+b$w-.3,
  ymin=b$y+.3,ymax=b$y+b$h-.3,fill=if(sts=='Brown only')pal$loss_background else pal$gain_background)
}
grDevices::dev.off()
stopifnot(!anyNA(nodes$x_mm),!anyNA(nodes$y_mm))
labels<-do.call(rbind,label_list); boxes<-do.call(rbind,box_list)
boxes<-rbind(boxes,data.frame(id='legend',x=5,y=142,w=170,h=19))
bf_check_boxes(boxes,width,height)
write.csv(nodes[,c('term_id','x_mm','y_mm','disk_diameter_mm','is_representative','representative_label')],
 paste0(prefix,'layout.csv'),row.names=FALSE)
edge_plot<-edges;edge_plot$x<-nodes$x_mm[match(edges$from,nodes$term_id)];edge_plot$y<-nodes$y_mm[match(edges$from,nodes$term_id)]
edge_plot$xend<-nodes$x_mm[match(edges$to,nodes$term_id)];edge_plot$yend<-nodes$y_mm[match(edges$to,nodes$term_id)]
sectors<-list()
for(i in seq_len(nrow(nodes))){
 ev<-c('OE','KD','combined_only')[as.logical(as.numeric(nodes[i,c('OE','KD','combined_only')]))]
 stopifnot(length(ev)>0)
 for(j in seq_along(ev))sectors[[length(sectors)+1]]<-data.frame(term_id=nodes$term_id[i],
  x=nodes$x_mm[i],y=nodes$y_mm[i],r=nodes$disk_diameter_mm[i]/2,
  start=2*pi*(j-1)/length(ev),end=2*pi*j/length(ev),evidence=ev[j])
}
sectors<-do.call(rbind,sectors)
plot<-ggplot2::ggplot()
if(length(regions))plot<-plot+ggplot2::geom_rect(data=do.call(rbind,regions),
 ggplot2::aes(xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax,fill=fill),colour=NA)+ggplot2::scale_fill_identity()
# Use native fixed colours per evidence layer to keep semantic pies independent of background fills.
plot<-plot+ggplot2::geom_segment(data=edge_plot,ggplot2::aes(x=x,y=y,xend=xend,yend=yend),
 colour=pal$edge,linewidth=.08,alpha=.20)
for(ev in c('OE','KD','combined_only'))plot<-plot+ggforce::geom_arc_bar(data=sectors[sectors$evidence==ev,],
 ggplot2::aes(x0=x,y0=y,r0=0,r=r,start=start,end=end),fill=pal[[ev]],colour=NA,n=100)
for(st in c('Shared','Brown only','DPM only'))plot<-plot+ggforce::geom_circle(data=nodes[nodes$directional_status==st,],
 ggplot2::aes(x0=x_mm,y0=y_mm,r=disk_diameter_mm/2),fill=NA,colour=pal$outline,
 linewidth=.10,linetype=if(st=='Brown only')'dotted' else 'solid',n=100)
spikes<-function(tab){do.call(rbind,lapply(seq_len(nrow(tab)),function(i){a<-seq(0,2*pi,length.out=13)[-13];
 r<-tab$disk_diameter_mm[i]/2;data.frame(x=tab$x_mm[i]+cos(a)*r,y=tab$y_mm[i]+sin(a)*r,
 xend=tab$x_mm[i]+cos(a)*(r+.3),yend=tab$y_mm[i]+sin(a)*(r+.3))}))}
plot<-plot+ggplot2::geom_segment(data=spikes(nodes[nodes$directional_status=='DPM only',]),
 ggplot2::aes(x=x,y=y,xend=xend,yend=yend),linewidth=.10,colour=pal$outline)+
 ggplot2::geom_text(data=labels,ggplot2::aes(x=x,y=y,label=label,hjust=hjust),
  family=font$family,size=7.5/ggplot2::.pt,lineheight=1.05,colour='#30343B')
# Compact shared legends, all dimensions in actual target millimetres.
evlegend<-data.frame(x=c(9,30,51),y=16,r=1.4,label=c('OE','KD','combined-only'),fill=unlist(pal[c('OE','KD','combined_only')]))
for(i in 1:3)plot<-plot+ggforce::geom_circle(data=evlegend[i,],ggplot2::aes(x0=x,y0=y,r=r),
 fill=evlegend$fill[i],colour=pal$outline,linewidth=.10)+
 ggplot2::geom_text(data=evlegend[i,],ggplot2::aes(x=x+3,y=y,label=label),hjust=0,
 family=font$family,size=7.5/ggplot2::.pt)
dirlegend<-data.frame(x=c(85,114,146),y=16,disk_diameter_mm=2.8,label=c('Shared (132)','Brown-only (87)','DPM-only (6)'))
for(i in 1:3)plot<-plot+ggforce::geom_circle(data=dirlegend[i,],ggplot2::aes(x0=x,y0=y,r=disk_diameter_mm/2),
 fill='white',colour=pal$outline,linewidth=.10,linetype=if(i==2)'dotted' else 'solid')+
 ggplot2::geom_text(data=dirlegend[i,],ggplot2::aes(x=x+3,y=y,label=label),hjust=0,family=font$family,size=7.5/ggplot2::.pt)
sp<-dirlegend[3,];sp$x_mm<-sp$x;sp$y_mm<-sp$y
plot<-plot+ggplot2::geom_segment(data=spikes(sp),ggplot2::aes(x=x,y=y,xend=xend,yend=yend),linewidth=.10,colour=pal$outline)
sz<-data.frame(x=c(12,25,38),y=7,term_size=c(50,250,750));sz$r<-4.2*sqrt(sz$term_size/max(nodes$term_size))/2
plot<-plot+ggforce::geom_circle(data=sz,ggplot2::aes(x0=x,y0=y,r=r),fill='white',colour=pal$outline,linewidth=.10)+
 ggplot2::geom_text(data=sz,ggplot2::aes(x=x,y=2.8,label=as.character(term_size)),family=font$family,size=7.5/ggplot2::.pt)+
 ggplot2::annotate('text',x=45,y=7,label='Genes in pathway',hjust=0,family=font$family,size=7.5/ggplot2::.pt)+
 ggplot2::annotate('text',x=114,y=7,label='Labels: representative terms',hjust=0,family=font$family,size=7.5/ggplot2::.pt)+
 ggplot2::coord_fixed(xlim=c(0,width),ylim=c(0,height),expand=FALSE,clip='off')+
 ggplot2::theme_void(base_family=font$family,base_size=7.5)+ggplot2::theme(plot.margin=ggplot2::margin(0,0,0,0,'mm'),
  plot.background=ggplot2::element_rect(fill='white',colour=NA),panel.background=ggplot2::element_rect(fill='white',colour=NA))
macro<-data.frame(id=c('data','labels','legend'),x=c(5,5,5),y=c(10,10,142),w=c(170,170,170),h=c(131,131,19))
sources<-c(spec_path,file.path(root,'scripts','render.R'),file.path(skill,'scripts','figure_style.R'),
 paste0(prefix,'nodes.csv'),paste0(prefix,'edges.csv'),paste0(prefix,'memberships.csv'),plan_path,
 file.path(root,'data','raw','panelE_Rdata.Rdata'),file.path(root,'data','raw','hsapiens.GO_BP_REACTOME.name.gmt'))
png<-file.path(work,'dpm_fig3e_recolored.png')
receipt<-bf_render_png(plot,png,font=font,allowed_text=spec$text_contract$allowed_text,width_mm=width,height_mm=height,
 target_width_mm=width,dpi=600,min_text_pt=7.5,source_files=sources,boxes=macro,allowed_pairs='data:labels',
 authorization=authorization,skill_root=skill,publication_size_class='double-column')
pdf<-file.path(root,'results','figures','dpm_fig3e_recolored.pdf');dir.create(dirname(pdf),recursive=TRUE,showWarnings=FALSE)
grDevices::quartz(type='pdf',file=pdf,width=width/25.4,height=height/25.4,family=font$family,bg='white');print(plot);grDevices::dev.off()
svg<-file.path(work,'dpm_fig3e_recolored-gate-qa.svg');svglite::svglite(svg,width=width/25.4,height=height/25.4,bg='white',system_fonts=list(sans=font$family));print(plot);grDevices::dev.off()
bind<-function(p)list(path=normalizePath(p,mustWork=TRUE),sha256=digest::digest(file=p,algo='sha256'))
metrics<-list(scope=spec$scientific_message,nodes=225,edges=2183,components=25,isolates=11,
 direction_counts=as.list(table(nodes$directional_status)),seed=seed,edge_rule='full-GMT overlap coefficient>=0.5, all eligible pairs',
 layout='NEW sorted-ID FR component packing plus radius-aware collision relaxation; not recovered author Cytoscape coordinates',
 area_mapping='disk area proportional to saved author term_size; max disk diameter4.2mm; original final mapping unknown',
 palette=pal,evidence_pies='equal sectors for binary support, not quantitative contribution',
 geometry=list(canvas_mm=c(width,height),font_pt=7.5,max_diameter_mm=max(nodes$disk_diameter_mm),
  component_checks=component_metrics,label_extents_mm=labels,exclusive_boxes_mm=boxes,gate_envelopes=macro),
 source_files=lapply(sources,bind),plot_layout=bind(paste0(prefix,'layout.csv')),
 artifacts=list(pdf=bind(pdf),png=bind(png),svg_qa=bind(svg)),render_receipt=bind(paste0(png,'.render.json')),CP4='PENDING_REVIEW')
jsonlite::write_json(metrics,file.path(root,'results','tables','render-metrics.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
writeLines(capture.output(sessionInfo()),file.path(root,'data','metadata','R-sessionInfo.txt'))
writeLines(capture.output(print(font)),file.path(root,'data','metadata','resolved-font.txt'))
cat('FIG3E_RENDER_OK\n',pdf,'\n',png,'\n')
