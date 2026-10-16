#!/usr/bin/env Rscript
# Fresh gated public packaged-table replay using native BUSCOplot.
# Scope: current published derived tables and own gallery layout, not author raw workflow.
suppressPackageStartupMessages({library(ggplot2);library(cowplot);library(yaml);library(jsonlite)})
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==7L)
root<-normalizePath(args[1]);work<-normalizePath(args[2]);auth<-normalizePath(args[3]);tasklib<-normalizePath(args[4])
out<-normalizePath(args[5]);spec_path<-normalizePath(args[6]);native_root<-normalizePath(args[7])
.libPaths(c(tasklib,.libPaths()));stopifnot(requireNamespace("BUSCOplot",quietly=TRUE))
skill<-root
while(!file.exists(file.path(skill,"SKILL.md"))||!file.exists(file.path(skill,"scripts/prepare_figure.py"))){
 next_root<-dirname(skill);stopifnot(next_root!=skill);skill<-next_root
}
source(file.path(skill,"scripts/figure_style.R"));source(file.path(root,"scripts/audit_inputs.R"))
font<-bf_font("Arial");options(warn=2);cowplot::set_null_device("agg")
x<-load_public_inputs(root);formal<-x$formal;lock<-x$lock;busc<-x$busc;low<-x$low;high<-x$high
busco_csv<-x$busco;sample_csv<-x$sample_csv;markers<-x$markers;samples<-colnames(busc)
qs<-c("AB212829.1"="THCAS","AB292682.1"="CBDAS","LY658671.1"="CBCAS")
design<-read_yaml(spec_path);width<-design$output_size$width_mm;height<-design$output_size$height_mm
acquisition<-fromJSON(file.path(root,"data/metadata/native-acquisition.json"))
for(i in seq_len(nrow(acquisition$assets))){
 a<-acquisition$assets[i,];p<-file.path(native_root,a$path)
 stopifnot(file.exists(p),file.info(p)$size==a$bytes,digest::digest(file=p,algo="sha256")==a$sha256)
}
for(folder in c("results/plot_data","results/figures","data/metadata","evidence"))dir.create(file.path(out,folder),recursive=TRUE,showWarnings=FALSE)
for(n in c("busco-coordinates.csv","busco-palette.csv","sample-order.csv","synthase-markers.csv")){
 stopifnot(file.copy(file.path(root,"results/plot_data",n),file.path(out,"results/plot_data",n),overwrite=FALSE))
}
expected_warnings<-character()
native<-withCallingHandlers(BUSCOplot::gg_line_map(busc,check_table=FALSE,
 palpha=if(formal)0.32 else 0.8,size=if(formal)1.4 else 1.2,
 lalpha=if(formal)0.15 else 0.2,linewidth=if(formal)0.8 else 1.0),
 warning=function(w){
  msg<-conditionMessage(w)
  if(identical(msg,"Check for BUSCO table disabled, the user is responsible for results!")){
   expected_warnings<<-c(expected_warnings,msg);invokeRestart("muffleWarning")
  }
 })
# The native function supplies all ortholog/sample factor semantics and line grouping.
# Only replace its categorical hue scale; expected local scale censoring is audited.
native$layers[[1]]$geom_params$na.rm<-TRUE
ids<-sort(unique(native$data$Busco_id));pal<-setNames(x$palette$color,x$palette$busco_id)
stopifnot(setequal(names(pal),ids),!anyDuplicated(names(pal)))
main<-suppressMessages(native+scale_color_manual(values=pal))
base_theme<-bf_theme(font,size=7)+theme(
 plot.margin=margin(1,1,1,1,"mm"),
 axis.line=element_line(linewidth=0.18,colour="#3E454A"),
 axis.ticks=element_line(linewidth=0.18,colour="#3E454A"),axis.ticks.length=grid::unit(0.8,"mm"),
 axis.title.y=element_text(size=7,margin=margin(r=1.8,unit="mm")),
 axis.title.x=element_blank(),axis.text.y=element_text(size=7),
 legend.position="none",panel.border=element_blank(),
 panel.grid.minor=element_blank(),
 panel.grid.major=element_line(linewidth=0.12,colour="#E3E6E8"))
