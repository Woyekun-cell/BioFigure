from pathlib import Path
import csv, hashlib, json, sys
import numpy as np
work=Path(sys.argv[1]).resolve()
q=json.loads((work/'config.json').read_text())
rng=np.random.default_rng(q['seed'])
out=work.parents[1]/'results/plot_data'
out.mkdir(exist_ok=True,parents=True)
files=[]
def save(name,fields,rows):
    path=out/(q['stem']+'_'+name+'.csv')
    with path.open('w',newline='') as f:
        writer=csv.writer(f);writer.writerow(fields);writer.writerows(rows)
    files.append(dict(path=str(path),sha256=hashlib.sha256(path.read_bytes()).hexdigest()))

if q['key']=='onco':
    samples=[];events=[];raw=rng.normal(0,.58,(16,120))
    for j in range(120):
        cl=j//40;sample=f'S{j+1:02d}'
        source=('Marrow','Blood')[int(rng.random()<.32)]
        response=float(np.clip(.37+.1*cl+rng.normal(0,.16),.01,.99))
        samples.append((sample,'ABC'[cl],source,round(response,6)))
        raw[:,j]+=np.roll(np.array([1.05,1.14,-.9,-.65,.85,.1,-1.12,-.15,.5,-.6,.8,.2,-.4,-.8,1,-.5]),cl*4)
        for i in range(24):
            chance=.57 if i//8==cl else .09
            if rng.random()<chance:
                kind=str(rng.choice(['SNV','Gain','Loss','Fusion'],p=[.5,.23,.21,.06]))
                events.append((sample,f'G{i+1:02d}',kind))
                if kind!='SNV' and rng.random()<.26:events.append((sample,f'G{i+1:02d}','SNV'))
    scaled=np.round((raw-raw.mean(axis=1,keepdims=True))/raw.std(axis=1,ddof=1,keepdims=True),6)
    save('samples',['sample','subtype','source','score'],samples)
    save('events',['sample','gene','event'],events)
    save('abundance',['sample','feature','value'],[(r[0],f'RNA {i+1}' if i<8 else f'Prot {i-7}',scaled[i,j]) for j,r in enumerate(samples) for i in range(16)])
    method='PCG64, three planted sample strata. Distinct gene-event records and synthetic row-standardized RNA/protein values. Events and values are descriptive fixtures.'
    units='Unique sample counts; event counts; feature-wise Z score; unitless score'
else:
    pathway=['Sug','TCA','Lip','AA','Pur','Pyr','Red','Cof','FA','BA','Cer','PE','PC','Org']
    n=320; features=[]; latent=rng.normal(0,.67,(n,14))
    effect=np.array([.68,-.65,.29,.86,-.36,.55,-.88,.04,.50,-.24,.11,.65,-.40,-.55])
    latent[160:,:]+=effect
    protein=np.roll(latent,1,axis=1)*.66+np.roll(latent,3,axis=1)*-.43+rng.normal(0,.54,(n,14))
    for i in range(14):
        total=int(rng.integers(75,126))
        prob=np.full(14,.022);prob[i]=.36;prob[(i+1)%14]=.22;prob=prob/prob.sum()
        for j in range(total):
            assigned=rng.random()>.28
            features.append((f'F{i+1}',f'M{i+1}-{j+1:02d}',str(rng.choice(pathway,p=prob)) if assigned else 'Unassigned'))
    save('membership',['factor','feature','class'],features)
    save('scores',['sample','cohort']+[f'F{i+1}' for i in range(14)]+[f'P{i+1}' for i in range(14)],
         [(f'S{j+1:02d}','Reference' if j<160 else 'Challenge',*np.round(latent[j],6),*np.round(protein[j],6)) for j in range(n)])
    method='PCG64, assigned feature membership with planted classes, and 320 paired factor/protein-score rows. Scores are simulated directly, with 14 factor axes and group offsets. No ICA fit or enrichment testing.'
    units='Unique feature count; within-factor class fraction; sample Pearson r; mean score'
(work/'simulation.json').write_text(json.dumps(dict(seed=q['seed'],files=files,method=method,units=units),indent=2)+'\n')
