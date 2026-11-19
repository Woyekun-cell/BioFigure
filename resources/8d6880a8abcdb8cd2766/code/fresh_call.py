#!/usr/bin/env python3
"""Fresh reference retrieval, preparation, CP2, exact one-use authorization, and native rendering.
Usage: python3 fresh_call.py LIBRARY_DIR OUTPUT_DIR [sod1-structure|pknox1-comparison]
An existing output directory with consumed authorization is not reused.
"""
from pathlib import Path
import json,subprocess,sys,yaml,shutil
root=Path(__file__).resolve().parents[1];skill=root.parents[3]
lib=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve();out.mkdir(parents=True,exist_ok=True)
tasks=sys.argv[3:] or ["sod1-structure","pknox1-comparison"]
class Quoted(yaml.SafeDumper):pass
Quoted.add_representer(str,lambda d,v:d.represent_scalar("tag:yaml.org,2002:str",v,style='"'))
retrieval=subprocess.run([sys.executable,str(skill/"scripts/retrieve_learned_methods.py"),"--case-id","BENCH-ggtranscript-sod1-2026"],capture_output=True,text=True,check=True)
(out/"learned-method-retrieval.json").write_text(retrieval.stdout)
entry=json.loads(retrieval.stdout)["results"][0]
assert not entry["missing_material"] and not entry["source_record_changed"] and not entry["changed_bound_material"]
for task in tasks:
 assert task in ["sod1-structure","pknox1-comparison"]
 receipt=out/(task+"-preparation.json");spec=out/(task+"-design-spec.yaml")
 assert not receipt.exists() and not spec.exists(), "Use a new call directory; previous call evidence is immutable."
 shutil.copy2(root/"data/metadata"/(task+"-design-spec.yaml"),spec)
 subprocess.run([sys.executable,str(skill/"scripts/prepare_figure.py"),str(root/"data/metadata"/(task+"-request.yaml")),"--output",str(receipt)],check=True)
 prepared=json.loads(receipt.read_text());assert prepared["status"]=="PREFLIGHT_COMPLETE"
 document=yaml.safe_load(spec.read_text());ref=document["reference_evidence"]
 ref["preparation_id"]=prepared["preparation_id"];ref["preparation_request"]=prepared["request"]
 binding=ref["learned_source_reference"];binding["source_record_sha256"]=entry["source_sha256"];binding["read_hashes"]=entry["current_read_hashes"]
 assert binding["opened_source_asset"]["sha256"]==entry["current_read_hashes"][binding["opened_source_asset"]["path"]],"Original image changed: open and review it before reusing."
 spec.write_text(yaml.dump(document,Dumper=Quoted,sort_keys=False,allow_unicode=True))
 cp=subprocess.run([sys.executable,str(skill/"scripts/validate_design_spec.py"),str(spec),"--preparation-receipt",str(receipt)],capture_output=True,text=True)
 (out/(task+"-cp2.log")).write_text(cp.stdout+"\n"+cp.stderr);assert cp.returncode==0,cp.stdout+cp.stderr
 subprocess.run([sys.executable,str(root/"scripts/run_render.py"),task,str(lib),str(out),str(receipt),str(spec)],check=True)
print("Fresh renders produced. Open both current PNGs/PDF previews; regenerate artifact-bound reviews before claiming visual PASS.")

