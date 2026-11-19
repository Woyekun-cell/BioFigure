suppressPackageStartupMessages({library(ggplot2);library(ggraph);library(igraph);library(grid);library(ComplexHeatmap);library(jsonlite)})
source(file.path(dirname(normalizePath(commandArgs(TRUE)[1])),'native_export.R'));d<-read.csv(file.path(B,'input.csv'),na.strings='',check.names=FALSE,stringsAsFactors=FALSE);fields<-c('Dx','sex','smoking','entry','obesity','HBP','DM');stopifnot(nrow(d)==857,!anyDuplicated(d$record_id))
for(k in fields){d[[k]]<-as.character(d[[k]]);d[[k]][is.na(d[[k]])]<-'Not recorded'}
# Prefix keys distinguish repeated Yes/No categories in different clinical levels.
nodes<-data.frame(name='root',parent=NA_character_,depth=0L,category='root',value=857,weight=0)
for(k in seq_along(fields)){
 key<-apply(d[,fields[seq_len(k)],drop=FALSE],1,paste,collapse='::');tab<-sort(table(key),decreasing=TRUE)
 for(z in names(tab)){pp<-strsplit(z,'::',fixed=TRUE)[[1]];nodes<-rbind(nodes,data.frame(name=z,parent=if(k==1)'root'else paste(head(pp,-1),collapse='::'),depth=k,category=tail(pp,1),value=unname(tab[z]),weight=if(k==7)unname(tab[z])else 0))}
}
stopifnot(!anyDuplicated(nodes$name));edges<-data.frame(from=nodes$parent[-1],to=nodes$name[-1]);g<-graph_from_data_frame(edges,vertices=nodes,directed=TRUE);lay<-as.data.frame(create_layout(g,'partition',weight=weight,circular=TRUE));lay<-lay[lay$depth>0,];lay$r0<-.9+(lay$depth-1)*.27;lay$r<-lay$r0+.265;lay$key<-paste(lay$depth,lay$category,sep=':')
levelmaps<-list(c(NSTEMI='#D6A23E',STEMI='#588DC3','Unstable Angina'='#D8757D'),c(Female='#DC9CAC',Male='#82B6D4'),c(Never='#E6E7E3','Ex-smoker'='#9B9F9E',Smoker='#3F494E'),c(Femoral='#9E6B7B',Radial='#D0ACB9'),c(No='#F0D3DE',Yes='#BB7B98'),c(No='#F5E4EC',Yes='#CB9DB1'),c(No='#FAF0F4',Yes='#DEB8CA'))
# moonBook labels use case-sensitive clinical categories; map any source levels explicitly.
for(k in seq_along(fields)){
 cats<-unique(lay$category[lay$depth==k]);miss<-setdiff(cats,names(levelmaps[[k]]));if(length(miss)){base<-if(k%in%c(2,4))c('#8EBBD1','#D8A4B4','#B8BCC0')else c('#B8BCC0','#E2E4E3','#82777F');levelmaps[[k]]<-c(levelmaps[[k]],setNames(base[seq_along(miss)],miss))}
}
colors<-unlist(lapply(seq_along(levelmaps),function(k)setNames(levelmaps[[k]],paste(k,names(levelmaps[[k]]),sep=':'))));stopifnot(all(lay$key%in%names(colors)))
# Every prefix span must match its exact patient count and remain within its parent.
stopifnot(all(abs((lay$end-lay$start)/(2*pi)-lay$value/857)<1e-10))
for(i in seq_len(nrow(lay))){parid<-nodes$parent[match(lay$name[i],nodes$name)];if(parid!='root'){j<-match(parid,lay$name);stopifnot(lay$start[i]>=lay$start[j]-1e-12,lay$end[i]<=lay$end[j]+1e-12)}}
write.csv(lay,file.path(B,'hierarchy-layout.csv'),row.names=FALSE)
p<-ggplot(lay)+ggforce::geom_arc_bar(aes(x0=0,y0=0,r0=r0,r=r,start=start,end=end,fill=key),colour='white',linewidth=.12)+scale_fill_manual(values=colors)+coord_fixed(xlim=c(-2.95,2.95),ylim=c(-2.95,2.95),expand=FALSE)+theme_void(base_family='Arial')+theme(legend.position='none',plot.margin=margin(0,0,0,0),plot.background=element_rect(fill='white',colour=NA))
labels<-c('Diagnosis','Sex','Smoking','Entry','Obesity','Hypertension','Diabetes')
draw_figure<-function(){
 pushViewport(viewport(x=unit(2,'mm'),y=unit(7,'mm'),width=unit(133,'mm'),height=unit(133,'mm'),just=c('left','bottom')));print(p,newpage=FALSE);popViewport()
 grid.text('857',unit(68.5,'mm'),unit(73.5,'mm'),gp=gp())
 for(k in seq_along(fields)){z<-levelmaps[[k]];z<-z[names(z)%in%unique(lay$category[lay$depth==k])];lg<-Legend(title=labels[k],labels=names(z),legend_gp=gpar(fill=z,col=NA),grid_width=unit(2,'mm'),grid_height=unit(2,'mm'),title_gp=gp(),labels_gp=gp());draw(lg,x=unit(140,'mm'),y=unit(137-(k-1)*18,'mm'),just=c('left','top'))}
 write_json(list(patient_records=857,depth=7,nodes=nrow(lay),leaf_weight_sum=sum(lay$value[lay$depth==7]),all_prefix_angles_conserve_counts=TRUE,all_children_within_parent=TRUE,missing_explicit=TRUE,renderer='ggraph partition layout + ggforce arc bars; static editable vector implementation',claim='Official moonBook ACS tutorial data; not original cancer-cohort counts'),file.path(B,'hierarchy-audit.json'),pretty=TRUE,auto_unbox=TRUE)
}
export_native(draw_figure,'ggplot2')
