#!/usr/bin/env Rscript
# Native ComplexHeatmap reconstruction of published Fig3a/b final source tables.
# Author source remains a separate private study; no NGS or new inference.
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==3L)
root<-normalizePath(args[1]);work<-normalizePath(args[2]);authorization<-normalizePath(args[3])
skill<-Sys.getenv("BIOFIGURE_SKILL_ROOT",normalizePath(file.path(root,"../../../..")))
source(file.path(skill,"scripts/figure_style.R"))
options(warn=2);set.seed(3403);Sys.setlocale("LC_COLLATE","C")
font<-bf_font("Arial");bf_complexheatmap_font(font)
spec_path<-file.path(root,"data/metadata/design-spec.yaml");spec<-yaml::read_yaml(spec_path)
pal<-unlist(spec$palette_semantics);width<-180;height<-160
stopifnot(spec$output_size$width_mm==width,spec$output_size$height_mm==height)
paths<-file.path(root,"data/plot_data",c("motif_matrix.csv","motif_annotation.csv","te_annotation.csv","te_scatter.csv","ame_results.csv"))
mx<-read.csv(paths[1],check.names=FALSE,stringsAsFactors=FALSE);mat<-as.matrix(mx[-1]);rownames(mat)<-mx$motif
ma<-read.csv(paths[2],check.names=FALSE,stringsAsFactors=FALSE);ta<-read.csv(paths[3],check.names=FALSE,stringsAsFactors=FALSE)
sc<-read.csv(paths[4],check.names=FALSE,stringsAsFactors=FALSE,na.strings="");qc_path<-file.path(root,"data/metadata/data-qc.json")
stopifnot(identical(dim(mat),c(14L,35L)),nrow(sc)==558L,sum(mat<0)==18L,all(is.finite(mat)),!anyDuplicated(rownames(mat)),!anyDuplicated(colnames(mat)),identical(ma$motif_original,rownames(mat)),identical(ta$subfamily,colnames(mat)))
groups<-factor(ta$enrichment_group,levels=c("Common","GP5d","HepG2"));stopifnot(identical(as.integer(table(groups)),c(10L,12L,13L)))
rowcols<-rep(pal[["text"]],14);rowcols[ma$motif_id=="AC0240"]<-pal[["HepG2"]];rowcols[ma$motif_id=="AC0498"]<-pal[["GP5d"]]
columncols<-unname(pal[as.character(groups)])
heatcol<-circlize::colorRamp2(c(-.2,0,.8,2,4),c(pal[["heat_negative"]],pal[["heat_zero"]],"#BCE0DB","#4FA6AD",pal[["heat_positive"]]))
ht<-ComplexHeatmap::Heatmap(mat,name="Scaled -log10(E-value)",col=heatcol,
  row_labels=ma$display_label,column_split=groups,cluster_rows=TRUE,cluster_columns=TRUE,
  cluster_column_slices=FALSE,cluster_row_slices=FALSE,clustering_method_rows="ward.D2",
  clustering_method_columns="ward.D2",show_row_dend=TRUE,show_column_dend=TRUE,
  row_dend_width=grid::unit(10,"mm"),column_dend_height=grid::unit(10,"mm"),
  width=grid::unit(125,"mm"),height=grid::unit(44,"mm"),column_gap=grid::unit(1.8,"mm"),
  rect_gp=grid::gpar(col="#CCCFCB",lwd=.4),use_raster=FALSE,
  row_names_gp=grid::gpar(fontfamily=font$family,fontsize=7.500001,col=rowcols),
  row_names_side="right",row_names_max_width=grid::unit(26,"mm"),
  column_names_gp=grid::gpar(fontfamily=font$family,fontsize=7.500001,col=columncols),
  column_names_rot=90,column_names_max_height=grid::unit(20,"mm"),
  column_title_gp=grid::gpar(fontfamily=font$family,fontsize=8.000001,fontface="bold",col=unname(pal[c("Common","GP5d","HepG2")])),
  row_title_gp=grid::gpar(fontfamily=font$family,fontsize=8.000001),
  heatmap_legend_param=list(direction="horizontal",at=c(-.2,0,1,2,3,4),labels=c("-0.2","0","1","2","3","4"),
    title_gp=grid::gpar(fontfamily=font$family,fontsize=8.000001),labels_gp=grid::gpar(fontfamily=font$family,fontsize=7.500001),
    legend_width=grid::unit(50,"mm"),title_position="topcenter",border="#647679"))
