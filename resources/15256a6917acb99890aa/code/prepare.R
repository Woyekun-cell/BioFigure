args<-commandArgs(TRUE);P<-normalizePath(args[1]);W<-file.path(P,'work/2026-10-30-omics-four');S<-file.path(W,'sources');D<-file.path(P,'results/plot_data')
suppressPackageStartupMessages({library(ggplot2);library(patchwork);library(dplyr);library(tidyr);library(grid);library(jsonlite)})
ink<-'#30343B';tc<-c(low_grade_cartilage='#30A59A',high_grade_cartilage='#497BC0',synovium='#E99A48',fat_pad='#A780BA')
theme_set(theme_classic(base_family='Arial',base_size=7)+theme(axis.text=element_text(size=7,colour=ink),axis.title=element_text(size=7),strip.text=element_text(size=7),strip.background=element_blank(),legend.text=element_text(size=7),legend.title=element_text(size=7),legend.position='bottom',legend.box='horizontal',plot.title=element_text(size=7,face='bold'),plot.tag=element_text(size=9,face='bold'),axis.line=element_line(linewidth=.25),axis.ticks=element_line(linewidth=.25),panel.spacing=unit(2,'mm'),legend.key.height=unit(3,'mm'),legend.key.width=unit(4,'mm'),plot.margin=margin(3,3,3,3)))
read<-function(n)read.csv(file.path(S,n),check.names=FALSE)
export<-function(x,k,n){f<-paste0('journal3_',k,'_20261030_',n,'.csv');write.csv(x,file.path(D,f),row.names=FALSE,na='');f}
start<-function(){glist<<-list(rectGrob(gp=gpar(fill='white',col=NA)));metrics<<-list()}
put<-function(x)glist[[length(glist)+1]]<<-x
txt<-function(t,x,y,size=7,just='left',rot=0,bold=FALSE,col=ink,italic=FALSE)put(textGrob(t,unit(x,'mm'),unit(y,'mm'),just=just,rot=rot,gp=gpar(fontfamily='Arial',fontsize=size,fontface=if(bold&&italic)'bold.italic'else if(bold)'bold'else if(italic)'italic'else'plain',col=col)))
seg<-function(x1,y1,x2,y2,col=ink,lwd=.6,lty=1)put(segmentsGrob(unit(x1,'mm'),unit(y1,'mm'),unit(x2,'mm'),unit(y2,'mm'),gp=gpar(col=col,lwd=lwd,lty=lty)))
dot<-function(x,y,fill,pch=21,size=1.5,col=ink)put(pointsGrob(unit(x,'mm'),unit(y,'mm'),pch=pch,size=unit(size,'mm'),gp=gpar(fill=fill,col=col,lwd=.5)))
finish<-function(k,p,files,transform,counts,palette,ww,hh,native=FALSE){
 w<-file.path(W,k);dir.create(w,recursive=TRUE,showWarnings=FALSE);saveRDS(p,file.path(w,if(native)'native-grob.rds'else'plot.rds'));write_json(list(stem=paste0('journal3_',k,'_20261030'),width_mm=ww,height_mm=hh,plot_data_files=files,transform=transform,counts=counts,palette=as.list(palette)),file.path(w,'input-qc.json'),auto_unbox=TRUE,pretty=TRUE,digits=NA);write_json(if(native)metrics else list(),file.path(w,'native-cell-metrics.json'),auto_unbox=TRUE,pretty=TRUE,digits=NA)
}
# B-D: preserve source posterior mean±SD; each DE strip has measured square cells.
start();tissues<-names(tc);all<-read('discordant_eQTLs_all_tissues.tsv');dis<-read('discordant_eQTLs_cartilage_grades.tsv');uni<-read('unique_eQTLs_cartilage_grades.tsv');flat<-list();orders<-list()
forest<-function(d,x1,x2,top,pitch,tag,title,id,strip=FALSE){
 ts<-tissues[paste0('PosteriorMean_',tissues)%in%names(d)];ord<-order(rowMeans(d[paste0('PosteriorMean_',ts)]));d<-d[ord,];n<-nrow(d);yy<-top-(seq_len(n)-.5)*pitch;names(yy)<-d$variant_id_genename
 ext<-max((abs(unlist(d[paste0('PosteriorMean_',ts)]))+unlist(d[paste0('PosteriorSD_',ts)])),na.rm=TRUE);lim<-max(.3,ceiling(ext*10)/10);xx<-function(v)x1+(v+lim)/(2*lim)*(x2-x1)
 for(v in pretty(c(-lim,lim),n=3)){if(v>=-lim&&v<=lim){seg(xx(v),top,xx(v),top-n*pitch,col=if(v==0)'#A4B0BA'else'#E5E9ED',lwd=if(v==0).7 else .35)}}
 txt(tag,x1-27,top+6,9,bold=TRUE);txt(title,x1-22,top+6,bold=TRUE)
 for(i in seq_len(n)){
  txt(d$gene_name[i],x1-2,yy[i],just='right',italic=TRUE)
  for(j in seq_along(ts)){
   t<-ts[j];mu<-d[[paste0('PosteriorMean_',t)]][i];sd<-d[[paste0('PosteriorSD_',t)]][i];lfsr<-d[[paste0('LFSR_',t)]][i];y<-yy[i]+(j-(length(ts)+1)/2)*.22
   seg(xx(mu-sd),y,xx(mu+sd),y,col='#707B85',lwd=.55);seg(xx(mu-sd),y-.3,xx(mu-sd),y+.3,col='#707B85',lwd=.55);seg(xx(mu+sd),y-.3,xx(mu+sd),y+.3,col='#707B85',lwd=.55);dot(xx(mu),y,tc[t],pch=if(lfsr<.05)25 else 21,size=if(lfsr<.05)1.7 else 1.05)
   flat[[length(flat)+1]]<<-data.frame(panel=id,variant_id=d$variant_id[i],gene=d$gene_name[i],rsid=d$rsid[i],tissue=t,mean=mu,sd=sd,LFSR=lfsr,display_row=i,y_mm=yy[i])
  }
 }
 yb<-top-n*pitch;seg(x1,yb,x2,yb)
 for(v in pretty(c(-lim,lim),n=3))if(v>=-lim&&v<=lim){seg(xx(v),yb,xx(v),yb-.8);txt(format(v,trim=TRUE),xx(v),yb-3,just='centre')}
 txt('Posterior mean ± SD',(x1+x2)/2,yb-7,just='centre');orders[[id]]<<-d$variant_id
 if(strip){
  limfc<-max(abs(d$logFC),na.rm=TRUE);pal<-colorRampPalette(c('#5089B5','#F8F8F4','#E6A166'))(256);fill<-pal[pmin(256,pmax(1,round((d$logFC+limfc)/(2*limfc)*255)+1))]
  x<-x2+4;gr<-rectGrob(unit(.5*pitch,'mm'),unit((n-seq_len(n)+.5)*pitch,'mm'),width=unit(pitch,'mm'),height=unit(pitch,'mm'),gp=gpar(fill=fill,col='white',lwd=.3));put(gTree(children=gList(gr),vp=viewport(x=unit(x,'mm'),y=unit(yb,'mm'),width=unit(pitch,'mm'),height=unit(n*pitch,'mm'),just=c('left','bottom'),name=paste0('matrix-',id))))
  stars<-ifelse(d$adj.P.Val<.001,'***',ifelse(d$adj.P.Val<.01,'**',ifelse(d$adj.P.Val<.05,'*','')));txt(stars,x+pitch/2,yy,just='centre',col=ifelse(abs(d$logFC)>.6*limfc,'white',ink));txt('DE',x+pitch/2,top+2,just='centre');txt(paste0('±',format(round(limfc,2),nsmall=2)),x+pitch/2,top+7,just='centre')
  metrics[[length(metrics)+1]]<<-list(matrix_id=id,panel_id=id,rows=n,columns=1,matrix_rows=n,matrix_columns=1,body_width_mm=pitch,body_height_mm=n*pitch,cell_width_mm=pitch,cell_height_mm=pitch,measurement_method='final_body_viewports_mm')
 }
}
forest(all,30,78,195,4,'b','Across tissues','all',FALSE);forest(dis,30,78,98,5,'c','Cartilage grades','grades',TRUE)
# Separate source-defined tissue groups, preserving order within each group.
top<-205
for(t in c('high_grade_cartilage','low_grade_cartilage')){
 z<-uni[uni$tissue_specific==t,];forest(z,126,168,top,2.5,if(top==205)'d'else'',if(t=='high_grade_cartilage')'High-grade-specific'else'Low-grade-specific',t,TRUE);top<-top-nrow(z)*2.5-12
}
for(i in seq_along(tc)){x<-9+((i-1)%%2)*43;y<-37-floor((i-1)/2)*8;dot(x,y,tc[i],25,1.9);txt(c('Low-grade cartilage','High-grade cartilage','Synovium','Fat pad')[i],x+3,y)}
txt('DE: log2 fold change',30,51,just='centre');for(j in 1:40){put(rectGrob(unit(17+(j-.5)*.65,'mm'),unit(47,'mm'),width=unit(.65,'mm'),height=unit(2,'mm'),gp=gpar(fill=colorRampPalette(c('#5089B5','#F8F8F4','#E6A166'))(40)[j],col=NA)))};txt('−',17,43,just='centre');txt('0',30,43,just='centre');txt('+',43,43,just='centre');txt('LFSR < 0.05',10,12);dot(7,12,ink,25,1.6);txt('LFSR ≥ 0.05',52,12);dot(49,12,'white',21,1.1)
f<-bind_rows(flat);files<-c(export(f,'effects','posterior'),export(dis,'effects','grade_DE'),export(uni,'effects','specific_DE'));g<-gTree(children=do.call(gList,glist))
finish('effects',g,files,'Source Fig3B-D public processed tables. Full17across-tissue pairs,5discordant-grade pairs and69grade-specific pairs. Posterior mean±posterior SD,not95%CI;source LFSR<.05 triangle semantics andBH-adjusted DEstar thresholds retained. Gene labels shortened to symbol;fullvariant/rsIDs retained inCSV. SourceFig3Asharingmatrixexcluded. Square DEstrips each independently centered onzero;per-panelmaximum printed above strip.',list(across=17,grades=5,specific=69,posterior_points=nrow(f)),tc,183,220,TRUE)
# Evidence: final publication source table is preferred over the older GitHub input.
start();final<-file.path(S,'OA-final-Figure4.tsv')
if(file.exists(final)){
 ev<-read.delim(final,check.names=FALSE);stopifnot(all(c('hgnc_symbol','variable','value')%in%names(ev)))
}else{
 dt<-read('prioritized_genes_scoring.tsv');scores<-c('OMIM','MR','OA.ko.mice','promoter_enhancer_HiC','active_promoter_HiC');dt$score<-rowSums(dt[,scores]);dt<-dt[dt$score>=2,];ev<-pivot_longer(dt,cols=all_of(c('coloc.HG','coloc.LG','coloc.Syn','coloc.FP',scores)),names_to='variable',values_to='value');ev$new.gene<-as.integer(ev$GO2.gene==0)
 mr<-read('mendelian_randomizaton_results.tsv');ev$plot.mr<-NA_character_
 tm<-c('coloc.HG'='high_grade_cartilage','coloc.LG'='low_grade_cartilage','coloc.Syn'='synovium','coloc.FP'='fat_pad')
 for(i in seq_len(nrow(ev)))if(ev$variable[i]%in%names(tm)&&ev$value[i]==1){sg<-unique(sign(mr$beta[mr$gene==ev$ensembl_gene_id[i]&mr$tissue==tm[ev$variable[i]]]));sg<-sg[is.finite(sg)];if(length(sg)==1)ev$plot.mr[i]<-if(sg>0)'+'else'-'}
}
genes<-sort(unique(as.character(ev$hgnc_symbol)));vars<-c('coloc.HG','coloc.LG','coloc.Syn','coloc.FP','MR','OA.ko.mice','OMIM','active_promoter_HiC','promoter_enhancer_HiC');labels<-c('HG','LG','Syn','FP','MR','KO','OMIM','Prom.','Loop');cc<-c(rep('#448BA7',4),rep('#9677B5',3),rep('#D69C4A',2));names(cc)<-vars
nleft<-ceiling(length(genes)/2)
for(block in 1:2){
 gs<-genes[seq_len(nleft)+(block-1)*nleft];gs<-gs[!is.na(gs)];x0<-24+(block-1)*66;top<-100
 txt(if(block==1)'a'else'b',x0-21,111,9,bold=TRUE)
 for(j in seq_along(vars))txt(labels[j],x0+(j-1)*4.3,top+4,just='centre',rot=45)
 for(i in seq_along(gs)){
  yy<-top-i*4.05;z<-ev[as.character(ev$hgnc_symbol)==gs[i],];seg(x0-1.7,yy,x0+36.2,yy,col='#E5E9ED',lwd=.45,lty=3);txt(gs[i],x0-3,yy,just='right',italic=TRUE,bold=any(z$new.gene==1))
  for(j in seq_along(vars)){
   v<-z[z$variable==vars[j],];stopifnot(nrow(v)==1)
   if(v$value==1){dot(x0+(j-1)*4.3,yy,cc[j],21,3.1,col=NA);if(!is.na(v$plot.mr)&&nzchar(v$plot.mr))txt(v$plot.mr,x0+(j-1)*4.3,yy,just='centre',col='white',bold=TRUE)}
  }
 }
}
for(i in 1:3){x<-9+(i-1)*43;dot(x,7,c('#448BA7','#9677B5','#D69C4A')[i],21,2,col=NA);txt(c('Colocalization','Genetic evidence','Epigenetic evidence')[i],x+3,7)}
files<-c(export(ev,'evidence','matrix'));g<-gTree(children=do.call(gList,glist));finish('evidence',g,files,paste('SourceFig4 evidencepresence dotmatrix,alphabeticalgenes splitintotwo alignedcolumns;sourcepositive/negativeMRsignsandnewgeneweight retained. FinalSourceDataused:',file.exists(final),'. No newcausalinference. Original117geneGitHubtablewouldyield38score>=2genesanddiffersfrompublished45-geneprose;all38genesinthefinalpublictableareplotted.'),list(genes=length(genes),cells=nrow(ev),final_source=file.exists(final)),c(colocalization='#448BA7',genetic='#9677B5',epigenetic='#D69C4A'),136,116,TRUE)
# CV summary boxes use supplied5/25/50/75/90percentiles; never synthesize distributions.
b<-read('cv-boxes.csv');sp<-read('cv-scatter.csv');col<-c('Protein abundance'='#4AA79B','Retention time'='#80A9C9')
orders<-list(DDA=c('F_Vanq_ecl','D_ulti_ecl','H_ulti_ecl','A_evo_ex','D_Vanq_ex','E_Vanq_ex','A_ulti_ex','G_ulti_ex','H_ulti_ex','B_ulti_HF','B_ulti_HFX','E_ulti_lumos','C_nE_tTOF','G_nLC_tTOF'),DIA=c('D_ulti_ecl','H_ulti_ecl','A_evo_ex','I_nLC_ex','D_Vanq_ex','E_Vanq_ex','A_ulti_ex','G_ulti_ex','H_ulti_ex','L_ulti_ex','L_ulti_ex_FAIMS','B_ulti_HF','B_ulti_HFX','E_ulti_lumos','L_nAcqu_tTOF','C_nE_tTOF','L_nE_tTOF','G_nLC_tTOF','J_nLC_tTOF','K_Mclass_zTOF'))
box<-function(mode,metric,tag,axis=TRUE){z<-b[b$acquisition==mode&b$metric==metric,];z$setup<-factor(z$setup,levels=orders[[mode]]);ggplot(z,aes(setup,fill=metric))+geom_boxplot(aes(ymin=q05,lower=q25,middle=median,upper=q75,ymax=q90),stat='identity',width=.64,linewidth=.35,colour=ink)+scale_fill_manual(values=col)+labs(x=NULL,y='CV (%)',title=paste(mode,'·',metric),tag=tag)+theme(legend.position='none',axis.text.x=if(axis)element_text(angle=55,hjust=1)else element_blank(),panel.grid.major.y=element_line(colour='#E8ECEF',linewidth=.2))+coord_cartesian(ylim=if(metric=='Protein abundance')c(0,115)else c(0,3.05))}
aa<-box('DDA','Protein abundance','a',FALSE)+geom_hline(yintercept=c(10,25),linetype=2,colour=c('#A5B86B','#D4A35B'),linewidth=.3);bb<-box('DIA','Protein abundance','b',FALSE)+geom_hline(yintercept=c(10,25),linetype=2,colour=c('#A5B86B','#D4A35B'),linewidth=.3)
sc<-function(mode,tag){z<-sp[sp$acquisition==mode,];ggplot(z,aes(peak_capacity,median_RT_CV,colour=LC_system,size=programmed_gradient))+geom_point(alpha=.8)+scale_colour_manual(values=c('Nanoflow'='#678CA5','Microflow'='#DE9470'),limits=c('Nanoflow','Microflow'),drop=FALSE)+scale_size_area(max_size=3.5,limits=c(11,120),breaks=c(11,60,120))+labs(x='Average peak capacity',y='Median RT CV (%)',title=mode,tag=tag,colour=NULL,size='Gradient (min)')+theme(legend.position='bottom')+guides(size=guide_legend(nrow=1,order=2),colour=guide_legend(nrow=1,order=1))}
p<-aa+bb+box('DDA','Retention time','c')+box('DIA','Retention time','d')+plot_layout(ncol=2,heights=c(.9,1.2))
files<-c(export(b,'cv','boxes'),export(sp,'cv','scatter'));finish('cv',p,files,'PublishedFig4a-d fromfinalSourceDatafigure4.68platform/metricboxsummaries.Whiskersq05/q90;boxq25/q75;mediansupplied.NorawdistributionornewCVcalculation.PublicFig_4A_C.RactuallyencodesRT(c,d);Fig_4B_D.RencodesproteinCV(a,b).Figure4e/fEXCLUDED:theiroriginalauthorscriptnotlocated,inaccordancewithuserpublicdrawingcoderequirement.Auxiliary34scatterrowsretainedandcheckedbutnotrendered.',list(boxes=nrow(b),auxiliary_scatter_not_rendered=nrow(sp)),col,183,112)
# User-approved replacement: same-paper Fig3e/f median trajectories, no missing individual lines fabricated.
z<-read('dilution-medians.csv');lev<-c('PYE1_PYE_A','PYE1_PYE_B','PYE3_PYE_A','PYE3_PYE_B','PYE9_PYE_A','PYE9_PYE_B');z$condition<-factor(z$condition,levels=lev);z$acquisition<-factor(z$acquisition,levels=c('DDA','DIA'))
p<-ggplot(z,aes(condition,median_log10_abundance,group=factor(bin),colour=bin))+geom_line(linewidth=.55)+geom_point(size=.9)+facet_grid(acquisition~setup,scales='free_y',labeller=labeller(setup=c(A_ulti_ex='A_ulti_ex (E. coli)',G_nLC_tTOF='G_nLC_tTOF (E. coli)')))+scale_colour_gradientn(colours=c('#286E8F','#43A99A','#C4C57B','#E7AC63','#D87870'),limits=c(1,10),breaks=c(1,3,5,7,10))+labs(x=NULL,y='Median log10 protein abundance',colour='Abundance decile')+scale_x_discrete(labels=c('1A','1B','3A','3B','9A','9B'))+theme(legend.position='bottom',panel.grid.major.y=element_line(colour='#E8ECEF',linewidth=.2))+guides(colour=guide_colourbar(display='rectangles',barwidth=unit(55,'mm'),barheight=unit(2,'mm'),ticks=FALSE))
files<-export(z,'dilution','medians');finish('dilution',p,files,'Userapproved replacement ofFig3a/brankwithsamepaperFig3e/f.202source medianvalues across2acquisitionmodes×2setups×10deciles×6conditions,including source missinglaterdilutions. Onlyexistingobservationsconnected;individualproteincurvesabsentandnotfabricated. No artificialzerooraxisbreak. SourceDIA_A_ulti_exbin7nonmonotoneendpointretained,notforcedtotrend.',list(observations=nrow(z)),c(low='#286E8F',middle='#C4C57B',high='#D87870'),183,140)
capture.output(sessionInfo(),file=file.path(W,'prepare-sessionInfo.txt'));cat('Prepared four source-data figures.\n')
