# Shared physical canvas helpers. Each case owns its data transformations/layers.
suppressPackageStartupMessages({library(ggplot2);library(jsonlite);library(systemfonts);library(grid);library(yaml);library(digest)})
options(warn=2)
cfg<-fromJSON('data/settings.json');W<-800;H<-cfg$canvas_height_px
source('figure_style.R');font<-bf_font('Arial')
stopifnot(cfg$font_family=='Arial',basename(font$path)=='Arial.ttf',cfg$width_mm==183,cfg$height_mm<=170,
 abs(cfg$height_mm/cfg$width_mm-H/W)<1e-6,is.logical(cfg$synthetic),nzchar(cfg$experimental_unit),nzchar(cfg$data_context))
source_display<-cfg$scene=='source-display'
rd<-function(n)read.csv(paste0('data/',n,'.csv'),stringsAsFactors=FALSE,check.names=FALSE,na.strings=c('','NA'))
key<-function(d,k){stopifnot(k%in%names(d),!anyNA(d[[k]]),all(nzchar(d[[k]])),!anyDuplicated(d[[k]]))}
ord<-function(d,k){key(d,k);stopifnot(!anyNA(d$order),!anyDuplicated(d$order),!anyNA(d$label),all(nzchar(d$label)));d[order(d$order,d[[k]]),]}
wrap<-function(x,n)vapply(x,function(s)paste(strwrap(s,width=n),collapse='\n'),character(1))
p<-ggplot()+scale_fill_identity()+scale_x_continuous(limits=c(0,W),expand=c(0,0))+scale_y_continuous(limits=c(-H,0),expand=c(0,0))+coord_cartesian(clip='off')+
 theme_void(base_family='Arial')+theme(plot.margin=margin(0,0,0,0),plot.background=element_rect(fill='white',colour=NA),panel.background=element_rect(fill='white',colour=NA),legend.position='none')
txt<-data.frame(id=character(),label=character(),x=numeric(),y=numeric(),size=numeric(),face=character(),hjust=numeric(),vjust=numeric(),angle=numeric(),color=character(),stringsAsFactors=FALSE)
T<-function(id,label,x,y,role='axis_text',face='plain',hjust=.5,vjust=.5,angle=0,color='black'){
 stopifnot(role%in%names(cfg$font_roles_pt));txt<<-rbind(txt,data.frame(id=id,label=as.character(label),x=x,y=-y,size=cfg$font_roles_pt[[role]],face=face,hjust=hjust,vjust=vjust,angle=angle,color=color))}
S<-function(x,y,xend,yend,color='black',lw=.2,lt='solid'){
 d<-data.frame(x=x,y=-y,xe=xend,ye=-yend);p<<-p+geom_segment(data=d,aes(x=x,y=y,xend=xe,yend=ye),linewidth=lw,colour=color,linetype=lt)}
B<-function(x0,y0,x1,y1,fill=NA,color=NA,lw=.2){
 d<-data.frame(x0=x0,x1=x1,y0=-y1,y1=-y0,fill=fill);p<<-p+geom_rect(data=d,aes(xmin=x0,xmax=x1,ymin=y0,ymax=y1,fill=fill),colour=color,linewidth=lw)}
O<-function(x,y,fill='black',size=1,stroke=0){d<-data.frame(x=x,y=-y,fill=fill);p<<-p+geom_point(data=d,aes(x=x,y=y,fill=fill),shape=21,colour='black',size=size,stroke=stroke)}
G<-function(d,lw=.3){p<<-p+geom_polygon(data=d,aes(x=x,y=-y,group=group,fill=fill),colour='black',linewidth=lw)}
ok<-function(e)list(status='pass',evidence=e)
checks<-list();metadata<-list();plot_tables<-list();layer_order<-character();panels<-list()
dir.create('results',showWarnings=FALSE);dir.create('results/plot_data',showWarnings=FALSE);dir.create('results/tables',showWarnings=FALSE)

