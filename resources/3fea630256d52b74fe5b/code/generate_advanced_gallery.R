# Standalone R reproduction of three SciDraw visual structures with simulated data.
# Run: Rscript reproduce.R [output_directory]
# Required packages: ape, ggplot2, grid, ragg, svglite, systemfonts, jsonlite.
suppressPackageStartupMessages({library(grid);library(ggplot2)})
args<-commandArgs(trailingOnly=TRUE)
out<-if(length(args))args[1] else 'output'
dir.create(out,recursive=TRUE,showWarnings=FALSE)
set.seed(20260909)
font<-'Arial'
f<-systemfonts::match_fonts(font)
stopifnot(systemfonts::font_info(path=f$path,index=f$index)$family[1]==font)
COL<-c('#237D79','#BE903D','#7D719B','#B96758')
# Text geometry is measured on the actual export device; coordinates below are mm.
text_log<-list(); current_plot<-''
text_at<-function(label,x,y,size=7,just='centre',rot=0,col='black',face='plain') {
 gp<-gpar(fontfamily=font,fontsize=size,col=col,fontface=face)
 g<-textGrob(label,x=unit(x,'mm'),y=unit(y,'mm'),gp=gp,just=just,rot=rot)
 grid.draw(g)
 w<-convertWidth(grobWidth(textGrob(label,gp=gp)),'mm',valueOnly=TRUE)
 h<-convertHeight(grobHeight(textGrob(label,gp=gp)),'mm',valueOnly=TRUE)
 text_log[[length(text_log)+1]]<<-data.frame(figure=current_plot,label=label,x=x,y=y,w=w,h=h,rot=rot)
}
line_mm<-function(x,y,col='#333333',lwd=.6,lty=1)grid.lines(unit(x,'mm'),unit(y,'mm'),gp=gpar(col=col,lwd=lwd,lty=lty))
poly_mm<-function(x,y,fill,col=NA,lwd=.5,lty=1)grid.polygon(unit(x,'mm'),unit(y,'mm'),gp=gpar(fill=fill,col=col,lwd=lwd,lty=lty))
export<-function(name,w,h,draw) {
 current_plot<<-name
 for(ext in c('png','svg')) {
  path<-file.path(out,paste0(name,'.',ext))
  if(ext=='png')ragg::agg_png(path,width=w,height=h,units='mm',res=300,background='white')
  else svglite::svglite(path,width=w/25.4,height=h/25.4,bg='white')
  tryCatch(withCallingHandlers({grid.newpage();draw()},warning=function(w)stop(conditionMessage(w),call.=FALSE)),finally=dev.off())
 }
}
# 1. Circular phylogram: all tip identifiers aligned across every annotation track.
phyla<-c('Actinobacteriota','Bacteroidota','Firmicutes','Proteobacteria')
subtrees<-lapply(1:4,function(k)ape::rtree(40,tip.label=sprintf('ASV_%d_%03d',k,1:40)))
tree<-ape::read.tree(text=paste0('(',paste(vapply(subtrees,function(t)paste0(sub(';','',ape::write.tree(t)),':0.3'),''),collapse=','),');'))
tree<-ape::reorder.phylo(ape::ladderize(tree),'cladewise')
N<-length(tree$tip.label); E<-tree$edge; tips<-E[E[,2]<=N,2]
stopifnot(length(unique(tips))==N)
depth<-ape::node.depth.edgelength(tree); ang<-rep(NA,length(depth));ang[tips]<-seq(14,346,length.out=N)*pi/180
children<-split(E[,2],E[,1]);angle_node<-function(node) {
 if(!is.na(ang[node]))return(ang[node])
 vals<-vapply(children[[as.character(node)]],angle_node,0)
 ang[node]<<-mean(range(vals));ang[node]
}
root<-setdiff(E[,1],E[,2])[1];angle_node(root)
scale_mm<-29/max(depth);radius<-3+depth*scale_mm
meta<-data.frame(ID=tree$tip.label,Phylum=phyla[as.integer(sub('ASV_([1-4])_.*','\\1',tree$tip.label))])
track_names<-c('Freshwater','Coastal','Marine','Soil')
presence<-matrix(rbinom(N*4,1,.62),N,4,dimnames=list(tree$tip.label,track_names))
score<-rbeta(N,1.5,5)
stopifnot(identical(meta$ID,rownames(presence)),all(score>=0 & score<=1))
ape::write.tree(tree,file=file.path(out,'simulated_tree.nwk'))
write.csv(cbind(meta,presence,Score=score),file.path(out,'tree_annotations.csv'),row.names=FALSE)
export('phylogeny',160,122,function(){
 cx<-59;cy<-61;xy<-function(r,a)cbind(cx+r*cos(a),cy+r*sin(a))
 for(i in seq_len(nrow(E))) {
  parent<-E[i,1];child<-E[i,2]
  a<-seq(ang[parent],ang[child],length.out=max(3,ceiling(abs(ang[parent]-ang[child])*60)))
  v<-xy(radius[parent],a);line_mm(v[,1],v[,2],lwd=.35)
  v<-xy(c(radius[parent],radius[child]),ang[child]);line_mm(v[,1],v[,2],lwd=.35)
 }
 sector<-function(r0,r1,a,width,fill,border=NA){
  aa<-seq(a-width/2,a+width/2,length.out=5)
  z<-rbind(xy(r0,aa),xy(r1,rev(aa)));poly_mm(z[,1],z[,2],fill,border,lwd=.15)
 }
 pitch<-(346-14)/(N-1)*pi/180
 for(i in tips){
  c<-COL[match(meta$Phylum[i],phyla)]
  v<-xy(c(radius[i],34),ang[i]);line_mm(v[,1],v[,2],col='#DDDDDD',lwd=.25,lty=3)
  for(j in 1:4)sector(34+(j-1)*2.1,36+(j-1)*2.1,ang[i],pitch*.94,if(presence[i,j])c else grDevices::adjustcolor(c,alpha.f=.12))
 }
 for(level in c(0,.5,1)){
  a<-seq(14,346,length.out=500)*pi/180;v<-xy(44+level*10,a);line_mm(v[,1],v[,2],col='#D8D8D8',lwd=.35)
  text_at(format(level,trim=TRUE),cx+44+level*10,cy-2.8,size=6)
 }
 for(i in tips)sector(44,44+10*score[i],ang[i],pitch*.74,COL[match(meta$Phylum[i],phyla)])
 for(j in 1:4)text_at(j,cx+35+(j-1)*2.1,cy+2,size=5.5)
 text_at('Phylum',122,103,just='left')
 for(k in 1:4){grid.rect(unit(123.5,'mm'),unit(98-k*5,'mm'),width=unit(3,'mm'),height=unit(3,'mm'),gp=gpar(fill=COL[k],col=NA));text_at(phyla[k],127,98-k*5,just='left')}
 text_at('Tracks (inner to outer)',122,67,just='left')
 for(j in 1:4)text_at(paste(j,track_names[j]),122,67-j*4.5,just='left')
 text_at('Presence',122,40,just='left')
 for(k in 1:2){grid.rect(unit(123.5,'mm'),unit(35-(k-1)*5,'mm'),width=unit(3,'mm'),height=unit(3,'mm'),gp=gpar(fill=c('#555555','#EEEEEE')[k],col=NA));text_at(c('Present','Absent')[k],127,35-(k-1)*5,just='left')}
 text_at('Outer bars: score (0–1)',122,21,just='left',size=6.5)
 line_mm(c(122,122+scale_mm),c(11,11),lwd=.7)
 text_at('1 tree-distance unit',122,7,just='left',size=6)
})
# 2. Raincloud: separate half-density, box and raw points; pre-specified adjacent comparisons.
groups<-c('Control','Early stress','Late stress','Recovery')
d<-data.frame(Group=factor(rep(groups,each=60),levels=groups),Value=rlnorm(240,log(rep(c(1,1.45,2.05,1.15),each=60)),.25))
comparisons<-lapply(1:3,function(i)t.test(log(d$Value[d$Group==groups[i+1]]),log(d$Value[d$Group==groups[i]])))
st<-data.frame(comparison=paste(groups[2:4],'vs',groups[1:3]),p=vapply(comparisons,function(t)t$p.value,0),
 ratio=vapply(comparisons,function(t)exp(t$estimate[1]-t$estimate[2]),0),
 lower=vapply(comparisons,function(t)exp(t$conf.int[1]),0),upper=vapply(comparisons,function(t)exp(t$conf.int[2]),0))
