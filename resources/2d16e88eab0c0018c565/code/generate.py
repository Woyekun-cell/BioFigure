from pathlib import Path
import csv, hashlib, json, sys
import numpy as np
work = Path(sys.argv[1]).resolve()
project = work.parents[1]
q = json.loads((work / 'config.json').read_text())
rng = np.random.default_rng(q['seed'])
out = project / 'results/plot_data'
out.mkdir(parents=True, exist_ok=True)
rows, features = [], []
patterns = np.array([[1.1,.5,-.8,-.5,0,.3],[-.5,1.2,1,.2,-.8,.5],
                     [-.7,-.6,.1,1.1,.7,-.4],[.4,-1.1,.6,-.6,1.1,.4]])
effects = [(0.10,1.02),(-.80,.32),(.52,-.75),(-.15,-.08)]
for i in range(28):
    module = i // 7
    protein = f'P{i+1:02d}'
    features.append([protein, 'ABCD'[module], *np.round(patterns[module]+rng.normal(0,.33,6),6)])
    for c, cohort in enumerate(('Reference','Challenge')):
        center = effects[module][c] + rng.normal(0,.28)
        for j in range(36):
            value = rng.normal(center,.44 + .09*((i+c)%4))
            while abs(value) > 2.8:
                value = rng.normal(center,.44 + .09*((i+c)%4))
            rows.append([protein,cohort,f'{cohort[0]}{j+1:02}',round(float(value),6)])
files = []
for name, fields, data in [('features',['protein','module']+[f'feature{i}' for i in range(1,7)],features),
                           ('abundance',['protein','cohort','subject','value'],rows)]:
    path = out / f"{q['stem']}_{name}.csv"
    with path.open('w',newline='') as f:
        writer=csv.writer(f)
        writer.writerow(fields)
        writer.writerows(data)
    files.append(dict(path=str(path),sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
(work/'simulation.json').write_text(json.dumps(dict(seed=q['seed'],files=files,
    method='PCG64 fixed seed. Four planted six-feature profiles and independent subject fixtures. Each protein has 36 observations per cohort. Values outside ±2.8 are resampled.',
    units='simulated log2 abundance relative to fixed reference; sample fractions; Euclidean distance in six descriptive features'),indent=2)+'\n')
