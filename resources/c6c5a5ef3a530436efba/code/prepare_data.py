from pathlib import Path
import csv,json,gzip,re,collections,hashlib
W=Path(__file__).resolve().parent;P=W.parents[1];D=W/'data';O=P/'results/plot_data';O.mkdir(exist_ok=True,parents=True);stem='chromoscope_sv_zoom_20261106'
def save(name,rows):
 assert rows,name
 with (O/(stem+'_'+name+'.csv')).open('w',newline='')as f:
  d=csv.DictWriter(f,list(rows[0]));d.writeheader();d.writerows(rows)
 return len(rows)
def load(name):return list(csv.DictReader((D/name).open(),delimiter='\t'))
sv=load('hartwig.sv.bedpe');cn=load('hartwig.cnv.tsv');target=next(x for x in sv if x['sv_id']=='gridss176fb_3143o');assert target['start1']=='87954020' and target['start2']=='88010560'
counts={'sv':save('sv',sv),'cnv':save('cnv',cn)}
sizes=json.loads((D/'sizes.json').read_text())['chromosomes'];chroms=['chr'+str(i)for i in range(1,23)]+['chrX','chrY'];save('sizes',[dict(chromosome=c,length=sizes[c])for c in chroms]);save('cytoband',[r for r in csv.DictReader((D/'cytoband.csv').open())if r['Chromosome']in chroms])
# Publication labels retained; choose one longest coding RefSeq transcript per named gene.
genes=json.loads((D/'genes.json').read_text())['ncbiRefSeq'];selected=[];exons=[]
for name in ['PAPSS2','ATAD1','PTEN']:
 g=sorted([x for x in genes if x['name2']==name and x['name'].startswith('NM_')],key=lambda x:(-(x['txEnd']-x['txStart']),x['name']))[0]
 selected.append(dict(gene=name,transcript=g['name'],start=g['txStart'],end=g['txEnd'],strand=g['strand']))
 for i,(a,b)in enumerate(zip(g['exonStarts'].strip(',').split(','),g['exonEnds'].strip(',').split(','))):exons.append(dict(gene=name,transcript=g['name'],exon=i+1,start=int(a),end=int(b)))
save('genes',selected);save('exons',exons)
variants=[]
for typ in ['snv','indel']:
 with gzip.open(D/(typ+'.vcf.gz'),'rt')as f:
  for line in f:
   if line.startswith('#'):continue
   a=line.rstrip().split('\t')
   if a[0]in ['10','chr10']and 87700000<=int(a[1])<=88150000:
    variants.append(dict(kind=typ,chromosome=a[0],pos1=int(a[1]),start0=int(a[1])-1,ref=a[3],alt=a[4],filter=a[6]))
save('variants',variants)
regions={'left':(87953700,87954350),'right':(88010250,88010900)};reads=[];blocks=[];coverage=[];bases=[]
for line in (D/'breakpoints.sam').read_text().splitlines():
 if line.startswith('@'):continue
 a=line.split('\t');flag=int(a[1]);pos=int(a[3])-1
 if flag&4:continue
 ops=[(int(n),op)for n,op in re.findall(r'(\d+)([MIDNSHP=X])',a[5])];end=pos+sum(n for n,op in ops if op in 'MDN=X')
 side=next((k for k,(l,h)in regions.items()if pos<h and end>l),None)
 if not side:continue
 reads.append(dict(side=side,read_id=a[0]+':'+a[1]+':'+a[3]+':'+a[5],name=a[0],flag=flag,chromosome=a[2],start=pos,end=end,mapq=int(a[4]),strand='-'if flag&16 else'+',cigar=a[5],sequence=a[9],ops=ops))
assert len(reads)>100,'SAM not yet fully downloaded'
left=collections.defaultdict(list);right=collections.defaultdict(list)
for r in reads:(left if r['side']=='left'else right)[r['name']].append(r)
classes={}
for name in left.keys()&right.keys():
 if len(left[name])==len(right[name])==1:
  classes[name]={('+','-'):'DEL',('-','+'):'DUP',('-','-'):'t2tINV',('+','+'):'h2hINV'}[(left[name][0]['strand'],right[name][0]['strand'])]
for side,(lo,hi)in regions.items():
 lane_ends=[];depth=[0]*(hi-lo);ref=json.loads((D/(side+'-sequence.json')).read_text())['dna'].upper()
 for i,b in enumerate(ref):bases.append(dict(side=side,pos=lo+i,base=b))
 for r in sorted([r for r in reads if r['side']==side],key=lambda r:(r['start'],r['end'],r['read_id'])):
  ops=r.pop('ops');r['sv_type']=classes.get(r['name'],'regular')
  leftclip=ops[0][0]if ops[0][1]in 'SH'else 0;rightclip=ops[-1][0]if ops[-1][1]in 'SH'else 0
  r['left_clip']=leftclip;r['right_clip']=rightclip
  # Same 5 bp collision padding as author alignment.ts. Include projected clips in packing.
  start=r['start']-leftclip;end=r['end']+rightclip
  lane=next((i for i,v in enumerate(lane_ends)if v+5<=start),len(lane_ends))
  if lane==len(lane_ends):lane_ends.append(end)
  else:lane_ends[lane]=end
  r['lane']=lane+1;p=r['start'];qi=0
  for n,op in ops:
   if op in 'M=X':
    blocks.append(dict(side=side,read_id=r['read_id'],lane=lane+1,start=p,end=p+n,kind='aligned',sv_type=r['sv_type']))
    for x in range(max(p,lo),min(p+n,hi)):depth[x-lo]+=1
    # Observed mismatch bases, preserving SAM reference-aligned sequence.
    for j in range(n):
     x=p+j
     if lo<=x<hi and r['sequence'][qi+j]in 'ACGT' and r['sequence'][qi+j]!=ref[x-lo]:
      blocks.append(dict(side=side,read_id=r['read_id'],lane=lane+1,start=x,end=x+1,kind=r['sequence'][qi+j],sv_type=r['sv_type']))
    p+=n;qi+=n
   elif op in 'DN':
    blocks.append(dict(side=side,read_id=r['read_id'],lane=lane+1,start=p,end=p+n,kind=op,sv_type=r['sv_type']));p+=n
   elif op=='I':qi+=n
   elif op=='S':
    a=p-n if qi==0 else p;b=p if qi==0 else p+n
    blocks.append(dict(side=side,read_id=r['read_id'],lane=lane+1,start=a,end=b,kind='clip',sv_type=r['sv_type']));qi+=n
   elif op=='H':pass
  r.pop('sequence')
 coverage.extend(dict(side=side,pos=lo+i,depth=v)for i,v in enumerate(depth))
 counts[side+'_reads']=sum(r['side']==side for r in reads);counts[side+'_lanes']=len(lane_ends)
counts.update(reads=save('reads',reads),blocks=save('read_blocks',blocks),coverage=save('coverage',coverage),bases=save('bases',bases),paired_highlight_names=len(classes),deletion_names=sum(x=='DEL'for x in classes.values()))
(W/'data-summary.json').write_text(json.dumps(dict(counts=counts,target=target,regions=regions,assembly='hg38',coordinates='Internal 0-based; VCF and SAM converted from 1-based; BEDPE preserved; UCSC 0-based.'),indent=2)+'\n');print(counts)
