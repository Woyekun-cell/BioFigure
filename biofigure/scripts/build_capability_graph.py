#!/usr/bin/env python3
import csv,hashlib,json,re,subprocess,tempfile
from collections import Counter,defaultdict
from pathlib import Path
R=Path(__file__).resolve().parents[1]; PROJECT=R.parent; WORKSPACE=PROJECT.parent
S=WORKSPACE/'Project_003_SciDraw代码分类抓取器/output/SciDraw代码分类包/按图表类型'
T=R/'library/topjournal-corpus'; SC=R/'benchmark/library/scidraw'
TB=PROJECT/'results/full_library_audit'; DT=TB; TB.mkdir(parents=True,exist_ok=True)
PK=re.compile(r'(?:library|require|requireNamespace|p_load)\s*\(\s*["\']?([A-Za-z][\w.]*)'); NS=re.compile(r'([A-Za-z][\w.]*)\s*:::{0,1}\s*([A-Za-z][\w.]*)'); FU=re.compile(r'(?<![\w.])([A-Za-z][\w.]*)\s*\(')
SK={'if','for','while','function','switch','return','c','list','data.frame','matrix','factor','print','paste','paste0','round','min','max','mean','sum','length','seq','rep','sample','set.seed'}
FA={'ordination':['pcoa','nmds','umap','ordination','cmdscale','vegdist'],'ternary':['三元','ggtern'],'heatmap':['热图','heatmap','complexheatmap','pheatmap'],'correlation':['相关','correlation','corrplot'],'survival':['生存','survival','kaplan','ggsurv'],'forest':['森林','forest','hazard ratio'],'volcano':['火山','volcano'],'enrichment':['gsea','富集','enrichment','clusterprofiler'],'network':['网络','network','ggraph','igraph'],'chord':['和弦','chord','circlize'],'upset-venn':['upset','venn'],'alluvial-sankey':['桑基','sankey','alluvial'],'phylogeny':['系统发育','phylo','ggtree'],'genome-track':['基因组','circos','track'],'swimmer':['泳道','swimmer'],'ridge':['山脊','峰峦','ridge'],'distribution':['箱线','小提琴','云雨','boxplot','violin'],'bar-composition':['柱形','bar','composition'],'time-series':['时序','时间序列','折线'],'scatter-bubble':['散点','气泡','scatter','bubble'],'map':['地图','map'],'circular':['环形','环状','polar']}
EV=[('source_manifest_first2.json','scidraw-rcs','rcs_05.png','scidraw_rcs.png','scidraw_rcs_source_comparison.png'),('source_manifest_first2.json','scidraw-ridge-bipolar','ridge_02.png','scidraw_ridge_bipolar.png','scidraw_ridge_bipolar_source_comparison.png'),('source_manifest_six.json','01_pcoa_marginal','pcoa_02.png','01_pcoa_marginal.png','01_pcoa_marginal.png'),('source_manifest_six.json','02_ternary_cell_state','ternary_03.png','02_ternary_cell_state.png','02_ternary_cell_state.png'),('source_manifest_six.json','03_correlation_heatmap','corr_03.png','03_correlation_heatmap.png','03_correlation_heatmap.png'),('source_manifest_six.json','04_patient_swimmer','swimmer_02.png','04_patient_swimmer.png','04_patient_swimmer.png'),('source_manifest_six.json','05_chord_outer_track','chord_02.png','05_chord_outer_track.png','05_chord_outer_track.png'),('source_manifest_six.json','06_volcano_gsea','volcano_02.png','06_volcano_gsea.png','06_volcano_gsea.png')]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def feat(txt,title):
 ns=set(NS.findall(txt)); pk=set(PK.findall(txt))|{x[0] for x in ns}; fn=(set(FU.findall(txt))|{x[1] for x in ns})-SK; low=(title+' '+txt).lower(); fam=[k for k,v in FA.items() if any(x.lower() in low for x in v)] or ['other'];return sorted(pk),sorted(fn),fam,sorted(ns)
def parse(paths):
 if not paths:return {}
 with tempfile.TemporaryDirectory() as d:
  i=Path(d)/'i';o=Path(d)/'o';i.write_text('\n'.join(map(str,paths))+'\n'); code='a<-readLines(commandArgs(TRUE)[1]);o<-commandArgs(TRUE)[2];z<-vector("list",length(a));for(j in seq_along(a)){z[[j]]<-tryCatch({parse(file=a[j]);c(a[j],"parse_ok","")},error=function(e)c(a[j],"parse_error",gsub("[\\t\\r\\n]+"," ",conditionMessage(e))))};write.table(do.call(rbind,z),o,sep="\\t",quote=F,row.names=F,col.names=F)';subprocess.run(['Rscript','-e',code,str(i),str(o)],check=True);return {a[0]:(a[1],a[2] if len(a)>2 else '') for a in csv.reader(o.open(),delimiter='\t') if len(a)>=2}
