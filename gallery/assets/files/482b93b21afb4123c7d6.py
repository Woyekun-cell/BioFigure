#!/usr/bin/env python3
"""Fresh retrieval/CP2, native source BAM computation, authorization and R rendering."""
from pathlib import Path
import argparse,json,subprocess,sys,hashlib
import yaml
p=argparse.ArgumentParser();p.add_argument('--run-dir',type=Path,required=True);p.add_argument('--bam-python',required=True);a=p.parse_args();b=Path(__file__).resolve().parents[1];skill=b.parents[3];run=a.run_dir.resolve();run.mkdir(parents=True,exist_ok=True)
def call(args,log=None):
 r=subprocess.run([str(x) for x in args],text=True,capture_output=True)
 if log:log.write_text(r.stdout+r.stderr)
 if r.returncode:raise RuntimeError(r.stdout+r.stderr)
 return r.stdout
entry=json.loads(call([sys.executable,skill/'scripts/retrieve_learned_methods.py','--case-id','BENCH-ggsashimi-splicing-2026']))['results'][0]
assert not entry['missing_material'] and not entry['source_record_changed'] and not entry['changed_bound_material']
(run/'retrieval.json').write_text(json.dumps(entry,indent=2)+'\n')
for mode in ('overlay_shrink','mean_fixed'):
 dest=run/mode;dest.mkdir(exist_ok=True);base=b/'data/metadata';request=base/(mode+'-request.yaml');prep=dest/'preparation.json';call([sys.executable,skill/'scripts/prepare_figure.py',request,'--output',prep],dest/'prepare.log');rec=json.loads(prep.read_text());assert rec['status']=='PREFLIGHT_COMPLETE'
 spec=json.loads((base/(mode+'-design-spec.yaml')).read_text());ref=spec['reference_evidence'];ref['preparation_id']=rec['preparation_id'];ref['preparation_request']=rec['request'];ref['learned_source_reference']['read_hashes']=entry['current_read_hashes'];ref['learned_source_reference']['source_record_sha256']=entry['source_sha256'];sp=dest/'design-spec.yaml';sp.write_text(json.dumps(spec,indent=2)+'\n');call([sys.executable,skill/'scripts/validate_design_spec.py',sp,'--preparation-receipt',prep],dest/'CP2.log');(dest/'reproduction-retrieval-receipt.json').write_text(json.dumps(rec['retrievals']['reproduction'],indent=2)+'\n')
call([a.bam_python,b/'scripts/extract_data.py',b,run/'plot_data'],run/'data-extraction.log')
call([a.bam_python,b/'scripts/generate_native.py',b,run],run/'native-generation.log')
for mode in ('overlay_shrink','mean_fixed'):
 dest=run/mode;sp=dest/'design-spec.yaml';auth=dest/'authorization.json';sources=[b/'scripts/render.R',skill/'scripts/figure_style.R',dest/'native-generated.R',b/'sources/upstream/ggsashimi.py',b/'scripts/generate_native.py'];cmd=[sys.executable,skill/'scripts/authorize_render.py','--receipt',dest/'preparation.json','--design-spec',sp,'--output',auth]
 for source in sources:cmd+=['--source',source]
 call(cmd,dest/'authorization.log');call(['Rscript',b/'scripts/render.R',b,run,mode,auth,skill,sp],dest/'render.log');print('FRESH_REPLAY_RENDER_OK',mode)
