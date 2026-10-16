#!/usr/bin/env python3
"""Install pinned author packages and locked import dependencies in a task-owned R library."""
# ARCHIVAL helper only. Public reproduce.py requires an existing native R library.
from pathlib import Path
import argparse,hashlib,json,subprocess,urllib.request,tarfile,shutil
ROOT=Path(__file__).resolve().parents[1]
def main():
 parser=argparse.ArgumentParser(); parser.add_argument('library',type=Path); parser.add_argument('--cache',type=Path);parser.add_argument('--r',default='R');parser.add_argument('--openssl-lib',type=Path);args=parser.parse_args()
 if any(not (ROOT/'sources/package'/name/'DESCRIPTION').is_file() for name in ['HiCExperiment','HiContacts']):
  parser.error('ARCHIVAL_HELPER_UNAVAILABLE: author package source trees are not bundled; use scripts/install_public_dependencies.R --profile all-public with an explicit --library instead')
 lib=args.library.resolve(); lib.mkdir(parents=True,exist_ok=True);cache=(args.cache or lib.parent/'package-cache').resolve();cache.mkdir(parents=True,exist_ok=True)
 lock=json.loads((ROOT/'data/metadata/native-dependency-lock.json').read_text(encoding="utf-8"))
 # Topological order is required; metadata contains only pinned URLs and SHA256 hashes.
 order=['dir.expiry','biocmake','BiocBaseUtils','BiocGenerics','UCSC.utils','Rhdf5lib','rhdf5filters','InteractionSet','BiocIO','rhdf5','strawr','GenomeInfoDb']
 entries={x['package']:x for x in lock['assets']}
 env=__import__('os').environ.copy();env['R_LIBS_USER']=str(lib)
 build=json.loads((ROOT/'data/metadata/build-tool-lock.json').read_text(encoding="utf-8"))
 build_cache=lib.parent/'build-cache'; build_cache.mkdir(parents=True,exist_ok=True)
 archive=build_cache/Path(build['url']).name
 if not archive.exists():
  with urllib.request.urlopen(build['url'],timeout=90) as response:b=response.read(build['bytes']+1)
  if len(b)!=build['bytes'] or hashlib.sha256(b).hexdigest()!=build['sha256']:raise ValueError('CMake source mismatch')
  archive.write_bytes(b)
 if hashlib.sha256(archive.read_bytes()).hexdigest()!=build['sha256']:raise ValueError('CMake source mismatch')
 cmake=build_cache/('cmake-'+build['version']+'-macos-universal/CMake.app/Contents/bin/cmake')
 if not cmake.exists():
  with tarfile.open(archive) as tar:tar.extractall(build_cache,filter='data')
 env['BIOCMAKE_FIND_OVERRIDE']=str(cmake);env['BIOCMAKE_CMAKE_CACHE_DIRECTORY']=str(build_cache)
 # An optional caller-selected OpenSSL directory is local to this invocation.
 # No machine-specific default or global R/system configuration is changed.
 ssl=args.openssl_lib.resolve() if args.openssl_lib else None
 if ssl is not None:
  if not ssl.is_dir():parser.error('--openssl-lib must name an existing directory')
  makevars=build_cache/'Makevars';makevars.write_text('LDFLAGS += -L'+str(ssl)+'\n', encoding="utf-8")
  env['R_MAKEVARS_USER']=str(makevars)
 for name in order:
  e=entries[name];tar=cache/(name+'_'+e['version']+'.tar.gz')
  if not tar.exists():
   with urllib.request.urlopen(e['url'],timeout=90) as response:b=response.read(e['bytes']+1)
   if len(b)!=e['bytes'] or hashlib.sha256(b).hexdigest()!=e['sha256']:raise ValueError('Dependency source mismatch:'+name)
   tar.write_bytes(b)
  if hashlib.sha256(tar.read_bytes()).hexdigest()!=e['sha256']:raise ValueError('Dependency source mismatch:'+name)
  desc=lib/name/'DESCRIPTION'
  if desc.exists() and ('Version: '+e['version']+'\n') in desc.read_text(encoding="utf-8"):continue
  # These task-owned incomplete install directories are regenerable, never original data.
  for partial in (lib/('00LOCK-'+name),lib/name):
   if partial.exists():shutil.rmtree(partial)
  subprocess.run([args.r,'CMD','INSTALL','--no-docs','--no-html','--library='+str(lib),str(tar)],check=True,env=env)
 for name in ['HiCExperiment','HiContacts']:
  subprocess.run([args.r,'CMD','INSTALL','--no-docs','--no-html','--library='+str(lib),str(ROOT/'sources/package'/name)],check=True,env=env)
 print(json.dumps({'status':'NATIVE_PACKAGES_INSTALLED','library':str(lib),'global_library_modified':False}))
if __name__=='__main__':main()