main<-main+labs(x=NULL,y="Position (Mb)")+base_theme
if(formal){
 low$Sample<-factor(low$Sample,levels=samples);high$Sample<-factor(high$Sample,levels=samples)
 hc<-unname(unlist(design$palette_semantics[unname(qs[high$qseqid])]))
 main<-main+
  geom_point(data=low,aes(x=Sample,y=sstart),inherit.aes=FALSE,shape=24,size=2.2,stroke=0.28,
   fill="#8E939840",colour="#757B8040",na.rm=TRUE)+
  geom_point(data=high,aes(x=Sample,y=sstart),inherit.aes=FALSE,shape=24,size=2.2,stroke=0.28,
   fill=hc,colour="#39434B",na.rm=TRUE)
 main<-suppressMessages(main+scale_y_continuous(breaks=seq(0,4e6,1e6),labels=as.character(0:4),
  minor_breaks=NULL,limits=c(0,4.1e6),expand=expansion(mult=c(.02,.025))))+
  scale_x_discrete(expand=expansion(add=.65))+
  annotate("text",x=16,y=2e5,label="BUSCO:127689at71240",family=font$family,size=7/.pt,hjust=.5)+
  theme(axis.text.x=element_blank(),axis.ticks.x=element_blank(),
    panel.grid=element_blank(),panel.grid.major=element_blank(),panel.grid.minor=element_blank())
 main_slot<-c(x=.5,y=3,w=161,h=105);legend_slot<-c(x=163,y=3,w=16,h=105)
 keys<-data.frame(label=c("Low-stringency","THCAS","CBDAS","CBCAS"),y=c(18,42,66,90),
  fill=c("#8E939840",unlist(design$palette_semantics[c("THCAS","CBDAS","CBCAS")])))
 key<-ggplot()+
  geom_point(data=keys,aes(x=4,y=y),shape=24,size=2.8,stroke=.3,fill=keys$fill,colour="#39434B")+
  geom_text(data=keys,aes(x=9,y=y-8,label=label),family=font$family,size=7/.pt,angle=270,hjust=.5)+
  coord_cartesian(xlim=c(0,16),ylim=c(0,105),expand=FALSE,clip="on")+
  theme_void(base_family=font$family,base_size=7)+theme(plot.margin=margin(0,0,0,0,"mm"))
}else{
 high$sseqid<-factor(high$sseqid,levels=samples)
 hc<-design$palette_semantics$CBDAS
 main<-main+
  geom_line(data=high,aes(x=sseqid,y=sstart,group=1),inherit.aes=FALSE,linewidth=1.2,colour=hc)+
  geom_point(data=high,aes(x=sseqid,y=sstart),inherit.aes=FALSE,shape=24,size=4,stroke=.4,fill=hc,colour="#273C46")+
  theme(axis.text.x=element_text(angle=60,hjust=1,vjust=1,size=7,colour="#30373D"),
    panel.grid.major.x=element_line(linewidth=.12,colour="#EBEDEF"))
 main_slot<-c(x=.5,y=1,w=179,h=111);legend_slot<-c(x=128,y=113,w=49,h=5)
}
# Measure native gtable's actual final physical data rectangle; no scientific redraw.
measure<-file.path(work,"gtable-measurement.png")
ragg::agg_png(measure,width=width,height=height,units="mm",res=300)
g<-ggplotGrob(main);pi<-g$layout[g$layout$name=="panel",]
left<-grid::convertWidth(sum(g$widths[seq_len(pi$l-1)]),"mm",valueOnly=TRUE)
right<-grid::convertWidth(sum(g$widths[(pi$r+1):length(g$widths)]),"mm",valueOnly=TRUE)
top<-grid::convertHeight(sum(g$heights[seq_len(pi$t-1)]),"mm",valueOnly=TRUE)
bottom<-grid::convertHeight(sum(g$heights[(pi$b+1):length(g$heights)]),"mm",valueOnly=TRUE)
invisible(dev.off())
bbox<-c(x=unname(main_slot["x"]+left),y=unname(main_slot["y"]+bottom),
 w=unname(main_slot["w"]-left-right),h=unname(main_slot["h"]-top-bottom))
