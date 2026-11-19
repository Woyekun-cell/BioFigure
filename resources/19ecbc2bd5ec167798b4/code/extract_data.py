#!/usr/bin/env python3
"""Run unchanged upstream BAM functions; independently audit CIGAR accumulation."""
import argparse,csv,hashlib,importlib.util,json,sys,types,collections
from pathlib import Path
import pysam
p=argparse.ArgumentParser();p.add_argument('root',type=Path);p.add_argument('out',type=Path);a=p.parse_args()
u=a.root.resolve()/'sources/upstream'; out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
spec=importlib.util.spec_from_file_location('upstream',u/'ggsashimi.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
region='chr10:27040584-27048100';m.args=types.SimpleNamespace(coordinates=region); chrom,start,end=m.parse_coordinates(region)
rows=list(csv.reader((u/'examples/input_bams.tsv').open(),delimiter='\t')); coverage=[]; junction_rows=[]; sample_rows=[]; qc=[]; all_j=[]
for order,(lib,bam,group) in enumerate(rows,1):
 path=u/'examples'/bam; cv,jj=m.read_bam(str(path),region,'NONE'); vals=m.prepare_for_R(cv['+'],jj['+'],region,10)
 independent=[0]*(end-start); ij=collections.Counter(); cigars=collections.Counter(); flags=collections.Counter(); skipped=0; fetched=0
 with pysam.AlignmentFile(str(path)) as af:
  header=af.header.to_dict()
  for r in af.fetch(chrom,start,end):
   fetched+=1;flags[str(r.flag)]+=1
   for op,n in r.cigartuples or []: cigars[pysam.CIGAR_OPS(op).name]+=1
   if r.is_unmapped or any(op in (5,6,7,8) for op,n in r.cigartuples): skipped+=1;continue
   pos=r.reference_start+1
   for op,n in r.cigartuples:
    if op==0:
     for x in range(max(pos,start),min(pos+n,end)): independent[x-start]+=1
    if op==3 and pos>start and pos+n<end:ij[(pos,pos+n)]+=1
    if op in (0,2,3):pos+=n
 assert independent==cv['+'] and dict(ij)==dict(jj['+'])
 for x,y in zip(vals[0],vals[1]):coverage.append([order,lib,Path(bam).name.split('.')[0],group,chrom,x,y])
 for (don,acc),count in jj['+'].items():
  junction_rows.append([order,lib,group,chrom,don,acc,count,count>=10]);
  if count>=10:all_j.append((don,acc))
 sample_rows.append([order,lib,Path(bam).name.split('.')[0],group,bam,fetched,skipped,len(jj['+']),sum(v>=10 for v in jj['+'].values()),max(cv['+']),sum(cv['+'])])
 qc.append({'library_id':lib,'file_id':Path(bam).name.split('.')[0],'group':group,'fetched_alignments':fetched,'skipped_alignments':skipped,'CIGAR_operations':dict(cigars),'flags':dict(flags),'source_header':header,'independent_exact_match':True})
trans,exons=m.read_gtf(str(u/'examples/annotation.gtf'),region)
def write(name,fields,data):
 with (out/name).open('w',newline='') as f:w=csv.writer(f);w.writerow(fields);w.writerows(data)
write('coverage.csv',['input_order','library_id','file_id','group','chromosome','upstream_position','coverage'],coverage)
write('junctions.csv',['input_order','library_id','group','chromosome','upstream_donor','upstream_acceptor','alignment_count','passes_M10'],junction_rows)
write('samples.csv',['input_order','library_id','file_id','group','bam','fetched_alignments','skipped_alignments','raw_junctions','M10_junctions','max_coverage','total_covered_bases'],sample_rows)
write('transcripts.csv',['transcript_id','start','end','strand'],[[tx.strip('"'),*v[:2],v[2].strip('"')] for tx,v in trans.items()])
write('exons.csv',['transcript_id','exon_start','exon_end','strand'],[[tx.strip('"'),*v[:2],v[2].strip('"')] for tx,es in exons.items() for v in es])
introns=list(m.intersect_introns(sorted(set(all_j))))
summary={'schema_version':1,'region':region,'upstream_coordinate_array':[start,end-1],'positions_per_library':end-start,'BAMs':len(rows),'group_sizes':dict(collections.Counter(x[2] for x in rows)),'coverage_rows':len(coverage),'raw_junction_rows':len(junction_rows),'M10_junction_rows':sum(x[-1] for x in junction_rows),'transcripts':len(trans),'exons':sum(map(len,exons.values())),'intersected_introns':introns,'scientific_unit':'alignment coverage and junction support; no biological n or inferential statistics','source_coordinate_note':'Faithfully preserves upstream parse_coordinates start-1 plus read.reference_start+1; do not equate to standard 0-based pileup','samples':qc,'environment':{'Python':sys.version,'pysam':pysam.__version__,'htslib':pysam.__samtools_version__},'files':{x.name:hashlib.sha256(x.read_bytes()).hexdigest() for x in sorted(out.glob('*.csv'))}}
(out/'data-qc.json').write_text(json.dumps(summary,indent=2)+'\n');print({k:v for k,v in summary.items() if k not in ('samples','environment','files')})
