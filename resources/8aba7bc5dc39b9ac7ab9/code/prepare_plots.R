args<-commandArgs(TRUE);P<-normalizePath(args[1]);W<-file.path(P,'work/2026-10-29-next-four')
suppressPackageStartupMessages({library(ggplot2);library(ggridges);library(patchwork);library(ggrepel);library(ggnewscale);library(grid)})
loc<-jsonlite::fromJSON(file.path(W,'source-locators.json'),simplifyVector=FALSE)
seed<-20261029;set.seed(seed)
base<-theme_classic(base_size=7,base_family='Arial')+theme(text=element_text(size=7,family='Arial',colour='#30343B'),
 axis.text=element_text(size=7,colour='#30343B'),axis.title=element_text(size=7),strip.text=element_text(size=7,face='bold'),
 legend.text=element_text(size=7),legend.title=element_text(size=7),plot.tag=element_text(size=9,face='bold'),
 axis.line=element_line(linewidth=.25,colour='#747B83'),axis.ticks=element_line(linewidth=.25,colour='#747B83'),
 plot.margin=margin(3,3,3,3),legend.key.height=unit(3.5,'mm'),legend.key.width=unit(3.5,'mm'))
save_case<-function(mid,p,dat,extra,width,height,family,task,origin,colors,observations,numeric,extra_labels=character()){
 w<-file.path(W,mid);dir.create(w,recursive=TRUE,showWarnings=FALSE)
 stem<-paste0('next4_',tolower(gsub('-','',mid)),'_simulated_recolored_20261029')
 files<-c(paste0(stem,'.csv'),paste0(stem,'_',names(extra),'.csv'))
 write.csv(dat,file.path(P,'results/plot_data',files[1]),row.names=FALSE)
 for(i in seq_along(extra))write.csv(extra[[i]],file.path(P,'results/plot_data',files[i+1]),row.names=FALSE)
 q<-list(stem=stem,seed=seed,origin='synthetic',width_mm=width,height_mm=height,figure_family=family,figure_task=task,
 plot_data_files=files,source=loc[[mid]],data_origin=origin,palette=as.list(colors),observations=observations,numeric=numeric,extra_labels=extra_labels)
 jsonlite::write_json(q,file.path(w,'input-qc.json'),auto_unbox=TRUE,pretty=TRUE)
 saveRDS(p,file.path(w,'plot.rds'))
 ragg::agg_png(file.path(w,'layout-preflight.png'),width=width,height=height,units='mm',res=180,background='white');print(p);dev.off()
 capture.output(sessionInfo(),file=file.path(w,'preparation-sessionInfo.txt'))
 cat(mid,'prepared;layout preview pending review\n')
}

# 146: preserve three stacked panels and ordered ridge gradients; no invented stars.
times<-c('0 ns','8 ns','12 ns','16 ns','20 ns','24 ns')
mus<-list(c(2.8,3.55,4.15,4.5,4.85,4.9),c(4.7,7.3,9.7,11.2,12.4,12.55),c(-1,2,5,8,11,12))
sds<-list(rep(.15,6),rep(.35,6),rep(1.5,6))
metrics<-c('Core RMSD (Å)','A-loop RMSD (Å)','Displacement (Å)')
cols146<-list(setNames(grDevices::colorRampPalette(c('#E2AD95','#853C50'))(6),times),
 setNames(grDevices::colorRampPalette(c('#D8C18F','#74602E'))(6),times),
 setNames(grDevices::colorRampPalette(c('#9FCED0','#285C7B'))(6),times))
d146<-do.call(rbind,lapply(1:3,function(m)do.call(rbind,lapply(1:6,function(t)data.frame(metric=metrics[m],time=times[t],
 frame_id=sprintf('FRAME_%03d',1:180),value=rnorm(180,mus[[m]][t],sds[[m]][t]))))))
stopifnot(!anyNA(d146),all(d146$value[d146$metric!=metrics[3]]>0))
ps<-lapply(1:3,function(m){d<-d146[d146$metric==metrics[m],];d$time<-factor(d$time,levels=rev(times));
 ggplot(d,aes(value,time,fill=time,colour=time))+geom_density_ridges(scale=1.08,rel_min_height=0,linewidth=.3)+
 scale_fill_manual(values=cols146[[m]],guide='none')+scale_colour_manual(values=cols146[[m]],guide='none')+
 scale_y_discrete(expand=expansion(add=c(.1,.95)))+labs(x=metrics[m],y=NULL)+base+
 theme(axis.line.y=element_blank(),axis.ticks.y=element_blank(),panel.grid=element_blank(),plot.margin=margin(3,3,2,3))})
