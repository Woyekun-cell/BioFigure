#!/usr/bin/env python3
"""Fresh native-R replay of fixed author processed Fig.4b inputs; never copies PASS."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
METHOD='BENCH-genomics-lepidoptera-merian-paints-2024'
PREFIX='fig4b_merian_recolored'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--output-dir',type=Path,required=True)
    ap.add_argument('--skill-root',type=Path)
    ap.add_argument('--workdir',type=Path)
    ap.add_argument('--source-view-confirmed',action='store_true',
        help='Confirm that the exact source Fig.4 PNG/PDF has actually been inspected for this replay.')
    a=ap.parse_args()
    if not a.source_view_confirmed:ap.error('Actual source viewing is required; pass --source-view-confirmed only after inspection.')
    skill=(a.skill_root or Path(os.environ.get('BIOFIGURE_SKILL_ROOT',str(ROOT.parents[3])))).resolve()
    root=a.output_dir.resolve()
    if root==ROOT or ROOT in root.parents or root in ROOT.parents:
        raise ValueError('--output-dir must be outside the preserved source package and its ancestors')
    if root.exists() and any(root.iterdir()):raise ValueError('--output-dir must be new or empty; reviewed outputs are never overwritten')
    work=(a.workdir or root/'work/visual-qa').resolve()
    if work==ROOT or ROOT in work.parents or work in ROOT.parents:
        raise ValueError('--workdir must not overlap the preserved source package')
    if work==root or (root in work.parents and work.relative_to(root).parts[0]!='work'):
        raise ValueError('--workdir inside output must be a dedicated subdirectory of output/work')
    if work in root.parents:
        raise ValueError('--workdir must not be an ancestor of output')
    if work.exists() and any(work.iterdir()):
        raise ValueError('--workdir must be new or empty; prior QA evidence is preserved')
    root.mkdir(parents=True,exist_ok=True)
    for d in ['sources','data/raw','scripts']:shutil.copytree(ROOT/d,root/d,dirs_exist_ok=True)
    (root/'data/metadata').mkdir(parents=True,exist_ok=True)
    for name in ['source-learning.json','figure-request.yaml','project-style.yaml']:
        shutil.copyfile(ROOT/'data/metadata'/name,root/'data/metadata'/name)
    work.mkdir(parents=True,exist_ok=True)
    for d in ['results/figures','results/tables','evidence']:(root/d).mkdir(parents=True,exist_ok=True)
    commands=[];env=dict(os.environ,BIOFIGURE_SKILL_ROOT=str(skill))
    def run(cmd):
        commands.append(list(map(str,cmd)))
        z=subprocess.run(cmd,capture_output=True,text=True,env=env)
        with (work/'runtime.log').open('a') as f:f.write(json.dumps(cmd,ensure_ascii=False)+'\n'+z.stdout+z.stderr)
        if z.returncode:raise RuntimeError(f'Command failed({z.returncode}): '+z.stdout+z.stderr)
    run(['Rscript',str(root/'scripts/prepare_data.R'),'--output-dir',str(root)])
    if (root/'scripts/verify_source.py').exists():
        run([sys.executable,str(root/'scripts/verify_source.py'),'--prepared-root',str(root),
             '--output',str(root/'evidence/independent-source-audit.json')])
    receipt=work/'preparation-receipt.json';spec=root/'data/metadata/design-spec.yaml'
    request=root/'data/metadata/figure-request.yaml'
    run([sys.executable,str(skill/'scripts/prepare_figure.py'),str(request),'--output',str(receipt)])
    run([sys.executable,str(root/'scripts/prepare_spec.py'),str(root),str(receipt)])
    run([sys.executable,str(skill/'scripts/validate_design_spec.py'),str(spec),'--preparation-receipt',str(receipt)])
    sources=[root/'scripts/render.R',skill/'scripts/figure_style.R',
        *[root/f'data/plot_data/fig4b_{n}.csv' for n in ['chromosomes','loci','ggtree_data']]]
    auth=work/'authorization.json'
    cmd=[sys.executable,str(skill/'scripts/authorize_render.py'),'--receipt',str(receipt),'--design-spec',str(spec),'--output',str(auth)]
    for p in sources:cmd+=['--source',str(p)]
    run(cmd);run(['Rscript',str(root/'scripts/render.R'),str(root),str(work),str(auth)])
    run([sys.executable,str(root/'scripts/verify_render_mapping.py'),'--case-root',str(root)])
    for p in [receipt,auth,Path(str(auth)+'.consumed')]:shutil.copyfile(p,root/'data/metadata'/p.name)
    pdf=root/f'results/figures/{PREFIX}.pdf'
    poppler=os.environ.get('BIOFIGURE_PDFTOPPM') or shutil.which('pdftoppm')
    if not poppler:
        candidate=Path.home()/'.cache/codex-runtimes/codex-primary-runtime/dependencies/native/poppler/poppler/bin/pdftoppm'
        if candidate.is_file():poppler=str(candidate)
    if not poppler:raise RuntimeError('Native pdftoppm unavailable: preserve PDF, actual PDF review still required.')
    for dpi in [96,120]:run([poppler,'-png','-singlefile','-r',str(dpi),str(pdf),str(work/f'{PREFIX}-pdf-{dpi}dpi')])
    bind=lambda p:{'path':str(p),'sha256':sha(p)}
    record={'schema_version':1,'method_id':METHOD,'scope':'fixed author processed formal Fig.4b; new categorical palette',
      'source_package':str(ROOT),'output_root':str(root),'workdir':str(work),'commands':commands,
      'inputs':[bind(p) for p in [request,spec,*sources]],
      'executed_scripts':[bind(p) for p in sorted((root/'scripts').glob('*')) if p.is_file()],
      'plot_data':[bind(p) for p in sorted((root/'data/plot_data').glob('*')) if p.is_file()],
      'final_pdf':bind(pdf),'visual_qualification':'PENDING_ACTUAL_NEW_OUTPUT_REVIEW',
      'fresh_CP2':True,'old_PASS_copied':False,'raw_analysis_rerun':False,'network_required':False,
      'new_input_transfer':'NOT_VERIFIED','original_whole_Fig4':'NOT_VERIFIED'}
    (root/'data/metadata/reproduction-audit.json').write_text(json.dumps(record,indent=2,ensure_ascii=False)+'\n')
    print(json.dumps({'status':'RENDER_OK_NOT_VISUAL_PASS','method':METHOD,'pdf':record['final_pdf'],'workdir':str(work)},ensure_ascii=False))
if __name__=='__main__':main()
