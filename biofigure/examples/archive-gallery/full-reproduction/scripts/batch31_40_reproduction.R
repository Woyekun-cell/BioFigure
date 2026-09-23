suppressPackageStartupMessages({
  library(ggplot2); library(patchwork); library(dplyr); library(tidyr)
})
set.seed(20260913)
root <- normalizePath(file.path(dirname(commandArgs(trailingOnly=FALSE)[grep('--file=',commandArgs(trailingOnly=FALSE))] |> sub('--file=','',x=_)), '..'), mustWork=TRUE)
figdir <- file.path(root,'results','figures'); datdir <- file.path(root,'results','plot_data')
dir.create(figdir,recursive=TRUE,showWarnings=FALSE); dir.create(datdir,recursive=TRUE,showWarnings=FALSE)
pal <- c('#008F83','#E76F51','#6B5B95','#2D4059','#E9C46A','#58A6D6','#9BC995','#D98CB3')
theme_bf <- theme_classic(base_family='Arial', base_size=9) + theme(axis.text=element_text(color='#222222'), plot.title=element_text(face='bold',size=10,hjust=.5), legend.title=element_text(face='bold'), legend.key=element_blank())
savep <- function(p,n,w=180,h=130) ggsave(file.path(figdir,n),p,width=w,height=h,units='mm',dpi=300,bg='white',device=ragg::agg_png)

# 31 GSEA: GseaVis-compatible visual grammar; package runtime recorded separately.
genesets <- c('Nucleoside diphosphate\nmetabolic process','Neuron migration','Regulation of ossification','Tissue migration')
x <- 1:500
g31 <- bind_rows(lapply(seq_along(genesets),function(i){z<-cumsum(rnorm(500,ifelse(i<3,.006,-.003),.06)); z<-z/max(abs(z)); tibble(rank=x,ES=z,set=genesets[i])}))
hits <- bind_rows(lapply(seq_along(genesets),function(i)tibble(rank=sort(sample(x,38)),set=genesets[i],row=i)))
write.csv(g31,file.path(datdir,'batch31_gsea.csv'),row.names=FALSE)
p31a <- ggplot(g31,aes(rank,ES,color=set))+geom_hline(yintercept=0,color='grey55',linetype=2,linewidth=.3)+geom_line(linewidth=1)+scale_color_manual(values=pal[1:4])+labs(x=NULL,y='Enrichment score')+theme_bf+theme(legend.position='right',legend.text=element_text(size=7),legend.key.width=unit(9,'mm'))
p31b <- ggplot(hits,aes(rank,factor(row),color=set))+geom_point(shape='|',size=4)+scale_color_manual(values=pal[1:4])+labs(x=NULL,y=NULL)+theme_bf+theme(legend.position='none',axis.text.y=element_blank(),axis.ticks.y=element_blank(),axis.text.x=element_blank(),axis.ticks.x=element_blank())
stat31<-tibble(Pathway=genesets,NES=c(1.45,-1.61,-1.41,-1.61),P=c(.01,.021,.001,.001),FDR=c(.02,.08,.07,.089));p31c<-ggplot(stat31,aes(1,rev(seq_along(Pathway))))+geom_tile(aes(fill=NES),width=.28,height=.9)+geom_text(aes(x=.62,label=sprintf('NES %+.2f   P %s   FDR %s',NES,format(P,digits=2),format(FDR,digits=2))),hjust=0,size=2.8,family='Arial')+scale_fill_gradient2(low='#5B7DB1',mid='white',high='#D87059',midpoint=0,guide='none')+coord_cartesian(xlim=c(.8,2.2),clip='off')+theme_void()
savep(p31a/p31c/p31b+plot_layout(heights=c(3,1.15,1.2)),'batch31_gsea.png',190,165)

