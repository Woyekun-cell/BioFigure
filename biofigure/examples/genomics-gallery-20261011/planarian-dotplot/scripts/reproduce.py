#!/usr/bin/env python3
"""Public native replay into a new directory; fresh CP2, no old authorization/PASS.
Planarian consumes sealed public CSV. OHCA downloads one hash-pinned processed RDS.
Requires Python PyYAML, existing R packages and Arial. Native PDF uses the shared exact-font PDF/Ghostscript interface.
"""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,sys,urllib.request

sys.dont_write_bytecode=True
os.environ['PYTHONDONTWRITEBYTECODE']='1'
PACKAGE=Path(__file__).resolve().parents[1]
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def find_skill(explicit=None):
    if explicit:
        path=Path(explicit).resolve()
        if not (path/'scripts/prepare_figure.py').is_file():raise ValueError('--skill-root must name the BioFigure directory')
        return path
    for path in PACKAGE.parents:
        if (path/'scripts/prepare_figure.py').is_file() and (path/'manifest.yaml').is_file():return path
    raise ValueError('Cannot locate BioFigure; provide --skill-root')
def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output-dir',type=Path);ap.add_argument('--skill-root',type=Path)
    ap.add_argument('--r-library',type=Path,help='Existing task-local R library; no automatic installation')
    ap.add_argument('--input-rds',type=Path,help='OHCA only: reuse a byte-identical pinned RDS instead of downloading')
    ap.add_argument('--source-view-confirmed',action='store_true',help='Declare a fresh actual view of the sealed own reference PDF at its target size')
    ap.add_argument('--check-dependencies',action='store_true');ap.add_argument('--pdf-previews',action='store_true')
    a=ap.parse_args();skill=find_skill(a.skill_root)
    config=json.loads((PACKAGE/'data/metadata/execution-config.json').read_text(encoding="utf-8"))
    env=dict(os.environ,BIOFIGURE_SKILL_ROOT=str(skill),PYTHONDONTWRITEBYTECODE='1',PYTHON=sys.executable,PYTHONUTF8='1')
    if a.r_library:
        if not a.r_library.is_dir():raise ValueError('--r-library must exist')
        env['R_LIBS_USER']=str(a.r_library.resolve())
    packages=config['required_R_packages']
    expr='p<-c('+','.join(json.dumps(p) for p in packages)+'); missing<-p[!vapply(p,requireNamespace,logical(1),quietly=TRUE)]; if(length(missing))stop(paste("Missing existing R packages:",paste(missing,collapse=", "))); cat("DEPENDENCIES_OK\\n")'
    deps=subprocess.run(['Rscript','-e',expr],capture_output=True,text=True,encoding='utf-8',env=env, errors="replace")
    if deps.returncode:raise RuntimeError(deps.stdout+deps.stderr)
    if a.check_dependencies:
        print(json.dumps({'status':'DEPENDENCIES_OK','packages':packages,'mode':config['mode']}));return
    if not a.output_dir:ap.error('--output-dir is required for replay')
    if not a.source_view_confirmed:ap.error('Open the sealed own reference PDF at target size, then declare --source-view-confirmed; historical review is not inherited')
    root=a.output_dir.resolve()
    if root==PACKAGE or PACKAGE in root.parents:raise ValueError('Output must be outside the sealed public package')
    if root.exists() and (not root.is_dir() or any(root.iterdir())):raise ValueError('--output-dir must be new or empty')
    root.mkdir(parents=True,exist_ok=True)
    for folder in ['scripts','data/metadata','results/plot_data']:
        shutil.copytree(PACKAGE/folder,root/folder,dirs_exist_ok=True)
    for folder in ['data/raw','results/figures','results/tables','evidence','work/visual-qa']:(root/folder).mkdir(parents=True,exist_ok=True)
    work=root/'work/visual-qa';commands=[]
    def run(cmd):
        commands.append([str(x) for x in cmd]);r=subprocess.run([str(x) for x in cmd],capture_output=True,text=True,encoding='utf-8',env=env, errors="replace")
        with (work/'runtime.log').open('a') as f:f.write(json.dumps(commands[-1])+'\n'+r.stdout+r.stderr)
        if r.returncode:raise RuntimeError('Command failed: '+r.stdout+r.stderr)
    reference=skill/config['opened_reference']
    view={'scope':'Fresh analyst-declared view of own sealed public layout, not author-paper fidelity','reference_sha256':sha(reference),'reference':config['opened_reference'],'confirmed_this_invocation':True}
    (root/'data/metadata/source-view.json').write_text(json.dumps(view,indent=2), encoding="utf-8")
    if config['mode']=='ohca-native-rds':
        asset=config['pinned_processed_input'];target=root/asset['path']
        if a.input_rds:data=a.input_rds.read_bytes()
        else:
            with urllib.request.urlopen(asset['url'],timeout=60) as response:data=response.read(asset['bytes']+1)
        if len(data)!=asset['bytes'] or hashlib.sha256(data).hexdigest()!=asset['sha256']:raise ValueError('Pinned author RDS size/hash mismatch')
        target.write_bytes(data)
        (root/'data/metadata/source-lock.json').write_text(json.dumps({'schema_version':1,'method_id':config['method_id'],'assets':[{'path':asset['path'],'sha256':asset['sha256'],'bytes':asset['bytes']}],'native_packages':config['requested_native_commits']},indent=2), encoding="utf-8")
        run(['Rscript',root/'scripts/audit_source_input.R',root])
    else:run(['Rscript',root/'scripts/audit_inputs.R',root])
    receipt=work/'preparation-receipt.json';spec=root/'data/metadata/design-spec.yaml'
    run([sys.executable,skill/'scripts/prepare_figure.py',root/'data/metadata/figure-request.yaml','--output',receipt])
    run([sys.executable,root/'scripts/prepare_spec.py',root,receipt])
    run([sys.executable,skill/'scripts/validate_design_spec.py',spec,'--preparation-receipt',receipt])
    sources=[root/'scripts/render.R',skill/'scripts/figure_style.R']
    if config['mode']=='ohca-native-rds':sources.extend([root/'data/metadata/source-lock.json',root/config['pinned_processed_input']['path']])
    else:sources.extend(root/x['path'] for x in config['plot_data'])
    auth=work/'authorization.json';cmd=[sys.executable,skill/'scripts/authorize_render.py','--receipt',receipt,'--design-spec',spec,'--output',auth]
    for p in sources:cmd.extend(['--source',p])
    run(cmd)
    if config['mode']=='ohca-native-rds':
        library=a.r_library.resolve() if a.r_library else Path(subprocess.check_output(['Rscript','-e','cat(.libPaths()[1])'],text=True,encoding='utf-8',env=env, errors="replace").strip())
        run(['Rscript',root/'scripts/render.R',root,work,auth,library,root,spec])
    else:run(['Rscript',root/'scripts/render.R',root,work,auth])
    for asset in config['plot_data']:
        if sha(root/asset['path'])!=asset['sha256']:raise ValueError('Replayed plot data differ from public sealed CSV: '+asset['path'])
    pdf=root/config['final_pdf'];png=work/config['preview_png']
    if a.pdf_previews:
        for dpi in [96,120]:run(['pdftoppm','-png','-singlefile','-r',str(dpi),pdf,work/(pdf.stem+'-pdf-'+str(dpi)+'dpi')])
    record={'schema_version':1,'method_id':config['method_id'],'scope':config['scope'],'mode':config['mode'],
        'fresh_CP2':True,'authorization_consumed':json.loads(auth.read_text(encoding="utf-8")).get('consumed') is True,'old_PASS_copied':False,'raw_analysis_rerun':False,
        'source_view':view,'commands':commands,'plot_data':[{'path':x['path'],'sha256':sha(root/x['path'])} for x in config['plot_data']],
        'final_pdf':{'path':config['final_pdf'],'sha256':sha(pdf)},'new_png_sha256':sha(png),
        'visual_review':'PENDING_ACTUAL_NEW_OUTPUT_REVIEW','formal_author_panel_fidelity':'NOT_VERIFIED','new_input_transfer':'NOT_VERIFIED'}
    (root/'data/metadata/reproduction-audit.json').write_text(json.dumps(record,indent=2), encoding="utf-8")
    print(json.dumps({'status':'NATIVE_REPLAY_RENDERED','scope':config['scope'],'output_dir':str(root),'audit':str(root/'data/metadata/reproduction-audit.json')},ensure_ascii=False))
if __name__=='__main__':main()
