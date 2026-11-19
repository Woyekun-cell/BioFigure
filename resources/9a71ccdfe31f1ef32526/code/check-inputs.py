#!/usr/bin/env python3
"""Independent standard-library source-data and quantile audit; writes no files."""
from pathlib import Path
from inspect_xlsx_stdlib import sheets
import csv,math,json
C=Path(__file__).resolve().parents[1]
def table(rows):
    head={''.join(c for c in k if c.isalpha()):v for k,v in rows[0].items()}
    return [{head[''.join(c for c in k if c.isalpha())]:v for k,v in r.items()}for r in rows[1:]]
def quantile(values,p):
    v=sorted(values);f=(len(v)-1)*p;i=math.floor(f);return v[i]+(f-i)*(v[min(i+1,len(v)-1)]-v[i])
source={k:table(v)for k,v in sheets(C/'sources/MOESM13.xlsx').items()};csv_err=0.
for key,rows in source.items():
    parsed=list(csv.DictReader((C/'results/plot_data/fig2abcd'/(key+'.csv')).open()))
    assert len(rows)==len(parsed)
    for a,b in zip(rows,parsed):
        assert a.keys()==b.keys()
        for k,v in a.items():
            if isinstance(v,float):csv_err=max(csv_err,abs(v-float(b[k])))
            else:assert v==b[k]
assert csv_err<1e-12
raw=source['panel_c_target_expression'];scaled=list(csv.DictReader((C/'results/plot_data/fig2abcd/panel_c_scaled_expression.csv').open()));err=0.
for gene in list(raw[0])[1:]:
    low=quantile([r[gene]for r in raw],.05);high=quantile([r[gene]for r in raw],.95);den=high-low or 1
    for a,b in zip(raw,scaled):
        assert a['tumor_id']==b['tumor_id'];expected=min(1,max(0,(a[gene]-low)/den));err=max(err,abs(expected-float(b[gene])))
assert err<1e-12
assert [r['ligand']for r in source['panel_a_ligand_activity']]==[r['ligand']for r in source['panel_b_ligand_target']]
assert list(source['panel_b_ligand_target'][0])[1:]==list(raw[0])[1:]
assert [r['tumor_id']for r in raw]==[r['tumor_id']for r in source['panel_d_tumor_score']]
print(json.dumps({'status':'PASS','source_workbook_csv_max_abs_error':csv_err,'scaled310_max_abs_error':err,'all_shared_keys_match':True,'raw_analysis_run':False},indent=2))