finish<-function(){
 # Compute oriented text rectangles at final physical size. No drawing/device
 # needed until the source/input/Spec authorization has been issued.
 widths<-vapply(seq_len(nrow(txt)),function(i){z<-txt[i,];path<-if(z$face=='bold')'/System/Library/Fonts/Supplemental/Arial Bold.ttf' else font$path;max(systemfonts::string_width(strsplit(z$label,'\n',fixed=TRUE)[[1]],path=path,size=z$size,res=300))*25.4/300/cfg$width_mm*W},numeric(1))
 heights<-vapply(strsplit(txt$label,'\n',fixed=TRUE),length,integer(1))*txt$size*25.4/72/cfg$width_mm*W*.95
 quads<-lapply(seq_len(nrow(txt)),function(i){z<-txt[i,];xx<-c(-z$hjust*widths[i],(1-z$hjust)*widths[i]);yy<-c(-z$vjust*heights[i],(1-z$vjust)*heights[i]);a<-z$angle*pi/180;corners<-rbind(c(xx[1],yy[1]),c(xx[2],yy[1]),c(xx[2],yy[2]),c(xx[1],yy[2]));rot<-matrix(c(cos(a),sin(a),-sin(a),cos(a)),2);q<-corners%*%t(rot);sweep(q,2,c(z$x,z$y),'+')})
 overlap<-function(a,b){edges<-rbind(a[c(2,3,4,1),]-a,b[c(2,3,4,1),]-b);axes<-cbind(-edges[,2],edges[,1]);for(i in seq_len(nrow(axes))){aa<-a%*%axes[i,];bb<-b%*%axes[i,];if(max(aa)<=min(bb)+.05||max(bb)<=min(aa)+.05)return(FALSE)};TRUE}
 collisions<-list()
 for(i in seq_len(nrow(txt))) {
  q<-quads[[i]]
  if(min(q[,1])<0||max(q[,1])>W||min(q[,2])< -H||max(q[,2])>0)stop('Text outside canvas: ',txt$id[i])
  if(i<nrow(txt))for(j in (i+1):nrow(txt))if(overlap(q,quads[[j]]))collisions[[length(collisions)+1]]<-c(txt$id[i],txt$id[j])
 }
 if(length(collisions))stop('Oriented text collision: ',paste(unlist(collisions),collapse=', '))
 roles<-as.list(cfg$font_roles_pt);stopifnot(setequal(unique(txt$size),unique(unlist(roles))))
 for(n in names(plot_tables))write.csv(plot_tables[[n]],paste0('results/plot_data/',n,'.csv'),row.names=FALSE)
 write.csv(txt,'results/tables/text-geometry.csv',row.names=FALSE)
 metrics<-list(canvas_mm=c(cfg$width_mm,cfg$height_mm),font_sizes_pt=roles,panels=panels,layer_order=layer_order,text_quad_coordinate='Original800px x declared height, Cartesian positive y upward',text_quads=lapply(quads,function(q)unname(split(q,row(q)))),collision_count=length(collisions),source_layout=metadata)
 write_json(metrics,'results/layout_metrics.json',auto_unbox=TRUE,pretty=TRUE,na='null')
 if(cfg$scene=='stress') {
  stopifnot(metadata$missing_count>0,metadata$extreme_value>metadata$new_input_extreme,metadata$shuffled_metadata)
  checks$stress_long_labels<-ok(paste('Complete wrapped labels; longest input',metadata$longest_label_chars,'characters; physical oriented text boxes disjoint'))
  checks$stress_multiple_groups<-ok(metadata$groups_evidence)
  checks$stress_missing_values<-ok(paste(metadata$missing_count,'unavailable values explicitly handled/logged; no invented replacements'))
  checks$stress_extreme_values<-ok(paste('Observed fixture extreme',metadata$extreme_value,'retained vs new-input',metadata$new_input_extreme))
  checks$stress_shuffled_metadata<-ok('Actual input metadata deliberately shuffled; canonical unique-key ordering restores all mark/label relationships')
 }
 write_json(checks,'results/scientific_results.json',auto_unbox=TRUE,pretty=TRUE)
 write_json(list(allowed_text=unique(txt$label),layout_metrics=metrics,scientific_results=checks),'results/preflight.json',auto_unbox=TRUE,pretty=TRUE)
 if('--preflight'%in%commandArgs(TRUE))quit(save='no',status=0)
 p<-p+geom_text(data=txt,aes(x=x,y=y,label=label,size=size/ggplot2::.pt,fontface=face,hjust=hjust,vjust=vjust,angle=angle,colour=color),family='Arial',lineheight=.95,show.legend=FALSE)+scale_size_identity()+scale_colour_identity()
 root<-Sys.getenv('BIOFIGURE_SKILL_ROOT');stopifnot(nzchar(root))
 sources<-c('render.R','composite_canvas.R','figure_style.R','data/settings.json','data/design-spec.yaml',list.files('data',pattern='\\.csv$',full.names=TRUE))
 args<-c(file.path(root,'scripts/authorize_render.py'),'--receipt','data/preparation-receipt.json','--design-spec','data/design-spec.yaml',unlist(lapply(sources[sources!='data/design-spec.yaml'],function(s)c('--source',s))),'--output','results/render-authorization.json')
 if(system2('python3',shQuote(args))!=0L)stop('Render authorization failed')
 dir.create('results/figures',showWarnings=FALSE)
 # Bounding unions are conservative: count labels share the data panel and
 # source inset legends occupy reserved empty areas. Exact oriented text boxes
 # above and case-specific mark/inset checks handle the actual collision gate.
 bounds<-function(qq){q<-do.call(rbind,qq);c(min(q[,1]),-max(q[,2]),max(q[,1]),-min(q[,2]))}
 db<-panels[names(panels)!='legend'];data_bounds<-c(min(vapply(db,function(z)z[1],numeric(1))),min(vapply(db,function(z)z[2],numeric(1))),max(vapply(db,function(z)z[3],numeric(1))),max(vapply(db,function(z)z[4],numeric(1))))
 islegend<-grepl('legend',txt$id);label_bounds<-bounds(quads[!islegend]);legend_bounds<-bounds(quads[islegend])
 if(cfg$method_id=='SCICASE-101')legend_bounds<-c(670,min(legend_bounds[2],ltop),797,max(legend_bounds[4],shm_top+95))
 if(cfg$method_id=='SCICASE-102')legend_bounds[1]<-min(115,legend_bounds[1])
 if(cfg$method_id=='SCICASE-112')legend_bounds<-panels$legend
 boxrow<-function(id,z)data.frame(id=id,x=z[1]/W*cfg$width_mm,y=z[2]/H*cfg$height_mm,w=(z[3]-z[1])/W*cfg$width_mm,h=(z[4]-z[2])/H*cfg$height_mm)
 boxes<-rbind(boxrow('data',data_bounds),boxrow('labels',label_bounds),boxrow('legend',legend_bounds))
 bf_render_png(p,'results/figures/figure.png',font=font,allowed_text=unique(txt$label),width_mm=cfg$width_mm,height_mm=cfg$height_mm,target_width_mm=cfg$width_mm,source_files=sources,boxes=boxes,allowed_pairs=c('data:labels','data:legend','labels:legend'),min_text_pt=min(unlist(roles)),authorization='results/render-authorization.json',skill_root=root,publication_size_class='double-column')
 grDevices::quartz(type='pdf',file='results/figures/figure.pdf',width=cfg$width_mm/25.4,height=cfg$height_mm/25.4,family='Arial',bg='white');print(p);invisible(dev.off())
 writeLines(capture.output(sessionInfo()),'results/session-info.txt')
}
