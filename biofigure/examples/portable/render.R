# SPDX-License-Identifier: MIT
# First-party, self-contained demonstration renderer. Data are synthetic.
# Analysis precedes CP2. Rendering requires a fresh single-use authorization.
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==6L)
phase<-args[1]; case<-args[2]; out<-normalizePath(args[3],mustWork=TRUE)
skill<-normalizePath(args[4],mustWork=TRUE); input<-normalizePath(args[5],mustWork=TRUE)
formats<-strsplit(args[6],',',fixed=TRUE)[[1]]
stopifnot(phase %in% c('analyze','render'),all(formats %in% c('png','pdf')))
source(file.path(skill,'scripts','figure_style.R'))
audit<-file.path(out,'_audit'); dir.create(audit,showWarnings=FALSE)
config_path<-file.path(audit,'render-config.json')
config<-jsonlite::fromJSON(config_path,simplifyVector=FALSE)
metadata<-jsonlite::fromJSON(config$metadata_path,simplifyVector=FALSE)
font<-bf_font('Arial')
bound<-function(p)list(path=normalizePath(p,mustWork=TRUE),sha256=digest::digest(file=p,algo='sha256'))
write_json<-function(x,p)jsonlite::write_json(x,p,pretty=TRUE,auto_unbox=TRUE,digits=NA,null='null')
pdf_begin<-function(path) {
  bf_pdf_open(path,a$width_mm,a$height_mm,font)
}
pdf_embed<-function(path) {
  result<-bf_pdf_finalize(path,font,a$width_mm,a$height_mm)
  write_json(result,paste0(path,'.pdf-audit.json'))
}
# Never let read.csv coerce identifiers such as 01 and 1 into the same ID.
input_binding<-bound(input)
d<-read.csv(input,check.names=FALSE,stringsAsFactors=FALSE,colClasses='character',fileEncoding='UTF-8')
numeric_columns<-switch(case,boxplot='Expression',heatmap=names(d)[-1],`dense-heatmap`=names(d)[-1],
  bubble=c('Average','Fraction'),volcano=c('log2FC','SE'),
  synteny=c('AStart','AEnd','BStart','BEnd','ALength','BLength'),phylogeny=character())
for(nm in numeric_columns) {
  d[[nm]]<-suppressWarnings(as.numeric(d[[nm]]))
  if(any(!is.finite(d[[nm]])))stop(paste('nonfinite numeric input:',nm))
}
if(!identical(input_binding,bound(input)))stop('input changed while reading; analyze and render must use one frozen input')
group_colours<-c(Control='#38658B',Treatment='#B66E83',Low='#9FAFBD',Medium='#7C96AE',High='#86749E',Recovery='#C18C79')
palette5<-c('#285C8D','#93B8D1','#FFFFFF','#BDABD4','#674788')
analysis_path<-file.path(audit,'analysis.json')

