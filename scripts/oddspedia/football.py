"""Deprecated compatibility wrapper for :mod:`scripts.oddspedia.events`."""

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.oddspedia.scraping.cli import main


if __name__ == "__main__":
    print(
        "scripts/oddspedia/football.py is deprecated; use the phase-specific "
        "Oddspedia scripts such as run_pipeline.py",
        file=sys.stderr,
    )
    main(default_sport="football")
