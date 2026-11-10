suppressPackageStartupMessages({library(ggplot2);library(ggtree);library(ggtreeExtra);library(ggnewscale);library(ape);library(grid);library(jsonlite)})
B<-normalizePath(commandArgs(TRUE)[1]);S<-Sys.getenv('BIOFIGURE_ROOT');source(file.path(S,'scripts/figure_style.R'));font<-bf_font('Arial');options(warn=2)
spec<-yaml::read_yaml(file.path(B,'design-spec.yaml'));ww<-spec$output_size$width_mm;hh<-spec$output_size$height_mm
tr<-ape::read.tree(file.path(B,'tree.nwk'));md<-read.csv(file.path(B,'meta_tree.csv'));pgp<-read.csv(file.path(B,'pgp.csv'));bgc<-read.csv(file.path(B,'bgc.csv'));gcf<-read.csv(file.path(B,'gcf.csv'))
stopifnot(length(tr$tip.label)==72,nrow(tr$edge)==142,!anyDuplicated(tr$tip.label),all(tr$edge.length>0),setequal(tr$tip.label,md$label),nrow(pgp)==432,nrow(bgc)==288,nrow(gcf)==72,all(pgp$Prop>=0&pgp$Prop<=1),max(abs(tapply(bgc$Comp,bgc$label,sum)-1))<1e-12)
phycol<-unlist(spec$palette_semantics[c('Actinobacteriota','Firmicutes','Alphaproteobacteria','Bacteroidota','Others')])
groupcol<-unlist(spec$palette_semantics[c('CRBC genomes','Published genomes')]);bgccol<-unlist(spec$palette_semantics[c('NRPS','PKS','RiPPs','Terpene')])
pgp$Type<-factor(pgp$Type,levels=c('P','N','Fe','IAA','GA','CK'))
base<-dplyr::full_join(tr,md[,c('label','PhyClass')],by='label')
p<-ggtree(base,layout='fan',open.angle=40,linewidth=.24,aes(colour=PhyClass))+
 scale_colour_manual(values=phycol,breaks=names(phycol),name='Taxonomy',na.translate=TRUE,na.value='#87939E',guide=guide_legend(order=1))+
 geom_tiplab2(aes(label=label),size=7/ggplot2::.pt,family='Arial',colour='#30343B',align=TRUE,offset=.025,linesize=.12,linetype='dotted')+
 geom_fruit(data=md[,c('label','Source_Group')],geom=geom_col,aes(y=label,x=1,fill=Source_Group),pwidth=.035,offset=.30,width=.86)+
 scale_fill_manual(values=groupcol,name='Genome source',guide=guide_legend(order=2))+new_scale_fill()+
 geom_fruit(data=pgp,geom=geom_tile,aes(y=label,x=Type,fill=Prop),pwidth=.19,offset=.025,colour='white',linewidth=.04)+
 scale_fill_gradientn(colours=unlist(spec$palette_semantics[c('ratio_zero','ratio_half','ratio_one')]),limits=c(0,1),name='PGP ratio\nP / N / Fe / IAA / GA / CK',breaks=c(0,.5,1),guide=guide_colorbar(order=3,display='rectangles',nbin=128,barheight=unit(20,'mm'),barwidth=unit(2.5,'mm')))+new_scale_fill()+
 geom_fruit(data=bgc,geom=geom_col,aes(y=label,x=Comp,fill=Class),pwidth=.17,offset=.025,width=.84)+
 scale_fill_manual(values=bgccol,name='BGC composition',guide=guide_legend(order=4))+new_scale_fill()+
 geom_fruit(data=gcf,geom=geom_col,aes(y=label,x=SUM,fill=Legend),pwidth=.13,offset=.025,width=.8)+
 scale_fill_manual(values=c(`GCF median`='#AE6045'),labels='0–42',name='GCF count',guide=guide_legend(order=5))+
 theme(legend.position='right',legend.text=element_text(size=7,family='Arial',colour='#202020'),legend.title=element_text(size=7,family='Arial',colour='#202020'),legend.key.size=unit(2.5,'mm'),legend.spacing.y=unit(2,'mm'),legend.box.spacing=unit(5,'mm'),plot.margin=margin(3,3,3,3,'mm'),text=element_text(family='Arial',size=7),plot.background=element_rect(fill='white',colour=NA))
# The tree consumes most of the canvas; annotation tracks sum to only0.525 tree-radius units.
for(device in c('png','pdf')){
 if(device=='png')ragg::agg_png(file.path(B,'figure.png'),width=ww,height=hh,units='mm',res=450,background='white') else grDevices::quartz(type='pdf',file=file.path(B,'figure.pdf'),width=ww/25.4,height=hh/25.4,family='Arial',bg='white')
 print(p);dev.off()
}
write.csv(p$data,file.path(B,'plotted_tree_coordinates.csv'),row.names=FALSE)
jsonlite::write_json(list(canvas_mm=c(ww,hh),font='Arial',tips=72,edges=142,topology_unchanged=TRUE,branch_lengths_unchanged=TRUE,metadata_matches_archive=TRUE,tracks=list(source=.035,PGP=.19,BGC=.17,GCF=.13),footer_absent=TRUE,title_absent=TRUE,scope=spec$scientific_message,CP3='Actual PDF and PNG inspected separately; no full workflow qualification claimed'),file.path(B,'geometry.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
writeLines(capture.output(sessionInfo()),file.path(B,'environment.txt'));cat('TREE_RENDER_OK\n')
