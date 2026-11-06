#!/usr/bin/env Rscript
# SciDraw source-method studies 36-45. Fixed-seed simulations; original data absent.
suppressPackageStartupMessages({
  library(ggplot2); library(patchwork); library(ggrepel); library(ggh4x)
  library(cowplot); library(networkD3); library(htmlwidgets); library(webshot2)
  library(scRNAtoolVis); library(circlize); library(ComplexHeatmap)
  library(ggtree); library(ggtreeExtra); library(treeio); library(ggnewscale)
  library(ggtern); library(ape); library(ragg)
})
arg <- grep('^--file=',commandArgs(FALSE),value=TRUE)
root <- normalizePath(file.path(dirname(sub('^--file=','',arg)),'..'))
fig_dir <- file.path(root,'results','figures'); data_dir <- file.path(root,'results','plot_data')
work_dir <- file.path(root,'work','cases-36-45')
dir.create(fig_dir,recursive=TRUE,showWarnings=FALSE);dir.create(data_dir,recursive=TRUE,showWarnings=FALSE)
dir.create(work_dir,recursive=TRUE,showWarnings=FALSE)
font <- 'Helvetica'
save_fig <- function(name,p,w,h) ggplot2::ggsave(file.path(fig_dir,name),p,width=w,height=h,dpi=220,
                                                  device=ragg::agg_png,bg='white')
write_data <- function(name,x) write.csv(x,file.path(data_dir,name),row.names=FALSE)
theme_bf <- function(size=9) theme_classic(base_family=font,base_size=size)+
  theme(axis.text=element_text(colour='black'),plot.margin=margin(6,8,6,6))

# 36 networkD3 Sankey: three stages, node widths fixed, link width encodes flow.
set.seed(20260957)
left <- c('Exe_at_ZT1','Exe_at_ZT13','Exe_at_ZT17','Exe_at_ZT21')
mid <- c('Adh1','Eno2','G6pc','Pck1')
right <- c('Wnt5b','Cnd2','Sox9','Col1a1','Col1a2','Col2a1','Col6a1','Col6a2',
           'Col6a3','Col11a2','Acan','Bglap','Col10a1','Wnt4','Dkk2','Mapk3','Comp','Wnt11','Mapk1','Gli1','Sost')
nodes36 <- data.frame(name=c(left,mid,right),stringsAsFactors=FALSE)
nodes36$group <- nodes36$name
links36 <- rbind(
  do.call(rbind,lapply(seq_along(left),function(i)data.frame(source=i-1,target=4+0:3,
    value=round(c(9,7,6,8)*runif(4,.65,1.25),1)))),
  do.call(rbind,lapply(seq_along(mid),function(i)data.frame(source=3+i,target=8+0:(length(right)-1),
    value=round(rexp(length(right),.38)+.4,1)))))
links36$group <- nodes36$name[links36$source+1]
cols36 <- c('#E7A83B','#46B8D4','#E95D6A','#31B879','#F4DD43','#D95AA0','#3FC9B3','#F08D59',
            grDevices::hcl.colors(length(right),'Set 3'))
widget36 <- networkD3::sankeyNetwork(Links=links36,Nodes=nodes36,Source='source',Target='target',
  Value='value',NodeID='name',NodeGroup='group',LinkGroup='group',fontSize=15,nodeWidth=12,height=600,width=800,iterations=0,
  nodePadding=7,colourScale=sprintf('d3.scaleOrdinal().range(["%s"])',paste(cols36,collapse='","')))
html36 <- file.path(work_dir,'36_sankey.html')
htmlwidgets::saveWidget(widget36,html36,selfcontained=FALSE)
webshot2::webshot(html36,file.path(fig_dir,'36_gradient_sankey.png'),vwidth=800,vheight=600,
                  cliprect=c(0,0,800,600),zoom=2,delay=.6)
img36 <- magick::image_read(file.path(fig_dir,'36_gradient_sankey.png')) |>
  magick::image_resize('1280x960!') |>
  magick::image_extent('1600x1200',gravity='northwest',color='white')
magick::image_write(img36,file.path(fig_dir,'36_gradient_sankey.png'))
write_data('36_gradient_sankey_links.csv',links36);write_data('36_gradient_sankey_nodes.csv',nodes36)

