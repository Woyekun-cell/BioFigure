#!/usr/bin/env python3
"""Reference-only case: author input redistribution rights are unresolved."""
import json
from pathlib import Path
import sys
profile = json.loads((Path(__file__).resolve().parents[1] / "data/metadata/public-replay.json").read_text())
sys.exit("REFERENCE_ONLY: " + profile["unavailable_reason"])
