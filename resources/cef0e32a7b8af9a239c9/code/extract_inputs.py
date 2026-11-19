from pathlib import Path
import csv,json,math,hashlib,os
import openpyxl
W=Path(__file__).resolve().parent;P=W.parents[1];S=P/'biofigure';D=W/'sources';D.mkdir(exist_ok=True)
case=json.loads((S/'benchmark/cases/paper-mofacll-2021-fig4a-20261028.json').read_text())
files=case['source_assets']+case['source_reference_images']
for item in files:
 src=(S/item['path']).resolve();assert src.is_file()
 h=hashlib.sha256(src.read_bytes()).hexdigest();assert h==item['sha256'],src
 target=D/src.name
 if not target.exists():target.symlink_to(os.path.relpath(src,D))
rows=list(openpyxl.load_workbook(D/'figure4.xlsx',data_only=True,read_only=True)['Figure 4'].values)
allrows=[]
labels={'OXIDATIVE_PHOSPHORYLATION':'OXPHOS','MYC_TARGETS_V1':'MYC targets v1','MTORC1_SIGNALING':'mTORC1 signaling','INTERFERON_ALPHA_RESPONSE':'Interferon alpha response','PROTEIN_SECRETION':'Protein secretion','CHOLESTEROL_HOMEOSTASIS':'Cholesterol homeostasis','FATTY_ACID_METABOLISM':'Fatty acid metabolism','INTERFERON_GAMMA_RESPONSE':'Interferon gamma response'}
for row in rows[4:54]:
 name,n,d,p,q=row[:5];assert name.startswith('HALLMARK_')and p>0 and q>=0
 short=name.removeprefix('HALLMARK_');allrows.append(dict(gene_set=name,number_genes=n,Direction=d,PValue=p,FDR=q,neglog10_PValue=-math.log10(p),selected=q<=.05,label=labels.get(short,short.replace('_',' ').capitalize())))
assert len(allrows)==50 and sum(r['selected']for r in allrows)==8
out=P/'results/plot_data';out.mkdir(parents=True,exist_ok=True)
for suffix,data in [('all',allrows),('selected',[r for r in allrows if r['selected']])]:
 with (out/f'pending_mofacll_fig4a_20261030_{suffix}.csv').open('w',newline='')as f:
  w=csv.DictWriter(f,fieldnames=list(allrows[0]));w.writeheader();w.writerows(data)
(W/'source-files.json').write_text(json.dumps([dict(**r,local=str((D/(S/r['path']).name).absolute()))for r in files],ensure_ascii=False,indent=2)+'\n')
print('Preserved50 author summaries; selected8 source FDR<=0.05; no new enrichment calculation.')
