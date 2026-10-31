"""Deprecated alias of scripts/silver/load_fotmob_silver.py."""

from src.common.deprecation import run_deprecated_script
from src.fotmob.commands.load_silver import main

if __name__ == "__main__":
    raise SystemExit(run_deprecated_script(__file__, "scripts/silver/load_fotmob_silver.py", main))