# 32 structured correlation heatmap: ComplexHeatmap core.
suppressPackageStartupMessages({library(ComplexHeatmap);library(circlize);library(grid)})
n1<-18;n2<-22; z<-matrix(rnorm(n1*n2),n1,n2); z[,1:7]<-z[,1:7]+seq(-1,1,length.out=n1); z[]<-pmax(-2,pmin(2,z))
rownames(z)<-paste0('Taxon ',seq_len(n1));colnames(z)<-paste0('Trait ',seq_len(n2)); grp<-factor(rep(c('Metabolic','Gut','Neural','Other'),c(6,6,5,5)))
write.csv(z,file.path(datdir,'batch32_correlation.csv'))
ragg::agg_png(file.path(figdir,'batch32_heatmap_part.png'),width=1500,height=1800,res=300,bg='white')
ht<-Heatmap(z,name='Z score',col=colorRamp2(c(-2,0,2),c('#F0A202','white','#27348B')),cluster_rows=TRUE,cluster_columns=FALSE,column_split=grp,column_gap=unit(1,'mm'),show_row_dend=FALSE,row_names_side='right',row_names_gp=gpar(fontfamily='Arial',fontsize=7),column_names_gp=gpar(fontfamily='Arial',fontsize=7),column_names_rot=90,top_annotation=HeatmapAnnotation(group=grp,col=list(group=setNames(pal[1:4],levels(grp))),show_annotation_name=FALSE),heatmap_legend_param=list(direction='horizontal',title_position='topcenter'))
draw(ht,heatmap_legend_side='bottom'); dev.off()
ragg::agg_png(file.path(figdir,'batch32_corr_part.png'),width=1500,height=1800,res=300,bg='white');cm32<-cor(matrix(rnorm(8000),400,20));corrplot::corrplot(cm32,method='square',type='lower',diag=TRUE,tl.col='#222222',tl.cex=.65,cl.pos='b',col=colorRampPalette(c('#F0A202','white','#27348B'))(100),mar=c(1,1,1,1));dev.off()
hm32<-magick::image_read(file.path(figdir,'batch32_heatmap_part.png'))|>magick::image_trim()|>magick::image_resize('1300x1500!');co32<-magick::image_read(file.path(figdir,'batch32_corr_part.png'))|>magick::image_trim()|>magick::image_resize('1300x1500!');magick::image_append(c(hm32,co32),stack=FALSE)|>magick::image_border('white','30x30')|>magick::image_write(file.path(figdir,'batch32_correlation.png'))

# 33 chord + UpSet: circlize and ComplexHeatmap core.
labs<-c('D','J1','J2','I','C1','C2','C3'); mtx<-matrix(sample(0:36,49,TRUE),7,7,dimnames=list(labs,labs));diag(mtx)<-0
sets<-lapply(seq_along(labs),function(i)sample(sprintf('G%03d',1:180),sample(45:85,1)));names(sets)<-labs
write.csv(mtx,file.path(datdir,'batch33_chord_matrix.csv'))
ragg::agg_png(file.path(figdir,'batch33_chord_part.png'),width=1500,height=1500,res=300,bg='white');circos.clear();circos.par(gap.after=rep(3,7));chordDiagram(mtx,grid.col=setNames(pal[1:7],labs),transparency=.48,annotationTrack='grid',preAllocateTracks=list(track.height=.1));circos.track(track.index=2,panel.fun=function(x,y){s=get.cell.meta.data('sector.index');circos.text(CELL_META$xcenter,CELL_META$ylim[1],s,facing='clockwise',niceFacing=TRUE,adj=c(0,.5),cex=.65)},bg.border=NA);dev.off()
ragg::agg_png(file.path(figdir,'batch33_upset_part.png'),width=2100,height=1100,res=300,bg='white');cm<-make_comb_mat(sets);draw(UpSet(cm,set_order=labs,top_annotation=upset_top_annotation(cm,add_numbers=TRUE),pt_size=unit(2.2,'mm')));dev.off()
ch<-magick::image_read(file.path(figdir,'batch33_chord_part.png'))|>magick::image_trim()|>magick::image_resize('1050x1050')
up<-magick::image_read(file.path(figdir,'batch33_upset_part.png'))|>magick::image_trim()|>magick::image_resize('1650x1050')
ch<-ch|>magick::image_resize('1650x920')
up<-up|>magick::image_resize('1650x920')
magick::image_append(c(ch,up),stack=TRUE)|>magick::image_border('white','35x35')|>magick::image_write(file.path(figdir,'batch33_chord_upset.png'))

