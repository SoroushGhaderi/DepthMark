"""Scrape priority-selected Oddspedia match payloads."""

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.oddspedia.scraping.entrypoints import run_event_command

if __name__ == "__main__":
    print(
        "Warning: scripts/oddspedia/scrape_matches.py is deprecated; use "
        "scripts/oddspedia/scrape_oddspedia_matches.py instead.",
        file=sys.stderr,
    )
    run_event_command("scrape")
