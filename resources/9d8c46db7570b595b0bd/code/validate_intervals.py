#!/usr/bin/env python3
"""Independent base-Python interval checks; no ggtranscript/GenomicRanges implementation reused."""
from pathlib import Path
import csv,json
root=Path(__file__).resolve().parents[1]
def read(name):
 with (root/"results/plot_data"/(name+".csv")).open() as f:return list(csv.DictReader(f))
def bases(rows):
 return set().union(*(set(range(int(r["start"]),int(r["end"])+1)) for r in rows))
results={}
for gene in ("sod1","pknox1"):
 ex=read(gene+"_exons");mp=read(gene+"_mapping");diff=read(gene+"_differences_genomic")
 tx=sorted({r["transcript_name"] for r in ex});ref=gene.upper()+"-201";refbases=bases([r for r in ex if r["transcript_name"]==ref])
 total=sorted(bases(ex));gaps=[(a+1,b-1) for a,b in zip(total,total[1:]) if b-a>1]
 def compress(x):return x-total[0]+2-sum(max(0,b-a+1-100) for a,b in gaps if b<x)
 for r in mp:
  assert compress(int(r["original_start"]))==int(r["scaled_start"])
  assert compress(int(r["original_end"]))==int(r["scaled_end"])
 for t in tx:
  curr=bases([r for r in ex if r["transcript_name"]==t])
  for kind,expected in [("not_in_ref",curr-refbases),("in_ref",refbases-curr)]:
   actual=bases([r for r in diff if r["transcript_name"]==t and r["diff_type"]==kind])
   assert expected==actual,(gene,t,kind)
 results[gene]={"status":"PASS","independent_exon_mapping_checked":len(mp),"transcripts":len(tx),"set_difference_checked_per_transcript":True,"common_gap_compression_exact":True,"original_union_exon_bases":len(total),"common_intronic_gaps":gaps,"compressed_bp_removed":sum(max(0,b-a+1-100) for a,b in gaps)}
output=root/"results/qa/independent-interval-audit.json";output.write_text(json.dumps(results,indent=2)+"\n");print(output)

