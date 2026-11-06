#!/bin/bash
# Same frozen inputs, fresh preparation/CP2/authorization, isolated output by default.
set -euo pipefail
CASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 "$CASE_DIR/scripts/replay.py" "$@"