drawn_ht<-NULL
heat_grob<-grid::grid.grabExpr({drawn_ht<<-ComplexHeatmap::draw(ht,heatmap_legend_side="bottom",padding=grid::unit(c(2,1,1,1),"mm"))},width=180/25.4,height=96/25.4,warn=0,wrap=TRUE,wrap.grobs=TRUE)
heat_grob<-grid::grid.force(heat_grob)
row_order<-ComplexHeatmap::row_order(drawn_ht);col_order<-ComplexHeatmap::column_order(drawn_ht)
stopifnot(length(row_order)==14L,length(col_order)==3L,setequal(unlist(col_order),1:35))
family_label<-function(x,panel){
 if(panel=="left")return(sub("^MER61[[:alnum:]]+$","MER61",sub("^LTR10[[:alnum:]]+$","LTR10",x)))
 x<-sub("^MER11[ABCD]$","MER11",x);x<-sub("^MER44[BCD]$","MER44",x);x<-sub("^MER52[ACD]$","MER52",x)
 x<-sub("^LTR12[_CDF]*$","LTR12",x);x<-sub("^LTR14[BC]$","LTR14",x);x<-sub("^LTR7[BY]?$","LTR7",x)
 x<-sub("^LTR10[[:alnum:]]+$","LTR10",x);sub("^THE1[ABCD]$","THE1",x)
}
scatter_metrics<-list();scatter_grobs<-list()
for(pn in c("left","right")){
 d<-sc[sc$panel==pn,];d$point_size<-ifelse(d$fisher_sig=="insig",.35,1.35)
 labels<-d[!is.na(d$lab)&d$lab!="NA",];labels$family<-family_label(labels$lab,pn)
 label_groups<-split(labels,labels$family)
 ld<-do.call(rbind,lapply(label_groups,function(z){data.frame(label=z$family[1],x=10^mean(log10(z$display_x)),y=10^mean(log10(z$display_y)))}))
 keep<-if(pn=="left")c("LTR7C","MER50C","LTR10","LTR18A","MER61") else c("LTR14","LTR7","HSMAR2","MER11","MER44","LTR12","MER52","THE1","LTR10")
 ld<-ld[match(keep,ld$label),];stopifnot(!anyNA(ld$label))
 if(pn=="left"){ld$x<-c(14,19,155,75,235);ld$y<-c(150,75,65,42,290)}else{ld$x<-c(.25,.85,5,.4,7,155,50,1,120);ld$y<-c(120,125,26,4.8,2.4,1.1,.28,.45,260)}
 leaders<-do.call(rbind,lapply(seq_len(nrow(ld)),function(i){z<-labels[labels$family==ld$label[i],];data.frame(x=z$display_x,y=z$display_y,xend=ld$x[i],yend=ld$y[i])}))
 if(pn=="right")ld$colour<-ifelse(ld$label%in%c("MER11","LTR7","LTR14"),pal[["GP5d"]],ifelse(ld$label%in%c("LTR12","MER44","MER52","THE1"),pal[["HepG2"]],pal[["text"]])) else ld$colour<-pal[["text"]]
 p<-ggplot2::ggplot(d,ggplot2::aes(display_x,display_y))+
  ggplot2::geom_abline(slope=1,intercept=0,colour="#BBC3C5",linetype="dashed",linewidth=.3)+
  ggplot2::geom_point(ggplot2::aes(fill=fisher_sig,size=point_size,shape=at_log_boundary),colour="#40535C",stroke=.2)+
  ggplot2::scale_size_identity()+ggplot2::scale_shape_manual(values=c(`FALSE`=21,`TRUE`=24),guide="none")+
  ggplot2::scale_fill_manual(values=pal[c("LINE","SINE","LTR","DNA","insig")],guide="none")+
  ggplot2::scale_x_log10(limits=c(.1,400),breaks=c(.1,1,10,100),labels=c("0.1","1","10","100"),expand=ggplot2::expansion(mult=c(.015,.02)))+
  ggplot2::scale_y_log10(limits=c(.1,400),breaks=c(.1,1,10,100),labels=c("0.1","1","10","100"),expand=ggplot2::expansion(mult=c(.015,.02)))+
  ggplot2::geom_segment(data=leaders,ggplot2::aes(x=x,y=y,xend=xend,yend=yend),inherit.aes=FALSE,colour="#89989C",linewidth=.2)+
  ggplot2::geom_text(data=ld,ggplot2::aes(x=x,y=y,label=label),inherit.aes=FALSE,colour=ld$colour,family=font$family,size=7.500001/ggplot2::.pt)+
  ggplot2::labs(x="HepG2 STARR-seq peak\nObserved / expected ratio",y="GP5d STARR-seq peak\nObserved / expected ratio",
    title=if(pn=="left")"Common enrichment" else "Differential enrichment")+
  ggplot2::theme_classic(base_family=font$family,base_size=7.500001)+
  ggplot2::theme(plot.title=ggplot2::element_text(size=8.000001,face="bold",hjust=.5,colour=pal[["text"]]),
    axis.text=ggplot2::element_text(size=7.500001,colour=pal[["text"]]),axis.title=ggplot2::element_text(size=8.000001,colour=pal[["text"]]),
    axis.line=ggplot2::element_line(linewidth=.25,colour="#65767C"),axis.ticks=ggplot2::element_line(linewidth=.25),
    plot.margin=ggplot2::margin(1,1,1,1,"mm"),plot.background=ggplot2::element_rect(fill="white",colour=NA))
 scatter_grobs[[pn]]<-ggplot2::ggplotGrob(p)
 scatter_metrics[[pn]]<-list(rows=nrow(d),boundary_rows=sum(d$at_log_boundary),source_zero_rows=sum(d$obs_exp_hepg2==0|d$obs_exp_gp5d==0),grouped_source_labels=ld,label_policy="formal source family highlights only; all558 source points retained",family_leaders=leaders)
}
texts<-data.frame(label=c("a","b","LINE","SINE","LTR","DNA","Below log-axis boundary"),x=c(1,1,9,31,53,75,109),y=c(158,94,99,99,99,99,99),size=c(9,9,7.500001,7.500001,7.500001,7.500001,7.500001),face=c("bold","bold",rep("plain",5)))
keys<-data.frame(cat=c("LINE","SINE","LTR","DNA"),x=c(6,28,50,72),y=99,col=unname(pal[c("LINE","SINE","LTR","DNA")]))
p<-ggplot2::ggplot()+ggplot2::coord_cartesian(xlim=c(0,width),ylim=c(0,height),expand=FALSE,clip="off")+
 ggplot2::theme_void(base_family=font$family,base_size=7.500001)+
 ggplot2::theme(plot.margin=ggplot2::margin(0,0,0,0),plot.background=ggplot2::element_rect(fill="white",colour=NA))+
 ggplot2::annotation_custom(scatter_grobs$left,xmin=0,xmax=88,ymin=102,ymax=160)+
 ggplot2::annotation_custom(scatter_grobs$right,xmin=92,xmax=180,ymin=102,ymax=160)+
 ggplot2::annotation_custom(heat_grob,xmin=0,xmax=180,ymin=0,ymax=96)+
 ggplot2::geom_point(data=keys,ggplot2::aes(x,y),fill=keys$col,shape=21,size=1.35,stroke=.2,colour="#40535C")+
 ggplot2::geom_point(ggplot2::aes(x=106,y=99),fill=pal[["boundary"]],shape=24,size=1.35,stroke=.2,colour="#40535C")+
 ggplot2::geom_text(data=texts,ggplot2::aes(x,y,label=label,size=size/ggplot2::.pt,fontface=face),hjust=0,vjust=.5,family=font$family,colour=pal[["text"]])+ggplot2::scale_size_identity()