# 37 single-panel significance heatmap with a spacer row and side group labels.
set.seed(20260958)
acid37 <- c('CA','CDCA','DCA','UDCA','LCA','TCA','GCA','Ala-CA','Arg-CA','Glu-CA','Glu-CDCA',
            'Glu-DCA','Glu-UDCA','His-CA','His-CDCA','His-DCA','His-UDCA','Ile-CA','Ile-CDCA',
            'Ile-DCA','Ile-UDCA','Leu-CA','Leu-CDCA','Leu-DCA','Leu-UDCA','Lys-CA','Lys-CDCA',
            'Lys-DCA','Lys-UDCA','Met-CDCA','Met-DCA','Met-UDCA','Phe-CA','Phe-CDCA','Phe-DCA',
            'Phe-UDCA','Ser-CA','Trp-CDCA','Trp-DCA','Tyr-CA','Tyr-CDCA','Tyr-DCA')
tf37 <- c('FXR','VDR','CAR','PXR','AHR','PPARa','PPARd','PPARg')
d37 <- expand.grid(acid=acid37,tf=tf37,stringsAsFactors=FALSE)
d37$fold <- pmax(0,pmin(2,rnorm(nrow(d37),.33,.11)+rep(c(.08,-.04,.03,-.02,.06,.04,0,-.02),each=length(acid37))))
spike <- sample(seq_len(nrow(d37)),55);d37$fold[spike] <- pmax(0,pmin(2,d37$fold[spike]+runif(55,-.35,.9)))
d37$p <- pmin(1,exp(-abs(d37$fold-.3)*5)*runif(nrow(d37),.01,.45))
d37$sig <- ifelse(d37$p<.01,'**',ifelse(d37$p<.05,'*',''))
d37$acid <- factor(d37$acid,levels=acid37);d37$tf <- factor(d37$tf,levels=tf37)
lim37 <- c(rev(acid37[8:length(acid37)]),'skip',rev(acid37[1:7]))
p37core <- ggplot(d37,aes(tf,acid))+geom_tile(aes(fill=fold),colour='black',linewidth=.25)+
  geom_text(aes(label=sig,colour=fold<.3),size=3.2,vjust=.75,show.legend=FALSE)+
  scale_colour_manual(values=c(`TRUE`='#145444',`FALSE`='#7C2115'))+
  scale_fill_gradientn(colours=c('#6FCFCF','white','#DD6048'),values=c(0,.15,1),limits=c(0,2),
    breaks=0:2,labels=c(expression(10^0),expression(10^1),expression(10^2)),name='Fold\nChange')+
  scale_y_discrete(limits=lim37)+scale_x_discrete(expand=c(0,0))+
  annotate('rect',xmin=.5,xmax=8.5,ymin=.5,ymax=43.5,fill=NA,colour='black',linewidth=.55)+
  theme_bw(base_family=font)+theme(panel.grid=element_blank(),panel.border=element_blank(),
    axis.text.x=element_text(angle=45,hjust=1,size=9),axis.text.y=element_text(size=8.5),
    axis.ticks.length=unit(1.5,'mm'),legend.position='top',plot.margin=margin(4,4,4,0,'mm'))+
  labs(x=NULL,y=NULL)+guides(fill=guide_colorbar(position='top',direction='horizontal',
    barwidth=unit(30,'mm'),barheight=unit(3,'mm'),title.position='left',frame.colour='black'))
anno37 <- ggdraw()+draw_label('Conventional\nBile Acids',y=.84,angle=90,size=9,fontfamily=font)+
  draw_label('BBAAs',y=.42,angle=90,size=9,fontfamily=font)
p37 <- plot_grid(anno37,p37core,ncol=2,rel_widths=c(.1,.9))
save_fig('37_heatmap_significance_blankrow.png',p37,6,12);write_data('37_heatmap_significance_blankrow.csv',d37)

