from pathlib import Path
import os,subprocess,sys
P=next(x for x in Path(__file__).resolve().parents if (x/'biofigure').is_dir()and(x/'work').is_dir())
W=P/'work/2026-10-28-batch-six/fleck'
subprocess.run([sys.executable,str(W/'run_render.py'),'replay-'+str(os.getpid())],check=True)
