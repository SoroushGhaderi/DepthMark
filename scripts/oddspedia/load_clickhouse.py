"""Compatibility wrapper for :mod:`scripts.oddspedia.load_bronze`."""

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.oddspedia.load_bronze import main


if __name__ == "__main__":
    print(
        "Warning: load_clickhouse.py is deprecated; use load_bronze.py instead.",
        file=sys.stderr,
    )
    raise SystemExit(main())
