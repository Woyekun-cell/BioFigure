args<-commandArgs(TRUE);P<-normalizePath(args[1]);W<-file.path(P,'work/2026-10-29-omics-four')
suppressPackageStartupMessages({library(ggplot2);library(patchwork);library(ggrepel);library(ggforce);library(grid)})
loc<-jsonlite::fromJSON(file.path(W,'source-locators.json'),simplifyVector=FALSE);seed<-20261029;set.seed(seed)
base<-theme_classic(base_size=7,base_family='Arial')+theme(text=element_text(family='Arial',size=7,colour='#30343B'),axis.text=element_text(size=7,colour='#30343B'),axis.title=element_text(size=7),strip.text=element_text(size=7),legend.text=element_text(size=7),legend.title=element_text(size=7),legend.ticks=element_blank(),plot.tag=element_text(size=9,face='bold'),plot.margin=margin(3,3,3,3),legend.key.height=unit(3,'mm'),legend.key.width=unit(3.5,'mm'),axis.line=element_line(colour='#737B84',linewidth=.25),axis.ticks=element_line(colour='#737B84',linewidth=.25))
savecase<-function(key,p,dat,extra,width,height,family,task,origin,palette,obs,numeric,extra_labels=character()){
 w<-file.path(W,key);dir.create(w,recursive=TRUE,showWarnings=FALSE);stem<-paste0('omics4_',tolower(key),'_simulated_recolored_20261029')
 files<-c(paste0(stem,'.csv'),paste0(stem,'_',names(extra),'.csv'));write.csv(dat,file.path(P,'results/plot_data',files[1]),row.names=FALSE)
 for(i in seq_along(extra))write.csv(extra[[i]],file.path(P,'results/plot_data',files[i+1]),row.names=FALSE)
 q<-list(stem=stem,seed=seed,origin='synthetic',width_mm=width,height_mm=height,figure_family=family,figure_task=task,plot_data_files=files,source=loc[[key]],data_origin=origin,palette=as.list(palette),observations=obs,numeric=numeric,extra_labels=extra_labels)
 jsonlite::write_json(q,file.path(w,'input-qc.json'),auto_unbox=TRUE,pretty=TRUE);saveRDS(p,file.path(w,'plot.rds'))
 ragg::agg_png(file.path(w,'layout-preflight.png'),width=width,height=height,units='mm',res=180,background='white');print(p);dev.off()
 capture.output(sessionInfo(),file=file.path(w,'preparation-sessionInfo.txt'));cat(key,'prepared;whole-layout review pending\n')
}
tagstyle<-theme(plot.tag=element_text(family='Arial',size=9,face='bold'))

