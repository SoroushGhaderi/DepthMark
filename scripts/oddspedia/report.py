"""Deprecated Oddspedia Markdown adapter for the unified scraping report."""

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.report_scraping import main

if __name__ == "__main__":
    print(
        "Warning: scripts/oddspedia/report.py is deprecated; use "
        "scripts/report_scraping.py --source oddspedia --format markdown instead.",
        file=sys.stderr,
    )
    raise SystemExit(main(default_source="oddspedia", default_format="markdown"))
