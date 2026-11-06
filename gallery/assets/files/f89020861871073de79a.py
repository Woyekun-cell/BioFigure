#!/usr/bin/env python3
"""Execute pinned upstream's documented debug mode, retain the complete generated R."""
import argparse,os,subprocess,json,sys,hashlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('root',type=Path);p.add_argument('out',type=Path);a=p.parse_args();b=a.root.resolve();u=b/'sources/upstream';a.out=a.out.resolve();a.out.mkdir(parents=True,exist_ok=True)
common=[sys.executable,str(u/'ggsashimi.py'),'-b',str(u/'examples/input_bams.tsv'),'-c','chr10:27040584-27048100','-M','10','-C','3','-O','3','--width=18','--height=3']
commands={}
for mode,opts in {'overlay_shrink':['-g',str(u/'examples/annotation.gtf'),'--shrink','--alpha','0.25','--base-size=20','--ann-height=4','-P',str(u/'examples/palette.txt')],'mean_fixed':['-A','mean','--alpha','1','--base-size=16','--fix-y-scale']}.items():
 target=a.out/mode;target.mkdir(exist_ok=True);cmd=common+opts;env=dict(os.environ,GGSASHIMI_DEBUG='yes');r=subprocess.run(cmd,cwd=target,env=env,capture_output=True,text=True);(target/'native-execution.log').write_text(r.stdout+r.stderr);r.check_returncode();(target/'native-generated.R').write_bytes((target/'R_script').read_bytes());(target/'R_script').unlink();commands[mode]={'command':cmd,'environment':{'GGSASHIMI_DEBUG':'yes'},'returncode':r.returncode,'R_sha256':hashlib.sha256((target/'native-generated.R').read_bytes()).hexdigest()}
(a.out/'native-commands.json').write_text(json.dumps(commands,indent=2)+'\n');print('NATIVE_PYTHON_GENERATION_OK')
