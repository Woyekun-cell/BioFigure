#!/usr/bin/env python3
"""Audit rendered PDF text/vector content and fixed-input replay equality."""
import argparse,collections,csv,hashlib,json,re,math
from pathlib import Path
import pypdfium2 as pdfium
from pypdf import PdfReader
p=argparse.ArgumentParser();p.add_argument('root',type=Path);p.add_argument('run1',type=Path);p.add_argument('run2',type=Path);a=p.parse_args();b=a.root.resolve();r1=a.run1.resolve();r2=a.run2.resolve();out=b/'evidence';raw=list(csv.DictReader((b/'results/plot_data/junctions.csv').open()));grouped=collections.defaultdict(list)
for row in raw:
 if row['passes_M10']=='True':grouped[(row['group'],int(row['upstream_donor']),int(row['upstream_acceptor']))].append(int(row['alignment_count']))
qa={'schema_version':1,'status':'PASS','scope':'fixed official BAM fixture only; model visual review separate','modes':{},'plot_data_hash_equal':{},'expected_source_count_labels':{str(k):v for k,v in grouped.items()}}
for pth in (r1/'plot_data').glob('*.csv'):
 equal=pth.read_bytes()==(r2/'plot_data'/pth.name).read_bytes();qa['plot_data_hash_equal'][pth.name]=equal;assert equal
for mode in ('overlay_shrink','mean_fixed'):
 d={};fn='ggsashimi_'+mode;pdf=r1/mode/(fn+'.pdf');doc=pdfium.PdfDocument(pdf);page=doc[0];tp=page.get_textpage();n=tp.count_chars();width,height=page.get_size();sizes=[];outside=[]
 for i in range(n):
  ch=tp.get_text_range(i,1)
  if not ch.strip():continue
  box=tp.get_charbox(i);pass # Quartz encodes font size in the text matrix, audited below
  if min(box)<-0.1 or box[2]>width+.1 or box[3]>height+.1:outside.append({'index':i,'char':ch,'bbox':box})
 def font_visit(text,cm,tm,font,size):
  if text.strip(): sizes.append(size*math.hypot(tm[2]*cm[0]+tm[3]*cm[2],tm[2]*cm[1]+tm[3]*cm[3]))
 PdfReader(pdf).pages[0].extract_text(visitor_text=font_visit)
 d['PDF']={'size_mm':[width*25.4/72,height*25.4/72],'minimum_font_pt':min(sizes),'font_sizes_pt':sorted(set(round(x,4) for x in sizes)),'outside_page_glyphs':outside,'fonts':[str(x.get_object().get('/BaseFont')) for x in PdfReader(pdf).pages[0]['/Resources']['/Font'].values()],'text':tp.get_text_range()};assert not outside and min(sizes)>=6.99
 images=list(PdfReader(pdf).pages[0].images);d['raster_images']=len(images);assert len(images)==0
 svg=(r1/mode/(fn+'.svg')).read_text();d['svg_image_nodes']=len(re.findall(r'<image\b',svg));assert not d['svg_image_nodes']
 page.render(scale=96/72).to_pil().save(r1/mode/(fn+'-pdf-96dpi.png'));page.render(scale=170/72).to_pil().save(r1/mode/(fn+'-pdf-review.png'))
 for ext in ('png','svg'):
  x=r1/mode/(fn+'.'+ext);y=r2/mode/(fn+'.'+ext);d[ext+'_sha256_equal']=hashlib.sha256(x.read_bytes()).hexdigest()==hashlib.sha256(y.read_bytes()).hexdigest();assert d[ext+'_sha256_equal']
 d['group_checks']={}
 for group in ('Endothelial','Epithelial','Mesenchymal'):
  rows=list(csv.DictReader((r1/mode/(group+'-display-junctions.csv')).open()));expect=[v for k,v in sorted(grouped.items()) if k[0]==group];assert len(rows)==3
  for row,vals in zip(rows,expect):
   if mode=='overlay_shrink':assert row['jlabel']==','.join(map(str,vals)) and float(row['count'])==sum(vals)
   else:assert float(row['jlabel'])==round(sum(vals)/len(vals))
  d['group_checks'][group]={'arcs':len(rows),'labels':[x['jlabel'] for x in rows],'count_sum_or_mean':[float(x['count']) for x in rows]}
 qa['modes'][mode]=d
(out/'independent-replay-and-PDF-QC.json').write_text(json.dumps(qa,indent=2)+'\n');print('REPLAY_PDF_QC_PASS')
