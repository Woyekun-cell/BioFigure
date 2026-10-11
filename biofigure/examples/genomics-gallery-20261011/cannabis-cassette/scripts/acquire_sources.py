#!/usr/bin/env python3
"""Fetch licensed pinned BUSCOplot source separately; no author raw-data pipeline."""
import argparse,hashlib,json,pathlib,urllib.request,concurrent.futures
ROOT=pathlib.Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output-dir',required=True,type=pathlib.Path);p.add_argument('--check-only',action='store_true');a=p.parse_args();out=a.output_dir.resolve();lock=json.loads((ROOT/'data/metadata/native-acquisition.json').read_text())
 def get(e):
  f=(out/e['path']).resolve()
  if out not in f.parents:raise ValueError('Unsafe source path')
  if f.is_file():b=f.read_bytes()
  elif a.check_only:raise FileNotFoundError(f)
  else:
   with urllib.request.urlopen(urllib.request.Request(e['url'],headers={'User-Agent':'BioFigure-public-replay/1.0'}),timeout=60) as h:b=h.read(e['bytes']+1)
  if len(b)!=e['bytes'] or hashlib.sha256(b).hexdigest()!=e['sha256']:raise ValueError('Pinned source mismatch:'+e['path'])
  f.parent.mkdir(parents=True,exist_ok=True)
  if not f.exists():f.write_bytes(b)
  return {'path':str(f),'sha256':e['sha256'],'url':e['url'],'role':e['role']}
 with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:assets=list(pool.map(get,lock['assets']))
 out.mkdir(parents=True,exist_ok=True);(out/'acquired-assets.json').write_text(json.dumps({'schema_version':1,'commit':lock['commit'],'assets':assets},indent=2)+'\n')
 print(json.dumps({'status':'PINNED_NATIVE_SOURCE_PASS','assets':len(assets),'source_directory':str(out)}))
if __name__=='__main__':main()
