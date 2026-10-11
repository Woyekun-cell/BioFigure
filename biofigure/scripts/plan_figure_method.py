#!/usr/bin/env python3
"""Compile a deterministic plotting contract for low-reasoning execution."""
from __future__ import annotations
import argparse, importlib.util, json
import re
from pathlib import Path
import yaml

ROOT=Path(__file__).resolve().parents[1]

def load_module(name,path):
 spec=importlib.util.spec_from_file_location(name,path); mod=importlib.util.module_from_spec(spec); spec.loader.exec_module(mod); return mod
REPRO=load_module('repro',ROOT/'scripts/retrieve_reproduction.py')
SCIDRAW=load_module('scidraw',ROOT/'scripts/retrieve_scidraw.py')
PANGENOME=load_module('pangenome',ROOT/'scripts/plan_pangenome_figure.py')
ALIASES={
 'matrix':['热图','heatmap','matrix','correlation','expression'],
 'association':['相关','散点','mantel','scatter','volcano','火山'],
 'circular':['环','circos','和弦','旭日','花瓣'],
 'composition':['组成','堆积','桑基','alluvial','三元','venn','composition','stacked bar','stacked composition'],
 'network':['网络','network','graph'],
 'clinical':['泳道','森林','临床','swimmer','forest'],
 'distribution':['小提琴','云雨','山脊','箱线图','柱状图','ridge','violin','boxplot','box plot','bar plot'],
 'enrichment':['富集','gsea','pathway'],
 'time-series':['时间序列','时序','流图','stream'],
 'map':['地图','空间','map','flow map'],
 'tree':['树','phylogeny','系统发育'],
 'single-cell':['单细胞','umap','cellchat'],
 'genome':['基因组','染色体','chromosome','genomic distribution','genome distribution','dmr','genome'],
 'time-to-event':['生存','survival','kaplan']}

FAMILY_QUERY_EXPANSIONS = {
 'genome': 'DMR chromosome distribution genomic variant ideogram Circos',
 'circular': 'circlize circos circular track ring layout',
 'network': 'network node edge pathway communication linkET',
 'matrix': 'heatmap correlation clustered matrix annotation tracks',
 'time-to-event': 'survival Kaplan-Meier risk table censoring curve',
 'clinical': 'swimmer timeline treatment response annotation',
}

def matches_alias(text, alias):
 alias=alias.lower()
 text=text.lower()
 if re.search(r'[a-z0-9]',alias):
  return re.search(r'(?<![a-z0-9])'+re.escape(alias)+r'(?![a-z0-9])',text) is not None
 return alias in text

def normalize_family(value):
 return {'heatmap':'matrix','general':'general-statistical','time_series':'time-series','single_cell':'single-cell','survival':'time-to-event'}.get(value,value)

def infer_families(query,candidate):
 # Explicit chart words in the user's query outrank metric/domain vocabulary.
 weak={'correlation','expression','matrix','相关','graph','pathway','map','空间','树','环','单细胞','基因组','genome','chromosome','chromatin'}
 explicit=[family for family,words in ALIASES.items()
           if any(word not in weak and matches_alias(query,word) for word in words)]
 found=explicit; method=candidate.get('package_method',{}) or {}
 for value in method.get('figure_families',[]) or []: found.append(normalize_family(value))
 for value in candidate.get('chart_tags',[]) or []: found.append(normalize_family(value))
 text=' '.join([query,candidate.get('title',''),candidate.get('category','')]).lower()
 for family,words in ALIASES.items():
  if any(matches_alias(text,word) for word in words): found.append(family)
 return list(dict.fromkeys(found)) or ['general-statistical']

def candidate_rows(query):
 rows=[]
 contract_doc=yaml.safe_load((ROOT/'atlas/family-execution-contracts.yaml').read_text())
 subtype=detect_subtype(query,contract_doc)
 subtype_aliases=contract_doc.get('subtypes',{}).get(subtype,{}).get('aliases',[])
 inferred=infer_families(query,{})
 family_terms=' '.join(FAMILY_QUERY_EXPANSIONS.get(x,'') for x in inferred)
 expanded=query+' '+' '.join(subtype_aliases)+' '+family_terms
 methods={x['issue']:x for x in json.loads((ROOT/'atlas/reproduction-methods.json').read_text())['cases']}
 for item in REPRO.retrieve(expanded,limit=10)['results']:
  issue=int(item['case_id'].split('-')[-1])
  method=(item.get('package_method',{}) or {})|{'figure_families':methods.get(issue,{}).get('figure_families',[])}
  row=item|{'source':'topjournal','package_method':method}
  row['selection_score']=item['score']+(20 if item.get('high_fidelity_eligible') else 0)+(30 if any(a.lower() in item.get('title','').lower() for a in subtype_aliases) else 0); rows.append(row)
 for item in SCIDRAW.retrieve(expanded,limit=10)['results']:
  row=item|{'source':'scidraw'}; row['selection_score']=item['score']+(20 if item.get('high_fidelity_eligible') else 0)+(30 if any(a.lower() in item.get('title','').lower() for a in subtype_aliases) else 0); rows.append(row)
 if subtype=='stacked-bar-composition':
  for row in rows:
   title=row.get('title','').lower()
   if '堆积柱状图' in title or 'stacked bar' in title:
    row['selection_score']+=50
 return sorted(rows,key=lambda x:(-x['selection_score'],x.get('case_id','')))

