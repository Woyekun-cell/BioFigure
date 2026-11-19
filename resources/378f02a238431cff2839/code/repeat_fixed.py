from pathlib import Path
import json,hashlib,subprocess,pdfplumber
W=Path(__file__).resolve().parent;P=W.parents[1];F=P/'results/figures/omicscope_oxphos_chord_20261105';D=P/'results/plot_data/omicscope_oxphos_chord_20261105';sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def streams(p):
 with pdfplumber.open(p)as pdf:return [hashlib.sha256(b''.join(x.get_data()for x in page.page_obj.contents)).hexdigest()for page in pdf.pages]
before=dict(png=sha(str(F)+'.png'),pdf_content_streams=streams(str(F)+'.pdf'),csv={p.name:sha(p)for p in D.glob('*.csv')})
for cmd in [['python3',str(W/'prepare_data.py')],['Rscript',str(W/'explore.R'),str(P)],['python3',str(W/'prepare_spec.py')],['Rscript',str(W/'render.R'),str(P)]]:
 r=subprocess.run(cmd,capture_output=True,text=True);assert r.returncode==0,(cmd,r.stdout,r.stderr)
after=dict(png=sha(str(F)+'.png'),pdf_content_streams=streams(str(F)+'.pdf'),csv={p.name:sha(p)for p in D.glob('*.csv')});assert before==after,(before,after)
(W/'fixed-input-repeat.json').write_text(json.dumps(dict(status='PASS',before=before,after=after,scope='Two complete same-input transform and nativeR layout/export runs. PNG bytes,PDF nativecontentstreams,3sourceprojectedCSVs identical. No new-input/crossenvironment/stresstest claim.'),indent=2)+'\n');print('Fixedinputrepeat PASS')
