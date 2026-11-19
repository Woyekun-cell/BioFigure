#!/usr/bin/env Rscript
# MEFISTO Fig2b/d/e: author-model data with final-artwork visual grammar.
# No training, tracing, group relabeling, factor sign change, or sample removal.
args <- commandArgs(TRUE)
stopifnot(length(args)==4L)
case <- normalizePath(args[1]); out <- args[2]; spec_path <- normalizePath(args[3]); auth <- normalizePath(args[4])
dir.create(dirname(out),recursive=TRUE,showWarnings=FALSE)
skill <- normalizePath(file.path(case,"../../../.."))
source(file.path(skill,"scripts/figure_style.R"))
suppressPackageStartupMessages({library(ggplot2);library(grid);library(pheatmap)})
options(warn=2); Sys.setlocale("LC_COLLATE","C"); set.seed(0)
font <- bf_font("Arial"); spec <- yaml::read_yaml(spec_path)
W <- spec$output_size$width_mm; H <- spec$output_size$height_mm
stopifnot(W==183,H==170)
datadir <- file.path(case,"results/plot_data")
read <- function(n) read.csv(file.path(datadir,paste0(n,".csv")),stringsAsFactors=FALSE,check.names=FALSE)
r2 <- read("r2_per_factor"); totals <- read("r2_total"); obs <- read("observed_factors")
pred <- read("interpolated_factors"); kg <- read("group_kernels"); scores <- read("factor_scores")
stopifnot(nrow(r2)==125,nrow(totals)==25,nrow(obs)==415,nrow(pred)==350,nrow(kg)==125)
stopifnot(max(abs(pred$ymin-(pred$mean-1.96*sqrt(pred$variance))))<1e-10)
species <- c("Mouse","Rabbit","Rat","Human","Opossum")
organs <- c("Brain","Cerebellum","Heart","Liver","Testis")
pal <- unlist(spec$palette_semantics)
cell <- 5.2; body <- cell*5; kernel_cell <- 5.6; kernel_body <- kernel_cell*5
r2$display_r2 <- ifelse(r2$r2_percent<0,.001,r2$r2_percent)
r2max <- max(r2$display_r2)
anchors <- read.csv(file.path(case,"data/metadata/reproduction/variance-color-anchors.csv"),comment.char="",stringsAsFactors=FALSE)
palette_fun <- scales::gradient_n_pal(anchors$source_hex,values=anchors$source_r2_percent/max(anchors$source_r2_percent),space="Lab")
purple <- palette_fun(seq(0,1,length.out=256))
purple_map <- function(x) palette_fun(pmax(0,pmin(1,x/r2max)))
kernelpal <- rev(grDevices::colorRampPalette(RColorBrewer::brewer.pal(7,"RdBu"))(100))
breaks <- c(seq(-1,0,length.out=51),seq(0,1,length.out=51)[-1])
texts <- list(); segments <- list(); annotations <- list(); nested_audits <- list(); kernel_orders <- list()
text <- function(label,x,y,size=7,hjust=.5,vjust=.5,angle=0,face="plain") {
 texts[[length(texts)+1L]] <<- data.frame(label=label,x=x,y=y,size=size,hjust=hjust,vjust=vjust,angle=angle,face=face)
}
seg <- function(x,y,xend,yend,lw=.15,col="#545454") {
 segments[[length(segments)+1L]] <<- data.frame(x=x,y=y,xend=xend,yend=yend,lw=lw,col=col)
}
box <- function(g,x,y,w,h) {
 annotations[[length(annotations)+1L]] <<- annotation_custom(g,xmin=x,xmax=x+w,ymin=y,ymax=y+h)
}
rect_grob <- function(fill="#FFFFFF",edge=NA,lwd=0) rectGrob(gp=gpar(fill=fill,col=edge,lwd=lwd))
p <- ggplot()+coord_fixed(xlim=c(0,W),ylim=c(0,H),expand=FALSE,clip="on")+
 theme_void(base_family=font$family,base_size=7)+
 theme(plot.margin=margin(0,0,0,0,"mm"),plot.background=element_rect(fill="white",colour=NA))
