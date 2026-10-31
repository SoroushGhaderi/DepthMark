"""Deprecated alias of the source-qualified, phase-specific Oddspedia scripts."""

from src.common.deprecation import run_deprecated_script
from src.oddspedia.scraping.entrypoints import football_main

if __name__ == "__main__":
    raise SystemExit(
        run_deprecated_script(
            __file__,
            "the source-qualified, phase-specific Oddspedia scripts",
            football_main,
        )
    )
