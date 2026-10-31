"""Deprecated alias of scripts/oddspedia/discover_oddspedia_events.py."""

from src.common.deprecation import run_deprecated_script
from src.oddspedia.scraping.entrypoints import discover_main

if __name__ == "__main__":
    raise SystemExit(
        run_deprecated_script(
            __file__,
            "scripts/oddspedia/discover_oddspedia_events.py",
            discover_main,
        )
    )
