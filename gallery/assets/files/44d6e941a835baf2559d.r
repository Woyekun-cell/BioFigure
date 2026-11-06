#!/usr/bin/env Rscript
# Exact author processed coordinate replot, native BUSCOplot, requested new colors.
# Created only after fresh BioFigure CP2 validation. No raw NGS or simulation.
suppressPackageStartupMessages({library(ggplot2);library(cowplot);library(yaml);library(jsonlite)})
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)%in%c(4L,6L))
root<-normalizePath(args[1]);work<-normalizePath(args[2]);auth<-normalizePath(args[3]);tasklib<-normalizePath(args[4])
out<-if(length(args)==6L)normalizePath(args[5]) else root
.libPaths(c(tasklib,.libPaths()))
stopifnot(requireNamespace("BUSCOplot",quietly=TRUE))
skill<-normalizePath(file.path(root,"../../../../../.."))
source(file.path(skill,"scripts/figure_style.R"))
font<-bf_font("Arial");options(warn=2);cowplot::set_null_device("agg")
formal<-basename(root)=="busco-chr7-cassette"
spec_path<-if(length(args)==6L)normalizePath(args[6]) else file.path(root,"data/metadata/design-spec.yaml");design<-read_yaml(spec_path)
width<-design$output_size$width_mm;height<-design$output_size$height_mm
lock<-fromJSON(file.path(root,"data/metadata/source-lock.json"))
for(i in seq_len(nrow(lock$assets))){
 a<-lock$assets[i,];stopifnot(digest::digest(file=file.path(root,a$path),algo="sha256")==a$sha256)
}
code<-readLines(file.path(root,"sources/author",if(formal)"BUSCOchrom7.Rmd" else "BUSCOpublic.Rmd"),warn=FALSE)
env<-new.env(parent=globalenv());run<-function(first,last)eval(parse(text=code[first:last]),envir=env)
wd<-getwd();setwd(file.path(root,"data/raw"))
if(formal){
 for(rng in list(c(26,45),c(53,54),c(60,71),c(79,112)))run(rng[1],rng[2])
 original<-env$busc;low_original<-env$my_df;high_original<-env$my_cann
 run(182,196);busc<-env$busc;low<-env$my_df;high<-env$my_cann;anchor<-env$my_min
 group<-rep(c("I","II","III","IV"),times=c(ncol(env$type1),ncol(env$type2),ncol(env$type3),ncol(env$type4)))
 stopifnot(nrow(busc)==147L,ncol(busc)==76L,sum(!is.na(busc))==10744L)
 visible<-function(x)!is.na(x)&x>=0&x<=4.1e6
 stopifnot(sum(visible(as.matrix(busc)))==173L,sum(visible(low$sstart))==2600L,sum(visible(high$sstart))==106L)
}else{
 for(rng in list(c(23,28),c(34,42),c(51,52),c(60,67),c(90,94),c(116,118)))run(rng[1],rng[2])
 busc<-env$busc;original<-busc;high<-env$cbdas;high_original<-high;anchor<-setNames(rep(0,ncol(busc)),colnames(busc))
 group<-rep(NA_character_,ncol(busc));visible<-function(x)is.finite(x)
 stopifnot(nrow(busc)==147L,ncol(busc)==31L,sum(!is.na(busc))==4254L,nrow(high)==31L,sum(high$sstart>high$send)==23L)
}
setwd(wd)
for(folder in c("results/plot_data","results/figures","data/metadata","evidence"))dir.create(file.path(out,folder),recursive=TRUE,showWarnings=FALSE)
samples<-colnames(busc)
busco_csv<-data.frame(busco_id=rep(rownames(busc),times=ncol(busc)),sample=rep(samples,each=nrow(busc)),
 original_bp=as.vector(as.matrix(original)),anchor_bp=rep(unname(anchor),each=nrow(busc)),
 display_bp=as.vector(as.matrix(busc)),sample_index=rep(seq_along(samples),each=nrow(busc)),
 stringsAsFactors=FALSE)
busco_csv$visible<-visible(busco_csv$display_bp)
write.csv(busco_csv,file.path(out,"results/plot_data/busco-coordinates.csv"),row.names=FALSE,na="")
sample_csv<-data.frame(sample=samples,sample_index=seq_along(samples),chemotype=group,
 source_role=ifelse(samples%in%c("CBDRx","Abacus","Finola"),"public-reference","study-assembly"))
