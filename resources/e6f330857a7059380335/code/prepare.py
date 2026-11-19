from pathlib import Path
import runpy
W=Path(__file__).resolve().parent
runpy.run_path(str(W.parents[1]/'work/2026-11-06-complex-aesthetic-four/prepare_case.py'),init_globals={'CASE':W})