make_ggplot<-function(a) {
  library(ggplot2)
  base<-bf_theme(font,7)
  if(case=='boxplot') {
    d$Group<-factor(d$Group,levels=unlist(a$groups))
    colours<-setNames(unlist(a$group_colours),levels(d$Group))
    d$Soft<-bf_fill_alpha(colours[as.character(d$Group)],.32)
    d$Point<-bf_fill_alpha(colours[as.character(d$Group)],.70)
    p<-ggplot(d,aes(Group,Expression))+
      geom_boxplot(aes(fill=Soft),width=.38,linewidth=.30,colour='#30343B',outlier.shape=NA,staplewidth=.35)+
      geom_point(aes(fill=Point),position=position_jitter(width=.085,height=0,seed=326),shape=21,size=1.65,stroke=.25,colour='#30343B')+
      scale_fill_identity()+
      scale_y_continuous(breaks=unlist(a$ticks),labels=unlist(a$tick_labels),limits=unlist(a$ylim),expand=expansion(0))+
      scale_x_discrete(expand=expansion(add=.55))+
      annotate('segment',x=1,xend=2,y=a$bracket_y,yend=a$bracket_y,linewidth=.25,alpha=1)+
      annotate('segment',x=c(1,2),xend=c(1,2),y=a$bracket_y,yend=a$bracket_y-a$bracket_tip,linewidth=.25,alpha=1)+
      annotate('text',x=1.5,y=a$p_y,label=a$p_label,family=font$family,size=7/ggplot2::.pt)+
      labs(x=NULL,y=a$y_label)+base+theme(legend.position='none')
    # Every actual point/line/fill data layer has a role and independently checked alpha.
    contracts<-list(list(layer=1,role='distribution-fill',fill_alpha=.32,edge_alpha=1),
      list(layer=2,role='replicate-point',fill_alpha=.70,edge_alpha=1),
      list(layer=3,role='summary-line',alpha=1),list(layer=4,role='summary-line',alpha=1))
  } else if(case=='bubble') {
    d$Group<-factor(d$Group,levels=unlist(a$groups));d$Gene<-factor(d$Gene,levels=rev(unlist(a$genes)))
    p<-ggplot(d,aes(Group,Gene))+geom_point(aes(size=Fraction,fill=Average),shape=21,colour='#20242A',stroke=.25)+
      scale_size_area(name='Expressing (%)',limits=c(0,100),breaks=c(25,50,75,100),max_size=3.5)+
      scale_fill_gradientn(name='Mean expression',colours=palette5,limits=c(-2,2),breaks=c(-2,0,2))+
      scale_x_discrete(expand=expansion(add=.5))+scale_y_discrete(expand=expansion(add=.5))+
      guides(fill=guide_colourbar(order=1,barheight=grid::unit(15,'mm'),barwidth=grid::unit(2,'mm')),
        size=guide_legend(order=2,override.aes=list(fill='#FFFFFF')))+
      labs(x=NULL,y=NULL)+base+theme(axis.line=element_blank(),axis.ticks=element_blank(),
        legend.box.spacing=unit(3,'mm'),legend.spacing.y=unit(3,'mm'),legend.key.height=unit(4,'mm'))
    contracts<-list(list(layer=1,role='continuous-bubble',fill_alpha=1,edge_alpha=1))
  } else if(case=='volcano') {
    d<-read.csv(file.path(audit,'statistics.csv'),check.names=FALSE)
    d$State<-factor(d$State,levels=c('Other','Down','Up'))
    d$LabelDown<-ifelse(d$State=='Down'&d$Gene %in% unlist(a$label_genes),d$Gene,'')
    d$LabelUp<-ifelse(d$State=='Up'&d$Gene %in% unlist(a$label_genes),d$Gene,'')
    p<-ggplot(d,aes(log2FC,NegLog10FDR))+
      geom_point(data=d[d$State=='Other',],colour='#B6BEC6',alpha=.22,size=.43)+
      geom_point(data=d[d$State!='Other',],aes(colour=State),alpha=.45,size=.65)+
      geom_hline(yintercept=-log10(.05),colour='#8B929B',linewidth=.25,linetype='dashed')+
      geom_vline(xintercept=c(-1,1),colour='#8B929B',linewidth=.25,linetype='dashed')+
      ggrepel::geom_text_repel(data=d,aes(label=LabelDown),xlim=c(-4.6,-1.6),nudge_x=-.35,
        family=font$family,size=6.5/ggplot2::.pt,colour='#252A30',seed=61,
        box.padding=.4,point.padding=.25,min.segment.length=0,segment.size=.22,
        max.overlaps=Inf,max.iter=20000)+
      ggrepel::geom_text_repel(data=d,aes(label=LabelUp),xlim=c(1.6,4.6),nudge_x=.35,
        family=font$family,size=6.5/ggplot2::.pt,colour='#252A30',seed=62,
        box.padding=.4,point.padding=.25,min.segment.length=0,segment.size=.22,
        max.overlaps=Inf,max.iter=20000)+
      scale_colour_manual(values=c(Down='#376B95',Up='#BB6D7C'),breaks=c('Down','Up'),drop=TRUE)+
      scale_x_continuous(breaks=unlist(a$x_ticks),labels=unlist(a$x_labels),limits=unlist(a$xlim),expand=expansion(0))+
      scale_y_continuous(breaks=unlist(a$ticks),labels=unlist(a$tick_labels),limits=unlist(a$ylim),expand=expansion(0))+
      labs(x='log2 fold change',y='-log10 FDR',colour=NULL)+base+
      theme(legend.position='top',legend.justification='left',legend.margin=margin(0,0,1,0,'mm'),legend.key.height=unit(2,'mm'))+
      guides(colour=guide_legend(override.aes=list(alpha=.8,size=1.4)))
    contracts<-list(list(layer=1,role='dense-point',alpha=.22),list(layer=2,role='dense-point',alpha=.45))
  } else if(case=='phylogeny') {
    tr<-ape::read.tree(text=d$Newick[1]); n<-length(tr$tip.label)
    dep<-ape::node.depth.edgelength(tr); ypos<-numeric(length(dep)); ypos[seq_len(n)]<-rev(seq_len(n))
    edges<-tr$edge
    pending<-unique(edges[,1]); while(length(pending)) {
      progress<-FALSE
      for(node in pending) {
        children<-edges[edges[,1]==node,2]
        if(all(ypos[children]>0)) {ypos[node]<-mean(range(ypos[children]));pending<-setdiff(pending,node);progress<-TRUE}
      }
      if(!progress)stop('tree contains unresolved or cyclic nodes')
    }
    horizontal<-data.frame(x=dep[edges[,1]],xend=dep[edges[,2]],y=ypos[edges[,2]],yend=ypos[edges[,2]])
    parents<-unique(edges[,1]); vertical<-do.call(rbind,lapply(parents,function(node) {
      yy<-ypos[edges[edges[,1]==node,2]];data.frame(x=dep[node],xend=dep[node],y=min(yy),yend=max(yy))
    }))
    tips<-data.frame(x=dep[seq_len(n)],y=ypos[seq_len(n)],label=tr$tip.label,
      clade=ifelse(seq_len(n)<=n/2,'Clade I','Clade II'))
    p<-ggplot()+geom_segment(data=rbind(horizontal,vertical),aes(x=x,xend=xend,y=y,yend=yend),linewidth=.30,colour='#545B63',alpha=1)+
      geom_point(data=tips,aes(x,y,fill=clade),shape=21,size=1.45,stroke=.2,colour='#30343B')+
      geom_text(data=tips,aes(x=a$label_x,y=y,label=label),hjust=0,family=font$family,size=7/ggplot2::.pt)+
      scale_fill_manual(values=c('Clade I'='#487B8D','Clade II'='#AF859C'),name=NULL)+
      scale_x_continuous(limits=c(0,a$xmax),breaks=unlist(a$x_ticks),labels=unlist(a$x_labels),expand=expansion(0))+
      scale_y_continuous(limits=c(.4,n+.6),expand=expansion(0))+labs(x='Branch length (a.u.)',y=NULL)+base+
      theme(axis.text.y=element_blank(),axis.ticks.y=element_blank(),axis.line.y=element_blank(),
        legend.position='top',legend.justification='left',legend.key.height=unit(2,'mm'))
    contracts<-list(list(layer=1,role='summary-line',alpha=1),list(layer=2,role='replicate-point',
      fill_alpha=1,edge_alpha=1,override_reason='Categorical tree tip markers encode membership, not overlapping replicate density.'))
  } else stop('not a ggplot case')
  list(plot=p,contracts=contracts)
}

