from pathlib import Path
import csv,json,hashlib
import openpyxl
W=Path(__file__).resolve().parent;S=W/'sources'
b=openpyxl.load_workbook(S/'lfq-SourceData.xlsx',read_only=True,data_only=True)
def save(name,header,rows):
 with (S/name).open('w',newline='')as f:
  w=csv.writer(f);w.writerow(header);w.writerows(rows)
rows=list(b['figure4'].values);boxes=[];scatter=[]
for i,r in enumerate(rows):
 if isinstance(r[0],str)and r[0].startswith('figure 4'):
  panel=r[0][-1];j=i+2
  while j<len(rows)and rows[j][0]is not None:
   z=rows[j]
   if panel in 'ABCD':boxes.append([panel,'DDA'if panel in 'AC'else'DIA','Protein abundance'if panel in'AB'else'Retention time']+list(z[:8]))
   else:scatter.append([panel,'DDA'if panel=='E'else'DIA']+list(z[:7]))
   j+=1
save('cv-boxes.csv',['panel','acquisition','metric','setup','minimum','q05','q25','median','q75','q90','maximum'],boxes)
save('cv-scatter.csv',['panel','acquisition','median_RT_CV','setup','peak_capacity','average_peak_width','total_gradient','programmed_gradient','LC_system'],scatter)
rows=list(b['figure3'].values);curves=[]
for start,stop,mode in [(3,52,'DDA'),(56,110,'DIA')]:
 for r in rows[start:stop]:
  for off,setup in [(0,'A_ulti_ex'),(4,'G_nLC_tTOF')]:
   if r[off]is not None:curves.append([mode,setup]+list(r[off:off+3]))
save('dilution-medians.csv',['acquisition','setup','bin','condition','median_log10_abundance'],curves)
(W/'download-receipt.json').write_text(json.dumps({'publisher_urls':{'OA-SourceData.zip':'https://media.springernature.com/original/springer-static/esm/art%3A10.1038%2Fs41467-026-74993-y/MediaObjects/41467_2026_74993_MOESM22_ESM.zip','lfq-SourceData.xlsx':'https://media.springernature.com/original/springer-static/esm/art%3A10.1038%2Fs41467-025-64501-z/MediaObjects/41467_2025_64501_MOESM14_ESM.xlsx'},'files':[{'path':str(f.resolve()),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()}for f in sorted(S.iterdir())if f.is_file()]},indent=2)+'\n')
print('Extracted',len(boxes),'source box summaries,',len(scatter),'scatter rows,',len(curves),'median trajectories.')
