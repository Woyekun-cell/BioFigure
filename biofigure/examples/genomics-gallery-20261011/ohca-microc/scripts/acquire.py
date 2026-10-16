#!/usr/bin/env python3
"""ARCHIVAL full-source acquisition helper; not the public replay entry.
Its full author acquisition-plan is intentionally not bundled; reproduce.py acquires only the pinned RDS.
"""
from pathlib import Path
import argparse, hashlib, json, urllib.request, concurrent.futures

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--check-only',action='store_true'); args=parser.parse_args()
    root=Path(__file__).resolve().parents[1]
    manifest=json.loads((root/'data/metadata/acquisition-plan.json').read_text(encoding="utf-8"))
    def acquire(entry):
        dest=root/entry['path']
        if dest.exists(): data=dest.read_bytes()
        elif args.check_only: raise FileNotFoundError(dest)
        else:
            with urllib.request.urlopen(entry['url'],timeout=60) as response:
                data=response.read(entry['max_bytes']+1)
            if len(data)>entry['max_bytes']: raise ValueError('Size cap exceeded: '+entry['path'])
            if len(data)!=entry.get('expected_bytes',len(data)): raise ValueError('Size mismatch: '+entry['path'])
            sha=entry.get('git_blob_sha')
            if sha and hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()!=sha: raise ValueError('Git blob mismatch: '+entry['path'])
            dest.parent.mkdir(parents=True,exist_ok=True); dest.write_bytes(data)
        if len(data)!=entry.get('expected_bytes',len(data)): raise ValueError('Size mismatch: '+entry['path'])
        sha=entry.get('git_blob_sha')
        if sha and hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()!=sha: raise ValueError('Git blob mismatch: '+entry['path'])
        return dict(entry,path=str(dest),sha256=hashlib.sha256(data).hexdigest(),bytes=len(data))
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool: acquired=list(pool.map(acquire,manifest['files']))
    target=root/'data/metadata/acquired-assets.json'
    value={'schema_version':1,'assets':acquired}
    encoded=json.dumps(value,indent=2,ensure_ascii=False)+'\n'
    if target.exists():
        if target.read_text(encoding="utf-8")!=encoded: raise ValueError('Refuse overwrite changed acquisition evidence')
    else: target.write_text(encoded, encoding="utf-8")
    print(json.dumps({'status':'PASS','assets':len(acquired),'bytes':sum(x['bytes'] for x in acquired),'manifest':str(target)},ensure_ascii=False))
if __name__=='__main__': main()