write.csv(sample_csv,file.path(out,"results/plot_data/sample-order.csv"),row.names=FALSE,na="")
qs<-c("AB212829.1"="THCAS","AB292682.1"="CBDAS","LY658671.1"="CBCAS")
marker_frame<-function(d,orig,level){
 sample<-if(formal)d$Sample else d$sseqid
 data.frame(qseqid=d$qseqid,sample=sample,sseqid=d$sseqid,source_sstart_bp=orig$sstart,
 display_bp=d$sstart,pident=d$pident,gaps=d$gaps,stringency=level,
 synthase=unname(qs[d$qseqid]),visible=visible(d$sstart),sample_index=match(sample,samples),
 source_send_bp=orig$send,stringsAsFactors=FALSE)
}
markers<-if(formal)rbind(marker_frame(low,low_original,"low"),marker_frame(high,high_original,"high"))else marker_frame(high,high_original,"high")
stopifnot(!anyNA(markers$sample_index))
write.csv(markers,file.path(out,"results/plot_data/synthase-markers.csv"),row.names=FALSE,na="")
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
ids<-sort(unique(native$data$Busco_id))
cycle<-strsplit(design$palette_semantics$BUSCO_cycle,",",fixed=TRUE)[[1]]
pal<-setNames(rep(cycle,length.out=length(ids)),ids)
palette_csv<-data.frame(busco_id=ids,color=unname(pal))
write.csv(palette_csv,file.path(out,"results/plot_data/busco-palette.csv"),row.names=FALSE)
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
ratio<-bbox["w"]/bbox["h"];source_ratio<-if(formal)1.5 else 1.65
stopifnot(abs(ratio/source_ratio-1)<.05)
composite<-ggdraw()+draw_plot(main,x=main_slot["x"]/width,y=main_slot["y"]/height,
 width=main_slot["w"]/width,height=main_slot["h"]/height)+
 draw_label(if(formal)"Fig.4d | Author data" else "Author public chr7 | Author data",
 x=bbox["x"]/width,y=(height-1)/height,hjust=0,vjust=1,fontfamily=font$family,size=8,fontface="plain")
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
qc<-list(schema_version=1,status="AUTHOR_PROCESSED_DATA_REPLOT_QC_PASS",method_id=lock$method_id,
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
 scope="Only selected author processed-data panel, requested new color scheme; not full original figure, new-input transfer or stable reuse")
write_json(qc,file.path(out,"evidence/scientific-checks.json"),pretty=TRUE,auto_unbox=TRUE)
sources<-c(spec_path,file.path(root,"scripts/render.R"),file.path(skill,"scripts/figure_style.R"),
 file.path(root,"data/metadata/source-lock.json"),file.path(root,lock$assets$path))
name<-if(formal)"fig4d-author-recolored" else "author-public-chr7-recolored"
preview<-file.path(work,paste0(name,".png"))
boxes<-data.frame(id=c("data","labels","legend"),x=c(bbox["x"],bbox["x"],legend_slot["x"]),
 y=c(bbox["y"],height-8,legend_slot["y"]),w=c(bbox["w"],if(formal)140 else 110,legend_slot["w"]),
 h=c(bbox["h"],7,legend_slot["h"]))
receipt<-bf_render_png(composite,preview,font,design$text_contract$allowed_text,width,height,width,sources,boxes,
 authorization=auth,skill_root=skill,publication_size_class="double-column",min_text_pt=7,
 heading_authorization="User requested selected author-data panel recolor; panel identifier records scope only")
grDevices::quartz(type="pdf",file=file.path(out,"results/figures",paste0(name,".pdf")),
 width=width/25.4,height=height/25.4,family=font$family)
print(composite);invisible(dev.off())
ggsave(file.path(work,paste0(name,".svg")),composite,device=svglite::svglite,width=width,height=height,units="mm",bg="white")
file.copy(preview,file.path(work,"first-color-render.png"),overwrite=FALSE)
file.copy(paste0(preview,".render.json"),file.path(out,"evidence/render-receipt.json"),overwrite=TRUE)
writeLines(capture.output(sessionInfo()),file.path(out,"data/metadata/environment.txt"))
packages<-c("BUSCOplot","ggplot2","cowplot","ragg","yaml","jsonlite","systemfonts","digest","svglite")
write_json(list(R=R.version.string,packages=as.list(setNames(vapply(packages,function(p)as.character(packageVersion(p)),character(1)),packages)),
 font=font,native_package_commit=lock$native_package_commit,seed=NULL,seed_basis="No stochastic operation; exact author coordinates"),
 file.path(out,"data/metadata/environment.json"),pretty=TRUE,auto_unbox=TRUE)
cat("AUTHORIZED_NATIVE_BUSCOPLOT_RENDER_OK",name,"data_aspect",ratio,"points",point_counts,"\n")
