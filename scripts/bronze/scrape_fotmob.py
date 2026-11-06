"""Deprecated alias of scripts/fotmob/scrape_fotmob.py."""

from src.common.deprecation import run_deprecated_script
from src.fotmob.commands.scrape import main

if __name__ == "__main__":
    raise SystemExit(run_deprecated_script(__file__, "scripts/fotmob/scrape_fotmob.py", main))