# Common synthetic differential-expression data for cases 38-40.
set.seed(20260959)
clusters <- c('B','CD14+ Mono','CD8 T','DC','FCGR3A+ Mono','Memory CD4 T','Naive CD4 T','NK','Platelet')
de <- do.call(rbind,lapply(seq_along(clusters),function(i){
  n<-420;fc<-c(rnorm(n*.7,0,.4),rnorm(n*.15,-2.3,.7),rnorm(n*.15,2.2,.7));
  data.frame(gene=paste0('G',i,'_',seq_len(n)),cluster=clusters[i],avg_log2FC=fc,
             p_val_adj=pmax(1e-6,pmin(1,10^(-abs(fc)*runif(n,.8,1.7))*runif(n,.2,1))))
}))
de$mlogp <- pmin(5,.35+abs(de$avg_log2FC)*runif(nrow(de),.75,1.25)+rexp(nrow(de),1.8))
de$p_val_adj <- 10^(-de$mlogp)
de$state <- ifelse(de$avg_log2FC>.5&de$p_val_adj<.05,'sigUp',
                   ifelse(de$avg_log2FC < -.5 & de$p_val_adj<.05,'sigDown','notSig'))
stopifnot(is.numeric(de$avg_log2FC),min(de$avg_log2FC) < -1,max(de$avg_log2FC)>1)

# 38 overview with background bands plus 3x3 fixed-scale small multiples.
cols38 <- c('#76A7C2','#80B97D','#795FA3','#EDAC77','#5F91AC','#BC8763','#A1A452','#D9C27E','#D14A3E')
p38a <- ggplot(de,aes(avg_log2FC,mlogp))+
  annotate('rect',xmin=-4,xmax=-.5,ymin=-Inf,ymax=Inf,fill='#C7DFE8')+
  annotate('rect',xmin=.5,xmax=4,ymin=-Inf,ymax=Inf,fill='#FFD8DF')+
  geom_point(aes(colour=cluster),size=1,alpha=.72)+scale_colour_manual(values=setNames(cols38,clusters))+
  geom_vline(xintercept=c(-.5,.5),linewidth=.35)+coord_cartesian(xlim=c(-4,4),ylim=c(0,5))+
  theme_bf(8)+theme(legend.position='none')+labs(x=expression(log[2]*'(FC)'),y=expression(-log[10]*'(adj. p-value)'))
p38b <- ggplot(de,aes(avg_log2FC,mlogp,colour=cluster))+geom_point(size=.65,alpha=.72)+
  facet_wrap2(~cluster,nrow=3,scales='fixed',strip=strip_themed(background_x=elem_list_rect(fill=cols38)))+
  scale_colour_manual(values=setNames(cols38,clusters))+coord_cartesian(xlim=c(-4,4),ylim=c(0,5))+
  theme_bf(6.5)+theme(legend.position='none',axis.text=element_text(size=6),strip.text=element_text(size=6.5),
                      panel.spacing=unit(1.2,'mm'))+labs(x=expression(log[2]*'(FC)'),y=NULL)
p38 <- p38a+p38b+plot_layout(widths=c(1,1.25))
save_fig('38_multi_tissue_volcano.png',p38,12,4.95);write_data('38_multi_tissue_volcano.csv',de)

# 39 nine horizontal volcano facets with direct top-gene labels.
top39 <- do.call(rbind,lapply(split(de,de$cluster),function(x)head(x[order(x$p_val_adj),],6)))
p39 <- ggplot(de,aes(mlogp,avg_log2FC))+geom_point(size=.65,colour='#C8C8C8',alpha=.75)+
  geom_point(data=top39,aes(colour=cluster),size=1.2)+
  geom_text(data=top39,aes(label=gene,colour=cluster),size=2.0,
            nudge_x=.16,check_overlap=TRUE)+
  geom_hline(yintercept=c(-.5,.5),linetype='dashed',colour='grey55',linewidth=.3)+
  facet_grid(.~cluster)+scale_colour_manual(values=setNames(cols38,clusters))+
  theme_bf(7)+theme(legend.position='none',strip.text=element_text(size=6.5),
                     axis.text.x=element_text(angle=45,hjust=1,size=6),panel.spacing.x=unit(1,'mm'))+
  labs(x=expression(-log[10]*'(p val adj)'),y=expression(log[2]*'(FC)'))
save_fig('39_multi_cell_volcano.png',p39,12,4.5);write_data('39_multi_cell_volcano.csv',de)

