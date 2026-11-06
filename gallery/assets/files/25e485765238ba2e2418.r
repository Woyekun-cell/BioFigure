#!/usr/bin/env Rscript
# Native ggtranscript tutorial reconstruction. Inputs and native package source are archived.
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==6L)
root<-normalizePath(args[1]);.libPaths(c(normalizePath(args[2]),.libPaths()))
out<-normalizePath(args[3]);task<-args[4];authorization<-normalizePath(args[5])
skill<-normalizePath(file.path(root,"../../../.."))
source(file.path(skill,"scripts/figure_style.R"))
suppressPackageStartupMessages({library(ggplot2);library(ggtranscript);library(dplyr)})
options(warn=2);Sys.setlocale("LC_COLLATE","C")
font<-bf_font("Arial");bf_complexheatmap_font(font);specpath<-normalizePath(args[6])
spec<-yaml::read_yaml(specpath);pal<-unlist(spec$palette_semantics)
width<-spec$output_size$width_mm;height<-spec$output_size$height_mm
size<-7.500001
rd<-function(name)read.csv(file.path(root,"results/plot_data",paste0(name,".csv")),stringsAsFactors=FALSE)
base_theme<-theme_classic(base_family=font$family,base_size=size)+
 theme(axis.text=element_text(size=size,colour=pal[["text"]]),
       axis.title=element_text(size=8.000001,colour=pal[["text"]]),
       axis.title.x=element_text(margin=margin(t=1.4,unit="mm")),
       axis.title.y=element_blank(),axis.line.y=element_blank(),axis.ticks.y=element_blank(),
       axis.ticks.length=unit(1,"mm"),axis.line.x=element_line(linewidth=.2,colour=pal[["intron"]]),
       axis.ticks.x=element_line(linewidth=.2,colour=pal[["intron"]]),
       plot.title=element_text(size=8.000001,face="bold",colour=pal[["text"]],margin=margin(b=2,unit="mm")),
       plot.tag=element_text(size=9.000001,face="bold",colour=pal[["text"]]),
       plot.margin=margin(1.3,2,1,1,"mm"),legend.position="none",
       plot.background=element_rect(fill="white",colour=NA),panel.background=element_rect(fill="white",colour=NA))