def probe(pk):
 code='for(x in commandArgs(T)){ok<-requireNamespace(x,quietly=T);cat(x,"\\t",ok,"\\t",if(ok)as.character(packageVersion(x))else"","\\n",sep="")}';q=subprocess.run(['Rscript','-e',code,*pk],capture_output=True,text=True,check=True);return {a[0]:{'installed':a[1]=='TRUE','version':a[2]} for z in q.stdout.splitlines() if len(a:=z.split('\t'))>2}
def funprobe(pairs):
 code='for(x in commandArgs(T)){a<-strsplit(x,"::",fixed=T)[[1]];ok<-requireNamespace(a[1],quietly=T);ex<-ok&&!inherits(try(getExportedValue(a[1],a[2]),silent=T),"try-error");cat(a[1],"\\t",a[2],"\\t",ok,"\\t",ex,"\\n",sep="")}'
 out=[];pairs=list(pairs)
 for i in range(0,len(pairs),12):
  q=subprocess.run(['Rscript','-e',code,*[f'{a}::{b}' for a,b in pairs[i:i+12]]],capture_output=True,text=True,check=True)
  out.extend(dict(package=a[0],function=a[1],package_installed=a[2]=='TRUE',function_exists=a[3]=='TRUE') for z in q.stdout.splitlines() if len(a:=z.split('\t'))>3)
 return out
cases=[];files=[];pairs=set()
def add(cid,source,title,typ,url,status,cfs):
 txt='\n'.join(p.read_text(errors='ignore') for p in cfs);pk,fn,fam,ns=feat(txt,title);pairs.update(ns);cases.append(dict(case_id=cid,source=source,title=title,chart_type=typ,source_url=url,source_status=status,code_files=len(cfs),packages=pk,functions=fn,method_families=fam,validation_status='static-code-audited',visual_status='not-run'));files.extend(dict(case_id=cid,path=str(p),language=p.suffix.lower(),sha256=sha(p)) for p in cfs)
for p in sorted(S.rglob('metadata.json')):
 m=json.loads(p.read_text());c=[p.parent/x for x in m.get('代码文件',[]) if (p.parent/x).exists()];add('scidraw-'+hashlib.sha1(str(p.parent.relative_to(S)).encode()).hexdigest()[:10],'scidraw',m.get('图表命名') or p.parent.name,m.get('图表类型',''),m.get('原文URL',''),m.get('抓取状态','unknown'),c)
for m in json.loads((T/'results/plot_data/biofigure_candidates.json').read_text()):
 c=[T/x['path'] for x in m.get('code_files',[]) if (T/x['path']).exists()];add(m['case_id'],'topjournal',m.get('title',''),'',m.get('source_url',''),m.get('source_status','unknown'),c)
rp=[Path(x['path']) for x in files if Path(x['path']).suffix.lower()=='.r'];pa=parse(rp)
for x in files:x['syntax_status'],x['parse_error']=pa.get(x['path'],('text-fragment-not-r-parsed',''))
by=defaultdict(list)
for x in files:by[x['case_id']].append(x['syntax_status'])
pm=probe(sorted({p for c in cases for p in c['packages']}))
for c in cases:
 st=by[c['case_id']];c['r_parse_ok']=st.count('parse_ok');c['r_parse_error']=st.count('parse_error');c['package_status']='all-installed' if all(pm.get(p,{}).get('installed') for p in c['packages']) else 'missing-package'
u2c={c['source_url']:c for c in cases if c['source_url']};evidence=[]
review_path=DT/'visual_comparison_review.json'; reviews={x['evidence_id']:x for x in json.loads(review_path.read_text())} if review_path.exists() else {}
for manifest,eid,sn,on,cn in EV:
 man=json.loads((SC/'metadata'/manifest).read_text());en=next(x for x in man['cases'] if x['id']==eid);u=en['source_url'];sp=SC/'sources'/sn;op=SC/'figures'/on;cp=SC/'evidence/comparison'/cn;rv=reviews.get(eid,{});status='source-compared-needs-revision' if rv and sp.exists() and op.exists() and cp.exists() else 'pending-regenerated-source-comparison';row=dict(evidence_id=eid,source_url=u,case_id=u2c.get(u,{}).get('case_id','unmatched'),source_image=str(sp),source_sha256=sha(sp) if sp.exists() else '',reproduction_png=str(op),reproduction_sha256=sha(op) if op.exists() else '',comparison_png=str(cp),comparison_sha256=sha(cp) if cp.exists() else '',visual_status=status,review_status=rv.get('review_status',''),review_note=rv.get('review_note',''));evidence.append(row);u2c.get(u,{}).update(visual_status=status)