# 40 use scRNAtoolVis::jjVolcano directly; group order and tile bands are package-native.
de40 <- base::transform(de,p_val=p_val_adj)
order40 <- rev(c('B','CD14+ Mono','CD8 T','DC','FCGR3A+ Mono','Memory CD4 T','Naive CD4 T','NK'))
p40 <- suppressMessages(scRNAtoolVis::jjVolcano(diffData=subset(de40,cluster%in%order40),tile.col=grDevices::hcl.colors(9,'RdBu'),
  pSize=.65,celltypeSize=3,cluster.order=order40,legend.position=c(.83,.82),flip=TRUE,topGeneN=0)+
  labs(x='Group',y='Log2 Fold Change')+
  scale_color_manual(values=c(sigUp='#CC3333',sigDown='#0099CC'),
                     labels=c(sigUp='Significant Up',sigDown='Significant Down')))
# jjVolcano 0.1.0 leaves an empty GeomTextRepel layer when topGeneN=0; ggplot2 4.0
# tries to resolve its zero-sized viewport. Remove only that empty compatibility layer.
p40$layers <- p40$layers[!vapply(p40$layers,function(layer)
  inherits(layer$geom,'GeomTextRepel') && nrow(layer$data)==0,logical(1))]
save_fig('40_jjvolcano_comparisons.png',p40,8,8);write_data('40_jjvolcano_comparisons.csv',de40)

# 41 circlize UMAP-like polar cell atlas with three metadata rings.
set.seed(20260962)
celltypes <- c('Amacrine_cell','Astrocyte','B_cell','Bipolar_cell','Endothelial','MG','Microglia',
               'Monocyte_macrophage','NK','RGC','RPE','T_cell')
cols41 <- setNames(grDevices::hcl.colors(length(celltypes),'Dark 3'),celltypes)
n41 <- 2600
d41 <- data.frame(celltype=sample(celltypes,n41,TRUE,prob=seq(1,2,length.out=length(celltypes))))
d41$condition <- sample(c('Control','Injury'),n41,TRUE);d41$timepoint <- sample(c('0h','12h','1d','2d','4d','7d'),n41,TRUE)
d41$x <- ave(runif(n41),d41$celltype,FUN=function(z)rank(z)/length(z))
d41$y <- pmin(.72,pmax(.12,rnorm(n41,.42,.09)))
png(file.path(fig_dir,'41_circular_umap_metadata.png'),width=1760,height=1760,res=220,bg='white')
circos.clear();circos.par(start.degree=90,gap.degree=1,cell.padding=c(0,0,0,0),
                         track.margin=c(.003,.003),points.overflow.warning=FALSE)
circos.initialize(d41$celltype,xlim=c(0,1))
add_meta_track <- function(variable,palette,height=.025){
  circos.trackPlotRegion(ylim=c(0,1),track.height=height,bg.border='white',panel.fun=function(x,y){
    sec<-CELL_META$sector.index;z<-d41[d41$celltype==sec,,drop=FALSE]
    if(variable=='celltype'){
      circos.rect(0,0,1,1,col=palette[sec],border=NA)
    } else {
      z<-z[order(z[[variable]]),,drop=FALSE];edges<-seq(0,1,length.out=nrow(z)+1)
      circos.rect(edges[-length(edges)],0,edges[-1],1,col=unname(palette[z[[variable]]]),border=NA)
    }
  })
}
# circlize adds tracks from outside to inside. Metadata therefore precedes the
# cell cloud; reversing this order creates the wrong visual grammar.
add_meta_track('celltype',cols41,.032)
add_meta_track('condition',c(Control='#F5C04A',Injury='#DD5C72'))
add_meta_track('timepoint',setNames(grDevices::hcl.colors(6,'Blues 3'),c('0h','12h','1d','2d','4d','7d')))
circos.trackPlotRegion(ylim=c(0,1),track.height=.72,bg.border=NA,panel.fun=function(x,y){
  sec<-CELL_META$sector.index;z<-d41[d41$celltype==sec,]
  circos.points(z$x,z$y,pch=16,cex=.32,col=scales::alpha(cols41[sec],.55))
  circos.text(.5,1.18,gsub('_',' ',sec),cex=.42,facing='clockwise',niceFacing=TRUE,adj=c(0,0.5))
})
circos.clear();dev.off();write_data('41_circular_umap_metadata.csv',d41)