# 34 faceted stacked composition.
celltypes<-c('Enterocytes','Enterocytes II','Fibroblasts','Fibroblasts II','Goblets','Goblet cells'); cond<-c('SPF','GF','FMT'); seg<-LETTERS[1:4]; sub<-paste0('Subtype ',1:7)
d34<-expand_grid(celltype=celltypes,condition=cond,segment=seg,subtype=sub)|>group_by(celltype,condition,segment)|>mutate(value=rgamma(n(),2),frac=100*value/sum(value),highlight=subtype=='Subtype 2')|>ungroup()
write.csv(d34,file.path(datdir,'batch34_stacked.csv'),row.names=FALSE)
plist34<-lapply(celltypes,function(ct)ggplot(filter(d34,celltype==ct),aes(segment,frac,fill=subtype))+geom_col(aes(color=highlight),linewidth=.35)+scale_color_manual(values=c('FALSE'=NA,'TRUE'='#111111'),guide='none',na.value=NA)+scale_fill_manual(values=c(pal,'#B8C1CC')[1:7])+facet_wrap(~condition,nrow=1)+labs(x=NULL,y='Percentage of cells',title=ct,fill=NULL)+theme_bf+theme(strip.background=element_blank(),strip.text=element_text(size=7),plot.title=element_text(size=9),legend.position='none',axis.text.x=element_text(size=6)))
p34<-wrap_plots(plist34,ncol=2)
savep(p34,'batch34_stacked_facets.png',190,190)

# 35 bubble heatmap + gene-class strip + dendrogram ordering.
types<-c('Club','Basal','Ionocyte','NE','Ciliated','Tuft','SDP','AIC','AT2','AT1','Malignant'); genes<-paste0('G',1:42); mat<-matrix(rnorm(length(types)*length(genes)),nrow=length(types),dimnames=list(types,genes)); ord<-labels(as.dendrogram(hclust(dist(t(mat)),method='ward.D2')));d35<-as.data.frame(as.table(mat));names(d35)<-c('cell','gene','avg');d35$pct<-plogis(d35$avg)*100;d35$gene<-factor(d35$gene,levels=ord);anno35<-tibble(gene=factor(ord,levels=ord),class=rep(paste0('Class ',1:7),length.out=length(ord)))
write.csv(d35,file.path(datdir,'batch35_bubble.csv'),row.names=FALSE)
p35a<-ggplot(d35,aes(gene,cell))+geom_point(aes(size=pct,fill=avg),shape=21,color='#333333',stroke=.18)+scale_fill_gradientn(colors=c('#F7F5FA','#B9AED4','#4A1486'))+scale_size(range=c(.3,4),breaks=c(25,50,75,100))+labs(x=NULL,y=NULL,fill='Average expression',size='Expression (%)')+theme_bf+theme(axis.text.x=element_blank(),axis.ticks.x=element_blank(),legend.position='top',panel.grid=element_line(color='#EEEEEE',linewidth=.2))
p35b<-ggplot(anno35,aes(gene,1,fill=class))+geom_tile()+scale_fill_manual(values=pal)+theme_void()+theme(legend.position='none')
savep(p35a/p35b+plot_layout(heights=c(12,.5)),'batch35_bubble_part.png',220,120)
ragg::agg_png(file.path(figdir,'batch35_tree_part.png'),width=650,height=1200,res=300,bg='white');par(mar=c(1,0,1,0),family='Arial');plot(as.dendrogram(hclust(dist(mat),method='ward.D2')),horiz=TRUE,axes=FALSE,leaflab='none');dev.off()
tr<-magick::image_read(file.path(figdir,'batch35_tree_part.png'))|>magick::image_trim()|>magick::image_resize('500x1200!');bp<-magick::image_read(file.path(figdir,'batch35_bubble_part.png'))|>magick::image_trim()|>magick::image_resize('2200x1200!');magick::image_append(c(tr,bp),stack=FALSE)|>magick::image_border('white','25x25')|>magick::image_write(file.path(figdir,'batch35_dendro_bubble.png'))

