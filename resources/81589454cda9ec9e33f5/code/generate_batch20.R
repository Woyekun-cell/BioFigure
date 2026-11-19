options(stringsAsFactors=FALSE)
set.seed(20260914)
needed <- c('ggplot2','dplyr','tidyr','patchwork','ragg','scales','fmsb','ggradar','gghalves','ggdist','ggbeeswarm','corrplot','pheatmap','GGally','vegan','linkET','ggside','factoextra')
missing <- needed[!vapply(needed, requireNamespace, logical(1), quietly=TRUE)]
if(length(missing)) stop('Missing packages: ', paste(missing,collapse=', '))
suppressPackageStartupMessages({library(ggplot2);library(dplyr);library(tidyr);library(patchwork)})
dir.create('results/figures',recursive=TRUE,showWarnings=FALSE)
dir.create('results/plot_data',recursive=TRUE,showWarnings=FALSE)
dir.create('results/tables',recursive=TRUE,showWarnings=FALSE)
pal <- c('#3977A8','#E76855','#55A879','#D6A33C','#8267A8')
theme_bf <- function(base_size=10) theme_classic(base_size=base_size,base_family='Arial')+theme(plot.title=element_text(face='bold',size=base_size+1,hjust=.02),axis.title=element_text(face='bold'),axis.text=element_text(color='#202020'),legend.position='right',legend.title=element_text(face='bold'),plot.margin=margin(8,12,8,8))
savep <- function(name,p,w=7,h=5){ragg::agg_png(file.path('results/figures',name),width=w,height=h,units='in',res=180,background='white');print(p);dev.off()}
savebase <- function(name,w,h,expr){ragg::agg_png(file.path('results/figures',name),width=w,height=h,units='in',res=180,background='white');eval.parent(substitute(expr));dev.off()}

# 01-05 radar methods ---------------------------------------------------------
vars <- c('Refractive index','Resistance','Young modulus','Hardness','Conductivity')
rad <- data.frame(rbind(rep(1,5),rep(0,5),c(.72,.62,.31,.55,.65),c(.94,.91,.88,.82,.9))); colnames(rad)<-vars; rownames(rad)<-c('max','min','Membrane','Standard')
write.csv(rad,'results/plot_data/01_polygon_radar.csv')
savebase('01_polygon_radar_fmsb.png',7,5.5,{
 par(mar=c(1,2,2,2),family='Arial'); fmsb::radarchart(rad,axistype=0,pcol=c(pal[1],'#D66A75'),pfcol=scales::alpha(c(pal[1],'#F19CA7'),.30),plwd=2,plty=1,cglcol='#B8BDC4',cglty=2,cglwd=.8,vlcex=.9); legend('bottomright',legend=rownames(rad)[3:4],col=c(pal[1],'#D66A75'),lwd=2,bty='n',cex=.9)
})
loc <- paste0('Region ',LETTERS[1:10]); rdf <- matrix(runif(50,.2,.92),10,5,dimnames=list(loc,vars)); write.csv(rdf,'results/plot_data/02_faceted_radar.csv')
savebase('02_faceted_radar_fmsb.png',9,7,{
 par(mfrow=c(2,5),mar=c(1.5,1,2.3,1),family='Arial'); for(i in 1:10){x=rbind(rep(1,5),rep(0,5),rdf[i,]);fmsb::radarchart(as.data.frame(x),axistype=0,pcol=pal[(i-1)%%5+1],pfcol=scales::alpha(pal[(i-1)%%5+1],.35),plwd=1.4,cglcol='#CDD1D5',cglwd=.6,vlcex=.55);title(loc[i],cex.main=.8,font.main=2)}
})
radar_long <- data.frame(group=c('High','Medium','Low'),A=c(.85,.55,.40),B=c(.75,.72,.40),C=c(.25,.52,.76),D=c(.35,.48,.70),E=c(.55,.60,.52),F=c(.72,.44,.30),G=c(.60,.36,.46),H=c(.46,.58,.68))
write.csv(radar_long,'results/plot_data/03_ggradar_outer.csv',row.names=FALSE)
rad_plots <- lapply(seq_len(nrow(radar_long)),function(i) ggradar::ggradar(radar_long[i,],grid.min=0,grid.mid=.5,grid.max=1,values.radar=c('0','0.5','1'),group.colours=pal[i],fill=TRUE,fill.alpha=.28,group.point.size=2,group.line.width=.7,background.circle.colour='white',axis.label.size=3,legend.position='none')+ggtitle(radar_long$group[i])+theme(plot.title=element_text(hjust=.5,face='bold',family='Arial'),plot.background=element_rect(fill=if(i==1)'#E9F5F5' else if(i==2)'#F4F1F8' else '#EEF5E9',color=NA)))
savep('03_circular_radar_outer_ggradar.png',wrap_plots(rad_plots,nrow=1),10,3.4)
rad_lmm <- radar_long[1:2,];rad_lmm$group<-c('D1','D2'); write.csv(rad_lmm,'results/plot_data/04_radar_lmm.csv',row.names=FALSE)
p4 <- ggradar::ggradar(rad_lmm,grid.min=0,grid.mid=.5,grid.max=1,values.radar=c('0','0.5','1'),group.colours=c('#E76F2E','#159A72'),fill=FALSE,group.point.size=2.3,group.line.width=.9,axis.label.size=3.5,legend.position='top')+labs(subtitle='LMM: group × region; FDR-adjusted contrasts')+theme(plot.background=element_rect(fill='white',color=NA),plot.subtitle=element_text(hjust=.5,family='Arial',size=9))
savep('04_circular_radar_lmm.png',p4,6,5.5)
org <- paste0('Tissue ',1:14); dd <- data.frame(group=c('Detected','Reference','Difference'),matrix(runif(42,.15,.95),3,14));colnames(dd)[-1]<-org;dd[3,-1]<-abs(dd[1,-1]-dd[2,-1]);write.csv(dd,'results/plot_data/05_radar_difference.csv',row.names=FALSE)
p5 <- ggradar::ggradar(dd,grid.min=0,grid.mid=.5,grid.max=1,values.radar=c('0','50%','100%'),group.colours=c('#66528C','#BA4E77','#D6BD28'),fill=FALSE,group.point.size=1.8,group.line.width=.65,axis.label.size=2.7,legend.position='right')+theme(plot.background=element_rect(fill='white',color=NA))
savep('05_circular_radar_difference.png',p5,7.5,6)