raster_n<-0L;text_n<-0L;native_text<-list();matrix_rectangles<-0L
# The viewport-safe capture stores native primitives inside recordedGrob$list.
# Inspect those too: shared bf_prepare only walks ordinary children/grobs.
audit<-function(g,inherited=grid::gpar()){
 gp<-inherited;for(k in names(g$gp))gp[[k]]<-g$gp[[k]]
 if(inherits(g,"rastergrob"))raster_n<<-raster_n+1L
 if(inherits(g,"rect")&&length(g$x)==490L)matrix_rectangles<<-matrix_rectangles+length(g$x)
 if(inherits(g,"text")&&length(g$label)){
  labels<-as.character(g$label);text_n<<-text_n+length(labels)
  bf_assert_scientific_text(labels,"native recorded grid text")
  stopifnot(all(labels%in%spec$text_contract$allowed_text),!is.null(gp$fontfamily),all(gp$fontfamily==font$family),!is.null(gp$fontsize),min(gp$fontsize)>=7.5)
  native_text[[length(native_text)+1L]]<<-list(labels=labels,font_family=gp$fontfamily,font_sizes_pt=gp$fontsize)
 }
 if(length(g$children))for(h in g$children)audit(h,gp)
 if(length(g$grobs))for(h in g$grobs)audit(h,gp)
 if(inherits(g,"recordedGrob")&&length(g$list))for(h in g$list)if(inherits(h,"grob"))audit(h,gp)
}
audit(heat_grob);for(g in scatter_grobs)audit(g);stopifnot(raster_n==0L,text_n>=90L)
sources<-c(spec_path,file.path(root,"scripts/render.R"),file.path(skill,"scripts/figure_style.R"),paths,qc_path)
macro<-data.frame(id=c("data","labels","legend"),x=c(0,0,0),y=c(14,14,0),w=c(180,180,180),h=c(146,146,14))
prefix<-"te_tf_motif_atlas_recolored";png<-file.path(work,paste0(prefix,".png"))
bf_render_png(p,png,font,spec$text_contract$allowed_text,width,height,width,sources,macro,allowed_pairs="data:labels",dpi=600,min_text_pt=7.5,authorization=authorization,skill_root=skill,publication_size_class="double-column")
pdf<-file.path(root,"results/figures",paste0(prefix,".pdf"));dir.create(dirname(pdf),recursive=TRUE,showWarnings=FALSE)
grDevices::quartz(type="pdf",file=pdf,width=width/25.4,height=height/25.4,family=font$family,bg="white");print(p);grDevices::dev.off()
svg<-file.path(work,paste0(prefix,"-gate-qa.svg"));svglite::svglite(svg,width=width/25.4,height=height/25.4,bg="white",system_fonts=list(sans=font$family));print(p);grDevices::dev.off()
bind<-function(f)list(path=normalizePath(f),sha256=digest::digest(file=f,algo="sha256"))
pk<-c("ComplexHeatmap","circlize","ggplot2","ggrepel","grid","ragg","svglite","systemfonts","readxl","yaml","jsonlite","digest")
metrics<-list(schema_version=1,scope=spec$scientific_message,counts=list(motif_rows=14,TE_columns=35,matrix_cells=490,column_slices=3,dendrograms=4,scatter_rows=558,negative_matrix_cells=18,zero_ratio_records=32,raster_grobs=raster_n,native_text_n=text_n),source_complete=TRUE,native_namespaces=c("ComplexHeatmap::Heatmap","ComplexHeatmap::draw","circlize::colorRamp2","ggplot2::geom_point","ggplot2::geom_text","ggplot2::geom_segment"),native_recorded_grob_text_audit=list(status="PASS",all_text_allowed=TRUE,font_family=font$family,minimum_text_pt=7.500001,includes_recordedGrob_list=TRUE,records=native_text),actual_matrix=list(rownames=rownames(mat),colnames=colnames(mat),row_order=row_order,column_orders=col_order,range=range(mat),column_square_sums=colSums(mat^2),input_matrix_preserved=TRUE),scatter=scatter_metrics,palette=as.list(pal),layout=list(canvas_mm=c(width,height),heatmap_capture_mm=c(180,96),scatter_capture_mm=c(88,58),matrix_mm=c(125,44),row_dend_mm=10,column_dend_mm=10,text_min_pt=7.500001),source_files=lapply(sources,bind),artifacts=list(pdf=bind(pdf),png=bind(png),svg=bind(svg)),render_receipt=bind(paste0(png,".render.json")),environment=list(R=R.version.string,platform=R.version$platform,packages=as.list(setNames(vapply(pk,function(k)as.character(utils::packageVersion(k)),character(1)),pk)),font=bind(font$path)),statistics=list(existing=TRUE,recomputed=FALSE),source_vs_final=list(panels="a/b only;c/d excluded",palette="changed linked semantic colors",unit_label="Scaled -log10(E-value); paper caption minimum vs code mean/RMS documented",zero_display="source zeros preserved; triangle at lower logboundary only"),new_input_transfer="NOT_VERIFIED",structural_stress="NOT_VERIFIED",whole_original_figure="NOT_VERIFIED",CP4="PENDING_ACTUAL_VIEW")
jsonlite::write_json(metrics,file.path(root,"results/tables/render-metrics.json"),auto_unbox=TRUE,pretty=TRUE,digits=17)
cat("NATIVE_RENDER_COMPLETE:",png,"\n")