# 36 swimmer with aplot annotation strip.
n<-38; d36<-tibble(id=factor(sprintf('%02d',1:n),levels=sprintf('%02d',n:1)),duration=sort(runif(n,70,520)),status=sample(c('Ongoing','Stopped'),n,TRUE),response=sample(c('PR','SD','PD'),n,TRUE));ev<-d36|>slice_sample(n=36)|>mutate(time=duration*runif(n(),.25,.9),event=sample(c('ctDNA+','ctDNA-'),n(),TRUE));ann<-tibble(id=d36$id,Sex=sample(c('Female','Male'),n,TRUE),Stage=sample(c('III','IV'),n,TRUE),Best=d36$response,LiverMets=sample(c('Yes','No'),n,TRUE),LungMets=sample(c('Yes','No'),n,TRUE))
write.csv(d36,file.path(datdir,'batch36_swimmer.csv'),row.names=FALSE)
p36<-ggplot(d36,aes(duration,id,color=response))+geom_segment(aes(x=0,xend=duration,yend=id),linewidth=.8)+geom_point(data=ev,aes(time,id,shape=event),size=2,fill='white')+geom_point(aes(x=duration,shape=status),size=2)+scale_color_manual(values=pal[c(1,4,2)])+scale_shape_manual(values=c('ctDNA+'=16,'ctDNA-'=1,'Ongoing'=17,'Stopped'=15))+labs(x='Time after surgery (days)',y=NULL,color='Best response',shape=NULL)+theme_bf+theme(legend.position='bottom')
pa<-ann|>pivot_longer(-id)|>ggplot(aes(name,id,fill=value))+geom_tile(color='white',linewidth=.2)+scale_fill_manual(values=c('Female'='#E76F51','Male'='#008F83','III'='#70A1D7','IV'='#2D4059','PR'='#55A868','SD'='#4C72B0','PD'='#C49A58','Yes'='#9B7EBD','No'='#F4F4F4'))+theme_void()+theme(axis.text.x=element_text(angle=90,hjust=1,size=6.5),legend.position='none')
savep(aplot::insert_left(p36,pa,width=.22),'batch36_swimmer.png',180,180)

# 37 Table 1: table1 computes summaries; grob provides PNG typography.
suppressPackageStartupMessages({library(table1);library(gridExtra)})
n<-146;d37<-tibble(group=factor(sample(c('Control','Treatment'),n,TRUE,prob=c(1,2))),age=sample(18:65,n,TRUE),sex=factor(sample(c('Female','Male'),n,TRUE)),weight=round(rlnorm(n,log(70),.2),1))
label(d37$age)<-'Age';units(d37$age)<-'years';label(d37$weight)<-'Weight';units(d37$weight)<-'kg'; invisible(table1(~age+sex+weight|group,data=d37,overall=FALSE))
fmt<-function(x)sprintf('%.1f (%.1f)',mean(x),sd(x)); tab<-data.frame(Characteristic=c('Age, years','  Mean (SD)','Sex','  Female','  Male','Weight, kg','  Mean (SD)'),Control=c('',fmt(d37$age[d37$group=='Control']),'',sum(d37$sex[d37$group=='Control']=='Female'),sum(d37$sex[d37$group=='Control']=='Male'),'',fmt(d37$weight[d37$group=='Control'])),Treatment=c('',fmt(d37$age[d37$group=='Treatment']),'',sum(d37$sex[d37$group=='Treatment']=='Female'),sum(d37$sex[d37$group=='Treatment']=='Male'),'',fmt(d37$weight[d37$group=='Treatment'])))
write.csv(d37,file.path(datdir,'batch37_table1.csv'),row.names=FALSE)
ragg::agg_png(file.path(figdir,'batch37_table1.png'),width=1600,height=950,res=300,bg='white');grid.newpage();grid.draw(tableGrob(tab,rows=NULL,theme=ttheme_minimal(base_family='Arial',base_size=13,core=list(fg_params=list(hjust=c(0,.5,.5),x=c(.03,.5,.5)),bg_params=list(fill=c('#FFFFFF','#F5F7F9'),col=NA)),colhead=list(fg_params=list(fontface='bold'),bg_params=list(fill='#DCE6F1',col=NA)))));dev.off()

