#!/usr/bin/env python3
"""Compile a deterministic plotting contract for low-reasoning execution."""
from __future__ import annotations
import argparse, importlib.util, json
from pathlib import Path
import yaml

ROOT=Path(__file__).resolve().parents[1]

def load_module(name,path):
 spec=importlib.util.spec_from_file_location(name,path); mod=importlib.util.module_from_spec(spec); spec.loader.exec_module(mod); return mod
REPRO=load_module('repro',ROOT/'scripts/retrieve_reproduction.py')
SCIDRAW=load_module('scidraw',ROOT/'scripts/retrieve_scidraw.py')
ALIASES={
 'matrix':['热图','matrix','correlation','expression'],
 'association':['相关','散点','mantel','scatter','volcano','火山'],
 'circular':['环','circos','和弦','旭日','花瓣'],
 'composition':['组成','堆积','桑基','alluvial','三元','venn'],
 'network':['网络','network','graph'],
 'clinical':['泳道','森林','临床','swimmer','forest'],
 'distribution':['小提琴','云雨','山脊','ridge','violin'],
 'enrichment':['富集','gsea','pathway'],
 'time-series':['时间序列','时序','流图','stream'],
 'map':['地图','空间','map','flow map'],
 'tree':['树','phylogeny','系统发育'],
 'single-cell':['单细胞','umap','cellchat'],
 'genome':['基因组','染色体','dmr','genome'],
 'time-to-event':['生存','survival','kaplan']}

def normalize_family(value):
 return {'heatmap':'matrix','general':'general-statistical','time_series':'time-series','single_cell':'single-cell','survival':'time-to-event'}.get(value,value)

def infer_families(query,candidate):
 found=[]; method=candidate.get('package_method',{}) or {}
 for value in method.get('figure_families',[]) or []: found.append(normalize_family(value))
 for value in candidate.get('chart_tags',[]) or []: found.append(normalize_family(value))
 text=' '.join([query,candidate.get('title',''),candidate.get('category','')]).lower()
 for family,words in ALIASES.items():
  if any(word.lower() in text for word in words): found.append(family)
 return list(dict.fromkeys(found)) or ['general-statistical']

def candidate_rows(query):
 rows=[]
 contract_doc=yaml.safe_load((ROOT/'atlas/family-execution-contracts.yaml').read_text())
 subtype=detect_subtype(query,contract_doc)
 subtype_aliases=contract_doc.get('subtypes',{}).get(subtype,{}).get('aliases',[])
 expanded=query+' '+' '.join(subtype_aliases)
 methods={x['issue']:x for x in json.loads((ROOT/'atlas/reproduction-methods.json').read_text())['cases']}
 for item in REPRO.retrieve(expanded,limit=10)['results']:
  issue=int(item['case_id'].split('-')[-1])
  method=(item.get('package_method',{}) or {})|{'figure_families':methods.get(issue,{}).get('figure_families',[])}
  row=item|{'source':'topjournal','package_method':method}
  row['selection_score']=item['score']+(20 if item.get('high_fidelity_eligible') else 0)+(30 if any(a.lower() in item.get('title','').lower() for a in subtype_aliases) else 0); rows.append(row)
 for item in SCIDRAW.retrieve(expanded,limit=10)['results']:
  row=item|{'source':'scidraw'}; row['selection_score']=item['score']+(20 if item.get('high_fidelity_eligible') else 0)+(30 if any(a.lower() in item.get('title','').lower() for a in subtype_aliases) else 0); rows.append(row)
 return sorted(rows,key=lambda x:(-x['selection_score'],x.get('case_id','')))

def detect_subtype(query, contracts):
 text=query.lower()
 for name,contract in contracts.get('subtypes',{}).items():
  if any(alias.lower() in text for alias in contract.get('aliases',[])): return name
 return None

def compile_plan(query):
 requested=infer_families(query,{})
 ambiguous=requested==['general-statistical'] or (requested==['genome'] and not any(w in query.lower() for w in ['密度','共线','synteny','density','ideogram','核型']))
 if ambiguous:
  return {'schema_version':1,'query':query,'planning_status':'NEEDS_SPEC','selected_case':None,'ready_to_render':False,'missing':['明确图型或参考图','输入数据字段及单位'],'claim_policy':'do not guess a chart from the highest retrieval score'}
 rows=candidate_rows(query)
 compatible=[r for r in rows if set(requested)&set(infer_families('',r))]
 if not compatible:
  return {'schema_version':1,'query':query,'planning_status':'NEEDS_REFERENCE','selected_case':None,'ready_to_render':False,'missing':['与请求图型一致的来源方法'],'claim_policy':'no unrelated fallback'}
 rows=compatible
 selected=rows[0]; document=yaml.safe_load((ROOT/'atlas/family-execution-contracts.yaml').read_text()); contracts=document['families']
 families=[x for x in infer_families(query,selected) if x in contracts] or ['general-statistical']; primary=families[0]
 subtype=detect_subtype(query,document); active=document.get('subtypes',{}).get(subtype,contracts[primary])
 method=selected.get('package_method',{}) or {}; analysis=selected.get('code_analysis',{}) or {}
 packages=list(dict.fromkeys((method.get('core_packages') or analysis.get('packages') or [])+active['preferred_packages']))
 functions=method.get('key_functions') or analysis.get('plot_primitives') or []
 eligible=bool(selected.get('benchmark_eligible'))
 return {'schema_version':1,'query':query,'planning_status':'METHOD_CANDIDATE','ready_to_render':False,'missing':['validate actual input fields and units','bind reference and final-size design'],
  'selected_case':{'case_id':selected.get('case_id'),'title':selected.get('title'),'source':selected['source'],'high_fidelity_eligible':eligible},
  'evidence_status':'verified-precedent' if eligible else 'method-contract-requires-source-comparison',
  'families':families,'subtype':subtype,'data_contract':active['required_fields'],
  'package_contract':{'specialized_first':True,'candidates':packages,'must_record_namespace_calls':True},
  'function_contract':functions,'layer_contract':active['mandatory_layers'],'blocking_failures':active['failure_conditions'],
  'execution_order':['validate-scientific-and-data-contract','load-and-smoke-test-specialized-package','write-independent-script-from-current-fields','render-final-size-png','inspect-object-level-collisions-and-fonts','compare-current-png-with-source-when-reference-guided','run-cp0-cp4-before-pass'],
  'claim_policy':'unverified-preview until current PNG and checkpoint evidence pass',
  'reasoning_mode_policy':'same contract for light, low, medium, and higher reasoning modes',
  'alternatives':[{'case_id':x.get('case_id'),'title':x.get('title'),'source':x['source'],'high_fidelity_eligible':bool(x.get('high_fidelity_eligible'))} for x in rows[1:4]]}

def main():
 p=argparse.ArgumentParser();p.add_argument('--query',required=True);p.add_argument('--output',type=Path);a=p.parse_args()
 payload=json.dumps(compile_plan(a.query),ensure_ascii=False,indent=2)+'\n'
 a.output.write_text(payload) if a.output else print(payload,end=''); return 0
if __name__=='__main__': raise SystemExit(main())
