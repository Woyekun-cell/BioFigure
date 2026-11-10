args<-commandArgs(TRUE);P<-normalizePath(args[1]);W<-file.path(P,'work/2026-10-29-other-four');.libPaths(c(file.path(W,'Rlib'),.libPaths()))
source(file.path(P,'biofigure/scripts/figure_style.R'));font<-bf_font('Arial');bf_pdf_open(NULL,20,20,font);dev.off()
suppressPackageStartupMessages({library(ggplot2);library(patchwork);library(ggHoriPlot);library(grid)})
options(warn=1)
loc<-jsonlite::fromJSON(file.path(W,'source-locators.json'),simplifyVector=FALSE);seed<-20261029
base<-theme_classic(base_size=7,base_family='Arial')+theme(text=element_text(family='Arial',size=7,colour='#30343B'),axis.text=element_text(size=7,colour='#30343B'),axis.title=element_text(size=7),strip.text=element_text(size=7),legend.text=element_text(size=7),legend.title=element_text(size=7),legend.ticks=element_blank(),plot.tag=element_text(size=9,face='bold'),plot.margin=margin(3,3,3,3),axis.line=element_line(linewidth=.25,colour='#737B84'),axis.ticks=element_line(linewidth=.25))
savecase<-function(key,p,dat,extra,width,height,task,origin,palette,obs,numeric,extra_labels=character()){
 w<-file.path(W,key);dir.create(w,recursive=TRUE,showWarnings=FALSE);stem<-paste0('other4_',tolower(key),'_simulated_recolored_20261029');files<-c(paste0(stem,'.csv'),if(length(extra))paste0(stem,'_',names(extra),'.csv')else character());write.csv(dat,file.path(P,'results/plot_data',files[1]),row.names=FALSE)
 for(i in seq_along(extra))write.csv(extra[[i]],file.path(P,'results/plot_data',files[i+1]),row.names=FALSE)
 q<-list(stem=stem,seed=seed,origin='synthetic',width_mm=width,height_mm=height,figure_family='multipanel',figure_task='integrated-evidence',task_detail=task,plot_data_files=as.list(files),source=loc[[key]],data_origin=origin,palette=as.list(palette),observations=obs,numeric=numeric,extra_labels=extra_labels)
 jsonlite::write_json(q,file.path(w,'input-qc.json'),auto_unbox=TRUE,pretty=TRUE);saveRDS(p,file.path(w,'plot.rds'))
 ragg::agg_png(file.path(w,'layout-preflight.png'),width=width,height=height,units='mm',res=180,background='white');print(p);dev.off();cat(key,'prepared\n')
}
# Independent mock association summaries; no association test or source phenotype inferred.
set.seed(seed);labs<-paste('Locus',LETTERS[1:4]);ranges<-c(12,27,40,65);chroms<-c(2,4,7,10);marker<-list();phen<-list();lead<-list();plots<-list();pc<-c(SNP='#A5B6C7',SV='#8E9381',Lead='#B66D57');geno<-c(REF='#4B8F8C',ALT='#AD91B2')
for(k in 1:4){
 n<-1200;pos<-sort(runif(n,ranges[k],ranges[k]+2));type<-sample(c('SNP','SV'),n,replace=TRUE,prob=c(.82,.18));pk<-ranges[k]+c(.8,1.25,.9,1.35)[k];score<-pmin(3.5,rexp(n,1.8))+c(8,10,12,9)[k]*exp(-(pos-pk)^2/(2*.035^2));ix<-which.min(abs(pos-pk));score[ix]<-max(score)+1;type[ix]<-'SV'
 d<-data.frame(locus=labs[k],chromosome=chroms[k],variant_id=sprintf('L%d_V%04d',k,1:n),position_mb=pos,type=type,p=10^(-score),score=score,lead=seq_len(n)==ix);marker[[k]]<-d;lead[[k]]<-d[ix,]
 gt<-sample(c('REF','ALT'),200,replace=TRUE,prob=c(.72,.28));val<-rnorm(200,0,.65)+ifelse(gt=='ALT',c(1.2,1.5,-1.3,1.4)[k],0);z<-data.frame(sample=sprintf('S%03d',1:200),locus=labs[k],lead_variant=d$variant_id[ix],genotype=factor(gt,levels=c('REF','ALT')),value=val);phen[[k]]<-z
 a<-ggplot(d,aes(position_mb,score))+geom_point(aes(shape=type,colour=type),size=.7,alpha=.8)+geom_point(data=d[ix,],shape=24,size=2,fill=pc['Lead'],colour=pc['Lead'])+geom_segment(data=d[ix,],aes(x=position_mb+.25,xend=position_mb+.04,y=score+.15,yend=score),inherit.aes=FALSE,linewidth=.3,arrow=arrow(length=unit(1,'mm')))+geom_text(data=transform(d[ix,],lab=paste0('SV-',k)),aes(x=position_mb+.28,y=score+.15,label=lab),inherit.aes=FALSE,family='Arial',size=7/.pt,hjust=0)+scale_colour_manual(values=pc[1:2],name='Variant')+scale_shape_manual(values=c(SNP=16,SV=17),name='Variant')+scale_x_continuous(breaks=ranges[k]+c(0,1,2),limits=c(ranges[k],ranges[k]+2))+scale_y_continuous(expand=expansion(mult=c(.01,.17)))+labs(x=paste0('Chr ',chroms[k],' (Mb)'),y='-log10(P)',tag=letters[k])+base+theme(legend.position='none')
 b<-ggplot(z,aes(genotype,value,fill=genotype))+geom_boxplot(width=.55,outlier.shape=NA,colour='#424A54',linewidth=.3)+geom_point(position=position_jitter(width=.12,height=0,seed=seed+k),size=.45,alpha=.3,colour='#30343B')+scale_fill_manual(values=geno,guide='none')+labs(x=NULL,y='Trait score')+base+theme(axis.ticks.x=element_blank())
 plots[[k]]<-(a+b)+plot_layout(widths=c(3.2,1.3))+plot_annotation(tag_levels=list(letters[k]),theme=theme(plot.tag=element_text(family='Arial',size=9,face='bold')))
}
d<-do.call(rbind,marker);z<-do.call(rbind,phen);ld<-do.call(rbind,lead);p<-wrap_plots(plots,ncol=2)
lg<-cowplot::get_legend(a+theme(legend.position='bottom'));p<-p/ggplotify::as.ggplot(lg)+plot_layout(heights=c(1,.06))
savecase('GWAS',p,d,list(phenotypes=z,lead_variants=ld),183,148,'four-regional-association-and-genotype-phenotype-pairs',
 '固定种子模拟四个局部窗口，每窗1200个SNP/SV摘要与200条虚拟样本表型。P为预设局部峰形转换的测试输入，并未执行GWAS或显著性检验；每个表型面板由同一locus/lead_variant连接REF/ALT。只学习番茄Fig4c-f的四组局部峰及箱线配对结构，未复现该研究的P值、代谢物或真实效应。',c(pc,geno),
 list(hierarchy='Four regional-peak/phenotype pairs form a2x2 grid;eight data panels in total.',geometry='Each regional scatter is wider than its adjacent genotype boxplot;common column alignment and separate local coordinate windows.',palette='Slate SNP circles,muted olive SV triangles and terracotta lead variants;teal/mauve genotype distributions repeat across pairs.',typography='7pt Arial data and axis labels,9pt a-d pair tags at183x148mm.',marks='1200mock variant summaries per window;source-style lead arrows and genotype boxplots with200input-bound points;no copied significance brackets.',annotation='Only chromosome coordinates,variant IDs,trait axes and genotype labels;all synthetic provenance stays outside canvas.'),list(variants=nrow(d),loci=4,phenotypes=nrow(z),lead_variants=4,samples_per_locus=200),paste0('SV-',1:4))

