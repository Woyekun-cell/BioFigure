library(grid)
pal<-c(A='#E57967',B='#229E98',C='#8970BB',D='#CEA13B')
.heatdata<-NULL
compose_plot<-function(g,q){
 if(!q$key %in% c('proteomap','longitudinal'))return(cowplot::ggdraw(g))
 cell<-if(q$key=='longitudinal')3.3 else 2.35
 p<-ggplot2::ggplot()+ggplot2::annotation_custom(g,xmin=0,xmax=183,ymin=0,ymax=q$height)+ggplot2::geom_tile(data=.heatdata,ggplot2::aes(x=x,y=y,fill=value),width=cell,height=cell,colour='white',linewidth=.025)+ggplot2::scale_fill_gradientn(colours=c('#305D85','#FAFAF5','#D96B5D'),limits=c(-3,3),na.value='#E5EAED',guide='none')+ggplot2::coord_fixed(xlim=c(0,183),ylim=c(0,q$height),expand=FALSE)+ggplot2::theme_void()+ggplot2::theme(plot.margin=ggplot2::margin(0,0,0,0))
 if(q$key=='longitudinal')p<-p+ggplot2::annotate('segment',x=84,xend=84,y=170,yend=222.8,colour='#677E8D',linewidth=.25,linetype=2)
 p

}
draw_case<-function(q,P,metrics_path=NULL){
 H<-q$height;labels<-character();geometry<-list();grid.newpage();pushViewport(viewport(xscale=c(0,183),yscale=c(0,H)))
 tx<-function(s,x,y,size=7,just='centre',col='#283642',face='plain',rot=0){labels<<-c(labels,as.character(s));grid.text(s,x=unit(x,'native'),y=unit(y,'native'),just=just,rot=rot,gp=gpar(fontfamily='Arial',fontsize=size,col=col,fontface=face))}
 ln<-function(x,y,col='#C7CED5',lwd=.6,lty=1){grid.lines(unit(x,'native'),unit(y,'native'),gp=gpar(col=col,lwd=lwd,lty=lty,lineend='round'))}
 rect<-function(x,y,w,h,fill,col=NA,lwd=.4){grid.rect(unit(x,'native'),unit(y,'native'),unit(w,'native'),unit(h,'native'),just=c('left','bottom'),gp=gpar(fill=fill,col=col,lwd=lwd))}
 poly<-function(x,y,fill,col=NA,lwd=.4){grid.polygon(unit(x,'native'),unit(y,'native'),gp=gpar(fill=fill,col=col,lwd=lwd))}
 dots<-function(x,y,col,size=.8,pch=16){grid.points(unit(x,'native'),unit(y,'native'),pch=pch,size=unit(size,'mm'),gp=gpar(col=col,fill=col))}
 read<-function(name)read.csv(file.path(P,'results/plot_data',paste0(q$stem,'_',name,'.csv')),check.names=FALSE)
 # Return recursive dendrogram nodes with leaf centres; branching never inferred from labels.
 tree_nodes<-function(hc){n<-length(hc$order);a<-setNames(seq_len(n),hc$order);nodes<-vector('list',n-1);for(i in seq_len(n-1)){m<-hc$merge[i,];children<-lapply(m,function(j)if(j<0)list(x=unname(a[as.character(-j)]),h=0,leaves=-j)else nodes[[j]]);nodes[[i]]<-list(x=mean(vapply(children,`[[`,numeric(1),'x')),h=hc$height[i],children=children,leaves=unlist(lapply(children,`[[`,'leaves')))};nodes}
 if(q$key=='chemring'){
  f<-read('features');m<-read('metadata');hc<-hclust(dist(as.matrix(f[,-1])),method='ward.D2');nodes<-tree_nodes(hc);ord<-hc$order;cl<-cutree(hc,k=8);cp<-c('#E57967','#229E98','#8970BB','#CEA13B','#477BA2','#C275A1','#78A56C','#B58A62');cx<-65;cy<-66
  theta<-function(k)(97-(k-.5)/64*344)*pi/180
  xy<-function(a,r)cbind(cx+cos(a)*r,cy+sin(a)*r)
  radial<-function(a,r1,r2,col,lwd=.7){z<-xy(a,c(r1,r2));ln(z[,1],z[,2],col,lwd)}
  arc<-function(a,b,r,col,lwd=.7){z<-xy(seq(a,b,length.out=60),r);ln(z[,1],z[,2],col,lwd)}
  sector<-function(a,b,lo,hi,col){th<-seq(a,b,length.out=20);z<-rbind(xy(th,lo),xy(rev(th),hi));poly(z[,1],z[,2],col)}
  for(k in 1:8){idx<-which(cl[ord]==k);sector(theta(max(idx)+.45),theta(min(idx)-.45),9,43,adjustcolor(cp[k],.085))}
  for(n in nodes){r<-42-(n$h/max(hc$height))*34;ccl<-unique(cl[n$leaves]);co<-if(length(ccl)==1)cp[ccl]else '#8996A1';a<-vapply(n$children,function(z)theta(z$x),numeric(1));arc(a[1],a[2],r,co,.85);for(j in 1:2){ch<-n$children[[j]];radial(a[j],r,42-ch$h/max(hc$height)*34,co,.85)}}
  classcols<-c(Degrader='#229E98',Binder='#E57967',Control='#B5BEC6');targetcols<-c('Target A'='#3B6587','Target B'='#739DB5','Target C'='#B6CDDC',Other='#E5EBEF');rec<-c('Recruiter I'='#8970BB','Recruiter II'='#C0A7D8',None='#EAE4F1')
  for(i in 1:64){j<-ord[i];a<-theta(i-.46);b<-theta(i+.46);co<-c(classcols[m$class[j]],targetcols[m$target[j]],rec[m$recruiter[j]],cp[cl[j]]);for(k in 1:4)sector(a,b,43.5+(k-1)*2.75,45.65+(k-1)*2.75,co[k]);z<-xy(theta(i),56);ang<-theta(i)*180/pi;tx(f$compound[j],z[1],z[2],6.5,rot=if(cos(theta(i))<0)ang+180 else ang)}
  # Central aperture intentionally blank; branches remain unobscured.
  legend<-function(title,nms,cols,y){tx(title,132,y,8,just='left',face='bold');for(i in seq_along(nms)){rect(132,y-5-i*4.6,3,2.2,cols[i]);tx(nms[i],137,y-3.9-i*4.6,7,just='left')};y-10-length(nms)*4.6}
  y<-legend('Compound class',names(classcols),classcols,120);y<-legend('Target',names(targetcols),targetcols,y);y<-legend('Recruiter',names(rec),rec,y);tx('Clusters',132,y,8,just='left',face='bold');for(i in 1:8){col<-(i-1)%%4;row<-(i-1)%/%4;rect(132+col*11,y-7-row*6,3,2.4,cp[i]);tx(i,137+col*11,y-5.8-row*6,6.5)}
  geometry<-list(compounds=64,descriptors=24,rings=4,clusters=8,leaf_order=f$compound[ord],cluster_membership=as.list(setNames(cl,f$compound)),distance='Euclidean',linkage='Ward.D2')
 }else if(q$key=='proteomap'){
  d<-read('matrix');md<-read('metadata');mat<-xtabs(value~protein+compound,d);rh<-hclust(dist(mat),method='ward.D2');ch<-hclust(dist(t(mat)),method='ward.D2');ro<-rh$order;co<-ch$order;c<-2.35;x0<-23;y0<-26
  .heatdata<<-expand.grid(col=seq_len(48),row=seq_len(24));.heatdata$x<<-x0+(.heatdata$col-.5)*c;.heatdata$y<<-y0+(24-.heatdata$row+.5)*c;.heatdata$value<<-as.vector(t(mat[ro,co]))
  # Both trees use identical ordered leaf centres to the displayed matrix.
  for(n in tree_nodes(ch)){xx<-x0+(n$x-.5)*c;yy<-91+n$h/max(ch$height)*14;xs<-vapply(n$children,function(z)x0+(z$x-.5)*c,numeric(1));ln(xs,rep(yy,2),'#667D8B',.55);for(i in 1:2)ln(rep(xs[i],2),c(91+n$children[[i]]$h/max(ch$height)*14,yy),'#667D8B',.55)}
  for(n in tree_nodes(rh)){xx<-20-n$h/max(rh$height)*14;ys<-vapply(n$children,function(z)y0+(24-z$x+.5)*c,numeric(1));ln(rep(xx,2),ys,'#667D8B',.55);for(i in 1:2)ln(c(20-n$children[[i]]$h/max(rh$height)*14,xx),rep(ys[i],2),'#667D8B',.55)}
  scorecol<-circlize::colorRamp2(c(0,1),c('#F0EDF5','#7962AD'))
  for(j in 1:48){z<-md[match(colnames(mat)[co[j]],md$compound),];rect(x0+(j-1)*c,84,c,2,pal[z$class]);rect(x0+(j-1)*c,87,c,2,scorecol(z$score));if(j%%4==0||j==1)tx(z$compound,x0+(j-.5)*c,22.5,6.5,rot=90)}
  tx('Class',139,85,7,just='left');tx('Score',139,88,7,just='left');for(i in 1:24)tx(rownames(mat)[ro[i]],139,y0+(24-i+.5)*c,6.5,just='left')
  tx('Compound class',153,102,7,just='left',face='bold');for(i in 1:4){rect(153,96-(i-1)*5,3,2.3,pal[i]);tx(names(pal)[i],158,97.1-(i-1)*5,7,just='left')}
  tx('Score',153,74,7,just='left',face='bold');for(i in 1:60)rect(153+(i-1)*.35,68,.36,2,scorecol((i-1)/59));tx('0',153,64,6.5);tx('1',174,64,6.5)
  tx('log2 fold change',153,52,7,just='left',face='bold');cc<-circlize::colorRamp2(c(-3,0,3),c('#305D85','#FAFAF5','#D96B5D'));for(i in 1:60)rect(153+(i-1)*.35,46,.36,2,cc(-3+(i-1)/59*6));for(i in 1:3)tx(c('-3','0','3')[i],153+(i-1)*10.5,42,6.5)
  tx('Compounds',79,12,7);tx('Proteins',2.5,58,7,rot=90)
  geometry<-list(rows=24,columns=48,cell_mm=2.35,row_order=rownames(mat)[ro],column_order=colnames(mat)[co],distance='Euclidean',linkage='Ward.D2',scale='unscaled synthetic log2 fold change',clipped_values=sum(abs(mat)>3))
 }else if(q$key=='shapcompare'){
  d<-read('attribution');rank<-names(sort(tapply(abs(d$attribution),d$protein,mean),decreasing=TRUE));cc<-circlize::colorRamp2(c(-1,0,1),c('#268D99','#E7E6ED','#DA7770'));xx<-function(v,x0)x0+(v+.8)/1.6*59;ys<-118-(0:17)*5.25
  tx('Narrow search',57,128,8,face='bold');tx('Wide search',123,128,8,face='bold');tx('Mean |score|',169,128,7,face='bold');rect(157,122.5,2.3,1.2,'#A8BAC7');tx('Narrow',160,123.1,6.5,just='left');rect(171,122.5,2.3,1.2,'#697E8D');tx('Wide',174,123.1,6.5,just='left')
  for(i in 1:18){tx(rank[i],21,ys[i],7,just='right');for(x0 in c(27,93))ln(c(x0,x0+59),rep(ys[i],2),'#E8ECEF',.45);ln(c(159,179),rep(ys[i],2),'#E8ECEF',.45)}
  for(k in 1:2){model<-c('Narrow','Wide')[k];x0<-c(27,93)[k];ln(rep(xx(0,x0),2),c(25,121),'#94A1AC',.65);for(i in 1:18){z<-d[d$protein==rank[i]&d$model==model,];z<-z[order(abs(z$attribution),z$compound),];px<-xx(z$attribution,x0);py<-numeric(nrow(z));for(j in seq_len(nrow(z))){candidates<-c(0,as.vector(rbind(seq(.53,2,.53),-seq(.53,2,.53))));used<-if(j>1)which(abs(px[1:(j-1)]-px[j])<.56)else integer();ok<-vapply(candidates,function(y)!length(used)||all((px[used]-px[j])^2+(py[used]-y)^2>=.53^2),logical(1));py[j]<-if(any(ok))candidates[which(ok)[1]]else candidates[which.max(vapply(candidates,function(y)min((px[used]-px[j])^2+(py[used]-y)^2),numeric(1)))]};dots(px,ys[i]+py,cc(z$expression),.68);ma<-mean(abs(z$attribution));rect(159,ys[i]+if(k==1).1 else -1.1,ma/.45*20,.9,c('#A8BAC7','#697E8D')[k])};for(v in c(-.8,-.4,0,.4,.8))tx(v,xx(v,x0),22,6.5);tx('Attribution score',x0+29.5,16,7)}
  for(v in c(0,.2,.4))tx(v,159+v/.45*20,22,6.5)
  tx('Low',58,6.5,6.5,just='right');for(i in 1:80)rect(61+(i-1)*.38,5.5,.39,2,cc(-1+(i-1)/79*2));tx('High',94,6.5,6.5,just='left');tx('Expression',113,6.5,7,just='left');geometry<-list(features=18,compounds_per_model=85,models=2,points=nrow(d),feature_order=rank,packing='Deterministic greedy Euclidean point packing; x-values unchanged; at most +/-2mm vertical displacement',attribution='Simulated surrogate, not model output')
 }else if(q$key=='longitudinal'){
  hm<-read('heatmap');features<-unique(hm$protein);cell<-3.3;x0<-18;y0<-170
  .heatdata<<-data.frame(x=x0+(hm$column-.5)*cell,y=y0+(length(features)-match(hm$protein,features)+.5)*cell,value=hm$mean)
  tx('Binned abundance',18,229,8,just='left',face='bold')
  for(i in seq_along(features)){
   yy0<-y0+(length(features)-i+.5)*cell;k<-(i-1)%/%4+1
   rect(14,yy0-cell/2,2.2,cell-.12,pal[k])
   tx(if((i-1)%%4==0)LETTERS[k]else features[i],12,yy0,6.5,just='right',col=if((i-1)%%4==0)pal[k]else '#283642',face=if((i-1)%%4==0)'bold'else 'plain')
  }
  for(v in c(-10,-5,0,5,8))tx(v,x0+(v+10)*2*cell,166,6.5)
  tx('Years from reference event',103,229,7)
  tx('Mean log2 abundance',146,219,7,just='left',face='bold')
  ramp<-circlize::colorRamp2(c(-3,0,3),c('#305D85','#FAFAF5','#D96B5D'))
  for(i in 1:60)rect(146+(i-1)*.48,212,.49,2.3,ramp(-3+(i-1)/59*6))
  for(i in 1:3)tx(c('-3','0','3')[i],146+(i-1)*14.4,208,6.5)
  rect(146,200,3,2.3,'#E5EAED');tx('Fewer than 3 visits',151,201.1,6.5,just='left')
  tx('Matched trajectories',146,192,7,just='left',face='bold')
  for(k in 1:4){rect(146,185-(k-1)*4.5,3,2.1,pal[k]);tx(paste('Protein',LETTERS[k]),151,186-(k-1)*4.5,6.5,just='left')}
  # The reference boundary is rendered between adjacent half-year tiles.
  d<-read('observations');g<-read('predictions');st<-read('statistics');it<-read('intervals');xx<-function(v,x0)x0+(v+10)/18*67;yy<-function(v,y0)y0+(v+2.2)/5.8*48
  ln(c(19,25),c(159,159),'#83949F',.6);dots(22,159,'#83949F',.7);tx('Individual',27,159,7,just='left');ln(c(55,62),c(159,159),'#2D3B47',1.8);tx('GAMM fit',64,159,7,just='left');rect(94,158,7,2,'#DAE0E5');tx('95% CrI',103,159,7,just='left');ln(c(127,132),c(159,159),'#CC7363',2.5);tx('CrI > 0',134,159,7,just='left');ln(c(155,160),c(159,159),'#3D9497',2.5);tx('CrI < 0',162,159,7,just='left')
  for(k in 1:4){prot<-paste('Protein',LETTERS[k]);x0<-if(k%%2==1)18 else 105;y0<-if(k<=2)90 else 18;z<-d[d$protein==prot,];pred<-g[g$protein==prot,];stat<-st[st$protein==prot,];co<-pal[k]
   tx(prot,x0,y0+57,8,just='left',face='bold',col=co);tx(paste0('n = ',stat$n_subjects,' subjects / ',stat$n_observations,' visits'),x0+67,y0+57,6.5,just='right')
   qlab<-if(stat$q_time<.001)'q < 0.001'else sprintf('q = %.3f',stat$q_time);tx(paste0('Time effect: ',qlab),x0,y0+51.8,6.5,just='left');tx(sprintf('edf = %.2f',stat$edf),x0+67,y0+51.8,6.5,just='right')
   for(v in c(-2,0,2)){ln(c(x0,x0+67),rep(yy(v,y0),2),if(v==0)'#9DADB7'else '#ECF0F2',.6,if(v==0)2 else 1);tx(v,x0-2.8,yy(v,y0),6.5,just='right')}
   ln(rep(xx(0,x0),2),c(y0,y0+48),'#9DADB7',.75,2)
   for(id in unique(z$subject)){a<-z[z$subject==id,];a<-a[order(a$time),];ln(xx(a$time,x0),yy(a$value,y0),adjustcolor(co,.24),.55);dots(xx(a$time,x0),yy(a$value,y0),adjustcolor(co,.45),.65)}
   poly(c(xx(pred$time,x0),rev(xx(pred$time,x0))),c(yy(pred$lower,y0),rev(yy(pred$upper,y0))),adjustcolor(co,.22));ln(xx(pred$time,x0),yy(pred$mean,y0),co,2.4)
   rr<-it[it$protein==prot,];ln(c(x0,x0+67),rep(y0-3.2,2),'#E4E8EC',1.5);if(nrow(rr))for(j in 1:nrow(rr)){a<-rr[j,];ln(xx(c(a$start,a$end),x0),rep(y0-3.2,2),if(a$direction>0)'#CC7363'else '#3D9497',2.6)}
   for(v in c(-10,-5,0,5))tx(v,xx(v,x0),y0-7.4,6.5);if(k>2)tx('Years from reference event',x0+33.5,4,7)
  }
  tx('Relative abundance (log2)',5,114,7,rot=90);tx('Relative abundance (log2)',92,114,7,rot=90);tx('Relative abundance (log2)',5,42,7,rot=90);tx('Relative abundance (log2)',92,42,7,rot=90)
  geometry<-list(proteins=4,subjects=60,visits_per_protein=nrow(d)/4,total_points=nrow(d),fitted_grid=300,prediction_band='95% pointwise Bayesian credible interval, not simultaneous',time_tests='Approximate GAMM smooth tests, BH adjusted over 4 protein fixtures',model='Gaussian REML GAMM with subject random intercept',local_markers='Exact contiguous grid intervals whose pointwise CrI excludes zero; no altered endpoints')
 }else if(q$key=='doseprofiles'){
  d<-read('summary');paths<-unique(d$pathway);xx<-function(v,x0)x0+(log10(v)-log10(.03))/(log10(10)-log10(.03))*59;yy<-function(v,y0)y0+(v+2.4)/6.8*42
  for(i in 1:4){x<-32+(i-1)*37;ln(c(x,x+7),c(132,132),pal[i],1.7);dots(x+3.5,132,pal[i],1.1,c(16,17,15,18)[i]);tx(paste('Series',names(pal)[i]),x+9,132,7,just='left')}
  for(k in 1:4){x0<-if(k%%2==1)18 else 108;y0<-if(k<=2)78 else 19;title<-paths[k];tx(title,x0,y0+47,8,just='left',face='bold')
   for(v in c(-2,0,2,4)){ln(c(x0,x0+59),rep(yy(v,y0),2),if(v==0)'#AFBBC4'else '#E8EDF1',if(v==0).7 else .5,if(v==0)2 else 1);tx(v,x0-3,yy(v,y0),6.5,just='right')}
   ends<-sapply(names(pal),function(g)tail(d$mean[d$pathway==title&d$series==g],1));labely<-yy(ends,y0);oo<-order(labely);for(i in 2:4)labely[oo[i]]<-max(labely[oo[i]],labely[oo[i-1]]+3.2)
   for(i in 1:4){z<-d[d$pathway==title&d$series==names(pal)[i],];x<-xx(z$dose_uM,x0);y<-yy(z$mean,y0);poly(c(x,rev(x)),c(yy(z$mean-z$sem,y0),rev(yy(z$mean+z$sem,y0))),adjustcolor(pal[i],.18));ln(x,y,pal[i],1.35);dots(x,y,pal[i],1.15,c(16,17,15,18)[i]);ln(c(tail(x,1)+1,x0+63),c(tail(y,1),labely[i]),pal[i],.5);tx(names(pal)[i],x0+64,labely[i],7,just='left',col=pal[i])}
   for(v in c(.03,.1,.3,1,3,10))tx(v,xx(v,x0),y0-3.5,6.5);if(k>2)tx('Concentration (uM)',x0+30,y0-10,7)
  }
  tx('Mean log2 fold change',5,97,7,rot=90);tx('Mean log2 fold change',5,38,7,rot=90);geometry<-list(facets=4,series=4,doses=6,proteins_per_pathway=36,summary_rows=nrow(d),uncertainty='Mean +/- SEM over 36 synthetic proteins, not biological replicates',dose_axis='log10',segments='Straight connectors between six observed fixture levels, no curve fitting')
 }
 grid.force(redraw=FALSE);upViewport();if(!is.null(metrics_path))jsonlite::write_json(list(rendered_text=unique(labels),geometry=geometry,size=list(width_mm=183,height_mm=H)),metrics_path,auto_unbox=TRUE,pretty=TRUE,digits=NA);invisible(labels)
}