# 42 fan phylogeny, clade highlights, tip bubbles and outer continuous heatmap.
set.seed(20260963);tree42<-ape::rtree(52);tree42$tip.label<-paste0('ASV_',seq_len(52))
tip42<-data.frame(label=tree42$tip.label,phylum=rep(c('Acidobacteriota','Bacteroidetes','Cyanobacteria','Firmicutes','Streptophyta','Unassigned'),length.out=52),
                  abundance=sample(c(1000,2000,3000),52,TRUE),niche=rnorm(52,0,.32))
tipmeta42 <- tip42[,c('label','phylum','abundance')];heat42 <- tip42[,c('label','niche')]
p42 <- (ggtree(tree42,layout='fan',open.angle=10,linewidth=.55) %<+% tipmeta42)+
  geom_tippoint(aes(size=abundance,fill=phylum),shape=21,colour='black',stroke=.25)+
  scale_size_continuous(range=c(1.5,4),breaks=c(1000,2000,3000))+
  scale_fill_manual(values=setNames(grDevices::hcl.colors(6,'Pastel 1'),unique(tip42$phylum)))+
  ggnewscale::new_scale_fill()+
  geom_fruit(data=heat42,geom=geom_tile,mapping=aes(y=label,x=1,fill=niche),offset=.08,pwidth=.13)+
  scale_fill_gradient2(low='#F5B7B1',mid='white',high='#85C1AE',midpoint=0,name='Niche breadth')+
  geom_tiplab2(size=2.5,offset=.13)+theme(legend.position='right')
save_fig('42_phylogeny_highlight_heatmap.png',p42,10,8);write_data('42_phylogeny_highlight_heatmap.csv',tip42)

# 43 fan phylogeny with coloured clades and two outer binary/continuous rings.
set.seed(20260964);tree43<-ape::rtree(76);tree43$tip.label<-paste0('Taxon_',seq_len(76))
phyla43<-c('Actinobacteria','Bacteroidetes','Firmicutes','Fusobacteria','Lentisphaerae','Proteobacteria','Spirochaetes','Verrucomicrobia')
tip43<-data.frame(label=tree43$tip.label,phylum=rep(phyla43,length.out=76),bsh=sample(c('Absent','Present'),76,TRUE,prob=c(.65,.35)),fraction=runif(76,0,.6))
col43<-setNames(grDevices::hcl.colors(length(phyla43),'Dark 3'),phyla43)
tipmeta43<-tip43[,c('label','phylum')];frac43<-tip43[,c('label','fraction')];bsh43<-tip43[,c('label','bsh')]
p43 <- (ggtree(tree43,layout='fan',open.angle=5,linewidth=.55) %<+% tipmeta43)+
  geom_tippoint(aes(colour=phylum),size=.8)+
  scale_colour_manual(values=col43,na.value='grey55',name='phylum')+
  ggnewscale::new_scale_fill()+geom_fruit(data=frac43,geom=geom_tile,mapping=aes(y=label,x=1,fill=fraction),offset=.04,pwidth=.08)+
  scale_fill_gradient(low='white',high='#D94B49',name='Fraction of total\nBBAAs detected')+
  ggnewscale::new_scale_fill()+geom_fruit(data=bsh43,geom=geom_tile,mapping=aes(y=label,x=1,fill=bsh),offset=.03,pwidth=.055)+
  scale_fill_manual(values=c(Absent='#E6F2F4',Present='#49B8C8'),name='Presence of bsh gene')+
  theme(legend.position='right')
save_fig('43_phylogeny_two_heatmaps.png',p43,10.66,8);write_data('43_phylogeny_two_heatmaps.csv',tip43)