# Native horizon folding,with one shared zero origin and six fixed bands.
set.seed(seed);prog<-sprintf('P%02d',1:16);conds<-c('Condition A','Condition B');times<-seq(0,72,length.out=145)
hd<-do.call(rbind,lapply(1:16,function(i)do.call(rbind,lapply(1:2,function(k){v<-1.3*sin(times/9+i*.45)+.55*cos(times/3.4+i*.2)+(k-1)*1.1*exp(-((times-38-i)^2)/180)+.12*sin(times*1.8+i);data.frame(program=prog[i],condition=conds[k],time_h=times,value=v)}))))
hd$program<-factor(hd$program,levels=prog);hd$condition<-factor(hd$condition,levels=conds)
hcols<-c('#385F83','#7598B4','#D4E1E9','#F1DCCA','#D39C75','#985D3F')
a<-ggplot(subset(hd,program=='P01'),aes(time_h,value))+geom_hline(yintercept=c(-2,-1,0,1,2),colour='#D4D8DD',linewidth=.2)+geom_line(colour='#4B687E',linewidth=.35)+facet_grid(~condition)+scale_y_continuous(limits=c(-3,3),breaks=c(-2,0,2))+scale_x_continuous(limits=c(0,72),breaks=c(0,24,48,72),expand=c(0,0))+labs(x=NULL,y='P01 score')+base+theme(strip.background=element_rect(fill='#F6F4F1',colour=NA),panel.spacing.x=unit(4,'mm'))
b<-ggplot(hd,aes(time_h,value,fill=after_stat(Cutpoints)))+geom_horizon(origin=0,horizonscale=c(-3,-2,-1,1,2,3),na.rm=TRUE)+facet_grid(program~condition)+scale_fill_manual(values=setNames(hcols,c('[-3, -2)','[-2, -1)','[-1, 0)','[0, 1)','[1, 2)','[2, 3)')),breaks=c('[-3, -2)','[-2, -1)','[-1, 0)','[0, 1)','[1, 2)','[2, 3)'),name='Score interval')+scale_x_continuous(limits=c(0,72),breaks=c(0,24,48,72),expand=c(0,0))+labs(x='Time (h)',y=NULL)+base+theme(axis.text.y=element_blank(),axis.ticks.y=element_blank(),axis.line.y=element_blank(),panel.spacing.y=unit(.55,'mm'),panel.spacing.x=unit(4,'mm'),strip.background=element_blank(),strip.text.y=element_text(angle=0),strip.text.x=element_blank(),legend.position='bottom',legend.key.height=unit(2,'mm'),legend.key.width=unit(3,'mm'))+guides(fill=guide_legend(nrow=1,title.position='top'))
p<-(a/b)+plot_layout(heights=c(1,4.4))+plot_annotation(tag_levels='a',theme=theme(plot.tag=element_text(family='Arial',size=9,face='bold')))
hd$fold_band<-pmin(3,pmax(1,ceiling(abs(hd$value))));hd$sign<-ifelse(hd$value<0,-1,1);hd$fold_height<-abs(hd$value)-(hd$fold_band-1)
savecase('HORIZON',p,hd,list(),183,150,'two-condition-six-band-faceted-horizon-with-decoding-traces',
 '确定性解析波形生成16虚拟program×2条件×145时点的相对分数，共4640行。所有条带共享原点0及单位宽度1的正负三层折叠，不逐行归一；上层直接显示同一P01原始轨迹帮助解码。仅学习ggHoriPlot官方分面/图例与折叠方法，不作基因活性、周期或处理机制结论。',setNames(hcols,c('negative3','negative2','negative1','positive1','positive2','positive3')),
 list(hierarchy='Two P01 decoding traces above32horizon stripes,with16shared program rows and two condition columns.',geometry='Native geom_horizon folds three positive and three negative unit-width bands;same zero origin and72h axis across every row.',palette='Three slate-blue levels below zero and three sand/copper levels above zero;intensity increases with absolute band.',typography='7pt Arial program/condition/axis/legend text and9pt a/b tags at183x150mm.',marks='Native geom_horizon areas from the saved input values;P01 raw lines use the exact same data,not independently generated profiles.',annotation='Only program IDs,conditions,score intervals and time axis;source climate title and workflow notes omitted.'),list(rows=nrow(hd),programs=16,conditions=2,times=145,origin=0,band_width=1))

