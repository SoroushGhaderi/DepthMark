"""Deprecated alias of scripts/oddspedia/scrape_oddspedia_matches.py."""

from src.common.deprecation import run_deprecated_script
from src.oddspedia.scraping.entrypoints import scrape_main

if __name__ == "__main__":
    raise SystemExit(
        run_deprecated_script(
            __file__,
            "scripts/oddspedia/scrape_oddspedia_matches.py",
            scrape_main,
        )
    )
