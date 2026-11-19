from pathlib import Path
import csv,json,hashlib,re,collections
P=Path(__file__).resolve().parents[2];W=Path(__file__).resolve().parent;G=P/'work/2026-10-13-deep-omics-learning/genome/sources/SynPan-CEN';D=P/'results/plot_data';D.mkdir(exist_ok=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
rows=[];info={};paths=[]
for sample in ['NIP','SL177']:
 f=G/f'{sample}_full_annotation.rmdup.txt';paths.append(f);raw=[r for r in csv.reader(f.open(),delimiter='\t') if r[0]==f'Chr01_{sample}'];origin=min(int(r[1])for r in raw)
 for i,r in enumerate(raw):
  chrom,start,end,strand,id0,group=r;start=int(start);end=int(end);assert end>=start
  id=f'{chrom}.LTR.{i}'if group in ['LTR','other_repeat']else id0
  family=('F'+re.search(r'(?:S?F)(\d+)\.',id0).group(1))if group.startswith('group')or group.endswith('+')else {'Gene':'Gene','Interval':'Interval','LTR':'LTR','other_repeat':'Other repeat'}.get(group,group)
  te=('SZ-22'if 'SZ-22'in id0 else 'RIRE'if 'RIRE'in id0 else 'Other LTR')if group=='LTR'else 'DNA transposon'if group=='other_repeat'else ''
  rows.append(dict(sample=sample,row_index=i,chrom=chrom,original_id=id0,match_id=id,group=group,family=family,strand=strand,absolute_start=start,absolute_end=end,start=start-origin,end=end-origin,te=te))
 info[sample]=dict(features=len(raw),origin_bp=origin,span_bp=max(int(r[2])for r in raw)-origin)
byid={(r['sample'],r['match_id']):r for r in rows};assert len(byid)==5900
sg=G/'Chr01_NIP_SL177_pairED15.sg_filter';dag=G/'Chr01_NIP_SL177_group_pairED_order_all.dag_fortest';paths.extend([sg,dag]);rawpairs=list(csv.reader(sg.open(),delimiter='\t'));first_ref=[];seen=set()
for r in rawpairs:
 if r[1]not in seen:first_ref.append(r);seen.add(r[1])
filtered=[];seen=set()
for r in first_ref:
 if r[5]not in seen:filtered.append(r);seen.add(r[5])
scores={}
for r in csv.reader(dag.open(),delimiter='\t'):scores.setdefault((r[1],r[5]),float(r[9]))
pairs=[]
for i,r in enumerate(filtered):
 a,b=byid[('NIP',r[1])],byid[('SL177',r[5])];ed=scores.get((r[1],r[5]));pairs.append(dict(pair_id=i,ref_id=r[1],query_id=r[5],ref_start=a['start'],ref_end=a['end'],query_start=b['start'],query_end=b['end'],ED=''if ed is None else ed,ED_status='Unavailable'if ed is None else 'ED 0',ref_family=a['family'],query_family=b['family']))
assert len(pairs)==1799 and sum(p['ED']!=''for p in pairs)==8 and {p['ED']for p in pairs if p['ED']!=''}=={0.0}
assert len({r['ref_id']for r in pairs})==len({r['query_id']for r in pairs})==len(pairs)
for name,data in [('features',rows),('pairs',pairs)]:
 f=D/f'rice_centromere_20261026_{name}.csv'
 with f.open('w')as out:w=csv.DictWriter(out,fieldnames=list(data[0]));w.writeheader();w.writerows(data)
qc=dict(status='PASS',data_origin='Unchanged author processed repository example: real NIP and SL177 Chr1 annotations and supplied matching IDs; not manuscript Fig5a materials.',materials=info,features=len(rows),raw_match_rows=len(rawpairs),one_to_one_pairs=len(pairs),ED_available=8,ED_missing=1791,ED_available_values=[0],feature_categories=dict(collections.Counter(r['family']for r in rows)),intervals_preserved=sum(r['group']=='Interval'for r in rows),genes_preserved=sum(r['group']=='Gene'for r in rows),local_coordinate_policy='Each material start minus its own minimum annotation start, both shown on one shared bp scale; source end-start convention retained.',deduplication='First reference-ID row, then first query-ID row, identical to author Merge_Tracks_Pairs.',scope='Chr1 repository example only. All1799 source matches shown; ribbon colors keyed to reference NIP family independently of ED. Native script only renders eight score-covered pairs; this adaptation retains all matches and keeps ED missing in the paired table.',remaining_paper_inputs='Fig5a Chr2/Chr3 three-material inputs; Fig6d ten-material CENH3 tracks; Fig4c/d exact similarity inputs unavailable.',source_files=[dict(path=str(f),sha256=sha(f))for f in paths]);(W/'input-qc.json').write_text(json.dumps(qc,indent=2,ensure_ascii=False)+'\n');print(json.dumps(qc,ensure_ascii=False))
