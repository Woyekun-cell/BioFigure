#!/usr/bin/env python3
"""Fresh gated replay of Nature 2025 Figure4c's preserved author data.
Requires installed BioFigure and pinned R packages; no global index hash is frozen.
New outputs never overwrite the verified baseline. New inputs are unsupported.
"""
from pathlib import Path
import argparse,hashlib,json,os,subprocess,sys
import yaml
CASE=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 a=argparse.ArgumentParser(description=__doc__);a.add_argument('--output',required=True,type=Path);a.add_argument('--skill-root',type=Path,default=Path(os.getenv('BIOFIGURE_SKILL_ROOT','~/.agents/skills/biofigure')).expanduser());args=a.parse_args()
 skill=args.skill_root.resolve();meta=CASE/'data/metadata/fig4c';manifest=json.loads((meta/'package-manifest.json').read_text())
 for item in manifest['frozen_files']:
  p=CASE/item['path']
  if not p.is_file() or sha(p)!=item['sha256']:raise SystemExit('Frozen source/code drift: '+str(p))
 runtime=manifest['runtime'];code='cat(as.character(getRversion()),"\\n");'+''.join('cat(as.character(packageVersion("'+k+'")),"\\n");'for k in runtime['packages'])
 actual=subprocess.check_output(['Rscript','-e',code],text=True).split()
 if actual!=[runtime['R_version']]+list(runtime['packages'].values()):raise SystemExit('Runtime changed. Requires a new adaptation and visual review.')
 out=args.output.expanduser().resolve();out.mkdir(parents=True,exist_ok=False);audit=out/'audit';audit.mkdir();specpath=audit/'design-spec.yaml'
 def run(cmd,log):
  p=subprocess.run(list(map(str,cmd)),capture_output=True,text=True,env={**os.environ,'BIOFIGURE_SKILL_ROOT':str(skill)});(audit/log).write_text(p.stdout+p.stderr)
  if p.returncode:raise SystemExit(f'Command failed ({p.returncode}); inspect {audit/log}')
 prep=audit/'preparation.json';run([sys.executable,skill/'scripts/prepare_figure.py',meta/'request.yaml','--output',prep],'prepare.log')
 rec=json.loads(prep.read_text());s=yaml.safe_load((meta/'design-spec.yaml').read_text());ev=s['reference_evidence'];ev['preparation_id']=rec['preparation_id'];ev['preparation_request']=rec['request'];ev['learned_method_reuse']={'adopted':[],'rejected':[{'method_id':x['method_id'],'reason':'Pinned paper-specific native renderer uses its exact original source and author data; alternatives are not adopted.'}for x in rec['learned_methods']['results']]}
 lock=json.loads((meta/'source-lock.json').read_text());lock['project_root']=str(CASE);lockpath=audit/'source-lock.json';lockpath.write_text(json.dumps(lock,indent=2)+'\n');ev['primary_source_lock']=str(lockpath);s['design_target']['reference']=str(CASE/'sources/original-fig4.png');s['project_style_contract']['registry_path']=str(meta/'style.yaml')
 # R YAML 1.1 interprets bare N as false. Quote that single native curved-label character.
 specpath.write_text(yaml.safe_dump(s,sort_keys=False,allow_unicode=True).replace('  - N\n',"  - 'N'\n"))
 sources=[CASE/'scripts/render-fig4c.R',skill/'scripts/figure_style.R',CASE/'results/plot_data/fig4c/regulon-age.csv',CASE/'results/plot_data/fig4c/rss.csv'];auth=audit/'authorization.json'
 cmd=[sys.executable,skill/'scripts/validate_design_spec.py',specpath,'--preparation-receipt',prep,'--issue-render-authorization',auth]
 for x in sources:cmd+=['--source',x]
 run(cmd,'cp2.log');run(['Rscript',CASE/'scripts/render-fig4c.R',CASE,out,specpath,auth],'render.log')
 exact=sha(out/'fig4c.png')==manifest['baseline_png_sha256'];result=dict(status='FIXED_INPUT_PNG_MATCH'if exact else'REQUIRES_VISUAL_REVIEW',png_exact=exact,pdf=str(out/'fig4c.pdf'),scope='Same preserved author inputs and pinned environment only; no new input or cross-environment validation.',package_manifest_sha256=sha(meta/'package-manifest.json'))
 (out/'replay-verification.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
 if not exact:raise SystemExit(2)
if __name__=='__main__':main()