p146<-wrap_plots(ps,ncol=1)+plot_annotation(tag_levels='a')
sum146<-aggregate(value~metric+time,d146,function(x)c(n=length(x),mean=mean(x),median=median(x),sd=sd(x)))
sum146<-data.frame(sum146[,1:2],sum146$value)
save_case('SCICASE-146',p146,d146,list(summaries=sum146),136,158,'multipanel','three-panel-temporal-ridges',
 '固定种子20261029生成三指标×六时间窗×180个模拟帧，共3240行。帧不作为独立生物重复；不执行推断检验，不复制原图星号。第三指标明确设为有符号位移，避免将负值解释为物理距离。非原轨迹或原论文数值。',
 unlist(lapply(1:3,function(i)setNames(cols146[[i]],paste0('metric',i,'_',times)))),
 list(hierarchy='Three vertically aligned metrics, each with six chronological density ridges; metric names sit below each panel.',
 geometry='Native ggridges density estimates share the ordered time rows within each panel; three panels have separate numeric axes and generous panel gaps.',
 palette='Three new light-to-dark time gradients:coral/burgundy,gold/olive and cyan/navy. Each time retains its named color within its metric.',
 typography='7pt Arial axes/time labels and9pt panel tags at136x158mm; no large source-style negative text margins.',
 marks='Smooth native density polygons with thin colored baselines; six explicit time labels. Unsupported source significance brackets are omitted.',
 annotation='Only metric units,time labels,ticks and panel tags; no source study conclusions,simulation prose or generation footer.'),
 list(rows=nrow(d146),metrics=3,time_windows=6,frames_per_window=180,inference_performed=FALSE))

# 147: the pooled row uses the same cells, not an independently generated population.
markers<-c('CD161','NKG2A','CD31','CD8','CD57','CD28');clusters<-paste0('c',1:8)
mu147<-matrix(c(3.9,3.3,3.6,1.1,2.8,2.1,2.3,2.5, 4.1,2.5,1.1,3.7,2.2,1.4,1.8,1.9,
 3.1,2.7,2.2,3.3,4.2,4.5,3.1,3.8, 2.9,3.2,3.1,3.4,2.8,3.4,4.4,4.8,
 4.9,3.4,3.5,1.8,1.7,1.6,3.2,3.6, 4.8,1.9,2.6,2.7,3.6,4.2,3.8,3.6),nrow=8)
d147<-do.call(rbind,lapply(seq_along(markers),function(j)do.call(rbind,lapply(1:8,function(k){
 n<-100;noise<-rnorm(n,0,.40+.06*((k+j)%%3));if(k%%3==0)noise<-noise+sample(c(-.45,.45),n,TRUE);v<-pmax(.01,mu147[k,j]+noise);
 data.frame(cell_id=sprintf('%s_%03d',clusters[k],1:n),cluster=clusters[k],marker=markers[j],expression=v)}))))
plot147<-rbind(transform(d147,group=cluster),transform(d147,group='All cells'))
plot147$group<-factor(plot147$group,levels=rev(c(clusters,'All cells')));plot147$marker<-factor(plot147$marker,levels=markers)
c147<-c(c1='#8FB6B0',c2='#65A29B',c3='#3E847F',c4='#2F625F',c5='#C2B0D2',c6='#A38BBA',c7='#86699E',c8='#674C7F','All cells'='#D5DADF')
p147<-ggplot(plot147,aes(expression,group,fill=group))+geom_density_ridges(quantile_lines=TRUE,quantiles=2,scale=.93,
 rel_min_height=0,linewidth=.22,colour='#424851')+facet_wrap(~marker,nrow=1)+scale_fill_manual(values=c147,guide='none')+
 scale_x_continuous(breaks=c(0,3,6),expand=expansion(mult=c(0,0)))+coord_cartesian(xlim=c(-.5,7.2))+
 scale_y_discrete(expand=expansion(add=c(.1,.95)))+labs(x='Expression score',y=NULL)+base+
 theme(panel.border=element_rect(fill=NA,colour='#92969D',linewidth=.25),axis.line=element_blank(),
 strip.background=element_rect(fill='#F3F4F6',colour='#92969D',linewidth=.25),panel.spacing.x=unit(1.8,'mm'))
