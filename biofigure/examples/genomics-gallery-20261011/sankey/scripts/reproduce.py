#!/usr/bin/env python3
"""Public plotting-table replay; author-source archive recipe is separate."""
from pathlib import Path
import subprocess,sys
p=Path(__file__).resolve().parents[2]/'replay_public.py'
subprocess.run([sys.executable,str(p),'sankey',*sys.argv[1:]],check=True)