# Two layers share the same explicit48module IDs; no source P-value or hard-coded n.
mods<-sprintf('M%02d',1:48);comm<-rep(paste0('C',1:6),times=c(7,9,11,6,8,7));terms<-sprintf('Set %02d',1:12);genes<-sprintf('SIM_G%04d',1:1800)
gene_terms<-data.frame(gene=genes,term=rep(terms,each=150))
gx<-sample(genes,450);extra_terms<-vapply(gx,function(g)sample(setdiff(terms,gene_terms$term[match(g,gene_terms$gene)]),1),character(1));gene_terms<-rbind(gene_terms,data.frame(gene=gx,term=extra_terms))
members<-do.call(rbind,lapply(1:48,function(i){c<-as.integer(sub('C','',comm[i]));favterms<-terms[c(2*c-1,2*c,(2*c+2)%%12+1)];fav<-unique(gene_terms$gene[gene_terms$term%in%favterms]);ng<-sample(60:130,1);ncore<-round(ng*runif(1,.55,.85));g<-unique(c(sample(fav,ncore),sample(setdiff(genes,fav),ng-ncore)));data.frame(module=mods[i],community=comm[i],gene=g)}))
ann<-do.call(rbind,lapply(1:48,function(i)do.call(rbind,lapply(terms,function(t){g<-members$gene[members$module==mods[i]];ct<-length(intersect(g,gene_terms$gene[gene_terms$term==t]));data.frame(module=mods[i],community=comm[i],set=t,count=ct,total=length(g),fraction=ct/length(g))}))))
tissues<-c('Caryopsis','Inflorescence','Shoot','Root','Embryonic');meta<-data.frame(sample=sprintf('S%02d',1:50),tissue=rep(tissues,each=10))
baseweights<-rbind(c(1.8,.1,.2,-.2,1.1),c(-.2,1.8,1.0,.1,.1),c(.1,-.1,1.2,1.6,.1),c(-.1,.6,2.1,.4,0),c(.2,1.0,-.1,.1,1.8),c(1.4,0,.3,1.8,-.1))
profiles<-do.call(rbind,lapply(1:48,function(i){c<-as.integer(sub('C','',comm[i]));w<-baseweights[c,]+rnorm(5,sd=.35);v<-w[match(meta$tissue,tissues)]+rnorm(50,sd=.9);data.frame(module=mods[i],community=comm[i],sample=meta$sample,tissue=meta$tissue,value=v)}))
corrows<-do.call(rbind,lapply(1:48,function(i)do.call(rbind,lapply(tissues,function(t){v<-profiles[profiles$module==mods[i],];r<-cor(v$value,as.integer(v$tissue==t));data.frame(module=mods[i],community=comm[i],tissue=t,r=r,abs_r=abs(r),n=50)}))))
ann$module<-factor(ann$module,levels=mods);ann$set<-factor(ann$set,levels=rev(terms));corrows$module<-factor(corrows$module,levels=mods);corrows$tissue<-factor(corrows$tissue,levels=rev(tissues))
bp1<-ggplot(subset(ann,count>=5),aes(module,set))+geom_point(aes(size=count,colour=fraction))+
 facet_grid(~community,scales='free_x',space='free_x')+scale_size_area(max_size=2.3,breaks=c(5,20,40),name='Gene count')+
 scale_colour_gradient(low='#D5E9DE',high='#247B67',limits=c(0,.6),name='Fraction',guide=guide_colourbar(barheight=unit(15,'mm'),barwidth=unit(2.2,'mm'),display='gradient'))+
 labs(x=NULL,y=NULL)+base+theme(axis.text.x=element_blank(),axis.ticks=element_blank(),panel.grid.major=element_line(colour='#E2E5E9',linewidth=.15),panel.border=element_rect(fill=NA,colour='#ADB3BB',linewidth=.22),strip.background=element_blank(),panel.spacing.x=unit(1,'mm'))
bp2<-ggplot(corrows,aes(module,tissue))+geom_point(aes(size=abs_r,colour=r))+
 facet_grid(~community,scales='free_x',space='free_x')+scale_size_area(max_size=2.3,breaks=c(.2,.5,.8),name='|r|')+
 scale_colour_gradient2(low='#667EAE',mid='#F5F4F1',high='#BB7A61',limits=c(-1,1),name='Pearson r',guide=guide_colourbar(barheight=unit(15,'mm'),barwidth=unit(2.2,'mm'),display='gradient'))+
 labs(x='Module',y=NULL)+base+theme(axis.text.x=element_text(angle=90,hjust=1,vjust=.5),axis.ticks=element_blank(),strip.text=element_blank(),panel.grid.major=element_line(colour='#E2E5E9',linewidth=.15),panel.border=element_rect(fill=NA,colour='#ADB3BB',linewidth=.22),strip.background=element_blank(),panel.spacing.x=unit(1,'mm'))
pb<-(bp1/bp2)+plot_layout(heights=c(12,5),guides='keep')+plot_annotation(tag_levels='a',theme=tagstyle)
savecase('BUBBLE',pb,members,list(gene_sets=gene_terms,annotation_counts=ann,sample_profiles=profiles,tissue_correlations=corrows),183,135,'multipanel','two-layer-functional-tissue-dot-matrix',
 '固定种子模拟48个大小不等模块、1800个虚拟基因的12个可重叠集合、50个人工样本/5组织标签。六社区列数7/9/11/6/8/7。上层按唯一基因成员计数/比例，显示count>=5，不称为富集P值。下层Pearson r从同一模块的50个多组织贡献模拟profile重算，点径|r|，不采用原代码硬编码544或P值误标。仅复现Fig3c双层布局，非原文数值。',
 c(annotation_low='#D5E9DE',annotation_high='#247B67',correlation_low='#667EAE',correlation_mid='#F5F4F1',correlation_high='#BB7A61'),
 list(hierarchy='Twelve annotation rows above five tissue-correlation rows,shared48module columns grouped into six communities.',geometry='Two aligned native dot matrices with identical module keys and community widths proportional to7/9/11/6/8/7 columns;separate right guides.',palette='Green annotation-fraction gradient and blue/neutral/coral correlation gradient; color and dot size have distinct named meanings.',typography='7pt Arial labels and9pt panel tags at183x135mm; module IDs rotate once below the lower matrix.',marks='Annotation dot area maps actual simulated counts with overlapping functional memberships;lower area maps absolute recomputed correlation; no source P-values.',annotation='Only collection/module/tissue IDs and quantitative keys. Source enrichment and inferential claims are excluded.'),list(modules=48,communities=6,genes=1800,memberships=nrow(members),annotation_rows=nrow(ann),profiles=nrow(profiles),correlations=nrow(corrows),samples_per_module=50))

