#!/usr/bin/env python3
"""Retrieve derived method families and package dependencies from the unified graph."""
import argparse,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
GRAPH=ROOT/'atlas/unified-capability-graph.json'
def toks(s): return set(re.findall(r'[a-z0-9_.+-]+|[\u4e00-\u9fff]{2,}',s.lower()))
def retrieve(query,limit=8):
 g=json.loads(GRAPH.read_text()); q=toks(query); edges=g['edges']; nodes={x['id']:x for x in g['nodes']}
 scored=[]
 for n in g['nodes']:
  if n.get('kind')!='case': continue
  related=[e['to'] for e in edges if e['from']==n['id']]
  text=' '.join([n.get('label',''),n.get('source','')]+[nodes.get(x,{}).get('label','') for x in related])
  overlap=len(q&toks(text))
  if overlap:
   score=overlap+(3 if n.get('visual_status','').startswith('source-compared') else 0)
   scored.append((score,n,related))
 scored.sort(key=lambda x:(-x[0],x[1]['id']))
 return {'query':query,'status_boundary':g['summary']['status_boundary'],'results':[{'case_id':n['id'],'title':n['label'],'source':n['source'],'validation_status':n['status'],'visual_status':n.get('visual_status','not-run'),'method_families':[nodes[x]['label'] for x in rel if x.startswith('family:')],'packages':[nodes[x]['label'] for x in rel if x.startswith('package:')]} for _,n,rel in scored[:limit]]}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--query',required=True);p.add_argument('--limit',type=int,default=8);p.add_argument('--output',type=Path);a=p.parse_args();s=json.dumps(retrieve(a.query,a.limit),ensure_ascii=False,indent=2)+'\n';a.output.write_text(s) if a.output else print(s,end='')
