from pathlib import Path
import csv,math,json
W=Path(__file__).resolve().parent;P=W.parents[1];D=P/'work/2026-11-06-genomics-source-a/aligned_TADbit_TAD-borders.tsv';O=P/'results/plot_data/p53_tad_dynamics_20261106';O.mkdir(parents=True,exist_ok=True)
times=['0h','1h','4h','7h','10h','24h','w24h'];rows=list(csv.DictReader(D.open(),delimiter='\t'))
for i,r in enumerate(rows):r['source_row']=i+1
value=lambda r,k:float(r[k])if r[k]else math.nan
rows.sort(key=lambda r:(r['Chromosome'],float(r['position'])))
retained=[r for r in rows if any(value(r,'score_'+t)>4 for t in times[:-1])]
inv=sum(all(value(r,'score_'+t)>4 for t in times)for r in retained);assert inv==2032
counts=[];sizes=[];excluded=[]
for t in times:
 border=[r for r in retained if value(r,'score_'+t)>4];counts.append(dict(timepoint=t,total=len(border),invariant=inv,variant=len(border)-inv))
 for chrom in sorted({r['Chromosome']for r in retained}):
  prev=1;prev_row='chromosome-start-index-1'
  for r in retained:
   if r['Chromosome']!=chrom or not(value(r,'score_'+t)>4):continue
   pos=value(r,'pos_'+t);bp=(pos-prev)*50000
   entry=dict(timepoint=t,chromosome=chrom,source_row=r['source_row'],previous_source_row=prev_row,source_position=r['position'],pos_bin=pos,previous_pos_bin=prev,size_bp=bp)
   (excluded if bp>1900000 else sizes).append(entry);prev=pos;prev_row=r['source_row']
changes=[]
for a,b in zip(times,times[1:]):
 gain=sum(not(value(r,'score_'+a)>4)and(value(r,'score_'+b)>4)for r in retained);loss=sum((value(r,'score_'+a)>4)and not(value(r,'score_'+b)>4)for r in retained);changes.append(dict(from_time=a,to_time=b,gain=gain,loss=loss,total=gain+loss,gain_fraction=gain/(gain+loss)))
def q7(a,p):
 h=(len(a)-1)*p;i=math.floor(h);return a[i]+(a[min(i+1,len(a)-1)]-a[i])*(h-i)
boxes=[]
for t in times:
 a=sorted(x['size_bp']for x in sizes if x['timepoint']==t);q1,med,q3=[q7(a,p)for p in [.25,.5,.75]];iqr=q3-q1;boxes.append(dict(timepoint=t,n=len(a),q1_bp=q1,median_bp=med,q3_bp=q3,whisker_low_bp=min(x for x in a if x>=q1-1.5*iqr),whisker_high_bp=max(x for x in a if x<=q3+1.5*iqr),minimum_bp=min(a),maximum_bp=max(a)))
annotations=[dict(control='0h',comparison=t,label='*',reported_threshold='P<0.01',origin='Published Figure2A significance annotation; no test recomputed for plotting')for t in times[1:]]
def write(name,data):
 with(O/name).open('w',newline='')as f:
  out=csv.DictWriter(f,list(data[0]));out.writeheader();out.writerows(data)
for name,data in [('tad_sizes.csv',sizes),('excluded_intervals.csv',excluded),('border_counts.csv',counts),('gain_loss.csv',changes),('box_summary.csv',boxes),('imported_annotations.csv',annotations)]:write(name,data)
assert len(rows)==4962 and len(retained)==4610 and len(sizes)==20851 and len(excluded)==1865
labels=['A','B','TAD size (Mb)','Number of TAD borders','Invariant','Variant','Gain / loss','Nut 0h','Nut 1h','Nut 4h','Nut 7h','Nut 10h','Nut 24h','Wash','*','0.0','0.5','1.0','1.5','2.0']+[f"n={x['n']:,}"for x in boxes]+[str(x['invariant'])for x in counts]+[str(x['variant'])for x in counts]+[f"+{x['gain']}"for x in changes]+[f"-{x['loss']}"for x in changes]
(W/'text-manifest.json').write_text(json.dumps(dict(labels=labels),indent=2)+'\n');(W/'data-summary.json').write_text(json.dumps(dict(input_rows=len(rows),retained_border_rows=len(retained),tad_intervals=len(sizes),excluded_gt1p9Mb=len(excluded),counts=counts,changes=changes,size_n=[x['n']for x in boxes],statistics='SixpublishedsourceP<.01starsimported;nonewtest,pvalueorbiologicalreplicateclaim.'),indent=2)+'\n');print('TADsourceprepared',len(sizes),'sizes',len(excluded),'excluded',inv,'invariant')
