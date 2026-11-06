#!/usr/bin/env python3
"""Recompute the fixed official Guo tutorial; does not grant visual/new-input PASS."""
from pathlib import Path
import argparse,json,subprocess,sys,time,hashlib,yaml
ap=argparse.ArgumentParser();ap.add_argument('--project-root',type=Path);ap.add_argument('--output-prefix',type=Path);args=ap.parse_args()
C=Path(__file__).resolve().parents[1];P=(args.project_root or Path(__file__).resolve().parents[6]).resolve();W=P/'work/2026-10-28-destiny-guo';S=P/'biofigure';W.mkdir(parents=True,exist_ok=True)
F=(args.output_prefix or C/'results/figures/destiny-guo-dpt').resolve();F.parent.mkdir(parents=True,exist_ok=True)
run_id=str(time.time_ns());logs=[]
def run(cmd):
 r=subprocess.run(list(map(str,cmd)),cwd=P,capture_output=True,text=True);logs.append({'command':list(map(str,cmd)),'exit_code':r.returncode,'output':r.stdout+r.stderr})
 if r.returncode:
  (W/('replay-'+run_id+'.json')).write_text(json.dumps({'status':'FAILED','commands':logs},indent=2));raise SystemExit(r.stdout+r.stderr)
 return r
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
lock=json.loads((C/'validation/source-lock.json').read_text());old_root=lock['project_root'];lock['project_root']=str(P)
(W/'source-lock.json').write_text(json.dumps(lock,indent=2)+'\n')
(W/'project-style.json').write_bytes((C/'validation/project-style.json').read_bytes())
(W/'request.yaml').write_bytes((C/'validation/request.yaml').read_bytes())
run([sys.executable,S/'scripts/prepare_figure.py',W/'request.yaml','--output',W/'preparation-receipt.json'])
receipt=json.loads((W/'preparation-receipt.json').read_text())
spec=yaml.safe_load((C/'validation/design-spec.yaml').read_text())
def rebase(v):
 if isinstance(v,dict):return {k:rebase(x)for k,x in v.items()}
 if isinstance(v,list):return [rebase(x)for x in v]
 if isinstance(v,str)and v.startswith(old_root+'/'):return str(P)+v[len(old_root):]
 return v
spec=rebase(spec);ev=spec['reference_evidence'];ev['preparation_id']=receipt['preparation_id'];ev['preparation_request']=receipt['request'];ev['primary_source_lock']=str(W/'source-lock.json');ev['learned_method_reuse']['rejected']=[{'method_id':x['method_id'],'reason':'Exact official destiny author code and true Guo input are locked here; this metadata candidate uses a different source/input/geometry and is not adopted.'}for x in receipt.get('learned_methods',{}).get('results',[])]
spec['project_style_contract']['registry_path']=str(W/'project-style.json');spec['project_style_contract']['registry_sha256']=sha(W/'project-style.json')
(W/'design-spec.yaml').write_text(yaml.safe_dump(spec,sort_keys=False,allow_unicode=True))
run([sys.executable,S/'scripts/validate_design_spec.py',W/'design-spec.yaml','--preparation-receipt',W/'preparation-receipt.json'])
run(['Rscript',C/'scripts/build_plot.R',P])
sources=[C/'scripts/render.R',C/'scripts/build_plot.R',S/'scripts/figure_style.R',W/'render-object.rds',C/'data/raw/guo.rda',C/'sources/DPT.R',C/'sources/author-dpt-plotting.r',C/'sources/author-diffusionmap-plotting.r']
auth=W/('authorization-'+run_id+'.json');cmd=[sys.executable,S/'scripts/authorize_render.py','--design-spec',W/'design-spec.yaml','--receipt',W/'preparation-receipt.json','--output',auth]
for x in sources:cmd+=['--source',x]
run(cmd);run(['Rscript',C/'scripts/render.R',P,auth,F])
report={'status':'RENDERED_PENDING_VISUAL_REVIEW','png':{'path':str(F)+'.png','sha256':sha(str(F)+'.png')},'pdf':{'path':str(F)+'.pdf','sha256':sha(str(F)+'.pdf')},'commands':logs,'scope':'Fixed official Guo author tutorial only; no visual/new-input/cross-environment/user acceptance is granted by replay.'}
(W/('replay-'+run_id+'.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items()if k!='commands'},ensure_ascii=False))