# Barley ED4 TFBS composition explicitly cancelled by user;generator removed.

# Three regions use the samepaired-site contract; change summaries are descriptive.
set.seed(seed)
cats<-LETTERS[1:7];regionsv<-paste('Region',1:3);cvs<-setNames(c('#4D948E','#89B8AE','#6B7FA6','#A4B6D0','#AA7997','#D5B2C5','#B59664'),cats)
delta<-rbind(c(.12,-.05,.08,.16,-.04,.09,.03),c(-.02,.14,-.08,.07,.11,-.04,.15),c(.06,.02,.18,-.07,.10,.04,-.06))
vd<-do.call(rbind,lapply(1:3,function(r)do.call(rbind,lapply(1:7,function(k){v<-rnorm(120,c(.25,.32,.15,.20,.12,.18,.30)[k]+.04*(r-2),c(.18,.26,.28,.16,.20,.14,.24)[k]);v2<-v+delta[r,k]+rnorm(120,sd=c(.10,.15,.23,.10,.20,.10,.15)[k]);rbind(data.frame(region=regionsv[r],feature=cats[k],site=sprintf('S%03d',1:120),period='Period 1',response=v),data.frame(region=regionsv[r],feature=cats[k],site=sprintf('S%03d',1:120),period='Period 2',response=v2))}))))
vd$feature<-factor(vd$feature,levels=cats);vd$period<-factor(vd$period,levels=c('Period 1','Period 2'));vd$region<-factor(vd$region,levels=regionsv)
x1<-subset(vd,period=='Period 1');x2<-subset(vd,period=='Period 2');chg<-merge(x1,x2,by=c('region','feature','site'),suffixes=c('_p1','_p2'));chg$change<-chg$response_p2-chg$response_p1
vs<-aggregate(change~region+feature,chg,function(v)c(n=length(v),median=median(v),q25=unname(quantile(v,.25)),q75=unname(quantile(v,.75))));vs<-data.frame(vs[,1:2],vs$change)
pv1<-ggplot(vd,aes(feature,response*100,fill=feature,linetype=period,alpha=period))+
 geom_violin(position=position_dodge(width=0),scale='width',width=.82,adjust=1.3,trim=FALSE,quantiles=.5,quantile.linetype='solid',quantile.linewidth=.25,colour='#363B43',linewidth=.32)+
 geom_hline(yintercept=0,linetype='dotdash',colour='#A26959',linewidth=.25)+facet_wrap(~region,nrow=1)+scale_fill_manual(values=cvs,guide='none')+
 scale_linetype_manual(values=c('solid','22'),name='Period')+scale_alpha_manual(values=c(.95,.27),name='Period')+
 labs(x='Feature',y='Relative response (%)')+base+theme(legend.position='top',axis.ticks.x=element_blank(),strip.background=element_rect(fill='#F6F5F7',colour='#B4B9C1',linewidth=.2),strip.text=element_text(face='bold'),panel.spacing.x=unit(3,'mm'))
vs$feature_rev<-factor(vs$feature,levels=rev(cats))
pv2<-ggplot(vs,aes(median*100,feature_rev,colour=feature))+
 geom_vline(xintercept=0,linetype='dotted',colour='#8E969F',linewidth=.3)+geom_linerange(aes(xmin=q25*100,xmax=q75*100),orientation='y',linewidth=.65)+
 geom_point(shape=21,fill='white',size=1.8,stroke=.5)+facet_wrap(~region,nrow=1)+scale_colour_manual(values=cvs,guide='none')+
 labs(x='Paired change: median and IQR (pp)',y='Feature')+base+theme(strip.background=element_blank(),strip.text=element_blank(),axis.ticks.y=element_blank(),panel.grid.major.x=element_line(colour='#E6E9ED',linewidth=.2),panel.spacing.x=unit(3,'mm'))