# Five separate actual tile layers: each audit is one5x5 matrix, not a fictitious whole canvas matrix.
for(j in seq_along(species)) {
 sp <- species[j]; bx <- 15+(j-1)*31.2
 d <- subset(r2,species==sp);d$x <- bx+(match(d$view,organs)-.5)*cell
 d$y <- 121.8+(d$source_factor_index-.5)*cell;d$hex <- purple_map(d$display_r2)
 p <- p+geom_tile(data=d,aes(x=x,y=y,fill=hex),width=cell,height=cell,colour="#777777",linewidth=.08)
 text(sp,bx+body/2,164,7.5)
 for(k in 1:5) text(organs[k],bx+(k-.5)*cell,119.7,7,hjust=1,angle=90)
 t <- subset(totals,species==sp);t$organ <- factor(t$view,levels=organs)
 bar <- ggplot(t,aes(x=organ,y=r2_percent))+
   geom_col(width=.9,fill=pal[[sp]],colour="#222222",linewidth=.23,alpha=1)+
   coord_cartesian(xlim=c(.5,5.5),ylim=c(0,90),expand=FALSE)+
   theme_void(base_family=font$family,base_size=7)+theme(plot.margin=margin(0,0,0,0,"mm"))
 contract <- list(list(layer=1,role="bar-fill",fill_alpha=1,edge_alpha=1,
   override_reason="Published original bars have opaque species fill and fine dark outline."))
 bf_check_mark_layers(bar,contract)
 nested_audits[[paste0("b-bars-",sp)]] <- list(actual_native_layers=1,contracts=contract,rows=nrow(t))
 box(ggplotGrob(bar),bx,150,body,11.5)
 seg(bx,150,bx+body,150,.12)
}
for(k in 1:5) text(paste("Factor",k),13.4,121.8+(k-.5)*cell,7,hjust=1)
seg(14.2,150,14.2,161.5,.12)
for(v in seq(0,80,20)) { y<-150+v/90*11.5;seg(13.5,y,14.2,y,.12);text(as.character(v),12.9,y,7,hjust=1) }
text("Var. (%)",6.4,155.75,7.5,angle=90)
text("b",1.2,166.4,10,hjust=0,face="bold")
# Native pheatmap computes kernel clustering and colors. Physical tile assembly changes only cell geometry.
tree_segments <- function(hc,bx,by,side) {
 n <- length(hc$order); centers <- numeric(n-1); heights <- numeric(n-1)
 maxh <- max(hc$height); if(maxh==0) maxh<-1
 point <- function(child) if(child<0)c(match(-child,hc$order)-.5,0)else c(centers[child],heights[child])
 for(i in 1:(n-1)) {
  a<-point(hc$merge[i,1]); b<-point(hc$merge[i,2]); h<-hc$height[i]/maxh*2.1
  centers[i]<-mean(c(a[1],b[1]));heights[i]<-h
  if(side=="col") {
   seg(bx+a[1]*kernel_cell,by+a[2],bx+a[1]*kernel_cell,by+h,.13)
   seg(bx+b[1]*kernel_cell,by+b[2],bx+b[1]*kernel_cell,by+h,.13)
   seg(bx+a[1]*kernel_cell,by+h,bx+b[1]*kernel_cell,by+h,.13)
  } else {
   seg(bx-a[2],by+(n-a[1])*kernel_cell,bx-h,by+(n-a[1])*kernel_cell,.13)
   seg(bx-b[2],by+(n-b[1])*kernel_cell,bx-h,by+(n-b[1])*kernel_cell,.13)
   seg(bx-h,by+(n-a[1])*kernel_cell,bx-h,by+(n-b[1])*kernel_cell,.13)
  }
 }
}
source_group <- unique(kg$species_row)
for(k in 1:5) {
 d <- subset(kg,source_factor_index==k)
 K <- matrix(NA_real_,5,5,dimnames=list(source_group,source_group))
 K[cbind(match(d$species_row,source_group),match(d$species_col,source_group))] <- d$correlation
 stopifnot(all(is.finite(K)),max(abs(K-t(K)))<1e-10,max(abs(K))<=1+1e-10)
 # Retain raw matrices and cluster from raw values; clamp roundoff only in color lookup.
 hr <- hclust(dist(K),method="complete");hc <- hclust(dist(t(K)),method="complete")
 Kcolor <- K; Kcolor[] <- pmin(1,pmax(-1,as.vector(K)))
 ph <- pheatmap(Kcolor,color=kernelpal,breaks=breaks,
  cluster_rows=hr,cluster_cols=hc,legend=FALSE,silent=TRUE)
 ro <- ph$tree_row$order;co <- ph$tree_col$order
 native_fill <- ph$gtable$grobs[[which(ph$gtable$layout$name=="matrix")]]$children[[1]]$gp$fill
 stopifnot(identical(dim(native_fill),c(5L,5L)))
 bx <- 13.85+(k-1)*34.35;by<-17
 cells <- expand.grid(row=1:5,col=1:5)
 cells$x <- bx+(cells$col-.5)*kernel_cell;cells$y<-by+(5-cells$row+.5)*kernel_cell
 cells$hex <- native_fill[cbind(cells$row,cells$col)]
 p<-p+geom_tile(data=cells,aes(x=x,y=y,fill=hex),width=kernel_cell,height=kernel_cell,
   colour="#A0A0A0",linewidth=.09)
 for(j in 1:5) text(colnames(K)[co[j]],bx+(j-.5)*kernel_cell,14.7,8,hjust=1,angle=90)
 tree_segments(ph$tree_col,bx,by+kernel_body,"col")
 tree_segments(ph$tree_row,bx,by,"row")
 kernel_orders[[paste0("Factor",k)]] <- list(row_species=rownames(K)[ro],column_species=colnames(K)[co],
  native_clustering="pheatmap supplied raw-Euclidean complete hclust",
  max_raw_abs=unname(max(abs(K))),display_floor_clamp_only=TRUE)
}
text("e",1.2,47,10,hjust=0,face="bold")
# Native process panels: all prediction rows and all observed points. Bands below means/observations.
for(k in 1:5) {
 bx <- 11.8+(k-1)*34.35;dw<-32.1;by<-58;dh<-41
 d<-subset(pred,source_factor_index==k);o<-subset(obs,source_factor_index==k)
 d$species<-factor(d$species,levels=species);o$species<-factor(o$species,levels=species)
 q<-ggplot(d,aes(x=time,y=mean,colour=species,fill=species,group=species))+
  geom_ribbon(aes(ymin=ymin,ymax=ymax),alpha=.2,colour="#999999",linewidth=.06)+
  geom_line(linewidth=.27,alpha=1)+
  geom_point(data=o,aes(x=time_warped,y=value),size=.76,alpha=.85,stroke=0)+
  scale_colour_manual(values=pal,guide="none")+scale_fill_manual(values=pal,guide="none")+
  coord_cartesian(xlim=c(1,14),ylim=c(-4.5,8.5),expand=FALSE)+
  theme_void(base_family=font$family,base_size=7)+theme(plot.margin=margin(0,0,0,0,"mm"))
 ct<-list(list(layer=1,role="uncertainty-band",fill_alpha=.2,edge_alpha=.2),
  list(layer=2,role="summary-line",edge_alpha=1),
  list(layer=3,role="dense-point",edge_alpha=.85,
   override_reason="Published sparse observed latent scores are visible opaque colored dots, not a density estimate."))
 bf_check_mark_layers(q,ct)
 nested_audits[[paste0("d-Factor",k)]]<-list(actual_native_layers=3,contracts=ct,prediction_rows=nrow(d),observed_rows=nrow(o))
 box(ggplotGrob(q),bx,by,dw,dh)
 seg(bx,by,bx+dw,by,.14)
 if(k==1) {
  seg(bx,by,bx,by+dh,.14)
  for(v in c(-2.5,0,2.5,5,7.5)) {y<-by+(v+4.5)/13*dh;seg(bx-.5,y,bx,y,.13);text(as.character(v),bx-1.1,y,7,hjust=1)}
 }
 text("Early",bx,54.7,7,hjust=0);text("Late",bx+dw,54.7,7,hjust=1)
 box(rect_grob("#FFFFFF","#555555",.35),bx,100.3,dw,4.5)
 text(paste("Factor",k),bx+dw/2,102.55,7.5)
 score<-scores[scores$source_factor_index==k,]
 for(role in c("Smoothness","Sharedness")) {
  y<-if(role=="Smoothness")95.4 else 91.9
  value<-if(role=="Smoothness")score$smoothness else score$sharedness
  color<-if(role=="Smoothness")"#5F9EA0" else "#B8CF86"
  box(rect_grob("#BEBEBE"),bx+1,y,dw-2,2.8)
  box(rect_grob(color),bx+1,y,(dw-2)*value,2.8)
  text(role,bx+dw/2,y+1.4,7)
 }
}
text("Factor value",2.2,78.5,7.5,angle=90)
text("Learnt common developmental time",96,49.7,7.5)
text("d",1.2,104.1,10,hjust=0,face="bold")
# Shared analytical color bars. These are legends, not additional matrix data.
vertical_key <- function(colors,x,y,w,h) {
 gradient <- do.call(grobTree,lapply(seq_along(colors),function(i) rectGrob(x=.5,y=(i-.5)/length(colors),width=1,height=1/length(colors)+.0001,gp=gpar(fill=colors[i],col=NA))))
 box(gradient,x,y,w,h)
}
vertical_key(purple,172.4,124,2.4,20.5);text("Var. (%)",175.5,148.2,7)
for(v in c(0,20,40,60)) text(as.character(v),176,124+v/r2max*20.5,7,hjust=0)
vertical_key(kernelpal,1.1,17,2,kernel_body)
for(v in c(-1,-.5,0,.5,1)) text(as.character(v),4.2,17+(v+1)/2*kernel_body,7,hjust=0)
# Layer11 is the complete outer physical-mm segment layer, covered by the Design Spec.
sg<-do.call(rbind,segments);tx<-do.call(rbind,texts)
p<-p+geom_segment(data=sg,aes(x=x,y=y,xend=xend,yend=yend,linewidth=lw,colour=col),alpha=1)+
 scale_fill_identity()+scale_colour_identity()+scale_linewidth_identity()+scale_size_identity()
