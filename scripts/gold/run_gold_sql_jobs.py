"""Deprecated alias of scripts/gold/run_fotmob_gold_jobs.py."""

from src.common.deprecation import run_deprecated_script
from src.fotmob.commands.run_gold_jobs import main

if __name__ == "__main__":
    raise SystemExit(run_deprecated_script(__file__, "scripts/gold/run_fotmob_gold_jobs.py", main))