def detect_subtype(query, contracts):
 text=query.lower()
 for name,contract in contracts.get('subtypes',{}).items():
  if any(matches_alias(text,alias) for alias in contract.get('aliases',[])): return name
 return None

def has_closed_proportion_evidence(query):
 text=query.lower()
 patterns=(r'\bexact precomputed proportions?\b',r'\balready normalized proportions?\b',
           r'\bexact ratios?\b',r'\bclosed proportions?\b',r'已闭合比例',r'精确比例',r'现成比例')
 return any(re.search(pattern,text) for pattern in patterns)

def compile_plan(query, primary_source=None, pangenome_context=None):
 pan=PANGENOME.compile_pangenome_plan(query,pangenome_context,primary_source)
 if pan is not None: return pan
 requested=infer_families(query,{})
 ambiguous=requested==['general-statistical'] or (requested==['genome'] and not any(w in query.lower() for w in ['密度','共线','synteny','density','ideogram','核型','chromosome','variant','distribution']))
 if ambiguous:
  return {'schema_version':1,'query':query,'planning_status':'NEEDS_SPEC','selected_case':None,'ready_to_render':False,'missing':['明确图型或参考图','输入数据字段及单位'],'claim_policy':'do not guess a chart from the highest retrieval score'}
 direct_source=isinstance(primary_source,str) and bool(primary_source.strip())
 if direct_source:
  rows=[]
  selected={'case_id':'PRIMARY-SOURCE','title':primary_source.strip(),'source':'primary-source','reference':primary_source.strip(),
            'high_fidelity_eligible':False,'package_method':{},'code_analysis':{}}
 else:
  rows=candidate_rows(query)
  compatible=[r for r in rows if set(requested)&set(infer_families('',r))]
  if not compatible:
   return {'schema_version':1,'query':query,'planning_status':'NEEDS_REFERENCE','selected_case':None,'ready_to_render':False,'missing':['与请求图型一致的来源方法'],'claim_policy':'no unrelated fallback'}
  rows=compatible
  selected=rows[0]
 document=yaml.safe_load((ROOT/'atlas/family-execution-contracts.yaml').read_text()); contracts=document['families']
 families=[x for x in requested if x in contracts] or ['general-statistical']; primary=families[0]
 subtype=detect_subtype(query,document); active=document.get('subtypes',{}).get(subtype,contracts[primary])
 method=selected.get('package_method',{}) or {}; analysis=selected.get('code_analysis',{}) or {}
 candidate_families=infer_families('',selected)
 matched_method=primary in candidate_families
 if subtype=='stacked-bar-composition':
  source_packages=[]
  preserve_values=has_closed_proportion_evidence(query)
  functions=['ggplot2::geom_col','ggplot2::position_stack' if preserve_values else 'ggplot2::position_fill']
 else:
  preserve_values=False
  source_packages=(method.get('core_packages') or analysis.get('packages') or []) if matched_method else []
  functions=(method.get('key_functions') or analysis.get('plot_primitives') or []) if matched_method else []
 packages=list(dict.fromkeys(active['preferred_packages']+source_packages))
 eligible=bool(selected.get('benchmark_eligible'))
 return {'schema_version':1,'query':query,'planning_status':'SOURCE_CANDIDATE' if direct_source else 'METHOD_CANDIDATE','ready_to_render':False,
  'missing':['audit original figure/caption, author code and exact input mapping','validate actual input fields and units','bind reference and final-size design'],
  'selected_case':{'case_id':selected.get('case_id'),'title':selected.get('title'),'source':selected['source'],'high_fidelity_eligible':eligible,
                   **({'reference':selected['reference']} if direct_source else {})},
  'evidence_status':'primary-source-not-yet-audited' if direct_source else ('verified-precedent' if eligible else 'method-contract-requires-source-comparison'),
  'families':families,'subtype':subtype,'data_contract':active['required_fields'],
  'value_policy':'preserve-closed-proportions' if subtype=='stacked-bar-composition' and preserve_values else ('normalize-within-group' if subtype=='stacked-bar-composition' else 'source-defined'),
  'package_contract':{'specialized_first':True,'candidates':packages,'must_record_namespace_calls':True},
  'function_contract':functions,'layer_contract':active['mandatory_layers'],'blocking_failures':active['failure_conditions'],
  'execution_order':['validate-scientific-and-data-contract','load-and-smoke-test-specialized-package','write-independent-script-from-current-fields','render-final-size-png','inspect-object-level-collisions-and-fonts','compare-current-png-with-source-when-reference-guided','run-cp0-cp4-before-pass'],
  'claim_policy':'unverified-preview until current PNG and checkpoint evidence pass',
  'reasoning_mode_policy':'same contract for light, low, medium, and higher reasoning modes',
  'alternatives':[{'case_id':x.get('case_id'),'title':x.get('title'),'source':x['source'],'high_fidelity_eligible':bool(x.get('high_fidelity_eligible'))} for x in rows[1:4]]}

def main():
 p=argparse.ArgumentParser();p.add_argument('--query',required=True);p.add_argument('--primary-source');p.add_argument('--output',type=Path);a=p.parse_args()
 payload=json.dumps(compile_plan(a.query,a.primary_source),ensure_ascii=False,indent=2)+'\n'
 a.output.write_text(payload) if a.output else print(payload,end=''); return 0
if __name__=='__main__': raise SystemExit(main())
