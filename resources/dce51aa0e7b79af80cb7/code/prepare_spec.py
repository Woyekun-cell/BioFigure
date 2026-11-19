from pathlib import Path
import json, yaml, hashlib, subprocess, sys, copy
W=Path(__file__).resolve().parent; P=W.parents[1]; S=P/'biofigure'
sys.path.insert(0,str(S/'scripts'))
from retrieve_learned_methods import retrieve
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def wr(p,x):Path(p).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
class QuotedDumper(yaml.SafeDumper):pass
QuotedDumper.add_representer(str,lambda d,v:d.represent_scalar('tag:yaml.org,2002:str',v,style="'"))
q=json.loads((W/'input-qc.json').read_text());tm=json.loads((W/'text-manifest.json').read_text());ref=Path(q['source']['image']);mid='SCICASE-033'
request=dict(reference_mode='reference-guided',operation='draw',figure_task='grouped-upset-dot-matrix',figure_family='matrix',
 data_shape='Unique simulated gene IDs by ten boolean set columns; derived exclusive intersection and set cardinalities',
 primary_domain='multipanel',primary_role='structure',backend='R',deliverable='paper-pdf',statistics_required=False,learned_method_id=mid)
(W/'request.yaml').write_text(yaml.safe_dump(request,sort_keys=False))
r=subprocess.run([sys.executable,str(S/'scripts/prepare_figure.py'),str(W/'request.yaml'),'--output',str(W/'preparation-receipt.json')],capture_output=True,text=True)
(W/'prepare.log').write_text(r.stdout+r.stderr);assert r.returncode==0,r.stdout+r.stderr
prep=json.loads((W/'preparation-receipt.json').read_text());e=retrieve('',case_id=mid)['results'][0];wr(W/'learned-readset.json',e)
files=[dict(role='figure_asset',path=str(ref),sha256=sha(ref))]
wr(W/'source-review-receipt.json',dict(schema_version=1,kind='primary-source-lock',reference_mode='reference-guided',
 query='Grouped UpSet with condition shapes, ordered time colors, class-colored intersection bars and set-size bars',project_root=str(P),
 primary_source=dict(kind='tutorial',title=e['title'],url=q['source']['source'],version='local-archived-code-and-exact-reference-image'),
 source_files=files,adopted_roles=['figure_asset'],source_mapping=[],
 inspection=dict(original_figure_opened=True,observation='Opened source image at800x333. Reviewed code06,07,09. Adopt ComplexUpset components and source grouping; data2.xlsx is absent, data variable is inconsistent and set_cols undefined. Use independent membership-only simulation, not inferred differential expression.'),
 generation_contract=dict(author_material_access='authorized-inspection-no-copy',implementation='new-script-from-user-data-and-derived-patterns',blind_generation=False),scope=q['data_origin']))
roles=dict(axis_text=7,axis_title=7,legend_text=7,strip_text=7,annotation_text=7,panel_label=9)
colors={'Apo only':'#CD816E','Sym only':'#409B91','Mixed':'#C3A148','D1':'#B8A6D2','D3':'#9E85C0','D5':'#8365AD','D7':'#674A91','D9':'#493369'}
style=dict(schema_version='1.0',project_id=q['stem'],palette=dict(palette_id='grouped-upset-coral-teal-purple',semantic_colors=colors),typography=dict(family='Arial',size_roles_pt=roles),size_system=dict(allowed_classes=['double-column']))
(W/'project-style.yaml').write_text(yaml.safe_dump(style,sort_keys=False))
s=yaml.safe_load((P/'work/2026-10-29-lollipop-completion/REPRO-021/design-spec.yaml').read_text())
s.update(reference_mode='reference-guided',figure_task=request['figure_task'],scientific_message=q['data_origin'],statistics_required=False,
 candidate_patterns=['LEARNED-'+mid],selected_pattern='LEARNED-'+mid,
 selection_reason='User selected the previously unauthored grouped UpSet; preserve the source composition and learn its aesthetic logic with a new semantic palette.')
s['data_contract_summary']=dict(input='Three linked CSV files: unique-ID membership table, derived exclusive intersections, ordered set metadata.',
 unit='One explicitly synthetic gene ID',origin=q['data_origin'],exclusions='No original gene identity, biological sample, differential-expression threshold or real study inference.',
 statistics='No inference. Independently recompute all exclusive intersection counts, set sizes and class assignments from the same unique IDs.')
s['biology_contract']=dict(primary_domain='multipanel',entities=['synthetic gene IDs','ten condition-time sets'],relationships=['exclusive set intersection','condition grouping','ordered time'],
 experimental_unit='Synthetic gene ID; not a biological replicate',statistical_unit='No inferential statistical unit',replicate_unit='Not applicable',evidence_level='Authorized fixed-seed structural and aesthetic demonstration',claim_boundary=q['data_origin'])