pv<-pv1/pv2+plot_layout(heights=c(1.2,1))+plot_annotation(tag_levels='a',theme=tagstyle)
savecase('VIOLIN',pv,vd,list(paired_changes=chg,summaries=vs),183,149,'multipanel','regional-overlaid-violins-and-paired-change-summary',
 '固定种子模拟3区域×7特征×120配对站点×2时期，共5040条相对响应。两期按region/feature/site连接为2520个变化量。下层点和线为这些变化量的中位数及25/75百分位，图示单位为百分点pp，不是置信区间；不执行假设检验。相对响应可负或超过100%，不是组成比例。由原图单区域叠加结构扩展为三区域及同数据摘要，非原天气研究结果。',
 cvs,list(hierarchy='Three regional comparisons of seven overlaid two-period violins above three aligned panels of paired-change summaries.',geometry='A six-panel composition with shared regional columns,explicit paired-site joins and common scales within each row.',palette='Named teal,slate,mauve and sand feature colors repeat across distributions and change summaries;period uses outline style and opacity.',typography='7pt Arial feature/axis/key text with9pt panel tags at183x149mm;compact A-G feature IDs keep dense facets readable.',marks='Native violin medians;lower points are paired-change medians and horizontal intervals are empiricalIQR,not inferred confidence intervals.',annotation='Only regional/feature IDs,period key and response/change axes;no significance,probability or real weather-study conclusions.'),list(rows=nrow(vd),features=7,regions=3,paired_sites_per_region=120,paired_changes=nrow(chg),periods=2,summary_rows=nrow(vs)))

# Simulated feature summaries provide a coherent volcano,without running real GSEA.
set.seed(seed)
n<-1600;eff<-c(rnorm(1500,0,.15),rnorm(50,1.05,.23),rnorm(50,-1.05,.23));se<-runif(n,.09,.22);z<-eff/se
pv0<-pmax(1e-300,2*pnorm(-abs(z)));fdr<-p.adjust(pv0,'BH')
dd<-data.frame(feature_id=sprintf('F%04d',1:n),effect=eff,se=se,z=z,p=pv0,q=fdr)
dd$class<-ifelse(dd$q<.05&dd$effect>.5,'Positive',ifelse(dd$q<.05&dd$effect< -.5,'Negative','Other'));dd$label<-''
ix<-c(head(order(dd$effect,decreasing=TRUE),3),head(order(dd$effect),3));dd$label[ix]<-dd$feature_id[ix]
vcols<-c(Positive='#BE766C',Negative='#3F8D92',Other='#CCD0D5')
vp<-ggplot(dd,aes(effect,-log10(q)))+geom_vline(xintercept=c(-.5,.5),linetype='dotted',colour='#A5AAB2',linewidth=.25)+
 geom_hline(yintercept=-log10(.05),linetype='dotted',colour='#A5AAB2',linewidth=.25)+geom_point(aes(colour=class),size=.65,alpha=.8)+
 geom_text_repel(data=dd[ix,],aes(label=label),family='Arial',size=7/.pt,seed=seed,direction='y',max.overlaps=Inf,box.padding=.25,point.padding=.2,min.segment.length=0,segment.size=.2)+
 scale_colour_manual(values=vcols,guide='none')+labs(x='Estimated difference',y='-log10(q)')+base