# Native vcd conditional mosaics,with declared table counts and response colors.
set.seed(seed);cohort<-c('Cohort A','Cohort B');modules<-paste0('M',1:4);contexts<-c('X','Y');doses<-c('L','H');outcomes<-c('Decrease','Stable','Increase');mc<-c(Decrease='#4F9294',Stable='#E6DDD0',Increase='#BE806D')
md<-expand.grid(Module=modules,Context=contexts,Dose=doses,Response=outcomes,Cohort=cohort,stringsAsFactors=FALSE)
md$Freq<-vapply(seq_len(nrow(md)),function(i){r<-md[i,];m<-match(r$Module,modules);a<-match(r$Cohort,cohort);o<-match(r$Response,outcomes);n<-c(7,13,9,17)[m]+ifelse(r$Context=='Y',4,0);mu<-n*c(.8,1.4,1.1)[o]*exp((a-1)*c(-.3,0,.35)[o]+ifelse(r$Dose=='H',c(-.25,0,.3)[o],0));rpois(1,mu)+3},numeric(1))
md$probability<-with(md,Freq/ave(Freq,Module,Context,Dose,Cohort,FUN=sum));mplots<-list()
for(k in 1:2){
 tab<-xtabs(Freq~Module+Context+Dose+Response,data=transform(subset(md,Cohort==cohort[k]),Module=factor(Module,levels=modules),Context=factor(Context,levels=contexts),Dose=factor(Dose,levels=doses),Response=factor(Response,levels=outcomes)))
 native<-grid.grabExpr({pushViewport(viewport(gp=gpar(fontfamily='Arial',fontsize=7)));vcd::doubledecker(tab,gp=gpar(fill=unname(mc),col='white',lwd=.5),labeling_args=list(dep_varname=FALSE,boxes=FALSE,clip=FALSE,pos_labels=rep('center',4),just_labels=c('center','left','center','center'),gp_labels=gpar(fontfamily='Arial',fontsize=7),gp_varnames=gpar(fontfamily='Arial',fontsize=7,fontface='plain')),margins=unit(c(2,18,20,2),'mm'),newpage=FALSE);upViewport()},width=183/25.4,height=60/25.4,wrap=TRUE)
 mplots[[k]]<-ggplotify::as.ggplot(native)+labs(tag=letters[k])+theme(plot.tag=element_text(family='Arial',size=9,face='bold'),plot.margin=margin(0,0,0,0))
}
# Compact cohort strips make the two independent table layouts explicit.
strip<-function(label)ggplot()+annotate('text',x=0,y=0,label=label,family='Arial',size=7/.pt,hjust=0,fontface='bold')+xlim(0,1)+ylim(-1,1)+theme_void()+theme(plot.margin=margin(0,8,0,8))
p<-strip('Cohort A')/mplots[[1]]/strip('Cohort B')/mplots[[2]]+plot_layout(heights=c(.06,1,.06,1))
savecase('MOSAIC',p,md,list(),183,137,'two-cohort-four-factor-doubledecker-mosaic',
 '固定种子生成2cohort×4module×2context×2dose×3response的96格整数计数。原生vcd doubledecker按条件边际计数决定列宽，列内高度为三类response比例；两cohort各自保留边际量，不强制等宽或等频。仅为多因素分类计数绘图测试，无真实受试者、疗效或显著性推断；不采用原书招生/Titanic结论。',mc,
 list(hierarchy='Two full-width native conditional-mosaic panels,one per cohort;each nests module,context,dose and three response states.',geometry='Native vcd vertical factor splits and horizontal response splits;column widths follow conditioning counts,not equal-width stacked bars.',palette='Teal,soft ivory and clay distinguish decreasing,stable and increasing mock response categories identically in both panels.',typography='7pt Arial factor/response labels and cohort strips,9pt a/b tags at183x137mm.',marks='96source-bound mock frequency cells;each native rectangular area represents its conditional-table frequency.',annotation='Only cohort,module,context,dose and response labels;no source admissions/survival content or inferential footnotes.'),list(cells=nrow(md),cohorts=2,modules=4,contexts=2,doses=2,responses=3,total=sum(md$Freq)))