for(z in annotations) p<-p+z
p<-p+geom_text(data=tx,aes(x=x,y=y,label=label,size=size/.pt,hjust=hjust,vjust=vjust,angle=angle,fontface=face),
  family=font$family,colour="#111111",lineheight=1)
# Actual text dimensions on the target device, including rotated labels.
measure_file<-tempfile(fileext=".png")
ragg::agg_png(measure_file,width=W,height=H,units="mm",res=450,background="white")
text_boxes<-lapply(seq_len(nrow(tx)),function(i){
 z<-tx[i,];g<-textGrob(z$label,gp=gpar(fontfamily=font$family,fontsize=z$size,fontface=z$face))
 tw<-convertWidth(grobWidth(g),"mm",valueOnly=TRUE);th<-convertHeight(grobHeight(g),"mm",valueOnly=TRUE)
 corners<-rbind(c(-z$hjust*tw,-z$vjust*th),c((1-z$hjust)*tw,-z$vjust*th),
  c((1-z$hjust)*tw,(1-z$vjust)*th),c(-z$hjust*tw,(1-z$vjust)*th))
 angle<-z$angle*pi/180;mat<-matrix(c(cos(angle),-sin(angle),sin(angle),cos(angle)),2,2,byrow=TRUE)
 xy<-t(mat%*%t(corners));xy[,1]<-xy[,1]+z$x;xy[,2]<-xy[,2]+z$y
 list(text=z$label,font_pt=z$size,bbox_mm=c(min(xy[,1]),min(xy[,2]),diff(range(xy[,1])),diff(range(xy[,2]))))
})
dev.off();unlink(measure_file)
outside<-Filter(function(z){b<-z$bbox_mm;b[1] < -0.05 || b[2] < -0.05||b[1]+b[3]>W+.05||b[2]+b[4]>H+.05},text_boxes)
if(length(outside))stop(paste("Text outside canvas:",paste(vapply(outside,function(x)x$text,character(1)),collapse="|")))
sources<-c(normalizePath(file.path(case,"scripts/render.R")),spec_path,file.path(skill,"scripts/figure_style.R"),
 file.path(case,"data/metadata/reproduction/variance-color-anchors.csv"),
 file.path(datadir,c("r2_per_factor.csv","r2_total.csv","observed_factors.csv","interpolated_factors.csv","group_kernels.csv","factor_scores.csv")))
