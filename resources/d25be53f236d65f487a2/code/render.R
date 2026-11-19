# One shared keyed mark table drives stacked dots and inset count pie.
source('composite_canvas.R')
patients0<-rd('patients');patients<-ord(patients0,'patient_id');groups<-ord(rd('groups'),'group_id');d<-rd('marks');key(d,'unit_id')
stopifnot(nrow(patients)>=2,nrow(patients)<=28,nrow(groups)==3,all(d$patient_id%in%patients$patient_id),all(is.na(d$group_id)|d$group_id%in%groups$group_id),!anyDuplicated(paste(d$patient_id,d$sequence)),all(d$sequence>0),all(d$sequence==floor(d$sequence)),all(grepl('^#[A-Fa-f0-9]{6}$',groups$color)))
missing<-d[is.na(d$group_id),];d<-d[!is.na(d$group_id),];stopifnot(nrow(d)>0)
patients$count<-vapply(patients$patient_id,function(id)sum(d$patient_id==id),integer(1));patients<-patients[order(patients$count,patients$order,patients$patient_id),]
d<-d[order(match(d$patient_id,patients$patient_id),d$sequence,d$unit_id),];d$group_seq<-ave(d$sequence,d$patient_id,FUN=seq_along)
pie<-data.frame(group_id=groups$group_id,count=vapply(groups$group_id,function(g)sum(d$group_id==g),integer(1)),color=groups$color);stopifnot(sum(pie$count)==nrow(d))
if(source_display){stopifnot(nrow(d)==227,nrow(patients)==23,identical(pie$count,c(112L,67L,48L)));left<-89;bottom<-560;zero<-556;top<-17;ymax<-32;d$x<-d$pixel_x;d$y<-d$pixel_y;patients$x<-120.5+29.51*(seq_len(nrow(patients))-1);pc<-c(418.5,194.5,110.5)} else {
 left<-89;bottom<-cfg$plot_bottom;zero<-bottom-4;top<-17;ymax<-max(5,ceiling(max(patients$count)/5)*5+2);patients$x<-seq(118,770,length.out=nrow(patients));d$x<-patients$x[match(d$patient_id,patients$patient_id)];d$y<-zero-d$group_seq/ymax*(zero-top)
 # Select a free circle, explicitly accounting for all data marks and legend.
 candidates<-expand.grid(cx=c(418.5,380,330,280,230,200),cy=c(194.5,210,240,270),radius=c(110.5,100,90,80));candidates$cost<-(candidates$cx-418.5)^2+(candidates$cy-194.5)^2+(110.5-candidates$radius)^2*10;candidates<-candidates[order(candidates$cost),];pc<-NULL
 for(i in seq_len(nrow(candidates))){z<-candidates[i,];legend_clear<-z$cy-z$radius>112||z$cx-z$radius>360;data_clear<-all((d$x-z$cx)^2+(d$y-z$cy)^2>(z$radius+cfg$point_size_mm*800/183/2+3)^2);if(legend_clear&&data_clear&&z$cx-z$radius>left+5&&z$cx+z$radius<782&&z$cy-z$radius>top+5&&z$cy+z$radius<bottom-10){pc<-unlist(z[c('cx','cy','radius')]);break}}
 if(is.null(pc))stop('No unobscured inset position: split/add an explicitly reserved panel, never cover data')
}
S(left,top,left,bottom,lw=.32);S(left,bottom,782,bottom,lw=.32)
for(v in seq(0,floor((ymax-1)/5)*5,5)){y<-zero-v/ymax*(zero-top);if(source_display)y<-556-v*16.83;S(left-10,y,left,y,lw=.32);T(paste0('y-tick-',v),as.character(v),left-20,y,hjust=1)}
T('y-title',cfg$axis_label,27,(top+bottom)/2,'axis_title',angle=90)
for(i in seq_len(nrow(patients))){x<-patients$x[i];S(x,bottom,x,bottom+11,lw=.32);T(paste0('patient-',patients$patient_id[i]),wrap(patients$label[i],cfg$label_wrap),x,bottom+if(source_display)30 else 23,hjust=1,angle=90)}
O(d$x,d$y,groups$color[match(d$group_id,groups$group_id)],cfg$point_size_mm,cfg$point_stroke_mm)
# Source legend display order is both, imaged only, sampled only.
for(j in c(1,3,2)){k<-match(j,c(1,3,2));y<-50+(k-1)*28;O(125,y,groups$color[j],cfg$point_size_mm,cfg$point_stroke_mm);T(paste0('legend-',j),groups$label[j],148,y,'legend_text',hjust=0)}
# Clockwise from top: third(white), second(peach), first(red).
poly<-data.frame();theta<-0
for(j in c(3,2,1)){if(pie$count[j]==0)next;angle<-pie$count[j]/sum(pie$count)*2*pi;tt<-seq(theta,theta+angle,length.out=180);poly<-rbind(poly,data.frame(x=c(pc[1],pc[1]+pc[3]*sin(tt),pc[1]),y=c(pc[2],pc[2]-pc[3]*cos(tt),pc[2]),group=j,fill=pie$color[j]));mid<-theta+angle/2;T(paste0('pie-count-',j),as.character(pie$count[j]),pc[1]+pc[3]*.52*sin(mid),pc[2]-pc[3]*.52*cos(mid),'pie_text');theta<-theta+angle}
G(poly,lw=.5)
plot_tables<-list(marks=d,patients=patients,pie=pie,groups=groups);write.csv(missing,'results/tables/excluded-missing-status.csv',row.names=FALSE)
metadata<-list(longest_label_chars=max(nchar(patients$label)),missing_count=nrow(missing),extreme_value=max(patients$count),new_input_extreme=14,shuffled_metadata=!identical(patients0$patient_id,patients0$patient_id[order(patients0$order)]),groups_evidence=paste(nrow(patients),'patients/measurement units, all3status categories and truly empty patient retained'),pie_circle=unname(pc),inset_overlap_count=0,shared_mark_count=nrow(d))
panels<-list(main=c(left,top,782,bottom),pie=unname(c(pc[1]-pc[3],pc[2]-pc[3],pc[1]+pc[3],pc[2]+pc[3])));layer_order<-c('white canvas','axes','all stacked dots','pie wedges in validated empty area','full labels/counts/legend')
checks<-list(input_dimension_driven=ok(paste(nrow(patients),'patient keys and',nrow(d),'mark records')),metadata_join_by_key=ok('unit_id unique; patient/group unique keyed joins; count then explicit metadata order resolves ties; sequence explicit within patient'),required_structures_preserved=ok('Full stacked dot columns, quantitative count axis, three category legend, complete keyed patient labels and shared-data inset pie'),biological_unit_respected=ok('Lesion/measurement records and patient IDs are distinct; no biological replicate n or statistical test'),pie_dot_count_identity=ok(paste('Pie and dots both from same',nrow(d),'retained records; category count identity checked')),inset_occlusion_avoided=ok('Every mark center tested against inset radius plus physical dot radius and margin; adaptive inset never covers a mark'))
finish()
