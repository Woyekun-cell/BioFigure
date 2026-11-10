library(grid)
pal <- c(A='#4A9B90', B='#577DB4', C='#C97B91', D='#9B984F')
compose_plot <- function(g,q) cowplot::ggdraw(g)
draw_case <- function(q,P,layout){
  root <- file.path(P,'results/plot_data',q$stem)
  features <- read.csv(paste0(root,'_features.csv'))
  values <- read.csv(paste0(root,'_abundance.csv'))
  tree <- hclust(dist(features[,3:8]),method='ward.D2')
  order_ids <- features$protein[tree$order]
  angle <- setNames(seq(35,325,length.out=28)*pi/180,order_ids)
  cx <- 73; cy <- 77
  labels <- character()
  pushViewport(viewport(xscale=c(0,183),yscale=c(0,156)))
  U <- function(v) unit(v,'native')
  XY <- function(r,a) list(x=cx+r*cos(a),y=cy+r*sin(a))
  text_at <- function(s,x,y,just='left',size=7,bold=FALSE,rot=0,col='#263544'){
    labels <<- c(labels,as.character(s))
    grid.text(s,U(x),U(y),just=just,rot=rot,gp=gpar(fontfamily='Arial',fontsize=size,fontface=if(bold)'bold' else 'plain',col=col))
  }
  line_at <- function(x,y,col='#B2BAC1',w=.55,lty=1){
    grid.lines(U(x),U(y),gp=gpar(col=col,lwd=w,lty=lty,lineend='round'))
  }
  path <- function(r,a,col='#B2BAC1',w=.55,lty=1){
    z <- XY(r,a);line_at(z$x,z$y,col,w,lty)
  }
  patch <- function(r,a,col,border=NA,w=.5){
    z <- XY(r,a)
    grid.polygon(U(z$x),U(z$y),gp=gpar(fill=col,col=border,lwd=w,linejoin='round'))
  }
  sector <- function(inner,outer,center,half,fill,border=NA,w=.5){
    if(outer-inner<1e-6)return()
    a <- seq(center-half,center+half,length.out=15)
    patch(rep(c(outer,inner),each=length(a)),c(a,rev(a)),fill,border,w)
  }
  swatch <- function(x,y,color){
    grid.rect(U(x),U(y),U(2.7),U(2.7),gp=gpar(fill=color,col=NA))
  }
  arc <- seq(min(angle)-.085,max(angle)+.085,length.out=350)
  # Four concentric guides delimit the violin ring, including its zero baseline.
  for(r in c(43,47.5,52,56.5,61))path(r,arc,if(r==52)'#AEB8C0' else '#E3E9ED',if(r==52).75 else .45,if(r==52)2 else 1)
  # The merge tree is traversed with the actual leaf order and original merge heights.
  node_angle <- numeric(27); node_radius <- 32-25*tree$height/max(tree$height)
  for(i in seq_len(27)){
    children <- tree$merge[i,]
    a <- vapply(children,function(j) if(j<0)angle[[features$protein[-j]]] else node_angle[j],numeric(1))
    rr <- vapply(children,function(j) if(j<0)32 else node_radius[j],numeric(1))
    for(j in 1:2)path(c(node_radius[i],rr[j]),a[j],'#6D7B86',.82)
    path(node_radius[i],seq(a[1],a[2],length.out=70),'#6D7B86',.82)
    node_angle[i] <- mean(a)
  }
  density_by <- lapply(split(values,interaction(values$protein,values$cohort,drop=TRUE)),function(x)
    density(x$value,from=-3,to=3,n=128,bw=.28))
  max_density <- max(vapply(density_by,function(x)max(x$y),numeric(1)))
  cohorts <- c(Reference='#7156B0',Challenge='#E28561')
  bins <- c(Low='#4D75A1',Mid='#E8EDF1',High='#E88B70')
  tab <- data.frame()
  for(id in order_ids){
    a <- angle[[id]]
    m <- features$module[match(id,features$protein)]
    x <- values[values$protein==id,]
    path(c(32,43),a,'#E3E9ED',.5)
    sector(33,35,a,.078,pal[m])
    f <- c(mean(x$value < -0.5),mean(abs(x$value)<=.5),mean(x$value>.5))
    edges <- 36+c(0,cumsum(f)*5.5)
    for(j in 1:3)sector(edges[j],edges[j+1],a,.061,bins[j],'#30343B',.35/25.4*96)
    path(c(43,61),a,'#D8E0E7',.5)
    for(j in 1:2){
      d <- density_by[[paste(id,names(cohorts)[j],sep='.')]]
      r <- 52+3*d$x
      displacement <- (-1)^j*.078*d$y/max_density
      patch(c(r,rev(r)),c(a+displacement,rep(a,length(r))),adjustcolor(cohorts[j],.76))
      keep <- d$y > max_density*.008
      path(r[keep],a+displacement[keep],cohorts[j],.55)
      mid <- median(x$value[x$cohort==names(cohorts)[j]])
      path(52+3*mid,c(a,a+(-1)^j*.035),'#263544',.85)
    }
    fraction <- mean(abs(x$value)>1)
    p <- XY(63.9,a)
    if(fraction>0)grid.circle(U(p$x),U(p$y),unit(1.55*sqrt(fraction),'mm'),gp=gpar(fill='#334C5F',col=NA))
    p <- XY(68.8,a)
    deg <- a*180/pi
    text_at(id,p$x,p$y,'center',7,TRUE,if(cos(a)<0)deg+180 else deg)
    tab <- rbind(tab,data.frame(protein=id,module=m,angle=as.numeric(a),low=f[1],mid=f[2],high=f[3],abs_over_one=fraction))
  }
  # Radial guide scales occupy the open sector. Neither overlaps data.
  for(v in c(-3,0,3)){
    x <- cx+52+3*v;line_at(c(x,x),c(cy-1,cy+1),'#677988',.65)
    text_at(v,x,cy-3.1,'center',6.5)
  }
  line_at(cx+c(43,61),rep(cy,2),'#677988',.65)
  text_at('log2 abundance',cx+52,cy-7,'center',7)
  text_at('Profile clustering',95,82,'center',7,TRUE)
  text_at('28 proteins',95,77,'center',7)
  x <- 151
  text_at('Module',x,136,bold=TRUE)
  for(i in 1:4){swatch(x+1.35,132-4*(i-1),pal[i]);text_at(names(pal)[i],x+4,132-4*(i-1))}
  text_at('Sample fraction',x,111,bold=TRUE)
  for(i in 1:3){swatch(x+1.35,106-4*(i-1),bins[i]);text_at(c('< -0.5','-0.5 to 0.5','> 0.5')[i],x+4,106-4*(i-1))}
  text_at('Abundance density',x,87,bold=TRUE)
  for(i in 1:2){swatch(x+1.35,82-4*(i-1),cohorts[i]);text_at(names(cohorts)[i],x+4,82-4*(i-1))}
  line_at(c(x,x+2.7),c(72,72),'#263544',.85)
  text_at('Median tick',x+4,72)
  text_at('|log2 abundance| > 1',x,60,bold=TRUE)
  for(i in 1:3){
    f <- c(.25,.5,1)[i]
    grid.circle(U(x+1.45),U(55-4*i),unit(1.55*sqrt(f),'mm'),gp=gpar(fill='#334C5F',col=NA))
    text_at(paste0(100*f,'%'),x+4,55-4*i)
  }
  popViewport()
  if(!is.null(layout)){
    write.csv(tab,paste0(root,'_tracks.csv'),row.names=FALSE)
    jsonlite::write_json(list(rendered_text=unique(labels),geometry=list(tips=28,angular_spacing=diff(unname(angle))[1],tracks=c('module','composition','split violin','threshold dot'),violin_scale=c(-3,3),bw=.28,shared_peak_density=max_density,leaf_order=order_ids)),layout,auto_unbox=TRUE,pretty=TRUE)
  }
}
