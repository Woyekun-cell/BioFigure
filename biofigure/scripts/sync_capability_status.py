#!/usr/bin/env python3
"""Synchronize reviewed method evidence into the unified capability graph."""
from __future__ import annotations
import argparse, json, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
GRAPH=ROOT/'atlas/unified-capability-graph.json'; METHODS=ROOT/'atlas/reproduction-methods.json'
SCIDRAW_METHODS=ROOT/'atlas/scidraw-source-compared-methods.json'
SCIDRAW_BATCH2_METHODS=ROOT/'atlas/scidraw-batch2-methods.json'
SCIDRAW_NODE_MAP={
 'SCIDRAW-RCS-001':'scidraw-a2dd8d3b52',
 'SCIDRAW-RIDGE-BIPOLAR-001':'scidraw-709e0a8c86',
 'SCIDRAW-PCOA-MARGINAL-001':'scidraw-62b8290bc1',
 'SCIDRAW-TERNARY-001':'scidraw-6be07d3441',
 'SCIDRAW-CORRPLOT-001':'scidraw-9a92615206',
 'SCIDRAW-SWIMMER-001':'scidraw-1a060be0fe',
 'SCIDRAW-CHORD-TRACK-001':'scidraw-fdf13d26d3',
 'SCIDRAW-VOLCANO-GSEA-001':'scidraw-f749086eb5',
}

def synchronize_registered_cases(graph, registry, results):
 by_id={node['id']:node for node in graph['nodes'] if node.get('kind')=='case'}
 for record in registry['cases']:
  cid=record['case_id']
  if cid not in by_id:
   node={'id':cid,'kind':'case','label':record.get('label',cid),
         'source':record.get('source','registered-source-learning'),
         'status':'source-learning-registered','visual_status':'NOT_VERIFIED',
         'review_status':'NOT_VERIFIED','high_fidelity_eligible':False,
         'learning_source':record.get('learning_source'),
         'scope':'Registered source learning only; no current execution or visual qualification inferred.'}
   graph['nodes'].append(node);by_id[cid]=node
  node=by_id[cid]
  # These scoped source-exposed cases require their own actual evidence bundle.
  # Preserve the historical review, but do not advertise unavailable private
  # bundles as current public high-fidelity capability.
  if (str(node.get('generation_mode','')).startswith('source-exposed-independent')
      and results.get(cid,{}).get('tracks',{}).get('reproduction',{}).get('status')!='PASS'):
   node.setdefault('historical_source_review', {k:node.get(k) for k in
       ('visual_status','review_status','high_fidelity_eligible','generation_mode')})
   node.update(visual_status='source-materials-unavailable',review_status='NOT_VERIFIED',
               high_fidelity_eligible=False,current_public_bundle_status='NOT_DISTRIBUTED_OR_NOT_VERIFIED')
 return graph

def expected_topjournal_state(node, by_issue):
 match=re.fullmatch(r'topfigure-(\d+)-[0-9a-f]+',node.get('id',''))
 if not match:return None
 method=by_issue.get(int(match.group(1)))
 if method is not None:
  visual=method.get('runtime_status','not-run');review=method.get('review_status','missing')
  return visual,review,visual=='source-compared-png' and review=='pass'
 # Current fixed-data bundles retain their own scope; they do not inherit
 # legacy source-comparison or new-input qualification.
 from benchmark_core import registry_results
 track=registry_results(ROOT).get(node['id'],{}).get('tracks',{}).get('reproduction',{})
 return ('source-structure-simulation','pass',False) if track.get('status')=='PASS' else ('not-run','missing',False)

def synchronize(graph,methods,scidraw_methods,scidraw_batch2_methods):
 by_issue={x['issue']:x for x in methods['cases']}
 for node in graph['nodes']:
  match=re.fullmatch(r'topfigure-(\d+)-[0-9a-f]+',node.get('id',''))
  if not match: continue
  visual,review,eligible=expected_topjournal_state(node,by_issue)
  node.update(visual_status=visual,review_status=review,high_fidelity_eligible=eligible)
 by_node={node['id']:node for node in graph['nodes']}
 for method in scidraw_methods['cases']:
  node_id=SCIDRAW_NODE_MAP[method['id']]
  if node_id not in by_node: raise ValueError(f'missing SciDraw graph node: {node_id}')
  node=by_node[node_id]
  node['visual_status']=method.get('runtime_status','not-run')
  node['review_status']=method.get('review_status','missing')
  node['high_fidelity_eligible']=node['visual_status']=='source-compared-png' and node['review_status']=='pass'
 for method in scidraw_batch2_methods['cases']:
  node_id=method['graph_node_id']
  if node_id not in by_node: raise ValueError(f'missing SciDraw graph node: {node_id}')
  node=by_node[node_id]
  node['visual_status']=method.get('runtime_status','not-run')
  node['review_status']=method.get('review_status','missing')
  node['high_fidelity_eligible']=node['visual_status']=='source-compared-png' and node['review_status']=='pass'
 source_compared=[n for n in graph['nodes'] if n.get('kind')=='case' and n.get('visual_status','').startswith('source-compared')]
 passed=[n for n in source_compared if n.get('high_fidelity_eligible')]
 graph['summary']['source_compared_cases']=len(source_compared)
 graph['summary']['source_compared_pass']=len(passed)
 graph['summary']['source_compared_needs_revision']=len(source_compared)-len(passed)
 graph['summary']['status_boundary']='Source review: only review_status=pass means historical fidelity accepted. Fixed-data reproduction, source-exposed new-input reuse, stress and user acceptance are separate; no old PASS certifies new output.'
 return graph

def main():
 p=argparse.ArgumentParser();p.add_argument('--output',default=str(GRAPH));a=p.parse_args()
 from benchmark_core import registry_results
 graph=json.loads(GRAPH.read_text())
 graph['summary'].setdefault('historical_source_review_summary', {k:graph['summary'].get(k) for k in
     ('source_compared_cases','source_compared_pass','source_compared_needs_revision')})
 graph=synchronize_registered_cases(graph,json.loads((ROOT/'benchmark/registry.json').read_text()),registry_results(ROOT))
 graph=synchronize(
  graph,
  json.loads(METHODS.read_text()),
  json.loads(SCIDRAW_METHODS.read_text()),
  json.loads(SCIDRAW_BATCH2_METHODS.read_text()),
 )
 from collections import Counter
 cases=[n for n in graph['nodes'] if n.get('kind')=='case']
 graph['summary']['case_count']=len(cases)
 graph['summary']['source_counts']=dict(Counter(n.get('source','unknown') for n in cases))
 Path(a.output).write_text(json.dumps(graph,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps(graph['summary'],ensure_ascii=False,indent=2)); return 0
if __name__=='__main__': raise SystemExit(main())
