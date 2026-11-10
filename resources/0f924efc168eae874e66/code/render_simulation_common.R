# Independent source-informed implementation; source tutorials remain unchanged.
suppressPackageStartupMessages({library(ggplot2);library(dplyr);library(tidyr);library(cowplot);library(ggrepel);library(ggtree);library(ggtreeExtra);library(ape);library(jsonlite);library(yaml)})
options(warn=1)
cowplot::set_null_device('agg')
pt <- ggplot2::.pt
plain <- function() theme_classic(base_size=7,base_family='Arial')+theme(text=element_text(family='Arial',colour='#202020'),axis.text=element_text(size=7,colour='#202020'),axis.title=element_text(size=7),axis.line=element_line(linewidth=.25),axis.ticks=element_line(linewidth=.25),legend.text=element_text(size=6),legend.title=element_text(size=7),legend.key.size=unit(2.6,'mm'),plot.margin=margin(2,2,2,2,'mm'))
footer <- function(p,caption_size=6) p # Disclosure is stored in external metadata, never on canvas.
plot86 <- function(root) {
 library(ggsankeyfier)
 d <- read.csv(file.path(root,'results/plot_data/pathways.csv'));cols<-unlist(fromJSON(file.path(root,'data/metadata/node_colors.json')))
 links<-d %>% separate_rows(metabolites,sep='/') %>% mutate(pathNames=factor(pathNames,levels=rev(d$pathNames)),metabolites=factor(metabolites,levels=rev(head(names(cols),-12))),weight=1)
 long<-pivot_stages_longer(links,stages_from=c('metabolites','pathNames'),values_from='weight');long$stage<-as.numeric(long$stage)
 pos<-position_sankey(v_space=.75,order='as_is',width=.075)
 p<-ggplot(long,aes(stage,weight,group=node,connector=connector,edge_id=edge_id,fill=node))+
 geom_sankeyedge(position=pos,fill='#D0D0D0',colour=NA,alpha=.50)+geom_sankeynode(position=pos,colour=NA)+
 geom_text(aes(label=node),stat='sankeynode',position=position_sankey(v_space=.75,order='as_is',nudge_x=-.055),hjust=1,size=6/pt,family='Arial',colour='#202020')+
 scale_fill_manual(values=cols,guide='none')+scale_x_continuous()+theme_void(base_family='Arial')+theme(legend.text=element_text(size=8.2),legend.title=element_text(size=9),legend.key.size=unit(3,'mm'),legend.position='right',plot.margin=margin(2,2,2,2,'mm'))
 built<-ggplot_build(p);nodes<-built$data[[3]];target<-nodes %>% filter(connector=='to') %>% transmute(pathNames=as.character(label),y=(ymin+ymax)/2,ymin,ymax)
 stopifnot(nrow(target)==12,!anyDuplicated(target$pathNames));bubble<-left_join(d,target,by='pathNames');stopifnot(!anyNA(bubble$y));bubble$score<--log10(bubble$Pvalue);bubble$x<-2.12+(bubble$score-.5)*.24
 ymax<-max(nodes$ymax);bottom<-min(target$ymin);top<-max(target$ymax)
 p<-p+geom_rect(inherit.aes=FALSE,aes(xmin=2.095,xmax=2.60,ymin=bottom,ymax=top),data=data.frame(a=1),fill=NA,colour='#30343B',linewidth=.25)+
 geom_point(data=bubble,aes(x=x,y=y,size=count,colour=Hit.Ratio),inherit.aes=FALSE)+scale_size_continuous(name='Count',range=c(1,3),breaks=c(2,5,10),guide=guide_legend(order=1))+scale_colour_gradient(name='Hit ratio',low='#FE7D82',high='#CC0000',breaks=c(.2,.3,.4,.5),guide=guide_colourbar(display='rectangles',order=2))+
 annotate('text',x=2.12+c(0,.5,1,1.5,2)*.24,y=bottom-1.2,label=c('0.5','1.0','1.5','2.0','2.5'),family='Arial',size=8/pt,vjust=1)+
 annotate('text',x=2.36,y=bottom-4.2,label='-log10(P)',family='Arial',size=9/pt)+
 coord_cartesian(xlim=c(.02,2.65),ylim=c(bottom-7,ymax+1),clip='off')
 write.csv(bubble,file.path(root,'results/plot_data/bubble_aligned.csv'),row.names=FALSE)
 write_json(list(status='PASS',membership_edges=nrow(links),metabolites=n_distinct(links$metabolites),pathways=nrow(target),maximum_y_alignment_error=max(abs(bubble$y-target$y[match(bubble$pathNames,target$pathNames)]))),file.path(root,'evidence/geometry-checks.json'),auto_unbox=TRUE,pretty=TRUE)
 footer(p)
}
plot89 <- function(root) {
 d<-read.csv(file.path(root,'results/plot_data/genes.csv'),na.strings=c('','NA'));d$score<-abs(d$epsilon*d$nlp);d$ntc<-grepl('^NTC',d$gene)
 candidates<-seq(0,max(d$score),by=.025);rates<-sapply(candidates,function(t){s<-d$score>t;if(!any(s))return(NA_real_);mean(d$ntc[s])});thr<-min(candidates[is.finite(rates)&rates<.05]);stopifnot(is.finite(thr),thr>0)
 d$above<-d$score>thr;d$group<-ifelse(d$ntc,'Non-targeting',ifelse(!d$above,'Other genes',ifelse(d$epsilon>0,'Positive hits','Negative hits')));d$group[d$gene=='MAPT']<-'MAPT'
 colors<-c('Non-targeting'='black','Other genes'='#999999','Positive hits'='#D5C9D5','Negative hits'='#B3CED9','MAPT'='#FFD700');pw<-c('GPI anchor'='#0110CF','Ubiquitin/Proteasome'='#7A15CB','UFMylation'='#D67C01','Autophagy+'='#228823','Autophagy-'='#33C934','Mitochondria'='#BF370D')
 curve<-data.frame(x=c(seq(-4,-.05,length.out=400),seq(.05,4,length.out=400)),branch=rep(c('left','right'),each=400));curve$y<-thr/abs(curve$x);curve<-subset(curve,y<=4.15)
 label_names<-c('METTL3','MAPT','METTL14','PIGB','MTOR','USP10','UBA5','UFM1','UFL1','USP16','ARIH2','SOCS4','ATG14','WIPI2','CUL5','LAMTOR5','KEAP1','RNF7');lab<-d[d$gene%in%label_names,]
 p<-ggplot(d,aes(epsilon,nlp))+geom_point(data=subset(d,!above&!ntc),aes(colour=group),alpha=.3,size=1)+geom_point(data=subset(d,!above&ntc),aes(colour=group),alpha=.3,size=1)+
 geom_point(data=subset(d,above&is.na(pathway)),aes(colour=group),size=1.4,alpha=.88)+geom_point(data=subset(d,above&!is.na(pathway)),aes(fill=pathway),shape=21,colour='#202020',stroke=.25,size=1.8)+
 geom_line(data=curve,aes(x,y,group=branch),inherit.aes=FALSE,linetype='dotted',linewidth=.35)+
 geom_text_repel(data=lab,aes(label=gene),family='Arial',size=8/pt,seed=42,min.segment.length=0,box.padding=.25,point.padding=.15,max.overlaps=Inf,max.iter=20000,max.time=Inf,segment.size=.2,nudge_x=ifelse(lab$epsilon<0,-.1,.1))+
 scale_colour_manual(values=colors,name=NULL,breaks=c('Other genes','Non-targeting','Positive hits','Negative hits','MAPT'))+scale_fill_manual(values=pw,name=NULL)+guides(colour=guide_legend(order=1),fill=guide_legend(order=2))+
 scale_x_continuous(breaks=c(-4,-2,0,2,4))+scale_y_continuous(breaks=0:4)+coord_cartesian(xlim=c(-4,4),ylim=c(0,4.25),expand=FALSE,clip='off')+
 labs(x='Normalized phenotype (simulated)',y='Synthetic -log10(P)')+plain()+theme(axis.text=element_text(size=9.6),axis.title=element_text(size=11.2),legend.text=element_text(size=7.2),legend.position='right',legend.box='vertical',legend.margin=margin(0,0,0,0),plot.margin=margin(4,3,3,3,'mm'))
 write.csv(data.frame(threshold=candidates,selected_ntc_fraction=rates),file.path(root,'results/plot_data/threshold_scan.csv'),row.names=FALSE)
 write_json(list(status='PASS',points=nrow(d),threshold=thr,selected_ntc_fraction=rates[match(thr,candidates)],method='Synthetic empirical negative-control proportion, not BH-FDR',curve_branches=2,labels=nrow(lab),seed=42),file.path(root,'evidence/geometry-checks.json'),auto_unbox=TRUE,pretty=TRUE)
 footer(p,7.2)
}
plot97 <- function(root) {
 mag<-read.csv(file.path(root,'results/plot_data/mag_abundance.csv'));arg<-read.csv(file.path(root,'results/plot_data/arg_samples.csv'));tr<-read.tree(file.path(root,'results/plot_data/MAG_tree.nwk'));stopifnot(setequal(tr$tip.label,mag$mag),!anyDuplicated(mag$mag))
 cl<-c('Actinomycetota'='#12A957','Gammaproteobacteria'='#F28E2B','Alphaproteobacteria'='#4E79A7','Acidobacteriota'='#58BDD1','Chloroflexota'='#F12A23','Gemmatimonadota'='#E5A623','Verrucomicrobiota'='#A66A2C','Planctomycetota'='#222222')
 tree<-ggtree(tr,layout='circular',linewidth=.25,colour='#535353') %<+% transmute(mag,label=mag,taxon)
 nodes<-mag %>% filter(taxon %in% names(cl)) %>% group_by(taxon) %>% summarise(node=getMRCA(tr,mag),.groups='drop');labs<-left_join(nodes,select(tree$data,node,x,y,angle),by='node') %>% mutate(x=max(tree$data$x)*1.05,angle=angle-90,angle=ifelse(angle< -90,angle+180,ifelse(angle>90,angle-180,angle)))
 centers<-tree$data %>% filter(isTip) %>% group_by(taxon) %>% summarise(cy=(min(y)+max(y))/2,ca=(min(angle)+max(angle))/2,.groups='drop')
 labs<-left_join(labs,centers,by='taxon');labs$y<-labs$cy;labs$angle<-labs$ca-90;labs$angle<-ifelse(labs$angle< -90,labs$angle+180,ifelse(labs$angle>90,labs$angle-180,labs$angle));labs$x<-max(tree$data$x)*1.09
 labs$label<-recode(labs$taxon,Gammaproteobacteria='γ-Proteobacteria',Alphaproteobacteria='α-Proteobacteria',Gemmatimonadota='Gemmati-\nmonadota',Verrucomicrobiota='Verruco-\nmicrobiota',Planctomycetota='Plancto-\nmycetota')
 depth<-node.depth.edgelength(tr);stopifnot(all(is.finite(depth)),max(abs(tree$data$x-depth[tree$data$node]))<1e-8);tip_range<-range(depth[seq_len(Ntip(tr))]);stopifnot(diff(tip_range)>1)
 radius<-max(tree$data$x);shared_max<-max(mag$control,mag$warming);tips<-tree$data %>% filter(isTip) %>% select(mag=label,y);ring<-left_join(mag,tips,by='mag');stopifnot(!anyNA(ring$y),!anyDuplicated(ring$y))
 ring_c<-transmute(ring,ymin=y-.45,ymax=y+.45,xmin=radius*1.18,xmax=radius*1.18+control/shared_max*radius*.095,track='C abundance')
 ring_w<-transmute(ring,ymin=y-.45,ymax=y+.45,xmin=radius*1.30,xmax=radius*1.30+warming/shared_max*radius*.095,track='W abundance')
 ring_effect<-transmute(ring,ymin=y-.5,ymax=y+.5,xmin=radius*1.42,xmax=radius*1.445,track=effect)
 tracks<-bind_rows(ring_c,ring_w,ring_effect);write.csv(tracks,file.path(root,'results/plot_data/ring_geometry.csv'),row.names=FALSE)
 tree<-tree+geom_point2(aes(subset=!isTip),shape=21,size=.48,stroke=.13,fill='white',colour='#555555')+geom_tippoint(aes(fill=taxon),shape=21,size=1.8,colour='#30343B',stroke=.15)+scale_fill_manual(values=c(cl,Other='white'),guide='none')+
 geom_text(data=labs,aes(x,y,label=label,angle=angle,colour=taxon),inherit.aes=FALSE,family='Arial',size=6.3/pt,lineheight=.88)+scale_colour_manual(values=cl,guide='none')+ggnewscale::new_scale_fill()+
 geom_vline(xintercept=radius*c(1.18,1.30),linewidth=.10,colour='#DDDDDD')+
 geom_rect(data=tracks,aes(xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax,fill=track),inherit.aes=FALSE,colour=NA)+
 scale_fill_manual(values=c('C abundance'='#2A9D98','W abundance'='#9A007A','Simulated increase'='#9A007A','Simulated decrease'='#2A9D98','Neutral'='#E8E8E8'),breaks=c('C abundance','W abundance','Simulated increase','Simulated decrease'),name=NULL,guide=guide_legend(nrow=2))+
 theme_void(base_family='Arial')+theme(legend.position='bottom',legend.text=element_text(size=6.9,family='Arial'),legend.key.size=unit(2.5,'mm'),plot.margin=margin(0,0,0,0))
 arg$treatment<-factor(arg$treatment,c('C','W'));summ<-arg%>%group_by(taxon,treatment)%>%summarise(mean=mean(arg_count),se=sd(arg_count)/sqrt(n()),n=n(),.groups='drop');write.csv(summ,file.path(root,'results/plot_data/arg_summary.csv'),row.names=FALSE)
 side<-function(groups){a<-arg%>%filter(taxon%in%groups)%>%mutate(taxon=factor(taxon,groups));s<-summ%>%filter(taxon%in%groups)%>%mutate(taxon=factor(taxon,groups))
 ggplot(a,aes(treatment,arg_count))+geom_col(data=s,aes(treatment,mean,fill=treatment),inherit.aes=FALSE,width=.55,colour='#30343B',linewidth=.25,alpha=.65)+geom_errorbar(data=s,aes(treatment,ymin=mean-se,ymax=mean+se),inherit.aes=FALSE,width=.18,linewidth=.25)+geom_point(aes(fill=treatment),shape=21,colour='#30343B',stroke=.13,size=1,alpha=.55,position=position_jitter(width=.13,height=0,seed=97))+facet_wrap(~taxon,ncol=1,scales='free_y',axes='all',axis.labels='all',labeller=as_labeller(c('Gammaproteobacteria'='γ-Proteobacteria','Alphaproteobacteria'='α-Proteobacteria',setNames(groups,groups))))+scale_fill_manual(values=c(C='#62B8B5',W='#B05AA3'))+scale_y_continuous(expand=expansion(mult=c(0,.12)),breaks=scales::breaks_pretty(n=3))+labs(x=NULL,y='ARG count')+plain()+theme(legend.position='none',strip.text=element_text(size=6.5,face='bold',family='Arial'),strip.background=element_blank(),panel.spacing=unit(4,'mm'),axis.text=element_text(size=6),plot.margin=margin(1,2,1,3,'mm'))}
 left<-side(c('Actinomycetota','Chloroflexota','Gemmatimonadota','Planctomycetota'));right<-side(c('Gammaproteobacteria','Alphaproteobacteria','Acidobacteriota','Verrucomicrobiota'))
 p<-plot_grid(left,tree,right,nrow=1,rel_widths=c(.19,.62,.19))
 write_json(list(status='PASS',tree_tips=Ntip(tr),edge_lengths_all_finite=TRUE,tip_radius_range=tip_range,maximum_branch_position_error=max(abs(tree$data$x-depth[tree$data$node])),shared_abundance_max=shared_max,abundance_track_width_fraction=.095,effect_band_width_fraction=.025,branch_linewidth_mm=.25,tip_size_mm=1.8,tip_annotation_bijection=TRUE,tracks=3,side_panels=8,synthetic_samples=nrow(arg),samples_per_group=12,summary='mean plus/minus SE, descriptive only; no hypothesis test'),file.path(root,'evidence/geometry-checks.json'),auto_unbox=TRUE,pretty=TRUE);footer(p)
}
plot98 <- function(root) {
 labs<-c('negative_divergingNeg'='Negative impact, diverges','negative_noChange'='Negative impact, stable','negative_resilNeg'='Negative impact, resilient','robust_divergingNeg'='Resistant, negative divergence','robust_resilNeg'='Resistant, negative resilience','robust_noChange'='Resistant, stable','robust_resilPos'='Resistant, positive resilience','robust_divergingPos'='Resistant, positive divergence','positive_resilPos'='Positive impact, resilient','positive_noChange'='Positive impact, stable','positive_divergingPos'='Positive impact, diverges','Model not converging'='Model not converging')
 palette<-setNames(c(rev(RColorBrewer::brewer.pal(11,'PuOr')),'grey85'),unname(labs));counts<-list()
 one<-function(fungi=FALSE){d<-read.csv(file.path(root,'results/plot_data',if(fungi)'fungi.csv' else 'prokaryotes.csv'));fields<-if(fungi)c('Kingdom','Phylum','Class','Order','Family','Genus','Species') else c('domain','phylum','class','order','family','genus');ph<-if(fungi)'Phylum' else 'phylum';d[fields]<-lapply(d[fields],factor);d$label<-factor(d$label,levels=d$label);d$phy<-as.character(d[[ph]])
 tr<-as.phylo(as.formula(paste('~',paste(c(fields,'label'),collapse='/'))),data=d,collapse=FALSE);tr$edge.length<-rep(1,nrow(tr$edge));tr$root.edge<-1
 stopifnot(Ntip(tr)==500,setequal(tr$tip.label,as.character(d$label)),all(tr$edge.length==1));long<-d%>%select(label,D,Fd,Fz,H)%>%pivot_longer(D:H,names_to='treatment',values_to='strategy');stopifnot(all(long$strategy%in%names(labs)),nrow(long)==2000);long$strategy<-factor(unname(labs[long$strategy]),levels=unname(labs));long$treatment<-factor(long$treatment,c('D','Fd','Fz','H'))
 cols<-setNames(hcl.colors(length(unique(d$phy)),'Dark 3'),sort(unique(d$phy)))
 p<-ggtree(tr,layout='radial',aes(colour=phy,alpha=sumCounts_asv),linewidth=.17) %<+% d
 wanted<-if(fungi)c('Ascomycota','Basidiomycota','Mortierellomycota') else c('Proteobacteria','Actinobacteria','Acidobacteria','Firmicutes','Verrucomicrobia')
 nodes<-d%>%filter(phy%in%wanted)%>%group_by(phy)%>%summarise(node=getMRCA(tr,as.character(label)),.groups='drop');text<-left_join(nodes,p$data,by='node');text$x<-max(p$data$x)*.77;text$angle<-text$angle-90;text$angle<-ifelse(text$angle< -90,text$angle+180,ifelse(text$angle>90,text$angle-180,text$angle))
 p<-p+geom_text(data=text,aes(x,y,label=phy.x,angle=angle),inherit.aes=FALSE,family='Arial',size=6/pt,colour='#30343B')+scale_colour_manual(values=cols,na.value='#C9C9C9',guide='none')+scale_alpha_continuous(range=c(.45,1),transform='log10',na.value=.45,guide='none')+
 geom_fruit(data=long,geom=geom_tile,aes(y=label,x=treatment,fill=strategy),offset=.035,pwidth=.25,width=.92,axis.params=list(axis='x',text.size=6/pt,hjust=.5,text.angle=90))+scale_fill_manual(values=palette,drop=FALSE,name='Ecological response strategy',guide=guide_legend(nrow=3,byrow=TRUE,title.position='top',title.hjust=0))+
 theme_void(base_family='Arial')+theme(legend.position='bottom',legend.text=element_text(size=6,family='Arial'),legend.title=element_text(size=7,face='bold',family='Arial'),legend.key.width=unit(3,'mm'),legend.key.height=unit(2.5,'mm'),legend.spacing.x=unit(.5,'mm'),legend.margin=margin(0,0,0,0),plot.margin=margin(0,0,0,0))
 counts[[if(fungi)'fungi' else 'prokaryotes']]<<-list(tips=500,cells=nrow(long),equal_branch_lengths=TRUE,tip_annotation_bijection=TRUE)
 p}
 a<-one();b<-one(TRUE);legend<-get_legend(a)
 top<-plot_grid(a+theme(legend.position='none'),b+theme(legend.position='none'),nrow=1)
 top<-ggdraw(top)+draw_label('Prokaryotes',.25,.98,size=7,fontfamily='Arial')+draw_label('Fungi',.75,.98,size=7,fontfamily='Arial')
 p<-plot_grid(top,legend,ncol=1,rel_heights=c(.80,.20));write_json(list(status='PASS',taxa=counts,treatment_order=c('D','Fd','Fz','H'),strategy_categories=length(palette),interpretation='taxonomy, not evolutionary branch distance'),file.path(root,'evidence/geometry-checks.json'),auto_unbox=TRUE,pretty=TRUE);footer(p)
}
render_case <- function(root,work,authorization,script) {
 skill<-normalizePath(Sys.getenv('BIOFIGURE_ROOT'));source(file.path(skill,'scripts/figure_style.R'));font<-bf_font('Arial');spec<-file.path(root,'data/metadata/design-spec.yaml');design<-read_yaml(spec);i<-as.integer(sub('issue_','',basename(root)))
 measure<-file.path(work,'build-device.png');ragg::agg_png(measure,width=design$output_size$width_mm,height=design$output_size$height_mm,units='mm',res=400);p<-switch(as.character(i),'86'=plot86(root),'89'=plot89(root),'97'=plot97(root),'98'=plot98(root));invisible(dev.off());unlink(measure);width<-design$output_size$width_mm;height<-design$output_size$height_mm
 input_names<-switch(as.character(i),'86'='pathways.csv','89'='genes.csv','97'=c('MAG_tree.nwk','arg_samples.csv','mag_abundance.csv'),'98'=c('fungi.csv','prokaryotes.csv'))
 sources<-c(spec,script,file.path(skill,'scripts/figure_style.R'),file.path(dirname(root),'scripts/render_simulation_common.R'),file.path(root,'results/plot_data',input_names))
 if(i==86)sources<-c(sources,file.path(root,'data/metadata/node_colors.json'))
 legend_box<-switch(as.character(i),'86'=c(.85,.25,.15,.55),'89'=c(.79,.30,.21,.45),'97'=c(.30,.81,.40,.12),'98'=c(.10,.79,.80,.17))
 boxes<-data.frame(id=c('data','labels','legend'),x=c(0,0,width*legend_box[1]),y=c(0,0,height*legend_box[2]),w=c(width,width,width*legend_box[3]),h=c(height*.965,height,height*legend_box[4]))
 # Conservative group envelopes overlap by design: labels occur throughout the data.
 # This gate verifies canvas containment only; it is NOT automatic collision evidence.
 # Actual text/legend collision review is recorded separately in visual-review.json.

 out<-file.path(root,'evidence/reproduction.png')
 bf_render_png(p,out,font,design$text_contract$allowed_text,width,height,width,sources,boxes,allowed_pairs=c('data:labels','data:legend','labels:legend'),authorization=authorization,skill_root=skill,publication_size_class='double-column',dpi=400,min_text_pt=design$font_contract$minimum_final_text_pt)
 quartz(type='pdf',file=file.path(root,'results/figures/reproduction.pdf'),width=width/25.4,height=height/25.4,family='Arial');print(p);invisible(dev.off())
 ggsave(file.path(work,'reproduction.svg'),p,device=svglite::svglite,width=width,height=height,units='mm',bg='white')
 capture.output(sessionInfo(),file=file.path(root,'evidence/sessionInfo.txt'));if(!is.null(warnings()))print(warnings());cat('RENDER_OK',i,'\n')
}
