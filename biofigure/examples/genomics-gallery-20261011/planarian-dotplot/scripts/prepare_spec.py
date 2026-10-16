#!/usr/bin/env python3
"""Bind the public own-layout template to a fresh current BioFigure receipt."""
from pathlib import Path
import hashlib,json,sys
sys.dont_write_bytecode=True
import yaml
root=Path(sys.argv[1]).resolve()
receipt=json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
config=json.loads((root/'data/metadata/execution-config.json').read_text(encoding="utf-8"))
method=config['method_id'];pattern='LEARNED-'+method
entry=next(x for x in receipt['learned_methods']['results'] if x['method_id']==method)
if entry['missing_material'] or entry['source_record_changed'] or entry['changed_bound_material']:
    raise ValueError('Public execution profile has missing/stale current read material')
d=yaml.safe_load((root/'data/metadata/design-template.yaml').read_text(encoding="utf-8"))
style_path=root/'data/metadata/project-style.yaml';style=yaml.safe_load(style_path.read_text(encoding="utf-8"))
d['backend_lock']=dict(receipt['route']['backend_lock'],locked=True)
d['figure_task']=receipt['request']['figure_task']
d['candidate_patterns']=[pattern];d['selected_pattern']=pattern
reference=d['reference_evidence']
reference['preparation_id']=receipt['preparation_id'];reference['preparation_request']=receipt['request']
reference['selected_method_case_id']=method
reference['retrieval_query']={'domain':receipt['request']['primary_domain'],'task':receipt['request']['figure_task'],'pattern':pattern}
asset=config['opened_reference']
view=json.loads((root/'data/metadata/source-view.json').read_text(encoding="utf-8"))
if view.get('confirmed_this_invocation') is not True or view.get('reference_sha256')!=entry['current_read_hashes'][asset]:
    raise ValueError('A fresh hash-bound own-source view declaration is required')
reference['learned_source_reference']={'method_id':method,'source_record_sha256':entry['source_sha256'],'read_hashes':entry['current_read_hashes'],
 'opened_source_asset':{'path':asset,'sha256':entry['current_read_hashes'][asset],'original_size_viewed':True,
 'scope':'Current own sealed public layout opened at final size; author-paper/full-figure fidelity is not certified'}}
reference['learned_method_reuse']={'adopted':[method],'rejected':[],
 'data_adaptation':config['scope'],'known_failures_addressed':'; '.join(config['limitations']),'source_issue_resolutions':[]}
d['project_style_contract']={'registry_path':str(style_path),'registry_sha256':hashlib.sha256(style_path.read_bytes()).hexdigest(),
 'project_id':style['project_id'],'palette_id':style['palette']['palette_id'],'semantic_colors':style['palette']['semantic_colors'],
 'reuse_policy':'exact_semantic_mapping','exception_basis':style.get('deviation_basis',style.get('exception_basis',''))}
(root/'data/metadata/design-spec.yaml').write_text(yaml.safe_dump(d,sort_keys=False,allow_unicode=True), encoding="utf-8")
print(json.dumps({'status':'FRESH_SPEC_BOUND','method_id':method}))
