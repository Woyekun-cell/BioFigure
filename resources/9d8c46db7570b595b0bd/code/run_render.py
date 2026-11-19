#!/usr/bin/env python3
"""Issue a fresh one-use authorization for the exact renderer/input set and run native R."""
from pathlib import Path
import sys,subprocess,json,os
root=Path(__file__).resolve().parents[1];skill=root.parents[3]
task,lib,out,receipt,specarg=sys.argv[1:6]
spec=Path(specarg).resolve();assert spec.is_file(), "Fresh call design spec is required."
out=Path(out).resolve();out.mkdir(parents=True,exist_ok=True)
sources=[root/"scripts/render.R",root/"scripts/prepare_data.R",root/"data/metadata/data-qc.json",skill/"scripts/figure_style.R"]
sources+=sorted((root/"results/plot_data").glob("*"))
sources += [root/"sources/R"/(x+".R") for x in ["geom_range","geom_intron","geom_half_range","shorten_gaps","to_intron","to_diff"]]
auth=out/(task+"-authorization.json")
cmd=[sys.executable,str(skill/"scripts/authorize_render.py"),"--receipt",receipt,"--design-spec",str(spec)]
for p in sources:cmd+=["--source",str(p)]
cmd+=["--output",str(auth)]
subprocess.run(cmd,check=True)
rcmd=["Rscript",str(root/"scripts/render.R"),str(root),lib,str(out),task,str(auth),str(spec)]
result=subprocess.run(rcmd,text=True,capture_output=True,cwd=out)
(out/(task+"-render.log")).write_text(result.stdout+"\n"+result.stderr)
(out/(task+"-command.json")).write_text(json.dumps({"authorization":cmd,"render":rcmd,"exit_code":result.returncode},indent=2)+"\n")
print(result.stdout);print(result.stderr)
sys.exit(result.returncode)

