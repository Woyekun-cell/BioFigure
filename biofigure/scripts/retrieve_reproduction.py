#!/usr/bin/env python3
"""Retrieve abstract reproduction patterns; never expose source code."""
from __future__ import annotations
import argparse,hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];CORPUS=ROOT/'atlas/reproduction-derived-corpus.json'
ALIASES={'热图':['matrix','Heatmap','ComplexHeatmap'],'生存':['time-to-event','survfit','ggsurvplot'],'环':['circular','circos'],'泳道':['clinical'],'富集':['enrichment'],'时间':['time-series']}
def tokens(s): return list(dict.fromkeys(re.findall(r'[A-Za-z0-9_.+-]+|[\u4e00-\u9fff]{2,}',s.lower())))
def score_case(case,query):
 expanded=query+' '+' '.join(v for k,vals in ALIASES.items() if k in query for v in vals)
 fields={'title':case['title'],'tags':' '.join(case['chart_tags']),'advantages':' '.join(case.get('advantage_tags',[])),'packages':' '.join(case['code_analysis']['packages']),'primitives':' '.join(case['code_analysis']['primitives']),'techniques':' '.join(case['code_analysis'].get('coding_techniques',[]))}
 weights={'title':9,'tags':7,'advantages':4,'packages':6,'primitives':5,'techniques':4};score=0
 for token in tokens(expanded):
  for key,value in fields.items():
   if token.lower() in value.lower():score+=weights[key]
 return score
def rank_cases(cases,query,limit):
 ranked=sorted(((score_case(c,query),c) for c in cases),key=lambda x:(-x[0],x[1]['case_id']))
 results=[]
 for score,c in ranked:
  if score<=0:continue
  results.append({k:c.get(k,[] if k in {'chart_tags','advantage_tags','layout_tags','visuals'} else '') for k in ['case_id','title','source_url','chart_tags','advantage_tags','layout_tags','code_analysis','visuals']}|{'score':score})
  if len(results)>=limit:break
 return {'query':query,'results':results,'generation_contract':{'author_material_access':'forbidden','implementation':'new-script-from-user-data-and-derived-patterns','technique_transfer':'abstract-patterns-only','requires_render_and_visual_review':True}}
def retrieve(query,limit=5):
 out=rank_cases(json.loads(CORPUS.read_text())['cases'],query,max(3,min(limit,5)))
 out['schema_version']=1;out['corpus']={'path':str(CORPUS.resolve()),'sha256':hashlib.sha256(CORPUS.read_bytes()).hexdigest()}
 return out
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--query',required=True);p.add_argument('--limit',type=int,default=5);p.add_argument('--json',action='store_true');p.add_argument('--output',type=Path);a=p.parse_args();out=retrieve(a.query,a.limit);payload=json.dumps(out,ensure_ascii=False,indent=2)+'\n';a.output.write_text(payload) if a.output else print(payload,end='');raise SystemExit(0 if len(out['results'])>=3 else 1)
