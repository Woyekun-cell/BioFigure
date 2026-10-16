"""Release-maintenance helper; run only after source and renderer bytes freeze."""
from pathlib import Path
import hashlib,json,re,sys,subprocess,os
ROOT=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parents[1]
SKILL=ROOT/'biofigure'
NEW=['boxplot','heatmap','dense-heatmap','bubble','volcano','synteny','phylogeny']
OLD=['cannabis-cassette','cannabis-chr7','dpm-bubbles','dpm-network','ohca-microc','oncoprint','planarian-dotplot','sankey']
EXCLUDED={'.git','__pycache__','.pytest_cache','work','cache'}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def binding(p,role='config',license='MIT',origin='BioFigure-owned'):
 return {'path':p.relative_to(SKILL).as_posix(),'sha256':sha(p),'role':role,'license':license,'origin':origin}
def usable(p):return p.is_file() and p.name!='.DS_Store' and not any(x in EXCLUDED for x in p.relative_to(SKILL).parts)
def role(p):
 if p.name=='provenance.json':return 'provenance'
 if p.suffix.lower() in {'.r','.py','.sh'}:return 'code'
 if p.suffix.lower() in {'.csv','.tsv','.rds'}:return 'input'
 if p.suffix.lower() in {'.pdf','.png','.svg'}:return 'reference'
 return 'config'
def dependencies(files):
 namespaces=set()
 for p in files:
  if p.suffix.lower()=='.r':namespaces.update(re.findall(r'\b([A-Za-z][A-Za-z0-9.]+)::',p.read_text()))
 namespaces-=set(['grDevices','stats','utils','grid','graphics','methods','base','tools','datasets','parallel'])
 return [{'name':'Python 3','version':'3.10+','source':'https://www.python.org/'}, {'name':'PyYAML','version':'6.0.3','source':'https://pypi.org/project/PyYAML/6.0.3/'}]+[{'name':'R:'+n,'version':'record installed version for the current render','source':'R namespace required by the bundled first-party renderer; use the package source documented in renderer-registry.yaml or the case provenance.'} for n in sorted(namespaces)]
cases=[]
for name in OLD:
 case=SKILL/'examples/genomics-gallery-20261011'/name
 profile=json.loads((case/'data/metadata/public-replay.json').read_text())
 status=profile.get('status', 'reference-only' if name.startswith('dpm-') else 'runnable')
 files=[p for p in case.rglob('*') if usable(p)]
 materials=[]
 for p in files:
  r=role(p);lic='MIT';origin='BioFigure-owned public adapter or metadata'
  if name in ['cannabis-cassette','cannabis-chr7','planarian-dotplot'] and r in ['input','reference']:
   lic='GPL-3.0-only';origin='Derived author-processed data from a pinned GPL-3.0 repository; attribution and modifications are recorded in licenses/third-party-provenance.json'
  materials.append(binding(p,r,lic,origin))
 shared=case.parent/'replay_public.py'
 if shared.exists():materials.append(binding(shared,'code'))
 limitations=['Current fixed processed tables and own layout only; no raw sequencing, full-paper fidelity, new-input transfer, stress or current visual PASS inferred.', 'Declared R packages and system fonts are external runtime dependencies; no dependency installation or renderer execution is performed by the portable audit.']
 if status!='runnable':limitations=[profile['unavailable_reason']]
 command=['python3','{skill_root}/'+(case/'scripts/reproduce.py').relative_to(SKILL).as_posix(),'--output-dir','{output_dir}']
 command+=['--source-view-confirmed']
 rec={'id':name,'title':profile.get('method_id',name),'status':status,'entrypoint':(case/'scripts/reproduce.py').relative_to(SKILL).as_posix(),'command':command,'provenance':(case/'provenance.json').relative_to(SKILL).as_posix(),'files':materials,'dependencies':dependencies(files),'limitations':limitations}
 if name in ['cannabis-cassette','cannabis-chr7']:
  rec['limitations'].append('BUSCOplot native source is fetched at pinned commit and verified by SHA256; its GPL license is retained. Network or a verified native-source cache is required.')
 if name=='ohca-microc':
  rec['external_inputs']=[{'url':'https://raw.githubusercontent.com/js2264/OHCA/8ef6242d336e8c8875f4afb2164b47c4d0fbcea4/inst/extdata/microC_with-loops.rds','sha256':'b20fc02f9dcd5fcd027d02b4108d08650407a7de80553e2171f87bc7f296750d','license':'MIT','required':True,'license_evidence':'licenses/OHCA-MIT.md'}]
 cases.append(rec)
