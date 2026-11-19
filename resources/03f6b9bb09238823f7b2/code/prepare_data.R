args<-commandArgs(TRUE);P<-normalizePath(args[1]);W<-file.path(P,'work/2026-10-29-remaining-maps/gibbs-geotopo');w<-file.path(W,'ASF-V15');D<-file.path(W,'neurogravity-fig3/Source_Data_Fig3');library(readxl);library(sf);library(jsonlite)
files<-list.files(D,pattern='xlsx$',full.names=TRUE);cities<-c('Boston','Los Angeles','SF Bay');epsgs<-c(32619,32611,32610);meta<-list();polys<-list();flows<-list()
for(i in seq_along(files)){
 f<-files[i];d<-as.data.frame(read_excel(f,sheet=2));o<-as.data.frame(read_excel(f,sheet=1));city<-cities[i];stopifnot(!anyDuplicated(d$Ind),!anyDuplicated(o[c('origin','destination')]),all(o$origin %in% d$Ind),all(o$destination %in% d$Ind))
 geo<-st_as_sfc(d$geometry,crs=if(i==3)3857 else 4326);g<-st_sf(d,geometry=geo);g<-st_transform(g,epsgs[i]);stopifnot(all(st_is_valid(g)));xy<-st_coordinates(st_centroid(st_geometry(g)));bb<-st_bbox(g)
 g$city<-city;polys[[i]]<-g
 models<-if(i==1)c('Gravity','neuroGravity')else 'neuroGravity'
 for(m in models){z<-o;z$flow<-z[[paste0(m,'_pred')]];stopifnot(all(is.finite(z$flow)),all(z$flow>=0));z$city<-city;z$model<-m;z$source_row<-seq_len(nrow(z));z$percentile<-rank(z$flow,ties.method='average')/nrow(z)*100;z$displayed<-z$percentile>=70
  a<-match(z$origin,d$Ind);b<-match(z$destination,d$Ind);z$x<-xy[a,1];z$y<-xy[a,2];z$xend<-xy[b,1];z$yend<-xy[b,2];flows[[length(flows)+1]]<-z[c('city','model','source_row','origin','destination','flow','percentile','displayed','x','y','xend','yend')]
 }
 meta[[city]]<-list(city=city,n_regions=nrow(d),n_observed=sum(d$observe=='Observed'),n_od=nrow(o),input_crs=if(i==3)'EPSG:3857'else'EPSG:4326',render_crs=paste0('EPSG:',epsgs[i]),source_file=normalizePath(f),extent=as.list(bb),sum_neuroGravity=sum(o$neuroGravity_pred))
}
z<-do.call(rbind,flows);saveRDS(list(polygons=polys,flows=z,meta=meta),file.path(w,'source-maps.rds'))
stem<-'asf15_neurogravity_published_networks_20261029';pd<-file.path(P,'results/plot_data');dir.create(pd,showWarnings=FALSE,recursive=TRUE);write.csv(z,file.path(pd,paste0(stem,'_flows.csv')),row.names=FALSE)
p<-do.call(rbind,lapply(polys,function(g){data.frame(city=g$city,Ind=g$Ind,GEOID=g$GEOID,observe=g$observe,population=g$population,render_crs=st_crs(g)$input,WKT=st_as_text(st_geometry(g)))}));write.csv(p,file.path(pd,paste0(stem,'_polygons.csv')),row.names=FALSE)
write_json(list(stem=stem,width_mm=183,height_mm=165,data_origin='Published author Source Data Fig3, existing aggregate OD predictions; no model training/inference, no synthetic repository demo data. Four prediction maps only; observation/ground-truth edges and validation panels outside scope.',crs='City-specific UTM19N/11N/10N; source WKT CRS verified from coordinate ranges and geographic position.',n_polygons=nrow(p),n_flow_values=nrow(z),n_displayed=sum(z$displayed),cities=meta,display_rule='Source-guided visual adaptation: top30% of flow ranks within each city/model, equal-weight empirical percentiles, native straight OD segments drawn weak-to-strong; exact author percentile computation and centroid algorithm not provided.',full_original_figure_reproduction=FALSE),file.path(w,'input-qc.json'),pretty=TRUE,auto_unbox=TRUE,digits=NA)
cat('rows',nrow(z),'displayed',sum(z$displayed),'polygons',nrow(p),'\n')