fmt<-function(x)format(x,trim=TRUE,big.mark=",",scientific=FALSE)
track<-function(e,i,compressed=TRUE,difference=NULL,title,tag){
 p<-ggplot(e,aes(xstart=start,xend=end,y=transcript_name))+
  geom_intron(data=i,aes(strand=strand),linewidth=.28,colour=pal[["intron"]],
              arrow=grid::arrow(length=unit(.9,"mm")),arrow.min.intron.length=if(compressed)300 else 500)
 if(is.null(difference)){
 p<-p+geom_range(aes(fill=transcript_biotype),height=.46,colour=pal[["intron"]],linewidth=.22)+
  scale_fill_manual(values=pal[c("protein_coding","processed_transcript","nonsense_mediated_decay","retained_intron")])
 }else{
 p<-p+geom_range(height=.46,fill=pal[["exon"]],colour=pal[["intron"]],linewidth=.22)+
  geom_range(data=difference,aes(fill=diff_type),height=.46,alpha=.52,colour=pal[["intron"]],linewidth=.18)+
  scale_fill_manual(values=pal[c("in_ref","not_in_ref")])
 }
 if(compressed){
 br<-if(max(e$end)<3000)c(0,500,1000,1500,2000,2500) else c(0,2500,5000,7500)
 p<-p+scale_x_continuous(breaks=br,labels=fmt,expand=expansion(mult=c(.012,.025)))
 }else p<-p+scale_x_continuous(breaks=c(31660000,31662500,31665000,31667500),labels=fmt,expand=expansion(mult=c(.012,.025)))
 p+scale_y_discrete(expand=expansion(add=.5))+
  labs(x=if(compressed)"Shortened coordinate (bp)" else "Genomic position (GRCh38, chr21, bp)",y=NULL,title=title,tag=tag)+base_theme
}
panels<-list();counts<-list()
if(task=="sod1-structure"){
 e<-rd("sod1_exons");i<-to_intron(e,"transcript_name");z<-shorten_gaps(e,i,"transcript_name",target_gap_width=100L)
 es<-filter(z,type=="exon");ins<-filter(z,type=="intron")
 stopifnot(nrow(e)==20L,nrow(i)==16L,n_distinct(e$transcript_name)==4L)
 p1<-track(e,i,FALSE,title="Exonic structure",tag="a")
 p2<-track(es,ins,TRUE,title="Shortened intronic gaps",tag="b")
 panels<-list(a=p1,b=p2)
 slots<-data.frame(id=c("a","b"),xmin=0,xmax=width,ymin=c(55,10),ymax=c(100,54))
 keys<-data.frame(x=c(28,73),y=c(4,4),fill=pal[c("protein_coding","processed_transcript")],
                  label=c("Protein-coding","Processed transcript"))
 counts<-list(transcripts_each=4,exons_each=20,introns_each=16,panels=2,source_complete=TRUE)
}else if(task=="pknox1-comparison"){
 e<-rd("pknox1_exons");i<-to_intron(e,"transcript_name");z<-shorten_gaps(e,i,"transcript_name",target_gap_width=100L)
 es<-filter(z,type=="exon");ins<-filter(z,type=="intron");ref<-filter(es,transcript_name=="PKNOX1-201")
 dif<-to_diff(filter(es,transcript_name!="PKNOX1-201"),ref,"transcript_name")
 p1<-track(es,ins,TRUE,title="Shortened intronic gaps",tag="a")
 p2<-track(es,ins,TRUE,difference=dif,title="Relative to PKNOX1-201",tag="b")
 e201<-ref;e203<-filter(es,transcript_name=="PKNOX1-203")
 p3<-ggplot(e201,aes(xstart=start,xend=end,y="PKNOX1-201 / PKNOX1-203"))+
  geom_intron(data=to_intron(e201,"transcript_name"),aes(strand=strand),linewidth=.28,colour=pal[["intron"]],arrow.min.intron.length=300,arrow=grid::arrow(length=unit(.9,"mm")))+
  geom_intron(data=to_intron(e203,"transcript_name"),aes(strand=strand),linewidth=.28,colour=pal[["intron"]],arrow.min.intron.length=300,arrow=grid::arrow(length=unit(.9,"mm")))+
  geom_half_range(fill=pal[["PKNOX1-201"]],height=.24,linewidth=.22,colour=pal[["intron"]])+
  geom_half_range(data=e203,range.orientation="top",fill=pal[["PKNOX1-203"]],height=.24,linewidth=.22,colour=pal[["intron"]])+
  scale_x_continuous(breaks=c(0,2500,5000,7500),labels=fmt,expand=expansion(mult=c(.012,.025)))+
  scale_y_discrete(expand=expansion(add=.33))+
  labs(x="Shortened coordinate (bp)",y=NULL,tag="c")+base_theme
 panels<-list(a=p1,b=p2,c=p3)
 slots<-data.frame(id=c("a","b","c"),xmin=c(0,92,0),xmax=c(88,180,180),ymin=c(44,44,0),ymax=c(119,119,30))
 keys<-data.frame(x=c(4,43,4,43,97,97,98,135),y=c(39,39,34,34,39,34,28,28),
   fill=pal[c("protein_coding","processed_transcript","nonsense_mediated_decay","retained_intron","in_ref","not_in_ref","PKNOX1-201","PKNOX1-203")],
   label=c("Protein-coding","Processed transcript","Nonsense-mediated decay","Retained intron","Present only in reference","Absent from reference","PKNOX1-201","PKNOX1-203"))
 stopifnot(nrow(es)==59L,nrow(ins)==48L,n_distinct(es$transcript_name)==11L,nrow(dif)==84L,nrow(e201)+nrow(e203)==21L)
 counts<-list(transcripts_each_top=11,exons_each_top=59,introns_each_top=48,difference_intervals=84,half_range_exons=21,half_range_introns=19,panels=3,source_complete=TRUE)
}else stop("Unknown task")
# Capture the genuine native ggtranscript grobs. Outer ggplot only places panels and legends.
grobs<-lapply(panels,ggplotGrob)
p<-ggplot()+coord_cartesian(xlim=c(0,width),ylim=c(0,height),expand=FALSE,clip="off")+
 theme_void(base_family=font$family,base_size=size)+
 theme(plot.margin=margin(0,0,0,0),plot.background=element_rect(fill="white",colour=NA))