if(phase=='analyze') {
  a<-list(schema_version=1,case=case,font_family='Arial',width_mm=90,height_mm=75,renderer='ggplot2',input_binding=input_binding,
    statistics=NULL,heatmap_cells=NULL,semantic_colors=list())
  if(case=='boxplot') {
    groups<-unique(d$Group);stopifnot(length(groups)==2,all(is.finite(d$Expression)),!anyDuplicated(d$Sample))
    values<-lapply(groups,function(g)d$Expression[d$Group==g]);stopifnot(all(lengths(values)>=2))
    test<-t.test(values[[2]],values[[1]],alternative='two.sided',var.equal=FALSE)
    value_unit<-metadata$value_unit
    if(is.null(value_unit)&&isTRUE(metadata$synthetic)&&identical(metadata$units,'arbitrary units'))value_unit<-'a.u.'
    if(is.null(value_unit)||!is.character(value_unit)||!nzchar(trimws(value_unit)))stop('NEEDS_SPEC: measurement value_unit must be explicit')
    a$value_unit<-value_unit;a$y_label<-paste0('Expression (',value_unit,')')
    stats<-data.frame(comparison=paste(groups[2],'-',groups[1]),method='Welch two-sample t-test',
      n_reference=length(values[[1]]),n_treatment=length(values[[2]]),mean_difference=mean(values[[2]])-mean(values[[1]]),
      ci_low=test$conf.int[1],ci_high=test$conf.int[2],p_value=test$p.value,df=unname(test$parameter),
      adjustment='none: single prespecified contrast',experimental_unit=metadata$experimental_unit,
      independence=metadata$independence,measurement_unit=value_unit)
    write.csv(stats,file.path(audit,'statistics.csv'),row.names=FALSE)
    rr<-range(d$Expression);span<-diff(rr);stopifnot(span>0)
    a$groups<-groups;a$group_colours<-setNames(c('#38658B','#B66E83'),groups)
    a$semantic_colors<-as.list(a$group_colours)
    a$ticks<-pretty(rr,n=4);a$ticks<-a$ticks[a$ticks>=rr[1]-.08*span&a$ticks<=rr[2]+.12*span]
    a$tick_labels<-format(a$ticks,trim=TRUE,scientific=FALSE)
    a$ylim<-c(min(rr[1]-.10*span,min(a$ticks)),rr[2]+.33*span)
    a$bracket_y<-rr[2]+.14*span;a$bracket_tip<-.035*span;a$p_y<-rr[2]+.24*span
    a$p_label<-if(test$p.value<.001)'P < 0.001' else sprintf('P = %.3f',test$p.value)
    a$statistics<-c(bound(file.path(audit,'statistics.csv')),list(method=stats$method,comparison=stats$comparison,p_semantics='raw'))
    a$allowed_text<-unique(c(groups,a$y_label,a$tick_labels,a$p_label))
  } else if(case %in% c('heatmap','dense-heatmap')) {
    m<-as.matrix(d[,-1,drop=FALSE]);rownames(m)<-d$Gene;stopifnot(all(is.finite(m)),!anyDuplicated(d$Gene))
    z<-t(scale(t(m)));stopifnot(all(is.finite(z)))
    write.csv(data.frame(Gene=rownames(z),z,check.names=FALSE),file.path(audit,'heatmap-values.csv'),row.names=FALSE)
    groups<-rep(c('Control','Low','High','Recovery'),each=ncol(m)/4)
    stopifnot(ncol(m)%%4==0)
    dense<-case=='dense-heatmap'
    cell<-2;bw<-ncol(m)*cell+3*1.5;bh<-nrow(m)*cell
    if(dense){bw<-48;bh<-106;a$height_mm<-135}
    a$groups<-unique(groups);a$sample_groups<-groups;a$height_mm<-if(dense)135 else 82
    a$semantic_colors<-as.list(c(Control='#6C8DA5',Low='#BDCFD9',High='#A58BB8',Recovery='#D4B6A6',
      `Z=-2`=palette5[1],`Z=-1`=palette5[2],`Z=0`=palette5[3],`Z=1`=palette5[4],`Z=2`=palette5[5]))
    a$renderer<-'ComplexHeatmap';a$heatmap_cells<-list(rows=nrow(m),columns=ncol(m),
      mode=if(dense)'dense-overview' else 'square',body_width_mm=bw,body_height_mm=bh,row_gap_mm=0,column_gap_mm=1.5)
    a$allowed_text<-c('Row Z-score','Group',unique(groups),'-2','0','2',if(!dense)c(rownames(m),colnames(m)))
  } else if(case=='bubble') {
    stopifnot(all(is.finite(d$Average)),all(d$Average>=-2&d$Average<=2),all(d$Fraction>=0&d$Fraction<=100))
    a$height_mm<-92;a$groups<-unique(d$Group);a$genes<-unique(d$Gene)
    a$semantic_colors<-as.list(setNames(palette5,c('expression=-2','expression=-1','expression=0','expression=1','expression=2')))
    a$allowed_text<-c(a$groups,a$genes,'Expressing (%)','Mean expression','25','50','75','100','-2','0','2')
  } else if(case=='volcano') {
    stopifnot(!anyDuplicated(d$Gene),all(is.finite(d$log2FC)),all(is.finite(d$SE)),all(d$SE>0))
    d$P<-2*pnorm(-abs(d$log2FC/d$SE));d$FDR<-p.adjust(d$P,'BH');d$NegLog10FDR<--log10(pmax(d$FDR,.Machine$double.xmin))
    d$State<-ifelse(d$FDR<.05&d$log2FC>1,'Up',ifelse(d$FDR<.05&d$log2FC< -1,'Down','Other'))
    write.csv(d,file.path(audit,'statistics.csv'),row.names=FALSE)
    a$x_ticks<-seq(-4,4,2);a$x_labels<-as.character(a$x_ticks);a$xlim<-c(-4.8,4.8)
    ymax<-ceiling(max(d$NegLog10FDR)/5)*5;a$ticks<-seq(0,ymax,by=5);a$tick_labels<-as.character(a$ticks);a$ylim<-c(0,ymax*1.10)
    labs<-unlist(lapply(c('Down','Up'),function(g)head(d$Gene[order(-d$NegLog10FDR)][d$State[order(-d$NegLog10FDR)]==g],2)))
    a$label_genes<-labs;a$allowed_text<-c('Down','Up',a$x_labels,a$tick_labels,'log2 fold change','-log10 FDR',labs)
    a$semantic_colors<-as.list(c(Down='#376B95',Up='#BB6D7C',Other='#B6BEC6'))
    a$statistics<-c(bound(file.path(audit,'statistics.csv')),list(method='Two-sided normal Wald tests on simulated effects and standard errors; BH across all genes',comparison='simulated treatment minus control',p_semantics='mixed_declared'))
  } else if(case=='synteny') {
    stopifnot(all(d$AStart>=0),all(d$AEnd>d$AStart),all(d$AEnd<=d$ALength),
      all(d$BStart>=0),all(d$BEnd>d$BStart),all(d$BEnd<=d$BLength))
    a$renderer<-'circlize';a$height_mm<-95;a$chromosomes<-c(unique(d$AChr),rev(unique(d$BChr)))
    a$semantic_colors<-as.list(setNames(c(c('#5E8393','#7BA7A1','#A3BDA2','#D6C199','#BC9AAA','#8C8EAF'),
      rev(c('#5E8393','#7BA7A1','#A3BDA2','#D6C199','#BC9AAA','#8C8EAF'))),a$chromosomes))
    a$allowed_text<-c(a$chromosomes,'0','50 Mb')
  } else if(case=='phylogeny') {
    tr<-ape::read.tree(text=d$Newick[1]);stopifnot(length(tr$tip.label)==12,all(tr$edge.length>0),ape::is.rooted(tr))
    maxdepth<-max(ape::node.depth.edgelength(tr));a$label_x<-maxdepth+.06;a$xmax<-maxdepth+.35
    a$x_ticks<-pretty(c(0,maxdepth),n=4);a$x_ticks<-a$x_ticks[a$x_ticks<=maxdepth];a$x_labels<-format(a$x_ticks,trim=TRUE)
    a$height_mm<-100;a$allowed_text<-c(tr$tip.label,'Clade I','Clade II','Branch length (a.u.)',a$x_labels)
    a$semantic_colors<-as.list(c(`Clade I`='#487B8D',`Clade II`='#AF859C'))
  } else stop('unknown case')
  a$allowed_text<-unique(a$allowed_text)
  write_json(a,analysis_path)
  cat('ANALYSIS_COMPLETE\n');quit(status=0)
}