st$p_adj<-p.adjust(st$p,'holm')
write.csv(st,file.path(out,'raincloud_statistics.csv'),row.names=FALSE);write.csv(d,file.path(out,'raincloud_data.csv'),row.names=FALSE)
welch<-oneway.test(log(Value)~Group,data=d,var.equal=FALSE)
writeLines(capture.output(welch),file.path(out,'raincloud_overall.txt'))
clouds<-do.call(rbind,lapply(1:4,function(i){
 values<-d$Value[d$Group==groups[i]];den<-density(values,from=min(values),to=max(values),n=256)
 data.frame(x=c(i+.12,i+.12+den$y/max(den$y)*.30,i+.12),y=c(den$x[1],den$x,tail(den$x,1)),Group=factor(groups[i],levels=groups))}))
d$x<-as.numeric(d$Group)-.13+runif(nrow(d),-.10,.10)
upper<-max(d$Value)+.45
labels<-paste0('adj. P = ',formatC(st$p_adj,digits=2,format='g'))
p<-ggplot()+geom_polygon(data=clouds,aes(x,y,group=Group,fill=Group),colour='#333333',linewidth=.30,alpha=.75)+
 geom_boxplot(data=d,aes(as.numeric(Group)+.12,Value,group=Group),width=.11,fill='white',colour='#333333',linewidth=.30,outlier.shape=NA)+
 geom_point(data=d,aes(x,Value,fill=Group),shape=21,size=1.2,stroke=.12,colour='#333333',alpha=.85)+
 geom_segment(data=data.frame(x=1:3+.12,xend=2:4-.13),aes(x=x,xend=xend,y=upper,yend=upper),linewidth=.25)+
 geom_text(data=data.frame(x=1:3+.495,y=upper+.16,label=labels),aes(x,y,label=label),family=font,size=6.3/.pt)+
 scale_fill_manual(values=setNames(COL,groups),guide='none')+
 scale_x_continuous(breaks=1:4,labels=groups,limits=c(.55,4.65),expand=expansion(mult=0))+
 scale_y_continuous(breaks=0:ceiling(upper),limits=c(0,upper+.45),expand=expansion(mult=0))+
 labs(x=NULL,y='Relative abundance')+
 theme_classic(base_size=7,base_family=font)+theme(text=element_text(family=font,colour='black'),axis.text=element_text(size=7,colour='black'),axis.title=element_text(size=7),
 axis.line=element_line(linewidth=.3),axis.ticks=element_line(linewidth=.3),axis.ticks.length=unit(1,'mm'),plot.margin=margin(3,3,3,3,unit='mm'),plot.background=element_rect(fill='white',colour=NA))
