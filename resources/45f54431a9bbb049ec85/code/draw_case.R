library(grid)
pal<-c(A='#42948D',B='#8B74B7',C='#D59054',D='#4B7793')
.heat_layers<-list()
compose_plot<-function(g,q){
 p<-ggplot2::ggplot()+ggplot2::annotation_custom(g,xmin=0,xmax=183,ymin=q$ymin,ymax=q$ymin+q$height)
 for(h in .heat_layers)p<-p+ggplot2::geom_tile(data=h$d,ggplot2::aes(x=x,y=y,fill=ink),width=h$cell,height=h$cell,colour='white',linewidth=.045)
 p+ggplot2::scale_fill_identity()+ggplot2::coord_fixed(xlim=c(0,183),ylim=c(q$ymin,q$ymin+q$height),expand=FALSE)+ggplot2::theme_void()+ggplot2::theme(plot.margin=ggplot2::margin(0,0,0,0))
}
draw_case<-function(q,P,metrics_path=NULL){
 labels<-character(); geometry<-list()
 .heat_layers<<-list()
 grid.newpage()
 pushViewport(viewport(xscale=c(0,183),yscale=c(q$ymin,q$ymin+q$height)))
 U<-function(x)unit(x,'native')
 txt<-function(s,x,y,size=7,just='left',rot=0,bold=FALSE,col='#273543'){
   labels<<-c(labels,as.character(s))
   grid.text(s,U(x),U(y),just=just,rot=rot,gp=gpar(fontfamily='Arial',fontsize=size,fontface=if(bold)'bold' else 'plain',col=col))
 }
 ln<-function(x,y,col='#CDD5DC',lw=.58,lty=1)grid.lines(U(x),U(y),gp=gpar(col=col,lwd=lw,lty=lty,lineend='round'))
 box<-function(x,y,w,h,fill,col=NA,lwd=.6)if(w>0&&h>0)grid.rect(U(x),U(y),U(w),U(h),just=c('left','bottom'),gp=gpar(fill=fill,col=col,lwd=lwd))
 point<-function(x,y,r,col)grid.circle(U(x),U(y),unit(r,'mm'),gp=gpar(fill=col,col=NA))
 polygon_at<-function(x,y,col)grid.polygon(U(x),U(y),gp=gpar(fill=col,col=NA))
 read<-function(s)read.csv(file.path(P,'results/plot_data',paste0(q$stem,'_',s,'.csv')),check.names=FALSE)
 diverge<-function(m)circlize::colorRamp2(c(-m,0,m),c('#35678A','#F7F6F1','#D47360'))
 gradient<-function(label,x,y,w,range,palette){
   txt(label,x,y+5,7,bold=TRUE)
   v<-seq(range[1],tail(range,1),length.out=62)
   for(i in seq_len(62))box(x+(i-1)*w/62,y,w/62+.01,1.7,palette(v[i]))
   for(i in seq_along(range))txt(range[i],x+(i-1)*w/(length(range)-1),y-2.5,6.5,'centre')
 }
 add_matrix<-function(mat,x0,y0,cell,colour){
   d<-expand.grid(r=seq_len(nrow(mat)),c=seq_len(ncol(mat)))
   d$x<-x0+(d$c-.5)*cell
   d$y<-y0+(nrow(mat)-d$r+.5)*cell
   d$ink<-colour(as.vector(mat))
   .heat_layers[[length(.heat_layers)+1]]<<-list(d=d,cell=cell)
 }
 write_table<-function(d,name)if(!is.null(metrics_path))
   write.csv(d,file.path(P,'results/plot_data',paste0(q$stem,'_',name,'.csv')),row.names=FALSE)
 if(q$key=='onco'){
   sm<-read('samples');e<-read('events');a<-read('abundance')
   events<-c('SNV','Gain','Loss','Fusion');ep<-c(SNV='#217D79',Gain='#DB8963',Loss='#7B6AA6',Fusion='#33526A')
   sites<-c(Marrow='#607684',Blood='#E0BFA0')
   count<-table(factor(e$sample,levels=sm$sample),factor(e$event,levels=events))
   ord<-order(sm$subtype,-rowSums(count),sm$sample)
   sm<-sm[ord,];count<-count[sm$sample,,drop=FALSE]
   genes<-sprintf('G%02d',1:24)
   sample_names<-sm$sample
   lookup<-split(e$event,paste(e$sample,e$gene,sep=':'))
   n<-120;c<-1.2;x0<-18;right<-x0+n*c
   xx<-function(j)x0+(j-.5)*c
   yy<-function(i)75.8+(24-i+.5)*c
   glyph<-function(x,y,k,ev){
     box(x-k/2+.025,y-k/2+.025,k-.05,k-.05,'#EDF1F3')
     both<-all(c('SNV','Fusion') %in% ev)
     if('Gain'%in%ev)box(x-k*.34,y+k*.24,k*.68,k*.15,ep['Gain'])
     if('Loss'%in%ev)box(x-k*.34,y-k*.39,k*.68,k*.15,ep['Loss'])
     if('SNV'%in%ev)point(x-if(both)k*.20 else 0,y,k*.135,ep['SNV'])
     if('Fusion'%in%ev){
       dx<-x+if(both)k*.20 else 0
       polygon_at(dx+k*c(-.18,0,.18,0),y+k*c(0,.18,0,-.18),ep['Fusion'])
     }
   }
   ymax<-ceiling(max(rowSums(count))/5)*5
   sy<-11/ymax
   for(j in seq_len(n)){
     x<-xx(j);z<-sm[j,]
     box(x-c/2,109,c,2.15,pal[z$subtype])
     box(x-c/2,106.2,c,2.15,sites[z$source])
     ends<-113+c(0,cumsum(count[j,]))*sy
     for(k in 1:4)box(x-.46,ends[k],.92,diff(ends)[k],ep[k],'#30343B',.35/25.4*96)
     for(i in 1:24)glyph(x,yy(i),c,lookup[[paste(z$sample,genes[i],sep=':')]])
   }
   ln(c(x0,right),rep(113,2))
   for(v in seq(0,ymax,by=5))txt(v,x0-2,113+v*sy,6.5,'right')
   txt('Events',5,118.5,6.5,'centre',90)
   txt('Subtype',x0-2,110.1,6.5,'right');txt('Source',x0-2,107.3,6.5,'right')
   txt('n',176,106.1,6.5,'centre')
   totals<-vapply(genes,function(g)length(unique(e$sample[e$gene==g])),integer(1))
   for(i in 1:24){
     y<-yy(i)
     box(164,y-.24,totals[i]/max(totals)*9,.48,'#628299','#30343B',.35/25.4*96)
     if(i %in% c(1,4,7,10,13,16,19,22,24)){
       txt(genes[i],x0-1.4,y,6.5,'right');txt(totals[i],176,y,6.5,'centre')
     }
   }
   fs<-c(paste('RNA',1:8),paste('Prot',1:8))
   mat<-matrix(NA_real_,16,n,dimnames=list(fs,sample_names))
   mat[cbind(match(a$feature,fs),match(a$sample,sample_names))]<-a$value
   add_matrix(mat,x0,55,c,diverge(3))
   txt('RNA',x0-1.4,69.4,6.5,'right');txt('Protein',x0-1.4,59.8,6.5,'right')
   for(j in c(40,80)){
     x<-x0+j*c
     ln(rep(x,2),c(75.8,104.6),'#A4B0BB',.7)
     ln(rep(x,2),c(44,53.7),'#D0DBE0',.6)
   }
   for(v in c(0,.5,1)){
      ln(c(x0,right),rep(44+v*9.7,2),'#E1E7EA')
      txt(v,x0-2,44+v*9.7,6.5,'right')
   }
   txt('Score',5,48.8,6.5,'centre',90)
   for(j in seq_len(n)){
      ln(rep(xx(j),2),c(44,44+9.7*sm$score[j]),'#B9CCD2',.5)
      point(xx(j),44+9.7*sm$score[j],.32,pal[sm$subtype[j]])
   }
   for(j in seq(4,116,by=14))txt(sm$sample[j],xx(j),41.6,6.5,'centre')
   # Zoom explicitly links the source range to an enlarged subset in identical order.
   js<-43:58;is<-9:14;zcell<-2.45;zx<-57;zy<-21.2
   lo<-xx(min(js))-.6;hi<-xx(max(js))+.6;top<-zy+length(is)*zcell
   ln(c(lo,lo,hi,hi),c(40,38.8,38.8,40),'#668093',.85)
   ln(c(lo,zx),c(38.8,top+.4),'#A6B5BE',.6)
   ln(c(hi,zx+16*zcell),c(38.8,top+.4),'#A6B5BE',.6)
   for(i in seq_along(is)){
     gy<-zy+(length(is)-i+.5)*zcell
     txt(genes[is[i]],zx-1.6,gy,6.5,'right')
     for(j in seq_along(js))glyph(zx+(j-.5)*zcell,gy,zcell,lookup[[paste(sample_names[js[j]],genes[is[i]],sep=':')]])
   }
   for(j in c(1,5,9,13,16))txt(sample_names[js[j]],zx+(j-.5)*zcell,18.5,6.5,'centre')
   txt('Subtype',18,34.9,6.5)
   for(i in 1:3){box(18,30.8-3.0*(i-1),2,1.8,pal[i]);txt(names(pal)[i],21.8,31.7-3.0*(i-1),6.5)}
   txt('Source',31,34.9,6.5)
   for(i in 1:2){box(31,30.8-3.0*(i-1),2,1.8,sites[i]);txt(names(sites)[i],34.8,31.7-3.0*(i-1),6.5)}
   for(i in 1:4){
     v<-34.3-3.1*(i-1)
     glyph(102,v,2.25,events[i])
     txt(events[i],104.5,v,6.5)
   }
   gradient('Feature Z score',123,27.8,30,c(-3,0,3),diverge(3))
   write_table(data.frame(sm,events=rowSums(count)), 'sample_order')
   write_table(data.frame(gene=genes,affected=totals),'gene_summary')
   write_table(data.frame(position=js,sample=sample_names[js]),'zoom_samples')
   geometry<-list(samples=n,genes=24,features=16,cell_mm=c,track_gaps_mm=c(events_to_subtype=1.85,subtype_to_source=.65,source_to_events_matrix=1.6,events_matrix_to_expression=1.6,expression_to_score=1.3),shared_sample_order=sample_names,zoom_samples=sample_names[js],zoom_genes=genes[is])
 }else{
   m<-read('membership');s<-read('scores');factors<-paste0('F',1:14)
   paths<-c('Sug','TCA','Lip','AA','Pur','Pyr','Red','Cof','FA','BA','Cer','PE','PC','Org')
   ps<-paste0('P',1:14)
   tbl<-table(factor(m$factor,levels=factors),factor(m$class,levels=c(paths,'Unassigned')))
   ratio<-unclass(tbl)[,1:14]/rowSums(tbl)
   cors<-cor(s[factors],s[ps])
   means<-rbind(colMeans(s[s$cohort=='Reference',factors]),colMeans(s[s$cohort=='Challenge',factors]))
   c<-3.45;y0<-17;y<-function(i)y0+(14-i+.5)*c
   cr<-circlize::colorRamp2(c(0,.45),c('#F4F7F6','#228075'));cc<-diverge(1)
   add_matrix(ratio,41.6,y0,c,cr);add_matrix(cors,92.1,y0,c,cc)
   co<-c('#7760AA','#D68154')
   for(i in 1:14){
     yy<-y(i);n<-sum(tbl[i,1:14]);u<-tbl[i,15]
     if(i%%2==0)box(11,yy-c/2,166.8,c,'#F3F6F7')
     txt(factors[i],10,yy,6.5,'right')
     box(12,yy-.7,n*.172,1.4,'#509C8A','#30343B',.35/25.4*96)
     box(12+n*.172,yy-.7,u*.172,1.4,'#DAE4E8','#30343B',.35/25.4*96)
     txt(n+u,13+(n+u)*.172,yy,6.5)
     xx<-160+means[,i]*12
     ln(c(142.6,177.8),rep(yy,2),'#ECF0F2')
     marker_y<-if(abs(diff(xx))<1.05) yy+c(.52,-.52) else rep(yy,2)
     ln(xx,marker_y,'#85939F',.8)
     point(xx[1],marker_y[1],.49,co[1]);point(xx[2],marker_y[2],.49,co[2])
   }
   ln(rep(160,2),c(y0,y0+14*c),'#AEBBC4',.58,2)
   totals<-colSums(tbl[,1:14]);iqr<-vapply(s[ps],IQR,numeric(1))
   top_bar<-function(v,x0,col,axis,cap){
     for(j in 1:14)box(x0+(j-.5)*c-.73,71.3,1.46,v[j]/cap*8.6,col,'#30343B',.35/25.4*96)
     ln(c(x0,x0+14*c),rep(71.3,2))
     txt(axis,x0-2.1,75.6,6.5,'centre',90)
     xr<-x0+14*c
     ln(rep(xr,2),c(71.3,79.9),'#C9D4DB')
     ln(c(xr,xr+.6),rep(79.9,2),'#A6B4BD')
     txt(cap,xr+.6,79.9,6.5)
   }
   top_bar(totals,41.6,'#509C8A','Count',ceiling(max(totals)/10)*10)
   top_bar(iqr,92.1,'#7898AD','IQR',2)
   for(j in 1:14){
     jy<-if(j%%2==1)67.4 else 69.7
     txt(paths[j],41.6+(j-.5)*c,jy,6.5,'centre')
     txt(ps[j],92.1+(j-.5)*c,jy,6.5,'centre')
   }
   for(v in c(0,60,120))txt(v,12+.182*v,13.9,6.5,'centre')
   for(v in c(-1,0,1))txt(v,160+v*12,13.9,6.5,'centre')
   box(12,8,1.9,1.6,'#509C8A');txt('Assigned',15.3,8.8,6.5)
   box(12,4.5,1.9,1.6,'#DAE4E8');txt('Unassigned',15.3,5.3,6.5)
   gradient('Class fraction',41.6,5.6,42.8,c(0,.225,.45),cr)
   gradient('Pearson r',92.1,5.6,42.8,c(-1,0,1),cc)
   for(i in 1:2){point(144.5,8.8-3.5*(i-1),.54,co[i]);txt(c('Reference','Challenge')[i],146.7,8.8-3.5*(i-1),6.5)}
   write_table(data.frame(factor=factors,assigned=rowSums(tbl[,1:14]),unassigned=tbl[,15],reference=means[1,],challenge=means[2,]),'factor_summary')
   write_table(data.frame(factor=factors,ratio,check.names=FALSE),'class_fraction')
   write_table(data.frame(factor=factors,cors),'correlations')
   write_table(data.frame(class=paths,total=totals,protein=names(iqr),iqr=as.numeric(iqr)),'column_summary')
   geometry<-list(factors=14,classes=14,protein_scores=14,cell_mm=c,matched_samples=nrow(s),matrix_gap_mm=2.2,right_gutter_mm=2.2,shared_factor_order=factors)
 }
 popViewport()
 if(!is.null(metrics_path))jsonlite::write_json(list(rendered_text=unique(labels),geometry=geometry),metrics_path,auto_unbox=TRUE,pretty=TRUE)
}
