"""Deprecated alias of scripts/fotmob/load_fotmob_gold.py."""

from src.common.deprecation import run_deprecated_script
from src.fotmob.commands.load_gold import main

if __name__ == "__main__":
    raise SystemExit(run_deprecated_script(__file__, "scripts/fotmob/load_fotmob_gold.py", main))
