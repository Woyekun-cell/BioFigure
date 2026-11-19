from pathlib import Path
import ast,csv,io,json,hashlib
W=Path(__file__).resolve().parent;P=W.parents[1];D=P/'work/2026-11-05-omics-source-a'
files={'Brain':'Crunfli2021_Brain.omics','Liver':'Nie2021_Liver.omics','Lung':'Wang2021_Proteomics.omics','Lung_RNA':'Wang2021_RNA.omics'}
allgenes=set();data={};enrichment={}
for study,fn in files.items():
 s=(D/'source-data/omics_files'/fn).read_text();chunks=s.split('-------\n');data[study]=list(csv.DictReader(io.StringIO(chunks[1].split('Enrichment Analysis:')[0]),delimiter='\t'));erows=list(csv.DictReader(io.StringIO(chunks[2]),delimiter='\t'));term=[r for r in erows if 'Oxidative phosphorylation' in r['Term']];assert len(term)==1
 gs=set(sum([ast.literal_eval(r['Genes']) for r in term],[]));allgenes|=gs;enrichment[study]=gs
# Author circular_term averages duplicate gene rows after pAdjusted<=0.05, using union of enriched-term genes across studies.
links=[]
for study,rows in data.items():
 grouped={}
 for r in rows:
  if r['gene_name'] in allgenes and float(r['pAdjusted'])<=.05:grouped.setdefault(r['gene_name'],[]).append(r)
 for gene,rs in sorted(grouped.items()):
  fc=sum(float(r['log2(fc)']) for r in rs)/len(rs)
  links.append(dict(study=study,gene=gene,log2fc=fc,display_fc=max(-1,min(1,fc)),source_rows=len(rs),source_pAdjusted_max=max(float(r['pAdjusted']) for r in rs)))
assert len(allgenes)==88 and len(links)==152
out=P/'results/plot_data/omicscope_oxphos_chord_20261105';out.mkdir(parents=True,exist_ok=True)
def write(name,rows,fields):
 with (out/name).open('w',newline='')as f:
  w=csv.DictWriter(f,fields);w.writeheader();w.writerows(rows)
write('links.csv',links,list(links[0]));write('genes.csv',[dict(gene=g,study_count=sum(x['gene']==g for x in links))for g in sorted(allgenes)],['gene','study_count'])
wide=[]
for study in files:
 for gene in sorted(allgenes):
  x=next((x for x in links if x['study']==study and x['gene']==gene),None);wide.append(dict(study=study,gene=gene,present=int(x is not None),log2fc=x['log2fc']if x else ''))
write('matrix.csv',wide,list(wide[0]));(W/'data-summary.json').write_text(json.dumps(dict(genes=88,studies=4,links=152,matrix_cells=352,study_counts={s:sum(x['study']==s for x in links)for s in files},duplicates_averaged=sum(x['source_rows']>1 for x in links),clipped_cells=sum(abs(x['log2fc'])>1 for x in links),source_scope='Imported author adjusted-P and log2FC only;4independentstudies,not biologicalreplicates;no inference recomputed.'),indent=2)+'\n')
labels=sorted(allgenes)+['Brain','Liver','Lung','Lung RNA','Oxidative phosphorylation','log2 fold change','-1','0','+1']
(W/'text-manifest.json').write_text(json.dumps(dict(labels=labels),indent=2)+'\n')
print((W/'data-summary.json').read_text())