pkrows=[dict(package=p,**pm[p],case_count=sum(p in c['packages'] for c in cases)) for p in pm];fnrows=funprobe(sorted(pairs))
for r in fnrows:r['case_count']=sum(any(re.search(r'\b'+re.escape(r['package'])+r'\s*:::{0,1}\s*'+re.escape(r['function'])+r'\b',Path(x['path']).read_text(errors='ignore')) for x in files if x['case_id']==c['case_id']) for c in cases)
def wc(p,rows,fields):
 with p.open('w',newline='') as f:w=csv.DictWriter(f,fieldnames=fields,lineterminator='\n');w.writeheader();w.writerows(rows)
flat=[]
for c in cases:x=c.copy();x['packages']='|'.join(x['packages']);x['functions']='|'.join(x['functions']);x['method_families']='|'.join(x['method_families']);flat.append(x)
wc(TB/'case_audit.csv',flat,list(flat[0]));wc(TB/'code_file_audit.csv',files,list(files[0]));wc(TB/'package_capability.csv',pkrows,['package','installed','version','case_count']);wc(TB/'namespaced_function_audit.csv',fnrows,['package','function','package_installed','function_exists','case_count']);wc(TB/'visual_evidence.csv',evidence,list(evidence[0]));fail=[x for x in files if x['syntax_status']=='parse_error'];wc(TB/'parse_failures.csv',fail,list(files[0]))
fr=[]
for f in sorted({x for c in cases for x in c['method_families']}):fr.append({'method_family':f,'case_count':sum(f in c['method_families'] for c in cases),'sources':'|'.join(sorted({c['source'] for c in cases if f in c['method_families']})),'source_compared_count':sum(f in c['method_families'] and c['visual_status'].startswith('source-compared') for c in cases)})
wc(TB/'method_family_matrix.csv',fr,list(fr[0]));nodes=[{'id':c['case_id'],'kind':'case','label':c['title'],'source':c['source'],'status':c['validation_status'],'visual_status':c['visual_status']} for c in cases]+[{'id':'family:'+x['method_family'],'kind':'method_family','label':x['method_family']} for x in fr]+[{'id':'package:'+x['package'],'kind':'package','label':x['package'],'installed':x['installed'],'version':x['version']} for x in pkrows];edges=[]
for c in cases:
 edges += [{'from':c['case_id'],'to':'family:'+f,'relation':'uses-method-family'} for f in c['method_families']]+[{'from':c['case_id'],'to':'package:'+p,'relation':'uses-package'} for p in c['packages']]
su={'schema_version':2,'case_count':len(cases),'source_counts':dict(Counter(c['source'] for c in cases)),'code_file_count':len(files),'r_file_count':len(rp),'r_parse_ok':sum(x['syntax_status']=='parse_ok' for x in files),'r_parse_error':len(fail),'unique_packages':len(pkrows),'installed_packages':sum(x['installed'] for x in pkrows),'missing_packages':[x['package'] for x in pkrows if not x['installed']],'namespaced_function_pairs':len(fnrows),'existing_namespaced_functions':sum(x['function_exists'] for x in fnrows),'method_family_count':len(fr),'visual_evidence_pending':sum(x['visual_status'].startswith('pending') for x in evidence),'source_compared_cases':sum(x['visual_status'].startswith('source-compared') for x in evidence),'source_compared_pass':sum(x['review_status']=='pass' for x in evidence),'source_compared_needs_revision':sum(x['review_status']=='needs-revision' for x in evidence),'status_boundary':'source-compared means visually reviewed; only review_status=pass means fidelity accepted'}
(DT/'coverage_summary.json').write_text(json.dumps(su,ensure_ascii=False,indent=2)+'\n');(DT/'capability_graph.json').write_text(json.dumps({'schema_version':2,'summary':su,'nodes':nodes,'edges':edges,'visual_evidence':evidence},ensure_ascii=False,indent=2)+'\n');print(json.dumps(su,ensure_ascii=False))
