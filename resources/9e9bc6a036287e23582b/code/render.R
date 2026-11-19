suppressPackageStartupMessages({library(survival);library(grid);library(jsonlite);library(systemfonts)})
args<-commandArgs(TRUE);root<-normalizePath(args[1]);dir.create(file.path(root,'results'),showWarnings=FALSE)
d<-survival::lung;d$patient_id<-seq_len(nrow(d));d$sex<-factor(d$sex,c(1,2),c('Male','Female'))
stopifnot(nrow(d)==228,identical(as.integer(table(d$sex)),c(138L,90L)),sum(d$status==2)==165)
write.csv(d,file.path(root,'lung.csv'),row.names=FALSE)
rows<-list();diagnostics<-list()
add<-function(label,z=NULL,header=FALSE){
 i<-length(rows)+1L
 if(header){rows[[i]]<<-data.frame(row_id=i,label=label,header=TRUE,hr=NA,lo=NA,hi=NA,p=NA,female='',male='');return(invisible(NULL))}
 z<-z[complete.cases(z[,c('time','status','sex')]),];fit<-coxph(Surv(time,status==2)~sex,data=z,ties='efron',x=TRUE)
 sm<-summary(fit);beta<-coef(fit)[1];se<-sqrt(vcov(fit)[1,1]);ci<-exp(beta+c(-1,1)*qnorm(.975)*se);p<-2*pnorm(-abs(beta/se));stopifnot(is.finite(se),se>0,abs(p-sm$coefficients[1,'Pr(>|z|)'])<1e-12,all(abs(ci-sm$conf.int[1,c('lower .95','upper .95')])<1e-10))
 count<-function(g)sprintf('%d/%d',sum(z$status[z$sex==g]==2),sum(z$sex==g))
 ph<-cox.zph(fit);diagnostics[[i]]<<-list(row_id=i,label=label,n=nrow(z),events=sum(z$status==2),beta=unname(beta),SE=unname(se),ph_test_p=unname(ph$table[1,3]),ph_assumption_flag=unname(ph$table[1,3]<.05),patients=z$patient_id)
 rows[[i]]<<-data.frame(row_id=i,label=label,header=FALSE,hr=exp(beta),lo=ci[1],hi=ci[2],p=p,female=count('Female'),male=count('Male'))
}
add('Overall',d)
configs<-list(list('Age (years)','age',70,'70 or younger','Older than 70'),list('ECOG status','ph.ecog',NULL),list('Physician Karnofsky score','ph.karno',80,'80 or lower','Above 80'),list('Patient Karnofsky score','pat.karno',80,'80 or lower','Above 80'),list('Meal calories (kcal)','meal.cal',800,'800 or lower','Above 800'),list('Weight loss (lb)','wt.loss',10,'10 or lower','Above 10'))
for(g in configs){add(g[[1]],header=TRUE);z<-d[!is.na(d[[g[[2]]]]),];if(g[[2]]=='ph.ecog'){for(k in 0:2)add(c('Asymptomatic','Symptomatic, ambulatory','In bed <50% of day')[k+1],z[z$ph.ecog==k,])}else{add(g[[4]],z[z[[g[[2]]]]<=g[[3]],]);add(g[[5]],z[z[[g[[2]]]]>g[[3]],])}}
r<-do.call(rbind,rows);stopifnot(nrow(r)==20,sum(!r$header)==14);r$hr_text<-ifelse(r$header,'',sprintf('%.2f (%.2f–%.2f)',r$hr,r$lo,r$hi));r$p_text<-ifelse(r$header,'',ifelse(r$p<.001,'<0.001',sprintf('%.3f',r$p)))
write.csv(r,file.path(root,'results.csv'),row.names=FALSE)
write_json(list(dataset='survival::lung',package_version=as.character(packageVersion('survival')),event_definition='status==2',comparison='Female / Male',units=list(time='days',wt.loss='pounds'),subgroup_missingness=sapply(d[c('age','ph.ecog','ph.karno','pat.karno','meal.cal','wt.loss')],function(x)sum(is.na(x))),ecog3_excluded_only_for_ecog_rows=1,model_diagnostics=Filter(Negate(is.null),diagnostics),claims='Exploratory observational Cox examples; unadjusted two-sided Wald P and pointwise95% CI; PH tests recorded, no causal or subgroup-interaction claim'),file.path(root,'scientific-review.json'),pretty=TRUE,auto_unbox=TRUE)
font<-match_fonts('Arial');stopifnot(grepl('Arial',basename(font$path)))
W<-183;H<-134;plotleft<-100;plotright<-137;xt<-function(hr)plotleft+(log10(hr)-log10(.2))/(log10(2)-log10(.2))*(plotright-plotleft)
stopifnot(all(r$lo[!r$header]>=.2),all(r$hi[!r$header]<=2));metrics<-list()
render<-function(){
 grid.newpage();pushViewport(viewport(x=0,y=0,width=unit(W,'mm'),height=unit(H,'mm'),just=c('left','bottom'),xscale=c(0,W),yscale=c(0,H)))
 grid.rect(gp=gpar(fill='white',col=NA));text<-function(t,x,y,size=7,bold=FALSE,align='left'){grid.text(t,x=unit(x,'mm'),y=unit(y,'mm'),just=align,gp=gpar(fontfamily='Arial',fontsize=size,fontface=if(bold)2 else 1))}
 text('Subgroup',3,129,bold=TRUE);text('Female',68,129,bold=TRUE,align='centre');text('Male',88,129,bold=TRUE,align='centre');text('Events / total',78,124,size=7,align='centre');text('Female vs male',118.5,129,bold=TRUE,align='centre');text('HR (95% CI)',140,129,bold=TRUE);text('P (raw)',180,129,bold=TRUE,align='right')
 grid.lines(unit(c(3,180),'mm'),unit(c(121.7,121.7),'mm'),gp=gpar(col='#454545',lwd=.5))
 yy<-118-(r$row_id-1)*5.1
 for(i in seq_len(nrow(r))){y<-yy[i];if(i%%2==1||r$header[i])grid.rect(x=unit(91.5,'mm'),y=unit(y,'mm'),width=unit(177,'mm'),height=unit(5.1,'mm'),gp=gpar(fill='#EEF1F1',col=NA))
 text(r$label[i],if(r$header[i]||i==1)3 else 5,y,bold=r$header[i]||i==1)
 if(!r$header[i]){text(r$female[i],68,y,align='centre');text(r$male[i],88,y,align='centre');grid.lines(unit(xt(c(r$lo[i],r$hi[i])),'mm'),unit(c(y,y),'mm'),gp=gpar(col='#202A2E',lwd=.7));grid.segments(unit(xt(c(r$lo[i],r$hi[i])),'mm'),unit(y-.5,'mm'),unit(xt(c(r$lo[i],r$hi[i])),'mm'),unit(y+.5,'mm'),gp=gpar(col='#202A2E',lwd=.6));grid.points(unit(xt(r$hr[i]),'mm'),unit(y,'mm'),pch=15,size=unit(1.25,'mm'),gp=gpar(col='#202A2E'));text(r$hr_text[i],140,y);text(r$p_text[i],180,y,align='right')}
 }
 grid.lines(unit(rep(xt(1),2),'mm'),unit(c(yy[20]-2.55,120.55),'mm'),gp=gpar(col='#555555',lwd=.6,lty=2))
 ticks<-c(.25,.5,1,2);y<-13;grid.lines(unit(c(plotleft,plotright),'mm'),unit(c(y,y),'mm'),gp=gpar(lwd=.65));for(t in ticks){grid.lines(unit(rep(xt(t),2),'mm'),unit(c(y,y-1.2),'mm'),gp=gpar(lwd=.6));text(format(t,trim=TRUE),xt(t),9,align='centre')}
 # Actual glyph widths measured at output device size; fail on a column overflow.
 widths<-sapply(r$label,function(t)convertWidth(grobWidth(textGrob(t,gp=gpar(fontfamily='Arial',fontsize=7))),'mm',valueOnly=TRUE));hrwidth<-max(sapply(r$hr_text,function(t)convertWidth(grobWidth(textGrob(t,gp=gpar(fontfamily='Arial',fontsize=7))),'mm',valueOnly=TRUE)))
 stopifnot(max(widths)+5<58,hrwidth<28);metrics<<-list(canvas_mm=c(W,H),row_count=20,row_pitch_mm=5.1,label_max_width_mm=max(widths),hr_text_max_width_mm=hrwidth,forest_mm=c(plotleft,plotright),intervals_within_axis=TRUE,font='Arial',font_path=font$path,footer_absent=TRUE);popViewport()
}
ragg::agg_png(file.path(root,'figure.png'),width=W,height=H,units='mm',res=400,background='white');render();dev.off()
quartz(type='pdf',file=file.path(root,'figure.pdf'),width=W/25.4,height=H/25.4,family='Arial');render();dev.off()
svglite::svglite(file.path(root,'figure.svg'),width=W/25.4,height=H/25.4,bg='white');render();dev.off()
write_json(metrics,file.path(root,'geometry.json'),pretty=TRUE,auto_unbox=TRUE);writeLines(capture.output(sessionInfo()),file.path(root,'environment.txt'));cat('FOREST_MODELS_AND_RENDER_OK\n')