ratio<-bbox["w"]/bbox["h"];source_ratio<-design$reference_evidence$source_density_contract$data_aspect
stopifnot(abs(ratio/source_ratio-1)<.05)
composite<-ggdraw()+draw_plot(main,x=main_slot["x"]/width,y=main_slot["y"]/height,
 width=main_slot["w"]/width,height=main_slot["h"]/height)
if(formal){
 composite<-composite+draw_plot(key,x=legend_slot["x"]/width,y=legend_slot["y"]/height,
  width=legend_slot["w"]/width,height=legend_slot["h"]/height)
 centers<-c(20,40.5,58.5,72.5)
 # Match discrete sample coordinate expansion: 0.35..76.65.
 xx<-bbox["x"]+(centers-.35)/(76.65-.35)*bbox["w"]
 labs<-c("THCAS\nChemotype I","THCAS:CBDAS\nChemotype II","CBDAS\nChemotype III","Chemotype IV")
 col<-unlist(design$palette_semantics[paste0("Chemotype ",c("I","II","III","IV"))])
 for(i in seq_along(xx))composite<-composite+draw_label(labs[i],x=xx[i]/width,y=110/height,
  fontfamily=font$family,size=7,color=col[i],hjust=.5,vjust=.5,lineheight=1.05)
}else{
 composite<-composite+draw_label("CBDAS",x=173/width,y=116/height,hjust=1,vjust=.5,
  fontfamily=font$family,size=7,color=hc)
}
built<-ggplot_build(main)
finite_count<-function(d)sum(is.finite(d$x)&is.finite(d$y))
point_counts<-if(formal)c(BUSCO=finite_count(built$data[[1]]),low=finite_count(built$data[[3]]),high=finite_count(built$data[[4]]))else
 c(BUSCO=finite_count(built$data[[1]]),CBDAS_path=finite_count(built$data[[3]]),CBDAS_markers=finite_count(built$data[[4]]))
stopifnot(identical(unname(point_counts),if(formal)c(173L,2600L,106L)else c(4254L,31L,31L)))
metrics<-list(schema_version=1,units="mm",final_canvas=list(width=width,height=height),
 main_slot=as.list(main_slot),legend_slot=as.list(legend_slot),actual_data_bbox=as.list(bbox),
 native_gtable_margins=list(left=left,right=right,top=top,bottom=bottom),
 source_data_aspect_approx=source_ratio,actual_inner_aspect=unname(ratio),relative_aspect_error=unname(abs(ratio/source_ratio-1)),
 aspect_tolerance=.05,sample_pitch_mm=unname(bbox["w"]/length(samples)),
 x_label_angle=if(formal)NULL else 60,minimum_font_pt=7,
 required_plot_data_counts=as.list(point_counts),source_density_reason="Original point density and full sample ordering preserved; dense source overlaps and large public-reference crossings intentionally retained")
