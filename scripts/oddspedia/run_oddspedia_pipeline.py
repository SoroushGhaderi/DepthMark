"""Canonical entry point for the Oddspedia ingestion pipeline."""

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.oddspedia.scraping.entrypoints import run_event_command

if __name__ == "__main__":
    run_event_command("run")
