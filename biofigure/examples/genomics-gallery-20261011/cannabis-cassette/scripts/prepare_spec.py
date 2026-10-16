#!/usr/bin/env python3
"""Fresh portable BioFigure prepare and CP2; never inherits historical authorization."""
import argparse,hashlib,json,os,pathlib,shutil,subprocess,sys,yaml
os.environ["PYTHONDONTWRITEBYTECODE"]="1"
ROOT=pathlib.Path(__file__).resolve().parents[1]
def skill_root():
 return next(p for p in ROOT.parents if (p/'scripts/prepare_figure.py').is_file() and (p/'SKILL.md').is_file())
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output-dir',required=True,type=pathlib.Path);p.add_argument('--rscript',default='Rscript');p.add_argument('--source-view-confirmed',action='store_true');a=p.parse_args();
 if not a.source_view_confirmed:p.error('View sources/own-reference.png and pass --source-view-confirmed; no source view is inferred')
 out=a.output_dir.resolve();out.mkdir(parents=True,exist_ok=True);bf=skill_root()
 for n in ['request.yaml','project-style.yaml']:shutil.copyfile(ROOT/'data/metadata'/n,out/n)
 receipt=out/'preparation-receipt.json'
 result=subprocess.run([sys.executable,str(bf/'scripts/prepare_figure.py'),str(out/'request.yaml'),'--output',str(receipt)],capture_output=True,text=True);(out/'prepare.log').write_text(result.stdout+result.stderr)
 if result.returncode:raise RuntimeError('Fresh public preflight failed; see '+str(out/'prepare.log'))
 pre=json.loads(receipt.read_text());assert pre['status']=='PREFLIGHT_COMPLETE';s=yaml.safe_load((ROOT/'data/metadata/design-template.yaml').read_text());mid=s['reference_evidence']['selected_method_case_id'];entry=next(x for x in pre['learned_methods']['results'] if x['method_id']==mid)
 ref=s['reference_evidence'];ref['retrieval_query']={'domain':s['biology_contract']['primary_domain'],'task':s['figure_task'],'pattern':s['selected_pattern']};ref['preparation_id']=pre['preparation_id'];ref['preparation_request']=pre['request'];ref['learned_source_reference']['method_id']=mid;ref['learned_source_reference']['source_record_sha256']=entry['source_sha256'];ref['learned_source_reference']['read_hashes']=entry['current_read_hashes']
 own=ROOT/'sources/own-reference.png';image_sha=hashlib.sha256(own.read_bytes()).hexdigest();image_path=next(k for k,v in entry['current_read_hashes'].items() if v==image_sha and pathlib.Path(k).suffix=='.png');ref['learned_source_reference']['opened_source_asset']={'path':image_path,'sha256':image_sha,'original_size_viewed':a.source_view_confirmed}
 s['backend_lock']={**pre['route']['backend_lock'],'locked':True}
 fontcode='source(commandArgs(TRUE)[1]);cat(jsonlite::toJSON(bf_font("Arial"),auto_unbox=TRUE))';font=json.loads(subprocess.run([a.rscript,'-e',fontcode,str(bf/'scripts/figure_style.R')],check=True,capture_output=True,text=True).stdout);s['font_contract']['resolved_font_file']=font['path']
 spec=out/'design-spec.yaml';spec.write_text(yaml.safe_dump(s,sort_keys=False,allow_unicode=True));q=subprocess.run([sys.executable,str(bf/'scripts/validate_design_spec.py'),str(spec),'--preparation-receipt',str(receipt)],capture_output=True,text=True);(out/'cp2.log').write_text(q.stdout+q.stderr)
 if q.returncode:raise RuntimeError('Fresh public CP2 failed; see '+str(out/'cp2.log'))
 print(json.dumps({'status':'FRESH_PUBLIC_CP2_PASS','metadata_directory':str(out),'skill_root':str(bf)}))
if __name__=='__main__':main()
