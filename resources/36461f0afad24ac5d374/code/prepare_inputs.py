"""Execute pinned plotsr selection/control-point source; export real figure inputs.
No Python formal renderer is claimed. The R renderer preserves these controls.
"""
from pathlib import Path
import ast,csv,json,hashlib,types
import pandas as pd
C=Path(__file__).resolve().parents[1];src=C/'sources/author/func.py';tree=ast.parse(src.read_text());names={'readsyriout','filterinput'};nodes=[n for n in tree.body if isinstance(n,ast.FunctionDef)and n.name in names];ns={'VARS':['SYN','INV','TRANS','INVTR','DUP','INVDP']};exec(compile(ast.Module(body=nodes,type_ignores=[]),str(src),'exec'),ns)
# Author bezierpath arithmetic and branch are executed unchanged; matplotlib-only
# imports, Path/Patch construction and renderer return are omitted for geometry export.
f=next(n for n in tree.body if isinstance(n,ast.FunctionDef)and n.name=='bezierpath');body=[]
for n in f.body:
 if isinstance(n,(ast.Import,ast.ImportFrom)):continue
 if isinstance(n,ast.Assign)and any(isinstance(t,ast.Name)and t.id=='codes'for t in n.targets):break
 body.append(n)
f.body=body+[ast.Return(value=ast.Name(id='verts',ctx=ast.Load()))];mod=ast.fix_missing_locations(ast.Module(body=[f],type_ignores=[]));exec(compile(mod,str(src),'exec'),ns)
meta=json.loads((C/'data/metadata/input-files.json').read_text());D=C/'results/plot_data';D.mkdir(parents=True,exist_ok=True);allrows=[];controls=[];audit={};chrs=['chr'+str(i)for i in range(1,23)]+['chrX'];rank={s:23-i for i,s in enumerate(chrs)}
args=types.SimpleNamespace(s=10000,nosyn=False,noinv=False,notr=False,nodup=False)
for hap,filename in meta['syri'].items():
 df,ids=ns['readsyriout'](str(C/'sources/data'/filename));raw=df.copy();df=ns['filterinput'](args,df,ids,False);assert set(df.achr)==set(chrs);assert set(ids)==set(chrs)
 df=df.reset_index(drop=True);df['source_bstart']=df.bstart;df['source_bend']=df.bend
 # plotsr.py v1.1.1 lines189-200: reverse all INV/INVTR/INVDP query ends.
 invindex=df.type.str.contains('INV');assert len(set(df.loc[invindex,'bstart']<df.loc[invindex,'bend']))==1
 if (df.loc[invindex,'bstart']<df.loc[invindex,'bend']).all():
  df.loc[invindex,['bstart','bend']]=df.loc[invindex,['bend','bstart']].to_numpy()
 df['hap']=hap;df['anchor_id']=[hap+'-'+str(i+1)for i in range(len(df))];df['display_type']=df.type.replace({'INVTR':'TRANS','INVDP':'DUP'});df['ry']=[rank[c]+.34 for c in df.achr];df['qy']=[rank[c]-.34 for c in df.achr]
 for row in df.itertuples(index=False):
  verts=ns['bezierpath'](row.astart,row.aend,row.bstart,row.bend,row.ry,row.qy,False,'#000000',.8)
  for i,(x,y)in enumerate(verts):controls.append(dict(anchor_id=row.anchor_id,hap=hap,vertex=i,x=x,y=y))
 allrows.append(df);audit[hap]=dict(raw_structural_rows=len(raw),plotted_rows=len(df),raw_types=raw.type.value_counts().to_dict(),plotted_types=df.type.value_counts().to_dict(),excluded_default_10kb_or_nonhomologous=len(raw)-len(df),mapping=ids)
pd.concat(allrows).to_csv(D/'syri_anchors.csv',index=False);pd.DataFrame(controls).to_csv(D/'author_bezier_controls.csv',index=False)
# These published author cytoband endpoints give full genome spans; do not use
# last aligned base as chromosome length.
lens=[]
for hap,filename in meta['cytobands'].items():
 b=pd.read_csv(C/'sources/data'/filename,sep='\t');a=b.groupby('chr',sort=False)['end'].max()
 for c,n in a.items():lens.append(dict(hap=hap,chr=c,length_bp=int(n),source=filename))
with(C/'data/metadata/chm13v2.0.fa.fai').open()as f:
 for line in f:
  c,n,*_=line.split()
  if c in chrs:lens.append(dict(hap='CHM13',chr=c,length_bp=int(n),source='chm13v2.0.fa.gz.fai'))
pd.DataFrame(lens).to_csv(D/'chromosome_lengths.csv',index=False)
# T2T v2.1 active/live HOR annotations explicitly contain the H...L designation;
# retain every matching source interval rather than infer centromeres from SVs.
b=pd.read_csv(C/'data/metadata/chm13v2.0_censat_v2.1.bed',sep='\t',header=None);b=b[b[3].str.match(r'hor_.*\([^)]*H[^)]*L\)')&b[0].isin(chrs)];b=b[[0,1,2,3]];b.columns=['chr','start0','end0','annotation'];assert set(b.chr)==set(chrs);b.to_csv(D/'chm13_live_hor.csv',index=False)
q=dict(status='PASS',author_version='plotsr v1.1.1',original_functions_executed=['readsyriout','filterinput','bezierpath arithmetic before matplotlib construction'],native_render_claimed=False,selection=dict(min_bp=10000,homologous_chromosomes_only=True,merge_syntenic_ribbons=False,inverted_query_end_swap='plotsr.py lines189-200'),comparisons=audit,chromosomes=chrs,live_hor_intervals=len(b),control_vertices=len(controls),no_synthetic_values=True)
(C/'evidence/input-qc.json').write_text(json.dumps(q,indent=2));print(json.dumps(q,indent=2))