for(k in seq_len(nrow(slots)))p<-p+annotation_custom(grobs[[slots$id[k]]],xmin=slots$xmin[k],xmax=slots$xmax[k],ymin=slots$ymin[k],ymax=slots$ymax[k])
p<-p+geom_rect(data=keys,aes(xmin=x,xmax=x+2.3,ymin=y-.9,ymax=y+.9),fill=keys$fill,colour=pal[["intron"]],linewidth=.18)+
 geom_text(data=keys,aes(x=x+3.6,y=y,label=label),hjust=0,vjust=.5,family=font$family,size=size/.pt,colour=pal[["text"]])
sources<-c(specpath,file.path(root,"scripts/render.R"),file.path(root,"scripts/prepare_data.R"),
 file.path(root,"data/metadata/data-qc.json"),file.path(skill,"scripts/figure_style.R"),
 list.files(file.path(root,"results/plot_data"),full.names=TRUE),
 file.path(root,"sources/R",c("geom_range.R","geom_intron.R","geom_half_range.R","shorten_gaps.R","to_intron.R","to_diff.R")))
# Macro regions document the outer composition; native panel metrics and PDF text audit verify internals.
macro<-if(task=="sod1-structure")data.frame(id=c("data","labels","lower","legend"),x=0,y=c(55,55,10,0),w=width,h=c(45,45,44,9)) else data.frame(id=c("data","labels","right","legend","half"),x=c(0,0,92,0,0),y=c(44,44,44,31,0),w=c(88,88,88,180,180),h=c(75,75,75,12,30))
png<-file.path(out,paste0(task,".png"))
bf_render_png(p,png,font,spec$text_contract$allowed_text,width,height,width,sources,macro,
 allowed_pairs="data:labels",dpi=600,min_text_pt=7.5,authorization=authorization,skill_root=skill,publication_size_class=spec$output_size$size_class)
pdf<-file.path(out,paste0(task,".pdf"));grDevices::quartz(type="pdf",file=pdf,width=width/25.4,height=height/25.4,family=font$family,bg="white");print(p);dev.off()
svg<-file.path(out,paste0(task,".svg"));svglite::svglite(svg,width=width/25.4,height=height/25.4,bg="white",system_fonts=list(sans=font$family));print(p);dev.off()
layer_counts<-lapply(panels,function(g)lapply(seq_along(g$layers),function(j)list(native_geom=class(g$layers[[j]]$geom)[1],rows=nrow(ggplot_build(g)$data[[j]]))))
bind<-function(f)list(path=normalizePath(f),sha256=digest::digest(file=f,algo="sha256"))
pk<-c("ggtranscript","ggplot2","GenomicRanges","GenomeInfoDb","UCSC.utils","IRanges","S4Vectors","Seqinfo","ragg","systemfonts","svglite")
metrics<-list(schema_version=1,task=task,counts=counts,native_geoms=layer_counts,palette=as.list(pal),
 coordinate_policy=list(input="Ensembl105 GRCh38 one-based closed",display="genomic or explicitly shortened coordinate",gap_width=100,all_exon_lengths_preserved=TRUE),
 layout=list(canvas_mm=c(width,height),slots=slots,minimum_text_pt=size,legend_rows=keys),
 environment=list(R=R.version.string,platform=R.version$platform,packages=as.list(setNames(vapply(pk,function(k)as.character(packageVersion(k)),character(1)),pk))),
 source_files=lapply(sources,bind),artifacts=list(pdf=bind(pdf),png=bind(png),svg=bind(svg)),font=bind(font$path),
 native_functions_executed=c("geom_range","geom_intron","to_intron","shorten_gaps",if(task=="pknox1-comparison")c("geom_half_range","to_diff")),
 source_functions_read_not_rendered=c("geom_junction","geom_junction_label_repel"),
 scientific_inference="none",whole_original_paper="NOT_VERIFIED",arbitrary_input_transfer="NOT_VERIFIED",CP4="PENDING_ACTUAL_VIEW")
jsonlite::write_json(metrics,file.path(out,paste0(task,"-metrics.json")),auto_unbox=TRUE,pretty=TRUE,digits=17)
capture.output(sessionInfo(),file=file.path(out,paste0(task,"-session.txt")))
cat("NATIVE_RENDER_COMPLETE:",png,"\n")