a<-jsonlite::fromJSON(analysis_path,simplifyVector=FALSE)
if(!is.list(a$input_binding)||!identical(a$input_binding$sha256,input_binding$sha256)||
   !identical(a$input_binding$path,input_binding$path))stop('input differs from the analyzed bytes; fresh analysis is required')
spec_path<-config$design_spec_path;auth_path<-config$authorization_path
sources<-unlist(config$source_files);allowed<-unlist(a$allowed_text)
spec<-yaml::read_yaml(spec_path)
boxes<-data.frame(id=c('data','labels','legend'),x=c(8,0,78),y=c(5,0,5),w=c(68,7,12),h=c(a$height_mm-15,a$height_mm,35))
# These are non-overlapping allocation zones, not a claim of text-level visual QA.
if(case=='bubble')boxes<-data.frame(id=c('data','labels','legend'),x=c(16,0,58),y=c(5,0,5),w=c(40,15,32),h=c(76,92,80))
if(case %in% c('heatmap','dense-heatmap'))boxes<-data.frame(id=c('data','labels','legend'),x=c(4,58,70),y=c(9,9,9),w=c(53,11,19),h=c(a$height_mm-18,a$height_mm-18,55))
bf_check_boxes(boxes,a$width_mm,a$height_mm)
png<-file.path(out,paste0(case,'.png'));pdf<-file.path(out,paste0(case,'.pdf'))