# Native bipartite plotweb,with a fixed node order across two weighted interaction tables.
set.seed(seed);an<-sprintf('A%02d',1:10);bn<-sprintf('B%02d',1:16);wa<-matrix(0L,10,16,dimnames=list(an,bn));wb<-wa
for(i in 1:10)for(j in 1:16){g1<-ceiling(i/3);g2<-ceiling(j/4);l<-if(g1==g2)14 else if(abs(g1-g2)==1)3 else .6;wa[i,j]<-rpois(1,l);wb[i,j]<-rpois(1,l*ifelse(j<=8,ifelse(i<=5,1.5,.7),ifelse(i>5,1.4,.7)))}
stopifnot(all(rowSums(wa)>0),all(colSums(wa)>0),all(rowSums(wb)>0),all(colSums(wb)>0))
acol<-setNames(rep(c('#3B7E83','#68A4A4','#9DC6BF','#C6DDD4'),length.out=10),an);bcol<-setNames(rep(c('#78688F','#9585AA','#B4A7C4','#D4CBDD'),each=4),bn)
webs<-list(wa,wb);bplots<-list()
for(k in 1:2){
 ww<-webs[[k]]
 # ggplotify translates the native base-graphics rectangles and links into vector grobs.
 native<-ggplotify::as.grob(local({ww_copy<-ww;ac<-acol;bc<-bcol;function(){par(family='sans',ps=10);bipartite::plotweb(ww_copy,sorting='normal',horizontal=TRUE,curved_links=TRUE,spacing=.28,text_size=.72,lower_color=ac,higher_color=bc,lower_border='#53676D',higher_border='#746C80',link_color='lower',link_border='transparent',link_alpha=.35,box_size=.07,lab_distance=.025,mar=c(.5,2.5,.5,2.5),family='sans')}}))
 bplots[[k]]<-ggplotify::as.ggplot(native)+labs(tag=letters[k])+theme(plot.tag=element_text(family='Arial',size=9,face='bold'),plot.margin=margin(0,0,0,0))
}
dat<-rbind(transform(as.data.frame(as.table(wa),responseName='weight'),condition='Condition A'),transform(as.data.frame(as.table(wb),responseName='weight'),condition='Condition B'));names(dat)[1:2]<-c('guild_a','guild_b')
marg<-do.call(rbind,lapply(1:2,function(k)rbind(data.frame(condition=c('Condition A','Condition B')[k],guild='A',node=an,total=rowSums(webs[[k]])),data.frame(condition=c('Condition A','Condition B')[k],guild='B',node=bn,total=colSums(webs[[k]])))))
p<-(strip('Condition A')/bplots[[1]]+plot_layout(heights=c(.06,1)))|(strip('Condition B')/bplots[[2]]+plot_layout(heights=c(.06,1)))
savecase('BIPARTITE',p,dat,list(node_totals=marg),183,143,'paired-quantitative-two-guild-interaction-webs',
 '固定种子模拟10个A类节点和16个B类节点的两条件非负整数互作矩阵，每条件160个位置，零值保留。原生bipartite::plotweb用边权和节点总量分配流带及端块；固定相同节点顺序，条件内部相对尺度，各条件总数不同，不能直接按跨面板绝对带宽比较。只作通用二部互作可视化，不是实际生态食物网或物种互作结论。',c(a_teal='#3B7E83',a_light='#C6DDD4',b_plum='#78688F',b_light='#D4CBDD'),
 list(hierarchy='Two quantitative two-guild interaction webs,one per condition,with identical ten A and sixteen B IDs.',geometry='Native bipartite curved links and node rectangles share fixed input row/column order;relative widths conserved within each network.',palette='Teal shades identify A nodes and muted plum shades identify B nodes;links inherit their A source color with controlled transparency.',typography='7pt Arial node labels after complete-grob normalization,7pt condition strips and9pt a/b panel tags at183x143mm.',marks='All positive weighted links and their exact row/column totals come from saved integer matrices;zero positions remain in CSV.',annotation='Only condition and node IDs;no taxonomy,trophic direction,causality or total-comparison inference;no workflow notes.'),list(matrix_positions=nrow(dat),conditions=2,guild_a_nodes=10,guild_b_nodes=16,total_a=sum(wa),total_b=sum(wb),positive_links_a=sum(wa>0),positive_links_b=sum(wb>0)))

capture.output(warnings(),file=file.path(W,'preparation-warnings.txt'))