sum147<-aggregate(expression~marker+group,plot147,function(x)c(n=length(x),mean=mean(x),median=median(x)))
sum147<-data.frame(sum147[,1:2],sum147$expression)
save_case('SCICASE-147',p147,d147,list(summaries=sum147),183,91,'multipanel','six-marker-faceted-ridges',
 '固定种子20261029生成800个模拟细胞、8簇、6个标记的4800条表达分数。All cells来自同一800细胞合并，未独立再造。竖线为原生ggridges的中位分位线；细胞不作为生物重复，无分组检验。标签沿用教程，数值不是真实单细胞数据。',
 c147,list(hierarchy='Six marker facets share nine cluster/pooled rows; median lines provide a second summary without another panel.',
 geometry='Equal-width facets and a common marker-score scale; All cells is recomputed by pooling the eight clusters in each marker.',
 palette='Named categorical teal and mauve shades replace the source multihue palette; pooled cells use neutral grey consistently across all six facets.',
 typography='7pt Arial labels,compact bold marker strips and thin panel borders; y labels occur once at the left.',
 marks='Native ggridges polygons with one median line per displayed ridge; no new significance annotation or biological classification.',
 annotation='Marker IDs,cluster IDs,pooled row and expression-score axis only; no simulation statement or method/footer on canvas.'),
 list(rows=nrow(d147),unique_cells=800,clusters=8,markers=6,displayed_ridges=54,all_cells_derived_from_same_ids=TRUE,inference_performed=FALSE))

# 151: source image matches the neighbouring archive's contour/label code.
n151<-2400;x<-runif(n151,-.08,.99);y<-.02+.90*x+rnorm(n151,sd=.145)
d151<-data.frame(feature_id=sprintf('BG%04d',1:n151),score_a=x,score_b=y,label='',class='Background')
focus<-data.frame(feature_id=sprintf('F%02d',1:9),score_a=c(.77,.89,.98,.61,.79,.96,.02,.22,.37),
 score_b=c(.88,.91,.99,.03,.20,.40,.59,.76,.93),label=sprintf('F%02d',1:9),
 class=rep(c('Concordant','A-biased','B-biased'),each=3))
d151<-rbind(d151,focus);focus$class<-factor(focus$class,levels=c('Concordant','A-biased','B-biased'))
c151<-c(Concordant='#35998C','A-biased'='#CA7A60','B-biased'='#597EB0')
p151<-ggplot(d151,aes(score_a,score_b))+geom_point(colour='#C7CCD2',alpha=.20,size=.32)+
 geom_density_2d(aes(colour=after_stat(level)),bins=12,linewidth=.28)+
 scale_colour_gradientn(colours=c('#DCD0E9','#9E82BB','#513767'),name='Density',
 guide=guide_colourbar(order=2,barheight=unit(22,'mm'),barwidth=unit(2.6,'mm'),display='gradient'))+
 geom_abline(intercept=0,slope=1,linetype='dashed',colour='#4A4F57',linewidth=.35)+
 geom_abline(intercept=c(-.3,.3),slope=1,linetype='dashed',colour=c151[c('A-biased','B-biased')],linewidth=.3)+
 new_scale_colour()+geom_point(data=focus,aes(fill=class),shape=21,colour='white',stroke=.28,size=1.7)+
 geom_text_repel(data=focus,aes(label=label,colour=class),size=7/.pt,family='Arial',fontface='italic',
 seed=seed,max.overlaps=Inf,box.padding=.35,point.padding=.25,min.segment.length=0,segment.size=.22,
 xlim=c(-.13,1.03),ylim=c(-.13,1.04),show.legend=FALSE)+
 scale_fill_manual(values=c151,name='Feature class',guide=guide_legend(order=1,override.aes=list(size=2)))+
 scale_colour_manual(values=c151,guide='none')+coord_cartesian(xlim=c(-.2,1.05),ylim=c(-.2,1.05),clip='on')+
 scale_x_continuous(breaks=c(-.2,0,.4,.8,1))+scale_y_continuous(breaks=c(-.2,0,.4,.8,1))+
 labs(x='Score A',y='Score B')+base+theme(aspect.ratio=1,legend.position='right',legend.box='vertical',legend.spacing.y=unit(2,'mm'))
save_case('SCICASE-151',p151,d151,list(highlighted_features=focus),136,116,'distribution','scatter-density-contours-labels',
 '固定种子20261029生成2400个背景特征和9个展示特征的成对分数。无真实基因名、rg值、P值或保守性结论；A/B偏向与同时高分仅为演示类别。对角线及±0.3差值线只是几何参考。图151与归档152代码重新按内容配对。',
 c151,list(hierarchy='Faint paired-score scatter supports thin density contours,three labeled feature categories and explicit diagonal comparison guides.',
 geometry='A square Cartesian data region with a reserved right legend column; nine short feature IDs replace the crowded real-gene labels.',
 palette='Lavender-to-plum density contours plus named teal/coral/blue highlighted classes; background points stay low contrast.',
 typography='7pt Arial axes,keys and italic feature IDs at136x116mm; separate categorical and continuous legend roles.',
 marks='Native bivariate KDE contours,small background points,white-outlined focus points and thin ggrepel leader lines; no inferred conservation classes.',
 annotation='Only feature IDs,score axes,density and class keys; source inferential gene claims and workflow footnotes are excluded.'),
 list(rows=nrow(d151),background_features=2400,highlighted_features=9,density_contour_bins=12,inference_performed=FALSE),focus$label)

