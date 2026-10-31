"""Compatibility adapter for running selected FotMob Gold SQL jobs."""

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.gold.run_fotmob_gold_jobs import main

if __name__ == "__main__":
    print(
        "Warning: scripts/gold/run_gold_sql_jobs.py is deprecated; use "
        "scripts/gold/run_fotmob_gold_jobs.py instead.",
        file=sys.stderr,
    )
    raise SystemExit(main())
