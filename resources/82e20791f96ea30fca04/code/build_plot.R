a<-commandArgs(TRUE);P<-normalizePath(a[1]);W<-file.path(P,'work/2026-11-06-p53-compartment-tracks');source(file.path(P,'biofigure/scripts/figure_style.R'));library(ggplot2);library(grid);library(cowplot);cowplot::set_null_device('agg');font<-bf_font('Arial')
d<-read.csv(file.path(P,'results/plot_data/p53_compartment_tracks_20261106.csv'));d$time<-factor(d$time,levels=c('0h','1h','4h','7h','10h','24h','w24h'));d$sign<-factor(d$sign,levels=c('Positive','Negative','Zero'));d$xmin<-(d$start-50000)/1e6;d$xmax<-(d$start+50000)/1e6;d$ymin<-pmin(0,d$display_score);d$ymax<-pmax(0,d$display_score)
xlim<-range(d$start)/1e6
g<-ggplot(d,aes(xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax,fill=sign))+geom_hline(yintercept=0,colour='#D3DCE0',linewidth=.18)+geom_rect(colour=NA)+scale_fill_manual(values=c(Positive='#159F96',Negative='#E36A55',Zero='white'),breaks=c('Positive','Negative'),drop=FALSE)+facet_grid(time~.)+scale_x_continuous(breaks=seq(60,90,5),expand=c(0,0))+scale_y_continuous(breaks=c(-1,0,1),expand=c(0,0))+coord_cartesian(xlim=xlim,ylim=c(-1.3,1.3),expand=FALSE,clip='on')+labs(x='Position (Mb)',y='Compartment score',fill=NULL)+theme_classic(base_size=7,base_family=font$family)+theme(strip.text=element_blank(),strip.background=element_blank(),axis.text=element_text(size=7,colour='#344956'),axis.title=element_text(size=7,colour='#344956'),axis.title.y=element_text(margin=margin(r=5)),axis.ticks=element_line(linewidth=.18,colour='#7F909A'),axis.line=element_line(linewidth=.18,colour='#7F909A'),panel.spacing.y=unit(2.7,'mm'),legend.position='none',plot.margin=margin(0,0,0,0))
col<-c('#2DAFA0','#57A9CC','#4D82C1','#6F6CB0','#9A70B8','#C46A91','#E9A042');labels<-c('Nut 0h','Nut 1h','Nut 4h','Nut 7h','Nut 10h','Nut 24h','Wash')
p<-ggdraw()+draw_plot(g,x=.02,y=.065,width=.865,height=.82)+draw_label('chr12:55,000,000-95,000,000',x=.04,y=.97,hjust=0,fontfamily=font$family,fontface='bold',size=9,colour='#263E4B')
# Rows are laid out in the actual gtable panel viewports; badge y aligns with data zero.
ragg::agg_png(file.path(W,'layout-device.png'),width=183,height=138,units='mm',res=180);gt<-ggplotGrob(g);panel<-gt$layout[grepl('^panel',gt$layout$name),];grid.newpage();grid.draw(gt);grid.force();vps<-grid.ls(print=FALSE)$name
ys<-numeric(7)
for(i in seq_len(7)){
 nm<-paste0(panel$name[i],'.',panel$t[i],'-',panel$l[i],'-',panel$b[i],'-',panel$r[i]);seekViewport(nm);loc<-deviceLoc(unit(.5,'npc'),unit(.5,'npc'),valueOnly=TRUE);ys[i]<-loc$y/(138/25.4);upViewport(0)
};dev.off()
for(i in seq_len(7)){
 yc<-.065+.82*ys[i];r<-rectGrob(gp=gpar(fill=adjustcolor(col[i],alpha.f=.23),col=NA));p<-p+draw_grob(r,x=.895,y=yc-.013,width=.092,height=.026)+draw_label(labels[i],x=.941,y=yc,fontfamily=font$family,fontface='bold',size=7,colour='#344956')
}
p<-p+draw_grob(rectGrob(gp=gpar(fill='#159F96',col=NA)),x=.755,y=.95,width=.012,height=.014)+draw_label('Positive',x=.774,y=.957,hjust=0,fontfamily=font$family,size=7,colour='#344956')+draw_grob(rectGrob(gp=gpar(fill='#E36A55',col=NA)),x=.87,y=.95,width=.012,height=.014)+draw_label('Negative',x=.889,y=.957,hjust=0,fontfamily=font$family,size=7,colour='#344956')
saveRDS(p,file.path(W,'plot.rds'));write.csv(d,file.path(W,'bar-geometry.csv'),row.names=FALSE);write.csv(data.frame(time=levels(d$time),badge_y=.065+.82*ys),file.path(W,'badge-geometry.csv'),row.names=FALSE)
ggsave(file.path(W,'preview.png'),p,width=183,height=138,units='mm',dpi=320,device=ragg::agg_png,bg='white')