# 06-10 raincloud methods ------------------------------------------------------
rain <- expand.grid(group=factor(c('subtilis','cereus','megaterium','circulans'),levels=c('subtilis','cereus','megaterium','circulans')),rep=1:75) |> mutate(value=pmax(0,rnorm(n(),c(14,12,7,4)[group],c(4,3.5,2.8,2)[group])))
write.csv(rain,'results/plot_data/06_raincloud.csv',row.names=FALSE)
p6<-ggplot(rain,aes(group,value,fill=group,color=group))+gghalves::geom_half_violin(side='r',position=position_nudge(x=.18),alpha=.75,width=.85)+geom_boxplot(width=.10,fill='white',outlier.shape=NA,position=position_nudge(x=.05))+geom_jitter(width=.07,size=.75,alpha=.55)+scale_fill_manual(values=c('#84A354','#B15053','#CF9A2C','#7D7C7F'))+scale_color_manual(values=c('#84A354','#B15053','#CF9A2C','#7D7C7F'))+labs(x=NULL,y='No. of BGCs / genome')+theme_bf()+theme(legend.position='none',axis.text.x=element_text(face='italic'))
savep('06_half_violin_box_points.png',p6,7,5)
age <- expand.grid(region=factor(c('Western Europe','Central/Eastern Europe','Southern Europe','Northern Europe','Central/Western Asia'),levels=rev(c('Western Europe','Central/Eastern Europe','Southern Europe','Northern Europe','Central/Western Asia'))),rep=1:55)|>mutate(kyr=pmin(15,pmax(0,rnorm(n(),c(2.5,4.5,6.5,8,10)[region],1.4))))
write.csv(age,'results/plot_data/07_violin_dotplot.csv',row.names=FALSE)
p7<-ggplot(age,aes(region,kyr,fill=region,color=region))+gghalves::geom_half_violin(side='r',position=position_nudge(x=.18),alpha=.8)+geom_boxplot(width=.12,fill='white',outlier.shape=NA)+ggbeeswarm::geom_quasirandom(width=.18,size=.55,alpha=.45,color='#767676')+coord_flip()+scale_y_reverse()+scale_fill_manual(values=c('#222222','#EF3340','#50AE88','#BDAA76','#78AECB'))+scale_color_manual(values=c('#222222','#EF3340','#50AE88','#BDAA76','#78AECB'))+labs(x=NULL,y='kyr BP')+theme_bf()+theme(legend.position='none')
savep('07_violin_box_beeswarm.png',p7,8,5.2)
qdat<-data.frame(group=rep(c('Stages III & IV','Stages I & II'),each=180),value=c(rgamma(180,shape=3,scale=150),rgamma(180,shape=4,scale=120)));write.csv(qdat,'results/plot_data/08_quantile_raincloud.csv',row.names=FALSE)
qs<-qdat|>group_by(group)|>summarise(q=list(seq(.1,.9,.1)),est=list(quantile(value,seq(.1,.9,.1))))|>unnest(c(q,est)); seg<-pivot_wider(qs,names_from=group,values_from=est)
p8<-ggplot(qdat,aes(group,value,fill=group))+gghalves::geom_half_violin(data=filter(qdat,group=='Stages III & IV'),side='l',position=position_nudge(x=-.16),alpha=.65)+gghalves::geom_half_violin(data=filter(qdat,group=='Stages I & II'),side='r',position=position_nudge(x=.16),alpha=.65)+geom_jitter(width=.035,size=.3,alpha=.22)+geom_boxplot(width=.07,outlier.shape=NA,fill='white')+geom_segment(data=seg,aes(x=1,xend=2,y=`Stages III & IV`,yend=`Stages I & II`),inherit.aes=FALSE,color='#555555',linewidth=.35)+geom_point(data=qs,aes(group,est),inherit.aes=FALSE,size=1.6)+coord_flip()+scale_fill_manual(values=c('#FFCE92','#B8CB99'))+labs(x=NULL,y='Distance (pixels)')+theme_bf()+theme(legend.position='bottom')
savep('08_quantile_raincloud_gghalves.png',p8,8,4.8)
gdat<-expand.grid(condition=c('MCI','DE'),group=c('No AD','AD as primary'),rep=1:70)|>mutate(value=rbeta(n(),2+as.numeric(factor(group)),3)+ifelse(condition=='DE',.13,0));write.csv(gdat,'results/plot_data/09_grouped_raincloud.csv',row.names=FALSE)
p9<-ggplot(gdat,aes(condition,value,fill=group))+gghalves::geom_half_violin(aes(color=group),side='l',position=position_nudge(x=-.12),alpha=.42)+geom_boxplot(position=position_dodge(.55),width=.13,outlier.shape=NA,alpha=.58)+geom_jitter(aes(color=group),position=position_jitterdodge(.035,.55),size=.45,alpha=.45)+scale_fill_manual(values=c('#94A4C7','#EE9A8D'))+scale_color_manual(values=c('#7589B4','#DD7769'))+labs(x=NULL,y=expression(P[AD]))+theme_bf()+theme(legend.position='top')
savep('09_grouped_raincloud_gghalves.png',p9,7,5)
epi<-data.frame(group=rep(c('Epilepsy','Control'),each=110),score=c(rnorm(110,-8,18),rnorm(110,11,17)));write.csv(epi,'results/plot_data/10_raindrop.csv',row.names=FALSE)
p10<-ggplot(epi,aes(group,score,fill=group,color=group))+ggdist::stat_halfeye(adjust=.7,width=.55,.width=0,justification=-.25,point_colour=NA,alpha=.9)+geom_boxplot(width=.10,outlier.shape=NA,alpha=.55)+geom_jitter(width=.07,size=.55,alpha=.35)+scale_fill_manual(values=c('#7655D9','#F2BB00'))+scale_color_manual(values=c('#7655D9','#D99B00'))+labs(x=NULL,y='Network strength (%)')+theme_bf()+theme(legend.position='none')
savep('10_raindrop_ggdist.png',p10,5.6,6)

