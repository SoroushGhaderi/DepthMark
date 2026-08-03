"""Compatibility umbrella for the phase-specific Oddspedia commands.

Use ``discover_events.py``, ``prioritize_events.py``, ``scrape_matches.py``,
``run_pipeline.py``, and ``status.py`` for new automation.
"""

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.oddspedia.scraping.cli import main


if __name__ == "__main__":
    print(
        "scripts/oddspedia/events.py is a compatibility entry point; use the "
        "phase-specific Oddspedia scripts for new automation.",
        file=sys.stderr,
    )
    main(default_sport="football")
