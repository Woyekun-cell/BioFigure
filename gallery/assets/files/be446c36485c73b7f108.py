#!/usr/bin/env python3
"""Fast gated replay of frozen source SCGV coordinates; never reruns150 MC simulations.
New inputs and changed runtime require independent adaptation/visual review.
"""
from pathlib import Path
import argparse,hashlib,json,os,subprocess,sys
import yaml
C=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--skill-root',type=Path,default=Path(os.getenv('BIOFIGURE_SKILL_ROOT','~/.agents/skills/biofigure')).expanduser());a=p.parse_args();S=a.skill_root.resolve();M=C/'data/metadata';man=json.loads((M/'package-manifest.json').read_text())
 for f in man['frozen_files']:
  q=C/f['path']
  if not q.is_file()or sha(q)!=f['sha256']:raise SystemExit('Frozen source/input/code drift: '+str(q))
 rt=man['runtime'];code='cat(as.character(getRversion()),"\\n");'+''.join('cat(as.character(packageVersion("'+k+'")),"\\n");'for k in rt['packages']);actual=subprocess.check_output(['Rscript','-e',code],text=True).split()
 if actual!=[rt['R_version']]+list(rt['packages'].values()):raise SystemExit('Runtime changed; independent adaptation and visual review required.')
 out=a.output.expanduser().resolve();out.mkdir(parents=True,exist_ok=False);A=out/'audit';A.mkdir()
 def run(cmd,log):
  r=subprocess.run(list(map(str,cmd)),text=True,capture_output=True,env={**os.environ,'BIOFIGURE_SKILL_ROOT':str(S)});(A/log).write_text(r.stdout+r.stderr)
  if r.returncode:raise SystemExit(f'Failed ({r.returncode}); inspect {A/log}')
 prep=A/'preparation.json';run([sys.executable,S/'scripts/prepare_figure.py',M/'request.yaml','--output',prep],'prepare.log');r=json.loads(prep.read_text());s=yaml.safe_load((M/'design-spec.yaml').read_text());ev=s['reference_evidence'];ev['preparation_id']=r['preparation_id'];ev['preparation_request']=r['request'];ev['learned_method_reuse']={'adopted':[],'rejected':[{'method_id':v['method_id'],'reason':'Frozen author SCclust tree and SCGV185-cell native geometry; alternate archived renderers not adopted.'}for v in r['learned_methods']['results']]};lock=json.loads((M/'source-lock.json').read_text());lock['project_root']=str(C);lp=A/'source-lock.json';lp.write_text(json.dumps(lock,indent=2));ev['primary_source_lock']=str(lp);s['project_style_contract']['registry_path']=str(M/'style.yaml');spec=A/'design-spec.yaml';spec.write_text(yaml.safe_dump(s,sort_keys=False));D=C/'results/plot_data/fig3a-t2';sources=[C/'scripts/render-fig3a-t2.R',S/'scripts/figure_style.R']+[D/f for f in ['rounded-cn.csv','cell-order.csv','tree-segments.csv','chromosome-bins.csv','source-colors.json']];auth=A/'authorization.json';cmd=[sys.executable,S/'scripts/validate_design_spec.py',spec,'--preparation-receipt',prep,'--issue-render-authorization',auth]
 for q in sources:cmd+=['--source',q]
 run(cmd,'cp2.log');run(['Rscript',C/'scripts/render-fig3a-t2.R',C,out,spec,auth],'render.log');exact=sha(out/'fig3a-t2.png')==man['baseline_png_sha256'];report=dict(status='FIXED_INPUT_PNG_MATCH'if exact else'REQUIRES_VISUAL_REVIEW',png_exact=exact,scope='Frozen185-cell/5000-bin author matrix, independently recomputed public-code average tree and SCGV native paths only. No original-NJ numerical identity, raw sequencing validation or new-input transfer.',author_simulation_rerun=False,baseline_sha256=man['baseline_png_sha256'],actual_sha256=sha(out/'fig3a-t2.png'))
 (out/'replay-verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
 if not exact:raise SystemExit(2)
if __name__=='__main__':main()
