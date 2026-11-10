args <- commandArgs(TRUE)
P <- normalizePath(args[1]); W <- file.path(P, 'work/2026-10-29-grouped-upset')
suppressPackageStartupMessages({library(ComplexUpset);library(ggplot2);library(patchwork);library(grid)})
set.seed(20261029)
days <- c('D1','D3','D5','D7','D9')
sets <- c(paste0(days,'_Apo'),paste0(days,'_Sym'))
patterns <- rbind(c(1,1,1,1,1),c(-1,-1,-1,-1,-1),c(0,1,1,1,1),c(0,-1,-1,-1,-1),
 c(1,1,1,0,0),c(0,0,-1,-1,-1),c(0,1,1,1,0),c(0,-1,-1,-1,0),
 c(1,1,0,0,0),c(0,0,0,-1,-1),c(1,0,0,0,0),c(0,-1,0,0,0),
 c(0,1,0,0,0),c(0,0,-1,0,0),c(0,0,1,0,0),c(0,0,0,-1,0),
 c(0,0,0,1,0),c(0,0,0,0,-1),c(0,0,0,0,1),c(-1,0,0,0,0),
 c(1,1,0,-1,-1),c(-1,-1,0,1,1),c(1,0,1,0,1),c(-1,0,-1,0,-1),
 c(1,0,0,0,-1),c(-1,0,0,0,1),c(0,1,0,-1,0),c(0,-1,0,1,0),
 c(1,1,1,-1,-1),c(-1,-1,-1,1,1))
counts <- c(300,280,240,210,190,175,160,145,132,121,112,104,96,90,84,78,72,67,62,58,53,49,45,41,38,34,31,28,25,22)
stopifnot(nrow(unique(patterns))==30,nrow(patterns)==length(counts),all(rowSums(abs(patterns))>0))
membership <- cbind(patterns==1,patterns== -1); colnames(membership) <- sets
classes <- ifelse(rowSums(patterns>0)>0 & rowSums(patterns<0)>0,'Mixed',ifelse(rowSums(patterns>0)>0,'Apo only','Sym only'))
index <- rep(seq_len(nrow(patterns)), counts)
dat <- data.frame(GeneID=sprintf('SIM_G%05d',seq_along(index)), membership[index,,drop=FALSE],
 Membership_class=factor(classes[index],levels=c('Apo only','Sym only','Mixed')), check.names=FALSE)
dat <- dat[sample(seq_len(nrow(dat))),,drop=FALSE]
stopifnot(!anyDuplicated(dat$GeneID),!anyNA(dat),all(rowSums(dat[,sets])>0))
for(d in days)stopifnot(!any(dat[[paste0(d,'_Apo')]] & dat[[paste0(d,'_Sym')]]))
summary <- data.frame(intersection_id=sprintf('I%02d',seq_along(counts)),count=counts,
 Membership_class=classes,membership,check.names=FALSE)
setinfo <- data.frame(set=sets,day=rep(days,2),condition=rep(c('Apo','Sym'),each=5),
 row_order=seq_along(sets),size=colSums(dat[,sets]))
stem <- 'grouped_upset_scicase033_simulated_recolored_20261029'
plotfiles <- paste0(stem,c('_memberships.csv','_intersections.csv','_sets.csv'))
for(i in 1:3)write.csv(list(dat,summary,setinfo)[[i]],file.path(P,'results/plot_data',plotfiles[i]),row.names=FALSE)

# Use the tutorial's actual ComplexUpset components; membership keys compute all bars.
daycols <- setNames(c('#B8A6D2','#9E85C0','#8365AD','#674A91','#493369'),days)
classcols <- c('Apo only'='#CD816E','Sym only'='#409B91','Mixed'='#C3A148')
theme_set(theme_minimal(base_size=7,base_family='Arial'))
ragg::agg_png(file.path(W,'legend-measurement.png'),width=183,height=116,units='mm',res=150,background='white')
tm <- theme(text=element_text(family='Arial',size=7,colour='#30343B'),
 panel.grid=element_blank(),axis.text=element_text(size=7,colour='#30343B'),
 axis.title=element_text(size=7),legend.title=element_text(size=7),
 legend.text=element_text(size=7),plot.margin=margin(2,2,2,2),
 axis.ticks=element_line(colour='#737780',linewidth=.25))
top <- intersection_size(counts=TRUE,text=list(size=7/ggplot2::.pt,vjust=-.6),
 mapping=aes(fill=Membership_class),bar_number_threshold=1) +
 scale_fill_manual(values=classcols,name='Membership class',drop=FALSE,guide='none') +
 scale_y_continuous(expand=expansion(mult=c(0,.13)),breaks=c(0,100,200,300)) +
 ylab('Intersection size') + tm + theme(panel.grid.major.y=element_line(colour='#ECECEF',linewidth=.22),
 axis.line.x=element_line(colour='#737780',linewidth=.25),legend.position='none') + coord_cartesian(clip='off')
mat <- intersection_matrix(geom=geom_point(aes(shape=ifelse(grepl('_Apo$',group),'Apo','Sym')),size=1.65,stroke=.25),
 segment=geom_segment(linewidth=.28),outline_color=list(active='#30343B',inactive='#BFC2C8')) +
 scale_shape_manual(values=c(Apo=24,Sym=21),guide='none') + tm +
 theme(axis.ticks=element_blank(),axis.title=element_blank())