if(a$renderer=='ggplot2') {
  obj<-make_ggplot(a)
  # The declared contracts are immutable parts of the authorized specification.
  same_contract<-length(obj$contracts)==length(spec$mark_style_contract$layers)&&
    all(vapply(seq_along(obj$contracts),function(i) {
      x<-obj$contracts[[i]];y<-spec$mark_style_contract$layers[[i]]
      identical(sort(names(x)),sort(names(y)))&&all(vapply(names(x),function(k)isTRUE(all.equal(x[[k]],y[[k]])),logical(1)))
    },logical(1)))
  if(!same_contract)
    stop('renderer mark contracts differ from authorized design')
  receipt<-bf_render_png(obj$plot,png,font,allowed,a$width_mm,a$height_mm,a$width_mm,sources,boxes,
    dpi=300,authorization=auth_path,skill_root=skill,publication_size_class='single-column')
  if('pdf' %in% formats) {
    prepared<-bf_prepare(obj$plot,font,allowed,width_mm=a$width_mm,height_mm=a$height_mm)
    pdf_begin(pdf)
    grid::grid.draw(prepared$grob);grDevices::dev.off();pdf_embed(pdf)
    write_json(list(artifact=bound(pdf),source_png=bound(png),same_grob=TRUE,backend='R',
      rendered_text=as.list(prepared$text),scope='Same R grob redrawn at final PDF size; separate actual PDF inspection required.'),paste0(pdf,'.export.json'))
  }
} else {
  # Native renderer uses exactly the same authorization and source binding.
  py<-Sys.getenv('PYTHON','python3')
  auth_args<-c(file.path(skill,'scripts','authorize_render.py'),'--design-spec',spec_path,'--output',auth_path,'--consume',
    unlist(lapply(sources[sources!=spec_path],function(x)c('--source',x))))
  status<-system2(py,shQuote(auth_args));if(status!=0L)stop('render authorization rejected')
  before<-lapply(sources,bound)
  bf_validate_publication_size(a$width_mm,a$height_mm,'single-column')
  bf_assert_scientific_text(allowed)
  native_text<-character();native_sizes<-numeric();cells<-list()
  collect_grid<-function(g,inherited=grid::gpar()) {
    gp<-inherited;for(k in names(g$gp))gp[[k]]<-g$gp[[k]]
    if(inherits(g,'text')&&length(g$label)) {
      if(is.expression(g$label))stop('unexpected math glyph requires separate audit')
      if(is.null(gp$fontfamily)||any(gp$fontfamily!=font$family))stop('native font inheritance mismatch')
      native_text<<-c(native_text,as.character(g$label));native_sizes<<-c(native_sizes,gp$fontsize)
    }
    for(child in c(g$grobs,as.list(g$children)))collect_grid(child,gp)
  }
  draw_heatmap<-function() {
    bf_complexheatmap_font(font)
    m<-as.matrix(d[,-1,drop=FALSE]);rownames(m)<-d$Gene;z<-t(scale(t(m)))
    dense<-case=='dense-heatmap'
    groups<-factor(unlist(a$sample_groups),levels=unlist(a$groups)); gc<-c(Control='#6C8DA5',Low='#BDCFD9',High='#A58BB8',Recovery='#D4B6A6')
    top<-ComplexHeatmap::HeatmapAnnotation(Group=groups,col=list(Group=gc),show_annotation_name=FALSE,
      simple_anno_size=grid::unit(2,'mm'),annotation_legend_param=list(Group=list(title_gp=grid::gpar(fontfamily=font$family,fontsize=7,fontface='plain'),
        labels_gp=grid::gpar(fontfamily=font$family,fontsize=7),ncol=1)))
    ht<-ComplexHeatmap::Heatmap(z,name='Row Z-score',col=circlize::colorRamp2(c(-2,-1,0,1,2),palette5),
      width=grid::unit(a$heatmap_cells$body_width_mm,'mm'),height=grid::unit(a$heatmap_cells$body_height_mm,'mm'),
      cluster_rows=TRUE,clustering_distance_rows='euclidean',clustering_method_rows='complete',
      cluster_columns=FALSE,column_split=groups,cluster_column_slices=FALSE,column_title=NULL,
      show_row_dend=!dense,row_dend_width=grid::unit(5,'mm'),column_gap=grid::unit(1.5,'mm'),top_annotation=top,
      show_row_names=!dense,show_column_names=!dense,column_names_rot=90,
      row_names_gp=grid::gpar(fontfamily=font$family,fontsize=6),column_names_gp=grid::gpar(fontfamily=font$family,fontsize=6),
      rect_gp=grid::gpar(col=if(dense)NA else '#FFFFFF',lwd=.25),border=FALSE,
      use_raster=dense,raster_device='agg_png',raster_quality=2,raster_resize_mat=FALSE,
      heatmap_legend_param=list(at=c(-2,0,2),title_position='topleft',legend_height=grid::unit(18,'mm'),
        title_gp=grid::gpar(fontfamily=font$family,fontsize=7,fontface='plain'),labels_gp=grid::gpar(fontfamily=font$family,fontsize=7)))
    drawn<-ComplexHeatmap::draw(ht,heatmap_legend_side='right',annotation_legend_side='right',merge_legends=TRUE,
      padding=grid::unit(c(4,3,3,3),'mm'))
    cells<<-bf_complexheatmap_cell_metrics(drawn,'Row Z-score',cell_mode=a$heatmap_cells$mode)
    # grid.grab() clears/replays the display list and creates a second PDF page.
    # Read the actual forced display-list objects without clearing or redrawing.
    grid::grid.force(redraw=FALSE)
    for(nm in grid::grid.ls(print=FALSE,recursive=FALSE,viewports=FALSE)$name) {
      g<-grid::grid.get(nm,strict=TRUE)
      bf_assert_scientific_grob_text(g);collect_grid(g,grid::gpar(fontfamily=font$family,fontsize=7))
    }
  }
  draw_synteny<-function() {
    library(circlize)
    circos.clear();on.exit(circos.clear(),add=TRUE)
    par(family=font$family,ps=7,mar=c(.1,.1,.1,.1),bg='white',xpd=FALSE)
    text_log<-new.env();text_log$labels<-character();text_log$sizes<-numeric()
    # Trace the real base text primitive, including any text created by circlize.
    assign('.bf_text_log',text_log,envir=.GlobalEnv)
    trace('text.default',where=asNamespace('graphics'),print=FALSE,tracer=quote({
      .bf<-get('.bf_text_log',envir=.GlobalEnv)
      if(length(labels)) {
        .fam<-if(!exists('family',inherits=FALSE)||is.null(family))par('family') else family
        if(any(.fam!='Arial'))stop('base text font mismatch')
        .bf$labels<-c(.bf$labels,as.character(labels));.bf$sizes<-c(.bf$sizes,par('ps')*if(is.null(cex))par('cex') else cex)
      }
    }))
    on.exit({untrace('text.default',where=asNamespace('graphics'));rm('.bf_text_log',envir=.GlobalEnv)},add=TRUE)
    chrs<-unlist(a$chromosomes);len<-c(setNames(d$ALength,d$AChr),setNames(d$BLength,d$BChr));len<-len[!duplicated(names(len))][chrs]
    hues<-c('#5E8393','#7BA7A1','#A3BDA2','#D6C199','#BC9AAA','#8C8EAF')
    cols<-setNames(c(hues,rev(hues)),chrs)
    gaps<-rep(2,length(chrs));gaps[c(6,12)]<-11
    circos.par(start.degree=90,gap.after=gaps,track.margin=c(.005,.005),cell.padding=c(0,0,0,0),
      canvas.xlim=c(-1.22,1.22),canvas.ylim=c(-1.22,1.22))
    circos.initialize(factors=factor(chrs,levels=chrs),xlim=cbind(rep(0,length(chrs)),as.numeric(len)))
    # Separate allocation for chromosome IDs and the coordinate ring. No text
    # is squeezed into the ribbon track or over the chromosome identity labels.
    circos.trackPlotRegion(ylim=c(0,1),track.height=.13,bg.col=NA,bg.border=NA,panel.fun=function(x,y) {
      chr<-get.cell.meta.data('sector.index');xl<-get.cell.meta.data('xlim')
      circos.text(mean(xl),.60,chr,facing='outside',niceFacing=TRUE,cex=1,adj=c(.5,.5))
    })
    circos.trackPlotRegion(ylim=c(0,1),track.height=.055,bg.col=cols,bg.border=NA)
    circos.trackPlotRegion(ylim=c(0,1),track.height=.14,bg.col=NA,bg.border=NA,panel.fun=function(x,y) {
      circos.axis(h='top',major.at=c(0,5e7),labels=c('0','50 Mb'),labels.cex=1,
        direction='inside',major.tick.length=.06,minor.ticks=0,lwd=.35,
        labels.facing='inside',labels.niceFacing=TRUE)
    })
    for(i in seq_len(nrow(d)))circos.link(d$AChr[i],c(d$AStart[i],d$AEnd[i]),d$BChr[i],c(d$BStart[i],d$BEnd[i]),
      col=grDevices::adjustcolor(cols[d$AChr[i]],alpha.f=.24),border=NA)
    native_text<<-c(native_text,text_log$labels);native_sizes<<-c(native_sizes,text_log$sizes)
  }
  native_draw<-if(a$renderer=='ComplexHeatmap')draw_heatmap else draw_synteny
  run_device<-function(path,type) {
    native_text<<-character();native_sizes<<-numeric();cells<<-list()
    if(type=='png')ragg::agg_png(path,width=a$width_mm,height=a$height_mm,units='mm',res=300,background='white') else pdf_begin(path)
    ok<-FALSE;on.exit({grDevices::dev.off();if(!ok)unlink(path)},add=TRUE)
    native_draw()
    bf_assert_scientific_text(native_text,'actual native canvas text')
    unexpected<-setdiff(native_text[nzchar(native_text)],allowed);if(length(unexpected))stop(paste('unapproved native text:',paste(unexpected,collapse=' | ')))
    if(!length(native_sizes)||any(!is.finite(native_sizes))||min(native_sizes)<6)stop('native text below final-size minimum')
    chars<-unique(unlist(strsplit(paste(native_text,collapse=''),'',fixed=TRUE)))
    if(any(systemfonts::glyph_info(chars,path=font$path,index=font$index)$index==0))stop('missing native font glyph')
    ok<-TRUE
    list(text=unique(native_text),sizes=native_sizes,cells=cells)
  }
  exported<-run_device(png,'png')
  if(!identical(before,lapply(sources,bound)))stop('input changed during native render')
  auth<-jsonlite::fromJSON(auth_path,simplifyVector=FALSE);marker<-paste0(auth_path,'.consumed')
  if(!file.exists(marker)||trimws(readLines(marker,warn=FALSE)[1])!=auth$authorization_id)stop('missing authorization consumption')
  receipt<-list(schema_version=1,status='PASS',backend='R',renderer=a$renderer,artifact=bound(png),sources=before,
    inspection_binding_policy='render-receipt-sha256-v1',
    authorization_consumption=list(consumed=TRUE,authorization_id=auth$authorization_id,marker=bound(marker),
      authorization_file=bound(auth_path),preparation_receipt=auth$bound$receipt),font=c(bound(font$path),list(family=font$family)),
    checks=list(font=TRUE,text_allowlist=TRUE,scientific_text_only=TRUE,footer_free=TRUE,layout=TRUE,target_size=TRUE,
      cell_geometry=length(exported$cells)>0),heatmap_cells=exported$cells,heatmap_cell_policy_id='heatmap-cells-v1',
    rendered_text=as.list(exported$text),text_policy_id='scientific-content-only-v1',footer_policy_id='no-canvas-footer-v1',
    target_min_text_pt=min(exported$sizes),min_text_pt=6,target_width_mm=a$width_mm,
    target_size=list(width_mm=a$width_mm,height_mm=a$height_mm,size_class='single-column',size_basis='final_physical_output'),
    device=list(width_mm=a$width_mm,height_mm=a$height_mm,dpi=300),boxes=boxes,
    scope='Executed native font/text/size/geometry checks; separate actual visual inspection required.')
  write_json(receipt,paste0(png,'.render.json'))
  if('pdf' %in% formats) {
    pdf_export<-run_device(pdf,'pdf')
    pdf_embed(pdf)
    write_json(list(artifact=bound(pdf),source_png=bound(png),backend='R',rendered_text=as.list(pdf_export$text),
      heatmap_cells=pdf_export$cells,scope='Fresh native redraw and measurements; actual PDF inspection required.'),paste0(pdf,'.export.json'))
  }
}
cat('RENDERED_PENDING_VISUAL_REVIEW\n')