write_json(metrics,file.path(out,"evidence/layout-metrics.json"),pretty=TRUE,auto_unbox=TRUE)
qc<-list(schema_version=1,status="CURRENT_PUBLIC_TABLE_NATIVE_REPLAY_QC_PASS",method_id=lock$method_id,
 native_function="BUSCOplot::gg_line_map",native_package_commit=lock$native_package_commit,
 simulated_data=FALSE,raw_pipeline_run=FALSE,statistics_required=FALSE,
 source_selected_dimensions=c(rows=nrow(busc),samples=ncol(busc)),plot_data_cells=nrow(busco_csv),
 finite_busco_cells=sum(is.finite(busco_csv$display_bp)),missing_busco_cells=sum(is.na(busco_csv$display_bp)),
 plotted_point_counts=as.list(point_counts),marker_rows=nrow(markers),
 visible_marker_rows=sum(markers$visible),source_order_preserved=identical(samples,sample_csv$sample),
 source_anchor_policy=if(formal)"NLv1b missing anchor offset mean-imputed; absent BUSCO point not invented" else "No anchor",
 reverse_hit_sstart_policy="Point position retains original BLAST sstart; no endpoint swap or wholechromosome flip",
 native_NA_policy="Remove NA rows before native geom_line, may connect nonadjacent retained samples",
 expected_native_warnings=expected_warnings,
 scope="Public fixed packaged plotCSV/current own layout native replay only; original raw workflow, full original fidelity, new-input transfer and stable reuse NOT_VERIFIED")
write_json(qc,file.path(out,"evidence/scientific-checks.json"),pretty=TRUE,auto_unbox=TRUE)
sources<-unique(c(spec_path,file.path(root,"scripts/render.R"),file.path(skill,"scripts/figure_style.R"),
 file.path(root,"data/metadata/source-lock.json"),file.path(root,lock$assets$path[!grepl("\\.ya?ml$",lock$assets$path)]),
 file.path(native_root,acquisition$assets$path)))
name<-if(formal)"fig4d-author-recolored" else "author-public-chr7-recolored"
preview<-file.path(work,paste0(name,".png"))
boxes<-data.frame(id=c("data","labels","legend"),x=c(bbox["x"],bbox["x"],legend_slot["x"]),
 y=c(bbox["y"],height-8,legend_slot["y"]),w=c(bbox["w"],if(formal)140 else 110,legend_slot["w"]),
 h=c(bbox["h"],7,legend_slot["h"]))
receipt<-bf_render_png(composite,preview,font,design$text_contract$allowed_text,width,height,width,sources,boxes,
 authorization=auth,skill_root=skill,publication_size_class="double-column",min_text_pt=7,
 heading_authorization="User requested selected author-data panel recolor; panel identifier records scope only")
pdf_path<-file.path(out,"results/figures",paste0(name,".pdf"))
if(capabilities("aqua")){grDevices::quartz(type="pdf",file=pdf_path,width=width/25.4,height=height/25.4,family=font$family)
}else{grDevices::cairo_pdf(filename=pdf_path,width=width/25.4,height=height/25.4,family=font$family)}
print(composite);invisible(dev.off())
ggsave(file.path(work,paste0(name,".svg")),composite,device=svglite::svglite,width=width,height=height,units="mm",bg="white")
file.copy(preview,file.path(work,"first-color-render.png"),overwrite=FALSE)
file.copy(paste0(preview,".render.json"),file.path(out,"evidence/render-receipt.json"),overwrite=TRUE)
writeLines(capture.output(sessionInfo()),file.path(out,"data/metadata/environment.txt"))
packages<-c("BUSCOplot","ggplot2","cowplot","ragg","yaml","jsonlite","systemfonts","digest","svglite")
write_json(list(R=R.version.string,packages=as.list(setNames(vapply(packages,function(p)as.character(packageVersion(p)),character(1)),packages)),
 font=font,native_package_commit=lock$native_package_commit,seed=NULL,seed_basis="No stochastic operation; packaged published coordinates"),
 file.path(out,"data/metadata/environment.json"),pretty=TRUE,auto_unbox=TRUE)
cat("AUTHORIZED_NATIVE_BUSCOPLOT_RENDER_OK",name,"data_aspect",ratio,"points",point_counts,"\n")