stripe <- upset_stripes(mapping=aes(colour=condition),data=setinfo[,c('set','condition')],
 colors=c(Apo='#F7F1EE',Sym='#EDF5F3'),geom=geom_segment(linewidth=4.5))
p <- upset(dat,intersect=rev(sets),name=NULL,encode_sets=FALSE,sort_sets=FALSE,
 sort_intersections_by='cardinality',sort_intersections='descending',min_size=1,keep_empty_groups=TRUE,
 height_ratio=.95,width_ratio=.16,stripes=stripe,
 base_annotations=list('Intersection size'=top),matrix=mat,
 set_sizes=upset_set_size(geom=geom_bar(width=.64,colour='#30343B',linewidth=.25))+
 scale_y_reverse(breaks=c(0,600,1200),labels=c('0','600','1,200'))+
 ylab('Set size')+tm+theme(axis.text.x=element_text(angle=0),axis.ticks.y=element_blank()),
 queries=lapply(sets,function(s)upset_query(set=s,fill=daycols[sub('_.*','',s)],color=daycols[sub('_.*','',s)])),
 themes=upset_modify_themes(list(default=tm,intersections_matrix=tm+theme(axis.text.y=element_text(size=7),axis.ticks=element_blank()),overall_sizes=tm)),guides=NULL)
p <- p & theme(legend.position='none')

# Keep keys outside the data area and use the same named mappings as the data marks.
key <- function(type){
 if(type=='class')ggplot(data.frame(Membership_class=factor(names(classcols),levels=names(classcols)),x=1:3),aes(x,1,fill=Membership_class))+
  geom_col(show.legend=TRUE)+scale_fill_manual(values=classcols,name='Membership class')+
  guides(fill=guide_legend(nrow=1))
 else if(type=='time')ggplot(data.frame(day=factor(days,levels=days),x=seq_along(days)),aes(x,1,colour=day))+
  geom_point(size=2,show.legend=TRUE)+scale_colour_manual(values=daycols,name='Time')+
  guides(colour=guide_legend(nrow=1,override.aes=list(size=2)))
 else ggplot(data.frame(condition=c('Apo','Sym'),x=1:2),aes(x,1,shape=condition))+
  geom_point(size=2,fill='#6D6477',colour='#30343B',show.legend=TRUE)+
  scale_shape_manual(values=c(Apo=24,Sym=21),name='Condition')+
  guides(shape=guide_legend(nrow=1,override.aes=list(size=2)))
}
extract_legend <- function(x){g<-ggplotGrob(x+theme_void(base_size=7,base_family='Arial')+
 theme(legend.position='top',legend.text=element_text(size=7),legend.title=element_text(size=7),
 legend.key.width=unit(3.5,'mm'),legend.key.height=unit(3,'mm'),legend.spacing.x=unit(1,'mm')));g$grobs[[which(g$layout$name=='guide-box-top')]]}
timekey<-wrap_elements(extract_legend(key('time')));condkey<-wrap_elements(extract_legend(key('condition')))
classkey<-wrap_elements(extract_legend(key('class')))
p <- classkey / p / (timekey+condkey+plot_layout(widths=c(1.3,1))) + plot_layout(heights=c(.075,1,.075))
saveRDS(p,file.path(W,'plot.rds'))
print(p)
dev.off()
q <- list(stem=stem,seed=20261029,origin='synthetic',width_mm=183,height_mm=116,
 plot_data_files=plotfiles,source=jsonlite::fromJSON(file.path(P,'work/2026-10-29-set-completion/source-locators.json'))[['SCICASE-033']],
 data_origin=paste('固定种子20261029独立生成',nrow(dat),'个模拟基因的十集合成员表和30个互斥交集。',
 'Apo/Sym是沿用教程的条件标签；每个时间点两条件互斥。交集类别按成员集合派生为Apo only/Sym only/Mixed。',
 '集合大小和交集计数均由唯一基因ID重新计算；仅用于结构、美化和程序测试，非原研究数据或差异表达结论。'),
 observations=list(hierarchy='Retain the source three-part UpSet: descending intersection bars above the aligned membership matrix, set-size bars at left, and two condition groups.',
 geometry='Thirty exclusive intersections and ten set rows with a shared native ComplexUpset order; labels and three keys get reserved space.',
 palette='Coral/teal/gold encode derived membership class; five ordered purples encode time; warm/teal pale stripes separate conditions.',
 typography='Arial 7pt at183x116mm; concise axis names and source-style set IDs; all30 intersection counts retained.',
 marks='Apo uses triangles and Sym circles; faint inactive symbols and thin connectors distinguish absent/present membership without relying on color alone.',
 annotation='No title, study claim, method paragraph or generation footnote on canvas; simulation and data-generation details live in metadata.'),
 numeric=list(genes=nrow(dat),sets=10,intersections=30,intersection_total=sum(counts),membership_edges=sum(as.matrix(dat[,sets])),
 ids_unique=TRUE,missing_values=0,per_day_conditions_mutually_exclusive=TRUE,class_rule='Any Apo and any Sym => Mixed; otherwise condition-only'))
jsonlite::write_json(q,file.path(W,'input-qc.json'),auto_unbox=TRUE,pretty=TRUE)
capture.output(sessionInfo(),file=file.path(W,'preparation-sessionInfo.txt'))
cat(nrow(dat),'synthetic genes,30exclusive intersections,10sets prepared\n')