# 38 ggmagnify core.
d38<-bind_rows(lapply(c('SPF','GF'),function(g){bind_rows(lapply(c('Background','Target A','Target B'),function(k)tibble(group=g,class=k,x=rbeta(ifelse(k=='Background',700,170),ifelse(k=='Background',2,8),ifelse(k=='Background',7,3)))))}))
write.csv(d38,file.path(datdir,'batch38_magnify.csv'),row.names=FALSE)
p38<-ggplot(d38,aes(x,fill=class))+geom_histogram(position='identity',bins=28,alpha=.78,color='white',linewidth=.15)+facet_wrap(~group,ncol=1)+scale_fill_manual(values=c('#CAB2D6','#D73027','#53BFC1'))+labs(x='Proximal                                      Distal',y='Count',fill=NULL)+theme_bf+theme(legend.position='bottom',strip.background=element_blank())+ggmagnify::geom_magnify(from=c(.58,.96,0,110),to=c(.38,.82,160,330),colour='#E9A23B',linewidth=.5,proj.linetype=1)
savep(p38,'batch38_magnify.png',165,165)

# 39 multi-group volcano; labels restricted to top genes, ggrepel outside dense cloud.
segm<-LETTERS[1:4];d39<-expand_grid(segment=segm,gene=paste0('Gene',1:900))|>mutate(fc=rnorm(n(),0,.72),sig=case_when(fc > .8~'Up in SPF',fc < -.8~'Up in GF',TRUE~'NS'))|>group_by(segment)|>mutate(label=ifelse(rank(-abs(fc))<=3,gene,NA_character_))|>ungroup()
write.csv(d39,file.path(datdir,'batch39_volcano.csv'),row.names=FALSE)
p39<-ggplot(d39,aes(gene,fc))+ggrastr::geom_point_rast(aes(color=sig),size=.45,alpha=.65,raster.dpi=300,dev='ragg')+geom_hline(yintercept=c(-.8,.8),linetype=2,color='grey50',linewidth=.3)+ggrepel::geom_text_repel(data=filter(d39,!is.na(label)),aes(label=label),size=2.4,box.padding=.25,min.segment.length=0,max.overlaps=Inf,seed=20260913)+facet_wrap(~segment,nrow=1,scales='free_x')+scale_color_manual(values=c('NS'='#777777','Up in GF'='#111111','Up in SPF'='#35B84A'))+labs(x=NULL,y='Average log2FC',color=NULL)+theme_bf+theme(axis.text.x=element_blank(),axis.ticks.x=element_blank(),axis.line.x=element_blank(),strip.background=element_blank(),legend.position='bottom')
savep(p39,'batch39_multigroup_volcano.png',220,95)

# 40 radial windmill.
lineages<-c('Biliary','Bladder','Bone','Bowel','Breast','CNS/Brain','Head/Neck','Kidney','Liver','Lung','Lymphoid','Myeloid','Other','Ovary','PNS','Pancreas','Skin','Soft','Stomach','Uterus')
d40<-expand_grid(lineage=lineages,rep=1:7)|>mutate(dep=runif(n(),.2,2),id=row_number()); labs40<-d40|>group_by(lineage)|>slice(ceiling(n()/2))|>ungroup()|>mutate(angle=90-360*(id-.5)/max(d40$id),hjust=ifelse(angle < -90,1,0),angle=ifelse(angle < -90,angle+180,angle))
write.csv(d40,file.path(datdir,'batch40_windmill.csv'),row.names=FALSE)
p40<-ggplot(d40,aes(id,dep,fill=lineage))+geom_hline(yintercept=c(1,1.5),color='grey55',linewidth=.45)+geom_col(width=.92,color=NA,alpha=.96)+geom_text(data=labs40,aes(x=id,y=2.18,label=lineage,angle=angle,hjust=hjust),size=2.7,color='#222222',inherit.aes=FALSE)+annotate('point',x=.5,y=.08,size=8,shape=21,fill='white',color='grey35',stroke=.5)+coord_polar(clip='off')+scale_y_continuous(limits=c(0,2.28),breaks=c(1,1.5,2))+scale_fill_manual(values=rep(c('#008F83','#F27267','#895280','#2D314F','#E9C46A','#58A6D6'),length.out=20))+theme_void(base_family='Arial')+theme(legend.position='none',plot.margin=margin(14,14,14,14))
savep(p40,'batch40_windmill.png',150,150)

unlink(file.path(figdir,c('batch32_heatmap_part.png','batch32_corr_part.png','batch33_chord_part.png','batch33_upset_part.png','batch35_tree_part.png','batch35_bubble_part.png')))
writeLines(capture.output(sessionInfo()),file.path(root,'results','tables','sessionInfo.txt'))
