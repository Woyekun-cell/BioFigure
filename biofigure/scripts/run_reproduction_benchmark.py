#!/usr/bin/env python3
"""Audit natural-language benchmark deliverables and render receipts."""
from __future__ import annotations
import argparse,hashlib,json
from pathlib import Path
from PIL import Image

def digest(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def audit_outputs(root,task_ids):
 errors=[];items=[]
 for task in task_ids:
  png=root/'figures'/f'{task}.png';csv=root/'plot_data'/f'{task}.csv';receipt=Path(str(png)+'.render.json')
  missing=[str(p) for p in [png,csv,receipt] if not p.is_file()]
  if missing:errors.append({'task':task,'missing':missing});continue
  try:
   with Image.open(png) as im: width,height=im.size;im.verify()
   r=json.loads(receipt.read_text())
   if r.get('status')!='PASS' or r.get('artifact',{}).get('sha256')!=digest(png):raise ValueError('render receipt mismatch')
   items.append({'task':task,'png_sha256':digest(png),'plot_data_sha256':digest(csv),'pixels':[width,height]})
  except Exception as exc:errors.append({'task':task,'error':str(exc)})
 return {'status':'PASS' if not errors else 'FAIL','tasks_verified':len(items),'errors':errors,'items':items,
         'scope':'artifact integrity and render receipt; visual review recorded separately'}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True);p.add_argument('--tasks',nargs='+',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=audit_outputs(a.root,a.tasks);a.output.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n');print(json.dumps(out,ensure_ascii=False,indent=2));raise SystemExit(0 if out['status']=='PASS' else 1)
