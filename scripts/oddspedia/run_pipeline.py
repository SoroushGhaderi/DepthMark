"""Deprecated alias of scripts/oddspedia/run_oddspedia_pipeline.py."""

from src.common.deprecation import run_deprecated_script
from src.oddspedia.scraping.entrypoints import run_main

if __name__ == "__main__":
    raise SystemExit(
        run_deprecated_script(
            __file__,
            "scripts/oddspedia/run_oddspedia_pipeline.py",
            run_main,
        )
    )
