from pathlib import Path
import csv,io,json,math
W=Path(__file__).resolve().parent;P=W.parents[1];D=P/'work/2026-11-05-omics-source-a/source-data/omics_files';O=P/'results/plot_data/omicscope_study_overview_20261105';O.mkdir(parents=True,exist_ok=True)
files={'Brain':'Crunfli2021_Brain.omics','Liver':'Nie2021_Liver.omics','Lung':'Wang2021_Proteomics.omics','Lung_RNA':'Wang2021_RNA.omics'};expressions={};reg={};enrich={};top=[]
for group,fn in files.items():
 s=(D/fn).read_text();chunks=s.split('-------\n');e=list(csv.DictReader(io.StringIO(chunks[1].split('Enrichment Analysis:')[0]),delimiter='\t'));expressions[group]=e;reg[group]=[x for x in e if float(x['pAdjusted'])<.05];enrich[group]=[x for x in csv.DictReader(io.StringIO(chunks[2]),delimiter='\t')if x['Gene_set']=='KEGG_2021_Human'];top.extend(x['Term']for x in enrich[group][:10])
terms=set(top);dots=[]
for group,ers in enrich.items():
 for r in ers:
  if r['Term']in terms:dots.append(dict(study=group,term=r['Term'],overlap=int(r['Overlap'].split('/')[0]),term_size=int(r['Overlap'].split('/')[1]),p_adjusted=float(r['Adjusted P-value']),neg_log10_p=-math.log10(float(r['Adjusted P-value']))))
termorder=list(dict.fromkeys(r['term']for r in dots));counts=[dict(study=g,input_count=len(expressions[g]),differential_count=len(reg[g]))for g in files];counts.append(dict(study='Total',input_count=len({x['gene_name']for rows in expressions.values()for x in rows}),differential_count=len({x['gene_name']for rows in reg.values()for x in rows})))
directions=[dict(study=g,direction=d,count=sum(float(x['log2(fc)'])>0 if d=='Up'else float(x['log2(fc)'])<0 for x in rows))for g,rows in reg.items()for d in ['Up','Down']]
def write(name,rows):
 with(O/name).open('w',newline='')as f:
  w=csv.DictWriter(f,list(rows[0]));w.writeheader();w.writerows(rows)
write('input_differential_counts.csv',counts);write('direction_counts.csv',directions);write('enrichment_points.csv',dots);write('term_order.csv',[dict(term=t,display_order=i+1)for i,t in enumerate(termorder)])
assert len(dots)==72 and len(termorder)==29;assert counts[-1]['input_count']==7867 and counts[-1]['differential_count']==7188
labels=['b','c','d','Entities','Differential / input','Up','Down','Input','Differential','Number of entities','-log10 adjusted P','Brain','Liver','Lung','Lung RNA','Total','0','4000','8000','500','1500','2500','8','16','24','32']+termorder+[f"{x['differential_count']:,} / {x['input_count']:,}"for x in counts]
(W/'text-manifest.json').write_text(json.dumps(dict(labels=labels),ensure_ascii=False,indent=2)+'\n');(W/'data-summary.json').write_text(json.dumps(dict(counts=counts,directions=directions,enrichment_terms=29,enrichment_points=72,term_order=termorder,neg_log10_range=[min(x['neg_log10_p']for x in dots),max(x['neg_log10_p']for x in dots)],source_rule='AuthorNebulaimportingstrictpAdjusted<0.05;authorbarplot/diff_reganddotplot_enrichment(top=10)semanticspreserved;noinference.'),indent=2)+'\n');print('4B-Ddataready',len(dots),len(termorder))
