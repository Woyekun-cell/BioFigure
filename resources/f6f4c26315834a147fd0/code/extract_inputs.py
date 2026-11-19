from pathlib import Path
import ast,csv,json,math,hashlib
from collections import defaultdict
W=Path(__file__).resolve().parent;S=W/'sources';members=defaultdict(set)
with (S/'Data9.csv').open()as f:
 for r in csv.DictReader(f):members[r['accession_module']].add(r['PanBaRT20_gene_id'])
tree=ast.parse((S/'author05.py').read_text());funcs=[x for x in tree.body if isinstance(x,ast.FunctionDef)and x.name in ['word2vec','cosdis']];ns={};exec(compile(ast.Module(body=funcs,type_ignores=[]),'bound-author-functions','exec'),ns);keys=sorted(members);vec={k:ns['word2vec'](list(members[k]))for k in keys};max_formula_error=0
with (S/'author-cosine.csv').open('w',newline='')as f:
 w=csv.writer(f);w.writerow(['module']+keys)
 for a in keys:
  vals=[]
  for b in keys:
   value=ns['cosdis'](vec[a],vec[b]);formula=len(members[a]&members[b])/math.sqrt(len(members[a])*len(members[b]));max_formula_error=max(max_formula_error,abs(value-formula));assert abs(value-formula)<1e-12;vals.append(round(value,4))
  w.writerow([a]+vals)
(W/'matrix/author-function-audit.json').write_text(json.dumps(dict(status='PASS',cells=738*738,max_raw_formula_error=max_formula_error,rounding='Python original author round(cosdis,4),sequential denominator semantics preserved'),indent=2)+'\n');print('Original author cosine matrix extracted; 544644 independently formula-checked cells')