# 44 ggtern niche-preference plot; size is average relative abundance.
set.seed(20260965);n44<-460
d44<-data.frame(Root=rgamma(n44,1.8,1),Nodule=rgamma(n44,1.2,1),Rhizosphere=rgamma(n44,1.6,1))
s44<-rowSums(d44);d44[,1:3]<-d44[,1:3]/s44;d44$average_RA<-rexp(n44,15)
d44$enrich<-'NotSig';d44$enrich[d44$Nodule>.72]<-'Nodule';d44$enrich[d44$Root>.72]<-'Root';d44$enrich[d44$Rhizosphere>.72]<-'Rhizosphere'
p44 <- ggtern(d44,aes(Root,Nodule,Rhizosphere))+geom_mask()+
  geom_point(aes(size=average_RA,colour=enrich),alpha=.8)+scale_size(range=c(.2,10),guide='none')+
  scale_colour_manual(values=c(NotSig='grey80',Nodule='#D84C4C',Rhizosphere='#FF8D17',Root='#449F72'),
    breaks=c('Nodule','Rhizosphere','Root'),guide=guide_legend(title='Enriched OTUs',override.aes=list(shape=15,size=4.5,alpha=1)))+
  ggtern::Tlab('Nodule (12)')+ggtern::Llab('Root\n(40)')+ggtern::Rlab('Rhizosphere\n(13)')+theme_bw(base_size=5)+
  theme(tern.panel.grid.minor=element_line(colour='white'),tern.panel.grid.major=element_line(linewidth=.3,linetype='22'),
    tern.axis.text=element_blank(),tern.axis.ticks=element_line(colour='white'),axis.title=element_text(size=11),
    legend.title=element_text(size=11),legend.text=element_text(size=11),legend.position=c(.79,.80))
suppressMessages(suppressWarnings(save_fig('44_otu_niche_ternary.png',p44,8,8)));write_data('44_otu_niche_ternary.csv',d44)

# 45 butterfly violin panels with shared feature labels and mirrored score axes.
set.seed(20260966)
features<-c('Mphi-FTH1','Mphi-NUPR1','Mphi-MT1X','Mphi-SELENOP','Mphi-LIL1B','Mphi-RNASE1',
            'Mphi-FOLR2','Mphi-FN1','Mphi-CCL3L1','Mphi-ISG15','Mphi-CXCL9','Mphi-CCL2')
d45<-expand.grid(feature=features,model=c('M1','M2'),rep=seq_len(70),stringsAsFactors=FALSE)
d45$score<-rnorm(nrow(d45),ifelse(d45$model=='M1',.55,-.45),.25)+rep(seq(-.35,.35,length.out=12),each=140)
d45$feature<-factor(d45$feature,levels=rev(features));pal45<-setNames(grDevices::hcl.colors(12,'Spectral'),features)
pv <- function(dat,side){
 ggplot(dat,aes(score,feature,fill=feature))+geom_violin(trim=FALSE,scale='width',colour='#555555',linewidth=.35)+
  geom_boxplot(width=.15,fill='white',outlier.shape=NA,linewidth=.3)+geom_vline(xintercept=if(side=='M1').25 else -.25,linetype='dashed',colour='#BF1A2C',linewidth=.6)+
  scale_fill_manual(values=pal45)+scale_x_continuous(position='top',breaks=c(-1.5,-1,-.5,0,.5,1,1.5))+
  coord_cartesian(xlim=c(-1.55,1.55))+
  labs(x='Score',y=NULL,caption=paste(side,'Feature'))+theme_bf(10)+theme(legend.position='none',axis.text.y=element_blank(),
    axis.ticks.y=element_blank(),plot.caption=element_text(hjust=.5,size=13,colour=if(side=='M1')'#F04625' else '#00A8EE'))
}
mid45<-ggplot(data.frame(feature=factor(rev(features),levels=rev(features))),aes(x=1,y=feature,label=gsub('Mphi-','Mφ-',feature)))+
  geom_text(aes(colour=feature),size=4.4,family=font)+scale_colour_manual(values=pal45)+theme_void()+theme(legend.position='none')
p45<-pv(subset(d45,model=='M1'),'M1')+mid45+pv(subset(d45,model=='M2'),'M2')+plot_layout(widths=c(1,.62,1))
save_fig('45_butterfly_violin.png',p45,9.8,8);write_data('45_butterfly_violin.csv',d45)

stopifnot(nrow(links36)>0,nrow(d37)==42*8,length(unique(de$cluster))==9,nrow(d41)==2600,
          nrow(tip42)==52,nrow(tip43)==76,nrow(d44)==460,nrow(d45)==12*2*70)
message('Rendered source-method studies 36-45')
