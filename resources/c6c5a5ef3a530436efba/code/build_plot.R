args<-commandArgs(TRUE);P<-normalizePath(args[1]);W<-file.path(P,'work/2026-11-06-sv-zoom-source-search');library(grid);library(circlize);library(jsonlite);cowplot::set_null_device('agg')
m<-fromJSON(file.path(W,'metadata.json'));pal<-unlist(m$palette);stem<-m$stem
rd<-function(n)read.csv(file.path(P,'results/plot_data',paste0(stem,'_',n,'.csv')),check.names=FALSE)
sv<-rd('sv');cn<-rd('cnv');sizes<-rd('sizes');cyto<-rd('cytoband');genes<-rd('genes');exons<-rd('exons');variants<-rd('variants');reads<-rd('reads');blocks<-rd('read_blocks');cov<-rd('coverage');bases<-rd('bases')
# circlize determines length-proportional sectors; grid keeps all exported marks editable.
ragg::agg_png(file.path(W,'circle-layout.png'),width=400,height=400,res=96);circos.clear();circos.par(start.degree=90,gap.degree=1.3,cell.padding=c(0,0,0,0),track.margin=c(0,0));circos.initialize(factors=factor(sizes$chromosome,levels=sizes$chromosome),xlim=cbind(0,sizes$length));circos.trackPlotRegion(ylim=c(0,1),track.height=.05,bg.border=NA,panel.fun=function(x,y){})
sectors<-data.frame(chromosome=sizes$chromosome,a=sapply(sizes$chromosome,function(c)circlize(0,.5,sector.index=c,track.index=1)[1,1]),b=sapply(sizes$chromosome,function(c)circlize(sizes$length[sizes$chromosome==c],.5,sector.index=c,track.index=1)[1,1]));circos.clear();dev.off();write.csv(sectors,file.path(W,'sector-geometry.csv'),row.names=FALSE)
G<-list();labels<-character();add<-function(g){G[[length(G)+1]]<<-g};ink<-'#263443';muted<-'#687684';light<-'#E5E9EC';ww<-183;hh<-170
ln<-function(x,y,col=ink,lwd=.5,lty=1) add(linesGrob(x/ww,y/hh,gp=gpar(col=col,lwd=lwd,lty=lty,lineend='round')))
rect<-function(x,y,w,h,col,border=NA,lwd=.4)add(rectGrob((x+w/2)/ww,(y+h/2)/hh,w/ww,h/hh,gp=gpar(fill=col,col=border,lwd=lwd)))
txt<-function(s,x,y,pt=7,col=ink,just='left',face='plain',rot=0){labels<<-c(labels,as.character(s));add(textGrob(s,x/ww,y/hh,just=just,rot=rot,gp=gpar(fontfamily='Arial',fontsize=pt,col=col,fontface=face)))}
poly<-function(x,y,col,border=NA,lwd=.4)add(polygonGrob(x/ww,y/hh,gp=gpar(fill=col,col=border,lwd=lwd)))
point<-function(x,y,col,r=.5)add(circleGrob(x/ww,y/hh,r=unit(r,'mm'),gp=gpar(fill=col,col=NA)))
angle<-function(c,p){i<-match(c,sectors$chromosome);(sectors$a[i]+(sectors$b[i]-sectors$a[i])*p/sizes$length[i])*pi/180}
xy<-function(c,p,r){a<-angle(c,p);cbind(39+r*cos(a),126+r*sin(a))}
arc<-function(c,a,b,r1,r2,col){p<-seq(a,b,length.out=max(4,ceiling((b-a)/sizes$length[match(c,sizes$chromosome)]*100)));q<-rbind(xy(c,p,r2),xy(c,rev(p),r1));poly(q[,1],q[,2],col)}
curve<-function(x,y,col,lwd=.5){t<-seq(0,1,length.out=45);bx<-(1-t)^3*x[1]+3*(1-t)^2*t*x[2]+3*(1-t)*t^2*x[3]+t^3*x[4];by<-(1-t)^3*y[1]+3*(1-t)^2*t*y[2]+3*(1-t)*t^2*y[3]+t^3*y[4];ln(bx,by,col,lwd)}
# Whole-genome panel: all source SVs retained, with gray interchromosomal links behind colored intrachromosomal links.
txt('a',4,164,10,face='bold');txt('SRR7890905',10,164,8,face='bold');txt('hg38',73,164,7,just='right',col=muted)
for(i in order(sv$chrom1==sv$chrom2)){
 r<-sv[i,];a<-xy(r$chrom1,r$start1,20.9);b<-xy(r$chrom2,r$end2,20.9);co<-pal[r$svclass];curve(c(a[1],39+(a[1]-39)*.25,39+(b[1]-39)*.25,b[1]),c(a[2],126+(a[2]-126)*.25,126+(b[2]-126)*.25,b[2]),adjustcolor(co,alpha.f=if(r$svclass=='TRA').38 else .74),if(r$svclass=='TRA').3 else .5)
}
for(i in seq_len(nrow(sizes))){c<-sizes$chromosome[i];arc(c,0,sizes$length[i],21.6,22.8,'#F0F3F4');arc(c,0,sizes$length[i],23.1,24.3,'#F0F3F4');p<-xy(c,sizes$length[i]/2,28.5);txt(sub('chr','',c),p[1],p[2],7,just='centre')}
for(i in seq_len(nrow(cn))){r<-cn[i,];c<-paste0('chr',r$chromosome);if(!c%in%sizes$chromosome)next;if(r$total_cn>=5)arc(c,r$start,r$end,23.1,24.3,pal['Gain']);if(r$minor_cn<=.01 && r$total_cn!=0)arc(c,r$start,r$end,21.6,22.8,pal['LOH'])}
stains<-c(gneg='#F4F6F7',gpos25='#BCC5CE',gpos50='#8694A2',gpos75='#576879',gpos100='#344657',acen='#B8A1C8',gvar='#D9E1E5',stalk='#D9E1E5')
for(i in seq_len(nrow(cyto))){r<-cyto[i,];arc(r$Chromosome,r$chromStart,r$chromEnd,24.8,26.4,stains[r$Stain])}
arc('chr10',87700000,88150000,26.8,27.8,pal['DEL']);p<-xy('chr10',87954020,27);ln(c(p[1],24,24,75,75,91),c(p[2],97,94,94,155,155),pal['DEL'],.7,2)
legend<-function(x,y,s,col){ln(c(x,x+3),c(y,y),col,2);txt(s,x+4.5,y)}
legend(8,92,'Deletion',pal['DEL']);legend(42,92,'Duplication',pal['DUP']);legend(8,87,'Inversion (TT)',pal['t2tINV']);legend(42,87,'Inversion (HH)',pal['h2hINV']);legend(8,82,'Translocation',pal['TRA']);legend(42,82,'Gain',pal['Gain']);legend(42,77,'LOH',pal['LOH'])
# Coordinate-aligned locus tracks. Original source coordinates; no liftover.
xmin<-87700000;xmax<-88150000;x0<-96;x1<-176;xx<-function(x)x0+(x-xmin)/(xmax-xmin)*(x1-x0);cx<-function(x)xx(pmin(xmax,pmax(xmin,x)))
txt('b',80,164,10,face='bold');txt('chr10 / PTEN',87,164,8,face='bold');txt('Position (Mb)',176,158,7,just='right',col=muted)
for(x in seq(87700000,88100000,100000)){ln(c(xx(x),xx(x)),c(151,153),muted,.5);txt(sprintf('%.1f',x/1e6),xx(x),155,7,just='centre')};ln(c(x0,x1),c(151,151),muted,.5)
cc<-cyto[cyto$Chromosome=='chr10' &cyto$chromStart<xmax &cyto$chromEnd>xmin,];for(i in seq_len(nrow(cc)))rect(cx(cc$chromStart[i]),147,cx(cc$chromEnd[i])-cx(cc$chromStart[i]),2.2,stains[cc$Stain[i]])
for(i in seq_len(nrow(genes))){r<-genes[i,];y<-143-(i-1)*5;txt(r$gene,94,y,7,just='right',face='italic',col=if(r$gene=='PTEN')pal['DEL']else ink);ln(c(cx(r$start),cx(r$end)),c(y,y),ink,.6);e<-exons[exons$gene==r$gene &exons$start<xmax &exons$end>xmin,];for(j in seq_len(nrow(e)))rect(cx(e$start[j]),y-.75,cx(e$end[j])-cx(e$start[j]),1.5,if(r$gene=='PTEN')pal['DEL']else '#516B7C');for(x in seq(max(xmin,r$start),min(xmax,r$end),by=20000)){d<-if(r$strand=='+')1 else -1;ln(c(xx(x)-.6*d,xx(x),xx(x)-.6*d),c(y-.45,y,y+.45),ink,.5)}}
for(typ in c('snv','indel')){y<-if(typ=='snv')127 else 123;txt(if(typ=='snv')'SNV'else'Indel',94,y,7,just='right',col=muted);ln(c(x0,x1),c(y,y),light,.4);v<-variants[variants$kind==typ,];for(i in seq_len(nrow(v)))if(typ=='snv')point(xx(v$start0[i]),y,pal[substr(v$alt[i],1,1)],.35)else ln(rep(xx(v$start0[i]),2),c(y-.8,y+.8),pal['h2hINV'],1)}
cnlocal<-cn[cn$chromosome=='10' &cn$start<xmax &cn$end>xmin,];txt('CN',94,115,7,just='right',col=muted)
for(v in c(0,2,4)){y<-109+v*2.1;ln(c(x0,x1),c(y,y),light,.4);txt(v,178,y,7,col=muted)}
for(i in seq_len(nrow(cnlocal))){r<-cnlocal[i,];ln(c(cx(r$start),cx(r$end)),rep(109+r$total_cn*2.1,2),'#516B7C',1.5)}
for(n in c('Gain','LOH')){y<-if(n=='Gain')105 else 101;txt(n,94,y+1,7,just='right',col=muted);rect(x0,y,x1-x0,2,'#F0F3F4');for(i in seq_len(nrow(cnlocal))){r<-cnlocal[i,];yes<-if(n=='Gain')r$total_cn>=5 else r$minor_cn<=.01&&r$total_cn!=0;if(yes)rect(cx(r$start),y,cx(r$end)-cx(r$start),2,pal[n])}}
bp1<-87954020;bp2<-88010560;txt('SV',94,97,7,just='right',col=muted);ln(c(x0,x1),c(97,97),light,.5)
local<-sv[sv$chrom1=='chr10' &sv$start1>=xmin &sv$start1<xmax,]
for(i in seq_len(nrow(local))){r<-local[i,];if(r$chrom2=='chr10'){curve(c(xx(r$start1),xx(r$start1),xx(r$end2),xx(r$end2)),c(97,87,87,97),pal[r$svclass],1.7);for(p in c(r$start1,r$start2))ln(rep(xx(p),2),c(97,76),pal['DEL'],.65,2)}else{ln(rep(xx(r$start1),2),c(97,82),pal['TRA'],1.2);txt('chr17',xx(r$start1),80,7,just='centre',col=muted)}}
txt('56.54 kb',mean(xx(c(bp1,bp2))),86,7,just='centre',col=pal['DEL']);ln(c(xx(bp1),47),c(76,73),pal['DEL'],.65,2);ln(c(xx(bp2),135),c(76,73),pal['DEL'],.65,2)
# Both read views retain all regional alignments and use identical axes and lane heights.
maxlane<-max(reads$lane);maxcov<-ceiling(max(cov$depth)/10)*10
for(side in c('left','right')){
 left<-side=='left';lo<-if(left)87953700 else 88010250;hi<-lo+650;bp<-if(left)bp1 else bp2;xa<-if(left)15 else 104;xb<-xa+64;rx<-function(x)xa+(x-lo)/650*64;clipx<-function(x)rx(pmax(lo,pmin(hi,x)))
 txt(if(left)'c'else'd',if(left)4 else 93,70,10,face='bold');txt(if(left)'Left breakpoint'else'Right breakpoint',xa,70,8,face='bold');txt(format(bp,big.mark=',',scientific=FALSE),xb,70,7,just='right',col=pal['DEL'])
 ticks<-seq(ceiling(lo/200)*200,floor(hi/200)*200,200);for(x in ticks){ln(rep(rx(x),2),c(63,64),muted,.5);txt(format(x,big.mark=',',scientific=FALSE),rx(x),66,7,just='centre')};ln(c(xa,xb),c(63,63),muted,.5)
 cv<-cov[cov$side==side,];poly(c(rx(cv$pos),xb,xa),c(54+cv$depth/maxcov*7,54,54),'#BCC9D2');txt('0',xa-2,54,7,just='right',col=muted);txt(maxcov,xa-2,61,7,just='right',col=muted)
 bs<-bases[bases$side==side,];for(i in seq_len(nrow(bs)))rect(rx(bs$pos[i]),51,64/650,1.7,pal[bs$base[i]])
 rect(xa,9,xb-xa,40.5,'#FAFBFC');b<-blocks[blocks$side==side,];for(i in order(b$kind!='aligned')){r<-b[i,];if(r$end<=lo ||r$start>=hi)next;y<-49.4-(r$lane-.5)*40/maxlane;h<-.78*40/maxlane;co<-if(r$kind=='aligned')if(r$sv_type=='regular')'#CED7DD'else pal[r$sv_type]else if(r$kind=='clip')'#506171'else if(r$kind%in%c('D','N'))'#9AA8B3'else pal[r$kind];if(r$kind%in%c('D','N'))ln(c(clipx(r$start),clipx(r$end)),c(y,y),co,.4)else rect(clipx(r$start),y-h/2,clipx(r$end)-clipx(r$start),h,co)}
 ln(rep(rx(bp),2),c(9,62),pal['DEL'],.75,2);point(rx(bp),62,pal['DEL'],.55)
}
legend(15,4.5,'Paired across breakpoints',pal['DEL']);legend(65,4.5,'Clipped','#506171');for(i in seq_along(c('A','C','G','T'))){b<-c('A','C','G','T')[i];rect(106+(i-1)*14,3.6,2,1.8,pal[b]);txt(b,109+(i-1)*14,4.5)}
g<-gTree(children=do.call(gList,G));saveRDS(g,file.path(W,'plot.rds'));write_json(unique(labels),file.path(W,'rendered-labels.json'),auto_unbox=TRUE,pretty=TRUE);write_json(list(SV=nrow(sv),CN=nrow(cn),read_count=nrow(reads),max_lane=maxlane,coverage_max=maxcov,marks=length(G),assembly='hg38',focal_sv='gridss176fb_3143o'),file.path(W,'geometry-summary.json'),auto_unbox=TRUE,pretty=TRUE)
cat('Native vector composition built:',length(G),'grobs\n')
