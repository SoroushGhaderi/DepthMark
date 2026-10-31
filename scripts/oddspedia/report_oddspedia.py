"""Deprecated alias of scripts/report_scraping.py --source oddspedia --format markdown."""

from src.common.deprecation import run_deprecated_script
from src.operations.commands.report_scraping import main

if __name__ == "__main__":
    raise SystemExit(
        run_deprecated_script(
            __file__,
            "scripts/report_scraping.py --source oddspedia --format markdown",
            main,
            default_source="oddspedia",
            default_format="markdown",
        )
    )
