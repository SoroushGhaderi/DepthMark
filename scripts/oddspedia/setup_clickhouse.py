"""Compatibility wrapper for the canonical Oddspedia warehouse setup command."""

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.oddspedia.setup_warehouse import main

if __name__ == "__main__":
    print(
        "Warning: scripts/oddspedia/setup_clickhouse.py is deprecated; use "
        "scripts/oddspedia/setup_oddspedia_warehouse.py instead.",
        file=sys.stderr,
    )
    raise SystemExit(main())