for name in NEW:
 case=SKILL/'examples/portable'/name
 if not (case/'provenance.json').is_file():raise SystemExit('Expected first-party provenance missing: '+name)
 files=[p for p in case.rglob('*') if usable(p)]
 files += [p for p in (SKILL/'examples/portable').iterdir() if usable(p)]
 files += [p for p in (SKILL/'examples/portable/metadata').rglob('*') if usable(p)]
 runner=SKILL/'scripts/run_public_example.py'
 if runner.exists():files.append(runner)
 cases.append({'id':name,'title':'First-party synthetic '+name,'status':'runnable','entrypoint':'scripts/run_public_example.py','command':['python3','{skill_root}/scripts/run_public_example.py',name,'--output-dir','{output_dir}'],'provenance':(case/'provenance.json').relative_to(SKILL).as_posix(),'preview_files':[(case/'figures'/(name+ext)).relative_to(SKILL).as_posix() for ext in ['.png','.pdf']],'expected_preview_formats':['png','pdf'],'files':[binding(p,role(p),'MIT','BioFigure-owned synthetic data, code, configuration or demonstration output') for p in sorted(set(files))],'dependencies':dependencies(files),'limitations':['Entirely synthetic; no biological finding or source-paper reproduction is established.','Fresh analysis, CP2, one-use authorization, output checks and actual PNG/PDF review remain required for each new invocation.']})
# Refresh the tracked derived lookup before binding shared runtime bytes.
subprocess.run([sys.executable,str(SKILL/'scripts/find_figure_reference.py'),'--refresh','--list-types'],stdout=subprocess.DEVNULL,check=True,env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1'))
common=[]
for p in SKILL.rglob('*'):
 if not usable(p):continue
 rel=p.relative_to(SKILL)
 if rel.parts[0] in {'examples','tests','library'} or rel.as_posix().startswith('benchmark/library/') or p.name=='public-cases.json':continue
 lic='GPL-3.0-only' if p.name=='GPL-3.0.txt' else 'MIT'
 origin='Upstream license text retained verbatim' if rel.parts[0]=='licenses' else 'BioFigure-owned runtime, method metadata or documentation; external materials are links, not relicensed copies'
 common.append(binding(p,'code' if p.suffix.lower() in {'.py','.r'} else 'config',lic,origin))
exclusions=json.loads((ROOT/'docs/gallery/rights-exclusions-3.8.0.json').read_text())['files']
exclusions=[dict(x,path=x['path'].removeprefix('biofigure/')) for x in exclusions if x['path'].startswith('biofigure/')]
# Check CLI flag spelling with --help only; this does not execute R or certify rendering.
for c in cases:
 if c['status']!='runnable':continue
 help_result=subprocess.run([sys.executable,str(SKILL/c['entrypoint']),'--help'],capture_output=True,text=True,env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1'),timeout=30)
 if help_result.returncode:raise SystemExit('Entrypoint help failed: '+c['id']+' '+help_result.stderr)
 documented_options=set(re.findall(r'(?<![\w-])--[a-z][a-z0-9-]*',help_result.stdout))
 missing=[arg for arg in c['command'] if arg.startswith('--') and arg.split('=',1)[0] not in documented_options]
 if missing:raise SystemExit('Undocumented command flags: '+c['id']+' '+str(missing))
manifest={'schema_version':1,'skill_version':'3.8.0','scope':'Declared public cases plus the complete first-party runtime. The historical learned catalog is searchable, not a runnable certification.','expected_case_ids':OLD+NEW,'shared_runtime_files':sorted(common,key=lambda x:x['path']),'distribution_exclusions':exclusions,'cases':cases}
(SKILL/'public-cases.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'cases':len(cases),'status_counts':{s:sum(x['status']==s for x in cases) for s in ['runnable','reference-only','blocked']},'shared_files':len(common)}))
