#!/usr/bin/env python3
"""Replay preserved author inputs through a fresh BioFigure design/render gate.
Requires an installed BioFigure runtime, R packages in runtime.json and Python PyYAML.
Creates a new output directory; never overwrites the preserved baseline.
"""
import argparse,hashlib,json,os,subprocess,sys,tempfile
from pathlib import Path
import yaml
CASE=Path(__file__).resolve().parents[1]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def run(cmd,log):
 p=subprocess.run([str(x) for x in cmd],capture_output=True,text=True,env={**os.environ,'BIOFIGURE_SKILL_ROOT':str(SKILL),'BIOFIGURE_DESIGN_SPEC':str(SPEC)})
 log.write_text(p.stdout+p.stderr)
 if p.returncode: raise SystemExit(f'Failed ({p.returncode}); see {log}')
def main():
 global SKILL,SPEC
 a=argparse.ArgumentParser(description=__doc__);a.add_argument('--case',required=True);a.add_argument('--output',type=Path,required=True);a.add_argument('--skill-root',type=Path,default=Path(os.getenv('BIOFIGURE_SKILL_ROOT','~/.agents/skills/biofigure')).expanduser());a.add_argument('--allow-version-change',action='store_true');args=a.parse_args()
 SKILL=args.skill_root.resolve();case=args.case
 if case not in [p.name for p in (CASE/'data/metadata').iterdir() if (p/'request.yaml').exists()]:raise SystemExit('Unknown case')
 manifest_path=CASE/'data/metadata/package-manifest.json'
 if not manifest_path.exists():raise SystemExit('Missing frozen package manifest')
 manifest=json.loads(manifest_path.read_text())
 for item in manifest['frozen_files']:
  p=CASE/item['path']
  if not p.is_file() or sha(p)!=item['sha256']:raise SystemExit('Preserved input/code drift: '+str(p))
 if not args.allow_version_change:
  runtime=json.loads((CASE/'data/metadata/runtime.json').read_text());code='cat(as.character(getRversion()),"\\n");'+''.join('cat(as.character(packageVersion("'+k+'")),"\\n");' for k in runtime['packages'])
  actual=subprocess.check_output(['Rscript','-e',code],text=True).split()
  if actual!=[runtime['R_version']]+list(runtime['packages'].values()):raise SystemExit('Runtime versions changed; inspect or use --allow-version-change for unverified output.')
 out=args.output.expanduser().resolve();out.mkdir(parents=True,exist_ok=False);audit=out/'audit';audit.mkdir();meta=CASE/'data/metadata'/case
 SPEC=audit/'design-spec.yaml'
 prep=audit/'preparation.json';run([sys.executable,SKILL/'scripts/prepare_figure.py',meta/'request.yaml','--output',prep],audit/'prepare.log')
 receipt=json.loads(prep.read_text());spec=yaml.safe_load((meta/'design-spec.yaml').read_text());ev=spec['reference_evidence'];ev['preparation_id']=receipt['preparation_id'];ev['preparation_request']=receipt['request'];ev['learned_method_reuse']={'adopted':[],'rejected':[{'method_id':x['method_id'],'reason':'Replay immutable local author-input package through its pinned renderer; retrieved alternative cases are not used.'} for x in receipt['learned_methods']['results']]}
 lock=json.loads((meta/'source-lock.json').read_text());lock['project_root']=str(CASE);(audit/'source-lock.json').write_text(json.dumps(lock,indent=2));ev['primary_source_lock']=str(audit/'source-lock.json');spec['design_target']['reference']=str(CASE/next(x['path'] for x in lock['source_files'] if x['role']=='figure_asset'));spec['data_contract_summary']['input']=str(CASE/'results/plot_data'/f'{case}.csv');spec['project_style_contract']['registry_path']=str(meta/'style.yaml');SPEC.write_text(yaml.safe_dump(spec,sort_keys=False))
 sources=[CASE/'scripts/render.R',SKILL/'scripts/figure_style.R',CASE/'results/plot_data'/f'{case}.csv'];auth=audit/'authorization.json'
 cmd=[sys.executable,SKILL/'scripts/validate_design_spec.py',SPEC,'--preparation-receipt',prep,'--issue-render-authorization',auth]
 for s in sources:cmd+=['--source',s]
 run(cmd,audit/'cp2.log');run(['Rscript',CASE/'scripts/render.R',CASE,case,out,auth],audit/'render.log')
 expected=manifest['baselines'][case]['png_sha256'];match=sha(out/f'{case}.png')==expected
 report=dict(status='FIXED_INPUT_PNG_MATCH' if match else 'REQUIRES_VISUAL_REVIEW',case=case,png_bytes_exact=match,scope='Same preserved author inputs only; no new-data transfer or cross-environment guarantee.',artifact=str(out/f'{case}.pdf'),source_manifest_sha256=sha(manifest_path))
 (out/'replay-verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False,indent=2))
 if not match:raise SystemExit(2)
if __name__=='__main__':main()
