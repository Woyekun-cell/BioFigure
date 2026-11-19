from pathlib import Path
import csv,json,hashlib
import openpyxl
W=Path(__file__).resolve().parent;S=W/'sources';P=W.parents[1];D=P/'results/plot_data'
def save(name,header,rows):
    with (S/name).open('w',newline='') as f:
        w=csv.writer(f);w.writerow(header);w.writerows(rows)
def table(book,sheet,name):
    rows=list(book[sheet].values);save(name,rows[0],rows[1:])
b=openpyxl.load_workbook(S/'41589_2023_1284_MOESM11_ESM.xlsx',read_only=True,data_only=True)
rows=list(b['Figure 4a'].values)
save('nparc-NEK2.csv',rows[1][:5],[r[:5] for r in rows[2:] if r[0] is not None])
save('nparc-null-parameters.csv',rows[1][6:19],[rows[2][6:19]])
save('nparc-alternative-parameters.csv',rows[6][6:20],[r[6:20] for r in rows[7:19]])
for panel,name in [('4b','global'),('4c','DNTT'),('4d','INPP4B')]:table(b,'Figure '+panel,'nparc-'+name+'.csv')
b=openpyxl.load_workbook(S/'41589_2023_1284_MOESM12_ESM.xlsx',read_only=True,data_only=True)
for panel,name in [('5b','global'),('5c','profiles'),('5e','sensitivity')]:table(b,'Figure '+panel,'coaggregation-'+name+'.csv')
b=openpyxl.load_workbook(S/'41467_2024_48009_MOESM4_ESM.xlsx',read_only=True,data_only=True)
for panel in ['7a','7b','7c','7d','9a','9b']:table(b,'Supplementary Figure '+panel,'dilution-'+panel+'.csv')
b=openpyxl.load_workbook(S/'simpel-suppdata.xlsx',read_only=True,data_only=True)
times=[0,2,4,8,16,32]
for sheet,name in [('MIDs for PCs and DAGs (SIMPEL)','mid'),('MIDs (adjusted by pool size)','scaled-mid')]:
    rows=[];compound=None
    for r in list(b[sheet].values)[3:]:
        if r[0]:compound=r[0].strip()
        if not r[1]:continue
        for j,v in enumerate(r[3:21]):
            if v is not None:rows.append([compound,r[1],times[j//3],j%3+1,v])
    save('isotope-'+name+'.csv',['compound','isotopologue','time','replicate','value'],rows)
rows=[]
for r in list(b['Label enrichment (nmol of 13C)'].values)[3:]:
    if not r[0]:continue
    for j,v in enumerate(r[2:20]):rows.append([r[0].strip(),times[j//3],j%3+1,v])
save('isotope-enrichment.csv',['compound','time','replicate','value'],rows)
# This receipt inventories preserved source files; URLs and commits are in source-locators.
(W/'download-receipt.json').write_text(json.dumps({'files':[{'path':str(f),'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'bytes':f.stat().st_size} for f in sorted(S.iterdir()) if f.is_file()]},indent=2)+'\n')
print('Public source sheets extracted; raw workbooks unchanged.')
