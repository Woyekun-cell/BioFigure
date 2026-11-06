"""Fresh fixed-CSV R replay. Does not rerun CellRank models or overwrite accepted figures."""
from pathlib import Path
import hashlib,subprocess,sys,time,json
C=Path(__file__).resolve().parents[1];P=next(p for p in C.parents if (p/'biofigure/scripts/prepare_figure.py').is_file());W=P/'work/2026-10-28-batch-six/cellrank';S=P/'biofigure'
assert hashlib.sha256((C/'data/raw/04_full_fates.h5ad').read_bytes()).hexdigest()=='1a360e8eec10aeb79729361dec1142cb30ea223f6d0fd2794280be252722c948','Fixed prior-model checkpoint changed;new input requires new contract.'
for b in json.loads((C/'validation/artifact-bindings.json').read_text()):
 p=Path(b['path'])
 if p.parent==C/'results/plot_data':assert hashlib.sha256(p.read_bytes()).hexdigest()==b['sha256'],'Fixed CSV changed;new preparation contract required.'
for cmd in [[sys.executable,str(S/'scripts/prepare_figure.py'),str(W/'request.yaml'),'--output',str(W/'preparation-receipt.json')],['Rscript',str(C/'scripts/build_plot.R'),str(P)],[sys.executable,str(W/'prepare_spec.py')],[sys.executable,str(W/'run_render.py'),'replay-'+str(time.time_ns())]]:
 subprocess.run(cmd,check=True,cwd=P)
print('Fresh authorized R PNG/PDF are in '+str(W)+'. Accepted figures are preserved. New direct visual review and CP4 are still required;no model rerun or native Python rendering is certified.')