groups<-paste('Module',LETTERS[1:6]);nterms<-c(14,11,18,10,16,12);cent<-data.frame(group=groups,x=c(-1.6,-.15,1.5,-1.4,.2,1.65),y=c(.85,1.25,.75,-.8,-.4,-.95))
termsn<-sprintf('T%02d',seq_len(sum(nterms)));tgroup<-rep(groups,times=nterms);node<-data.frame(term=termsn,group=tgroup)
tm<-do.call(rbind,lapply(seq_along(termsn),function(i){k<-match(tgroup[i],groups);pool<-switch(as.character(k),'1'=1501:1530,'2'=1531:1550,'3'=1551:1580,'4'=1581:1600,'5'=1:250,'6'=251:500);bridge<-c(((k-2)%%6)*4+1:4,(k-1)*4+1:4);data.frame(term=termsn[i],feature_id=unique(c(sample(pool,min(sample(12:28,1),length(pool))),sample(1:1600,sample(7:20,1)),bridge)) )}))
tm$feature_id<-dd$feature_id[as.integer(tm$feature_id)];node$score<-vapply(termsn,function(t)mean(dd$effect[match(tm$feature_id[tm$term==t],dd$feature_id)]),numeric(1))
node$gene_count<-vapply(termsn,function(t)sum(tm$term==t),integer(1));node$x<-node$y<-NA_real_
edge<-do.call(rbind,lapply(1:(length(termsn)-1),function(i)do.call(rbind,lapply((i+1):length(termsn),function(j){a<-tm$feature_id[tm$term==termsn[i]];b<-tm$feature_id[tm$term==termsn[j]];s<-length(intersect(a,b))/length(union(a,b));if(s>=.15)data.frame(from=termsn[i],to=termsn[j],jaccard=s)else NULL}))))
for(k in 1:6){ix<-which(node$group==groups[k]);ee<-subset(edge,from%in%node$term[ix]&to%in%node$term[ix]);gr<-igraph::graph_from_data_frame(ee[,c('from','to')],directed=FALSE,vertices=data.frame(name=node$term[ix]));xy<-igraph::layout_with_fr(gr,niter=500);xy<-scale(xy,center=TRUE,scale=FALSE);xy<-xy/max(sqrt(rowSums(xy^2)));rad<-.45+.015*nterms[k];node$x[ix]<-cent$x[k]+xy[,1]*rad;node$y[ix]<-cent$y[k]+xy[,2]*rad*.78}
edge$x<-node$x[match(edge$from,node$term)];edge$y<-node$y[match(edge$from,node$term)];edge$xend<-node$x[match(edge$to,node$term)];edge$yend<-node$y[match(edge$to,node$term)]
 np<-ggplot()+geom_segment(data=edge,aes(x,y,xend=xend,yend=yend),colour='#A0A6AE',alpha=.14,linewidth=.12)+
 geom_mark_ellipse(data=node,aes(x,y,group=group),fill=NA,colour='#B5BBC3',linewidth=.24,expand=unit(1.3,'mm'))+
 geom_point(data=node,aes(x,y,fill=score,size=gene_count),shape=21,colour='#626D78',stroke=.16)+
 geom_label(data=transform(cent,y=y+.72),aes(x,y,label=group),size=7/.pt,family='Arial',fill='white',linewidth=0,label.padding=unit(.4,'mm'))+
 scale_size_area(max_size=2.8,breaks=c(20,40,60),name='Genes per set')+
 scale_fill_gradient2(low='#3F8D92',mid='#F4F3F0',high='#BE766C',limits=c(-1.1,1.1),name='Mean difference',guide=guide_colourbar(barheight=unit(2.4,'mm'),barwidth=unit(24,'mm'),display='gradient'))+
 coord_equal(xlim=c(-2.4,2.4),ylim=c(-1.75,2.2))+theme_void(base_family='Arial',base_size=7)+theme(legend.position='bottom',legend.title=element_text(size=7),legend.text=element_text(size=7),legend.ticks=element_blank(),plot.margin=margin(3,3,3,3))
pvol<-vp+np+plot_layout(widths=c(1,1.65))+plot_annotation(tag_levels='a',theme=tagstyle)
savecase('VOLCANO',pvol,dd,list(term_memberships=tm,nodes=node,edges=edge),183,121,'multipanel','volcano-and-module-membership-network',
 '固定种子生成1600条模拟效应/标准误摘要，P按已声明正态摘要模型计算，q为1600条BH转换，仅用于流程测试，不是真实差异分析。81个虚拟term分成14/11/18/10/16/12节点的6模块。边由成员Jaccard>=.15产生，节点面积为集合大小、颜色为同一feature平均效应；社区内位置由实际子图力导向计算。未执行原图GSEA/EnrichmentMap，没有实际通路结论。',
 vcols,list(hierarchy='A volcano summary at left and a larger grouped term network at right retain the source two-panel reading order.',geometry='Six unequal communities have irregular input-derived force layouts and visible envelopes;all edges derive from shared feature membership.',palette='Coral/teal distinguish positive/negative summary effects;the network has a matching diverging mean-effect colorbar and muted grey edges.',typography='7pt Arial axes,feature/module labels and keys with9pt panel tags at183x121mm;white label backing keeps network edges clear of group names.',marks='Native ggplot/ggrepel points,area-scaled term nodes,community envelopes and computed Jaccard edges;no claimed real GSEA run.',annotation='Only feature/module IDs,summary axes and quantitative keys;source disease context and pathway conclusions omitted.'),list(features=n,nodes=nrow(node),modules=6,edges=nrow(edge),term_memberships=nrow(tm),highlight_labels=6),dd$label[which(nzchar(dd$label))])
