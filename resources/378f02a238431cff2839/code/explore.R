args<-commandArgs(TRUE);P<-normalizePath(args[1]);W<-file.path(P,'work/2026-11-05-omicscope-oxphos-chord');D<-file.path(P,'results/plot_data/omicscope_oxphos_chord_20261105');library(ggplot2);library(grid);source(file.path(P,'biofigure/scripts/figure_style.R'));font<-bf_font('Arial')
links<-read.csv(file.path(D,'links.csv'),check.names=FALSE);genes<-sort(unique(links$gene));studies<-c('Brain','Liver','Lung','Lung_RNA');cols<-c(Brain='#1E9E98',Liver='#E87055',Lung='#6574BE',Lung_RNA='#A1A83C');fc<-colorRampPalette(c('#7565AA','#F6F4EF','#DF9A2F'))(501)
xy<-function(theta,r)cbind(x=cos(theta*pi/180)*r,y=sin(theta*pi/180)*r)
arc<-function(a,b,r,n=max(5,ceiling(abs(b-a)*3)))xy(seq(a,b,length.out=n),r)
sector<-function(a,b,ri=.86,ro=.94)rbind(arc(a,b,ro),arc(b,a,ri))
bezier<-function(p0,p3,n=36){t<-seq(0,1,length.out=n);p1<-p0*.12;p2<-p3*.12;cbind(x=(1-t)^3*p0[1]+3*(1-t)^2*t*p1[1]+3*(1-t)*t^2*p2[1]+t^3*p3[1],y=(1-t)^3*p0[2]+3*(1-t)^2*t*p1[2]+3*(1-t)*t^2*p2[2]+t^3*p3[2])}
unit<-1.1;gap_gene<-.2;gap_study<-2;theta<-182.3;layout<-list()
for(g in genes){n<-sum(links$gene==g);layout[[g]]<-c(a=theta,b=theta-n*unit);theta<-theta-n*unit-gap_gene}
theta<-theta-gap_study+gap_gene
for(s in studies){n<-sum(links$study==s);layout[[s]]<-c(a=theta,b=theta-n*unit);theta<-theta-n*unit-gap_study}
polys<-list();tracks<-list();labels<-list();leaders<-list();counts<-setNames(integer(length(studies)),studies);ii<-0;ti<-0
for(g in genes){sub<-links[links$gene==g,];sub<-sub[match(intersect(studies,sub$study),sub$study),];gj<-0
 for(j in seq_len(nrow(sub))){s<-sub$study[j];ga<-layout[[g]][1]-gj*unit;gb<-ga-unit;sa<-layout[[s]][1]-counts[s]*unit;sb<-sa-unit;ii<-ii+1
  ribbon<-rbind(arc(ga,gb,.854),bezier(xy(gb,.854),xy(sa,.854)),arc(sa,sb,.854),bezier(xy(sb,.854),xy(ga,.854)));polys[[ii]]<-data.frame(ribbon,id=ii,study=s)
  ti<-ti+1;tracks[[ti]]<-data.frame(sector(ga,gb),id=ti,fill=fc[round((sub$display_fc[j]+1)*250)+1]);gj<-gj+1;counts[s]<-counts[s]+1
 }
}
for(s in studies){ti<-ti+1;tracks[[ti]]<-data.frame(sector(layout[[s]][1],layout[[s]][2]),id=ti,fill=unname(cols[s]))}
# Uniform label angles with monotone leaders prevent dense one-link labels colliding while preserving source sector/link widths.
angs<-seq(182.3,-2.3,length.out=length(genes));for(i in seq_along(genes)){g<-genes[i];mid<-mean(layout[[g]]);a<-angs[i];pt<-xy(a,1.045);angle<-a;if(a>90){angle<-a-180;hj<-1}else hj<-0;labels[[i]]<-data.frame(x=pt[1],y=pt[2],label=g,angle=angle,hjust=hj,size=6);leaders[[i]]<-data.frame(x=xy(mid,.944)[1],y=xy(mid,.944)[2],xend=xy(a,1.025)[1],yend=xy(a,1.025)[2])}
for(s in studies){a<-mean(layout[[s]]);pt<-xy(a,1.035);angle<-a+90;if(angle< -90)angle<-angle+180;labels[[length(labels)+1]]<-data.frame(x=pt[1],y=pt[2],label=gsub('_',' ',s),angle=angle,hjust=.5,size=8)}
poly<-do.call(rbind,polys);tr<-do.call(rbind,tracks);labs<-do.call(rbind,labels);leaders<-do.call(rbind,leaders)
cb<-data.frame(xmin=seq(-.44,.44,length.out=502)[1:501],xmax=seq(-.44,.44,length.out=502)[2:502],ymin=-1.28,ymax=-1.245,fill=fc);p<-ggplot()+geom_polygon(data=poly,aes(x,y,group=id,fill=study),alpha=.46,color=NA)+scale_fill_manual(values=cols,guide='none')+ggnewscale::new_scale_fill()+geom_polygon(data=tr,aes(x,y,group=id,fill=fill),color='white',linewidth=.075)+scale_fill_identity()+geom_segment(data=leaders,aes(x,y,xend=xend,yend=yend),color='#AEB4BA',linewidth=.16)+geom_text(data=labs,aes(x,y,label=label,angle=angle,hjust=hjust,size=size),family='Arial',color='#30343B',vjust=.5)+scale_size_identity()+geom_rect(data=cb,aes(xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax,fill=fill),inherit.aes=FALSE,color=NA)+annotate('text',x=0,y=1.34,label='Oxidative phosphorylation',family='Arial',size=9/ggplot2::.pt,color='#30343B')+annotate('text',x=0,y=-1.16,label='log2 fold change',family='Arial',size=7/ggplot2::.pt,color='#30343B')+annotate('text',x=c(-.44,0,.44),y=-1.345,label=c('-1','0','+1'),family='Arial',size=7/ggplot2::.pt,color='#30343B')+coord_equal(xlim=c(-1.42,1.42),ylim=c(-1.4,1.42),expand=FALSE,clip='off')+theme_void(base_family='Arial')+theme(plot.margin=margin(3,3,3,3,'mm'),plot.background=element_rect(fill='white',color=NA))
# geom_text uses mm; convert the specified publication font sizes from pt.
p$layers[[4]]$data$size<-p$layers[[4]]$data$size/ggplot2::.pt
saveRDS(p,file.path(W,'plot.rds'));ragg::agg_png(file.path(W,'preview.png'),width=183,height=170,units='mm',res=300,background='white');print(p);dev.off();write.csv(labs,file.path(W,'label-layout.csv'),row.names=FALSE);write.csv(tr,file.path(W,'arc-polygons.csv'),row.names=FALSE);write.csv(poly,file.path(W,'ribbon-polygons.csv'),row.names=FALSE);capture.output(sessionInfo(),file=file.path(W,'explore-sessionInfo.txt'))
