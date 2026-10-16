"""Write a new 3.8 current public-gallery manifest; never rewrite 3.7 history."""
from pathlib import Path
import hashlib,json,sys
ROOT=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
old=json.loads((ROOT/'docs/gallery/refresh-20261011.json').read_text(encoding='utf-8'))
excluded={'BF-0219','BF-0220'}
artifacts=[]
for a in old['artifacts']:
 if a['gallery_id'] in excluded:continue
 a=dict(a)
 original_paths={f['path'] for f in a['files']}
 prov=a['provenance'] if isinstance(a['provenance'],str) else a['provenance']['path']
 case=(ROOT/prov).parent
 original_paths.update(p.relative_to(ROOT).as_posix() for p in case.rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.name!='.DS_Store')
 a['files']=[{'path':rel,'sha256':sha(ROOT/rel)} for rel in sorted(original_paths) if (ROOT/rel).is_file()]
 profile=json.loads((case/'data/metadata/public-replay.json').read_text(encoding='utf-8'))
 a['public_execution_status']=profile.get('status','runnable')
 a['release_scope']='Current packaged own-layout processed-input replay; no new visual or original-paper qualification inferred.'
 artifacts.append(a)
current={k:v for k,v in old.items() if k not in ['artifacts','new_figures']}
by_id={row['id']:row for row in json.loads((ROOT/'docs/gallery/catalog.json').read_text(encoding='utf-8'))['figures']}
for replacement in current.get('replacements',[]):replacement['current_sha256']=by_id[replacement['gallery_id']]['sha256']
if (ROOT/'docs/gallery/runtime-validation-3.8.0.json').is_file():current['runtime_validation']={'path':'docs/gallery/runtime-validation-3.8.0.json','sha256':sha(ROOT/'docs/gallery/runtime-validation-3.8.0.json')}
current.update(release='3.8.0',inventory_date='2026-10-16',artifacts=artifacts,
 new_figures=len(artifacts)-len(old['replacements']),
 current_scope='Six retained earlier public adapter archives with explicit current execution status; seven first-party portable examples are bound separately by biofigure/public-cases.json. DPM derivatives are excluded for unresolved input redistribution rights. Historical images do not certify a currently blocked renderer.',
 historical_manifest='docs/gallery/refresh-20261011.json',
 rights_exclusions='docs/gallery/rights-exclusions-3.8.0.json')
(ROOT/'docs/gallery/refresh-3.8.0.json').write_text(json.dumps(current,ensure_ascii=False,indent=2)+'\n', encoding='utf-8')
(ROOT/'docs/gallery/current-release.json').write_text(json.dumps({'schema_version':1,'release':'3.8.0','current_refresh_manifest':'docs/gallery/refresh-3.8.0.json','public_case_manifest':'biofigure/public-cases.json','rights_exclusions':'docs/gallery/rights-exclusions-3.8.0.json'},ensure_ascii=False,indent=2)+'\n', encoding='utf-8')
print('CURRENT_GALLERY_MANIFEST',len(artifacts),'retained adapters; historical manifest unchanged')
