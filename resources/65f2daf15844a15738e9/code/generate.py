"""Deterministic synthetic fixtures. No measurements, patient IDs or inferred SVs."""
from pathlib import Path
import csv,json,random,math,sys,hashlib
W=Path(sys.argv[1]).resolve();P=W.parents[1];q=json.loads((W/'config.json').read_text());r=random.Random(q['seed']);out=P/'results/plot_data';out.mkdir(exist_ok=True,parents=True)
def save(name,rows):
 p=out/(q['stem']+'_'+name+'.csv')
 with p.open('w')as f:
  z=csv.DictWriter(f,fieldnames=list(rows[0]));z.writeheader();z.writerows(rows)
 return str(p)
files=[]
if q['key']=='recon':
 bounds=[0,2,5,8,10,12,15,18,21,24,27,30,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,48,51,54,58,62,66,70,75,80,85]
 total=[2,2,3,2,1,2,4,3,3,2,2,3,5,7,4,8,5,3,7,10,6,4,8,5,3,6,4,3,2,2,4,3,2,3,2,2]
 cn=[]
 for sample in ['Profile A','Profile B']:
  for i,(a,b) in enumerate(zip(bounds,bounds[1:])):
   v=total[i]+(r.choice([-1,0,0,0,1])if sample=='Profile B' else 0);v=max(1,v)
   cn.append(dict(sample=sample,segment=f'CN{i+1:02}',start=a,end=b,total=v,minor=min(v//2,0 if 32<=a<46 else 1)))
 sv=[]
 for i in range(48):
  endpoints=sorted(r.sample(bounds[1:-1]if i<17 else bounds[12:27],2))
  sv.append(dict(id=f'SV{i+1:02}',start=endpoints[0],end=endpoints[1],strand=['+-','-+','++','--'][i%4],type=['DEL','DUP','HH','TT'][i%4]))
 files=[save('cn',cn),save('sv',sv)]
elif q['key']=='haplotypes':
 walks=[];segments=[]
 for phase in ['cis','trans']:
  lengths=[]
  for i in range(36):
   a=min(13,max(.12,r.lognormvariate(.2 if phase=='cis' else 1.4,.6)));b=min(9,max(.4,r.lognormvariate(1.05,.55)))
   lengths.append((a,b,i))
  for rank,(a,b,i) in enumerate(sorted(lengths),1):
   id=f'{phase.upper()}-{i+1:02}';walks.append(dict(id=id,phase=phase,rank=rank,locus1=a,locus2=b))
   intervals=[(-12,-b,'Flank'),(-b,0,'Locus 2'),(0,a,'Locus 1'),(a,a+b,'Locus 2'),(a+b,24,'Flank')]if phase=='cis' else [(-12,-b,'Flank'),(-b,0,'Locus 2'),(0,a,'Locus 1'),(a,24,'Flank')]
   for k,(s,e,l) in enumerate(intervals):segments.append(dict(id=id,phase=phase,rank=rank,part=k,start=s,end=e,role=l))
 files=[save('walks',walks),save('segments',segments)]
elif q['key']=='svision':
 seg=[(0,12,0,12,'Forward',.95,.92),(6,12,12,18,'Duplication',.04,.82),(12,20,18,26,'Forward',.95,.94),(20,28,26,26,'Deletion',.08,.88),(28,40,38,26,'Inversion',.12,.91),(40,60,38,58,'Forward',.96,.94)]
 files=[save('segments',[dict(id=f'B{i+1}',ref_start=a,ref_end=b,query_start=c,query_end=d,component=e,control_fraction=f,case_fraction=g)for i,(a,b,c,d,e,f,g)in enumerate(seg)])]
 cov=[]
 for sample in ['Control','Case']:
  for i in range(120):
   pos=i*.5+.25;v=30+(15 if sample=='Case' and 6<=pos<12 else 0)-(22 if sample=='Case' and 20<=pos<28 else 0)
   cov.append(dict(sample=sample,pos=pos,coverage=max(0,round(v+r.gauss(0,2.1),2))))
 files.append(save('coverage',cov))
elif q['key']=='breakgraph':
 seg=[];links=[]
 for i in range(20):
  start=12+i*.63;level=0 if i%6 not in [2,3]else (1 if i%6==2 else 2)
  seg.append(dict(fixture='local',id=f'S{i+1:02}',chrom='chr9',start=start,end=start+.43,lane=level))
 for i in range(30):
  a,b=sorted(r.sample(range(20),2));links.append(dict(fixture='local',id=f'J{i+1:02}',source=f'S{a+1:02}',target=f'S{b+1:02}',type=['HT','TH','HH','TT'][i%4]))
 chrs=['chr2','chr6','chr8','chr17','chr20'];pos=[143,42,14,38,5]
 for c,(ch,p)in enumerate(zip(chrs,pos)):
  for j in range(2):seg.append(dict(fixture='multi',id=f'M{c*2+j+1:02}',chrom=ch,start=p+j*4,end=p+j*4+3,lane=c))
 pairs=[(1,3),(2,6),(3,7),(4,9),(5,10),(6,7),(8,9),(1,10),(2,4),(5,8)]
 for i,(a,b)in enumerate(pairs):links.append(dict(fixture='multi',id=f'T{i+1:02}',source=f'M{a:02}',target=f'M{b:02}',type='Interchr'))
 files=[save('segments',seg),save('junctions',links)]
else:raise ValueError(q['key'])
manifest=dict(origin='SIMULATED; synthetic visual demonstration and software testing only',seed=q['seed'],generator=str(Path(__file__).resolve()),method={'recon':'Predefined piecewise CN, seeded second-profile offsets and boundary-constrained SV endpoints','haplotypes':'Seeded bounded lognormal gap lengths; predefined cis/trans interval topology, ordered by locus1 then locus2','svision':'Explicit piecewise reference/query coordinates for DEL+INV+DUP, prescribed component fractions; seeded coverage noise','breakgraph':'Explicit genomic segments plus seeded within-chromosome edges and fixed interchromosomal edges'}[q['key']],units='Mb for recon/breakgraph, kb for haplotypes/svision',assembly='Synthetic coordinate system; no real reference assembly or genomic inference',files=[dict(path=p,sha256=hashlib.sha256(Path(p).read_bytes()).hexdigest())for p in files])
(W/'simulation.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(q['key'],len(files),'synthetic tables')
