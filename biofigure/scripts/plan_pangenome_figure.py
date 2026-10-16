#!/usr/bin/env python3
"""Intent-driven pangenome planning. Metadata validation, never inferential analysis."""
from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[1]
LIBRARY='static/core/pangenome-paradigms.json'

def applies(query,context=None):
 return context is not None or re.search(r'泛基因组|超泛基因组|\b(?:super[ -]?)?pan[ -]?genome\b',query,re.I) is not None

def compile_pangenome_plan(query,context=None,primary_source=None):
 if not applies(query,context):return None
 doc=json.loads((ROOT/LIBRARY).read_text());context={} if context is None else context
 def needs(missing,options=()):
  return {'schema_version':1,'query':query,'planning_status':'NEEDS_SPEC','ready_to_render':False,'selected_case':None,
          'missing':missing,'question':'请明确分析目标与数据字段：要看组成、共享/缺失、累积规律、变异分布还是性状关联？',
          'options':list(options),'claim_policy':'Do not choose from journal name or keyword alone.'}
 if not isinstance(context,dict):return needs(['pangenome_context must be a mapping'])
 typ=context.get('data_type');candidates=[r for r in doc['paradigms'] if r['data_type']==typ]
 if not candidates:return needs(['data_type must match a documented pangenome data contract'],sorted({r['data_type'] for r in doc['paradigms']}))
 intent=context.get('intent')
 if not intent and len(candidates)==1:intent=candidates[0]['intent']
 selected=[r for r in candidates if r['intent']==intent]
 if len(selected)!=1:return needs(['intent: select the scientific question for this data'],[{'intent':r['intent'],'question':r['question'],'chart':r['chart']} for r in candidates])
 r=selected[0];missing=[];columns=context.get('columns',[])
 if not isinstance(columns,list) or any(not isinstance(c,str) for c in columns):return needs(['columns must be a list of explicitly mapped semantic field names'])
 missing += ['field:'+x for x in r['required_fields'] if x not in columns]
 if context.get('unit')!=r['unit']:missing.append('unit:'+r['unit'])
 if typ=='family_presence':
  if context.get('missing_policy')!='unknown_not_absent':missing.append('missing_policy:unknown_not_absent')
  values=context.get('presence_values')
  if values is not None and (not isinstance(values,list) or any(v not in (0,1,None) for v in values)):
   missing.append('presence_values must be binary 0/1 or null; gene lists/copy counts require explicit conversion')
 if missing:return needs(missing)
 return {'schema_version':1,'query':query,'planning_status':'METHOD_CANDIDATE','ready_to_render':False,
  'selected_case':{'case_id':doc['case_id']+':'+r['id'],'source':'pangenome-source-audit','title':r['question'],
                   'reference':'https://www.nature.com/articles/s41588-023-01340-y',
                   'source_commit':doc['commit'],'source_path':r['source_path'],'high_fidelity_eligible':False},
  'requested_primary_source':primary_source,'requested_source_status':'requires_independent_audit' if primary_source else 'not_requested',
  'families':[r['family']],'subtype':r['chart'],'data_contract':r['required_fields'],
  'experimental_unit':r['unit'],'statistics_contract':r['statistics'],'blocking_failures':[r['guards']],
  'package_contract':{'specialized_first':True,'candidates':r['packages'],'must_record_namespace_calls':True},
  'function_contract':r['functions'],'semantic_color':'Color encodes declared class/type/orientation; unknown distinct from absence.',
  'data_validation_status':'metadata_only_actual_values_pending','source_figure':r['figure'],'learning_contract':LIBRARY,
  'missing':['validate actual values, missingness and ID uniqueness','inspect original figure and matching code','validate Design Spec and CP2 before renderer code'],
  'claim_policy':'Source-audited candidate; plot-data re-render is not a full pangenome pipeline reproduction.'}
