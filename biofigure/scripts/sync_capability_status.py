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

def synchronize(graph,methods,scidraw_methods,scidraw_batch2_methods):
 by_issue={x['issue']:x for x in methods['cases']}
 for node in graph['nodes']:
  match=re.fullmatch(r'topfigure-(\d+)-[0-9a-f]+',node.get('id',''))
  if not match: continue
  method=by_issue.get(int(match.group(1)),{})
  node['visual_status']=method.get('runtime_status','not-run')
  node['review_status']=method.get('review_status','missing')
  node['high_fidelity_eligible']=node['visual_status']=='source-compared-png' and node['review_status']=='pass'
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
 return graph

def main():
 p=argparse.ArgumentParser();p.add_argument('--output',default=str(GRAPH));a=p.parse_args()
 graph=synchronize(
  json.loads(GRAPH.read_text()),
  json.loads(METHODS.read_text()),
  json.loads(SCIDRAW_METHODS.read_text()),
  json.loads(SCIDRAW_BATCH2_METHODS.read_text()),
 )
 Path(a.output).write_text(json.dumps(graph,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps(graph['summary'],ensure_ascii=False,indent=2)); return 0
if __name__=='__main__': raise SystemExit(main())