export('raincloud',128,92,function()grid.draw(ggplotGrob(p)))
# 3. Radar: five explicitly bounded 0–1 variables, equal axis scales, two groups.
traits<-c('Protein\nhomeostasis','Antioxidant\ncapacity','Lipid\nturnover','Energy\nmetabolism','Immune\nresponse')
mu<-rbind(c(.75,.49,.52,.78,.58),c(.53,.79,.72,.50,.81))
rdat<-do.call(rbind,lapply(1:2,function(g)do.call(rbind,lapply(1:5,function(k)data.frame(Group=c('Control','Stress')[g],Subject=1:30,Trait=k,Value=rbeta(30,mu[g,k]*28,(1-mu[g,k])*28))))))
means<-matrix(NA,2,5);for(g in 1:2)for(k in 1:5)means[g,k]<-mean(rdat$Value[rdat$Group==c('Control','Stress')[g]&rdat$Trait==k])
rt<-lapply(1:5,function(k)t.test(Value~Group,data=rdat[rdat$Trait==k,]))
rstats<-data.frame(Trait=gsub('\n',' ',traits),p=vapply(rt,function(t)t$p.value,0));rstats$p_adj<-p.adjust(rstats$p,'BH')
write.csv(rdat,file.path(out,'radar_data.csv'),row.names=FALSE);write.csv(rstats,file.path(out,'radar_statistics.csv'),row.names=FALSE)
export('radar',130,102,function(){
 cx<-53;cy<-52;R<-31;a<-(90-seq(0,288,by=72))*pi/180
 for(level in c(.25,.5,.75,1))poly_mm(cx+R*level*cos(a),cy+R*level*sin(a),NA,col='#D8D8D8',lwd=.5)
 for(k in 1:5)line_mm(c(cx,cx+R*cos(a[k])),c(cy,cy+R*sin(a[k])),col='#D8D8D8',lwd=.5)
 for(g in 1:2){
  col<-COL[g]; x<-cx+R*means[g,]*cos(a);y<-cy+R*means[g,]*sin(a)
  poly_mm(x,y,grDevices::adjustcolor(col,alpha.f=.18),col=col,lwd=1,lty=g)
  grid.points(unit(x,'mm'),unit(y,'mm'),pch=c(21,24)[g],size=unit(1.6,'mm'),gp=gpar(fill=col,col=col,lwd=.3))
 }
 for(k in 1:5){
  x<-cx+(R+8)*cos(a[k]);y<-cy+(R+8)*sin(a[k]);text_at(traits[k],x,y,size=7)
 }
 # Scale labels placed between spokes and away from filled profiles.
 for(level in c(.25,.5,.75,1))text_at(format(level,trim=TRUE),cx+R*level*.16,cy+R*level,size=5.7,col='#666666')
 text_at('Group',105,59,just='left')
 for(g in 1:2){line_mm(c(105,110),rep(54-(g-1)*6,2),col=COL[g],lwd=1,lty=g);text_at(c('Control','Stress')[g],112,54-(g-1)*6,just='left')}
 text_at('Score (0–1)',105,36,just='left',size=6.5)
})
write.csv(do.call(rbind,text_log),file.path(out,'text_geometry.csv'),row.names=FALSE)
writeLines(capture.output(sessionInfo()),file.path(out,'sessionInfo.txt'))
cat('THREE_FIGURES_RENDERED\n')
