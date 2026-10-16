#!/usr/bin/env python3
"""Fresh gate-bound native-R redraw. --output-dir creates an independent new package.
No installation, network, raw-omics or enrichment workflow. PDF final; PNG/SVG QA.
Requires this learned case and current BioFigure source library plus installed R.
"""
from pathlib import Path
import argparse, datetime, hashlib, json, os, shutil, subprocess, sys
import yaml
ROOT=Path(__file__).resolve().parents[1]
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output-dir',type=Path);ap.add_argument('--workdir',type=Path)
    ap.add_argument('--skill-root',type=Path);a=ap.parse_args()
    skill=(a.skill_root or Path(os.environ.get('BIOFIGURE_SKILL_ROOT',str(ROOT.parents[5])))).resolve()
    mode='network'
    panel='f' if mode=='bubbles' else 'e';method=f'BENCH-genomics-dpm-hoxa10-{mode}-2024'
    root=ROOT
    if a.output_dir:
        root=a.output_dir.resolve()
        if root.exists() and any(root.iterdir()): raise ValueError('--output-dir must be new or empty; reviewed outputs are never overwritten')
        root.mkdir(parents=True,exist_ok=True)
        for d in ['data/raw','sources','scripts']: shutil.copytree(ROOT/d,root/d,dirs_exist_ok=True)
        (root/'data/metadata').mkdir(parents=True)
        names=['source-learning.json','source-QC.json','figure-request.yaml','project-style.yaml','design-spec.yaml']
        if mode=='network':names+=['label-plan.json']
        for n in names:shutil.copyfile(ROOT/'data/metadata'/n,root/'data/metadata'/n)
    stamp=datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    work=(a.workdir or (root/'work/visual-qa' if a.output_dir else skill.parent/'work/2026-10-11-complex-reproduction/dpm'/f'{mode}-run-{stamp}')).resolve()
    work.mkdir(parents=True,exist_ok=True)
    for d in ['results/figures','results/tables','results/plot_data','evidence']: (root/d).mkdir(parents=True,exist_ok=True)
    commands=[];env=dict(os.environ,BIOFIGURE_SKILL_ROOT=str(skill))
    def run(cmd):
        commands.append(cmd);r=subprocess.run(cmd,capture_output=True,text=True,env=env, encoding="utf-8", errors="replace")
        with (work/'runtime.log').open('a') as f:f.write(json.dumps(cmd,ensure_ascii=False)+'\n'+r.stdout+r.stderr)
        if r.returncode:raise RuntimeError(f'Command failed ({r.returncode}): '+r.stdout+r.stderr)
    run(['Rscript',str(root/'scripts/audit_inputs.R'),str(root)])
    request=root/'data/metadata/figure-request.yaml';receipt=work/'preparation-receipt.json'
    run([sys.executable,str(skill/'scripts/prepare_figure.py'),str(request),'--output',str(receipt)])
    r=json.loads(receipt.read_text(encoding="utf-8"));adopted=next(x for x in r['learned_methods']['results'] if x['method_id']==method)
    spec=root/'data/metadata/design-spec.yaml';d=yaml.safe_load(spec.read_text(encoding="utf-8"))
    d['backend_lock']=dict(r['route']['backend_lock'],locked=True)
    d['reference_evidence']['preparation_id']=r['preparation_id'];d['reference_evidence']['preparation_request']=r['request']
    ref=d['reference_evidence']['learned_source_reference'];ref['source_record_sha256']=adopted['source_sha256'];ref['read_hashes']=adopted['current_read_hashes']
    ref['opened_source_asset']['sha256']=sha(skill/ref['opened_source_asset']['path'])
    d['project_style_contract']['registry_path']=str(root/'data/metadata/project-style.yaml');d['project_style_contract']['registry_sha256']=sha(root/'data/metadata/project-style.yaml')
    spec.write_text(yaml.safe_dump(d,allow_unicode=True,sort_keys=False), encoding="utf-8")
    run([sys.executable,str(skill/'scripts/validate_design_spec.py'),str(spec),'--preparation-receipt',str(receipt)])
    prefix=f'dpm_fig3{panel}_recolored'
    sources=[root/'scripts/render.R',skill/'scripts/figure_style.R']
    if mode=='bubbles':sources += [root/f'results/plot_data/{prefix}_plot_data.csv',root/'data/raw/panelE_Rdata.Rdata',root/'data/raw/cancer_gene_census_2023-01-18.tsv']
    else:sources += [*[root/f'results/plot_data/{prefix}_{x}.csv' for x in ['nodes','edges','memberships']],root/'data/metadata/label-plan.json',root/'data/raw/panelE_Rdata.Rdata',root/'data/raw/hsapiens.GO_BP_REACTOME.name.gmt']
    auth=work/'authorization.json';cmd=[sys.executable,str(skill/'scripts/authorize_render.py'),'--receipt',str(receipt),'--design-spec',str(spec),'--output',str(auth)]
    for p in sources:cmd+=['--source',str(p)]
    run(cmd);run(['Rscript',str(root/'scripts/render.R'),str(root),str(work),str(auth)])
    for p in [receipt,auth,Path(str(auth)+'.consumed')]:shutil.copyfile(p,root/'data/metadata'/p.name)
    pdf=root/f'results/figures/{prefix}.pdf'
    for dpi in [96,120]:run(['pdftoppm','-png','-singlefile','-r',str(dpi),str(pdf),str(work/f'{prefix}-pdf-{dpi}dpi')])
    record={'scope':d['scientific_message'],'mode':mode,'commands':commands,'workdir':str(work),'independent_output':bool(a.output_dir),
      'source_package':str(ROOT),'inputs':[{'path':str(p),'sha256':sha(p)} for p in [spec,request,*sources]],
      'plot_data':[{'path':str(p),'sha256':sha(p)} for p in sorted((root/'results/plot_data').glob('*.csv'))],
      'final_pdf':{'path':str(pdf),'sha256':sha(pdf)},'CP4':'PENDING_ACTUAL_NEW_OUTPUT_REVIEW'}
    (root/'data/metadata/reproduction-audit.json').write_text(json.dumps(record,indent=2,ensure_ascii=False), encoding="utf-8")
    print(json.dumps({'status':'RENDER_OK','method':method,'output_root':str(root),'pdf':record['final_pdf'],'workdir':str(work)},ensure_ascii=False))
if __name__=='__main__':main()