s['backend_lock']=dict(prep['route']['backend_lock'],locked=True)
s['reference_evidence']=dict(preparation_id=prep['preparation_id'],preparation_request=prep['request'],selected_method_case_id=mid,
 retrieval_query=dict(domain='matrix',task=request['figure_task'],pattern='LEARNED-'+mid),selected_atlas_ids=[],observed_principles=list(q['observations'].values()),
 transfer_decisions=['Use native ComplexUpset for cardinalities, membership matrix and aligned set-size components.','Retain shape-separated conditions and ordered-time color keys; derive class labels honestly from complete set membership.','Display30 intersections instead of the source larger count to preserve7pt count labels and a dedicated legend lane.'],
 rejected_elements=['Do not run inconsistent data/DEG_df code or infer DEG calls from fold-change-only marginal filtering.','Exclude ordinary UpSetR code01-05 and separate Venn code10.','No rainbow, original red-blue time palette or canvas simulation footnote.'],evidence_status='source-and-visual-reviewed',
 learned_source_reference=dict(method_id=mid,source_record_sha256=e['source_sha256'],read_hashes=e['current_read_hashes'],
 opened_source_asset=dict(path=str(ref.relative_to(S)),sha256=sha(ref),original_size_viewed=True)),
 learned_method_reuse=dict(adopted=[mid],rejected=[],data_adaptation=q['data_origin'],
 known_failures_addressed='No original data2.xlsx; independently derive complete boolean membership. Preserve per-day condition exclusivity and compute all statistics by gene ID. Do not grid.force a nested patchwork.',
 source_issue_resolutions=[dict(source_path=x['path'],resolution='Source inspected only; independently implement the adopted ComplexUpset visual components, explicitly define set columns and do not execute missing spreadsheet or erroneous variable code.')for x in e.get('known_source_syntax_issues',[])]))
ids=['intersection-bars','membership-matrix','set-size-bars','semantic-keys']
s['reference_analysis']=dict(figure_family='matrix',semantic_purpose='Exclusive membership and cardinality across two conditions at five ordered times',
 panels=[dict(id=i,role=i,position=v)for i,v in zip(ids,['upper right','lower right','lower left','reserved legend lanes'])],
 elements=[dict(id=i,role=i,geometry=v,position='Native ComplexUpset shared coordinates',data_mapping='Unique gene ID, complete membership signature and named set metadata',required=True)for i,v in zip(ids,['nativecountbars','pointmatrixandsegments','nativehorizontalbars','namedlegends'])],
 relationships=[{'from':ids[0],'to':ids[1],'type':'shares-order','shared_key':'exclusive membership signature'},{'from':ids[1],'to':ids[2],'type':'shares-coordinate','shared_key':'set ID'}],
 spatial_topology=dict(coordinate_system='Cartesian native ComplexUpset dot matrix',reading_order=ids,alignment_keys=['exclusive signature','set ID'],layer_order=['condition stripes','inactive symbols','connectors','active symbols','counts','keys']),
 required_structures=ids,forbidden_substitutions=['independent bar totals unrelated to gene membership','ordinary ungrouped UpSet','biologically interpreted simulated memberships'])
s['visual_hierarchy']=dict(primary=q['observations']['hierarchy'],secondary='Condition shape and time colors',tertiary='Counts, set labels and keys')
s['encoding']=dict(x='Descending exclusive intersections',y='Native ordered condition-time set rows',color=q['observations']['palette'],shape='Apo triangle24,Sym circle21')
s['annotation']=dict(counts='Computed from unique IDs',ordering='Five Apo rows followed by five Sym rows',claim_boundary=q['data_origin'])
s['legend']=dict(place='outside_top',shared=False,policy='Class key above; time and condition keys in a separate lower lane. No legends placed within the matrix or bars.')
s['palette_semantics']=colors
s['project_style_contract']=dict(registry_path=str(W/'project-style.yaml'),registry_sha256=sha(W/'project-style.yaml'),project_id=q['stem'],palette_id=style['palette']['palette_id'],semantic_colors=colors,reuse_policy='exact_semantic_mapping',exception_basis='User requested a new source-specific palette.')
s['renderer']=dict(language='R',backend='ggplot2',packages=['ComplexUpset','ggplot2','patchwork','ggplotify','grid','ragg'],function_adaptation='Native ComplexUpset intersection_size,intersection_matrix,upset_set_size,upset_query and upset_stripes; independent source-guided simulation and named metadata.')
s['output_size']=dict(width_mm=q['width_mm'],height_mm=q['height_mm'],formats=['pdf','png'],size_class='double-column',size_basis='final_physical_output',size_rationale=dict(panel_count=4,density='high',longest_label_chars=max(map(len,tm['labels'])),recommended_class='double-column',selection_reason='Thirty count labels,ten set rows and three semantic keys require full double-column width.',override_basis='Source-derived complex set-comparison composition.'))
s['layout_contract']=dict(canvas='183x116mm white',data_bbox='Native ComplexUpset aligned body',annotation_bbox='Reserved row labels and bar count height',legend_bbox='Top class key and separate lower time/condition lane',label_reserve='7ptArial',collision_policy='Failon unintended overlap or clipping',text_extent_method='Nativegridtextand actual PDF glyph bounds',preflight_collision_check='Inspect current wholePNG and PDF against source',coordinate_policy='Preserve shared intersection/set keys and descending counts')
s['font_contract']['size_roles_pt']=roles
s['design_target']={k:dict(observation=v,implementation=v,difference_reason=q['data_origin'])for k,v in q['observations'].items()}
s['design_target'].update(reference=str(ref),reference_opened=True)
s['text_contract']=dict(allowed_text=tm['labels'],allow_headings=False,footer_policy='outside-only')
(W/'design-spec.yaml').write_text(yaml.dump(s,Dumper=QuotedDumper,sort_keys=False,allow_unicode=True))
r=subprocess.run([sys.executable,str(S/'scripts/validate_design_spec.py'),str(W/'design-spec.yaml'),'--preparation-receipt',str(W/'preparation-receipt.json')],capture_output=True,text=True)
(W/'cp2.log').write_text(r.stdout+r.stderr);print(r.stdout[-2500:]);assert r.returncode==0,r.stderr
