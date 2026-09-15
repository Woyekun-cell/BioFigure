#!/usr/bin/env python3
"""Retrieve abstract reproduction patterns; never expose source code."""
from __future__ import annotations
import argparse,hashlib,json,re
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from benchmark_core import registry_results
ROOT=Path(__file__).resolve().parents[1];CORPUS=ROOT/'atlas/reproduction-derived-corpus.json';METHODS=ROOT/'atlas/reproduction-methods.json'
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
 return {'query':query,'results':results,'generation_contract':{'author_material_access':'authorized-inspection-no-copy','implementation':'new-script-from-user-data-and-derived-patterns','technique_transfer':'abstract-patterns-and-method-structure','requires_render_and_visual_review':True}}
def high_fidelity_eligible(method):
 return method.get('runtime_status') == 'source-compared-png' and method.get('review_status') == 'pass'
def retrieve(query,limit=5,require_validated=False,require_benchmark=False):
 benchmark=registry_results(ROOT)
 graph=json.loads((ROOT/'atlas/unified-capability-graph.json').read_text())
 by_issue={int(n['id'].split('-')[1]):n['id'] for n in graph['nodes'] if n.get('id','').startswith('topfigure-')}
 corpus_cases=json.loads(CORPUS.read_text())['cases']
 candidate_limit=len(corpus_cases) if require_validated else max(3,min(limit,5))
 out=rank_cases(corpus_cases,query,candidate_limit)
 methods={x['issue']:x for x in json.loads(METHODS.read_text())['cases']}
 for item in out['results']:
  issue=int(item['case_id'].split('-')[-1]);m=methods.get(issue,{})
  item['package_method']={k:m.get(k) for k in ('core_packages','core_package_status','key_functions','runtime_status','review_status','validated_pngs','validation_date','validation_note')}
  item['high_fidelity_eligible']=high_fidelity_eligible(m)
  item['legacy_review_eligible']=item['high_fidelity_eligible']
  item['benchmark_status']=benchmark.get(by_issue.get(issue,''),{}).get('status','PENDING')
  item['benchmark_eligible']=item['benchmark_status']=='PASS'
 if require_validated:
  out['results']=[x for x in out['results'] if x['high_fidelity_eligible']][:limit]
 if require_benchmark:
  out['results']=[x for x in out['results'] if x['benchmark_eligible']]
 out['retrieval_policy']={'require_validated':require_validated,'high_fidelity_rule':'runtime_status=source-compared-png and review_status=pass','returned':len(out['results'])}
 out['schema_version']=1;out['corpus']={'path':str(CORPUS.resolve()),'sha256':hashlib.sha256(CORPUS.read_bytes()).hexdigest()}
 return out
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--query',required=True);p.add_argument('--limit',type=int,default=5);p.add_argument('--require-validated',action='store_true');p.add_argument('--require-benchmark',action='store_true');p.add_argument('--json',action='store_true');p.add_argument('--output',type=Path);a=p.parse_args();out=retrieve(a.query,a.limit,a.require_validated,a.require_benchmark);payload=json.dumps(out,ensure_ascii=False,indent=2)+'\n';a.output.write_text(payload) if a.output else print(payload,end='');minimum=1 if a.require_validated else 3;raise SystemExit(0 if len(out['results'])>=minimum else 1)
