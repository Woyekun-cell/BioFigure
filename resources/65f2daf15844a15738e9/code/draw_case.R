library(grid)
pal<-c(DEL='#EF765F',DUP='#16A596',HH='#8270C7',TT='#DBA43A',HT='#EF765F',TH='#16A596',Interchr='#548FC2',Forward='#96CFC5',Deletion='#EF765F',Inversion='#8270C7',Duplication='#DBA43A','Locus 1'='#14A598','Locus 2'='#E98272',Flank='#DCE2E7')
draw_case<-function(q,P,metrics_path=NULL){
 H<-q$height;labels<-character();geometry<-list();grid.newpage();pushViewport(viewport(xscale=c(0,183),yscale=c(0,H)))
 tx<-function(s,x,y,size=7,just='centre',col='#283642',face='plain',rot=0){labels<<-c(labels,as.character(s));grid.text(s,x=unit(x,'native'),y=unit(y,'native'),just=just,rot=rot,gp=gpar(fontfamily='Arial',fontsize=size,col=col,fontface=face))}
 ln<-function(x,y,col='#C7CED5',lwd=.6,lty=1){grid.lines(unit(x,'native'),unit(y,'native'),gp=gpar(col=col,lwd=lwd,lty=lty,lineend='round'))}
 rect<-function(x,y,w,h,fill,col=NA,lwd=.4){grid.rect(unit(x,'native'),unit(y,'native'),unit(w,'native'),unit(h,'native'),just=c('left','bottom'),gp=gpar(fill=fill,col=col,lwd=lwd))}
 poly<-function(x,y,fill,col=NA,lwd=.4){grid.polygon(unit(x,'native'),unit(y,'native'),gp=gpar(fill=fill,col=col,lwd=lwd))}
 curve<-function(x1,y1,x2,y2,lift,col,lwd=.7){t<-seq(0,1,length.out=81);x<-(1-t)*x1+t*x2;y<-(1-t)*y1+t*y2+4*lift*t*(1-t);ln(x,y,col,lwd);c(mean(c(x1,x2)),mean(c(y1,y2))+lift)}
 dots<-function(x,y,col,size=.5,pch=16){grid.points(unit(x,'native'),unit(y,'native'),pch=pch,size=unit(size,'mm'),gp=gpar(col=col,fill=col))}
 key<-function(items,x,y,spacing=28){for(i in seq_along(items)){s<-items[i];rect(x+(i-1)*spacing,y-1.1,3.8,2.2,pal[s]);tx(s,x+5.3+(i-1)*spacing,y,just='left')}}
 read<-function(name)read.csv(file.path(P,'results/plot_data',paste0(q$stem,'_',name,'.csv')),check.names=FALSE)
 if(q$key=='recon'){
  cn<-read('cn');sv<-read('sv');key(c('DEL','DUP','HH','TT'),20,130,26);ln(c(131,137),c(130,130),'#283642',1.8);tx('Total CN',139,130,just='left');ln(c(158,164),c(130,130),'#14A598',1.8);tx('Minor',166,130,just='left')
  profile<-function(sample,x0,w,lo,hi,base,ch,top,title,ticks){
   xx<-function(v)x0+(v-lo)/(hi-lo)*w
   for(v in c(0,2,4,6,8,10)){ln(c(x0,x0+w),rep(base+v/10*ch,2),'#E9EDF0',.5);tx(v,x0-2,base+v/10*ch,just='right')}
   d<-cn[cn$sample==sample&cn$end>lo&cn$start<hi,]
   for(i in seq_len(nrow(d))){z<-d[i,];ln(xx(c(max(lo,z$start),min(hi,z$end))),rep(base+z$total/10*ch,2),'#293D4B',1.7);ln(xx(c(max(lo,z$start),min(hi,z$end))),rep(base+z$minor/10*ch,2),pal['Locus 1'],1.5)}
   z<-sv[sv$start>=lo&sv$end<=hi,];for(i in seq_len(nrow(z))){v<-z[i,];y<-base+ch+2+(match(v$type,c('DEL','DUP','HH','TT'))-1)*3.3;ln(rep(xx(v$start),2),c(base,y),adjustcolor(pal[v$type],.35),.4);ln(rep(xx(v$end),2),c(base,y),adjustcolor(pal[v$type],.35),.4);curve(xx(v$start),y,xx(v$end),y,2.3,pal[v$type],.65)}
   bands<-seq(lo,hi,length.out=31);for(i in 1:30)rect(xx(bands[i]),base-3.3,w/30,1.7,c('#D5DEE5','#F2F4F6','#8D9EA9')[1+(i%%3)])
   for(v in ticks){ln(rep(xx(v),2),c(base-4,base-5));tx(v,xx(v),base-7.2)}
   tx(title,x0,top,8,just='left',face='bold');tx('CN',x0-10,base+ch/2,rot=90)
  }
  profile('Profile A',16,72,0,85,82,18,121,'Profile A',c(0,20,40,60,80))
  profile('Profile B',108,72,0,85,82,18,121,'Profile B',c(0,20,40,60,80))
  for(x0 in c(16)){a<-x0+32/85*72;b<-x0+46/85*72;rect(a,77,b-a,39,NA,'#9CAAB6',.7);ln(c(a,24),c(76,71),'#C9D1D8',.6,2);ln(c(b,178),c(76,71),'#C9D1D8',.6,2)}
  profile('Profile A',24,154,32,46,20,23,68,'Profile A / chr17: 32-46 Mb',seq(32,46,2));tx('Chromosome 17 position (Mb)',103,6)
  geometry<-list(CN_profiles=2,zoom=c(32,46),CN_segments=nrow(cn),SV_events=nrow(sv),zoom_events=sum(sv$start>=32&sv$end<=46))
 }else if(q$key=='haplotypes'){
  seg<-read('segments');walk<-read('walks');xx<-function(v)20+(v+12)/36*108
  for(k in 1:2){phase<-c('cis','trans')[k];base<-if(k==1)78 else 24;top<-base+36
   tx(paste(phase,'derivative walks'),20,top+5,8,just='left',face='bold');tx('Gap lengths',147,top+5,8,just='left',face='bold')
   s<-seg[seg$phase==phase,];for(i in seq_len(nrow(s))){z<-s[i,];rect(xx(z$start),base+(36-z$rank)*.94,xx(z$end)-xx(z$start),.79,pal[z$role])}
   ln(c(xx(0),xx(0)),c(base-1,top),'#657985',.6,2)
   for(v in c(-10,0,10,20)){ln(rep(xx(v),2),c(base-1,base-2));tx(v,xx(v),base-4.5)}
   tx('Walk rank',8,base+17,rot=90);tx('1',16,base+33.5,just='right');tx('36',16,base+.5,just='right')
   for(j in 1:2){d<-density(log10(walk[walk$phase==phase,paste0('locus',j)]*1000),bw=.18,from=1.5,to=5,n=256);dy<-base+4+(2-j)*16;dx<-143+(d$x-1.5)/3.5*36;yy<-dy+d$y/max(d$y)*10;poly(c(dx[1],dx,tail(dx,1)),c(dy,yy,dy),adjustcolor(pal[paste('Locus',j)],.75));ln(c(143,179),c(dy,dy),'#CAD3DA',.45)}
   for(v in c(2,3,4,5))tx(c('100','1k','10k','100k')[v-1],143+(v-1.5)/3.5*36,base-4.5,6.5)
  }
  tx('Derivative coordinate from first junction (kb)',74,13);tx('Length (bp)',161,13);key(c('Locus 1','Locus 2','Flank'),42,5,36)
  geometry<-list(walks=nrow(walk),segments=nrow(seg),row_pitch_mm=.94,coordinate_limits=c(-12,24),density='Gaussian KDE of log10 gap length in bp, bw=0.18; visual summary only')
 }else if(q$key=='svision'){
  seg<-read('segments');cov<-read('coverage');key(c('Forward','Deletion','Inversion','Duplication'),20,121,40)
  # The vector adaptation preserves the author's upper/control and lower/case bands.
  x0<-19;y0<-44;sz<-67;xx<-function(v)x0+v/60*sz;yy<-function(v)y0+sz-v/60*sz
  rect(x0,y0,sz,sz,'white','#BBC7D0');for(v in seq(0,60,10)){ln(c(xx(v),xx(v)),c(y0,y0+sz),'#EDF1F4',.4);ln(c(x0,x0+sz),rep(yy(v),2),'#EDF1F4',.4);tx(v,xx(v),y0-3);tx(v,x0-3,yy(v),just='right')}
  pushViewport(viewport(x=unit(x0+sz/2,'native'),y=unit(y0+sz/2,'native'),width=unit(sz,'native'),height=unit(sz,'native'),xscale=c(x0,x0+sz),yscale=c(y0,y0+sz),clip='on'))
  for(i in seq_len(nrow(seg))){z<-seg[i,];a<-xx(z$ref_start);b<-xx(z$ref_end);c<-yy(z$query_start);d<-yy(z$query_end);co<-pal[z$component];normal<-c(-(d-c),b-a);normal<-normal/sqrt(sum(normal^2));
   for(j in 1:2){sign<-if(j==1)1 else -1;f<-z[[if(j==1)'control_fraction' else 'case_fraction']];offset<-normal*sign*.8;wid<-normal*sign*(.8+3.5*f);poly(c(a+offset[1],b+offset[1],b+wid[1],a+wid[1]),c(c+offset[2],d+offset[2],d+wid[2],c+wid[2]),adjustcolor(co,.85))};ln(c(a,b),c(c,d),'#273A47',1.1)
  }
  upViewport();tx('Reference position (kb)',52,35);tx('Upper: control / Lower: case',52,29,6.5);tx('Derivative position (kb)',5,78,rot=90);tx('Sequence representation',19,114,8,just='left',face='bold')
  tx('Augmented coverage',101,114,8,just='left',face='bold');xx2<-function(v)102+v/60*76
  for(k in 1:2){sam<-c('Control','Case')[k];base<-if(k==1)86 else 53;d<-cov[cov$sample==sam,];mx<-50
   for(v in c(0,25,50)){ln(c(102,178),rep(base+v/50*18,2),'#E8EDF1',.5);tx(v,99,base+v/50*18,6.5,just='right')}
   poly(c(xx2(d$pos[1]),xx2(d$pos),xx2(tail(d$pos,1))),c(base,base+d$coverage/mx*18,base),'#DAE8ED');ln(xx2(d$pos),base+d$coverage/mx*18,'#5C8494',.55)
   for(i in c(2,4,5)){z<-seg[i,];f<-z[[if(k==1)'control_fraction' else 'case_fraction']];rect(xx2(z$ref_start),base-3.5,xx2(z$ref_end)-xx2(z$ref_start),2.3,pal[z$component]);tx(sprintf('%.0f%%',f*100),mean(xx2(c(z$ref_start,z$ref_end))),base-7.2,6.5)}
   tx(sam,102,base+20,8,just='left',face='bold');if(k==2)for(v in c(0,20,40,60))tx(v,xx2(v),base-12,6.5)
  }
  tx('Reference position (kb)',140,35)
  # Coordinate-proportional segment maps, distinct reference and derivative lengths.
  tx('Reference',18,24,just='left');tx('Derivative',18,14,just='left');rx<-function(v)51+v/60*127
  ref<-data.frame(a=c(0,6,12,20,28,40),b=c(6,12,20,28,40,60),l=c('A','B','C','D','E','F'));colors<-c('#A8D8CE','#DBA43A','#A8D8CE','#EF765F','#8270C7','#A8D8CE')
  for(i in 1:6){rect(rx(ref$a[i]),22.3,rx(ref$b[i])-rx(ref$a[i])-.25,3.4,colors[i]);tx(ref$l[i],mean(rx(c(ref$a[i],ref$b[i]))),24,6.5)}
  parts<-data.frame(a=c(0,6,12,18,26,38),b=c(6,12,18,26,38,58),l=c('A','B','B','C','E','F'),c=colors[c(1,2,2,3,5,6)])
  for(i in 1:6){a<-rx(parts$a[i]);b<-rx(parts$b[i]);rev<-parts$l[i]=='E';poly(if(rev)c(a,a+.8,b,b,a+.8)else c(a,b-.8,b,b-.8,a),if(rev)c(14,12.3,12.3,15.7,15.7)else c(12.3,12.3,14,15.7,15.7),parts$c[i]);tx(parts$l[i],(a+b)/2,14,6.5)}
  geometry<-list(reference_kb=60,derivative_kb=58,segments=nrow(seg),deletion_kb=8,duplication_kb=6,inversion_kb=12,bands='upper control, lower case; thickness=fraction x3.5mm; explicit vectors not inferred model output')
 }else if(q$key=='breakgraph'){
  seg<-read('segments');junction<-read('junctions');key(c('HT','TH','HH','TT','Interchr'),30,125,29)
  drawgraph<-function(fixture,x0,y0,w,h,limits){
   s<-seg[seg$fixture==fixture,];j<-junction[junction$fixture==fixture,];xx<-function(v)x0+(v-limits[1])/diff(limits)*w;yy<-function(v)y0+v*h/4
   ticks<-if(fixture=='local')seq(12,26,2)else seq(0,160,40)
   for(v in ticks){ln(rep(xx(v),2),c(y0-1,y0+h),'#EDF1F4',.5);tx(v,xx(v),y0-5,6.5)}
   for(i in seq_len(nrow(j))){z<-j[i,];a<-s[s$id==z$source,];b<-s[s$id==z$target,];ya<-yy(a$lane);yb<-yy(b$lane);lift<-if(fixture=='local')5+(i%%5)*2 else 2;mid<-curve(xx(a$end),ya,xx(b$start),yb,lift,adjustcolor(pal[z$type],.85),.9);dots(mid[1],mid[2],pal[z$type],.85,pch=18)}
   for(i in seq_len(nrow(s))){z<-s[i,];ln(xx(c(z$start,z$end)),rep(yy(z$lane),2),'#5FAE9C',3.4)}
   if(fixture=='local')tx('chr9',x0-3,y0,7,just='right')else for(l in unique(s$lane))tx(unique(s$chrom[s$lane==l]),x0-3,yy(l),7,just='right')
   tx('Position (Mb)',x0+w/2,y0-12)
  }
  tx('Local breakpoint cluster',19,115,8,just='left',face='bold');drawgraph('local',19,82,159,28,c(12,26));tx('Multi-chromosome junctions',19,62,8,just='left',face='bold');drawgraph('multi',19,20,159,32,c(0,160))
  geometry<-list(segments=nrow(seg),junctions=nrow(junction),local_rows=3,multi_chromosomes=5,semantic='Thick segments are genomic intervals; midpoint diamonds annotate junctions, not physical breakpoint coordinates; x-axis uses genomic position in each row')
 }
 grid.force(redraw=FALSE);upViewport()
 if(!is.null(metrics_path))jsonlite::write_json(list(rendered_text=unique(labels),geometry=geometry,size=list(width_mm=183,height_mm=H)),metrics_path,auto_unbox=TRUE,pretty=TRUE,digits=NA)
 invisible(unique(labels))
}
