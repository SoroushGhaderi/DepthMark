"""Compatibility wrapper for canonical Oddspedia event resolution."""

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.oddspedia.resolve_events import main

if __name__ == "__main__":
    print(
        "Warning: scripts/oddspedia/resolve_matches.py is deprecated; use "
        "scripts/oddspedia/resolve_oddspedia_events.py instead.",
        file=sys.stderr,
    )
    raise SystemExit(main())
