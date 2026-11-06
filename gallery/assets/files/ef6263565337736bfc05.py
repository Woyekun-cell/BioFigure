"""Fresh preparation and authorized R replay of this fixed source fixture. Does not overwrite accepted figures."""
from pathlib import Path
import hashlib,subprocess,sys,time,json
C=Path(__file__).resolve().parents[1];P=next(p for p in C.parents if (p/'biofigure/scripts/prepare_figure.py').is_file());W=P/'work/2026-10-28-batch-six/spatial';S=P/'biofigure'
assert hashlib.sha256((C/'data/raw/seqfish.h5ad').read_bytes()).hexdigest()=='7e544c0ede7538067537da69c52748ad01522ef7fc8691e077fd73c9434019f7','Fixed source bytes changed;new input requires new contract.'
for cmd in [[sys.executable,str(S/'scripts/prepare_figure.py'),str(W/'request.yaml'),'--output',str(W/'preparation-receipt.json')],['Rscript',str(C/'scripts/compute.R'),str(P)],['Rscript',str(C/'scripts/build_plot.R'),str(P)],[sys.executable,str(W/'prepare_spec.py')],[sys.executable,str(W/'run_render.py'),'replay-'+str(time.time_ns())]]:
 subprocess.run(cmd,check=True,cwd=P)
print('Fresh R PNG/PDF are in '+str(W)+'. Original accepted artifacts are preserved. Fresh direct visual review and CP4 are still required.')