# 152: four separately normalized filled-density panels; no fabricated P-values.
ns<-c(360,96,64,144);labs152<-paste('Class',LETTERS[1:4]);mu152<-c(2.65,2.8,2.85,2.45);sd152<-c(.24,.32,.45,.12)
d152<-do.call(rbind,lapply(1:4,function(k)data.frame(feature_id=sprintf('%s_%03d',LETTERS[k],seq_len(ns[k])),
 class=labs152[k],score=pmax(2.01,pmin(4.95,rnorm(ns[k],mu152[k],sd152[k]))),length_aa=round(pmax(100,pmin(295,rnorm(ns[k],165+c(15,0,-5,10)[k],c(23,22,28,25)[k])))))))
pal152<-list(c('#F1F8F6','#257D78'),c('#F8F3ED','#A7723D'),c('#F6F0F7','#8C5796'),c('#F1F5F9','#3D678E'))
ps152<-lapply(1:4,function(k){d<-d152[d152$class==labs152[k],];
 ggplot(d,aes(score,length_aa))+geom_density_2d_filled(contour_var='ndensity',breaks=seq(0,1,length.out=9),n=120)+
 scale_fill_manual(values=grDevices::colorRampPalette(pal152[[k]])(8),guide='none')+
 coord_cartesian(xlim=c(2,5),ylim=c(100,300),expand=FALSE)+scale_x_continuous(breaks=2:5)+scale_y_continuous(breaks=c(100,200,300))+
 annotate('text',x=4.85,y=291,label=paste0('n = ',nrow(d)),hjust=1,vjust=1,size=7/.pt,family='Arial')+
 labs(x=NULL,y=if(k==1)'Length (aa)'else NULL,title=labs152[k])+base+theme(aspect.ratio=1,
 plot.title=element_text(size=7,face='bold',hjust=.5,margin=margin(b=3)),
 axis.text.y=if(k==1)element_text(size=7)else element_blank(),axis.ticks.y=if(k==1)element_line(linewidth=.25)else element_blank(),
 panel.border=element_rect(fill=NA,colour='#91969D',linewidth=.25),panel.background=element_rect(fill=pal152[[k]][1],colour=NA),axis.line=element_blank())})
p152<-wrap_plots(ps152,nrow=1)+plot_annotation(caption=NULL)&theme(plot.margin=margin(4,3,4,3))
# A shared axis is a scientific label, retained as a separate small native text panel.
axis152<-ggplot()+annotate('text',x=.5,y=.5,label='Score',size=7/.pt,family='Arial')+theme_void()
p152<-p152/axis152+plot_layout(heights=c(1,.07))
sum152<-aggregate(cbind(score,length_aa)~class,d152,function(x)c(n=length(x),mean=mean(x),sd=sd(x)))
sum152<-data.frame(class=sum152$class,score=sum152$score,length_aa=sum152$length_aa)
save_case('SCICASE-152',p152,d152,list(summaries=sum152),183,65,'multipanel','four-filled-density-panels',
 '固定种子20261029生成四类共664个模拟特征，包含展示分数和模拟正整数长度。四面板n由输入计数，密度强度在各面板内归一，不能比较绝对密度；没有生成或标注P值、显著性或真实IDR/PLD/TF结论。图152与归档151代码重新配对。',
 setNames(unlist(lapply(pal152,tail,1)),labs152),list(hierarchy='Four small multiples share score/length coordinates,each with nested filled-density regions and a compact count label.',
 geometry='Equal square panels aligned on one row; only the leftmost length axis is labeled and a shared score label sits below.',
 palette='Four new pale-to-dark single-hue ramps:teal,ochre,mauve and steel blue; density is normalized separately within each panel.',
 typography='7pt Arial class labels,count labels and axes at183x65mm; titles are compact data-category labels,not study claims.',
 marks='Native geom_density_2d_filled with eight normalized-density intervals; crisp regions retain the source filled-contour composition.',
 annotation='Generic class IDs,actual simulated counts,length and score axes only. The source P-value axis and biological category assertions are not transferred.'),
 list(rows=nrow(d152),groups=4,group_counts=ns,positive_integer_lengths=TRUE,density_normalization='within-panel',inference_performed=FALSE))
