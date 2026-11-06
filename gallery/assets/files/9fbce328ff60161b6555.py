#!/usr/bin/env python3
"""Recreate only the task-isolated R library from archived official source tarballs."""
from pathlib import Path
import os, subprocess, sys, tarfile
root=Path(__file__).resolve().parents[1]
work=Path(sys.argv[1]).resolve()
lib=work/"R-lib";lib.mkdir(parents=True,exist_ok=True)
env=os.environ.copy();env["R_LIBS_USER"]=str(lib)
archives=[
 ("UCSC.utils-e02c191d114d0507bd45df4d4bbbb48220383fbe.tar.gz","UCSC.utils-e02c191d114d0507bd45df4d4bbbb48220383fbe"),
 ("GenomeInfoDb-44b18f529396a2020b4cdf5a5ec62ca87e122832.tar.gz","GenomeInfoDb-44b18f529396a2020b4cdf5a5ec62ca87e122832"),
 ("ggtranscript-source.tar.gz","ggtranscript-682a0df688ad242fa262d0b0557bf973dc202787")]
for archive,directory in archives:
 with tarfile.open(root/"sources"/archive) as handle:
  handle.extractall(work,filter="data")
 subprocess.run(["R","CMD","INSTALL",f"--library={lib}",str(work/directory)],env=env,check=True)
print(lib)

