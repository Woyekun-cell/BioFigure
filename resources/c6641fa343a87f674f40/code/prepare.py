from pathlib import Path
import runpy,sys
W=Path(__file__).resolve().parent
sys.argv=[str(W)]
runpy.run_path(str(W.parents[1]/'work/2026-11-06-genomic-structures-next/prepare_case.py'),init_globals={'CASE':W})