# 11-20 correlation and matrix methods ----------------------------------------
n<-420;grp<-sample(c('MAG-A','MAG-B','MAG-C'),n,TRUE,c(.2,.55,.25));x<-10^runif(n,4,7);y<-x*10^rnorm(n,.03,.14);resdat<-data.frame(group=grp,genome=x,predicted=y);write.csv(resdat,'results/plot_data/11_fit_residual.csv',row.names=FALSE)
fit<-lm(log10(predicted)~log10(genome),resdat);resdat$resid<-residuals(fit)
p11a<-ggplot(resdat,aes(genome,predicted,color=group))+geom_point(size=.7,alpha=.55)+geom_smooth(method='lm',formula=y~x,se=FALSE,color='#E56B35',linewidth=.7)+ggside::geom_xsidedensity(aes(fill=group),alpha=.28,position='identity',show.legend=FALSE)+ggside::geom_ysidedensity(aes(fill=group),alpha=.28,position='identity',show.legend=FALSE)+scale_x_log10()+scale_y_log10()+scale_color_manual(values=pal[1:3])+scale_fill_manual(values=pal[1:3])+labs(x='Genome total size (bp)',y='Predicted CDS')+theme_bf()+ggside::theme_ggside_void()+theme(legend.position=c(.18,.76),legend.background=element_rect(fill=scales::alpha('white',.75),color=NA))
p11b<-ggplot(resdat,aes(group,resid,fill=group))+geom_boxplot(width=.55,outlier.shape=NA)+geom_hline(yintercept=0,linetype=2,color='#555555')+scale_fill_manual(values=pal[1:3])+labs(x=NULL,y='Residuals (log)')+theme_bf()+theme(legend.position='none')
savep('11_fit_marginal_residual_box.png',p11a+inset_element(p11b,.52,.06,.97,.40),7,6)
cmat<-cor(matrix(rnorm(60*36),60,36)+rep(rnorm(36),each=60)*.7);rownames(cmat)<-colnames(cmat)<-paste0('V',1:36);groups<-rep(1:4,each=9);write.csv(cmat,'results/plot_data/12_corr_bar.csv')
savebase('12_corrplot_with_sidebars.png',9,7,{
 layout(matrix(c(1,2),1,2),widths=c(5,1));par(mar=c(2,2,4,1),family='Arial');corrplot::corrplot(cmat,type='upper',order='hclust',method='circle',tl.cex=.55,tl.col=c('#7751A8','#20A8B2','#E69A3B','#4774C4')[groups],diag=TRUE,cl.pos='b',mar=c(1,1,2,1));par(mar=c(5,1,4,3));barplot(rev(rowMeans(abs(cmat))),horiz=TRUE,col=rev(c('#7751A8','#20A8B2','#E69A3B','#4774C4')[groups]),axes=FALSE,border=NA);axis(1,cex.axis=.7);mtext('Mean |r|',1,2,cex=.8)
})
cm2<-cor(matrix(rnorm(80*42),80,42)+rep(rnorm(42),each=80)*.55);ord<-hclust(as.dist(1-cm2))$order;m<-cm2[ord,ord];m[lower.tri(m)]<-NA;md<-as.data.frame(as.table(m));md<-md[!is.na(md$Freq),];write.csv(md,'results/plot_data/13_cluster_triangle.csv',row.names=FALSE)
p13<-ggplot(md,aes(Var2,Var1,fill=Freq))+geom_tile(color='white',linewidth=.12)+scale_fill_gradient2(low='#BED9EA',mid='white',high='#8D2F2B',midpoint=0)+coord_fixed()+labs(x=NULL,y=NULL,fill='Correlation')+theme_minimal(base_family='Arial')+theme(panel.grid=element_blank(),axis.text.x=element_text(size=5.2),axis.text.y=element_text(size=5.2),legend.position='right')
dend<-factoextra::fviz_dend(as.dendrogram(hclust(as.dist(1-cm2))),show_labels=FALSE,lwd=.45,axes=FALSE,ggtheme=theme_void())
p13r<-dend/p13+patchwork::plot_layout(heights=c(1,5))
savep('13_clustered_upper_triangle.png',p13r,8,7)
mat<-matrix(rnorm(32*16),32,16,dimnames=list(paste0('Cell ',1:32),paste0('Factor ',1:16)));mat[1:10,1:5]<-mat[1:10,1:5]+1.4;ann<-data.frame(Lineage=rep(c('Epithelial','Immune','Stromal','Myeloid'),each=8),row.names=rownames(mat));write.csv(mat,'results/plot_data/14_pheatmap.csv')
savebase('14_annotated_pheatmap.png',8,7,{pheatmap::pheatmap(mat,scale='row',cluster_cols=FALSE,annotation_row=ann,color=colorRampPalette(c('#4078A8','white','#C85D67'))(75),border_color='#ECECEC',fontsize=7,fontsize_row=6,main='Cell-state factor landscape')})
feat<-c('MHC-II','MHC-I','Complement','Apoptosis','TNFα/NFκB','IFNα','IFNγ','STING1');cnv<-c('Chrom gain','Chrom loss','Arm gain','Arm loss','Segment gain','Segment loss');bdat<-expand.grid(Feature=feat,CNV=cnv,Group=c('WGD-low','WGD-high'),Type=c('Curated','Hallmark'))|>mutate(rho=runif(n(),-.6,.6),pval=runif(n(),.0002,.12),sig=ifelse(pval<.01,'*',''));write.csv(bdat,'results/plot_data/15_faceted_bubble.csv',row.names=FALSE)
p15<-ggplot(bdat,aes(CNV,Feature))+geom_point(aes(size=-log10(pval),fill=rho),shape=21,color='#333333',stroke=.45)+geom_text(aes(label=sig),size=3)+facet_grid(Type~Group,scales='free_y',space='free_y')+scale_fill_gradient2(low='#6254A3',mid='white',high='#9B332E')+scale_size(range=c(1.2,5))+labs(x=NULL,y=NULL,fill="Spearman's ρ",size=expression(-log[10](P)))+theme_bf(9)+theme(axis.text.x=element_text(angle=55,hjust=1),strip.background=element_rect(fill='#F0F0F0'))
savep('15_faceted_correlation_bubbles.png',p15,9,6.8)
phy<-paste0('Phylum ',1:12);datasets<-paste0(rep(c('16S','Shotgun'),5),'-',rep(c('ARG','Beta-lactam','Glycopeptide','Tetracycline','Aminoglycoside'),each=2));bd2<-expand.grid(Phylum=phy,dataset=datasets)|>mutate(r=runif(n(),-.8,.8),abundance=sample(c(.004,.03,.22),n(),TRUE),sig=ifelse(runif(n())<.18,'*',''));write.csv(bd2,'results/plot_data/16_grouped_bubble.csv',row.names=FALSE)
p16<-ggplot(bd2,aes(dataset,Phylum))+geom_point(aes(size=cut(abundance,c(0,.01,.1,1)),fill=r),shape=21,color='#222222',stroke=.5)+geom_text(aes(label=sig),size=3)+geom_vline(xintercept=seq(2.5,8.5,2),linewidth=.35)+scale_fill_gradient2(low='#B33B2E',mid='white',high='#2A77A9')+scale_size_manual(values=c(2.5,4,5.5),name='Relative abundance')+labs(x=NULL,y=NULL,fill='Correlation')+theme_bf(9)+theme(axis.text.x=element_text(angle=58,hjust=1),panel.grid=element_blank())
savep('16_grouped_correlation_bubbles.png',p16,9,6)
yr<-seq(1970,2030,length.out=90);gd<-data.frame(Year=yr,AAC=14-.055*(yr-1970)+rnorm(90,0,2.4),PC=3+.035*(yr-1970)+rnorm(90,0,1.2),LC=.9+rnorm(90,0,.25),TV=22+.55*(yr-1970)+rnorm(90,0,8));write.csv(gd,'results/plot_data/17_ggally_regression.csv',row.names=FALSE)
cols<-c('#E6141C','#20A64F','#F4BA1A','#693290');names(cols)<-names(gd)[-1]
lower_fun<-function(data,mapping,...){ggplot(data,mapping)+geom_point(size=.55,color='#777777')+geom_smooth(method='lm',formula=y~x,se=FALSE,color='#CB514A',linewidth=.45)+theme_bf(7)}
diag_fun<-function(data,mapping,...){v=rlang::as_name(mapping$x);ggplot(data,mapping)+geom_histogram(aes(y=after_stat(density)),bins=12,fill=cols[v],color='white')+geom_density(linewidth=.45)+theme_bf(7)}
upper_fun<-function(data,mapping,...){x<-GGally::eval_data_col(data,mapping$x);y<-GGally::eval_data_col(data,mapping$y);ct<-cor.test(x,y);ggplot(data.frame(x=0,y=0),aes(x,y))+annotate('rect',xmin=-Inf,xmax=Inf,ymin=-Inf,ymax=Inf,fill=if(ct$p.value<.05)'#F8DED9' else '#F0F0F0')+annotate('text',x=0,y=0,label=sprintf('R² = %.2f\nP = %.3f',ct$estimate^2,ct$p.value),size=2.8)+theme_void()}
gm<-GGally::ggpairs(gd[,2:5],lower=list(continuous=lower_fun),diag=list(continuous=diag_fun),upper=list(continuous=upper_fun))+theme(strip.text=element_text(family='Arial',face='bold'))
savep('17_ggally_regression_matrix.png',gm,7.5,7)
data(varespec,package='vegan');data(varechem,package='vegan');set.seed(1801)
mant<-linkET::mantel_test(varespec,varechem,spec_select=list(Community_A=1:6,Community_B=7:12,Community_C=13:18,Community_D=19:24))|>mutate(P=cut(p,c(-Inf,.01,.05,Inf),labels=c('<0.01','0.01–0.05','≥0.05')),R=cut(abs(r),c(-Inf,.2,.4,Inf),labels=c('<0.2','0.2–0.4','≥0.4')))
write.csv(mant,'results/plot_data/18_linket_network.csv',row.names=FALSE)
p18<-linkET::qcorrplot(linkET::correlate(varechem),type='lower',diag=TRUE)+linkET::geom_square()+linkET::geom_couple(data=mant,aes(colour=P,size=R),curvature=linkET::nice_curvature(),nudge_x=.45)+scale_color_manual(values=c('<0.01'='#C83D4B','0.01–0.05'='#E69A35','≥0.05'='#AAB2BC'),drop=FALSE)+scale_size_manual(values=c('<0.2'=.45,'0.2–0.4'=1,'≥0.4'=1.8),drop=FALSE)+guides(color=guide_legend(title='Mantel P'),size=guide_legend(title='Mantel |r|'))+theme(text=element_text(family='Arial',size=9),legend.position='right')
savep('18_linket_correlation_network.png',p18,8.5,6.5)
dm<-as.data.frame(MASS::mvrnorm(240,mu=rep(0,6),Sigma=outer(1:6,1:6,function(i,j).7^abs(i-j))));names(dm)<-c('sp','Ca','Co','PEG','Ca2','HP1');write.csv(dm,'results/plot_data/19_density_matrix.csv',row.names=FALSE)
density_lower<-function(data,mapping,...){ggplot(data,mapping)+stat_density_2d(aes(fill=after_stat(nlevel)),geom='polygon',contour=TRUE)+scale_fill_gradientn(colors=c('white','#1FC3C8','#2166AC','#35A853','#F7E225','#E86A24','#A5162A'),guide='none')+theme_void()}
density_diag<-function(data,mapping,...){ggplot(data,mapping)+geom_density(fill='#43B7C2',alpha=.75,color='white')+theme_void()}
density_upper_rainbow<-function(data,mapping,...){x<-GGally::eval_data_col(data,mapping$x);y<-GGally::eval_data_col(data,mapping$y);rr<-cor(x,y,method='spearman');ggplot()+annotate('tile',x=0,y=0,fill=scales::col_numeric(c('#2B63B8','#27C5D8','#F4E535','#E95C25'),c(-1,1))(rr),width=2,height=2)+annotate('text',x=0,y=0,label=sprintf('%.2f',rr),size=3.2)+theme_void()}
g19<-GGally::ggpairs(dm,lower=list(continuous=density_lower),diag=list(continuous=density_diag),upper=list(continuous=density_upper_rainbow))+theme(strip.text=element_text(size=8,family='Arial'))
savep('19_density_matrix_rainbow.png',g19,8,7)
density_upper_red<-function(data,mapping,...){x<-GGally::eval_data_col(data,mapping$x);y<-GGally::eval_data_col(data,mapping$y);rr<-cor(x,y,method='spearman');ggplot()+annotate('tile',x=0,y=0,fill=scales::col_numeric(c('#FFF5F0','#FC9272','#CB181D'),c(0,1))(abs(rr)),width=2,height=2)+annotate('text',x=0,y=0,label=sprintf('%.2f',rr),size=3.2)+theme_void()}
g20<-GGally::ggpairs(dm,lower=list(continuous=density_lower),diag=list(continuous=function(data,mapping,...) ggplot(data,mapping)+geom_density(fill='#D9574D',alpha=.72,color='white')+theme_void()),upper=list(continuous=density_upper_red))+theme(strip.text=element_text(size=8,family='Arial'))
savep('20_density_matrix_red.png',g20,8,7)

files<-list.files('results/figures',pattern='\\.png$',full.names=FALSE);stopifnot(length(files)==20)
writeLines(capture.output(sessionInfo()),'results/tables/sessionInfo.txt')
cat('SCIDRAW_BATCH20_PNG_OK=',length(files),'\n',sep='')
