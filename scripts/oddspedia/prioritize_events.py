"""Deprecated alias of scripts/oddspedia/prioritize_oddspedia_events.py."""

from src.common.deprecation import run_deprecated_script
from src.oddspedia.scraping.entrypoints import prioritize_main

if __name__ == "__main__":
    raise SystemExit(
        run_deprecated_script(
            __file__,
            "scripts/oddspedia/prioritize_oddspedia_events.py",
            prioritize_main,
        )
    )
