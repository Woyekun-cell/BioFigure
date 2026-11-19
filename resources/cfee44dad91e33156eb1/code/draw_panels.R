draw_panels<-function(features,pairs,metrics_path=NULL){
 library(grid);grid.newpage();texts<-character();sizes<-numeric();gp<-function(sz=6.5,...)gpar(fontfamily='Arial',fontsize=sz,...)
 text<-function(label,x,y,sz=6.5,just='left',...){texts<<-c(texts,as.character(label));sizes<<-c(sizes,sz);grid.text(label,unit(x,'mm'),unit(y,'mm'),just=just,gp=gp(sz,...))}
 family_colors<-c(bf_palette('npg-inspired-10',kind='categorical',n=10,skill_root=S)[c(2,8,3,1,5,6,7,4,9,10)],bf_palette('tol-muted-9',kind='categorical',n=9,skill_root=S)[c(2,3,4,7,9)]);names(family_colors)<-paste0('F',1:15)
 col<-c(family_colors,'LTR'='#B9BFC6','Other repeat'='#E2E5E9','Interval'='#FFFFFF','Gene'='#30343B');strand<-setNames(bf_palette('tol-bright-7',kind='categorical',n=7,skill_root=S)[c(2,5)],c('+','-'));te<-setNames(bf_palette('tableau-10',kind='categorical',n=10,skill_root=S)[c(1,5,2,9)],c('SZ-22','RIRE','Other LTR','DNA transposon'))
 x0<-24;dw<-153
 block<-function(label,top,lo,hi,ticks){
  text(label,2,top+10,8,fontface='bold');text(if(label=='A')'Chr1'else'Chr1: 0–60 kb',x0,top+10,7,fontface='bold')
  for(s in c('NIP','SL177')){yy<-if(s=='NIP')c(top,top-4,top-8)else c(top-32,top-28,top-24);for(j in 1:3){grid.rect(unit(x0,'mm'),unit(yy[j],'mm'),unit(dw,'mm'),unit(2.5,'mm'),just=c('left','center'),gp=gpar(fill='white',col='#A6ADB5',lwd=.3));text(c('TE','Strand','Family')[j],x0-1,yy[j],6.5,'right')};text(s,2,if(s=='NIP')top-4 else top-28,7,fontface='bold')}
  pushViewport(viewport(x=unit(x0,'mm'),y=unit(top-16,'mm'),width=unit(dw,'mm'),height=unit(44,'mm'),xscale=c(lo,hi),yscale=c(top-38,top+6),just=c('left','center'),clip='on'))
  pp<-pairs;stopifnot(all(pp$ref_family%in%names(col)))
  for(i in seq_len(nrow(pp))){z<-pp[i,];grid.polygon(x=unit(c(z$ref_start,z$ref_end,z$query_end,z$query_start)/1000,'native'),y=unit(c(top-9.3,top-9.3,top-22.7,top-22.7),'native'),gp=gpar(fill=unname(col[z$ref_family]),alpha=.6,col=NA))}
  for(s in c('NIP','SL177')){
   d<-features[features$sample==s,];yy<-if(s=='NIP')c(top,top-4,top-8)else c(top-32,top-28,top-24)
   rects<-function(dd,y,colors){if(!nrow(dd))return();grid.rect(x=unit(dd$start/1000,'native'),y=unit(rep(y,nrow(dd)),'native'),width=unit((dd$end-dd$start)/1000,'native'),height=unit(rep(2.5,nrow(dd)),'native'),just=c('left','center'),gp=gpar(fill=colors,col=NA))}
   rects(d,yy[3],unname(col[d$family]));z<-d[d$strand%in%c('+','-')&grepl('^F[0-9]+$',d$family),];rects(z,yy[2],unname(strand[z$strand]));z<-d[nzchar(d$te),];rects(z,yy[1],unname(te[z$te]))
  }
  upViewport();axisy<-top-37
  grid.lines(unit(c(x0,x0+dw),'mm'),unit(rep(axisy,2),'mm'),gp=gpar(col='#59616A',lwd=.5))
  for(v in ticks){xx<-x0+dw*(v-lo)/(hi-lo);grid.lines(unit(rep(xx,2),'mm'),unit(c(axisy,axisy-1),'mm'),gp=gpar(col='#59616A',lwd=.5));text(as.character(v),xx,axisy-2.5,6.5,'center')}
  text('Position within annotated interval (kb)',x0+dw/2,axisy-7,7,'center')
 }
 block('A',132,0,750,seq(0,700,100));block('B',75,0,60,seq(0,60,10))
 key<-function(label,color,x,y,w=2){grid.rect(unit(x,'mm'),unit(y,'mm'),unit(w,'mm'),unit(1.8,'mm'),just=c('left','center'),gp=gpar(fill=color,col=if(color=='#FFFFFF')'#A6ADB5'else NA,lwd=.3));text(label,x+w+1,y)}
 for(i in 1:15)key(paste0('F',i),family_colors[i],16+(i-1)*10.5,24)
 labs<-c('LTR','Other repeat','Interval','Gene');for(i in 1:4)key(labs[i],col[labs[i]],c(16,51,97,135)[i],18)
 for(i in 1:4)key(names(te)[i],te[i],c(16,51,97,135)[i],12)
 key('Strand +',strand['+'],16,6);key('Strand −',strand['-'],51,6);text('Links: NIP family',97,6)
 if(!is.null(metrics_path))jsonlite::write_json(list(rendered_text=unique(texts),point_sizes=unique(sizes),heatmap_cells=list(),rendered_size=list(width_mm=183,height_mm=146),tracks=list(width_mm=153,height_mm=2.5),family_palette=as.list(family_colors),link_colors=data.frame(pair_id=pairs$pair_id,reference_family=pairs$ref_family,color=unname(col[pairs$ref_family]),alpha=.6)),metrics_path,pretty=TRUE,auto_unbox=TRUE)
 invisible(NULL)
}
