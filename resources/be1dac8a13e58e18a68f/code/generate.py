from pathlib import Path
import numpy as np,json,csv,hashlib,sys
W=Path(sys.argv[1]).resolve();P=W.parents[1];q=json.loads((W/'config.json').read_text());rng=np.random.default_rng(q['seed']);O=P/'results/plot_data';O.mkdir(parents=True,exist_ok=True);files=[]
def out(name,cols,rows):
 p=O/(q['stem']+'_'+name+'.csv')
 with p.open('w')as f:w=csv.writer(f);w.writerow(cols);w.writerows(rows)
 files.append(dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
if q['key']=='chemring':
 prot=rng.integers(0,2,(8,24));rows=[];meta=[]
 for i in range(64):
  cl=i//8;a=prot[cl].copy();flip=rng.choice(24,2,replace=False);a[flip]=1-a[flip];cid=f'C{i+1:02}'
  rows.append([cid]+list(a));meta.append([cid,'Degrader' if cl<5 else 'Binder' if cl<7 else 'Control',['Target A','Target B','Target C','Other'][cl%4],['Recruiter I','Recruiter II','None'][cl%3]])
 out('features',['compound']+[f'F{i+1:02}'for i in range(24)],rows);out('metadata',['compound','class','target','recruiter'],meta)
 method='PCG64 binary prototypes (8 x 24) with two bit flips per 64 compound rows; no chemical structures or ancestry inferred.'
elif q['key']=='proteomap':
 ids=[f'P{i+1:02}'for i in range(24)];rows=[];meta=[]
 patterns=np.array([[1.6,-1.1,.2,.8],[-1.5,.4,1.5,-.6],[.4,1.4,-1.2,-.4],[-.8,-.3,.8,1.6]])
 for j in range(48):
  cl=j//12;cid=f'C{j+1:02}';meta.append([cid,chr(65+cl),round(float(np.clip(.12+.23*cl+rng.normal(0,.08),0,1)),6)])
  for i,p in enumerate(ids):rows.append([p,cid,round(float(patterns[i//6,cl]+rng.normal(0,.44)),6)])
 out('matrix',['protein','compound','value'],rows);out('metadata',['compound','class','score'],meta)
 method='PCG64 4x4 block-pattern log2 fold-change fixture plus normal noise (sd0.44); 24x48 complete matrix; score metadata independent bounded generator. No row scaling; Ward.D2 clustering in renderer.'
elif q['key']=='shapcompare':
 rows=[]
 for i in range(18):
  for j in range(85):
   v=float(rng.uniform(-1,1));e=float(rng.normal(0,.18));amp=.48*np.exp(-i/6)+.025
   for model in ['Narrow','Wide']:
    x=amp*(v*(-1 if i%3==0 else 1)+e)*(1 if model=='Narrow'else 1.25+.23*np.sin(i))
    rows.append([f'P{i+1:02}',f'C{j+1:02}',model,round(v,6),round(x,6)])
 out('attribution',['protein','compound','model','expression','attribution'],rows)
 method='PCG64 18 features x85 compounds x2 variants; decaying feature-specific amplitude, alternating association sign and shared expression/noise. Values are synthetic attribution surrogates, not outputs of a fitted SHAP model.'
elif q['key']=='longitudinal':
 rows=[]
 for i in range(60):
  n=int(rng.integers(6,11));start=float(rng.uniform(-9.8,-3.3));end=float(rng.uniform(2.8,7.8));times=np.sort(rng.uniform(start,end,n));offsets=rng.normal(0,.43,4)
  for j,t in enumerate(times):
   means=[-.4+2.5/(1+np.exp(-(t+1.8)/2)), -.2+2.6/(1+np.exp(-(t-2)/1.4)), -.15+1.9*np.exp(-((t+.8)/3.5)**2), 0.0]
   for k in range(4):rows.append([f'Protein {chr(65+k)}',f'S{i+1:02}',j+1,round(float(t),6),round(float(means[k]+offsets[k]+rng.normal(0,.3)),6)])
 out('observations',['protein','subject','visit','time','value'],rows)
 # Keep the four original trajectory fixtures and add twelve companion rows.
 members={}; observations=[]
 for k in range(4):
  anchor=f'Protein {chr(65+k)}';members[anchor]=k
  raw=[r for r in rows if r[0]==anchor];observations.extend(raw)
  for j in range(3):
   feature=f'{chr(65+k)}{j+1:02}';members[feature]=k
   offsets={r[1]:float(rng.normal(0,.26)) for r in raw if r[2]==1}
   observations.extend([feature,r[1],r[2],r[3],round((.85-.18*j)*r[4]+offsets[r[1]]+float(rng.normal(0,.27)),6)] for r in raw)
 out('heatmap_observations',['protein','subject','visit','time','value'],observations)
 bins={}
 for feature,subject,visit,time,value in observations:
  index=int(np.floor((time+10)*2))
  bins.setdefault((feature,index),[]).append(value)
 out('heatmap',['protein','module','column','n','mean'],[
  [feature,module+1,i+1,len(v),round(float(np.mean(v)),8) if len(v)>=3 else 'NA']
  for feature,module in members.items() for i in range(36)
  for v in [bins.get((feature,i),[])]
 ])

 method='PCG64: 60 independent subjects, 6-10 irregular visits per subject shared across 4 synthetic proteins; Gaussian subject intercept sd0.43 and independent within-subject residual sd0.30. Three smooth response shapes and one null fixture. Fixed reference event at time0 and fixed zero abundance baseline; no patient, disease or observed proteome.'
else:
 rows=[];summary=[];doses=[.03,.1,.3,1,3,10];paths=['Mitochondrial complex','Cytosolic ribosome','DNA replication','Proteostasis'];amps=np.array([[3.9,2.7,1.7,.5],[-1.8,-.6,-1.4,-.2],[.6,1.5,2.6,.4],[2.5,1.4,.5,1.9]])
 for k,path in enumerate(paths):
  for g in range(4):
   baseline=rng.normal(0,.13,36);scale=rng.normal(1,.3,36);ec=.22+.2*g+.12*k
   for dose in doses:
    mu=amps[k,g]*dose/(ec+dose)
    vals=mu*scale+baseline+rng.normal(0,.1,36)
    vals=np.round(vals,6)
    rows.extend([path,chr(65+g),dose,f'P{k*36+i+1:03}',float(v)]for i,v in enumerate(vals))
    summary.append([path,chr(65+g),dose,36,round(float(vals.mean()),9),round(float(vals.std(ddof=1)/6),9)])
 out('profiles',['pathway','series','dose_uM','protein','value'],rows);out('summary',['pathway','series','dose_uM','n_proteins','mean','sem'],summary)
 method='PCG64 4 pathway fixtures x4 series x6 doses x36 synthetic proteins; saturating dose function plus per-protein intercept/slope and noise. Means and SEM=sampleSD/sqrt(36) over proteins; same IDs across doses; not independent biological replicates. Piecewise straight segments on log10-dose axis, no fitted biological potency.'
(W/'simulation.json').write_text(json.dumps(dict(seed=q['seed'],generator='numpy.random.default_rng PCG64',numpy_version=np.__version__,method=method,units='Binary descriptors; synthetic log2 fold-change; synthetic contribution scores; dose in micromolar as applicable',purpose='Visual demonstration and software testing only',files=files),indent=2)+'\n')
print(q['key'],len(files),'data tables')
