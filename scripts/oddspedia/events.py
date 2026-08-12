"""Compatibility umbrella for the phase-specific Oddspedia commands.

Use the source-qualified, phase-specific Oddspedia scripts for new automation.
"""

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.oddspedia.scraping.cli import main


if __name__ == "__main__":
    print(
        "Warning: scripts/oddspedia/events.py is deprecated; use the source-qualified "
        "phase-specific Oddspedia scripts for new automation.",
        file=sys.stderr,
    )
    main(default_sport="football")