macro<-data.frame(id=c("data","labels","legend"),x=c(0,0,0),y=c(0,0,0),w=c(W,W,W),h=c(H,H,H))
receipt<-bf_render_png(p,paste0(out,".png"),font,spec$text_contract$allowed_text,W,H,W,sources,macro,
 allowed_pairs=c("data:labels","data:legend","labels:legend"),dpi=450,min_text_pt=7,
 authorization=auth,skill_root=skill,publication_size_class="double-column")
grDevices::quartz(type="pdf",file=paste0(out,".pdf"),width=W/25.4,height=H/25.4,family=font$family,bg="white")
print(p);pdf_cells<-bf_measure_ggplot_cells(bf_ggplot_cell_plan(p,ggplot_build(p),TRUE),ggplotGrob(p))
dev.off()
svglite::svglite(paste0(out,".svg"),width=W/25.4,height=H/25.4,bg="white",system_fonts=list(sans=font$family))
print(p);dev.off()
audit<-list(status="NATIVE_R_SOURCE_MODEL_RENDERED_REQUIRES_ACTUAL_SOURCE_VISUAL_REVIEW",
 source_model_no_retraining=TRUE,canvas_mm=c(W,H),
 colorbar_backend="native grid.rect vector strips; identical bottom-to-top orientation on PNG/PDF/SVG",heatmap_cells_png=receipt$heatmap_cells,
 heatmap_cells_pdf=pdf_cells,all10_5x5_cells_square=length(receipt$heatmap_cells)==10,
 matrix_native_clustering=kernel_orders,nested_actual_layer_audits=nested_audits,
 text_boxes=text_boxes,text_outside_canvas=outside,footer_absent=TRUE,
 raw_negative_r2_preserved=sum(r2$r2_percent<0),r2_display_rule="ifelse(raw<0,.001,raw); raw CSV unchanged",
 r2_palette_limits=c(0,r2max),posterior_interval="mean +/-1.96sqrt(variance)",all_observed_points=415,
 all_prediction_rows=350,actual_species_palette=as.list(pal),
 macro_box_scope="Whole-canvas group bounds intentionally overlap; actual10matrix bodies, text boxes and named panel slots checked separately.",
 known_differences=c("b source slightly tall cells converted to physical squares","deposited Kg species labels/values differ from published F4/F5; not changed",
  "no original illustration a or factor scatter c","Final artwork colors retained instead of current hue_pal defaults"),
 versions=as.list(setNames(vapply(c("ggplot2","pheatmap","ragg","svglite","systemfonts"),function(n)as.character(packageVersion(n)),character(1)),
  c("ggplot2","pheatmap","ragg","svglite","systemfonts"))))
jsonlite::write_json(audit,paste0(out,".audit.json"),pretty=TRUE,auto_unbox=TRUE,digits=NA)
writeLines(capture.output(sessionInfo()),paste0(out,".environment.txt"))
cat("MEFISTO_NATIVE_RENDER_COMPLETE",out,"\n")
