"""Deprecated alias of scripts/fotmob/remove_fotmob_bronze.py."""

from src.common.deprecation import run_deprecated_script
from src.fotmob.commands.remove_bronze import main

if __name__ == "__main__":
    raise SystemExit(
        run_deprecated_script(__file__, "scripts/fotmob/remove_fotmob_bronze.py", main)
    )
