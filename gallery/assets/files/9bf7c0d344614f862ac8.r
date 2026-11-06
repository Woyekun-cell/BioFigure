args<-commandArgs(TRUE);P<-normalizePath(args[1]);W<-file.path(P,'work/2026-10-28-batch-six/spatial');C<-file.path(P,'biofigure/benchmark/library/spatial/squidpy-seqfish-neighborhood-20261028')
suppressPackageStartupMessages({library(ggplot2);library(grid);library(gridExtra);library(ggplotify);library(jsonlite)})
capture_device<-ragg::agg_capture(width=183,height=150,units='mm',res=300,background='white')
a<-readRDS(file.path(W,'computations.rds'));d<-a$cells;e<-a$edges
focus<-c('Allantois','Dermomyotome','Endothelium','Haematoendothelial progenitors','Intermediate mesoderm','Lateral plate mesoderm','Presomitic mesoderm')
cols<-c('#315970','#B16A85','#628CA5','#D7A0AF','#8BAFBD','#4E7C86','#DFC4CB');names(cols)<-focus
zbox<-c(xmin=.15,xmax=.82,ymin=.28,ymax=.95)
theme_map<-theme_void(base_family='Arial',base_size=7)+theme(plot.margin=margin(4,4,3,4),plot.title=element_text(size=7,face='plain'),plot.tag=element_text(size=9,face='bold'),plot.tag.position=c(0,1))
map<-ggplot(d,aes(plot_x,plot_y))+geom_point(size=.37,colour='#D9DDE0',stroke=0)+geom_point(data=d[d$cell_type%in%focus,],aes(colour=cell_type),size=.46,stroke=0)+scale_colour_manual(values=cols,limits=focus,drop=FALSE)+coord_equal(expand=FALSE,clip='off')+theme_map+theme(legend.position='none')+annotate('rect',xmin=zbox[1],xmax=zbox[2],ymin=zbox[3],ymax=zbox[4],fill=NA,colour='#434A50',linewidth=.25,linetype=2)
leg<-grobTree(textGrob('Cell type',x=.03,y=.91,just='left',gp=gpar(fontfamily='Arial',fontsize=7)),pointsGrob(x=rep(.05,8),y=seq(.79,.13,length.out=8),pch=16,size=unit(1.4,'mm'),gp=gpar(col=c(cols,'#D9DDE0'))),textGrob(c(focus,'Other cells'),x=.10,y=seq(.79,.13,length.out=8),just='left',gp=gpar(fontfamily='Arial',fontsize=6.5)))
map<-grobTree(ggplotGrob(map),textGrob('a',x=unit(1,'mm'),y=unit(70,'mm'),just=c('left','top'),gp=gpar(fontfamily='Arial',fontface='bold',fontsize=9)))
top<-arrangeGrob(map,leg,ncol=2,widths=c(122,61))
# Heatmap is a vector grob: exact square cells, explicit row identities and Ward dendrogram.
n<-22L;ord<-a$hc$order;z<-a$z[ord,ord];cell<-2.55;mx<-51;my<-11;side<-n*cell
pal<-colorRampPalette(c('#497D97','#F4F3F0','#B56E87'),space='Lab')(256)
cc<-matrix(pal[pmax(1,pmin(256,round((pmax(-50,pmin(50,z))+50)/100*255)+1))],n,n)
ht<-grobTree(textGrob('b',x=unit(1,'mm'),y=unit(76,'mm'),just=c('left','top'),gp=gpar(fontfamily='Arial',fontface='bold',fontsize=9)),textGrob('Neighborhood enrichment',x=unit(mx+side/2,'mm'),y=unit(75,'mm'),gp=gpar(fontfamily='Arial',fontsize=7)))
for(i in 1:n)for(j in 1:n)ht<-addGrob(ht,rectGrob(x=unit(mx+(j-.5)*cell,'mm'),y=unit(my+(n-i+.5)*cell,'mm'),width=unit(cell,'mm'),height=unit(cell,'mm'),gp=gpar(fill=cc[i,j],col=NA)))
ht<-addGrob(ht,textGrob(rownames(z),x=unit(mx-1.7,'mm'),y=unit(my+(n-seq_len(n)+.5)*cell,'mm'),just='right',gp=gpar(fontfamily='Arial',fontsize=6.5)))
# Top Ward dendrogram; leaves use native hclust order. Branch heights rescaled into reserved 5mm lane.
hc<-a$hc;xx<-yy<-numeric(n-1);maxh<-max(hc$height)
for(k in seq_len(n-1)){ids<-hc$merge[k,];leafpos<-function(v)if(v<0)match(-v,ord)-.5 else xx[v];leafheight<-function(v)if(v<0)0 else yy[v];x1<-leafpos(ids[1]);x2<-leafpos(ids[2]);y1<-leafheight(ids[1]);y2<-leafheight(ids[2]);h<-hc$height[k]/maxh*4.8;xx[k]<-mean(c(x1,x2));yy[k]<-h;ht<-addGrob(ht,polylineGrob(x=unit(mx+c(x1,x1,x2,x2)*cell,'mm'),y=unit(my+side+.5+c(y1,h,h,y2),'mm'),gp=gpar(col='#555E65',lwd=.35)))}
for(i in 1:256)ht<-addGrob(ht,rectGrob(x=unit(mx+(i-.5)/256*side,'mm'),y=unit(6,'mm'),width=unit(side/256+.015,'mm'),height=unit(1.7,'mm'),gp=gpar(fill=pal[i],col=NA)))
ht<-addGrob(ht,grobTree(textGrob(c('-50','0','50'),x=unit(mx+c(0,.5,1)*side,'mm'),y=unit(3.3,'mm'),gp=gpar(fontfamily='Arial',fontsize=6.5)),textGrob('Z-score',x=unit(mx-2,'mm'),y=unit(6,'mm'),just='right',gp=gpar(fontfamily='Arial',fontsize=6.5))))
ht<-grobTree(ht,vp=viewport(width=unit(115,'mm'),height=unit(78,'mm')))
keep<-d$plot_x>=zbox[1]&d$plot_x<=zbox[2]&d$plot_y>=zbox[3]&d$plot_y<=zbox[4];idx<-which(keep);ek<-e[e$i%in%idx & e$j%in%idx,];ed<-data.frame(x=d$plot_x[ek$i],y=d$plot_y[ek$i],xend=d$plot_x[ek$j],yend=d$plot_y[ek$j])
pz<-ggplot()+geom_segment(data=ed,aes(x,y,xend=xend,yend=yend),colour='#CBD2D7',linewidth=.13)+geom_point(data=d[keep,],aes(plot_x,plot_y),size=.8,colour='#D9DDE0',stroke=0)+geom_point(data=d[keep&d$cell_type%in%focus,],aes(plot_x,plot_y,colour=cell_type),size=.85,stroke=0)+scale_colour_manual(values=cols)+coord_equal(xlim=zbox[1:2],ylim=zbox[3:4],expand=FALSE)+theme_map+labs(title='Delaunay neighborhood')+theme(legend.position='none',plot.margin=margin(12,7,7,4))
pz<-grobTree(ggplotGrob(pz),textGrob('c',x=unit(1,'mm'),y=unit(76,'mm'),just=c('left','top'),gp=gpar(fontfamily='Arial',fontface='bold',fontsize=9)))
bottom<-arrangeGrob(ht,pz,ncol=2,widths=c(115,68));g<-arrangeGrob(top,bottom,nrow=2,heights=unit(c(72,78),'mm'))
labels<-character();sizes<-numeric();fix<-function(x){if(inherits(x,'text')){x$gp$fontfamily<-'Arial';if(!is.null(x$gp$fontsize))sizes<<-c(sizes,x$gp$fontsize);if(!is.expression(x$label))labels<<-c(labels,as.character(x$label))};if(length(x$grobs))x$grobs<-lapply(x$grobs,fix);if(length(x$children))x$children<-do.call(gList,lapply(x$children,fix));x};g<-fix(g)
p<-as.ggplot(g)+theme_void(base_family='Arial',base_size=7)+theme(plot.margin=margin(0,0,0,0));saveRDS(p,file.path(W,'render-object.rds'));saveRDS(g,file.path(W,'composed-grob.rds'))
write_json(list(labels=unique(labels[nzchar(labels)]),font_sizes=sort(unique(sizes)),zoom=list(bounds=as.list(zbox),n_cells=sum(keep),n_edges=nrow(ed)),palette=as.list(cols)),file.path(W,'plot-qc.json'),pretty=TRUE,auto_unbox=TRUE)

dev.off()
