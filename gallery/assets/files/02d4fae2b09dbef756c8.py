#!/usr/bin/env python3
"""Fresh gated fixed-input replay. No new-data transfer qualification. Output must not exist."""
from pathlib import Path
import argparse,hashlib,json,os,subprocess,sys
import yaml
CASE=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True,type=Path);p.add_argument('--skill-root',type=Path,default=Path(os.getenv('BIOFIGURE_SKILL_ROOT','~/.agents/skills/biofigure')).expanduser());a=p.parse_args();s=a.skill_root.resolve();m=CASE/'data/metadata';manifest=json.loads((m/'package-manifest.json').read_text())
 for x in manifest['frozen_files']:
  if sha(CASE/x['path'])!=x['sha256']:raise SystemExit('Frozen material changed: '+x['path'])
 rt=manifest['runtime'];code='cat(as.character(getRversion()),"\\n");'+''.join('cat(as.character(packageVersion("'+k+'")),"\\n");'for k in rt['packages']);actual=subprocess.check_output(['Rscript','-e',code],text=True).split()
 if actual!=[rt['R_version']]+list(rt['packages'].values()):raise SystemExit('Runtime drift requires new adaptation and review')
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);audit=out/'audit';audit.mkdir()
 def run(cmd,name):
  r=subprocess.run(list(map(str,cmd)),text=True,capture_output=True,env={**os.environ,'BIOFIGURE_SKILL_ROOT':str(s)});(audit/name).write_text(r.stdout+r.stderr)
  if r.returncode:raise SystemExit('Failure: '+str(audit/name))
 prep=audit/'preparation.json';run([sys.executable,s/'scripts/prepare_figure.py',m/'request.yaml','--output',prep],'prepare.log');r=json.loads(prep.read_text());d=yaml.safe_load((m/'design-spec.yaml').read_text());ev=d['reference_evidence'];ev['preparation_id']=r['preparation_id'];ev['preparation_request']=r['request'];ev['learned_method_reuse']={'adopted':[],'rejected':[{'method_id':x['method_id'],'reason':'Exact pinned NicheNet source and code; alternative methods not adopted.'}for x in r['learned_methods']['results']]};lock=json.loads((m/'source-lock.json').read_text());lock['project_root']=str(CASE);lockpath=audit/'source-lock.json';lockpath.write_text(json.dumps(lock,indent=2));ev['primary_source_lock']=str(lockpath);d['design_target']['reference']=str(CASE/'sources/Fig2.png');d['project_style_contract']['registry_path']=str(m/'style.yaml');sp=audit/'design-spec.yaml';sp.write_text(yaml.safe_dump(d,sort_keys=False,allow_unicode=True));auth=audit/'authorization.json'
 files=[CASE/'scripts/render-fig2abcd.R',s/'scripts/figure_style.R']+[CASE/'results/plot_data/fig2abcd'/x for x in ['panel_a_ligand_activity.csv','panel_b_ligand_target.csv','panel_c_target_expression.csv','panel_d_tumor_score.csv']]+[CASE/'sources/author/dynutils-scaling-47f4f4e.R'];cmd=[sys.executable,s/'scripts/validate_design_spec.py',sp,'--preparation-receipt',prep,'--issue-render-authorization',auth]
 for f in files:cmd+=['--source',f]
 run(cmd,'cp2.log');run(['Rscript',CASE/'scripts/render-fig2abcd.R',CASE,out,sp,auth],'render.log');exact=sha(out/'fig2abcd.png')==manifest['baseline_png_sha256'];result=dict(status='FIXED_INPUT_PNG_MATCH'if exact else'REQUIRES_VISUAL_REVIEW',png_exact=exact,png_sha256=sha(out/'fig2abcd.png'),scope='Preserved original public input and pinned environment only; new data not verified.');(out/'replay-verification.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
 if not exact:raise SystemExit(2)
if __name__=='__main__':main()
